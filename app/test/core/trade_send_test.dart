import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/models/trade_draft.dart';
import 'package:ava/src/core/protocol/community_session.dart';
import 'package:ava/src/core/protocol/trade_offers_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:ava/src/services/steam_network.dart';
import 'package:ava/src/services/steam_time.dart';

const _owner = '76561198000000001';
const _partner = '76561198000000002';
SteamGuardAccount _account() => SteamGuardAccount(
  session: SessionData(steamId: int.parse(_owner), accessToken: 'token'),
);
TradeSelection _selection(
  String owner, {
  String asset = '99999999999999999',
  bool tradable = true,
  int amount = 1,
}) => TradeSelection(
  ownerSteamId: owner,
  amount: amount,
  item: InventoryItem(
    appid: 730,
    contextId: '2',
    assetId: asset,
    classId: '100',
    instanceId: '0',
    amount: 3,
    marketHashName: 'test',
    name: 'Test item',
    type: '',
    iconUrl: '',
    marketable: true,
    tradable: tradable,
  ),
);
TradeDraft _draft() => TradeDraft(
  fromSteamId: _owner,
  partnerSteamId: _partner,
  give: [_selection(_owner, amount: 2)],
  receive: [_selection(_partner, asset: '20')],
  message: 'hello',
);

class _Api extends SteamApiClient {
  int posts = 0;
  String? path;
  Map<String, dynamic>? form;
  Map<String, String>? cookies;
  String? referer;
  Map<String, dynamic> reply = {'tradeofferid': '123'};
  Object? error;
  int gets = 0;
  List<Map<String, dynamic>> snapshots = [];
  Map<String, dynamic>? lastQuery;
  @override
  Future<Map<String, dynamic>> apiGetJson(
    String iface,
    String method,
    Map<String, dynamic> query, {
    String? accessToken,
    int version = 1,
  }) async {
    lastQuery = query;
    final index = gets++;
    return index < snapshots.length
        ? snapshots[index]
        : {
            'response': {'trade_offers_sent': <Object>[]},
          };
  }

  @override
  Future<Map<String, dynamic>> communityPostJson(
    String path,
    Map<String, dynamic> form, {
    Map<String, String>? cookies,
    String? referer,
  }) async {
    posts++;
    this.path = path;
    this.form = form;
    this.cookies = cookies;
    this.referer = referer;
    if (error != null) throw error!;
    return reply;
  }
}

/// Exercise the actual Dio status gate and community decoder offline.
class _SendAdapter implements HttpClientAdapter {
  final int status;
  final String body;
  int posts = 0;
  bool? followsRedirects;
  _SendAdapter(this.status, this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST') {
      posts++;
      followsRedirects = options.followRedirects;
      return ResponseBody.fromString(
        body,
        status,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(_snapshot([])),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'message without an ID or rejection marker cannot authorize a resend',
    () async {
      for (final reply in [
        {'success': true, 'message': 'Offer submitted'},
        {'message': 'Processing'},
      ]) {
        final api = _Api()..reply = reply;
        await expectLater(
          TradeOffersClient(api).send(_account(), _draft()),
          throwsA(isA<TradeSendUnconfirmed>()),
        );
        expect(api.posts, 1);
      }
    },
  );

  test(
    'real Dio 500 Steam rejection reaches the caller without a resend',
    () async {
      final adapter = _SendAdapter(
        500,
        '{"strError":"These items are no longer available for trade. (26)"}',
      );
      final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s < 500))
        ..httpClientAdapter = adapter;
      await expectLater(
        TradeOffersClient(SteamApiClient(dio: dio)).send(_account(), _draft()),
        throwsA(
          isA<SteamApiException>().having(
            (e) => e.message,
            'Steam reason',
            contains('no longer available'),
          ),
        ),
      );
      expect(adapter.posts, 1);
      expect(adapter.followsRedirects, isFalse);
    },
  );

  test('gateway HTML or opaque 5xx stays unknown with one POST', () async {
    final adapter = _SendAdapter(502, '<html>upstream timed out</html>');
    final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s < 500))
      ..httpClientAdapter = adapter;
    await expectLater(
      TradeOffersClient(SteamApiClient(dio: dio)).send(_account(), _draft()),
      throwsA(isA<TradeSendUnconfirmed>()),
    );
    expect(adapter.posts, 1);
    final api = _Api()
      ..error = SteamApiException(2, 'HTTP 500', 'send', httpStatus: 500);
    await expectLater(
      TradeOffersClient(api).send(_account(), _draft()),
      throwsA(isA<TradeSendUnconfirmed>()),
    );
    expect(api.posts, 1);
  });

  test(
    'receive-only draft cannot send after the account session changes',
    () async {
      final api = _Api();
      final account = _account()..session.steamId = 76561198000000003;
      final draft = TradeDraft(
        fromSteamId: _owner,
        partnerSteamId: _partner,
        give: [],
        receive: [_selection(_partner)],
      );
      await expectLater(
        TradeOffersClient(api).send(account, draft),
        throwsA(isA<TradeAccountMismatch>()),
      );
      expect(api.posts, 0);
    },
  );
  test(
    'send keeps both directions, exact asset IDs and amounts, matching csrf',
    () async {
      final api = _Api()
        ..reply = {'tradeofferid': '123', 'needs_mobile_confirmation': true};
      final result = await TradeOffersClient(api).send(_account(), _draft());
      expect(api.path, '/tradeoffer/new/send');
      expect(api.form!['partner'], _partner);
      expect(api.form!['sessionid'], api.cookies!['sessionid']);
      expect(api.cookies!['steamLoginSecure'], '$_owner||token');
      expect(
        api.referer,
        'https://steamcommunity.com/tradeoffer/new/?partner=39734274',
      );
      final body = jsonDecode(api.form!['json_tradeoffer']);
      expect(body['me']['assets'], [
        {
          'appid': 730,
          'contextid': '2',
          'assetid': '99999999999999999',
          'amount': 2,
        },
      ]);
      expect(body['them']['assets'][0]['assetid'], '20');
      expect(api.form!['tradeoffermessage'], 'hello');
      expect(result.offerId, '123');
      expect(result.needsMobileConfirmation, isTrue);
      expect(api.posts, 1);
    },
  );
  test('email confirmation is distinct from completion', () async {
    final api = _Api()
      ..reply = {'tradeofferid': '7', 'needs_email_confirmation': true};
    expect(
      (await TradeOffersClient(
        api,
      ).send(_account(), _draft())).needsEmailConfirmation,
      isTrue,
    );
  });
  test(
    'empty, marker-only, zero-id and explicit failure replies are not success',
    () async {
      for (final reply in <Map<String, dynamic>>[
        {},
        {'success': true},
        {'needs_mobile_confirmation': true},
        {'tradeofferid': '0'},
        {'tradeofferid': '12', 'success': false},
      ]) {
        final api = _Api()..reply = reply;
        await expectLater(
          TradeOffersClient(api).send(_account(), _draft()),
          throwsA(isA<TradeSendUnconfirmed>()),
        );
        expect(api.posts, 1);
      }
    },
  );
  test('needauth and server rejection preserve the failure reason', () async {
    final api = _Api()..reply = {'needsauth': true};
    await expectLater(
      TradeOffersClient(api).send(_account(), _draft()),
      throwsA(isA<CommunityAuthException>()),
    );
    api.reply = {'strError': 'Trade unavailable'};
    await expectLater(
      TradeOffersClient(api).send(_account(), _draft()),
      throwsA(
        isA<SteamApiException>().having(
          (e) => e.message,
          'message',
          'Trade unavailable',
        ),
      ),
    );
  });
  test('network failure is never retried', () async {
    final api = _Api()..error = Exception('connection lost');
    await expectLater(
      TradeOffersClient(api).send(_account(), _draft()),
      throwsException,
    );
    expect(api.posts, 1);
  });
  test(
    'missing access token and invalid partner cannot make HTTP calls',
    () async {
      final api = _Api();
      final noToken = _account()..session.accessToken = null;
      await expectLater(
        TradeOffersClient(api).send(noToken, _draft()),
        throwsA(isA<MissingAccessTokenException>()),
      );
      for (final partner in [_owner, '123', 'https://evil.example']) {
        await expectLater(
          TradeOffersClient(api).send(
            _account(),
            TradeDraft(
              fromSteamId: _owner,
              partnerSteamId: partner,
              give: [_selection(_owner)],
              receive: [],
            ),
          ),
          throwsArgumentError,
        );
      }
      expect(api.posts, 0);
    },
  );
  test(
    'swapped owners, duplicates, untradable items and invalid quantity rejected',
    () {
      for (final give in [
        [_selection(_partner)],
        [_selection(_owner), _selection(_owner)],
        [_selection(_owner, tradable: false)],
        [_selection(_owner, amount: 0)],
        [_selection(_owner, amount: 4)],
        [_selection(_owner, asset: 'not-a-number')],
      ]) {
        expect(
          () => TradeDraft(
            fromSteamId: _owner,
            partnerSteamId: _partner,
            give: give,
            receive: [],
          ).validate(_owner),
          throwsArgumentError,
        );
      }
      expect(
        () => TradeDraft(
          fromSteamId: _owner,
          partnerSteamId: _partner,
          give: [],
          receive: [_selection(_owner)],
        ).validate(_owner),
        throwsArgumentError,
      );
    },
  );
  test('gift or receive-only offers allowed, empty offers rejected', () {
    TradeDraft(
      fromSteamId: _owner,
      partnerSteamId: _partner,
      give: [_selection(_owner)],
      receive: [],
    ).validate(_owner);
    TradeDraft(
      fromSteamId: _owner,
      partnerSteamId: _partner,
      give: [],
      receive: [_selection(_partner)],
    ).validate(_owner);
    expect(
      () => TradeDraft(
        fromSteamId: _owner,
        partnerSteamId: _partner,
        give: [],
        receive: [],
      ).validate(_owner),
      throwsArgumentError,
    );
  });

  test('HTTP 500 Steam business rejection retains its diagnostic', () async {
    final request = RequestOptions(path: '/tradeoffer/new/send');
    final api = _Api()
      ..error = DioException.badResponse(
        statusCode: 500,
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 500,
          data: '{"strError":"Items are unavailable (26)"}',
        ),
      );
    await expectLater(
      TradeOffersClient(api).send(_account(), _draft()),
      throwsA(
        isA<SteamApiException>().having(
          (e) => e.message,
          'message',
          'Items are unavailable (26)',
        ),
      ),
    );
    expect(api.posts, 1);
    expect(api.gets, 1);
  });

  test(
    'definite failed flags and alternate messages are not unknown',
    () async {
      for (final reply in [
        {'success': false},
        {'success': '0'},
        {'success': 0, 'message': 'Trading is restricted'},
        {'error': 'Unavailable'},
        {'eresult': 26},
      ]) {
        final api = _Api()..reply = reply;
        await expectLater(
          TradeOffersClient(api).send(_account(), _draft()),
          throwsA(anyOf(isA<TradeSendRejected>(), isA<SteamApiException>())),
        );
        expect(api.posts, 1);
        expect(api.gets, 1);
      }
    },
  );

  test(
    'numeric and string mobile/email confirmation markers are kept',
    () async {
      final api = _Api()
        ..reply = {
          'tradeofferid': '123',
          'needs_mobile_confirmation': 1,
          'needs_email_confirmation': '1',
        };
      final result = await TradeOffersClient(api).send(_account(), _draft());
      expect(result.needsMobileConfirmation, isTrue);
      expect(result.needsEmailConfirmation, isTrue);
    },
  );

  test(
    'setup failure is not sent but transport timeouts stay unresolved',
    () async {
      final request = RequestOptions(path: '/tradeoffer/new/send');
      final api = _Api()
        ..error = DioException(
          requestOptions: request,
          error: const SteamConnectionSetupException(),
          type: DioExceptionType.connectionError,
        );
      await expectLater(
        TradeOffersClient(api).send(_account(), _draft()),
        throwsA(isA<TradeSendNotSent>()),
      );
      expect(api.gets, 1);
      for (final type in [
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        final api = _Api()
          ..error = DioException(requestOptions: request, type: type);
        await expectLater(
          TradeOffersClient(api).send(_account(), _draft()),
          throwsA(isA<TradeSendUnconfirmed>()),
        );
        expect(api.posts, 1);
        expect(api.gets, 2);
      }
    },
  );

  test(
    'missing POST receipt is recovered by a fresh exact pending offer',
    () async {
      final api = _Api()
        ..reply = {}
        ..snapshots = [
          _snapshot([]),
          _snapshot([_sentOffer('99', state: 9, confirmation: 2)]),
        ];
      final result = await TradeOffersClient(api).send(_account(), _draft());
      expect(result.offerId, '99');
      expect(result.needsMobileConfirmation, isTrue);
      expect(api.posts, 1);
      expect(api.lastQuery!['get_sent_offers'], '1');
      expect(api.lastQuery!['get_received_offers'], '0');
    },
  );

  test(
    'older identical, wrong direction or altered amounts cannot confirm send',
    () async {
      for (final offer in [
        _sentOffer('99')..['time_created'] = 1,
        _sentOffer('99')..['time_created'] = SteamTime.currentSteamTime + 3600,
        _sentOffer('99')..['is_our_offer'] = false,
        _sentOffer('99')..['accountid_other'] = 111,
        _sentOffer('99')..['message'] = 'different',
        _sentOffer('99')..['items_to_give'] = [_selection(_owner).toJson()],
        _sentOffer('99')..['items_to_receive'] = [],
      ]) {
        final api = _Api()
          ..reply = {}
          ..snapshots = [
            _snapshot([]),
            _snapshot([offer]),
          ];
        await expectLater(
          TradeOffersClient(api).send(_account(), _draft()),
          throwsA(isA<TradeSendUnconfirmed>()),
        );
        expect(api.posts, 1);
      }
    },
  );

  test(
    'existing identical offer and multiple new matches stay unresolved',
    () async {
      for (final snapshots in [
        [
          _snapshot([_sentOffer('99')]),
          _snapshot([_sentOffer('99')]),
        ],
        [
          _snapshot([]),
          _snapshot([_sentOffer('98'), _sentOffer('99')]),
        ],
      ]) {
        final api = _Api()
          ..reply = {}
          ..snapshots = snapshots;
        await expectLater(
          TradeOffersClient(api).send(_account(), _draft()),
          throwsA(isA<TradeSendUnconfirmed>()),
        );
        expect(api.posts, 1);
      }
    },
  );

  test(
    'incomplete baseline cannot mistake an existing offer for a new one',
    () async {
      final api = _Api()
        ..reply = {}
        ..snapshots = [
          _snapshot([], cursor: '123'),
          _snapshot([], cursor: '123'),
          _snapshot([_sentOffer('99')]),
        ];
      final client = TradeOffersClient(api);
      try {
        await client.send(_account(), _draft());
        fail('Expected unresolved result');
      } on TradeSendUnconfirmed catch (error) {
        expect(error.attempt!.previousOfferIds, isNull);
        expect(await client.recheckSend(_account(), error), isNull);
      }
      expect(api.posts, 1);
      expect(api.gets, 2);
    },
  );

  test('reconciliation reads every page before attributing an offer', () async {
    final api = _Api()
      ..reply = {}
      ..snapshots = [
        _snapshot([], cursor: '12'),
        _snapshot([_sentOffer('99')]),
        _snapshot([_sentOffer('99')], cursor: '13'),
        _snapshot([_sentOffer('100')]),
      ];
    final result = await TradeOffersClient(api).send(_account(), _draft());
    expect(result.offerId, '100');
    expect(api.posts, 1);
    expect(api.gets, 4);
  });

  test(
    'a later read-only check can find delayed creation without another POST',
    () async {
      final api = _Api()
        ..reply = {}
        ..snapshots = [
          _snapshot([]),
          _snapshot([]),
          _snapshot([_sentOffer('99')]),
        ];
      final client = TradeOffersClient(api);
      try {
        await client.send(_account(), _draft());
        fail('Expected unresolved result');
      } on TradeSendUnconfirmed catch (error) {
        expect((await client.recheckSend(_account(), error))!.offerId, '99');
      }
      expect(api.posts, 1);
    },
  );

  test(
    'pending offer with unknown confirmation method is not called sent',
    () async {
      final api = _Api()
        ..reply = {}
        ..snapshots = [
          _snapshot([]),
          _snapshot([_sentOffer('99', state: 9, confirmation: 0)]),
        ];
      await expectLater(
        TradeOffersClient(api).send(_account(), _draft()),
        throwsA(isA<TradeSendUnconfirmed>()),
      );
      expect(api.posts, 1);
    },
  );
}

Map<String, dynamic> _snapshot(
  List<Map<String, dynamic>> offers, {
  String cursor = '0',
}) => {
  'response': {'trade_offers_sent': offers, 'next_cursor': cursor},
};

Map<String, dynamic> _sentOffer(
  String id, {
  int state = 2,
  int confirmation = 0,
}) => {
  'tradeofferid': id,
  'is_our_offer': true,
  'accountid_other': 39734274,
  'message': 'hello',
  'time_created': SteamTime.currentSteamTime,
  'trade_offer_state': state,
  'confirmation_method': confirmation,
  'items_to_give': [_selection(_owner, amount: 2).toJson()],
  'items_to_receive': [_selection(_partner, asset: '20').toJson()],
};
