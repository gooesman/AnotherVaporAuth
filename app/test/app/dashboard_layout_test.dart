import 'dart:async';

import 'package:ava/src/app/dashboard_sections.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Settings extends SettingsStore {
  _Settings() : super(MemoryStorageProvider());
  Object? saved;
  List<String>? sections;
  Completer<Object?>? pendingLoad;
  Completer<void>? pendingWrite;
  bool failNextWrite = false;
  int writes = 0;

  @override
  Future<Object?> loadDashboardLayout() async =>
      pendingLoad != null ? pendingLoad!.future : saved;

  @override
  Future<void> saveDashboardLayout(
    List<String> order,
    Map<String, int> spans, {
    Map<String, Map<String, int>> rects = const {},
    Map<int, Map<String, Map<String, int>>> responsiveRects = const {},
  }) async {
    writes++;
    final pending = pendingWrite;
    pendingWrite = null;
    if (pending != null) await pending.future;
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Synthetic layout write failure');
    }
    saved = {
      'order': [...order],
      'spans': {...spans},
      'rects': rects,
      'responsiveRects': {
        for (final entry in responsiveRects.entries)
          '${entry.key}': entry.value,
      },
    };
  }

  @override
  Future<List<String>?> loadDashboardSections() async => sections;

  @override
  Future<void> saveDashboardSections(List<String> value) async =>
      sections = [...value];
}

DashboardGridRect _rect(int column, int row, int width, int height) =>
    DashboardGridRect(
      column: column,
      row: row,
      columnSpan: width,
      rowSpan: height,
    );

ProviderContainer _container(_Settings settings) {
  final container = ProviderContainer(
    overrides: [settingsStoreProvider.overrideWithValue(settings)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<DashboardLayoutController> _ready(ProviderContainer container) async {
  final notifier = container.read(dashboardLayoutProvider.notifier);
  await Future<void>.delayed(Duration.zero);
  expect(notifier.ready, isTrue);
  return notifier;
}

void main() {
  test('missing and malformed layouts retain the legacy defaults', () {
    for (final saved in [
      null,
      true,
      1,
      'bad',
      [],
      {'order': 1, 'spans': []},
    ]) {
      final layout = DashboardLayout.fromJson(saved);
      expect(layout.order, DashboardLayout.defaultOrder);
      expect(layout.spans, DashboardLayout.defaultSpans);
      expect(layout.rects, isEmpty);
      expect(layout.responsiveRects, isEmpty);
    }
  });

  test('legacy order and spans migrate without materializing hidden cells', () {
    final layout = DashboardLayout.fromJson({
      'order': ['tools', 'invalid', null, 'friends', 'tools', 1],
      'spans': {'tools': 1, 'friends': 2, 'wallet': 0, 'listings': 4},
    });
    expect(layout.order, [
      'tools',
      'friends',
      'wallet',
      'listings',
      'favorites',
      'inventory',
    ]);
    expect(layout.spans, {
      ...DashboardLayout.defaultSpans,
      'tools': 1,
      'friends': 2,
    });
    expect(layout.rects, isEmpty);
    final displayed = resolveDashboardGrid(
      order: layout.order,
      spans: layout.spans,
      rects: layout.gridForColumns(3),
      visible: ['tools', 'wallet'],
    );
    expect(displayed['tools']!.row, 0);
    expect(displayed['wallet']!.row, displayed['tools']!.bottom);
  });

  test('malformed geometry and unknown profiles are discarded or bounded', () {
    final layout = DashboardLayout.fromJson({
      'rects': {
        'wallet': _rect(-2, -1, 99, 0).toJson(),
        'friends': {'column': 0, 'row': '1', 'columnSpan': 1, 'rowSpan': 3},
        'unknown': _rect(0, 0, 1, 3).toJson(),
      },
      'responsiveRects': {
        '1': {'wallet': _rect(2, 999, 3, 999).toJson()},
        '2': {'unknown': _rect(0, 0, 1, 3).toJson()},
        '4': {'wallet': _rect(0, 0, 1, 3).toJson()},
      },
    });
    expect(layout.rects, {'wallet': _rect(0, 0, 3, 3)});
    expect(layout.responsiveRects.keys, [1]);
    expect(layout.responsiveRects[1]!['wallet'], _rect(0, 232, 1, 24));
    expect(layout.gridForColumns(2), same(layout.rects));
  });

  test('layout collections are immutable independent snapshots', () {
    final order = ['tools'];
    final spans = {'tools': 1};
    final rects = {'tools': _rect(1, 2, 1, 4)};
    final narrow = {'tools': _rect(0, 3, 1, 6)};
    final layout = DashboardLayout(
      order: order,
      spans: spans,
      rects: rects,
      responsiveRects: {1: narrow},
    );
    order.clear();
    spans.clear();
    rects.clear();
    narrow.clear();
    expect(layout.order.first, 'tools');
    expect(layout.spans['tools'], 1);
    expect(layout.rects['tools'], _rect(1, 2, 1, 4));
    expect(layout.responsiveRects[1]!['tools'], _rect(0, 3, 1, 6));
    expect(() => layout.order.add('wallet'), throwsUnsupportedError);
    expect(() => layout.spans['tools'] = 3, throwsUnsupportedError);
    expect(() => layout.rects.clear(), throwsUnsupportedError);
    expect(() => layout.responsiveRects[1]!.clear(), throwsUnsupportedError);
  });

  test(
    'loading blocks edits and old visibility choices remain unchanged',
    () async {
      final settings = _Settings()
        ..sections = ['favorites']
        ..pendingLoad = Completer<Object?>();
      final container = _container(settings);
      final controller = container.read(dashboardLayoutProvider.notifier);
      final sections = container.read(dashboardSectionsProvider.notifier);
      var notifications = 0;
      container.listen(dashboardLayoutProvider, (_, _) => notifications++);
      await controller.saveGrid({'wallet': _rect(0, 1, 3, 4)});
      await controller.reset();
      expect(settings.writes, 0);
      settings.pendingLoad!.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(controller.ready, isTrue);
      expect(sections.ready, isTrue);
      expect(notifications, 1);
      expect(container.read(dashboardSectionsProvider), {'favorites'});
    },
  );

  test(
    'one gesture atomically saves all displaced cards and reopens',
    () async {
      final settings = _Settings()..pendingWrite = Completer<void>();
      final pending = settings.pendingWrite!;
      final container = _container(settings);
      final controller = await _ready(container);
      final before = container.read(dashboardLayoutProvider);
      final result = relocateDashboardGrid(
        current: {'wallet': _rect(0, 0, 3, 4), 'tools': _rect(0, 4, 3, 4)},
        section: 'tools',
        target: _rect(1, 1, 2, 6),
      );
      final saving = controller.saveGrid(result);
      await Future<void>.delayed(Duration.zero);
      expect(settings.writes, 1);
      expect(container.read(dashboardLayoutProvider), same(before));
      pending.complete();
      await saving;
      expect(container.read(dashboardLayoutProvider).rects, result);
      expect(container.read(dashboardLayoutProvider).spans['tools'], 2);
      final reopened = _container(settings);
      await _ready(reopened);
      expect(reopened.read(dashboardLayoutProvider).rects, result);
      expect(
        reopened.read(dashboardLayoutProvider).order,
        DashboardLayout.defaultOrder,
      );
    },
  );

  test('queued visible deltas keep earlier and hidden card geometry', () async {
    final settings = _Settings()..pendingWrite = Completer<void>();
    final pending = settings.pendingWrite!;
    final container = _container(settings);
    final controller = await _ready(container);
    final first = controller.saveGrid({'wallet': _rect(0, 1, 2, 4)});
    final delta = {'friends': _rect(2, 8, 1, 8)};
    final second = controller.saveGrid(delta);
    delta.clear();
    final third = controller.saveGrid({'tools': _rect(0, 2, 1, 5)}, columns: 1);
    await Future<void>.delayed(Duration.zero);
    expect(settings.writes, 1);
    pending.complete();
    await Future.wait([first, second, third]);
    final layout = container.read(dashboardLayoutProvider);
    expect(settings.writes, 3);
    expect(layout.rects, {
      'wallet': _rect(0, 1, 2, 4),
      'friends': _rect(2, 8, 1, 8),
    });
    expect(
      layout.responsiveRects[1]!.keys,
      containsAll(['wallet', 'friends', 'tools']),
    );
    expect(layout.responsiveRects[1]!['tools'], _rect(0, 2, 1, 5));
  });

  test(
    'narrow projections do not write and each edited width persists independently',
    () async {
      final settings = _Settings();
      final container = _container(settings);
      final controller = await _ready(container);
      final desktop = {
        'wallet': _rect(1, 3, 2, 4),
        'friends': _rect(0, 9, 1, 6),
      };
      await controller.saveGrid(desktop);
      for (final columns in [1, 2]) {
        final layout = container.read(dashboardLayoutProvider);
        resolveDashboardGrid(
          order: layout.order,
          spans: layout.spans,
          rects: layout.gridForColumns(columns),
          visible: desktop.keys,
          columns: columns,
        );
      }
      expect(settings.writes, 1);
      await controller.saveGrid({'wallet': _rect(1, 2, 1, 6)}, columns: 2);
      expect(
        container.read(dashboardLayoutProvider).gridForColumns(1),
        same(container.read(dashboardLayoutProvider).responsiveRects[2]),
      );
      await controller.saveGrid({'wallet': _rect(0, 12, 1, 8)}, columns: 1);
      final reopened = _container(settings);
      await _ready(reopened);
      final layout = reopened.read(dashboardLayoutProvider);
      expect(layout.rects, desktop);
      expect(layout.responsiveRects[2]!['wallet'], _rect(1, 2, 1, 6));
      expect(layout.responsiveRects[1]!['wallet'], _rect(0, 12, 1, 8));
      expect(layout.spans['wallet'], 2);
    },
  );

  test('hiding and re-enabling a card preserves all saved profiles', () async {
    final settings = _Settings()..sections = ['wallet', 'friends'];
    final container = _container(settings);
    final sectionController = container.read(
      dashboardSectionsProvider.notifier,
    );
    final controller = await _ready(container);
    await controller.saveGrid({'friends': _rect(2, 7, 1, 8)});
    await controller.saveGrid({'friends': _rect(0, 15, 1, 10)}, columns: 1);
    final before = container.read(dashboardLayoutProvider);
    await sectionController.toggle('friends');
    await sectionController.toggle('friends');
    expect(container.read(dashboardLayoutProvider), same(before));
    expect(container.read(dashboardSectionsProvider), {'wallet', 'friends'});
  });

  test(
    'failed geometry save leaves state and disk intact and queue recovers',
    () async {
      final settings = _Settings();
      final container = _container(settings);
      final controller = await _ready(container);
      await controller.saveGrid({'tools': _rect(2, 5, 1, 6)});
      final before = container.read(dashboardLayoutProvider);
      final saved = settings.saved;
      settings.failNextWrite = true;
      await expectLater(
        controller.saveGrid({'tools': _rect(0, 0, 3, 10)}),
        throwsStateError,
      );
      expect(container.read(dashboardLayoutProvider), same(before));
      expect(settings.saved, same(saved));
      await controller.saveGrid({'inventory': _rect(0, 12, 2, 8)});
      expect(
        container.read(dashboardLayoutProvider).rects['tools'],
        before.rects['tools'],
      );
      expect(
        container.read(dashboardLayoutProvider).rects['inventory'],
        _rect(0, 12, 2, 8),
      );
    },
  );

  test(
    'invalid and unchanged edits do not write; reset clears grids not visibility',
    () async {
      final settings = _Settings()..sections = ['friends'];
      final container = _container(settings);
      final controller = await _ready(container);
      await controller.saveGrid({});
      await controller.saveGrid({'unknown': _rect(0, 0, 1, 3)});
      await controller.saveGrid({'wallet': _rect(0, 0, 1, 3)}, columns: 4);
      expect(settings.writes, 0);
      final grid = {'wallet': _rect(0, 0, 1, 3)};
      await controller.saveGrid(grid);
      await controller.saveGrid(grid);
      expect(settings.writes, 1);
      await controller.saveGrid(grid, columns: 1);
      await controller.reset();
      final reopened = _container(settings);
      await _ready(reopened);
      final layout = reopened.read(dashboardLayoutProvider);
      expect(layout.order, DashboardLayout.defaultOrder);
      expect(layout.spans, DashboardLayout.defaultSpans);
      expect(layout.rects, isEmpty);
      expect(layout.responsiveRects, isEmpty);
      expect(settings.sections, ['friends']);
    },
  );
}
