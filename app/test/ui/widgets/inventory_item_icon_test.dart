import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/ui/widgets/inventory_item_icon.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

InventoryItem _item({String color = '8847ff', String rarity = 'Restricted'}) =>
    InventoryItem(
      appid: 730,
      contextId: '2',
      assetId: '1',
      classId: '2',
      instanceId: '0',
      amount: 1,
      marketHashName: 'Test item',
      name: 'Test item',
      type: '',
      iconUrl: '',
      marketable: true,
      tradable: true,
      rarityColor: color,
      rarityName: rarity,
    );

Widget _app(Widget child, [AvaThemeVariant variant = AvaThemeVariant.light]) =>
    MaterialApp(
      theme: buildAvaTheme(variant),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('thumbnail fits list and grid constraints in every AVA skin', (
    tester,
  ) async {
    for (final variant in AvaThemeVariant.values) {
      await tester.pumpWidget(
        _app(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InventoryItemIcon(
                key: const ValueKey('list'),
                item: _item(),
                size: 44,
              ),
              SizedBox(
                width: 160,
                height: 112,
                child: InventoryItemIcon(
                  key: const ValueKey('grid'),
                  item: _item(),
                ),
              ),
              InventoryItemIcon(item: _item(color: 'invalid'), size: 44),
            ],
          ),
          variant,
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('list'))),
        const Size(44, 44),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('grid'))),
        const Size(160, 112),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('rarity tooltip does not swallow mobile item long press', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      _app(
        GestureDetector(
          onLongPress: () => presses++,
          child: InventoryItemIcon(item: _item(), size: 44),
        ),
      ),
    );
    await tester.longPress(find.byType(InventoryItemIcon));
    await tester.pumpAndSettle();
    expect(presses, 1);
    expect(find.text('Restricted'), findsNothing);
  });

  testWidgets('hover exposes Steam rarity label without changing selection', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        GestureDetector(
          onTap: () => taps++,
          child: InventoryItemIcon(item: _item(), size: 44),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(InventoryItemIcon)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Restricted'), findsOneWidget);
    expect(taps, 0);
    await mouse.removePointer();
    await tester.pumpAndSettle();
  });
}
