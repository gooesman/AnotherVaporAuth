import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../json_coerce.dart';
import '../models/market_search.dart';
import '../models/steam_guard_account.dart';
import '../models/steam_item.dart';
import 'community_session.dart';

/// Result of listing an item for sale.
class SellResult {
  final bool success;
  final bool requiresConfirmation;
  final String? message;
  const SellResult({
    required this.success,
    this.requiresConfirmation = false,
    this.message,
  });
}

/// Steam Community Market operations for one account: price lookup, listing an
/// item for sale, listing management. All writes are POST form bodies with a
/// generated `sessionid` (sent as both a cookie and a form field) and a Referer.
class MarketClient {
  final SteamApiClient api;
  MarketClient(this.api);

  String _inventoryReferer(SteamGuardAccount a) =>
      '${SteamApiClient.communityBase}/profiles/${a.steamId}/inventory';

  /// Reads one public search page, including its quoted prices. No account
  /// cookies, login, retries, or per-item requests are needed. A caller's
  /// SteamRequestScope supplies cancellation and its whole-operation deadline
  /// through SteamApiClient (the search screen uses twelve seconds).
  Future<MarketSearchPage> search({
    required String query,
    int? appid,
    required int currency,
    int start = 0,
    int count = 20,
  }) async {
    if (appid != null && (appid <= 0 || appid > 0x7fffffff)) {
      throw ArgumentError.value(appid, 'appid');
    }
    if (currency <= 0 || currency > 1000) {
      throw ArgumentError.value(currency, 'currency');
    }
    if (start < 0 || start > 0x7fffffff - 20) {
      throw ArgumentError.value(start, 'start');
    }
    if (count <= 0) throw ArgumentError.value(count, 'count');
    if (query.length > 512 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(query)) {
      throw ArgumentError.value(query, 'query');
    }
    final pageSize = count.clamp(1, 20);
    final json = await api.communityGetJson('/market/search/render/', {
      'query': query.trim(),
      'start': '$start',
      'count': '$pageSize',
      'search_descriptions': '0',
      'sort_column': 'popular',
      'sort_dir': 'desc',
      if (appid != null) 'appid': '$appid',
      'norender': '1',
      'currency': '$currency',
      'l': api.steamLanguage,
    });
    if (json['success'] != true &&
        !(json['success'] is int && json['success'] == 1)) {
      // A 429 can carry JSON diagnostics; the shared community transport
      // preserves that body rather than the status. Keep Steam's explicit
      // RateLimitExceeded code, without guessing from arbitrary message text.
      final result = json['eresult'];
      final rateLimited = (result is int && result == 84) || result == '84';
      throw SteamApiException(
        rateLimited ? 84 : 2,
        rateLimited
            ? 'Steam market search rate limited'
            : 'Steam market search failed',
        '/market/search/render/',
      );
    }
    return MarketSearchPage.fromJson(
      json,
      expectedStart: start,
      maximumPageSize: pageSize,
    );
  }

  /// Historical sale prices for the item (for a trend sparkline). Returns the
  /// most recent [points] price values, or empty on failure. Requires login.
  Future<List<double>> priceHistory(
    SteamGuardAccount account,
    int appid,
    String marketHashName, {
    int points = 60,
  }) async {
    final sid = newCommunitySessionId();
    try {
      final json = await api.communityGetJson('/market/pricehistory/', {
        'appid': '$appid',
        'market_hash_name': marketHashName,
      }, cookies: communityCookies(account, sessionId: sid));
      if (json['success'] != true) return const [];
      final prices = (json['prices'] as List?) ?? const [];
      final values = <double>[];
      for (final p in prices) {
        if (p is List && p.length >= 2 && p[1] is num) {
          values.add((p[1] as num).toDouble());
        }
      }
      return values.length > points
          ? values.sublist(values.length - points)
          : values;
    } catch (_) {
      return const [];
    }
  }

  /// Reference price for an item (localized strings). Null on failure/rate-limit.
  Future<MarketPrice?> priceOverview(
    int appid,
    String marketHashName,
    int currency,
  ) async {
    try {
      final json = await api.communityGetJson('/market/priceoverview/', {
        'appid': '$appid',
        'currency': '$currency',
        'market_hash_name': marketHashName,
      });
      if (json['success'] != true) return null;
      return MarketPrice.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Lists [item] for sale. [priceReceive] is the amount the seller receives, in
  /// the wallet's minor units. On success Steam usually needs a mobile
  /// confirmation to finalize the listing.
  Future<SellResult> sell(
    SteamGuardAccount account,
    InventoryItem item,
    int priceReceive, {
    String? assetId,
  }) async {
    final sid = newCommunitySessionId();
    final json = await api.communityPostJson(
      '/market/sellitem/',
      {
        'sessionid': sid,
        'appid': '${item.appid}',
        'contextid': item.contextId,
        'assetid': assetId ?? item.assetId,
        'amount': '1',
        'price': '$priceReceive',
      },
      cookies: communityCookies(account, sessionId: sid),
      referer: _inventoryReferer(account),
    );
    final ok = json['success'] == true;
    final needsConf =
        json['requires_confirmation'] == 1 ||
        json['needs_mobile_confirmation'] == true;
    dlog(
      'sellitem ${item.marketHashName} price=$priceReceive '
      '-> success=$ok conf=$needsConf',
    );
    return SellResult(
      success: ok,
      requiresConfirmation: needsConf,
      message: json['message'] as String?,
    );
  }

  /// The account's listings, including held and unconfirmed ones. Steam sends
  /// the latter in separate buckets, whose entries are often `active: 0`.
  /// [count] controls the active-listings page size, not the overall result cap.
  Future<List<MarketListing>> myListings(
    SteamGuardAccount account, {
    int count = 100,
  }) async {
    final sid = newCommunitySessionId();
    final pageSize = count.clamp(1, 100);
    final all = <String, MarketListing>{};
    final pagedListingIds = <String>{};
    var start = 0;
    while (true) {
      final json = await api.communityGetJson('/market/mylistings/', {
        'norender': '1',
        'count': '$pageSize',
        'start': '$start',
        'l': api.steamLanguage,
      }, cookies: communityCookies(account, sessionId: sid));
      if (json['needauth'] == true || json['needsauth'] == true) {
        throw CommunityAuthException(401, '/market/mylistings/');
      }
      if (json['success'] != true && asInt(json['success']) != 1) {
        throw const FormatException('Steam market listings are unavailable.');
      }
      for (final listing in parseListings(json)) {
        final existing = all[listing.listingId];
        // Hold/confirmation buckets may be repeated on every active page.
        // An explicit pending state wins over a duplicate "active" record.
        if (existing == null || listing.state != MarketListingState.active) {
          all[listing.listingId] = listing;
        }
      }
      final activePage = _listingObjects(json['listings']);
      final next = start + activePage.length;
      final total = asInt(json['total_count']);
      if (activePage.isEmpty) {
        if (start < total) {
          throw const FormatException('Steam market pagination ended early.');
        }
        break;
      }
      final before = pagedListingIds.length;
      for (final raw in activePage) {
        final id = raw['listingid']?.toString() ?? '';
        if (RegExp(r'^\d+$').hasMatch(id)) pagedListingIds.add(id);
      }
      // Check progress before the final-page condition: a repeated last page
      // can reach the advertised offset without yielding the missing listing.
      // Held/confirmation buckets do not participate in active pagination.
      if (pagedListingIds.length == before) {
        throw const FormatException('Steam market pagination did not advance.');
      }
      if (next >= total) {
        if (pagedListingIds.length < total) {
          throw const FormatException(
            'Steam market pagination was incomplete.',
          );
        }
        break;
      }
      start = next;
    }
    return all.values.toList();
  }

  /// The JSON variant of Steam's mylistings response has three independent
  /// collections. Assets can be inline or referenced via the shared asset map.
  static List<MarketListing> parseListings(Map<String, dynamic> json) {
    final result = <String, MarketListing>{};
    for (final (key, state) in [
      ('listings', null),
      ('listings_on_hold', MarketListingState.onHold),
      ('listings_to_confirm', MarketListingState.pendingConfirmation),
    ]) {
      for (final raw in _listingObjects(json[key])) {
        final id = raw['listingid']?.toString() ?? '';
        if (!RegExp(r'^\d+$').hasMatch(id)) continue;
        final asset = raw['asset'];
        final merged = Map<String, dynamic>.from(raw);
        if (asset is Map) {
          dynamic full = json['assets'];
          for (final part in [
            asset['appid'],
            asset['contextid'],
            asset['id'],
          ]) {
            full = full is Map ? full['$part'] : null;
          }
          merged['asset'] = <String, dynamic>{
            if (full is Map) ...Map<String, dynamic>.from(full),
            ...Map<String, dynamic>.from(asset),
          };
        }
        result[id] = MarketListing.fromJson(merged, state: state);
      }
    }
    return result.values.toList();
  }

  static List<Map<String, dynamic>> _listingObjects(dynamic value) {
    final entries = value is List
        ? value
        : value is Map
        ? value.values
        : const [];
    return entries.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// Cancels/removes an active listing.
  Future<bool> cancel(SteamGuardAccount account, String listingId) async {
    final sid = newCommunitySessionId();
    try {
      final json = await api.communityPostJson(
        '/market/removelisting/$listingId',
        {'sessionid': sid},
        cookies: communityCookies(account, sessionId: sid),
        referer: '${SteamApiClient.communityBase}/market/',
      );
      final ok = isCancelSuccess(json);
      dlog('removelisting $listingId -> success=$ok');
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Whether a `/market/removelisting/` response actually confirms the
  /// listing was removed. Steam's normal success reply has no body worth
  /// parsing — [SteamApiClient.communityPostJson] decodes an empty/bare-list
  /// body as `{}` — so an empty object (no failure markers) counts as
  /// success. An explicit `success: false`, or a needs-reauth marker, is a
  /// failure regardless of the lack of a thrown exception; any other
  /// explicit `success` value must equal `true`. Pure/static so it's
  /// unit-testable without a network stack.
  static bool isCancelSuccess(Map<String, dynamic> json) {
    if (json['needauth'] == true || json['needsauth'] == true) return false;
    if (!json.containsKey('success')) return true;
    return json['success'] == true;
  }
}
