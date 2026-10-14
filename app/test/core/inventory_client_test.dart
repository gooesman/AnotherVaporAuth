import 'dart:convert';
import 'dart:io';
import 'package:ava/src/core/inventory_filter.dart';

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

Future<InventoryItem> _item(Map<String, dynamic> description) async {
  final api = _InventoryApi()
    ..json = {
      'success': 1,
      'assets': [
        {
          'appid': 730,
          'contextid': '2',
          'assetid': '123',
          'classid': '456',
          'instanceid': '0',
          'amount': '1',
        },
      ],
      'descriptions': [
        {'classid': '456', 'instanceid': '0', ...description},
      ],
    };
  return (await InventoryClient(api).items(_account(), 730, '2')).items.single;
}

void main() {
  test(
    'keeps Steam owner cooldown dates and strips presentation markup',
    () async {
      final item = await _item({
        'owner_descriptions': [
          {'type': 'html', 'value': ' '},
          {'type': 'html', 'value': '<b>可交易时间：</b>[date]1792393200[/date]'},
          {
            'type': 'html',
            'value': 'Tradable After Oct 19, 2026 (7:00:00) GMT',
          },
        ],
      });
      expect(item.restrictions, hasLength(2));
      expect(item.restrictions.first.text, '可交易时间：[date]1792393200[/date]');
      expect(item.restrictions.first.until, DateTime.utc(2026, 10, 19, 7));
      expect(item.restrictions.last.until, DateTime.utc(2026, 10, 19, 7));
    },
  );

  test('keeps unknown cooldown text without inventing unlock dates', () async {
    final item = await _item({
      'tradable': 0,
      'market_tradable_restriction': 7,
      'market_marketable_restriction': 7,
      'owner_descriptions': [
        null,
        {'value': 5},
        {'value': 'Tradable After Feb 30, 2026 (7:00:00) GMT'},
        {'value': '交易受限，结束时间未提供'},
        {'value': 'Trade ends [date]999999999999999999999[/date]'},
      ],
    });
    expect(item.restrictions, hasLength(3));
    expect(item.restrictions.every((note) => note.until == null), isTrue);
    final unavailable = await _item({'tradable': 0, 'marketable': 0});
    expect(unavailable.restrictions, isEmpty);
  });

  test('does not mistake an unzoned description date for UTC', () async {
    final item = await _item({
      'owner_descriptions': [
        {'value': 'Tradable After Oct 19, 2026 (7:00:00)'},
      ],
    });
    expect(item.restrictions.single.until, isNull);
  });

  test(
    'category fixtures retain genuine localized tags across CS2, Dota and Steam',
    () async {
      final cases =
          jsonDecode(
                File(
                  'test/fixtures/inventory_categories.json',
                ).readAsStringSync(),
              )
              as List;
      for (final fixture in cases) {
        final api = _InventoryApi()
          ..json = Map<String, dynamic>.from(fixture['response'] as Map);
        final page = await InventoryClient(
          api,
        ).items(_account(), fixture['appid'] as int, '2');
        final options = inventoryFacetOptions(
          page.items,
          InventoryFacet.type,
          unknownLabel: 'Other',
        );
        expect(options.length, page.items.length);
        expect(
          options.any((option) => option.key == inventoryUnknownFacet),
          isFalse,
        );
        if (fixture['appid'] == 730) {
          expect(
            options.map((option) => option.label),
            containsAll(['步枪', '喷漆', '音乐盒']),
          );
        } else if (fixture['appid'] == 570) {
          expect(options.single.label, 'Wearable');
        } else {
          expect(options.single.key, 'item_class/item_class_2');
        }
      }
    },
  );

  test(
    'classification ignores translated category names and malformed optional tags',
    () async {
      final item = await _item({
        'tags': [
          null,
          5,
          {
            'category': 'Weapon',
            'internal_name': 'x',
            'localized_category_name': 'Type',
            'localized_tag_name': 'Rifle',
          },
          {
            'category': 'Type',
            'internal_name': 5,
            'localized_tag_name': 'Rifle',
          },
          {
            'category': 'Type',
            'internal_name': '',
            'localized_tag_name': 'Rifle',
          },
        ],
      });
      expect(
        inventoryFacetKey(item, InventoryFacet.type),
        inventoryUnknownFacet,
      );
      expect(
        const InventoryFilter(type: inventoryUnknownFacet).matches(item),
        isTrue,
      );
    },
  );

  test(
    'duplicate tags use stable identifiers independent of display language',
    () async {
      final item = await _item({
        'tags': [
          {
            'category': 'Type',
            'internal_name': 'CSGO_Type_Spray',
            'localized_tag_name': '喷漆',
          },
          {
            'category': 'Type',
            'internal_name': 'CSGO_Type_Spray',
            'localized_tag_name': 'Graffiti',
          },
          {
            'category': 'Rarity',
            'internal_name': 'common',
            'localized_tag_name': '普通级',
          },
        ],
      });
      expect(item.tags.length, 2);
      expect(
        const InventoryFilter(
          type: 'type/CSGO_Type_Spray',
          rarity: 'rarity/common',
          query: '喷漆',
        ).matches(item),
        isTrue,
      );
      expect(
        const InventoryFilter(
          type: 'type/CSGO_Type_Spray',
          rarity: 'rarity/rare',
        ).matches(item),
        isFalse,
      );
    },
  );

  test(
    'unknown tags remain available and search does not guess their type',
    () async {
      final item = await _item({
        'name': 'Mystery Rifle',
        'market_hash_name': 'Future item',
        'type': 'Unclassified',
        'tags': [],
      });
      expect(
        const InventoryFilter(query: 'mystery FUTURE').matches(item),
        isTrue,
      );
      expect(
        const InventoryFilter(type: 'type/CSGO_Type_Rifle').matches(item),
        isFalse,
      );
      expect(
        const InventoryFilter(type: inventoryUnknownFacet).matches(item),
        isTrue,
      );
    },
  );

  test('missing localized type labels share one unclassified option', () async {
    final a = await _item({
      'tags': [
        {'category': 'Type', 'internal_name': 'missing_label'},
      ],
    });
    final b = await _item({'tags': []});
    final options = inventoryFacetOptions(
      [a, b],
      InventoryFacet.type,
      unknownLabel: 'Other',
    );
    expect(options.single.key, inventoryUnknownFacet);
    expect(
      const InventoryFilter(type: inventoryUnknownFacet).matches(a),
      isTrue,
    );
  });

  test(
    'rarity tag takes precedence over quality regardless of order',
    () async {
      final item = await _item({
        'name_color': 'ffffff',
        'tags': [
          {
            'category': 'Quality',
            'color': 'CF6A32',
            'localized_tag_name': 'StatTrak™',
          },
          {'category': 'Rarity', 'color': '8847FF', 'localized_tag_name': '受限'},
        ],
      });
      expect(item.rarityColor, '8847ff');
      expect(item.rarityName, '受限');
    },
  );

  test('missing rarity color falls back to valid quality metadata', () async {
    final item = await _item({
      'tags': [
        {'category': 'Rarity', 'localized_tag_name': 'Rare'},
        {
          'category': 'quality',
          'color': '#4B69FF',
          'localized_tag_name': ' Unique ',
        },
      ],
    });
    expect(item.rarityColor, '4b69ff');
    expect(item.rarityName, 'Unique');
  });

  test(
    'name color fallback does not invent a rarity from localized text',
    () async {
      final item = await _item({
        'name': 'StatTrak™ Knife',
        'type': 'Covert Knife',
        'name_color': 'eb4b4b',
        'tags': [
          {
            'category': 'Weapon',
            'color': '8847ff',
            'localized_category_name': 'Rarity',
            'localized_tag_name': 'Covert',
          },
        ],
      });
      expect(item.rarityColor, 'eb4b4b');
      expect(item.rarityName, isEmpty);
    },
  );

  test(
    'malformed optional tags and colors cannot break inventory loading',
    () async {
      for (final raw in [
        null,
        123,
        {},
        'not-a-list',
        <Object?>[null, 1],
      ]) {
        final item = await _item({'tags': raw, 'name_color': 'b0c3d9'});
        expect(item.rarityColor, 'b0c3d9');
        expect(item.rarityName, isEmpty);
      }
      for (final color in [null, 123, 'red', 'ffffff00', '#fff', 'xyzxyz']) {
        final item = await _item({
          'name_color': color,
          'tags': [
            {'category': 42, 'color': 'ff0000'},
            {'category': 'Rarity', 'color': color, 'localized_tag_name': {}},
          ],
        });
        expect(item.rarityColor, isEmpty);
        expect(item.rarityName, isEmpty);
      }
    },
  );

  test(
    'missing metadata remains neutral instead of assuming a CS2 rarity',
    () async {
      final item = await _item({'name': '军规级', 'type': 'Mil-Spec Grade'});
      expect(item.rarityColor, isEmpty);
      expect(item.rarityName, isEmpty);
    },
  );

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
