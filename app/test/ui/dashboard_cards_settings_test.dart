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
    Map<String, int> spans,
  ) async {
    if (pendingLayoutSave != null) await pendingLayoutSave!.future;
    if (failLayout) throw StateError('Synthetic layout save failure');
    layoutWrites++;
    layout = {
      'order': [...order],
      'spans': {...spans},
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

Finder _row(String section) =>
    find.byKey(ValueKey('dashboard-settings-row-$section'));

Future<void> _action(WidgetTester tester, String section, String action) async {
  final menu = find.byKey(ValueKey('dashboard-layout-menu-$section'));
  await tester.ensureVisible(menu);
  await tester.tap(menu);
  await tester.pumpAndSettle();
  final item = find.byWidgetPredicate(
    (widget) => widget is PopupMenuItem<String> && widget.value == action,
  );
  await tester.tap(item);
  await tester.pumpAndSettle();
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

  testWidgets('saved layout gates menus until loading completes', (
    tester,
  ) async {
    final settings = _Settings()..pendingLayoutLoad = Completer<Object?>();
    settings.loaded.complete(['friends']);
    await _pump(tester, settings);
    await tester.pumpAndSettle();
    expect(find.byType(ReorderableListView), findsNothing);
    final menu = find.byKey(const ValueKey('dashboard-layout-menu-friends'));
    expect(tester.widget<PopupMenuButton<String>>(menu).enabled, isFalse);
    settings.pendingLayoutLoad!.complete({
      'order': ['friends'],
      'spans': {'friends': 2},
    });
    await tester.pumpAndSettle();
    expect(tester.widget<PopupMenuButton<String>>(menu).enabled, isTrue);
    expect(
      tester.getTopLeft(_row('friends')).dy,
      lessThan(tester.getTopLeft(_row('wallet')).dy),
    );
    expect(settings.layoutWrites, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'up and down menus move a card between both ends without toggling it',
    (tester) async {
      final settings = _Settings();
      settings.loaded.complete(['wallet', 'friends']);
      await _pump(tester, settings);
      await tester.pumpAndSettle();
      for (var step = 0; step < 5; step++) {
        await _action(tester, 'wallet', 'down');
      }
      final order = _container(tester).read(dashboardLayoutProvider).order;
      expect(order, [
        'listings',
        'favorites',
        'friends',
        'inventory',
        'tools',
        'wallet',
      ]);
      expect(
        tester.getTopLeft(_row('wallet')).dy,
        greaterThan(tester.getTopLeft(_row('tools')).dy),
      );
      expect(DashboardLayout.fromJson(settings.layout).order, order);
      for (var step = 0; step < 5; step++) {
        await _action(tester, 'wallet', 'up');
      }
      final container = _container(tester);
      expect(
        container.read(dashboardLayoutProvider).order,
        DashboardLayout.defaultOrder,
      );
      expect(
        DashboardLayout.fromJson(settings.layout).order,
        DashboardLayout.defaultOrder,
      );
      expect(container.read(dashboardSectionsProvider), {'wallet', 'friends'});
      expect(
        tester.getTopLeft(_row('wallet')).dy,
        lessThan(tester.getTopLeft(_row('listings')).dy),
      );
      expect(settings.saved, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('row menu changes order and desktop width independently', (
    tester,
  ) async {
    final settings = _Settings();
    settings.loaded.complete(null);
    await _pump(tester, settings);
    await tester.pumpAndSettle();
    await _action(tester, 'wallet', 'down');
    expect(_container(tester).read(dashboardLayoutProvider).order.take(2), [
      'listings',
      'wallet',
    ]);
    await _action(tester, 'friends', '2');
    expect(
      _container(tester).read(dashboardLayoutProvider).spans['friends'],
      2,
    );
    final saved = DashboardLayout.fromJson(settings.layout);
    expect(saved.order.take(2), ['listings', 'wallet']);
    expect(saved.spans['friends'], 2);
    expect(settings.saved, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final (section, direction, target) in [
    ('listings', 'up', 'wallet'),
    ('inventory', 'down', 'tools'),
  ]) {
    testWidgets('stale $direction menu is safe after a card reaches the edge', (
      tester,
    ) async {
      final settings = _Settings()..pendingLayoutSave = Completer<void>();
      settings.loaded.complete(['wallet', 'friends']);
      await _pump(tester, settings);
      await tester.pumpAndSettle();
      await _action(tester, section, direction);
      expect(settings.layoutWrites, 0);

      final menu = find.byKey(ValueKey('dashboard-layout-menu-$section'));
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final item = find.byWidgetPredicate(
        (widget) =>
            widget is PopupMenuItem<String> && widget.value == direction,
      );
      expect(tester.widget<PopupMenuItem<String>>(item).enabled, isTrue);

      settings.pendingLayoutSave!.complete();
      await tester.pumpAndSettle();
      final expected = [...DashboardLayout.defaultOrder];
      final destination = expected.indexOf(target);
      expected.remove(section);
      expected.insert(destination, section);
      expect(_container(tester).read(dashboardLayoutProvider).order, expected);
      expect(tester.widget<PopupMenuItem<String>>(item).enabled, isTrue);
      await tester.tap(item);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_container(tester).read(dashboardLayoutProvider).order, expected);
      expect(DashboardLayout.fromJson(settings.layout).order, expected);
      expect(settings.layoutWrites, 1);
      expect(_container(tester).read(dashboardSectionsProvider), {
        'wallet',
        'friends',
      });
      expect(settings.saved, isNull);
    });
  }

  testWidgets('reset restores arrangement without changing visibility', (
    tester,
  ) async {
    final settings = _Settings()
      ..layout = {
        'order': ['friends', 'inventory', 'tools'],
        'spans': {'friends': 3, 'inventory': 2, 'tools': 1},
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
    expect(container.read(dashboardSectionsProvider), {'friends'});
    expect(settings.saved, isNull);
    expect(
      DashboardLayout.fromJson(settings.layout).order,
      DashboardLayout.defaultOrder,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout write failure retains order and shows a save error', (
    tester,
  ) async {
    final settings = _Settings()..failLayout = true;
    settings.loaded.complete(null);
    await _pump(tester, settings);
    await tester.pumpAndSettle();
    await _action(tester, 'wallet', 'down');
    expect(
      _container(tester).read(dashboardLayoutProvider).order,
      DashboardLayout.defaultOrder,
    );
    expect(find.text('Could not save the display preference.'), findsOneWidget);
    expect(settings.layout, isNull);
    expect(settings.layoutWrites, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('393 wide settings and width menu fit enlarged Chinese text', (
    tester,
  ) async {
    final settings = _Settings();
    settings.loaded.complete(null);
    await _pump(tester, settings, textScale: 1.8, locale: const Locale('zh'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final menu = find.byKey(const ValueKey('dashboard-layout-menu-favorites'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final width = find.byWidgetPredicate(
      (widget) => widget is PopupMenuItem<String> && widget.value == '2',
    );
    await tester.ensureVisible(width);
    await tester.tap(width);
    await tester.pumpAndSettle();
    expect(
      _container(tester).read(dashboardLayoutProvider).spans['favorites'],
      2,
    );
    expect(tester.takeException(), isNull);
  });
}
