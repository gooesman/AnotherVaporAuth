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
    'all grid profiles are one copied snapshot and reset removes them',
    () async {
      final store = SettingsStore(storage);
      final wide = {
        'wallet': {'column': 1, 'row': 2, 'columnSpan': 2, 'rowSpan': 6},
      };
      final phone = {
        'wallet': {'column': 0, 'row': 3, 'columnSpan': 1, 'rowSpan': 8},
      };
      final profiles = {1: phone};
      final saving = store.saveDashboardLayout(
        ['wallet'],
        {'wallet': 2},
        rects: wide,
        responsiveRects: profiles,
      );
      wide['wallet']!['row'] = 90;
      phone['wallet']!.clear();
      profiles.clear();
      await saving;
      expect(await SettingsStore(storage).loadDashboardLayout(), {
        'order': ['wallet'],
        'spans': {'wallet': 2},
        'rects': {
          'wallet': {'column': 1, 'row': 2, 'columnSpan': 2, 'rowSpan': 6},
        },
        'responsiveRects': {
          '1': {
            'wallet': {'column': 0, 'row': 3, 'columnSpan': 1, 'rowSpan': 8},
          },
        },
      });
      await store.saveDashboardLayout(['wallet'], {'wallet': 3});
      expect(await SettingsStore(storage).loadDashboardLayout(), {
        'order': ['wallet'],
        'spans': {'wallet': 3},
      });
    },
  );

  test(
    'failed geometry write cannot partially replace profiles or other settings',
    () async {
      final store = SettingsStore(storage);
      final grid = {
        'wallet': {'column': 1, 'row': 2, 'columnSpan': 2, 'rowSpan': 6},
      };
      await store.saveDashboardLayout(['wallet'], {'wallet': 2}, rects: grid);
      await store.saveLocale('zh');
      final before = await store.loadDashboardLayout();
      storage.failNextAccess = true;
      await expectLater(
        store.saveDashboardLayout(
          ['tools'],
          {'tools': 1},
          responsiveRects: {1: grid},
        ),
        throwsA(isA<FileSystemException>()),
      );
      final reopened = SettingsStore(storage);
      expect(await reopened.loadDashboardLayout(), before);
      expect(await reopened.loadLocale(), 'zh');
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
