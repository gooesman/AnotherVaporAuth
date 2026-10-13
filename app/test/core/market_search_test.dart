import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/steam_request_scope.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _SearchAdapter implements HttpClientAdapter {
  Object body;
  int status = 200;
  bool pending = false;
  final requests = <RequestOptions>[];
  final started = Completer<void>();
  final cancelled = Completer<void>();

  _SearchAdapter(this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (!started.isCompleted) started.complete();
    cancelFuture?.then((_) {
      if (!cancelled.isCompleted) cancelled.complete();
    });
    if (pending) {
      await cancelled.future;
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'search cancelled',
      );
    }
    return ResponseBody.fromString(
      body is String ? body as String : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(MarketClient, _SearchAdapter) _client(Object body) {
  final adapter = _SearchAdapter(body);
  final dio = Dio(
    BaseOptions(followRedirects: false, validateStatus: (s) => s! < 500),
  )..httpClientAdapter = adapter;
  final api = SteamApiClient(dio: dio)..steamLanguage = 'schinese';
  return (MarketClient(api), adapter);
}

// Synthetic protocol fixtures, not captured account data or a claim of a
// successful live response. The anonymous live probe was rate-limited (429).
Map<String, dynamic> _item({String hash = 'AK-47 | Redline (Field-Tested)'}) =>
    {
      'name': 'AK-47 | 红线 (久经沙场)',
      'hash_name': hash,
      'sell_listings': 235,
      'sell_price': 12345,
      'sell_price_text': '¥ 123.45',
      'asset_description': {
        'appid': 730,
        'market_hash_name': hash,
        'icon_url': 'Steam_image-Key123',
        'type': '保密级 步枪',
        'name_color': 'd2d2d2',
      },
    };

Map<String, dynamic> _page({
  int start = 0,
  int total = 41,
  int size = 20,
  List<dynamic>? items,
}) => {
  'success': true,
  'start': start,
  'pagesize': size,
  'total_count': total,
  'results': items ?? [_item()],
};

void main() {
  test(
    'price quotes send the chosen currency and preserve actual returned amounts',
    () async {
      final (client, adapter) = _client({
        'success': true,
        'lowest_price': '¥ 15.36',
      });
      final cny = await client.priceOverviewChecked(
        440,
        'Mann Co. Supply Crate Key',
        23,
      );
      expect(cny!.lowest, '¥ 15.36');
      expect(adapter.requests.single.uri.queryParameters['currency'], '23');
      adapter.body = {'success': true, 'lowest_price': r'$2.16'};
      final usd = await client.priceOverviewChecked(
        440,
        'Mann Co. Supply Crate Key',
        1,
      );
      expect(usd!.lowest, r'$2.16');
      expect(adapter.requests.last.uri.queryParameters['currency'], '1');
      expect(
        adapter.requests.every(
          (r) => r.uri.path == '/market/priceoverview/' && r.method == 'GET',
        ),
        isTrue,
      );
      expect(
        adapter.requests.every((r) => !r.headers.containsKey('Cookie')),
        isTrue,
      );
    },
  );

  test(
    'price HTTP 429 JSON without eresult remains a typed rate limit',
    () async {
      final (client, adapter) = _client({'success': false})..$2.status = 429;
      await expectLater(
        client.priceOverviewChecked(440, 'key', 23),
        throwsA(
          isA<SteamApiException>()
              .having((e) => e.httpStatus, 'status', 429)
              .having((e) => e.eresult, 'eresult', 84),
        ),
      );
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'anonymous search sends locale/currency and no cookie, one read only',
    () async {
      final (client, adapter) = _client(_page());
      final page = await client.search(
        query: ' 红线 & Blue ',
        appid: 730,
        currency: 23,
        count: 200,
      );
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.host, 'steamcommunity.com');
      expect(request.uri.path, '/market/search/render/');
      expect(request.uri.queryParameters, {
        'query': '红线 & Blue',
        'appid': '730',
        'start': '0',
        'count': '20',
        'search_descriptions': '0',
        'sort_column': 'popular',
        'sort_dir': 'desc',
        'norender': '1',
        'currency': '23',
        'l': 'schinese',
      });
      expect(
        request.headers.keys.map((e) => e.toLowerCase()),
        isNot(contains('cookie')),
      );
      final item = page.items.single;
      expect(item.appid, 730);
      expect(item.name, 'AK-47 | 红线 (久经沙场)');
      expect(item.marketHashName, 'AK-47 | Redline (Field-Tested)');
      expect(item.lowestPriceMinor, 12345);
      expect(item.priceText, '¥ 123.45');
      expect(item.listingCount, 235);
      expect(item.type, '保密级 步枪');
      expect(item.rarityColor, 'd2d2d2');
      expect(
        item.iconUrl,
        'https://community.fastly.steamstatic.com/economy/image/Steam_image-Key123/128fx128f',
      );
      expect(page.nextStart, 20);
      expect(page.hasMore, isTrue);
      expect(() => page.items.clear(), throwsUnsupportedError);
    },
  );

  test(
    'integer success/string counts and final partial page are supported',
    () async {
      final (client, adapter) = _client({
        ..._page(start: 40),
        'success': 1,
        'start': '40',
        'pagesize': '20',
        'total_count': '41',
      });
      final page = await client.search(query: '', currency: 1, start: 40);
      expect(page.hasMore, isFalse);
      expect(page.nextStart, 60);
      expect(adapter.requests.single.queryParameters, isNot(contains('appid')));
    },
  );

  test(
    'an empty result and a changing total cannot keep pagination alive',
    () async {
      for (final total in [0, 41]) {
        final (client, _) = _client(_page(total: total, items: []));
        final page = await client.search(query: 'missing', currency: 1);
        expect(page.items, isEmpty);
        expect(page.hasMore, isFalse);
      }
    },
  );

  test(
    'no listings or absent price never becomes a fake zero quotation',
    () async {
      final noListings = _item()..['sell_listings'] = 0;
      final missingPrice = _item()
        ..remove('sell_price')
        ..remove('sell_price_text');
      final (client, _) = _client(_page(items: [noListings, missingPrice]));
      final page = await client.search(query: '', currency: 1);
      for (final item in page.items) {
        expect(item.lowestPriceMinor, isNull);
        expect(item.priceText, isNull);
      }
    },
  );

  test(
    'untrusted icon URLs and invalid color cannot escape the Steam image host',
    () async {
      for (final icon in [
        'https://other.invalid/a',
        '//other.invalid/a',
        '../secret',
        'key?token=test',
        'key%2F..',
        '',
      ]) {
        final item = _item();
        (item['asset_description'] as Map)['icon_url'] = icon;
        (item['asset_description'] as Map)['name_color'] = 'red';
        final (client, _) = _client(_page(items: [item]));
        final page = await client.search(query: '', currency: 1);
        expect(page.items.single.iconUrl, isEmpty);
        expect(page.items.single.rarityColor, isEmpty);
      }
    },
  );

  test(
    'failure or non-boolean/non-integer success cannot become empty success',
    () async {
      for (final success in [false, 0, '1', 1.0, null]) {
        final (client, _) = _client({..._page(items: []), 'success': success});
        await expectLater(
          client.search(query: '', currency: 1),
          throwsA(isA<SteamApiException>()),
        );
      }
    },
  );

  test(
    'invalid page metadata and rows are rejected instead of coercing counts',
    () async {
      for (final changes in <Map<String, dynamic>>[
        {'start': 20},
        {'pagesize': 21},
        {'pagesize': -1},
        {'total_count': -1},
        {'total_count': 1.5},
        {'total_count': true},
        {'total_count': 0x80000000},
        {'results': {}},
        {
          'results': [null],
        },
        {'pagesize': 0},
      ]) {
        final (client, _) = _client({..._page(), ...changes});
        await expectLater(
          client.search(query: '', currency: 1),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'invalid item identity and fractional/negative prices are rejected',
    () async {
      final cases = <Map<String, dynamic>>[
        _item()..['asset_description'] = null,
        _item()..['sell_price'] = -1,
        _item()..['sell_price'] = 123.45,
        _item()..['sell_listings'] = true,
      ];
      for (final changes in [
        {'appid': 0},
        {'appid': 'not-an-id'},
        {'market_hash_name': ''},
        {'market_hash_name': 'name\u0000'},
      ]) {
        final item = _item();
        (item['asset_description'] as Map).addAll(changes);
        cases.add(item);
      }
      for (final item in cases) {
        final (client, _) = _client(_page(items: [item]));
        await expectLater(
          client.search(query: '', currency: 1),
          throwsFormatException,
        );
      }
    },
  );

  test('429 and invalid JSON propagate as failures without retry', () async {
    for (final body in [
      'Too Many Requests',
      {'success': false},
    ]) {
      final (client, adapter) = _client(body)..$2.status = 429;
      await expectLater(
        client.search(query: '', currency: 1),
        throwsA(isA<SteamApiException>()),
      );
      expect(adapter.requests, hasLength(1));
    }
    final (client, _) = _client('<html>network interstitial</html>');
    await expectLater(
      client.search(query: '', currency: 1),
      throwsFormatException,
    );
  });

  test(
    'HTTP 429 stays rate limited even if its JSON diagnostics omit eresult',
    () async {
      for (final code in [84, '84', 2, 'RateLimitExceeded', null]) {
        final (client, adapter) = _client({
          'success': false,
          'eresult': code,
          'message': 'rate limited',
        })..$2.status = 429;
        await expectLater(
          client.search(query: '', currency: 1),
          throwsA(
            isA<SteamApiException>().having(
              (error) => error.eresult,
              'eresult',
              84,
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test('invalid caller arguments fail before any network request', () async {
    final (client, adapter) = _client(_page());
    for (final call in <Future<dynamic> Function()>[
      () => client.search(query: '', currency: 0),
      () => client.search(query: '', currency: 1, appid: -1),
      () => client.search(query: '', currency: 1, start: -1),
      () => client.search(query: '', currency: 1, count: 0),
      () => client.search(query: 'query\n', currency: 1),
    ]) {
      await expectLater(call(), throwsArgumentError);
    }
    expect(adapter.requests, isEmpty);
  });

  test(
    'caller cancellation reaches the real API transport and never retries',
    () async {
      final (client, adapter) = _client(_page())..$2.pending = true;
      final scope = SteamRequestScope();
      final result = scope.run(() => client.search(query: '', currency: 1));
      final check = expectLater(result, throwsA(isA<DioException>()));
      await adapter.started.future;
      scope.cancel();
      await check;
      await adapter.cancelled.future.timeout(const Duration(seconds: 1));
      expect(adapter.requests, hasLength(1));
    },
  );

  test('whole-operation deadline closes a pending search transport', () async {
    final (client, adapter) = _client(_page())..$2.pending = true;
    final scope = SteamRequestScope(timeout: const Duration(milliseconds: 25));
    await expectLater(
      scope.run(() => client.search(query: '', currency: 1)),
      throwsA(isA<TimeoutException>()),
    );
    await adapter.cancelled.future.timeout(const Duration(seconds: 1));
    expect(adapter.requests, hasLength(1));
  });
}
