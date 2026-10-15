import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/ui/widgets/inventory_cooldown_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppLocalizations> _show(
  WidgetTester tester,
  List<InventoryRestriction> notes,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: InventoryCooldownInfo(
          item: InventoryItem(
            appid: 730,
            contextId: '2',
            assetId: 'locked',
            classId: '1',
            instanceId: '0',
            amount: 1,
            marketHashName: 'Rifle',
            name: 'Rifle',
            type: 'Rifle',
            iconUrl: '',
            marketable: false,
            tradable: false,
            restrictions: notes,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final l = AppLocalizations.of(
    tester.element(find.byType(InventoryCooldownInfo)),
  );
  await tester.tap(find.byKey(const ValueKey('inventory-cooldown-locked')));
  await tester.pumpAndSettle();
  return l;
}

void main() {
  testWidgets('unknown restriction keeps Steam text and never guesses a date', (
    tester,
  ) async {
    final l = await _show(tester, const [InventoryRestriction('交易受限，日期未提供')]);
    expect(find.text('交易受限，日期未提供'), findsOneWidget);
    expect(find.text(l.inventoryCooldownUnknown), findsOneWidget);
    expect(find.textContaining('Remaining:'), findsNothing);
    expect(find.textContaining('Cooldown until'), findsNothing);
  });

  testWidgets('expired date does not turn a locked item into a tradable one', (
    tester,
  ) async {
    final l = await _show(tester, [
      InventoryRestriction(
        'Tradable After [date]1577836800[/date]',
        until: DateTime.utc(2020, 1, 1),
        dateText: '[date]1577836800[/date]',
      ),
    ]);
    expect(find.text(l.inventoryCooldownElapsed), findsOneWidget);
    expect(find.text(l.inventoryCooldownNotTradable), findsOneWidget);
    expect(find.textContaining('Remaining:'), findsNothing);
    expect(find.textContaining('[date]'), findsNothing);
  });

  testWidgets('future date includes remaining time without a ticking timer', (
    tester,
  ) async {
    await _show(tester, [
      InventoryRestriction(
        'Tradable After [date]future[/date]',
        until: DateTime.now().add(const Duration(days: 2, hours: 3)),
        dateText: '[date]future[/date]',
      ),
    ]);
    expect(find.textContaining('Remaining: 2d'), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
