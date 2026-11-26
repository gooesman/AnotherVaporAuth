import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../../services/steam_network.dart';
import '../../services/steam_time.dart';
import '../models/steam_guard_account.dart';
import '../models/trade_offer.dart';
import '../models/steam_friend.dart';
import '../models/trade_draft.dart';
import 'community_session.dart';
import 'eresult.dart';

/// Result of accepting a trade offer.
class TradeAcceptResult {
  final bool success;
  final bool needsMobileConfirmation;
  final String? message;
  const TradeAcceptResult({
    required this.success,
    this.needsMobileConfirmation = false,
    this.message,
  });
}

/// Trade offers for one account: list/count via the documented IEconService
/// JSON API (access_token auth), plus accept/decline/cancel via the community
/// `tradeoffer` endpoints (sessionid cookie/form auth).
class TradeOffersClient {
  final SteamApiClient api;
  TradeOffersClient(this.api);

  /// Creates an offer only; mobile/email confirmation remains a separate,
  /// explicit user action. This write must never be automatically retried.
  /// Protocol: Steam's own public/javascript/economy_tradeoffer.js,
  /// CTradeOfferStateManager.ConfirmTradeOffer (verified 2026-10-10).
  Future<TradeSendResult> send(
    SteamGuardAccount account,
    TradeDraft draft,
  ) async {
    requireAccessToken(account);
    draft.validate('${account.steamId}');
    final startedAt = SteamTime.currentSteamTime;
    Set<String>? previousIds;
    try {
      previousIds = (await _sentForCheck(
        account,
        startedAt - 300,
        timeout: const Duration(seconds: 3),
      )).map((offer) => '${offer['tradeofferid']}').toSet();
    } catch (_) {
      // Reconciliation is optional: a Web API outage must not prevent the
      // community write. Without this snapshot, no later match proves success.
    }
    draft.validate('${account.steamId}');
    final sid = newCommunitySessionId();
    Object? uncertainCause;
    try {
      final json = await api.communityPostJson(
        '/tradeoffer/new/send',
        {
          'sessionid': sid,
          'serverid': '1',
          'partner': draft.partnerSteamId,
          'tradeoffermessage': draft.message,
          'json_tradeoffer': jsonEncode(draft.toJson()),
          'captcha': '',
          'trade_offer_create_params': '{}',
        },
        cookies: communityCookies(account, sessionId: sid),
        referer:
            '${SteamApiClient.communityBase}/tradeoffer/new/'
            '?partner=${steamAccountId(draft.partnerSteamId)}',
      );
      return _sendReceipt(json);
    } on DioException catch (error) {
      // Steam's own trade page reads strError from failed HTTP responses too.
      // In particular, a 5xx business rejection is still a useful diagnostic;
      // Dio throws it before communityPostJson can decode the response.
      final data = error.response?.data;
      Map<String, dynamic>? diagnostic;
      if (data is Map<String, dynamic>) diagnostic = data;
      if (data is String) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) diagnostic = decoded;
        } on FormatException {
          /* A gateway's HTML is not a Steam receipt. */
        }
      }
      if (diagnostic != null) {
        try {
          return _sendReceipt(diagnostic);
        } on TradeSendUnconfirmed {
          /* Reconcile, never repeat the POST. */
        }
      }
      if (error.error is SteamConnectionSetupException) {
        throw TradeSendNotSent(error);
      }
      uncertainCause = error;
    } on TradeSendUnconfirmed catch (error) {
      uncertainCause = error.cause;
    } on FormatException {
      // Do not expose raw HTML / response fragments in the UI.
    } on SteamApiException catch (error) {
      if ((error.httpStatus ?? 0) < 500) rethrow;
      uncertainCause = error;
    } on CommunityAuthException {
      rethrow;
    } on TradeSendRejected {
      rethrow;
    } catch (error) {
      uncertainCause = error;
    }
    final uncertain = TradeSendUnconfirmed(
      cause: uncertainCause,
      attempt: TradeSendAttempt(
        draft: draft,
        startedAt: startedAt,
        finishedAt: SteamTime.currentSteamTime,
        previousOfferIds: previousIds,
      ),
    );
    try {
      final found = await recheckSend(account, uncertain);
      if (found != null) return found;
    } catch (_) {
      /* The UI offers another read-only check with no resend. */
    }
    throw uncertain;
  }

  static bool _yes(dynamic value) =>
      value == true || value == 1 || value == '1';
  static bool _no(dynamic value) =>
      value == false || value == 0 || value == '0';
  static bool _validId(String id) => RegExp(r'^[1-9]\d*$').hasMatch(id);

  TradeSendResult _sendReceipt(Map<String, dynamic> json) {
    if (_yes(json['needauth']) || _yes(json['needsauth'])) {
      throw const CommunityAuthException(401, '/tradeoffer/new/send');
    }
    final id = '${json['tradeofferid'] ?? ''}';
    final rawDiagnostic = [
      json['strError'],
      json['message'],
      json['error'],
    ].whereType<String>().where((s) => s.trim().isNotEmpty).firstOrNull;
    final diagnostic = rawDiagnostic == null
        ? null
        : DebugLog.redactSecrets(
            rawDiagnostic.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
          );
    final resultCode = int.tryParse('${json['eresult'] ?? ''}');
    final rejected =
        _no(json['success']) ||
        (resultCode != null && resultCode != 1) ||
        (json['strError'] is String &&
            (json['strError'] as String).isNotEmpty) ||
        (json['error'] is String && (json['error'] as String).isNotEmpty);
    if (rejected) {
      // Contradictory diagnostics with an ID do not prove the write failed.
      if (_validId(id)) throw const TradeSendUnconfirmed();
      if (diagnostic != null || resultCode != null) {
        throw SteamApiException(
          resultCode ?? 2,
          diagnostic ?? eresultLabel(resultCode!),
          'SendTradeOffer',
        );
      }
      throw const TradeSendRejected();
    }
    if (!_validId(id)) {
      // A message alone may describe a queued/successful write. Without an
      // explicit rejection or receipt ID, it cannot authorize another send.
      throw TradeSendUnconfirmed(
        cause: diagnostic == null
            ? null
            : SteamApiException(2, diagnostic, 'SendTradeOffer'),
      );
    }
    return TradeSendResult(
      offerId: id,
      needsMobileConfirmation: _yes(json['needs_mobile_confirmation']),
      needsEmailConfirmation: _yes(json['needs_email_confirmation']),
    );
  }

  /// Only reads Steam. A missing match is never proof that no offer was sent:
  /// indexing may lag, items may already be accepted, or pagination may fail.
  Future<TradeSendResult?> recheckSend(
    SteamGuardAccount account,
    TradeSendUnconfirmed uncertain,
  ) async {
    final attempt = uncertain.attempt;
    if (attempt == null || attempt.previousOfferIds == null) return null;
    attempt.draft.validate('${account.steamId}');
    final offers = await _sentForCheck(account, attempt.startedAt - 300);
    final draft = attempt.draft;
    bool assetsMatch(dynamic raw, List<TradeSelection> expected) {
      if (raw == null) return expected.isEmpty;
      if (raw is! List || raw.length != expected.length) return false;
      final actual = <String, int>{};
      for (final item in raw) {
        if (item is! Map) return false;
        final key = '${item['appid']}/${item['contextid']}/${item['assetid']}';
        final amount = int.tryParse('${item['amount']}');
        if (amount == null || actual.containsKey(key)) return false;
        actual[key] = amount;
      }
      return expected.every((item) => actual[item.key] == item.amount);
    }

    final matches = offers.where((offer) {
      final created = int.tryParse('${offer['time_created']}') ?? 0;
      final partner = int.tryParse('${offer['accountid_other']}');
      return _yes(offer['is_our_offer']) &&
          !attempt.previousOfferIds!.contains('${offer['tradeofferid']}') &&
          created >= attempt.startedAt - 2 &&
          created <= attempt.finishedAt + 2 &&
          '$partner' == steamAccountId(draft.partnerSteamId) &&
          (offer['message'] ?? '') == draft.message &&
          assetsMatch(offer['items_to_give'], draft.give) &&
          assetsMatch(offer['items_to_receive'], draft.receive);
    }).toList();
    if (matches.length != 1) return null;
    final match = matches.single;
    final state = int.tryParse('${match['trade_offer_state']}');
    if (state != 2 && state != 3 && state != 9 && state != 11) return null;
    final confirmation = int.tryParse('${match['confirmation_method']}');
    // For a pending offer, do not claim completion unless Steam identifies the
    // confirmation route. Unknown methods remain in the safe unresolved state.
    if (state == 9 && confirmation != 1 && confirmation != 2) return null;
    return TradeSendResult(
      offerId: '${match['tradeofferid']}',
      needsMobileConfirmation: state == 9 && confirmation == 2,
      needsEmailConfirmation: state == 9 && confirmation == 1,
    );
  }

  Future<List<Map<String, dynamic>>> _sentForCheck(
    SteamGuardAccount account,
    int since, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final token = requireAccessToken(account);
    final elapsed = Stopwatch()..start();
    final offers = <Map<String, dynamic>>[];
    final seenCursors = <String>{};
    var cursor = '0';
    for (var page = 0; page < 5; page++) {
      final remaining = timeout - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('Offer query timed out');
      }
      final json = await api
          .apiGetJson('IEconService', 'GetTradeOffers', {
            'get_sent_offers': '1',
            'get_received_offers': '0',
            'get_descriptions': '0',
            'active_only': '1',
            'historical_only': '0',
            'time_historical_cutoff': '$since',
            'cursor': cursor,
          }, accessToken: token)
          .timeout(remaining);
      final response = json['response'];
      if (response is! Map) {
        throw const FormatException('Incomplete offer list');
      }
      final list = response['trade_offers_sent'];
      if (list != null && list is! List) {
        throw const FormatException('Invalid offer list');
      }
      for (final value in (list as List?) ?? const []) {
        if (value is! Map<String, dynamic> ||
            !_validId('${value['tradeofferid']}')) {
          throw const FormatException('Invalid offer identifier');
        }
        offers.add(value);
      }
      cursor = '${response['next_cursor'] ?? 0}';
      if (cursor == '0') return offers;
      if (!_validId(cursor) || !seenCursors.add(cursor)) break;
    }
    throw const FormatException('Incomplete offer pagination');
  }

  /// Safely narrows a decoded-JSON value to `Map<String, dynamic>`. A plain
  /// `as Map<String, dynamic>?` cast throws when the value is a
  /// `Map<dynamic, dynamic>` (e.g. an empty `{}` literal in tests, or some
  /// JSON decoders) — this converts instead of casting, and defaults to
  /// empty for anything else (missing key, null, non-map).
  Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};

  /// Active (default) or historical offers, both directions, with
  /// descriptions joined. Historical == the "历史" segment.
  Future<TradeOffersPage> fetch(
    SteamGuardAccount account, {
    bool historical = false,
  }) async {
    final token = requireAccessToken(account);
    final json = await api.apiGetJson('IEconService', 'GetTradeOffers', {
      'get_received_offers': '1',
      'get_sent_offers': '1',
      'get_descriptions': '1',
      'language': api.steamLanguage,
      'active_only': historical ? '0' : '1',
      'historical_only': historical ? '1' : '0',
    }, accessToken: token);
    final page = TradeOffersPage.fromResponse(_asMap(json['response']));
    dlog(
      'trade offers: ${page.received.length} received, '
      '${page.sent.length} sent (historical=$historical)',
    );
    return page;
  }

  /// Count of pending received offers (tab badge).
  Future<int> pendingReceivedCount(SteamGuardAccount account) async {
    final token = requireAccessToken(account);
    final json = await api.apiGetJson(
      'IEconService',
      'GetTradeOffersSummary',
      const {},
      accessToken: token,
    );
    final resp = _asMap(json['response']);
    final v = resp['pending_received_count'];
    return v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  }

  /// Partner display info via the community miniprofile endpoint (no auth).
  /// Returns (personaName, avatarUrl); empty strings on failure.
  Future<(String, String)> miniProfile(int accountId) async {
    try {
      final json = await api.communityGetJson(
        '/miniprofile/$accountId/json',
        const {},
      );
      return (
        (json['persona_name'] ?? '') as String,
        (json['avatar_url'] ?? '') as String,
      );
    } catch (_) {
      return ('', '');
    }
  }

  /// Accepts a received offer. Steam replies `{tradeid, needs_mobile_confirmation}`
  /// on success or `{strError}` on failure. A mobileconf (type 2) usually
  /// follows — the caller routes the user to the confirmations tab.
  Future<TradeAcceptResult> accept(
    SteamGuardAccount account,
    TradeOffer offer,
  ) async {
    requireAccessToken(account);
    final sid = newCommunitySessionId();
    final Map<String, dynamic> json;
    try {
      json = await api.communityPostJson(
        '/tradeoffer/${offer.id}/accept',
        {
          'sessionid': sid,
          'serverid': '1',
          'tradeofferid': offer.id,
          'partner': '${offer.partnerSteamId}',
          'captcha': '',
        },
        cookies: communityCookies(account, sessionId: sid),
        referer: '${SteamApiClient.communityBase}/tradeoffer/${offer.id}/',
      );
    } on CommunityAuthException {
      // A stale session can also surface at the HTTP layer (401 or a redirect
      // to the login page) — same routing as the needauth JSON reply below.
      dlog('tradeoffer accept ${offer.id} -> needauth (http)');
      return const TradeAcceptResult(success: false, message: 'needauth');
    }
    // An expired session surfaces as needauth/needsauth — return a
    // recognizable message so the UI can route to re-login.
    if (json['needauth'] == true || json['needsauth'] == true) {
      dlog('tradeoffer accept ${offer.id} -> needauth');
      return const TradeAcceptResult(success: false, message: 'needauth');
    }
    final err = json['strError'] as String?;
    // Success requires a positive marker: tradeid echo or the mobileconf
    // flag. (Steam can also reply `needs_email_confirmation` for accounts
    // without a mobile authenticator — near-theoretical for AVA users, so
    // it's not handled, but noting the shape here for posterity.)
    final ok =
        err == null &&
        (json.containsKey('tradeid') ||
            json['needs_mobile_confirmation'] == true);
    dlog('tradeoffer accept ${offer.id} -> ok=$ok err=${err ?? '-'}');
    return TradeAcceptResult(
      success: ok,
      needsMobileConfirmation: json['needs_mobile_confirmation'] == true,
      message: err,
    );
  }

  /// Declines a received offer / cancels a sent one. Success must be
  /// positively confirmed by Steam echoing `{"tradeofferid": "..."}` — an
  /// empty body (expired session decoded as {}) must NOT read as "declined":
  /// telling the user a still-active phishing offer was declined is the
  /// worst failure mode for an authenticator app.
  Future<bool> decline(SteamGuardAccount account, String offerId) =>
      _writeOp(account, offerId, 'decline');

  Future<bool> cancel(SteamGuardAccount account, String offerId) =>
      _writeOp(account, offerId, 'cancel');

  Future<bool> _writeOp(
    SteamGuardAccount account,
    String offerId,
    String op,
  ) async {
    requireAccessToken(account);
    final sid = newCommunitySessionId();
    try {
      final json = await api.communityPostJson(
        '/tradeoffer/$offerId/$op',
        {'sessionid': sid},
        cookies: communityCookies(account, sessionId: sid),
        referer: '${SteamApiClient.communityBase}/tradeoffer/$offerId/',
      );
      if (json['needauth'] == true || json['needsauth'] == true) return false;
      if (json['strError'] != null) return false;
      if (json.containsKey('success') && json['success'] != true) return false;
      // Success must be positively confirmed by the offer-id echo — an empty
      // body (expired session decoded as {}) must NOT read as "declined".
      final ok = json['tradeofferid'] != null;
      dlog(
        'tradeoffer $op $offerId -> '
        '${ok ? 'ok' : 'no confirmation in reply'}',
      );
      return ok;
    } on CommunityAuthException {
      // HTTP-level stale session: propagate so the tab can point the user at
      // re-auth — swallowed as `false` it would read as a generic failure
      // with no sign-in cue, unlike accept()'s needauth mapping.
      rethrow;
    } catch (e) {
      dlog('tradeoffer $op $offerId failed: $e');
      return false;
    }
  }
}
