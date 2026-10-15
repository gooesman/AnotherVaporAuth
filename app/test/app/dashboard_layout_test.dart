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
    Map<String, int> spans,
  ) async {
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
    };
  }

  @override
  Future<List<String>?> loadDashboardSections() async => sections;

  @override
  Future<void> saveDashboardSections(List<String> value) async =>
      sections = [...value];
}

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
  test('missing and malformed layouts preserve the previous arrangement', () {
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
    }
  });

  test(
    'unknown duplicate and invalid entries normalize to six valid cards',
    () {
      final layout = DashboardLayout.fromJson({
        'order': ['tools', 'invalid', null, 'friends', 'tools', 1],
        'spans': {
          'tools': 1,
          'friends': 2,
          'wallet': 0,
          'listings': 4,
          'inventory': 2.0,
          'favorites': '3',
          'invalid': 1,
        },
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
    },
  );

  test('layout collections are immutable independent snapshots', () {
    final order = ['tools'];
    final spans = {'tools': 1};
    final layout = DashboardLayout(order: order, spans: spans);
    order.clear();
    spans['tools'] = 3;
    expect(layout.order.first, 'tools');
    expect(layout.spans['tools'], 1);
    expect(() => layout.order.add('wallet'), throwsUnsupportedError);
    expect(() => layout.spans['tools'] = 3, throwsUnsupportedError);
  });

  test(
    'old visibility choices do not change and loading blocks edits',
    () async {
      final settings = _Settings()
        ..sections = ['favorites']
        ..pendingLoad = Completer<Object?>();
      final container = _container(settings);
      final controller = container.read(dashboardLayoutProvider.notifier);
      final sections = container.read(dashboardSectionsProvider.notifier);
      var notifications = 0;
      container.listen(dashboardLayoutProvider, (_, _) => notifications++);
      expect(controller.ready, isFalse);
      await Future.wait([
        controller.move('wallet', 'tools'),
        controller.setSpan('friends', 2),
        controller.reset(),
      ]);
      expect(settings.writes, 0);
      settings.pendingLoad!.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(controller.ready, isTrue);
      expect(sections.ready, isTrue);
      expect(notifications, 1);
      expect(
        container.read(dashboardLayoutProvider).order,
        DashboardLayout.defaultOrder,
      );
      expect(container.read(dashboardSectionsProvider), {'favorites'});
    },
  );

  test('move uses the target original index in either direction', () async {
    final settings = _Settings();
    final container = _container(settings);
    final controller = await _ready(container);
    await controller.move('wallet', 'friends');
    expect(container.read(dashboardLayoutProvider).order, [
      'listings',
      'favorites',
      'friends',
      'wallet',
      'inventory',
      'tools',
    ]);
    await controller.move('tools', 'favorites');
    expect(container.read(dashboardLayoutProvider).order, [
      'listings',
      'tools',
      'favorites',
      'friends',
      'wallet',
      'inventory',
    ]);
    expect(
      container.read(dashboardLayoutProvider).spans,
      DashboardLayout.defaultSpans,
    );
  });

  test(
    'queued moves and resizing persist without losing earlier changes',
    () async {
      final settings = _Settings()..pendingWrite = Completer<void>();
      final pending = settings.pendingWrite!;
      final container = _container(settings);
      final controller = await _ready(container);
      final first = controller.move('tools', 'wallet');
      final second = controller.setSpan('friends', 2);
      final third = controller.move('inventory', 'friends');
      await Future<void>.delayed(Duration.zero);
      expect(settings.writes, 1);
      expect(
        container.read(dashboardLayoutProvider).order,
        DashboardLayout.defaultOrder,
      );
      pending.complete();
      await Future.wait([first, second, third]);
      final layout = container.read(dashboardLayoutProvider);
      expect(layout.order, [
        'tools',
        'wallet',
        'listings',
        'favorites',
        'inventory',
        'friends',
      ]);
      expect(layout.spans['friends'], 2);
      final reopened = _container(settings);
      await _ready(reopened);
      expect(reopened.read(dashboardLayoutProvider).order, layout.order);
      expect(reopened.read(dashboardLayoutProvider).spans, layout.spans);
    },
  );

  test(
    'hiding and re-enabling a card preserves its position and span',
    () async {
      final settings = _Settings()..sections = ['wallet', 'friends'];
      final container = _container(settings);
      final sectionController = container.read(
        dashboardSectionsProvider.notifier,
      );
      final controller = await _ready(container);
      await controller.move('friends', 'wallet');
      await controller.setSpan('friends', 3);
      final before = container.read(dashboardLayoutProvider);
      await sectionController.toggle('friends');
      await sectionController.toggle('friends');
      expect(container.read(dashboardLayoutProvider), same(before));
      expect(container.read(dashboardLayoutProvider).order.first, 'friends');
      expect(container.read(dashboardLayoutProvider).spans['friends'], 3);
      expect(container.read(dashboardSectionsProvider), {'wallet', 'friends'});
    },
  );

  test(
    'failed layout write keeps state and later operations still save',
    () async {
      final settings = _Settings()..failNextWrite = true;
      final container = _container(settings);
      final controller = await _ready(container);
      final before = container.read(dashboardLayoutProvider);
      await expectLater(controller.move('tools', 'wallet'), throwsStateError);
      expect(container.read(dashboardLayoutProvider), same(before));
      expect(settings.saved, isNull);
      await controller.setSpan('inventory', 2);
      expect(
        container.read(dashboardLayoutProvider).order,
        DashboardLayout.defaultOrder,
      );
      expect(container.read(dashboardLayoutProvider).spans['inventory'], 2);
    },
  );

  test(
    'invalid edits do not write and reset restores order and widths only',
    () async {
      final settings = _Settings()..sections = ['friends'];
      final container = _container(settings);
      final controller = await _ready(container);
      await controller.move('invalid', 'wallet');
      await controller.move('wallet', 'invalid');
      await controller.move('wallet', 'wallet');
      await controller.setSpan('wallet', 0);
      await controller.setSpan('wallet', 4);
      await controller.setSpan('unknown', 2);
      await controller.setSpan('wallet', 3);
      expect(settings.writes, 0);
      await controller.move('tools', 'wallet');
      await controller.setSpan('tools', 1);
      await controller.reset();
      final reopened = _container(settings);
      await _ready(reopened);
      expect(
        reopened.read(dashboardLayoutProvider).order,
        DashboardLayout.defaultOrder,
      );
      expect(
        reopened.read(dashboardLayoutProvider).spans,
        DashboardLayout.defaultSpans,
      );
      expect(settings.sections, ['friends']);
    },
  );
}
