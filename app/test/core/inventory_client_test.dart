import 'dart:convert';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/protocol/inventory_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _InventoryApi extends SteamApiClient {
  String html = '';
  Map<String, dynamic> json = {'success': 1, 'assets': [], 'descriptions': []};
  String? requestedPath;
  Map<String, String>? requestedCookies;

  @override
  Future<String> communityGetText(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? cookies,
  }) async {
    requestedPath = path;
    requestedCookies = cookies;
    return html;
  }

  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async {
    requestedPath = path;
    requestedCookies = cookies;
    return json;
  }
}

SteamGuardAccount _account() => SteamGuardAccount(
  session: SessionData(steamId: 76561198000000123, accessToken: 'fake-token'),
);

String _page(Map<String, dynamic> apps, [Map<String, dynamic>? wallet]) =>
    'var g_rgAppContextData = ${jsonEncode(apps)};\n'
    'var g_rgWalletInfo = ${jsonEncode(wallet ?? {'success': false})};';

void main() {
  test(
    'same game retains distinct contexts and exposes Steam context names',
    () async {
      final api = _InventoryApi()
        ..html = _page({
          '730': {
            'name': 'Counter-Strike 2',
            'rgContexts': {
              '2': {'name': 'Backpack', 'asset_count': 24},
              '16': {'name': 'Trade Protected', 'asset_count': 4},
              '99': {'name': 'Empty', 'asset_count': 0},
            },
          },
        });
      final result = await InventoryClient(api).overview(_account());
      expect(result.games.map((g) => g.contextId), ['2', '16']);
      expect(result.games.map((g) => g.displayName), [
        'Counter-Strike 2 · Backpack',
        'Counter-Strike 2 · Trade Protected',
      ]);
      expect(result.games.map((g) => g.itemCount), [24, 4]);
    },
  );

  test(
    'duplicate context labels stay distinguishable without dropping items',
    () async {
      final api = _InventoryApi()
        ..html = _page({
          '730': {
            'name': 'Counter-Strike 2',
            'rgContexts': {
              '2': {'name': 'Items', 'asset_count': 24},
              '16': {'name': 'Items', 'asset_count': 4},
            },
          },
        });
      final result = await InventoryClient(api).overview(_account());
      expect(result.games.map((g) => g.displayName), [
        'Counter-Strike 2 · Items (2)',
        'Counter-Strike 2 · Items (16)',
      ]);
    },
  );

  test(
    'unnamed contexts use distinct IDs and single context keeps game name',
    () async {
      final api = _InventoryApi()
        ..html = _page({
          '730': {
            'name': 'CS2',
            'rgContexts': {
              '2': {'asset_count': 24},
              '16': {'asset_count': 4},
            },
          },
          '570': {
            'name': 'Dota 2',
            'rgContexts': {
              '2': {'name': 'Items', 'asset_count': 10},
            },
          },
        });
      final result = await InventoryClient(api).overview(_account());
      expect(result.games.map((g) => g.displayName), [
        'CS2 · 2',
        'Dota 2',
        'CS2 · 16',
      ]);
    },
  );

  test(
    'overview reports unavailable HTML instead of an empty inventory',
    () async {
      final api = _InventoryApi()..html = '<html>Unavailable</html>';
      await expectLater(
        InventoryClient(api).overview(_account()),
        throwsFormatException,
      );
    },
  );

  test(
    'wallet reads available and delayed integer balances from Steam page',
    () async {
      final api = _InventoryApi()
        ..html = _page({}, {
          'success': true,
          'wallet_currency': '23',
          'wallet_balance': '12345',
          'wallet_delayed_balance': 678,
          'wallet_fee_percent': '0.05',
          'wallet_publisher_fee_percent_default': '0.10',
          'wallet_market_minimum': '7',
          'wallet_currency_increment': '1',
        });
      final result = await InventoryClient(api).wallet(_account());
      expect(api.requestedPath, startsWith('/market/'));
      expect(result.currency, 23);
      expect(result.balance, 12345);
      expect(result.delayedBalance, 678);
      expect(result.steamFeePct, .05);
    },
  );

  test('unavailable wallet never becomes a zero balance', () async {
    final api = _InventoryApi()..html = _page({});
    final wallet = await InventoryClient(api).wallet(_account());
    expect(wallet.balance, isNull);
    expect(wallet.delayedBalance, isNull);
    expect(WalletInfo.fallback.balance, isNull);
    expect(WalletInfo.fromJson({'wallet_balance': '0'}).balance, 0);
  });

  test('missing wallet data is an error, never a fake empty wallet', () async {
    final api = _InventoryApi()..html = '<html>No wallet data</html>';
    await expectLater(
      InventoryClient(api).wallet(_account()),
      throwsFormatException,
    );
  });

  test('anonymous HTTP 200 wallet page triggers session renewal', () async {
    final api = _InventoryApi()..html = 'var g_bLoggedIn = false; ${_page({})}';
    await expectLater(
      InventoryClient(api).wallet(_account()),
      throwsA(isA<CommunityAuthException>()),
    );
  });

  test(
    'friend overview uses owner ID while retaining current login cookies',
    () async {
      final api = _InventoryApi()..html = _page({});
      await InventoryClient(
        api,
      ).overview(_account(), ownerSteamId: '76561198000000456');
      expect(
        api.requestedPath,
        contains('/profiles/76561198000000456/inventory/'),
      );
      expect(
        api.requestedCookies?['steamLoginSecure'],
        contains('76561198000000123'),
      );
    },
  );

  test(
    'friend items use owner ID and never replace the authenticated identity',
    () async {
      final api = _InventoryApi();
      await InventoryClient(
        api,
      ).items(_account(), 730, '2', ownerSteamId: '76561198000000456');
      expect(api.requestedPath, '/inventory/76561198000000456/730/2');
      expect(
        api.requestedCookies?['steamLoginSecure'],
        contains('76561198000000123'),
      );
    },
  );

  test('invalid owner ID cannot become a different request path', () async {
    final api = _InventoryApi();
    await expectLater(
      InventoryClient(
        api,
      ).items(_account(), 730, '2', ownerSteamId: '../market'),
      throwsArgumentError,
    );
    expect(api.requestedPath, isNull);
  });

  test('private or failed inventory is not misreported as empty', () async {
    final api = _InventoryApi()..json = {'success': 0, 'error': 'Private'};
    await expectLater(
      InventoryClient(api).items(_account(), 730, '2'),
      throwsFormatException,
    );
  });

  test('successful empty inventory stays empty', () async {
    final api = _InventoryApi();
    final result = await InventoryClient(api).items(_account(), 730, '2');
    expect(result.items, isEmpty);
    expect(result.more, isFalse);
  });
}
