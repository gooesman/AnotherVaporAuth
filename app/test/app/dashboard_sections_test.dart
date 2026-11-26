import 'dart:async';

import 'package:ava/src/app/dashboard_sections.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Settings extends SettingsStore {
  List<String>? saved;
  Completer<List<String>?>? pendingLoad;
  Completer<void>? pendingWrite;
  bool failNextWrite = false;
  final writes = <List<String>>[];
  _Settings({this.saved}) : super(MemoryStorageProvider());

  @override
  Future<List<String>?> loadDashboardSections() async =>
      pendingLoad != null ? pendingLoad!.future : saved;

  @override
  Future<void> saveDashboardSections(List<String> sections) async {
    writes.add([...sections]);
    final pending = pendingWrite;
    pendingWrite = null;
    if (pending != null) await pending.future;
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Synthetic save failure');
    }
    saved = [...sections];
  }
}

ProviderContainer _container(_Settings settings) => ProviderContainer(
  overrides: [settingsStoreProvider.overrideWithValue(settings)],
);

Future<DashboardSections> _ready(ProviderContainer container) async {
  final notifier = container.read(dashboardSectionsProvider.notifier);
  await Future<void>.delayed(Duration.zero);
  expect(notifier.ready, isTrue);
  return notifier;
}

void main() {
  test('new cards are opt-in and existing choices stay compatible', () async {
    final defaults = _container(_Settings());
    addTearDown(defaults.dispose);
    await _ready(defaults);
    expect(defaults.read(dashboardSectionsProvider), {
      'wallet',
      'listings',
      'tools',
    });

    final legacy = _container(_Settings(saved: ['wallet', 'tools']));
    addTearDown(legacy.dispose);
    await _ready(legacy);
    expect(legacy.read(dashboardSectionsProvider), {'wallet', 'tools'});

    final selected = _container(
      _Settings(saved: ['friends', 'inventory', 'favorites', 'unknown']),
    );
    addTearDown(selected.dispose);
    await _ready(selected);
    expect(selected.read(dashboardSectionsProvider), {
      'friends',
      'inventory',
      'favorites',
    });
  });

  test('loading blocks changes and completion notifies listeners', () async {
    final settings = _Settings()..pendingLoad = Completer<List<String>?>();
    final container = _container(settings);
    addTearDown(container.dispose);
    var notifications = 0;
    container.listen(dashboardSectionsProvider, (_, _) => notifications++);
    final notifier = container.read(dashboardSectionsProvider.notifier);
    expect(notifier.ready, isFalse);
    await notifier.toggle('friends');
    expect(settings.writes, isEmpty);
    settings.pendingLoad!.complete(['wallet', 'listings', 'tools']);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.ready, isTrue);
    expect(notifications, 1);
  });

  test(
    'rapid switches persist serially without dropping other choices',
    () async {
      final settings = _Settings()..pendingWrite = Completer<void>();
      final pending = settings.pendingWrite!;
      final container = _container(settings);
      addTearDown(container.dispose);
      final notifier = await _ready(container);
      final friends = notifier.toggle('friends');
      final inventory = notifier.toggle('inventory');
      final favorites = notifier.toggle('favorites');
      await Future<void>.delayed(Duration.zero);
      expect(settings.writes, hasLength(1));
      pending.complete();
      await Future.wait([friends, inventory, favorites]);
      expect(container.read(dashboardSectionsProvider), DashboardSections.all);
      expect(settings.saved!.toSet(), DashboardSections.all);
      expect(settings.writes, hasLength(3));
      final reopened = _container(settings);
      addTearDown(reopened.dispose);
      await _ready(reopened);
      expect(reopened.read(dashboardSectionsProvider), DashboardSections.all);
    },
  );

  test(
    'failed save keeps visible state and does not block later writes',
    () async {
      final settings = _Settings()..failNextWrite = true;
      final container = _container(settings);
      addTearDown(container.dispose);
      final notifier = await _ready(container);
      final failed = notifier.toggle('friends');
      final next = notifier.toggle('inventory');
      await expectLater(failed, throwsStateError);
      await next;
      expect(container.read(dashboardSectionsProvider), {
        ...DashboardSections.defaults,
        'inventory',
      });
      expect(settings.saved!.toSet(), {
        ...DashboardSections.defaults,
        'inventory',
      });
    },
  );

  test('unknown cards never write and all cards can stay disabled', () async {
    final settings = _Settings(saved: []);
    final container = _container(settings);
    addTearDown(container.dispose);
    final notifier = await _ready(container);
    expect(container.read(dashboardSectionsProvider), isEmpty);
    await notifier.toggle('unknown');
    expect(settings.writes, isEmpty);
    expect(container.read(dashboardSectionsProvider), isEmpty);
  });
}
