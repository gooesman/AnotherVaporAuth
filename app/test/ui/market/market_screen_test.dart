import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/protocol/inventory_client.dart';
import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/auto_login.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/ui/market/market_screen.dart';
import 'package:ava/src/ui/market/sell_sheet.dart';
import 'package:ava/src/ui/widgets/inventory_item_icon.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AutoLogin extends AutoLogin {
  _AutoLogin() : super(SteamApiClient());
  @override
  Future<AutoLoginOutcome> ensureSession(SteamGuardAccount account) async =>
      AutoLoginOutcome.ok;
}

class _Inventory extends InventoryClient {
  _Inventory({
    this.inventoryItems = const [],
    this.walletInfo = WalletInfo.fallback,
  }) : super(SteamApiClient());
  final List<InventoryItem> inventoryItems;
  final WalletInfo walletInfo;
  final selectedContexts = <String>[];

  @override
  Future<InventoryOverview> overview(
    SteamGuardAccount account, {
    String? ownerSteamId,
  }) async => InventoryOverview(const [
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
  ], walletInfo);

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
    return InventoryPage(inventoryItems, null, false);
  }
}

class _Market extends MarketClient {
  _Market() : super(SteamApiClient());
  int cancellations = 0;
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
  }) async => [
    _listing('1', 'Active item', MarketListingState.active),
    _listing('2', 'Held item', MarketListingState.onHold),
    _listing('3', 'Pending item', MarketListingState.pendingConfirmation),
  ];

  @override
  Future<bool> cancel(SteamGuardAccount account, String listingId) async {
    cancellations++;
    return true;
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
  WalletInfo wallet = WalletInfo.fallback,
  AvaThemeVariant variant = AvaThemeVariant.light,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  final market = _Market();
  final inventory = _Inventory(inventoryItems: items, walletInfo: wallet);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        autoLoginProvider.overrideWithValue(_AutoLogin()),
        inventoryClientProvider.overrideWithValue(inventory),
        marketClientProvider.overrideWithValue(market),
      ],
      child: MaterialApp(
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
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
  await tester.pumpAndSettle();
  return (
    market,
    inventory,
    AppLocalizations.of(tester.element(find.byType(MarketScreen))),
  );
}

void main() {
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
    await tester.tap(find.text('CS2 · Trade Protected  '));
    await tester.pumpAndSettle();
    expect(inventory.selectedContexts, ['2', '16']);
    expect(tester.takeException(), isNull);
  });
}
