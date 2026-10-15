import 'dart:io';

import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Storage extends StorageProvider {
  _Storage(this.path);
  final String path;
  bool failNextAccess = false;
  @override
  Future<String> maFilesDir() async {
    if (failNextAccess) {
      failNextAccess = false;
      throw const FileSystemException('Synthetic storage failure');
    }
    return p.join(path, 'maFiles');
  }
}

void main() {
  late Directory temp;
  late _Storage storage;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ava-layout-store-');
    storage = _Storage(temp.path);
  });
  tearDown(() => temp.delete(recursive: true));

  test(
    'layout persists snapshots separately from existing preferences',
    () async {
      final store = SettingsStore(storage);
      expect(await store.loadDashboardLayout(), isNull);
      final order = ['friends', 'wallet'];
      final spans = {'friends': 2, 'wallet': 3};
      final saving = store.saveDashboardLayout(order, spans);
      order.clear();
      spans['friends'] = 1;
      await Future.wait([
        saving,
        store.saveDashboardSections(['friends']),
        store.saveLocale('zh'),
      ]);
      final reopened = SettingsStore(storage);
      expect(await reopened.loadDashboardLayout(), {
        'order': ['friends', 'wallet'],
        'spans': {'friends': 2, 'wallet': 3},
      });
      expect(await reopened.loadDashboardSections(), ['friends']);
      expect(await reopened.loadLocale(), 'zh');
    },
  );

  test(
    'failed disk write throws and leaves persisted layout untouched',
    () async {
      final store = SettingsStore(storage);
      await store.saveDashboardLayout(['wallet'], {'wallet': 3});
      storage.failNextAccess = true;
      await expectLater(
        store.saveDashboardLayout(['friends'], {'friends': 2}),
        throwsA(isA<FileSystemException>()),
      );
      expect(await store.loadDashboardLayout(), {
        'order': ['wallet'],
        'spans': {'wallet': 3},
      });
      await store.saveDashboardLayout(['inventory'], {'inventory': 2});
      expect(await SettingsStore(storage).loadDashboardLayout(), {
        'order': ['inventory'],
        'spans': {'inventory': 2},
      });
    },
  );

  test(
    'failed prerequisite read throws and preserves unrelated settings',
    () async {
      final seed = SettingsStore(storage);
      await seed.saveLocale('zh');
      await seed.saveDashboardLayout(['friends'], {'friends': 2});
      final store = SettingsStore(storage);
      storage.failNextAccess = true;
      await expectLater(
        store.saveDashboardLayout(['wallet'], {'wallet': 3}),
        throwsA(isA<SettingsReadException>()),
      );
      final reopened = SettingsStore(storage);
      expect(await reopened.loadLocale(), 'zh');
      expect(await reopened.loadDashboardLayout(), {
        'order': ['friends'],
        'spans': {'friends': 2},
      });
    },
  );
}
