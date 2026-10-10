import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/protocol/inventory_client.dart';
import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/friends/trade_inventory_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewer = '76561198000000001';
const _partner = '76561198000000002';

class _Inventory extends InventoryClient {
  final WalletInfo walletInfo;
  final viewers = <String>[];
  final owners = <String?>[];

  _Inventory({this.walletInfo = WalletInfo.fallback}) : super(SteamApiClient());

  @override
  Future<InventoryOverview> overview(
    SteamGuardAccount account, {
    String? ownerSteamId,
  }) async {
    viewers.add('${account.steamId}');
    owners.add(ownerSteamId);
    return InventoryOverview(const [
      InventoryGame(
        appid: 730,
        contextId: '2',
        name: 'Counter-Strike 2',
        iconUrl: '',
        itemCount: 1,
      ),
    ], walletInfo);
  }

  @override
  Future<InventoryPage> items(
    SteamGuardAccount account,
    int appid,
    String contextId, {
    String? ownerSteamId,
    String? startAssetId,
    int count = 75,
  }) async => const InventoryPage(
    [
      InventoryItem(
        appid: 730,
        contextId: '2',
        assetId: '22',
        classId: '100',
        instanceId: '0',
        amount: 3,
        marketHashName: 'SCAR-20 | Contractor (Field-Tested)',
        name: 'SCAR-20 | Contractor (Field-Tested)',
        type: 'Consumer Grade Sniper Rifle',
        iconUrl: '',
        // Tradable items may still have market references while unsellable.
        marketable: false,
        tradable: true,
      ),
    ],
    null,
    false,
  );
}

class _Market extends MarketClient {
  final requests = <(int, String, int)>[];

  _Market() : super(SteamApiClient());

  @override
  Future<MarketPrice?> priceOverview(
    int appid,
    String marketHashName,
    int currency,
  ) async {
    requests.add((appid, marketHashName, currency));
    return const MarketPrice(lowest: '12.34', median: '12.50', volume: 12);
  }
}

Future<void> _show(
  WidgetTester tester,
  _Inventory inventory,
  _Market market, {
  Size size = const Size(1100, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(MemoryStorageProvider('mock')),
        timeAlignerProvider.overrideWithValue(() async {}),
        inventoryClientProvider.overrideWithValue(inventory),
        marketClientProvider.overrideWithValue(market),
      ],
      child: MaterialApp(
        theme: buildAvaTheme(AvaThemeVariant.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: TradeInventoryPicker(
          account: SteamGuardAccount(
            session: SessionData(
              steamId: int.parse(_viewer),
              accessToken: 'fake',
            ),
          ),
          ownerSteamId: _partner,
          mine: false,
          selected: const [],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _selected(WidgetTester tester) =>
    tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value!;

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(TradeInventoryPicker)));

Future<void> _dismissMenu(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(TradeInventoryPicker))).pop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('partner inventory prices use the signed-in viewer currency', (
    tester,
  ) async {
    final inventory = _Inventory(
      walletInfo: WalletInfo.fromJson({'wallet_currency': 23}),
    );
    final market = _Market();
    await _show(tester, inventory, market);
    expect(inventory.viewers, [_viewer]);
    expect(inventory.owners, [_partner]);
    expect(market.requests, isEmpty);
    expect(_selected(tester), isFalse);

    await tester.tap(find.byKey(const ValueKey('item-actions-730/2/22')));
    await tester.pumpAndSettle();
    expect(_selected(tester), isFalse);
    expect(market.requests, isEmpty);
    await tester.tap(find.text(_l(tester).itemMarketViewPrice));
    await tester.pumpAndSettle();
    expect(market.requests, [(730, 'SCAR-20 | Contractor (Field-Tested)', 23)]);
    expect(_selected(tester), isFalse);
    expect(find.textContaining('12.34'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right-click and long press preserve selection and quantity', (
    tester,
  ) async {
    final market = _Market();
    await _show(tester, _Inventory(), market);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(_selected(tester), isTrue);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(
      find.text('SCAR-20 | Contractor (Field-Tested)'),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text(_l(tester).itemMarketViewPrice), findsOneWidget);
    expect(_selected(tester), isTrue);
    expect(find.text('2'), findsOneWidget);
    await _dismissMenu(tester);

    await tester.longPress(find.text('SCAR-20 | Contractor (Field-Tested)'));
    await tester.pumpAndSettle();
    expect(find.text(_l(tester).itemMarketViewPrice), findsOneWidget);
    expect(_selected(tester), isTrue);
    expect(find.text('2'), findsOneWidget);
    await _dismissMenu(tester);
    expect(market.requests, isEmpty);

    // Primary clicks still control selection after either context gesture.
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(_selected(tester), isFalse);
    expect(find.text('2'), findsNothing);
  });

  testWidgets(
    'narrow picker shows price without changing checkbox or overflow',
    (tester) async {
      final market = _Market();
      await _show(tester, _Inventory(), market, size: const Size(320, 740));
      await tester.tap(find.byKey(const ValueKey('item-actions-730/2/22')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l(tester).itemMarketViewPrice));
      await tester.pumpAndSettle();
      expect(market.requests.single.$3, 1);
      expect(find.textContaining('12.34'), findsWidgets);
      expect(_selected(tester), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
