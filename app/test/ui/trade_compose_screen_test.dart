import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_friend.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/models/trade_draft.dart';
import 'package:ava/src/core/protocol/inventory_client.dart';
import 'package:ava/src/core/protocol/trade_offers_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/friends/trade_compose_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _owner = '76561198000000001';
const _partner = '76561198000000002';

class _Inventory extends InventoryClient {
  final owners = <String>[];
  _Inventory() : super(SteamApiClient());
  @override
  Future<InventoryOverview> overview(
    SteamGuardAccount account, {
    String? ownerSteamId,
  }) async {
    owners.add(ownerSteamId!);
    return const InventoryOverview([
      InventoryGame(
        appid: 730,
        contextId: '2',
        name: 'CS2',
        iconUrl: '',
        itemCount: 1,
      ),
    ], WalletInfo.fallback);
  }

  @override
  Future<InventoryPage> items(
    SteamGuardAccount account,
    int appid,
    String contextId, {
    String? ownerSteamId,
    String? startAssetId,
    int count = 75,
  }) async => InventoryPage(
    [
      InventoryItem(
        appid: 730,
        contextId: '2',
        assetId: ownerSteamId == _owner ? '11' : '22',
        classId: '100',
        instanceId: '0',
        amount: 1,
        marketHashName: '',
        name: ownerSteamId == _owner ? 'My skin' : 'Their skin',
        type: '',
        iconUrl: '',
        marketable: true,
        tradable: true,
      ),
    ],
    null,
    false,
  );
}

class _Trade extends TradeOffersClient {
  int sends = 0;
  TradeDraft? draft;
  Object? error;
  Completer<TradeSendResult>? pending;
  _Trade() : super(SteamApiClient());
  @override
  Future<TradeSendResult> send(
    SteamGuardAccount account,
    TradeDraft draft,
  ) async {
    sends++;
    this.draft = draft;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return const TradeSendResult(offerId: '123', needsMobileConfirmation: true);
  }
}

Future<void> _show(
  WidgetTester tester,
  _Inventory inventory,
  _Trade trade, {
  SteamGuardAccount? account,
}) async {
  tester.view.physicalSize = const Size(1100, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(MemoryStorageProvider('mock')),
        timeAlignerProvider.overrideWithValue(() async {}),
        inventoryClientProvider.overrideWithValue(inventory),
        tradeOffersClientProvider.overrideWithValue(trade),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TradeComposeScreen(
                      account:
                          account ??
                          SteamGuardAccount(
                            session: SessionData(
                              steamId: int.parse(_owner),
                              accessToken: 'fake',
                            ),
                          ),
                      partner: const SteamFriend(
                        steamId: _partner,
                        name: 'Test friend',
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, bool mine) async {
  await tester.tap(find.text('Select items').at(mine ? 0 : 1));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trade-selection-done')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'receive-only offer stays bound to the sending account shown during review',
    (tester) async {
      final account = SteamGuardAccount(
        accountName: 'Sending A',
        session: SessionData(steamId: int.parse(_owner), accessToken: 'fake'),
      );
      final trade = _Trade();
      await _show(tester, _Inventory(), trade, account: account);
      await _select(tester, false);
      await tester.tap(find.byKey(const ValueKey('trade-review')));
      await tester.pumpAndSettle();
      expect(find.text('Sending account'), findsOneWidget);
      expect(find.text('Sending A'), findsOneWidget);
      expect(find.text('SteamID: $_owner'), findsOneWidget);
      account.session.steamId = 76561198000000003;
      await tester.tap(find.byKey(const ValueKey('trade-confirm-send')));
      await tester.pumpAndSettle();
      expect(trade.sends, 0);
      expect(
        find.textContaining('This is a different Steam account.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'system back cannot discard a send in progress or trigger a duplicate',
    (tester) async {
      final trade = _Trade()..pending = Completer<TradeSendResult>();
      await _show(tester, _Inventory(), trade);
      await _select(tester, true);
      await tester.tap(find.byKey(const ValueKey('trade-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trade-confirm-send')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(trade.sends, 1);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TradeComposeScreen), findsOneWidget);
      final review = tester.widget<FilledButton>(
        find.byKey(const ValueKey('trade-review')),
      );
      expect(review.onPressed, isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TradeComposeScreen), findsOneWidget);
      expect(trade.sends, 1);
      trade.pending!.complete(const TradeSendResult(offerId: '123'));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(trade.sends, 1);
    },
  );
  testWidgets(
    'both inventories keep their owner and cancellation sends nothing',
    (tester) async {
      final inventory = _Inventory();
      final trade = _Trade();
      await _show(tester, inventory, trade);
      await _select(tester, true);
      await _select(tester, false);
      expect(inventory.owners, [_owner, _partner]);
      await tester.tap(find.byKey(const ValueKey('trade-review')));
      await tester.pumpAndSettle();
      expect(find.text('SteamID: $_partner'), findsNWidgets(2));
      expect(find.textContaining('My skin × 1'), findsOneWidget);
      expect(find.textContaining('Their skin × 1'), findsOneWidget);
      expect(trade.sends, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(trade.sends, 0);
      await tester.tap(find.byKey(const ValueKey('trade-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trade-confirm-send')));
      await tester.pumpAndSettle();
      expect(trade.sends, 1);
      expect(trade.draft!.give.single.ownerSteamId, _owner);
      expect(trade.draft!.receive.single.ownerSteamId, _partner);
      expect(find.text('Open'), findsOneWidget);
    },
  );
  testWidgets('gift is explicit and ambiguous send cannot be blindly retried', (
    tester,
  ) async {
    final trade = _Trade()..error = Exception('connection lost after send');
    await _show(tester, _Inventory(), trade);
    await _select(tester, true);
    await tester.tap(find.byKey(const ValueKey('trade-review')));
    await tester.pumpAndSettle();
    expect(
      find.text('You are giving these items away and will receive nothing.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('trade-confirm-send')));
    await tester.pumpAndSettle();
    expect(trade.sends, 1);
    expect(find.textContaining('The send result is unknown.'), findsOneWidget);
    expect(find.byKey(const ValueKey('trade-review')), findsNothing);
    expect(find.text('View pending & offers'), findsOneWidget);
  });
}
