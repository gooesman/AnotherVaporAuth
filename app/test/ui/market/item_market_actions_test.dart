import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/ui/market/item_market_actions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Market extends MarketClient {
  _Market() : super(SteamApiClient());
  final calls = <(int, String, int)>[];
  MarketPrice? result = const MarketPrice(
    lowest: '¥ 1.23',
    median: '¥ 1.30',
    volume: 42,
  );
  Completer<MarketPrice?>? pending;
  bool fail = false;

  @override
  Future<MarketPrice?> priceOverview(int appid, String hashName, int currency) {
    calls.add((appid, hashName, currency));
    if (fail) throw StateError('network unavailable');
    return pending?.future ?? Future.value(result);
  }
}

InventoryItem _item({
  String hash = 'SCAR-20 | Contractor (Field-Tested)',
  bool marketable = true,
  int appid = 730,
}) => InventoryItem(
  appid: appid,
  contextId: '2',
  assetId: '1',
  classId: '2',
  instanceId: '0',
  amount: 1,
  marketHashName: hash,
  name: 'Test item',
  type: 'Consumer Grade',
  iconUrl: '',
  marketable: marketable,
  tradable: true,
);

Future<AppLocalizations> _show(
  WidgetTester tester,
  _Market market, {
  InventoryItem? item,
  int currency = 23,
  VoidCallback? onSelect,
  Future<bool> Function(Uri)? launch,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketClientProvider.overrideWithValue(market),
        itemMarketLauncherProvider.overrideWithValue(
          launch ?? (_) async => true,
        ),
      ],
      child: MaterialApp(
        theme: buildAvaTheme(AvaThemeVariant.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: ItemMarketActions(
                item: item ?? _item(),
                currency: currency,
                builder: (context, price, showActions) => ListTile(
                  key: const ValueKey('inventory-row'),
                  title: const Text('Test item'),
                  subtitle: price,
                  onTap: onSelect,
                  trailing: IconButton(
                    key: const ValueKey('overflow'),
                    onPressed: showActions,
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(ItemMarketActions)));
}

Future<void> _menu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('overflow')));
  await tester.pumpAndSettle();
}

Future<void> _price(WidgetTester tester) async {
  await _menu(tester);
  await tester.tap(find.byKey(const ValueKey('item-market-view-price')));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'concurrent identical lookups share a request and success expires after five minutes',
    () async {
      final market = _Market()..pending = Completer<MarketPrice?>();
      var now = DateTime.utc(2026, 10, 10);
      final cache = ItemMarketPriceCache(market, now: () => now);
      final first = cache.lookup(730, 'hash', 23);
      final second = cache.lookup(730, 'hash', 23);
      expect(identical(first, second), isTrue);
      expect(market.calls, [(730, 'hash', 23)]);
      market.pending!.complete(market.result);
      expect(await first, same(await second));
      market.pending = null;
      now = now.add(const Duration(minutes: 4, seconds: 59));
      await cache.lookup(730, 'hash', 23);
      expect(market.calls.length, 1);
      now = now.add(const Duration(seconds: 1));
      await cache.lookup(730, 'hash', 23);
      expect(market.calls.length, 2);
    },
  );

  test(
    'failures and empty prices cool down for thirty seconds, never invent zero',
    () async {
      final market = _Market()..fail = true;
      var now = DateTime.utc(2026, 10, 10);
      final cache = ItemMarketPriceCache(market, now: () => now);
      expect(await cache.lookup(730, 'hash', 23), isNull);
      await cache.lookup(730, 'hash', 23);
      expect(market.calls.length, 1);
      now = now.add(const Duration(seconds: 30));
      market.fail = false;
      market.result = const MarketPrice(lowest: ' ', median: '');
      await cache.lookup(730, 'hash', 23);
      expect(market.calls.length, 2);
      now = now.add(const Duration(seconds: 30));
      await cache.lookup(730, 'hash', 23);
      expect(market.calls.length, 3);
    },
  );

  test(
    'cache separates game, exact market name, currency and mutable Steam language',
    () async {
      final market = _Market();
      final cache = ItemMarketPriceCache(market);
      await cache.lookup(730, 'hash', 23);
      await cache.lookup(570, 'hash', 23);
      await cache.lookup(730, 'hash2', 23);
      await cache.lookup(730, 'hash', 1);
      market.api.steamLanguage = 'schinese';
      await cache.lookup(730, 'hash', 23);
      expect(market.calls.length, 5);
      await cache.lookup(0, 'hash', 23);
      await cache.lookup(730, ' ', 23);
      await cache.lookup(730, 'hash', 0);
      expect(market.calls.length, 5);
    },
  );

  test('listing URL encodes the exact hash name as one path segment', () {
    final hash = '★ StatTrak™ / #?%+ & A\\B';
    final uri = itemMarketListingUri(_item(hash: hash));
    expect(uri.scheme, 'https');
    expect(uri.host, 'steamcommunity.com');
    expect(uri.pathSegments, ['market', 'listings', '730', hash]);
    expect(uri.hasQuery, isFalse);
    expect(uri.hasFragment, isFalse);
    expect(uri.userInfo, isEmpty);
  });

  testWidgets(
    'no automatic request; overflow lookup shows correct reference and currency',
    (tester) async {
      final market = _Market();
      var selections = 0;
      final l = await _show(tester, market, onSelect: () => selections++);
      expect(market.calls, isEmpty);
      await _menu(tester);
      expect(market.calls, isEmpty);
      expect(selections, 0);
      await tester.tap(find.byKey(const ValueKey('item-market-view-price')));
      await tester.pumpAndSettle();
      expect(market.calls, [(730, _item().marketHashName, 23)]);
      expect(find.text(l.itemMarketCurrency('CNY')), findsOneWidget);
      expect(find.text('${l.marketLowest}: ¥ 1.23'), findsOneWidget);
      expect(find.text('${l.marketMedian}: ¥ 1.30'), findsOneWidget);
      expect(find.text('${l.itemMarketVolume}: 42'), findsOneWidget);
      expect(find.text(l.itemMarketReferenceNote), findsOneWidget);
      await tester.tap(find.text(l.commonClose));
      await tester.pumpAndSettle();
      expect(find.text('${l.marketLowest}: ¥ 1.23 · CNY'), findsOneWidget);
      expect(selections, 0);
      await tester.longPress(find.text('${l.marketLowest}: ¥ 1.23 · CNY'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('item-market-view-price')),
        findsOneWidget,
      );
      expect(selections, 0);
      expect(market.calls.length, 1);
    },
  );

  testWidgets(
    'right-click and long-press open actions without selecting; tap still selects',
    (tester) async {
      final market = _Market();
      var selections = 0;
      await _show(tester, market, onSelect: () => selections++);
      await tester.tap(find.text('Test item'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('item-market-view-price')),
        findsOneWidget,
      );
      expect(selections, 0);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Test item'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('item-market-view-price')),
        findsOneWidget,
      );
      expect(selections, 0);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test item'));
      expect(selections, 1);
      expect(market.calls, isEmpty);
    },
  );

  testWidgets('missing prices show unavailable rather than a fabricated zero', (
    tester,
  ) async {
    final market = _Market()..result = null;
    final l = await _show(tester, market);
    await _price(tester);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l.marketPriceUnavailable),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('0.00'), findsNothing);
    await tester.tap(find.text(l.commonClose));
    await tester.pumpAndSettle();
    expect(find.text(l.marketPriceUnavailable), findsOneWidget);
  });

  testWidgets(
    'temporary unmarketability does not prevent reference lookup; fallback says USD',
    (tester) async {
      final market = _Market();
      final l = await _show(
        tester,
        market,
        item: _item(marketable: false),
        currency: 0,
      );
      await _price(tester);
      expect(market.calls.single.$3, 1);
      expect(find.text(l.itemMarketCurrency('USD')), findsOneWidget);
    },
  );

  testWidgets(
    'missing hash disables actions and explains why without a request',
    (tester) async {
      final market = _Market();
      final l = await _show(tester, market, item: _item(hash: ' '));
      await _menu(tester);
      final action = tester.widget<PopupMenuItem>(
        find.byKey(const ValueKey('item-market-view-price')),
      );
      expect(action.enabled, isFalse);
      expect(find.text(l.itemMarketNoIdentity), findsOneWidget);
      expect(market.calls, isEmpty);
    },
  );

  testWidgets(
    'failed browser launch surfaces a message without fetching prices',
    (tester) async {
      final market = _Market();
      Uri? opened;
      final l = await _show(
        tester,
        market,
        launch: (uri) async {
          opened = uri;
          return false;
        },
      );
      await _menu(tester);
      await tester.tap(find.byKey(const ValueKey('item-market-open')));
      await tester.pumpAndSettle();
      expect(opened, itemMarketListingUri(_item()));
      expect(find.text(l.itemMarketOpenFailed), findsOneWidget);
      expect(market.calls, isEmpty);
    },
  );

  testWidgets(
    'late response cannot label a replacement item with the old item price',
    (tester) async {
      final market = _Market()..pending = Completer<MarketPrice?>();
      final l = await _show(tester, market);
      await _menu(tester);
      await tester.tap(find.byKey(const ValueKey('item-market-view-price')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text(l.commonClose));
      await tester.pumpAndSettle();
      await _show(tester, market, item: _item(hash: 'Replacement hash'));
      market.pending!.complete(market.result);
      await tester.pumpAndSettle();
      expect(find.textContaining('¥ 1.23'), findsNothing);
    },
  );
}
