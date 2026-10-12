import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/screen_corners.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/protocol/inventory_client.dart';
import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/auto_login.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/market/market_screen.dart';
import 'package:ava/src/ui/market/market_search_tab.dart';
import 'package:ava/src/ui/market/sell_sheet.dart';
import 'package:ava/src/ui/widgets/inventory_item_icon.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AutoLogin extends AutoLogin {
  _AutoLogin({this.pending}) : super(SteamApiClient());
  final Future<AutoLoginOutcome>? pending;
  int calls = 0;
  @override
  Future<AutoLoginOutcome> ensureSession(SteamGuardAccount account) async {
    calls++;
    if (pending != null) return pending!;
    return AutoLoginOutcome.ok;
  }
}

class _Controller extends AppController {
  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(MemoryStorageProvider()),
    accounts: const [],
    locked: false,
  );
}

const _defaultGames = [
  InventoryGame(
    appid: 730,
    contextId: '2',
    name: 'CS2',
    iconUrl: '',
    itemCount: 24,
    contextName: 'Backpack',
    showContext: true,
  ),
  InventoryGame(
    appid: 730,
    contextId: '16',
    name: 'CS2',
    iconUrl: '',
    itemCount: 4,
    contextName: 'Trade Protected',
    showContext: true,
  ),
];

class _Inventory extends InventoryClient {
  _Inventory({
    this.inventoryItems = const [],
    this.walletInfo = WalletInfo.fallback,
    this.nextPage = const [],
    this.games = _defaultGames,
    this.pendingOverview,
  }) : super(SteamApiClient());
  final List<InventoryItem> inventoryItems;
  final WalletInfo walletInfo;
  final List<InventoryItem> nextPage;
  final List<InventoryGame> games;
  final Future<InventoryOverview>? pendingOverview;
  int overviewCalls = 0;
  final selectedContexts = <String>[];
  final selectedInventories = <(int, String)>[];

  @override
  Future<InventoryOverview> overview(
    SteamGuardAccount account, {
    String? ownerSteamId,
  }) async {
    overviewCalls++;
    if (pendingOverview != null) return pendingOverview!;
    return InventoryOverview(games, walletInfo);
  }

  @override
  Future<InventoryPage> items(
    SteamGuardAccount account,
    int appid,
    String contextId, {
    String? ownerSteamId,
    String? startAssetId,
    int count = 75,
  }) async {
    selectedContexts.add(contextId);
    selectedInventories.add((appid, contextId));
    return startAssetId == null && nextPage.isNotEmpty
        ? InventoryPage(inventoryItems, 'cursor', true)
        : InventoryPage(
            startAssetId == null ? inventoryItems : nextPage,
            null,
            false,
          );
  }
}

class _Market extends MarketClient {
  _Market() : super(SteamApiClient());
  int cancellations = 0;
  int listingsCalls = 0;
  final priceQueries = <(int, String, int)>[];

  @override
  Future<MarketPrice?> priceOverview(
    int appid,
    String marketHashName,
    int currency,
  ) async {
    priceQueries.add((appid, marketHashName, currency));
    return const MarketPrice(lowest: '¥ 1.23', median: '¥ 1.25', volume: 20);
  }

  @override
  Future<List<MarketListing>> myListings(
    SteamGuardAccount account, {
    int count = 100,
  }) async {
    listingsCalls++;
    return [
      _listing('1', 'Active item', MarketListingState.active),
      _listing('2', 'Held item', MarketListingState.onHold),
      _listing('3', 'Pending item', MarketListingState.pendingConfirmation),
    ];
  }

  @override
  Future<List<double>> priceHistory(
    SteamGuardAccount account,
    int appid,
    String marketHashName, {
    int points = 60,
  }) async => const [];

  @override
  Future<bool> cancel(SteamGuardAccount account, String listingId) async {
    cancellations++;
    return true;
  }
}

class _CountedItem extends InventoryItem {
  _CountedItem(int id)
    : super(
        appid: 730,
        contextId: '2',
        assetId: '$id',
        classId: '$id',
        instanceId: '0',
        amount: 1,
        marketHashName: 'Rifle $id',
        name: 'Rifle $id',
        type: 'Rifle',
        iconUrl: '',
        marketable: true,
        tradable: true,
        tags: const [
          InventoryTag(category: 'Type', internalName: 'Rifle', label: 'Rifle'),
        ],
      );

  int tagReads = 0;
  @override
  List<InventoryTag> get tags {
    tagReads++;
    return super.tags;
  }
}

MarketListing _listing(String id, String name, MarketListingState state) =>
    MarketListing(
      listingId: id,
      appid: 730,
      marketHashName: name,
      name: name,
      iconUrl: '',
      buyerPrice: 115,
      fee: 15,
      createdAt: 0,
      active: state == MarketListingState.active,
      state: state,
      holdUntil: state == MarketListingState.onHold ? 1900000000 : null,
    );

Future<(_Market, _Inventory, AppLocalizations)> _show(
  WidgetTester tester, {
  int initialTab = 1,
  List<InventoryItem> items = const [],
  List<InventoryItem> nextPage = const [],
  WalletInfo wallet = WalletInfo.fallback,
  AvaThemeVariant variant = AvaThemeVariant.light,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double cornerRadius = 0,
  EdgeInsets? systemPadding,
  List<InventoryGame> games = _defaultGames,
  _AutoLogin? autoLogin,
  Future<InventoryOverview>? pendingOverview,
  bool settle = true,
}) async {
  final market = _Market();
  final inventory = _Inventory(
    inventoryItems: items,
    walletInfo: wallet,
    nextPage: nextPage,
    games: games,
    pendingOverview: pendingOverview,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appControllerProvider.overrideWith(_Controller.new),
        autoLoginProvider.overrideWithValue(autoLogin ?? _AutoLogin()),
        inventoryClientProvider.overrideWithValue(inventory),
        marketClientProvider.overrideWithValue(market),
      ],
      child: MaterialApp(
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: systemPadding,
          ),
          child: ScreenCorners(bottom: cornerRadius, child: child!),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAvaTheme(variant),
        home: MarketScreen(
          account: SteamGuardAccount(
            accountName: 'Test player',
            session: SessionData(steamId: 76561198000000123),
          ),
          initialTab: initialTab,
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return (
    market,
    inventory,
    AppLocalizations.of(tester.element(find.byType(MarketScreen))),
  );
}

InventoryItem _categoryItem(
  String id,
  String name,
  String category,
  String label,
) => InventoryItem(
  appid: 730,
  contextId: '2',
  assetId: id,
  classId: id,
  instanceId: '0',
  amount: 1,
  marketHashName: name,
  name: name,
  type: '',
  iconUrl: '',
  marketable: true,
  tradable: true,
  tags: [InventoryTag(category: 'Type', internalName: category, label: label)],
);

Future<void> _filter(WidgetTester tester, String control, String label) async {
  await tester.tap(find.byKey(ValueKey(control)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening public market reads no private account data', (
    tester,
  ) async {
    final login = _AutoLogin();
    final (market, inventory, l) = await _show(
      tester,
      initialTab: 2,
      autoLogin: login,
    );
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);
    expect(find.widgetWithText(Tab, l.marketTabSearch), findsOneWidget);
    expect(login.calls, 0);
    expect(inventory.overviewCalls, 0);
    expect(inventory.selectedInventories, isEmpty);
    expect(market.listingsCalls, 0);
    expect(market.priceQueries, isEmpty);
    expect(
      tester.widget<MarketSearchTab>(find.byType(MarketSearchTab)).active,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy initialTab one loads personal listings only', (
    tester,
  ) async {
    final login = _AutoLogin();
    final (market, inventory, _) = await _show(
      tester,
      initialTab: 1,
      autoLogin: login,
    );
    expect(find.text('Active item'), findsOneWidget);
    expect(login.calls, 1);
    expect(market.listingsCalls, 1);
    expect(inventory.overviewCalls, 0);
    expect(inventory.selectedInventories, isEmpty);
  });

  testWidgets(
    'refresh targets only the active tab and cached filters survive switching',
    (tester) async {
      final (market, inventory, l) = await _show(tester, initialTab: 0);
      expect(inventory.overviewCalls, 1);
      expect(inventory.selectedInventories, hasLength(1));
      expect(market.listingsCalls, 0);
      await tester.tap(find.byTooltip(l.commonRefresh));
      await tester.pumpAndSettle();
      expect(inventory.selectedInventories, hasLength(2));
      expect(market.listingsCalls, 0);
      await tester.enterText(
        find.byKey(const ValueKey('inventory-search')),
        'kept inventory query',
      );
      await tester.tap(find.widgetWithText(Tab, l.marketTabListings));
      await tester.pumpAndSettle();
      expect(market.listingsCalls, 1);
      await tester.tap(find.byTooltip(l.commonRefresh));
      await tester.pumpAndSettle();
      expect(market.listingsCalls, 2);
      expect(inventory.selectedInventories, hasLength(2));
      await tester.tap(
        find.widgetWithText(ChoiceChip, '${l.marketListingOnHold} (1)'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, l.marketTabSearch));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarketSearchTab>(find.byType(MarketSearchTab)).reload,
        0,
      );
      await tester.tap(find.byTooltip(l.commonRefresh));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarketSearchTab>(find.byType(MarketSearchTab)).reload,
        1,
      );
      expect(market.listingsCalls, 2);
      expect(inventory.overviewCalls, 1);
      expect(inventory.selectedInventories, hasLength(2));
      await tester.tap(find.widgetWithText(Tab, l.marketTabListings));
      await tester.pumpAndSettle();
      expect(find.text('Held item'), findsOneWidget);
      expect(find.text('Active item'), findsNothing);
      expect(market.listingsCalls, 2);
      expect(
        tester
            .widget<MarketSearchTab>(
              find.byType(MarketSearchTab, skipOffstage: false),
            )
            .active,
        isFalse,
      );
      await tester.tap(find.widgetWithText(Tab, l.marketTabInventory));
      await tester.pumpAndSettle();
      expect(inventory.selectedInventories, hasLength(2));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('inventory-search')))
            .controller!
            .text,
        'kept inventory query',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final initialTab in [0, 1]) {
    testWidgets(
      'switching away from tab $initialTab during sign-in defers its private fetch',
      (tester) async {
        final pending = Completer<AutoLoginOutcome>();
        final login = _AutoLogin(pending: pending.future);
        final (market, inventory, l) = await _show(
          tester,
          initialTab: initialTab,
          autoLogin: login,
          settle: false,
        );
        await tester.tap(find.widgetWithText(Tab, l.marketTabSearch));
        await tester.pumpAndSettle();
        pending.complete(AutoLoginOutcome.ok);
        await tester.pumpAndSettle();
        expect(inventory.overviewCalls, 0);
        expect(inventory.selectedInventories, isEmpty);
        expect(market.listingsCalls, 0);
        await tester.tap(
          find.widgetWithText(
            Tab,
            initialTab == 0 ? l.marketTabInventory : l.marketTabListings,
          ),
        );
        await tester.pumpAndSettle();
        expect(login.calls, 2);
        expect(inventory.overviewCalls, initialTab == 0 ? 1 : 0);
        expect(market.listingsCalls, initialTab == 1 ? 1 : 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'overview finishing while hidden waits to fetch inventory items',
    (tester) async {
      final pending = Completer<InventoryOverview>();
      final (market, inventory, l) = await _show(
        tester,
        initialTab: 0,
        pendingOverview: pending.future,
        settle: false,
      );
      await tester.pump();
      expect(inventory.overviewCalls, 1);
      await tester.tap(find.widgetWithText(Tab, l.marketTabSearch));
      await tester.pumpAndSettle();
      pending.complete(InventoryOverview(_defaultGames, WalletInfo.fallback));
      await tester.pumpAndSettle();
      expect(inventory.selectedInventories, isEmpty);
      expect(market.listingsCalls, 0);
      await tester.tap(find.widgetWithText(Tab, l.marketTabInventory));
      await tester.pumpAndSettle();
      expect(inventory.overviewCalls, 1);
      expect(inventory.selectedInventories, hasLength(1));
    },
  );

  testWidgets(
    'successful sell marks hidden listings dirty until next activation',
    (tester) async {
      final (market, _, l) = await _show(
        tester,
        initialTab: 1,
        items: [_categoryItem('1', 'Sellable item', 'Rifle', 'Rifle')],
      );
      expect(market.listingsCalls, 1);
      await tester.tap(find.widgetWithText(Tab, l.marketTabInventory));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('inventory-730-2-1')));
      await tester.pumpAndSettle();
      expect(find.byType(SellSheet), findsOneWidget);
      // Exercise the documented SellSheet result without issuing any trade.
      tester.state<NavigatorState>(find.byType(Navigator)).pop(true);
      await tester.pumpAndSettle();
      expect(market.listingsCalls, 1);
      await tester.tap(find.widgetWithText(Tab, l.marketTabListings));
      await tester.pumpAndSettle();
      expect(market.listingsCalls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  const games = [
    InventoryGame(
      appid: 570,
      contextId: '2',
      name: 'Dota 2',
      iconUrl: '',
      itemCount: 46,
    ),
    InventoryGame(
      appid: 730,
      contextId: '16',
      name: 'Counter-Strike 2',
      iconUrl: '',
      itemCount: 24,
      contextName: 'Trade-protected Items with a very long localized label',
      showContext: true,
    ),
    InventoryGame(
      appid: 753,
      contextId: '6',
      name: 'Steam',
      iconUrl: '',
      itemCount: 15,
    ),
    InventoryGame(
      appid: 730,
      contextId: '2',
      name: 'Counter-Strike 2',
      iconUrl: '',
      itemCount: 4,
      contextName: 'Inventory with a very long localized label',
      showContext: true,
    ),
  ];
  for (final size in [const Size(320, 640), const Size(844, 390)]) {
    for (final textScale in [1.0, 1.8]) {
      testWidgets(
        '${size.width}x${size.height} phone at $textScale text scale exposes every game context',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final (_, inventory, _) = await _show(
            tester,
            initialTab: 0,
            games: games,
            textScale: textScale,
            cornerRadius: 48,
            systemPadding: const EdgeInsets.fromLTRB(24, 0, 16, 34),
          );
          final menu = find.byKey(const ValueKey('market-game-menu'));
          final bounds = tester.getRect(menu);
          expect(bounds.left, greaterThanOrEqualTo(24));
          expect(bounds.right, lessThanOrEqualTo(size.width - 16));
          expect(bounds.height, greaterThanOrEqualTo(48));
          for (final game in games) {
            await tester.tap(menu);
            await tester.pumpAndSettle();
            expect(find.byType(PopupMenuItem<InventoryGame>), findsNWidgets(4));
            final option = find.byKey(
              ValueKey('market-game-option-${game.appid}-${game.contextId}'),
            );
            await tester.ensureVisible(option);
            await tester.pumpAndSettle();
            await tester.tap(option);
            await tester.pumpAndSettle();
            expect(
              find.text('${game.displayName}  ').hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
          expect(inventory.selectedInventories, [
            (570, '2'),
            (730, '16'),
            (753, '6'),
            (730, '2'),
          ]);
        },
      );
    }
  }

  testWidgets('cached facet labels update when the app language changes', (
    tester,
  ) async {
    final items = [_categoryItem('1', 'Unknown item', '', '')];
    final (_, _, english) = await _show(tester, initialTab: 0, items: items);
    await _filter(tester, 'inventory-type', english.inventoryFilterOther);
    final (_, _, chinese) = await _show(
      tester,
      initialTab: 0,
      items: items,
      locale: const Locale('zh'),
    );
    expect(
      find.text(chinese.inventoryFilterOther).hitTestable(),
      findsOneWidget,
    );
    expect(find.text(english.inventoryFilterOther), findsNothing);
    expect(find.byKey(const ValueKey('inventory-730-2-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search does not rebuild facets and resize does not rescan inventory',
    (tester) async {
      final items = List.generate(200, _CountedItem.new);
      await _show(tester, initialTab: 0, items: items);
      for (final item in items) {
        item.tagReads = 0;
      }
      await tester.enterText(
        find.byKey(const ValueKey('inventory-search')),
        'unmatched search',
      );
      await tester.pumpAndSettle();
      expect(
        items.fold(0, (reads, item) => reads + item.tagReads),
        items.length,
      );
      for (final item in items) {
        item.tagReads = 0;
      }
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(items.fold(0, (reads, item) => reads + item.tagReads), 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reselecting a game preserves items and filters, refresh reloads',
    (tester) async {
      final (_, inventory, l) = await _show(tester, initialTab: 0);
      await tester.enterText(
        find.byKey(const ValueKey('inventory-search')),
        'kept filter',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CS2 · Backpack  '));
      await tester.pumpAndSettle();
      expect(inventory.selectedContexts, ['2']);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('inventory-search')))
            .controller!
            .text,
        'kept filter',
      );
      await tester.tap(find.byTooltip(l.commonRefresh));
      await tester.pumpAndSettle();
      expect(inventory.selectedContexts, ['2', '2']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone rounded corners do not collapse the game selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _show(tester, initialTab: 0, cornerRadius: 48);
    expect(tester.takeException(), isNull);
    expect(find.text('CS2 · Backpack  ').hitTestable(), findsOneWidget);
    expect(
      tester.getSize(find.text('CS2 · Backpack  ')).height,
      greaterThanOrEqualTo(13),
    );
  });

  testWidgets(
    'market type filtering preserves matching items and combines with search',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _show(
        tester,
        initialTab: 0,
        items: [
          _categoryItem('1', 'Rifle item', 'CSGO_Type_Rifle', 'Rifle'),
          _categoryItem('2', 'Paint item', 'CSGO_Type_Spray', 'Graffiti'),
          _categoryItem('3', 'Music item', 'CSGO_Type_MusicKit', 'Music Kit'),
        ],
      );
      await _filter(tester, 'inventory-type', 'Music Kit');
      expect(find.byKey(const ValueKey('inventory-730-2-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('inventory-730-2-1')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('inventory-search')),
        'rifle',
      );
      await tester.pumpAndSettle();
      expect(find.byType(InventoryItemIcon), findsNothing);
      await _filter(tester, 'inventory-type', 'All');
      expect(find.byKey(const ValueKey('inventory-730-2-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty filtered results can load another page and discover new categories',
    (tester) async {
      final (_, _, l) = await _show(
        tester,
        initialTab: 0,
        items: [_categoryItem('1', 'Rifle item', 'CSGO_Type_Rifle', 'Rifle')],
        nextPage: [
          _categoryItem('2', 'Music item', 'CSGO_Type_MusicKit', 'Music Kit'),
        ],
      );
      await tester.enterText(
        find.byKey(const ValueKey('inventory-search')),
        'music',
      );
      await tester.pumpAndSettle();
      expect(find.text(l.inventoryFilterNoMatches), findsOneWidget);
      expect(find.text(l.inventoryFilterLoaded), findsOneWidget);
      await tester.tap(find.text(l.tradeMore));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inventory-730-2-2')), findsOneWidget);
      expect(find.text(l.inventoryFilterLoaded), findsNothing);
      await _filter(tester, 'inventory-type', 'Music Kit');
      expect(find.byKey(const ValueKey('inventory-730-2-2')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '360px large-text filters remain usable without keyboard overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await _show(
        tester,
        initialTab: 0,
        textScale: 1.5,
        locale: const Locale('de'),
        items: [
          _categoryItem(
            '1',
            'Music item',
            'CSGO_Type_MusicKit',
            'Very long localized music kit category label',
          ),
        ],
      );
      await _filter(
        tester,
        'inventory-type',
        'Very long localized music kit category label',
      );
      await tester.enterText(
        find.byKey(const ValueKey('inventory-search')),
        'music',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'short screen with large text and keyboard keeps filters and results scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await _show(
        tester,
        initialTab: 0,
        textScale: 1.5,
        locale: const Locale('de'),
        items: [
          _categoryItem('1', 'Music item', 'CSGO_Type_MusicKit', 'Music Kit'),
        ],
        nextPage: [
          _categoryItem('2', 'Rifle item', 'CSGO_Type_Rifle', 'Rifle'),
        ],
      );
      await tester.enterText(
        find.byKey(const ValueKey('inventory-search')),
        'music',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('inventory-730-2-1')),
        120,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(InventoryItemIcon).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  const item = InventoryItem(
    appid: 730,
    contextId: '2',
    assetId: '123',
    classId: '456',
    instanceId: '0',
    amount: 1,
    marketHashName: 'Example | Skin (Field-Tested)',
    name: 'Example skin',
    type: 'Mil-Spec Grade',
    iconUrl: '',
    marketable: false,
    tradable: true,
    rarityColor: '4b69ff',
    rarityName: 'Mil-Spec Grade',
  );
  const cnyWallet = WalletInfo(
    currency: 23,
    steamFeePct: 0.05,
    publisherFeePct: 0.10,
    marketMinimum: 1,
    currencyIncrement: 1,
  );

  testWidgets(
    'right-click looks up a held inventory item without opening a sale',
    (tester) async {
      final (market, _, l) = await _show(
        tester,
        initialTab: 0,
        items: [item],
        wallet: cnyWallet,
      );
      expect(find.byType(InventoryItemIcon), findsOneWidget);
      expect(market.priceQueries, isEmpty);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(item.name)),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.itemMarketViewPrice));
      await tester.pumpAndSettle();
      expect(market.priceQueries, [(730, item.marketHashName, 23)]);
      expect(find.text(l.itemMarketCurrency('CNY')), findsOneWidget);
      expect(find.text('${l.marketLowest}: ¥ 1.23'), findsOneWidget);
      expect(find.byType(SellSheet), findsNothing);
      await tester.tap(find.text(l.commonClose));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(MarketScreen),
          matching: find.textContaining('¥ 1.23 · CNY'),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final variant in AvaThemeVariant.values) {
    testWidgets(
      'small ${variant.name} inventory keeps price menu and quote usable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (market, _, l) = await _show(
          tester,
          initialTab: 0,
          items: [item],
          wallet: cnyWallet,
          variant: variant,
        );
        await tester.tap(find.byTooltip(l.itemMarketActions));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.itemMarketViewPrice));
        await tester.pumpAndSettle();
        expect(find.text(l.itemMarketCurrency('CNY')), findsOneWidget);
        await tester.tap(find.text(l.commonClose));
        await tester.pumpAndSettle();
        expect(market.priceQueries, hasLength(1));
        expect(find.textContaining('¥ 1.23 · CNY'), findsOneWidget);
        expect(find.byType(SellSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final locale in [const Locale('zh'), const Locale('de')]) {
    testWidgets(
      '${locale.languageCode} long names and large text leave the thumbnail usable',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const longItem = InventoryItem(
          appid: 730,
          contextId: '2',
          assetId: '123',
          classId: '456',
          instanceId: '0',
          amount: 1,
          marketHashName: 'Example | Skin (Field-Tested)',
          name: 'M4A1 消音型 | 氧化处理（久经沙场）',
          type: 'Restricted Rifle',
          iconUrl: '',
          marketable: false,
          tradable: true,
          rarityColor: '8847ff',
          rarityName: 'Restricted',
        );
        final (_, _, l) = await _show(
          tester,
          initialTab: 0,
          items: [longItem],
          wallet: cnyWallet,
          locale: locale,
          textScale: 1.8,
        );
        await tester.tap(find.byTooltip(l.itemMarketActions));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.itemMarketViewPrice));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.commonClose));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(InventoryItemIcon)).height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('all sale states remain visible and held filter is selectable', (
    tester,
  ) async {
    final (_, _, l) = await _show(tester);
    expect(find.text('Active item'), findsOneWidget);
    expect(find.text('Held item'), findsOneWidget);
    expect(find.text('Pending item'), findsOneWidget);
    final holdChip = find.widgetWithText(
      ChoiceChip,
      '${l.marketListingOnHold} (1)',
    );
    await tester.tap(holdChip);
    await tester.pumpAndSettle();
    expect(find.text('Held item'), findsOneWidget);
    expect(find.text('Active item'), findsNothing);
    expect(find.text('Pending item'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the confirmation never removes a listing', (
    tester,
  ) async {
    final (market, _, l) = await _show(tester);
    await tester.tap(find.byTooltip(l.marketCancel).first);
    await tester.pumpAndSettle();
    expect(market.cancellations, 0);
    await tester.tap(find.widgetWithText(TextButton, l.commonCancel));
    await tester.pumpAndSettle();
    expect(market.cancellations, 0);
    expect(find.text('Active item'), findsOneWidget);
  });

  testWidgets('same game contexts have distinct labels and selection paths', (
    tester,
  ) async {
    final (_, inventory, _) = await _show(tester, initialTab: 0);
    expect(find.text('CS2 · Backpack  '), findsOneWidget);
    expect(find.text('CS2 · Trade Protected  '), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('inventory-search')),
      'previous game filter',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('CS2 · Trade Protected  '));
    await tester.pumpAndSettle();
    expect(inventory.selectedContexts, ['2', '16']);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('inventory-search')))
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
