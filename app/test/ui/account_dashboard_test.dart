import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/protocol/inventory_client.dart';
import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/account_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Settings extends SettingsStore {
  List<String>? sections;
  _Settings() : super(MemoryStorageProvider());
  @override
  Future<List<String>?> loadDashboardSections() async => sections;
  @override
  Future<void> saveDashboardSections(List<String> value) async {
    sections = value;
  }
}

class _Controller extends AppController {
  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(MemoryStorageProvider()),
    accounts: [_account(1), _account(2)],
    locked: false,
  );

  void lockForTest() =>
      state = AsyncData(state.requireValue.copyWith(locked: true));

  void removeForTest() =>
      state = AsyncData(state.requireValue.copyWith(accounts: []));
}

class _Inventory extends InventoryClient {
  final Map<int, Future<WalletInfo>> wallets;
  int calls = 0;
  _Inventory(this.wallets) : super(SteamApiClient());
  @override
  Future<WalletInfo> wallet(SteamGuardAccount account) {
    calls++;
    return wallets[account.steamId]!;
  }
}

class _Market extends MarketClient {
  int calls = 0;
  Future<List<MarketListing>>? pending;
  _Market() : super(SteamApiClient());
  @override
  Future<List<MarketListing>> myListings(
    SteamGuardAccount account, {
    int count = 100,
  }) async {
    calls++;
    if (pending != null) return pending!;
    return [
      MarketListing.fromJson({
        'listingid': '17',
        'price': 200,
        'fee': 30,
        'currencyid': 2023,
        'active': 0,
        'asset': {'appid': 730, 'name': 'Synthetic held item'},
      }, state: MarketListingState.onHold),
    ];
  }
}

WalletInfo _wallet(int? amount) =>
    WalletInfo.fromJson({'wallet_currency': 23, 'wallet_balance': ?amount});
SteamGuardAccount _account(int id) => SteamGuardAccount(
  accountName: 'demo_$id',
  session: SessionData(steamId: id, accessToken: 'synthetic'),
);

Widget _app(
  Widget child,
  _Inventory inventory,
  _Market market,
  _Settings settings,
) => ProviderScope(
  overrides: [
    inventoryClientProvider.overrideWithValue(inventory),
    marketClientProvider.overrideWithValue(market),
    settingsStoreProvider.overrideWithValue(settings),
    appControllerProvider.overrideWith(_Controller.new),
  ],
  child: MaterialApp(
    theme: buildAvaTheme(AvaThemeVariant.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: child is AccountDashboardScreen
        ? child
        : Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets(
    'local account and completed listings render while wallet waits',
    (tester) async {
      final wallet = Completer<WalletInfo>();
      final actions = <String>[];
      await tester.pumpWidget(
        _app(
          AccountDashboardScreen(account: _account(1), onAction: actions.add),
          _Inventory({1: wallet.future}),
          _Market(),
          _Settings(),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('demo_1'), findsOneWidget);
      expect(find.text('SteamID 1'), findsOneWidget);
      expect(find.text('Synthetic held item'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dashboard-wallet-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard-listings-loading')),
        findsNothing,
      );
      await tester.ensureVisible(find.text('Synthetic held item'));
      await tester.pump();
      await tester.tap(find.text('Synthetic held item'));
      expect(actions, ['listings']);
      await tester.pump(const Duration(seconds: 12));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dashboard-wallet-loading')),
        findsNothing,
      );
      expect(find.text('Synthetic held item'), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wallet renders before slow listings and leaving cancels its wait',
    (tester) async {
      final market = _Market()
        ..pending = Completer<List<MarketListing>>().future;
      await tester.pumpWidget(
        _app(
          AccountDashboard(account: _account(1), onAction: (_) {}),
          _Inventory({1: Future.value(_wallet(12345))}),
          market,
          _Settings(),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('CNY 123.45'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dashboard-wallet-loading')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('dashboard-listings-loading')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved hidden cards do not fetch and toggling starts only that card',
    (tester) async {
      final inventory = _Inventory({1: Future.value(_wallet(12345))});
      final market = _Market();
      final settings = _Settings()..sections = ['tools'];
      await tester.pumpWidget(
        _app(
          AccountDashboard(account: _account(1), onAction: (_) {}),
          inventory,
          market,
          settings,
        ),
      );
      await tester.pumpAndSettle();
      expect(inventory.calls, 0);
      expect(market.calls, 0);
      await tester.tap(find.byTooltip('Choose overview cards'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckedPopupMenuItem<String>).first);
      await tester.pumpAndSettle();
      expect(inventory.calls, 1);
      expect(market.calls, 0);
      expect(find.text('CNY 123.45'), findsOneWidget);
    },
  );

  testWidgets(
    'equivalent account rebuild reuses reads and lock clears balances',
    (tester) async {
      final inventory = _Inventory({1: Future.value(_wallet(12345))});
      final market = _Market();
      final selected = ValueNotifier(_account(1));
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<SteamGuardAccount>(
            valueListenable: selected,
            builder: (_, account, _) =>
                AccountDashboard(account: account, onAction: (_) {}),
          ),
          inventory,
          market,
          _Settings(),
        ),
      );
      await tester.pumpAndSettle();
      selected.value = _account(1);
      await tester.pumpAndSettle();
      expect(inventory.calls, 1);
      expect(market.calls, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AccountDashboard)),
      );
      (container.read(appControllerProvider.notifier) as _Controller)
          .lockForTest();
      await tester.pumpAndSettle();
      expect(find.text('CNY 123.45'), findsNothing);
      expect(inventory.calls, 1);
      expect(market.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows wallet and held listings with explicit currency and opens listings',
    (tester) async {
      final actions = <String>[];
      await tester.pumpWidget(
        _app(
          AccountDashboard(account: _account(1), onAction: actions.add),
          _Inventory({1: Future.value(_wallet(12345))}),
          _Market(),
          _Settings(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CNY 123.45'), findsOneWidget);
      expect(find.text('On hold 1'), findsOneWidget);
      expect(find.text('CNY 2.30'), findsOneWidget);
      await tester.ensureVisible(find.text('Synthetic held item'));
      await tester.tap(find.text('Synthetic held item'));
      expect(actions, ['listings']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late wallet result cannot overwrite the next selected account', (
    tester,
  ) async {
    final lateWallet = Completer<WalletInfo>();
    final inventory = _Inventory({
      1: lateWallet.future,
      2: Future.value(_wallet(8900)),
    });
    final market = _Market();
    final settings = _Settings();
    final selected = ValueNotifier(_account(1));
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<SteamGuardAccount>(
          valueListenable: selected,
          builder: (_, account, _) =>
              AccountDashboard(account: account, onAction: (_) {}),
        ),
        inventory,
        market,
        settings,
      ),
    );
    await tester.pump();
    selected.value = _account(2);
    await tester.pumpAndSettle();
    lateWallet.complete(_wallet(100));
    await tester.pumpAndSettle();
    expect(find.text('CNY 89.00'), findsOneWidget);
    expect(find.text('CNY 1.00'), findsNothing);
    expect(
      market.calls,
      2,
      reason: 'Both accounts start their cards in parallel',
    );
  });

  testWidgets(
    'unknown balance is not displayed as zero and compact mode skips listings',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final market = _Market();
      await tester.pumpWidget(
        _app(
          AccountDashboard(
            account: _account(1),
            compact: true,
            onAction: (_) {},
          ),
          _Inventory({1: Future.value(_wallet(null))}),
          market,
          _Settings(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Unavailable'), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
      expect(market.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('display options persist and hide a card', (tester) async {
    final settings = _Settings();
    await tester.pumpWidget(
      _app(
        AccountDashboard(account: _account(1), onAction: (_) {}),
        _Inventory({1: Future.value(_wallet(12345))}),
        _Market(),
        settings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose overview cards'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<String>).first);
    await tester.pumpAndSettle();
    expect(settings.sections, isNot(contains('wallet')));
    expect(find.byKey(const ValueKey('wallet-balance')), findsNothing);
    expect(find.text('Synthetic held item'), findsOneWidget);
  });
}
