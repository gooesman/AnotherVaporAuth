import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/market_favorites.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/market_search.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/steam_request_scope.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/widgets/dashboard_favorites_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MarketSearchItem _item(String name) => MarketSearchItem(
  appid: 730,
  marketHashName: name,
  name: name,
  priceText: r'$999.99',
  lowestPriceMinor: 99999,
);

SteamGuardAccount _account(int id) => SteamGuardAccount(
  accountName: 'fixture_$id',
  session: SessionData(steamId: id, accessToken: 'synthetic-$id'),
);

class _Market extends MarketClient {
  _Market() : super(SteamApiClient());
  final calls = <(int, String, int)>[];
  final tokens = <CancelToken?>[];
  Future<MarketPrice?> Function(int)? onPrice;

  @override
  Future<MarketPrice?> priceOverviewChecked(
    int appid,
    String hash,
    int currency,
  ) {
    calls.add((appid, hash, currency));
    tokens.add(SteamRequestScope.currentCancelToken);
    return onPrice?.call(currency) ??
        Future.value(
          MarketPrice(
            lowest: currency == 23 ? '¥ 15.36' : r'$2.16',
            median: 'median must not be displayed',
          ),
        );
  }
}

class _FavoritesStore extends MarketFavoritesStore {
  _FavoritesStore() : super(MemoryStorageProvider());
  MarketFavorites value = const MarketFavorites();
  @override
  Future<MarketFavorites> load() async => value;
  @override
  Future<void> save(MarketFavorites next) async => value = next;
}

class _Controller extends AppController {
  _Controller(this.accounts);
  final List<SteamGuardAccount> accounts;

  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(MemoryStorageProvider()),
    accounts: accounts,
    locked: false,
  );

  void lockForTest() =>
      state = AsyncData(state.requireValue.copyWith(locked: true));
  void remove() => state = AsyncData(state.requireValue.copyWith(accounts: []));
}

class _Harness {
  _Harness(this.tester, this.market) {
    account = accounts.first;
    controller = _Controller(accounts);
    favorites.value = MarketFavorites(
      items: [_item('Saved item')],
      currency: 23,
    );
  }

  final WidgetTester tester;
  final _Market market;
  final accounts = [_account(1), _account(2)];
  late SteamGuardAccount account;
  late _Controller controller;
  final favorites = _FavoritesStore();
  bool active = true;
  int reload = 0;
  double spacer = 0;
  double? cardHeight;
  ScrollController? outerScroll;
  ScrollController? innerScroll;
  int opened = 0;
  Locale locale = const Locale('en');
  AvaThemeVariant variant = AvaThemeVariant.dark;
  double textScale = 1;
  ProviderContainer get container => ProviderScope.containerOf(
    tester.element(find.byType(DashboardFavoritesCard)),
  );

  Future<void> show() async {
    Widget card = DashboardFavoritesCard(
      account: account,
      active: active,
      reload: reload,
      onViewAll: () => opened++,
    );
    if (cardHeight != null) {
      card = SizedBox(
        height: cardHeight,
        child: SingleChildScrollView(controller: innerScroll, child: card),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketClientProvider.overrideWithValue(market),
          marketFavoritesStoreProvider.overrideWithValue(favorites),
          appControllerProvider.overrideWith(() => controller),
          clockProvider.overrideWithValue(tester.binding.clock.now),
        ],
        child: MaterialApp(
          locale: locale,
          theme: buildAvaTheme(variant),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              controller: outerScroll,
              child: Column(
                children: [
                  SizedBox(height: spacer),
                  card,
                  const SizedBox(height: 800),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  testWidgets('nested card quotes only when visible in both scroll viewports', (
    tester,
  ) async {
    final pending = Completer<MarketPrice?>();
    final market = _Market()..onPrice = (_) => pending.future;
    final outer = ScrollController();
    final inner = ScrollController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    final h = _Harness(tester, market)
      ..spacer = 1000
      ..cardHeight = 200
      ..outerScroll = outer
      ..innerScroll = inner;
    await h.show();
    expect(market.calls, isEmpty);
    outer.jumpTo(1000);
    await tester.pump();
    await tester.pump();
    expect(market.calls, hasLength(1));
    outer.jumpTo(0);
    await tester.pump();
    expect(market.tokens.single!.isCancelled, isTrue);
    pending.complete(const MarketPrice(lowest: 'stale'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inner clipping defers a quote until the row scrolls into view', (
    tester,
  ) async {
    final pending = Completer<MarketPrice?>();
    final market = _Market()..onPrice = (_) => pending.future;
    final inner = ScrollController();
    addTearDown(inner.dispose);
    final h = _Harness(tester, market)
      ..cardHeight = 60
      ..innerScroll = inner;
    await h.show();
    expect(market.calls, isEmpty);
    inner.jumpTo(inner.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    expect(market.calls, hasLength(1));
    inner.jumpTo(0);
    await tester.pump();
    expect(market.tokens.single!.isCancelled, isTrue);
    pending.complete(const MarketPrice(lowest: 'stale'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'preview quotes only its first four favorites in saved currency',
    (tester) async {
      final market = _Market();
      final h = _Harness(tester, market);
      h.favorites.value = MarketFavorites(
        items: List.generate(8, (i) => _item('Item $i')),
        currency: 23,
      );
      await h.show();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      expect(market.calls, [for (var i = 0; i < 4; i++) (730, 'Item $i', 23)]);
      expect(find.text('Item 4'), findsNothing);
      expect(find.text('¥ 15.36'), findsNWidgets(4));
      expect(find.text(r'$999.99'), findsNothing);
      expect(find.text('median must not be displayed'), findsNothing);
      await tester.tap(find.text('Item 0'));
      final l = AppLocalizations.of(
        tester.element(find.byType(DashboardFavoritesCard)),
      );
      await tester.tap(find.text(l.dashboardFavoritesMore));
      expect(h.opened, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets('unset currency follows ${locale.languageCode} locale', (
      tester,
    ) async {
      final market = _Market();
      final h = _Harness(tester, market)..locale = locale;
      h.favorites.value = MarketFavorites(items: [_item('Saved item')]);
      await h.show();
      expect(market.calls.single.$3, locale.languageCode == 'zh' ? 23 : 1);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'offscreen card makes no quote request and stops an invisible row',
    (tester) async {
      final pending = Completer<MarketPrice?>();
      final market = _Market()..onPrice = (_) => pending.future;
      final h = _Harness(tester, market)..spacer = 1000;
      await h.show();
      expect(market.calls, isEmpty);
      await tester.ensureVisible(find.text('Saved item'));
      await tester.pump();
      await tester.pump();
      expect(market.calls, hasLength(1));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 700),
      );
      await tester.pump();
      expect(market.tokens.single!.isCancelled, isTrue);
      pending.complete(const MarketPrice(lowest: 'stale'));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'inactive preview does not quote and resume reuses fresh prices',
    (tester) async {
      final market = _Market();
      final h = _Harness(tester, market)..active = false;
      await h.show();
      expect(market.calls, isEmpty);
      h.active = true;
      await h.show();
      expect(market.calls, hasLength(1));
      h.active = false;
      await h.show();
      h.active = true;
      await h.show();
      expect(market.calls, hasLength(1));
      h.reload++;
      await h.show();
      expect(market.calls, hasLength(2));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('currency change cancels stale quote and never shows its price', (
    tester,
  ) async {
    final pending = Completer<MarketPrice?>();
    final market = _Market()
      ..onPrice = (currency) => currency == 23
          ? pending.future
          : Future.value(const MarketPrice(lowest: r'$2.16'));
    final h = _Harness(tester, market);
    await h.show();
    await h.container.read(marketFavoritesProvider.notifier).setCurrency(1);
    await tester.pump();
    await tester.pump();
    expect(market.tokens.first!.isCancelled, isTrue);
    expect(market.calls.map((call) => call.$3), [23, 1]);
    pending.complete(const MarketPrice(lowest: 'stale CNY'));
    await tester.pump();
    expect(find.text('stale CNY'), findsNothing);
    expect(find.text(r'$2.16'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final change in ['account', 'token', 'source', 'client']) {
    testWidgets('$change change cancels the previous quote', (tester) async {
      final pending = Completer<MarketPrice?>();
      final market = _Market()..onPrice = (_) => pending.future;
      final h = _Harness(tester, market);
      await h.show();
      switch (change) {
        case 'account':
          h.account = h.accounts.last;
        case 'token':
          h.account.session.accessToken = 'renewed-synthetic';
        case 'source':
          h.account.fromPortable = true;
        case 'client':
          market.api.steamLanguage = 'schinese';
      }
      await h.show();
      expect(market.tokens.first!.isCancelled, isTrue);
      expect(market.calls, hasLength(2));
      pending.complete(const MarketPrice(lowest: 'fresh'));
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final stop in ['inactive', 'lock', 'remove', 'background', 'dispose']) {
    testWidgets('$stop immediately cancels the pending quote', (tester) async {
      final pending = Completer<MarketPrice?>();
      final market = _Market()..onPrice = (_) => pending.future;
      final h = _Harness(tester, market);
      await h.show();
      expect(market.calls, hasLength(1));
      switch (stop) {
        case 'inactive':
          h.active = false;
          await h.show();
        case 'lock':
          h.controller.lockForTest();
          await tester.pump();
        case 'remove':
          h.controller.remove();
          await tester.pump();
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
        case 'dispose':
          await tester.pumpWidget(const SizedBox());
      }
      expect(market.tokens.single!.isCancelled, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(market.calls, hasLength(1));
      pending.complete(const MarketPrice(lowest: 'stale'));
      await tester.pumpWidget(const SizedBox());
      if (stop == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    });
  }

  testWidgets('empty favorites never request market data', (tester) async {
    final market = _Market();
    final h = _Harness(tester, market);
    h.favorites.value = const MarketFavorites();
    await h.show();
    await tester.pump(const Duration(seconds: 3));
    expect(market.calls, isEmpty);
    expect(find.byType(ListTile), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mounting while already paused does not request a quote', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final market = _Market();
    final h = _Harness(tester, market);
    await h.show();
    await tester.pump(const Duration(seconds: 2));
    expect(market.calls, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(market.calls, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'remote replacement cancels old favorites and loads the new identities',
    (tester) async {
      final pending = Completer<MarketPrice?>();
      final market = _Market()..onPrice = (_) => pending.future;
      final h = _Harness(tester, market);
      await h.show();
      await h.container
          .read(marketFavoritesProvider.notifier)
          .applySynced(
            MarketFavorites(
              items: [_item('Replacement')],
              currency: 23,
            ).toJson(),
          );
      await tester.pump();
      await tester.pump();
      expect(market.tokens.first!.isCancelled, isTrue);
      expect(market.calls.map((call) => call.$2), [
        'Saved item',
        'Replacement',
      ]);
      expect(find.text('Saved item'), findsNothing);
      expect(find.text('Replacement'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      pending.complete(const MarketPrice(lowest: 'discarded'));
    },
  );

  testWidgets('median-only quote is not displayed as a lowest asking price', (
    tester,
  ) async {
    final market = _Market()
      ..onPrice = (_) async => const MarketPrice(median: '¥ 10.00');
    final h = _Harness(tester, market);
    await h.show();
    expect(find.text('¥ 10.00'), findsNothing);
    expect(find.text(r'$999.99'), findsNothing);
    final l = AppLocalizations.of(
      tester.element(find.byType(DashboardFavoritesCard)),
    );
    expect(find.text(l.marketSearchPriceUnavailable), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final variant in AvaThemeVariant.values) {
    testWidgets(
      '${variant.name}: narrow overview with large text has no overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = _Harness(tester, _Market())
          ..variant = variant
          ..textScale = 1.6;
        await h.show();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
