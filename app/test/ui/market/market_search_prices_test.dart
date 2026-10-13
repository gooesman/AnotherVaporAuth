import 'dart:async';

import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/steam_request_scope.dart';
import 'package:ava/src/ui/market/item_market_actions.dart';
import 'package:ava/src/ui/market/market_search_prices.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Market extends MarketClient {
  _Market() : super(SteamApiClient());
  final calls = <(int, String, int)>[];
  final tokens = <CancelToken?>[];
  Future<MarketPrice?> Function(String, int)? onPrice;

  @override
  Future<MarketPrice?> priceOverviewChecked(
    int appid,
    String hash,
    int currency,
  ) {
    calls.add((appid, hash, currency));
    tokens.add(SteamRequestScope.currentCancelToken);
    return onPrice?.call(hash, currency) ??
        Future.value(
          MarketPrice(lowest: currency == 23 ? '¥ 15.36' : r'$2.16'),
        );
  }
}

MarketSearchPriceKey _key(String name, [int currency = 23]) =>
    (440, name, currency, 'english');

void main() {
  testWidgets('only visible rows read, serially with a one-second gap', (
    tester,
  ) async {
    final market = _Market();
    final first = Completer<MarketPrice?>();
    market.onPrice = (hash, _) =>
        hash == 'first' ? first.future : Future.value(null);
    final prices = MarketSearchPrices(
      ItemMarketPriceCache(market, checked: true),
    );
    addTearDown(prices.dispose);
    expect(market.calls, isEmpty);
    prices.visible('row1', _key('first'));
    prices.visible('row2', _key('second'));
    expect(market.calls, hasLength(1));
    first.complete(const MarketPrice(lowest: '¥ 15.36'));
    await tester.pump();
    expect(prices.quote(_key('first')).price!.lowest, '¥ 15.36');
    await tester.pump(const Duration(milliseconds: 999));
    expect(market.calls, hasLength(1));
    await tester.pump(const Duration(milliseconds: 2));
    expect(market.calls, hasLength(2));
  });

  testWidgets('a row scrolled away before its turn never fetches', (
    tester,
  ) async {
    final market = _Market();
    final prices = MarketSearchPrices(
      ItemMarketPriceCache(market, checked: true),
    );
    addTearDown(prices.dispose);
    prices.visible('row1', _key('first'));
    prices.visible('row2', _key('second'));
    await tester.pump();
    prices.visible('row2', null);
    await tester.pump(const Duration(seconds: 2));
    expect(market.calls, [(440, 'first', 23)]);
  });

  testWidgets(
    'multiple cached prices appear immediately without pacing or network',
    (tester) async {
      final market = _Market();
      final cache = ItemMarketPriceCache(market, checked: true);
      await cache.lookup(440, 'first', 23);
      await cache.lookup(440, 'second', 23);
      final prices = MarketSearchPrices(cache);
      addTearDown(prices.dispose);
      prices.visible('row1', _key('first'));
      prices.visible('row2', _key('second'));
      expect(prices.quote(_key('first')).price!.lowest, '¥ 15.36');
      expect(prices.quote(_key('second')).price!.lowest, '¥ 15.36');
      expect(market.calls, hasLength(2));
      prices.reset();
      prices.visible('row1', _key('first'));
      prices.visible('row2', _key('second'));
      expect(prices.quote(_key('second')).loading, isFalse);
      expect(market.calls, hasLength(2));
    },
  );

  testWidgets('429 pauses all rows; scrolling and reset do not hammer Steam', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 13);
    final market = _Market()
      ..onPrice = (_, _) => Future.error(
        SteamApiException(84, 'HTTP 429', 'price', httpStatus: 429),
      );
    final prices = MarketSearchPrices(
      ItemMarketPriceCache(market, checked: true),
      now: () => now,
    );
    addTearDown(prices.dispose);
    prices.visible('row1', _key('first'));
    prices.visible('row2', _key('second'));
    await tester.pump();
    expect(prices.quote(_key('second')).error, isA<SteamApiException>());
    prices.visible('row3', _key('third'));
    prices.reset();
    prices.visible('new-row', _key('fourth', 1));
    await tester.pump(const Duration(seconds: 10));
    expect(market.calls, hasLength(1));
    market.onPrice = null;
    prices.retry(_key('fourth', 1));
    now = now.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 31));
    expect(market.calls, [(440, 'first', 23), (440, 'fourth', 1)]);
    expect(prices.quote(_key('fourth', 1)).price!.lowest, r'$2.16');
  });

  testWidgets('cancelled old currency cannot publish or poison a new quote', (
    tester,
  ) async {
    final usd = Completer<MarketPrice?>();
    final cny = Completer<MarketPrice?>();
    final market = _Market()
      ..onPrice = (_, currency) => currency == 1 ? usd.future : cny.future;
    final cache = ItemMarketPriceCache(market, checked: true);
    final prices = MarketSearchPrices(cache);
    addTearDown(prices.dispose);
    prices.visible('row', _key('key', 1));
    prices.reset();
    prices.visible('row', _key('key', 23));
    expect(market.tokens.first!.isCancelled, isTrue);
    expect(market.calls, hasLength(2));
    usd.complete(const MarketPrice(lowest: r'$2.16'));
    cny.complete(const MarketPrice(lowest: '¥ 15.36'));
    await tester.pump();
    expect(cache.peek(440, 'key', 1), isNull);
    expect(prices.quote(_key('key', 23)).price!.lowest, '¥ 15.36');
  });

  testWidgets(
    'failed missing prices stay unavailable and explicit retry fetches again',
    (tester) async {
      final market = _Market()..onPrice = (_, _) async => null;
      final prices = MarketSearchPrices(
        ItemMarketPriceCache(market, checked: true),
      );
      addTearDown(prices.dispose);
      prices.visible('row', _key('key'));
      await tester.pump();
      expect(prices.quote(_key('key')).loading, isFalse);
      expect(prices.quote(_key('key')).price, isNull);
      prices.visible('row', null);
      prices.visible('row', _key('key'));
      expect(market.calls, hasLength(1));
      market.onPrice = null;
      prices.retry(_key('key'));
      await tester.pump(const Duration(seconds: 2));
      expect(market.calls, hasLength(2));
      expect(prices.quote(_key('key')).price!.lowest, '¥ 15.36');
    },
  );
}
