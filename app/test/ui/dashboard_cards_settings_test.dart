import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/dashboard_sections.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Settings extends SettingsStore {
  final loaded = Completer<List<String>?>();
  List<String>? saved;
  bool fail = false;
  _Settings() : super(MemoryStorageProvider());

  @override
  Future<List<String>?> loadDashboardSections() => loaded.future;

  @override
  Future<void> saveDashboardSections(List<String> value) async {
    if (fail) throw StateError('Synthetic save failure');
    saved = [...value];
  }
}

Future<void> _pump(WidgetTester tester, _Settings settings) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsStoreProvider.overrideWithValue(settings)],
      child: MaterialApp(
        theme: buildAvaTheme(AvaThemeVariant.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(
          body: SingleChildScrollView(child: DashboardCardsSettingsCard()),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('six switches wait for saved choices and persist selections', (
    tester,
  ) async {
    final settings = _Settings();
    await _pump(tester, settings);
    expect(find.byType(SwitchListTile), findsNWidgets(6));
    for (final tile in tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    )) {
      expect(tile.onChanged, isNull);
    }
    settings.loaded.complete(null);
    await tester.pumpAndSettle();
    for (final section in DashboardSections.all) {
      final finder = find.byKey(ValueKey('dashboard-section-$section'));
      final tile = tester.widget<SwitchListTile>(finder);
      expect(tile.onChanged, isNotNull);
      expect(tile.value, DashboardSections.defaults.contains(section));
    }
    final favorites = find.byKey(const ValueKey('dashboard-section-favorites'));
    await tester.ensureVisible(favorites);
    await tester.tap(favorites);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(favorites).value, isTrue);
    expect(settings.saved!.toSet(), {
      ...DashboardSections.defaults,
      'favorites',
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('save failures explain the error without changing the switch', (
    tester,
  ) async {
    final settings = _Settings()..fail = true;
    settings.loaded.complete([]);
    await _pump(tester, settings);
    await tester.pumpAndSettle();
    final friends = find.byKey(const ValueKey('dashboard-section-friends'));
    await tester.tap(friends);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(friends).value, isFalse);
    expect(find.text('Could not save the display preference.'), findsOneWidget);
    expect(settings.saved, isNull);
    expect(tester.takeException(), isNull);
  });
}
