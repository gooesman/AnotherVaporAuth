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
  Object? layout;
  Completer<Object?>? pendingLayoutLoad;
  Completer<void>? pendingLayoutSave;
  bool failLayout = false;
  int layoutWrites = 0;
  _Settings() : super(MemoryStorageProvider());

  @override
  Future<List<String>?> loadDashboardSections() => loaded.future;

  @override
  Future<void> saveDashboardSections(List<String> value) async {
    if (fail) throw StateError('Synthetic save failure');
    saved = [...value];
  }

  @override
  Future<Object?> loadDashboardLayout() async =>
      pendingLayoutLoad != null ? pendingLayoutLoad!.future : layout;

  @override
  Future<void> saveDashboardLayout(
    List<String> order,
    Map<String, int> spans, {
    Map<String, Map<String, int>> rects = const {},
    Map<int, Map<String, Map<String, int>>> responsiveRects = const {},
  }) async {
    if (pendingLayoutSave != null) await pendingLayoutSave!.future;
    if (failLayout) throw StateError('Synthetic layout save failure');
    layoutWrites++;
    layout = {
      'order': [...order],
      'spans': {...spans},
      'rects': rects,
      'responsiveRects': {
        for (final entry in responsiveRects.entries)
          '${entry.key}': entry.value,
      },
    };
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Settings settings, {
  double textScale = 1,
  Locale locale = const Locale('en'),
}) async {
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
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: DashboardCardsSettingsCard()),
        ),
      ),
    ),
  );
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(DashboardCardsSettingsCard)),
);

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

  testWidgets(
    'layout reset waits for saved arrangement and explains editing entry',
    (tester) async {
      final settings = _Settings()..pendingLayoutLoad = Completer<Object?>();
      settings.loaded.complete(['friends']);
      await _pump(tester, settings);
      await tester.pumpAndSettle();
      final reset = find.byKey(
        const ValueKey('dashboard-settings-reset-layout'),
      );
      expect(tester.widget<TextButton>(reset).onPressed, isNull);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      final l = AppLocalizations.of(
        tester.element(find.byType(DashboardCardsSettingsCard)),
      );
      expect(find.text(l.dashboardLayoutSettingsHint), findsOneWidget);
      settings.pendingLayoutLoad!.complete({
        'order': ['friends'],
        'spans': {'friends': 2},
      });
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(reset).onPressed, isNotNull);
      expect(
        _container(tester).read(dashboardLayoutProvider).order.first,
        'friends',
      );
      expect(settings.layoutWrites, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reset restores arrangement without changing visibility', (
    tester,
  ) async {
    final settings = _Settings()
      ..layout = {
        'order': ['friends', 'inventory', 'tools'],
        'spans': {'friends': 3, 'inventory': 2, 'tools': 1},
        'rects': {
          'friends': {'column': 0, 'row': 5, 'columnSpan': 3, 'rowSpan': 7},
        },
        'responsiveRects': {
          '1': {
            'friends': {'column': 0, 'row': 4, 'columnSpan': 1, 'rowSpan': 6},
          },
        },
      };
    settings.loaded.complete(['friends']);
    await _pump(tester, settings);
    await tester.pumpAndSettle();
    final reset = find.byKey(const ValueKey('dashboard-settings-reset-layout'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    final container = _container(tester);
    expect(
      container.read(dashboardLayoutProvider).order,
      DashboardLayout.defaultOrder,
    );
    expect(
      container.read(dashboardLayoutProvider).spans,
      DashboardLayout.defaultSpans,
    );
    expect(container.read(dashboardLayoutProvider).rects, isEmpty);
    expect(container.read(dashboardLayoutProvider).responsiveRects, isEmpty);
    expect(container.read(dashboardSectionsProvider), {'friends'});
    expect(settings.saved, isNull);
    expect(
      DashboardLayout.fromJson(settings.layout).order,
      DashboardLayout.defaultOrder,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed reset retains saved grid and explains the error', (
    tester,
  ) async {
    final settings = _Settings()
      ..failLayout = true
      ..layout = {
        'rects': {
          'wallet': {'column': 1, 'row': 4, 'columnSpan': 2, 'rowSpan': 7},
        },
      };
    settings.loaded.complete(null);
    await _pump(tester, settings);
    await tester.pumpAndSettle();
    final before = _container(tester).read(dashboardLayoutProvider).rects;
    final reset = find.byKey(const ValueKey('dashboard-settings-reset-layout'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(_container(tester).read(dashboardLayoutProvider).rects, before);
    expect(DashboardLayout.fromJson(settings.layout).rects, before);
    expect(find.text('Could not save the display preference.'), findsOneWidget);
    expect(settings.layoutWrites, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('393 wide settings fit enlarged Chinese text', (tester) async {
    final settings = _Settings();
    settings.loaded.complete(null);
    await _pump(tester, settings, textScale: 1.8, locale: const Locale('zh'));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(DashboardCardsSettingsCard)),
    );
    expect(find.text(l.dashboardLayoutSettingsHint), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    final reset = find.byKey(const ValueKey('dashboard-settings-reset-layout'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(settings.layoutWrites, 1);
    expect(tester.takeException(), isNull);
  });
}
