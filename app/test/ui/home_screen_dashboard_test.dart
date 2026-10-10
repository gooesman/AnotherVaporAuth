import 'dart:typed_data';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/entitlement.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/core/protocol/inventory_client.dart';
import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/skins/skin_spec.dart';
import 'package:ava/src/ui/account_dashboard.dart';
import 'package:ava/src/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final homePreviewAccounts = [
  for (var i = 0; i < 3; i++)
    SteamGuardAccount(
      accountName: ['demo_primary', 'demo_trading', 'demo_backup'][i],
      personaName: ['演示账号 · 常用', '演示账号 · 交易', '演示账号 · 备用'][i],
      sharedSecret: 'c3ludGhldGljLXRlc3Qtc2VjcmV0',
      session: SessionData(
        steamId: 76561198000000001 + i,
        accessToken: 'synthetic',
      ),
    ),
];

class _PreviewApi extends SteamApiClient {
  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async => ProtoReader(Uint8List(0));
}

class _PreviewSettings extends SettingsStore {
  _PreviewSettings(super.storage);
  @override
  Future<bool> loadTutorialSeen() async => true;
}

class _PreviewController extends AppController {
  final StorageProvider storage;
  _PreviewController(this.storage);
  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(storage),
    accounts: homePreviewAccounts,
    locked: false,
  );
}

class _PreviewSkin extends SkinSpecController {
  final SkinSpec? spec;
  _PreviewSkin(this.spec);
  @override
  SkinSpec? build() => spec;
}

class _PreviewInventory extends InventoryClient {
  _PreviewInventory() : super(_PreviewApi());
  @override
  Future<WalletInfo> wallet(SteamGuardAccount account) async =>
      WalletInfo.fromJson({
        'success': true,
        'wallet_currency': 23,
        'wallet_balance': account == homePreviewAccounts[0] ? 123450 : 8900,
        'wallet_delayed_balance': 5678,
      });
}

class _PreviewMarket extends MarketClient {
  _PreviewMarket() : super(_PreviewApi());
  @override
  Future<List<MarketListing>> myListings(
    SteamGuardAccount account, {
    int count = 100,
  }) async => [
    for (final (index, name, state) in [
      (0, 'AK-47 | 演示物品', MarketListingState.active),
      (1, '手套 | 演示物品', MarketListingState.onHold),
      (2, '贴纸 | 演示物品', MarketListingState.pendingConfirmation),
    ])
      MarketListing(
        listingId: '${index + 1}',
        appid: 730,
        marketHashName: name,
        name: name,
        iconUrl: '',
        buyerPrice: 11500 + index * 100,
        fee: 1500,
        currency: 23,
        createdAt: 0,
        active: state == MarketListingState.active,
        state: state,
      ),
  ];
}

class _CountingInventory extends _PreviewInventory {
  int walletReads = 0;

  @override
  Future<WalletInfo> wallet(SteamGuardAccount account) {
    walletReads++;
    return super.wallet(account);
  }
}

class _CountingMarket extends _PreviewMarket {
  int listingReads = 0;

  @override
  Future<List<MarketListing>> myListings(
    SteamGuardAccount account, {
    int count = 100,
  }) {
    listingReads++;
    return super.myListings(account, count: count);
  }
}

/// Synthetic-only harness shared with the ignored visual preview script.
Widget dashboardHomePreviewApp({
  required AvaThemeVariant variant,
  bool mobile = false,
  Locale locale = const Locale('en'),
  SkinSpec? skinSpec,
  InventoryClient? inventory,
  MarketClient? market,
}) {
  final storage = MemoryStorageProvider();
  final tokens = AvaTokens.of(variant);
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      storageProvider.overrideWithValue(storage),
      settingsStoreProvider.overrideWithValue(_PreviewSettings(storage)),
      appControllerProvider.overrideWith(() => _PreviewController(storage)),
      apiClientProvider.overrideWithValue(_PreviewApi()),
      inventoryClientProvider.overrideWithValue(
        inventory ?? _PreviewInventory(),
      ),
      marketClientProvider.overrideWithValue(market ?? _PreviewMarket()),
      tickProvider.overrideWith((ref) => Stream.value(1900000010)),
      timeAlignerProvider.overrideWithValue(() async {}),
      skinSpecProvider.overrideWith(() => _PreviewSkin(skinSpec)),
      proStatusProvider.overrideWithValue(ProStatus.pro),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAvaTheme(variant).copyWith(
        platform: mobile ? TargetPlatform.android : TargetPlatform.windows,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bg,
          gradient: tokens.bgGradient,
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
      home: const HomeScreen(),
    ),
  );
}

Future<void> pumpDashboardHome(WidgetTester tester) async {
  // Home contains a continuously pulsing status dot, so pump finite frames
  // instead of waiting for all animations to stop.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  for (final variant in AvaThemeVariant.values) {
    for (final mobile in [false, true]) {
      testWidgets(
        'home dashboard fits ${variant.name} ${mobile ? 'phone' : 'desktop'}',
        (tester) async {
          tester.view.physicalSize = mobile
              ? const Size(393, 852)
              : const Size(1400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            dashboardHomePreviewApp(variant: variant, mobile: mobile),
          );
          await pumpDashboardHome(tester);
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(find.text('demo_trading'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (mobile) {
            // Phone account taps select their token without opening tools.
            expect(find.byType(AccountDashboard), findsNothing);
            await tester.tap(find.text('demo_trading'));
            await pumpDashboardHome(tester);
            expect(find.byType(AccountDashboardScreen), findsNothing);
            expect(find.byType(AccountDashboard), findsNothing);
            expect(find.text('demo_trading'), findsNWidgets(2));
            await tester.longPress(find.text('demo_trading').last);
            await pumpDashboardHome(tester);
            await tester.tap(find.text('Account overview'));
            await pumpDashboardHome(tester);
            expect(find.byType(AccountDashboardScreen), findsOneWidget);
            expect(find.text('CNY 89.00'), findsOneWidget);
          } else {
            expect(find.text('CNY 1234.50'), findsOneWidget);
            expect(find.byType(AccountDashboardScreen), findsNothing);
            await tester.tap(find.text('demo_trading'));
            await pumpDashboardHome(tester);
            expect(find.text('CNY 89.00'), findsOneWidget);
            expect(find.byType(AccountDashboardScreen), findsNothing);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'phone only fetches overview data after choosing it from account menu',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final inventory = _CountingInventory();
      final market = _CountingMarket();
      await tester.pumpWidget(
        dashboardHomePreviewApp(
          variant: AvaThemeVariant.light,
          mobile: true,
          inventory: inventory,
          market: market,
        ),
      );
      await pumpDashboardHome(tester);
      final l = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
      expect(find.byType(AccountDashboard), findsNothing);
      expect(find.text(l.dashboardWallet), findsNothing);
      expect(find.text(l.dashboardTitle), findsNothing);
      expect(find.text(l.dashboardMarket), findsNothing);
      expect(find.text(l.friendsTitle), findsNothing);
      expect(find.text(l.backupCodesTitle), findsNothing);
      expect(inventory.walletReads, 0);
      expect(market.listingReads, 0);

      await tester.tap(find.text('demo_trading'));
      await pumpDashboardHome(tester);
      expect(inventory.walletReads, 0);
      expect(market.listingReads, 0);
      await tester.longPress(find.text('demo_trading').last);
      await pumpDashboardHome(tester);
      for (final label in [
        l.dashboardTitle,
        l.actionMarket,
        l.friendsTitle,
        l.backupCodesTitle,
      ]) {
        expect(
          find.descendant(of: find.byType(Dialog), matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(inventory.walletReads, 0);
      expect(market.listingReads, 0);
      await tester.tap(find.text(l.dashboardTitle));
      await pumpDashboardHome(tester);
      expect(find.byType(AccountDashboardScreen), findsOneWidget);
      expect(find.text('CNY 89.00'), findsOneWidget);
      expect(inventory.walletReads, 1);
      expect(market.listingReads, 1);
      await tester.pageBack();
      await pumpDashboardHome(tester);
      expect(find.byType(AccountDashboard), findsNothing);
      expect(inventory.walletReads, 1);
      expect(market.listingReads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('wide Android home does not load the desktop overview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final inventory = _CountingInventory();
    final market = _CountingMarket();
    await tester.pumpWidget(
      dashboardHomePreviewApp(
        variant: AvaThemeVariant.light,
        mobile: true,
        inventory: inventory,
        market: market,
      ),
    );
    await pumpDashboardHome(tester);
    expect(find.byType(AccountDashboard), findsNothing);
    expect(inventory.walletReads, 0);
    expect(market.listingReads, 0);
    await tester.tap(find.text('demo_trading'));
    await pumpDashboardHome(tester);
    expect(find.byType(AccountDashboard), findsNothing);
    expect(find.byType(AccountDashboardScreen), findsNothing);
    expect(find.text('demo_trading'), findsNWidgets(2));
    expect(inventory.walletReads, 0);
    expect(market.listingReads, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'phone account menu scrolls with large translated labels on short screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        dashboardHomePreviewApp(
          variant: AvaThemeVariant.light,
          mobile: true,
          locale: const Locale('de'),
        ),
      );
      await pumpDashboardHome(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      await pumpDashboardHome(tester);
      expect(tester.takeException(), isNull, reason: 'before opening menu');
      await tester.ensureVisible(find.text('demo_trading'));
      await tester.longPress(find.text('demo_trading'));
      await pumpDashboardHome(tester);
      final l = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
      final last = find.descendant(
        of: find.byType(Dialog),
        matching: find.text(l.keyRedeemAction),
      );
      await tester.ensureVisible(last);
      await pumpDashboardHome(tester);
      expect(last.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
