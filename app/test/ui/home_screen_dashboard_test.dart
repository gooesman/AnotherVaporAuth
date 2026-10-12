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
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
  @override
  Future<List<String>?> loadDashboardSections() async => null;
}

class _PreviewController extends AppController {
  final StorageProvider storage;
  final List<SteamGuardAccount> accounts;
  _PreviewController(this.storage, this.accounts);
  @override
  Future<AppData> build() async =>
      AppData(store: AccountStore(storage), accounts: accounts, locked: false);
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
  TargetPlatform? platform,
  Locale locale = const Locale('en'),
  SkinSpec? skinSpec,
  InventoryClient? inventory,
  MarketClient? market,
  SteamApiClient? api,
  List<SteamGuardAccount>? accounts,
  Stream<int>? ticks,
  bool disableAnimations = true,
  AppController Function(StorageProvider, List<SteamGuardAccount>)?
  controllerFactory,
}) {
  final storage = MemoryStorageProvider();
  final tokens = AvaTokens.of(variant);
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      storageProvider.overrideWithValue(storage),
      settingsStoreProvider.overrideWithValue(_PreviewSettings(storage)),
      appControllerProvider.overrideWith(
        () => (controllerFactory ?? _PreviewController.new)(
          storage,
          accounts ?? homePreviewAccounts,
        ),
      ),
      apiClientProvider.overrideWithValue(api ?? _PreviewApi()),
      inventoryClientProvider.overrideWithValue(
        inventory ?? _PreviewInventory(),
      ),
      marketClientProvider.overrideWithValue(market ?? _PreviewMarket()),
      tickProvider.overrideWith((ref) => ticks ?? Stream.value(1900000010)),
      timeAlignerProvider.overrideWithValue(() async {}),
      skinSpecProvider.overrideWith(() => _PreviewSkin(skinSpec)),
      proStatusProvider.overrideWithValue(ProStatus.pro),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAvaTheme(variant).copyWith(
        platform:
            platform ??
            (mobile ? TargetPlatform.android : TargetPlatform.windows),
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
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
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
  for (final (platform, size) in [
    (TargetPlatform.windows, const Size(1400, 900)),
    (TargetPlatform.windows, const Size(393, 852)),
    (TargetPlatform.macOS, const Size(1400, 900)),
    (TargetPlatform.linux, const Size(1400, 900)),
  ]) {
    testWidgets(
      '${platform.name} ${size.width} account rows stay still on horizontal '
      'drag and retain right-click actions',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          dashboardHomePreviewApp(
            variant: AvaThemeVariant.light,
            platform: platform,
          ),
        );
        await pumpDashboardHome(tester);
        final row = find.text('demo_trading');
        final originalCenter = tester.getCenter(row);
        for (final dx in [-120.0, 120.0]) {
          await tester.timedDrag(
            row,
            Offset(dx, 0),
            const Duration(milliseconds: 500),
          );
          await pumpDashboardHome(tester);
          expect(tester.getCenter(row), originalCenter);
          expect(find.byType(CustomSlidableAction), findsNothing);
        }
        final l = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
        await tester.tap(row, buttons: kSecondaryMouseButton);
        await pumpDashboardHome(tester);
        final menu = find.byType(PopupMenuItem<String>);
        for (final label in [
          l.dashboardTitle,
          l.actionConfirmations,
          l.commonRefresh,
          l.commonExport,
          l.commonDelete,
        ]) {
          expect(
            find.descendant(of: menu, matching: find.text(label)),
            findsOneWidget,
          );
        }
        await tester.tap(
          find.descendant(of: menu, matching: find.text(l.dashboardTitle)),
        );
        await pumpDashboardHome(tester);
        expect(find.byType(AccountDashboardScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final (platform, size) in [
    (TargetPlatform.android, const Size(393, 852)),
    (TargetPlatform.android, const Size(900, 500)),
    (TargetPlatform.iOS, const Size(393, 852)),
  ]) {
    testWidgets(
      '${platform.name} ${size.width} account rows keep both swipe actions',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          dashboardHomePreviewApp(
            variant: AvaThemeVariant.light,
            platform: platform,
          ),
        );
        await pumpDashboardHome(tester);
        final row = find.text('demo_trading');
        final originalCenter = tester.getCenter(row);
        final l = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
        await tester.timedDrag(
          row,
          const Offset(-120, 0),
          const Duration(milliseconds: 500),
        );
        await pumpDashboardHome(tester);
        expect(tester.getCenter(row).dx, lessThan(originalCenter.dx));
        expect(find.text(l.commonExport), findsOneWidget);
        expect(find.text(l.commonDelete), findsOneWidget);
        await Slidable.of(tester.element(row))!.close(duration: Duration.zero);
        await tester.pump();
        await tester.timedDrag(
          row,
          const Offset(70, 0),
          const Duration(milliseconds: 500),
        );
        await pumpDashboardHome(tester);
        expect(tester.getCenter(row).dx, greaterThan(originalCenter.dx));
        expect(find.text(l.actionConfirmations), findsOneWidget);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

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
            expect(find.byType(Dialog), findsNothing);
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
    'phone taps select tokens and long press opens overview without a menu',
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

      // The large selected-account avatar follows the same phone convention:
      // a tap cannot accidentally leave the token screen.
      await tester.tap(find.byKey(const ValueKey('selected-account-avatar')));
      await pumpDashboardHome(tester);
      expect(find.byType(AccountDashboardScreen), findsNothing);
      expect(inventory.walletReads, 0);
      expect(market.listingReads, 0);

      await tester.tap(find.text('demo_trading'));
      await pumpDashboardHome(tester);
      expect(inventory.walletReads, 0);
      expect(market.listingReads, 0);
      await tester.longPress(find.text('demo_trading').last);
      await pumpDashboardHome(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AccountDashboardScreen), findsOneWidget);
      expect(
        tester
            .widget<AccountDashboardScreen>(find.byType(AccountDashboardScreen))
            .account
            .steamId,
        homePreviewAccounts[1].steamId,
      );
      expect(find.text('CNY 89.00'), findsOneWidget);
      expect(inventory.walletReads, 1);
      expect(market.listingReads, 1);
      await tester.pageBack();
      await pumpDashboardHome(tester);
      expect(find.byType(AccountDashboard), findsNothing);
      expect(inventory.walletReads, 1);
      expect(market.listingReads, 1);
      await tester.longPress(
        find.byKey(const ValueKey('selected-account-avatar')),
      );
      await pumpDashboardHome(tester);
      expect(find.byType(AccountDashboardScreen), findsOneWidget);
      expect(
        tester
            .widget<AccountDashboardScreen>(find.byType(AccountDashboardScreen))
            .account
            .steamId,
        homePreviewAccounts[1].steamId,
      );
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
    // In two-column layout the sidebar precedes the token header.
    await tester.longPress(find.text('demo_trading').first);
    await pumpDashboardHome(tester);
    expect(find.byType(AccountDashboardScreen), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(inventory.walletReads, 1);
    expect(market.listingReads, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'phone opens overview directly with large labels on short screens',
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
      expect(tester.takeException(), isNull, reason: 'before opening overview');
      await tester.ensureVisible(find.text('demo_trading'));
      await tester.longPress(find.text('demo_trading'));
      await pumpDashboardHome(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AccountDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
