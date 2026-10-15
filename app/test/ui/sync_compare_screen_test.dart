import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/sync_providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/services/sync/sync_engine.dart';
import 'package:ava/src/ui/sync/sync_compare_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/sync_engine_test.dart'
    show Device, InMemoryServer, InMemoryTransport, kSubscription;

class _ScreenEngine extends SyncEngine {
  _ScreenEngine(Device device, this.preview)
    : super(
        configStore: device.configStore,
        accounts: device.port,
        trash: device.trash,
        deviceId: () async => 'widget',
        transportFactory: (_, _) => InMemoryTransport(InMemoryServer()),
      );
  final SyncComparison preview;
  bool? uploaded;
  @override
  Future<SyncComparison> compareWithRemote() async => preview;
  @override
  Future<void> applyComparison(
    SyncComparison preview,
    SyncComparisonItem item, {
    required bool upload,
  }) async {
    uploaded = upload;
  }
}

void main() {
  testWidgets(
    'phone comparison shows currency codes, hides secrets, waits for direction',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = (await tester.runAsync(() async {
        final device = Device(InMemoryServer(), 'widget-device');
        device.settingsPort.values['market_favorites'] = {
          'currency': 1,
          'items': [],
        };
        await device.engine.syncNow();
        device.settingsPort.values.addAll({
          'market_favorites': {'currency': 23, 'items': []},
          'steam_acceleration': kSubscription,
        });
        final preview = await device.engine.compareWithRemote();
        device.engine.dispose();
        return _ScreenEngine(device, preview);
      }))!;
      addTearDown(engine.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncEngineProvider.overrideWithValue(engine)],
          child: MaterialApp(
            theme: buildAvaTheme(AvaThemeVariant.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const SyncCompareScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('CNY'), findsOneWidget);
      expect(find.textContaining('USD'), findsOneWidget);
      expect(find.textContaining('fixture-token'), findsNothing);
      expect(find.textContaining('fixture-node-secret'), findsNothing);
      expect(engine.uploaded, isNull);
      await tester.ensureVisible(find.text('Pull remote → local'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pull remote → local'));
      await tester.pumpAndSettle();
      expect(engine.uploaded, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
