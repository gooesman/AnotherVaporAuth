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
  _Inventory() : super(SteamApiClient());
  final selectedContexts = <String>[];

  @override
  Future<InventoryOverview> overview(
    SteamGuardAccount account, {
    String? ownerSteamId,
  }) async => const InventoryOverview([
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
  ], WalletInfo.fallback);

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
    return const InventoryPage([], null, false);
  }
}

class _Market extends MarketClient {
  _Market() : super(SteamApiClient());
  int cancellations = 0;

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
}) async {
  final market = _Market();
  final inventory = _Inventory();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        autoLoginProvider.overrideWithValue(_AutoLogin()),
        inventoryClientProvider.overrideWithValue(inventory),
        marketClientProvider.overrideWithValue(market),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAvaTheme(AvaThemeVariant.light),
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
