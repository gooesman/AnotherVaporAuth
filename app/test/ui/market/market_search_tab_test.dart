import 'dart:async';
import 'dart:io';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/screen_corners.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/market_search.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/steam_request_scope.dart';
import 'package:ava/src/ui/market/item_market_actions.dart';
import 'package:ava/src/ui/market/market_search_tab.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Request = ({String query, int? appid, int currency, int start});

MarketSearchItem _item(
  String name, {
  int? price = 123,
  String? priceText = r'$1.23',
}) => MarketSearchItem(
  appid: 730,
  marketHashName: name,
  name: name,
  iconUrl: '',
  type: 'Rifle',
  rarityColor: '8847ff',
  lowestPriceMinor: price,
  priceText: priceText,
  listingCount: 12,
);

MarketSearchPage _page(String name, {int start = 0, int total = 1}) =>
    MarketSearchPage(
      items: [_item(name)],
      start: start,
      pageSize: 20,
      total: total,
    );

class _Market extends MarketClient {
  _Market() : super(SteamApiClient());
  final requests = <_Request>[];
  final tokens = <CancelToken?>[];
  final prices = <(int, String, int)>[];
  final priceTokens = <CancelToken?>[];
  Future<MarketSearchPage> Function(_Request)? onSearch;
  Completer<MarketPrice?>? pricePending;
  Future<MarketPrice?> Function(String, int)? onPrice;

  @override
  Future<MarketSearchPage> search({
    required String query,
    int? appid,
    required int currency,
    int start = 0,
    int count = 20,
  }) {
    expect(count, 20);
    final request = (
      query: query,
      appid: appid,
      currency: currency,
      start: start,
    );
    requests.add(request);
    tokens.add(SteamRequestScope.currentCancelToken);
    return onSearch?.call(request) ?? Future.value(_page(query));
  }

  @override
  Future<MarketPrice?> priceOverview(int appid, String hash, int currency) {
    prices.add((appid, hash, currency));
    priceTokens.add(SteamRequestScope.currentCancelToken);
    return onPrice?.call(hash, currency) ??
        pricePending?.future ??
        Future.value(
          MarketPrice(
            lowest: currency == 23 ? '¥ 8.76' : r'$1.23',
            median: currency == 23 ? '¥ 8.80' : r'$1.24',
            volume: 5,
          ),
        );
  }

  @override
  Future<MarketPrice?> priceOverviewChecked(
    int appid,
    String hash,
    int currency,
  ) => priceOverview(appid, hash, currency);
}

SteamGuardAccount _account({int id = 123, bool portable = false}) =>
    SteamGuardAccount(
      accountName: 'Tester',
      session: SessionData(steamId: id, accessToken: 'synthetic-$id'),
    )..fromPortable = portable;

class _Harness {
  _Harness(this.tester, this.market);
  final WidgetTester tester;
  _Market market;
  SteamGuardAccount account = _account();
  DateTime now = DateTime(2026, 10, 12);
  bool active = true;
  int reload = 0;
  int? initialCurrency;
  Locale locale = const Locale('en');
  AvaThemeVariant variant = AvaThemeVariant.light;
  double textScale = 1;
  final opened = <Uri>[];

  Future<void> show({bool settle = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketClientProvider.overrideWithValue(market),
          clockProvider.overrideWithValue(() => now),
          itemMarketLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAvaTheme(variant),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: ScreenCorners(bottom: 32, child: child!),
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Market')),
            body: MarketSearchTab(
              account: account,
              active: active,
              reload: reload,
              initialCurrency: initialCurrency,
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  AppLocalizations get l =>
      AppLocalizations.of(tester.element(find.byType(MarketSearchTab)));

  Future<void> submit(String text, {bool settle = true}) async {
    await tester.ensureVisible(
      find.byKey(const ValueKey('market-search-query')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('market-search-query')),
      text,
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> chooseCurrency(int current, String code) async {
    final field = find.byKey(const ValueKey('market-search-currency'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(code),
      -250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(code).last);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'currency changes requote the visible list, discard late dollars, and reuse CNY cache',
    (tester) async {
      final oldUsd = Completer<MarketPrice?>();
      var firstUsd = true;
      final market = _Market()
        ..onPrice = (_, currency) {
          if (currency == 1 && firstUsd) {
            firstUsd = false;
            return oldUsd.future;
          }
          return Future.value(
            MarketPrice(lowest: currency == 23 ? '¥ 15.36' : r'$2.16'),
          );
        };
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('key', settle: false);
      await tester.pump();
      final dropdown = tester.widget<DropdownButtonFormField<int>>(
        find.byKey(const ValueKey('market-search-currency')),
      );
      dropdown.onChanged!(23);
      await tester.pumpAndSettle();
      expect(market.priceTokens.first!.isCancelled, isTrue);
      expect(find.text('¥ 15.36'), findsOneWidget);
      expect(find.text(r'$1.23'), findsNothing);
      oldUsd.complete(const MarketPrice(lowest: r'$999.99'));
      await tester.pumpAndSettle();
      expect(find.text(r'$999.99'), findsNothing);
      dropdown.onChanged!(1);
      await tester.pumpAndSettle();
      expect(find.text(r'$2.16'), findsOneWidget);
      dropdown.onChanged!(23);
      await tester.pump();
      expect(find.text('¥ 15.36'), findsOneWidget);
      expect(market.prices, [
        (730, 'key', 1),
        (730, 'key', 23),
        (730, 'key', 1),
      ]);
      expect(market.requests, hasLength(1));
    },
  );

  testWidgets(
    'returning from background uses visible cached prices without another request',
    (tester) async {
      final market = _Market();
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('key');
      expect(market.prices, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(r'$1.23'), findsOneWidget);
      expect(market.prices, hasLength(1));
      expect(market.requests, hasLength(1));
    },
  );

  testWidgets(
    'CNY uses a separate true quote and never displays unverified search dollars',
    (tester) async {
      final market = _Market()
        ..onSearch = ((_) async => MarketSearchPage(
          items: [
            _item('quoted', priceText: r'$1.23'),
            _item('unknown units', priceText: null),
          ],
          start: 0,
          pageSize: 20,
          total: 2,
        ))
        ..onPrice = (hash, currency) async => hash == 'unknown units'
            ? null
            : const MarketPrice(lowest: '¥ 8.76');
      final h = _Harness(tester, market)..initialCurrency = 23;
      await h.show();
      await h.submit('price');
      expect(market.requests.single.currency, 23);
      expect(find.text(r'$1.23'), findsNothing);
      expect(find.text('¥ 8.76'), findsOneWidget);
      expect(find.text('CNY 1.23'), findsNothing);
      expect(find.text(h.l.marketSearchPriceUnavailable), findsOneWidget);
    },
  );

  testWidgets(
    'in-place token change while pending cannot strand loading without a parent rebuild',
    (tester) async {
      final pending = Completer<MarketSearchPage>();
      final market = _Market()..onSearch = (_) => pending.future;
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('old session', settle: false);
      h.account.session.accessToken = 'changed-in-place';
      pending.complete(_page('old account result'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('market-search-loading')), findsNothing);
      expect(find.text('old account result'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('market-search-submit')),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'changing currency cancels a pending page without querying new currency',
    (tester) async {
      final pending = Completer<MarketSearchPage>();
      final market = _Market()..onSearch = (_) => pending.future;
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('currency', settle: false);
      final dropdown = tester.widget<DropdownButtonFormField<int>>(
        find.byKey(const ValueKey('market-search-currency')),
      );
      dropdown.onChanged!(23);
      await tester.pumpAndSettle();
      expect(market.tokens.single!.isCancelled, isTrue);
      expect(market.requests, hasLength(1));
      pending.complete(_page('old currency'));
      await tester.pumpAndSettle();
      expect(find.text('old currency'), findsNothing);
    },
  );

  testWidgets('replacing market client invalidates cached results', (
    tester,
  ) async {
    final market = _Market();
    final h = _Harness(tester, market);
    await h.show();
    await h.submit('cached');
    h.market = _Market();
    await h.show();
    expect(find.text(r'$1.23'), findsNothing);
    expect(h.market.requests, isEmpty);
    await h.submit('cached');
    expect(h.market.requests, hasLength(1));
    expect(market.requests, hasLength(1));
  });

  testWidgets(
    'backgrounding cancels pending requests and resume makes no request',
    (tester) async {
      final pending = Completer<MarketSearchPage>();
      final market = _Market()..onSearch = (_) => pending.future;
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('background', settle: false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(market.tokens.single!.isCancelled, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(market.requests, hasLength(1));
      pending.complete(_page('hidden result'));
      await tester.pumpAndSettle();
      expect(find.text('hidden result'), findsNothing);
    },
  );

  testWidgets(
    'desktop result rows are lazy and load more does not run automatically',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final market = _Market()
        ..onSearch = (_) async => MarketSearchPage(
          items: List.generate(20, (index) => _item('result $index')),
          start: 0,
          pageSize: 20,
          total: 40,
        );
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('many');
      expect(find.byType(ListTile).evaluate().length, lessThan(20));
      expect(find.text('result 19'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('result 19'),
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('market-search-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('result 19'), findsOneWidget);
      expect(market.requests, hasLength(1));
      expect(market.prices.length, greaterThan(0));
      expect(market.prices.length, lessThan(20));
    },
  );

  testWidgets(
    'mount, input, game/currency changes and empty submit make no requests',
    (tester) async {
      final market = _Market();
      final h = _Harness(tester, market)..locale = const Locale('zh');
      await h.show();
      expect(find.text('CNY'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('market-search-query')),
        'ak',
      );
      await tester.tap(find.byKey(const ValueKey('market-search-game')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dota 2').last);
      await tester.pumpAndSettle();
      await h.chooseCurrency(23, 'USD');
      await h.submit('  ');
      h.reload++;
      await h.show();
      expect(market.requests, isEmpty);
      expect(market.prices, isEmpty);
    },
  );

  testWidgets(
    'submitted query is trimmed and visible prices use the selected currency',
    (tester) async {
      final market = _Market();
      final h = _Harness(tester, market)..initialCurrency = 23;
      await h.show();
      await h.submit('  AK-47  ');
      expect(market.requests.single, (
        query: 'AK-47',
        appid: null,
        currency: 23,
        start: 0,
      ));
      expect(find.text('¥ 8.76'), findsOneWidget);
      expect(find.text(r'$1.23'), findsNothing);
      expect(find.text(h.l.marketSearchListings(12)), findsOneWidget);
      expect(market.prices.single, (730, 'AK-47', 23));
      expect(market.tokens.single, isNotNull);
      h.initialCurrency = 1;
      await h.show();
      expect(find.text('CNY'), findsOneWidget);
    },
  );

  testWidgets('default currency is explicit USD outside Chinese locales', (
    tester,
  ) async {
    final h = _Harness(tester, _Market())..initialCurrency = -1;
    await h.show();
    expect(find.text('USD'), findsOneWidget);
    await h.submit('item');
    expect(h.market.requests.single.currency, 1);
  });

  testWidgets(
    'same in-flight submission is not duplicated; query changes cancel old read',
    (tester) async {
      final pending = Completer<MarketSearchPage>();
      final market = _Market()
        ..onSearch = (request) => request.query == 'old'
            ? pending.future
            : Future.value(_page('new item'));
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('old', settle: false);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(market.requests, hasLength(1));
      await h.submit('new');
      expect(market.tokens.first!.isCancelled, isTrue);
      pending.complete(_page('old item'));
      await tester.pumpAndSettle();
      expect(find.text('new item'), findsOneWidget);
      expect(find.text('old item'), findsNothing);
    },
  );

  testWidgets('leaving tab cancels pending HTTP; returning never auto-loads', (
    tester,
  ) async {
    final pending = Completer<MarketSearchPage>();
    final market = _Market()..onSearch = (_) => pending.future;
    final h = _Harness(tester, market);
    await h.show();
    await h.submit('pending', settle: false);
    h.active = false;
    await h.show();
    expect(market.tokens.single!.isCancelled, isTrue);
    h.active = true;
    await h.show();
    expect(market.requests, hasLength(1));
    expect(find.text(h.l.commonRetry), findsOneWidget);
    pending.complete(_page('stale'));
    await tester.pumpAndSettle();
    expect(find.text('stale'), findsNothing);
  });

  testWidgets('request deadline cancels token and leaves retry usable', (
    tester,
  ) async {
    final pending = Completer<MarketSearchPage>();
    final market = _Market()..onSearch = (_) => pending.future;
    final h = _Harness(tester, market);
    await h.show();
    await h.submit('slow', settle: false);
    await tester.pump(const Duration(seconds: 13));
    await tester.pumpAndSettle();
    expect(market.tokens.single!.isCancelled, isTrue);
    expect(find.text(h.l.netErrTimeout), findsOneWidget);
    expect(find.text(h.l.commonRetry), findsOneWidget);
    pending.complete(_page('too late'));
    await tester.pumpAndSettle();
    expect(find.text('too late'), findsNothing);
  });

  testWidgets(
    'account source and in-place session rotation cancel and clear old results',
    (tester) async {
      final market = _Market();
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('same query');
      h.account = _account(portable: true);
      await h.show();
      expect(find.text(r'$1.23'), findsNothing);
      await h.submit('same query');
      expect(market.requests, hasLength(2));
      h.account.session.accessToken = 'rotated';
      await h.show();
      expect(find.text(r'$1.23'), findsNothing);
      await h.submit('same query');
      expect(market.requests, hasLength(3));
    },
  );

  testWidgets(
    'language change cancels pending read and does not refetch automatically',
    (tester) async {
      final pending = Completer<MarketSearchPage>();
      final market = _Market()..onSearch = (_) => pending.future;
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('old language', settle: false);
      market.api.steamLanguage = 'schinese';
      h.locale = const Locale('zh');
      await h.show();
      expect(market.tokens.single!.isCancelled, isTrue);
      expect(market.requests, hasLength(1));
      pending.complete(_page('old language item'));
      await tester.pumpAndSettle();
      expect(find.text('old language item'), findsNothing);
    },
  );

  testWidgets(
    'successful pages reuse a bounded five-minute cache; explicit refresh bypasses',
    (tester) async {
      final market = _Market();
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('cached');
      await h.submit('cached');
      expect(market.requests, hasLength(1));
      h.active = false;
      await h.show();
      h.active = true;
      await h.show();
      expect(find.text(r'$1.23'), findsOneWidget);
      expect(market.requests, hasLength(1));
      h.reload++;
      await h.show();
      expect(market.requests, hasLength(2));
      h.now = h.now.add(const Duration(minutes: 6));
      await h.submit('cached');
      expect(market.requests, hasLength(3));
      for (var i = 0; i < 12; i++) {
        await h.submit('item $i');
      }
      await h.submit('cached');
      expect(market.requests, hasLength(16));
    },
  );

  testWidgets(
    'failed search is not cached; 429 shows rate limit instead of no results',
    (tester) async {
      final market = _Market()
        ..onSearch = (_) => Future.error(
          SteamApiException(84, 'limit', 'search', httpStatus: 429),
        );
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('retry me');
      expect(find.text(h.l.marketSearchRateLimited), findsOneWidget);
      expect(find.text(h.l.marketSearchNoResults), findsNothing);
      market.onSearch = (_) async => _page('found');
      await h.submit('retry me');
      expect(market.requests, hasLength(2));
      expect(find.text('found'), findsOneWidget);
    },
  );

  testWidgets(
    'explicit pagination retains previous results on failure and retries only that page',
    (tester) async {
      var failSecond = true;
      final market = _Market()
        ..onSearch = (request) async {
          if (request.start == 0) return _page('first', total: 40);
          if (failSecond) throw const SocketException('offline');
          return _page('second', start: 20, total: 40);
        };
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('paged');
      expect(market.requests, hasLength(1));
      await tester.ensureVisible(
        find.byKey(const ValueKey('market-search-more')),
      );
      await tester.tap(find.byKey(const ValueKey('market-search-more')));
      await tester.pumpAndSettle();
      expect(find.text('first'), findsOneWidget);
      expect(find.text(h.l.commonRetry), findsOneWidget);
      failSecond = false;
      await tester.tap(find.byKey(const ValueKey('market-search-more')));
      await tester.pumpAndSettle();
      expect(market.requests.map((request) => request.start), [0, 20, 20]);
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
      expect(find.byKey(const ValueKey('market-search-more')), findsNothing);
    },
  );

  testWidgets(
    'detail automatically loads selected-currency lowest price when the row quote is pending',
    (tester) async {
      final oldQuote = Completer<MarketPrice?>();
      var reads = 0;
      final market = _Market()
        ..onPrice = (_, currency) {
          expect(currency, 23);
          return ++reads == 1
              ? oldQuote.future
              : Future.value(
                  const MarketPrice(lowest: '¥ 15.36', median: '¥ 15.20'),
                );
        };
      final h = _Harness(tester, market)..initialCurrency = 23;
      await h.show();
      await h.submit('key', settle: false);
      await tester.pump();
      expect(market.prices, hasLength(1));
      await tester.tap(find.text('key').last);
      await tester.pumpAndSettle();
      expect(market.priceTokens.first!.isCancelled, isTrue);
      expect(market.prices, [(730, 'key', 23), (730, 'key', 23)]);
      expect(find.text('${h.l.marketLowest}: ¥ 15.36'), findsOneWidget);
      expect(find.text('${h.l.marketMedian}: ¥ 15.20'), findsOneWidget);
      expect(find.text(r'$1.23'), findsNothing);
      oldQuote.complete(const MarketPrice(lowest: r'$999.99'));
      await tester.pumpAndSettle();
      expect(find.text(r'$999.99'), findsNothing);
      expect(find.text('${h.l.marketLowest}: ¥ 15.36'), findsOneWidget);
    },
  );

  testWidgets(
    'median-only quote is never substituted for the list lowest price',
    (tester) async {
      final market = _Market()
        ..onPrice = (_, _) async => const MarketPrice(median: '¥ 15.20');
      final h = _Harness(tester, market)..initialCurrency = 23;
      await h.show();
      await h.submit('median-only');
      expect(find.text(h.l.marketSearchPriceUnavailable), findsOneWidget);
      expect(find.text('¥ 15.20'), findsNothing);
      expect(find.text(r'$1.23'), findsNothing);
      await tester.tap(find.text('median-only').last);
      await tester.pumpAndSettle();
      expect(find.text('${h.l.marketMedian}: ¥ 15.20'), findsOneWidget);
      expect(find.text('${h.l.marketLowest}: ¥ 15.20'), findsNothing);
      expect(market.prices, hasLength(1));
    },
  );

  testWidgets(
    'detail opens without new requests, refreshes one price, and encodes official URL',
    (tester) async {
      const name = 'Rare / # ? % item';
      final market = _Market();
      final h = _Harness(tester, market);
      await h.show();
      await h.submit(name);
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('market-search-details')),
        findsOneWidget,
      );
      expect(market.prices, hasLength(1));
      await tester.tap(
        find.byKey(const ValueKey('market-search-refresh-price')),
      );
      await tester.pumpAndSettle();
      expect(market.prices, [(730, name, 1), (730, name, 1)]);
      expect(find.text('${h.l.marketLowest}: \$1.23'), findsOneWidget);
      await tester.tap(find.text(h.l.itemMarketOpen));
      await tester.pumpAndSettle();
      final uri = h.opened.single;
      expect(uri.scheme, 'https');
      expect(uri.host, 'steamcommunity.com');
      expect(uri.pathSegments, ['market', 'listings', '730', name]);
      expect(uri.hasQuery, isFalse);
      expect(uri.hasFragment, isFalse);
    },
  );

  testWidgets(
    'closing or invalidating detail cancels its pending price request',
    (tester) async {
      final market = _Market();
      final h = _Harness(tester, market);
      await h.show();
      await h.submit('detail');
      market.pricePending = Completer<MarketPrice?>();
      await tester.tap(find.text('detail').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('market-search-refresh-price')),
      );
      await tester.pump();
      h.active = false;
      await h.show();
      expect(market.priceTokens.last!.isCancelled, isTrue);
      expect(find.byKey(const ValueKey('market-search-details')), findsNothing);
      market.pricePending!.complete(const MarketPrice(lowest: 'old price'));
      await tester.pumpAndSettle();
      expect(find.text('old price'), findsNothing);
    },
  );

  testWidgets('dispose cancels current HTTP token and prevents later UI work', (
    tester,
  ) async {
    final pending = Completer<MarketSearchPage>();
    final market = _Market()..onSearch = (_) => pending.future;
    final h = _Harness(tester, market);
    await h.show();
    await h.submit('dispose', settle: false);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(market.tokens.single!.isCancelled, isTrue);
    pending.complete(_page('discarded'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final variant in AvaThemeVariant.values) {
    testWidgets(
      '${variant.name}: small screen, large text and keyboard remain scrollable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final h = _Harness(tester, _Market())
          ..variant = variant
          ..textScale = 1.5
          ..locale = const Locale('de');
        await h.show();
        await tester.enterText(
          find.byKey(const ValueKey('market-search-query')),
          'market',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('market-search-submit')),
        );
        expect(tester.takeException(), isNull);
        expect(h.market.requests, isEmpty);
        tester.view.viewInsets = const FakeViewPadding();
        await h.submit('market');
        await tester.scrollUntilVisible(
          find.text('market').last,
          200,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('market-search-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
