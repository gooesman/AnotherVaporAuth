import 'dart:convert';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/models/trade_draft.dart';
import 'package:ava/src/core/protocol/community_session.dart';
import 'package:ava/src/core/protocol/trade_offers_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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
}
