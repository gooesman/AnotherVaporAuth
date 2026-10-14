import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/market_favorites.dart';
import 'package:ava/src/app/steam_acceleration_providers.dart';
import 'package:ava/src/app/sync_providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/manifest.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/steam_acceleration.dart';
import 'package:ava/src/services/steam_acceleration_runtime.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/services/sync/sync_config_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _url = 'https://subscription.example.invalid/list?token=synthetic';
const _otherUrl = 'http://synthetic:password@other.example.invalid/list';
const _nodes = '''
proxies:
  - name: First test node
    type: ss
    server: first.example.invalid
    port: 443
    cipher: aes-128-gcm
    password: first-synthetic-secret
  - name: Second test node
    type: ss
    server: second.example.invalid
    port: 443
    cipher: aes-128-gcm
    password: second-synthetic-secret
''';

final _portProvider = Provider<AppSettingsPort>(AppSettingsPort.new);
const _favoriteDoc = {
  'currency': 23,
  'items': [
    {'appid': 440, 'market_hash_name': 'Key', 'name': 'Key',
      'icon_url': '', 'type': 'Tool', 'rarity_color': 'ffd700'},
  ],
};

class _Controller extends AppController {
  _Controller(this.initiallyLocked);
  final bool initiallyLocked;

  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(ref.read(storageProvider), Manifest(encrypted: true)),
    accounts: const [],
    locked: initiallyLocked,
  );

  void setLocked(bool locked) {
    state = AsyncData(state.requireValue.copyWith(locked: locked));
  }
}

class _SecureStore extends SteamAccelerationStore {
  _SecureStore(this.value);
  String? value;
  int reads = 0;
  int writes = 0;
  bool failWrite = false;
  Completer<void>? pendingRead;
  Completer<void>? pendingWrite;
  final readStarted = Completer<void>();
  final writeStarted = Completer<void>();

  @override
  Future<String?> read() async {
    reads++;
    if (!readStarted.isCompleted) readStarted.complete();
    await pendingRead?.future;
    return value;
  }

  @override
  Future<void> write(String value) async {
    writes++;
    if (failWrite) throw const FileSystemException('synthetic storage failure');
    if (!writeStarted.isCompleted) writeStarted.complete();
    await pendingWrite?.future;
    this.value = value;
  }

  @override
  Future<void> clear() async {
    writes++;
    value = null;
  }
}

class _Runtime implements SteamAccelerationRuntime {
  int starts = 0;
  int stops = 0;
  bool running = false;
  SteamAccelerationEnvironment environment = const SteamAccelerationEnvironment(
    detectionAvailable: true,
  );

  @override
  bool get supported => true;
  @override
  Future<SteamAccelerationEnvironment> detectEnvironment() async => environment;
  @override
  Future<bool> isRunning() async => running;
  @override
  Future<void> start(
    String configuration,
    SteamProxyEndpoint endpoint, {
    void Function(SteamAccelerationPhase)? onPhaseChanged,
  }) async {
    onPhaseChanged?.call(SteamAccelerationPhase.downloadingCore);
    onPhaseChanged?.call(SteamAccelerationPhase.starting);
    starts++;
    running = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }
}

class _Fixture {
  _Fixture._(
    this.directory,
    this.store,
    this.runtime,
    this.service,
    this.container,
  );
  final Directory directory;
  final _SecureStore store;
  final _Runtime runtime;
  final SteamAccelerationService service;
  final ProviderContainer container;
  int fetches = 0;
  bool _containerDisposed = false;

  AppSettingsPort get port => container.read(_portProvider);

  void disposeContainer() {
    if (_containerDisposed) return;
    _containerDisposed = true;
    container.dispose();
  }

  static Future<_Fixture> create({
    bool locked = false,
    bool configured = true,
  }) async {
    final directory = await Directory.systemTemp.createTemp('ava-proxy-sync-');
    final store = _SecureStore(
      configured
          ? jsonEncode({'v': 1, 'url': _url, 'auto': true, 'nodes': _nodes})
          : null,
    );
    final runtime = _Runtime();
    late _Fixture result;
    final service = SteamAccelerationService(
      store: store,
      runtime: runtime,
      fetchSubscription: (_) async {
        result.fetches++;
        return _nodes;
      },
      environmentInterval: const Duration(hours: 1),
    );
    final container = ProviderContainer(
      overrides: [
        storageProvider.overrideWithValue(
          DirectoryStorageProvider(p.join(directory.path, 'maFiles')),
        ),
        appControllerProvider.overrideWith(() => _Controller(locked)),
        steamAccelerationServiceProvider.overrideWithValue(service),
      ],
    );
    result = _Fixture._(directory, store, runtime, service, container);
    addTearDown(() async {
      result.disposeContainer();
      service.dispose();
      await directory.delete(recursive: true);
    });
    await container.read(appControllerProvider.future);
    return result;
  }
}

/// Captures only SyncEngine's five-second debounce. The real provider and
/// engine remain installed; no network, timer sleeps or test-only production
/// hooks are needed to observe which service events schedule a round.
class _DebounceTimer implements Timer {
  _DebounceTimer();
  bool cancelled = false;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
  @override
  void cancel() => cancelled = true;
}

void main() {
  test('settings snapshot and pull retain favorites and selected currency', () async {
    final fixture = await _Fixture.create();
    await fixture.port.apply({'market_favorites': _favoriteDoc});
    expect((await fixture.port.snapshot())!['market_favorites'], _favoriteDoc);
    await fixture.port.apply({'skin': AvaSkin.pixel.name});
    expect((await fixture.port.snapshot())!['market_favorites'], _favoriteDoc);
    expect(fixture.fetches, 0);
    expect(fixture.runtime.starts, 0);
  });

  test('malformed or unsavable subscription does not overwrite favorites', () async {
    final fixture = await _Fixture.create();
    await fixture.container.read(marketFavoritesProvider.notifier).applySynced(_favoriteDoc);
    final empty = {'currency': 1, 'items': <Object>[]};
    await expectLater(fixture.port.apply({
      'market_favorites': empty, 'steam_acceleration': {'v': 1, 'configured': true},
    }), throwsA(anything));
    expect((await fixture.port.snapshot())!['market_favorites'], _favoriteDoc);
    fixture.store.failWrite = true;
    await expectLater(fixture.port.apply({
      'market_favorites': empty,
      'steam_acceleration': {'v': 1, 'configured': true, 'url': _otherUrl},
    }), throwsA(anything));
    expect((await fixture.port.snapshot())!['market_favorites'], _favoriteDoc);
  });

  test('invalid favorites fails before changing the subscription', () async {
    final fixture = await _Fixture.create();
    await expectLater(fixture.port.apply({
      'market_favorites': {'currency': 23, 'items': 'invalid'},
      'steam_acceleration': {'v': 1, 'configured': false},
    }), throwsFormatException);
    expect(fixture.store.writes, 0);
  });
  test(
    'an explicit preference change wins over a delayed cold-start read',
    () async {
      final fixture = await _Fixture.create();
      final pending = Completer<bool>();
      bool? saved;
      final preference =
          NotifierProvider<PersistedSettingController<bool>, bool>(
            () => PersistedSettingController(
              true,
              (_) => pending.future,
              (_, value) async => saved = value,
            ),
          );
      expect(fixture.container.read(preference), isTrue);
      await fixture.container.read(preference.notifier).set(false);
      expect(saved, isFalse);
      pending.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(fixture.container.read(preference), isFalse);
    },
  );

  test(
    'snapshot reads saved portable subscription and cached selected node',
    () async {
      final fixture = await _Fixture.create();
      final document = (await fixture.port.snapshot())!;
      final proxy = document['steam_acceleration'] as Map<String, dynamic>;
      expect(proxy['v'], 1);
      expect(proxy['configured'], isTrue);
      expect(proxy['url'], _url);
      expect(proxy['nodes'], contains('first-synthetic-secret'));
      expect(proxy['selected'], fixture.service.state.selectedNodeId);
      expect(
        proxy.keys,
        unorderedEquals(['v', 'configured', 'url', 'nodes', 'selected']),
      );
      expect(fixture.service.state.autoStart, isTrue);
      expect(fixture.fetches, 0);
      expect(fixture.runtime.starts, 0);
      expect(fixture.store.reads, 1);
      expect(document['skin'], AvaSkin.none.name);
    },
  );

  test(
    'apply imports portable fields before normal settings without starting networking',
    () async {
      final fixture = await _Fixture.create();
      await fixture.service.load();
      final selected = fixture.service.state.nodes.last.id;
      await fixture.port.apply({
        'steam_acceleration': {
          'v': 1,
          'configured': true,
          'url': _otherUrl,
          'nodes': _nodes,
          'selected': selected,
        },
        'skin': AvaSkin.pixel.name,
        'haptics': false,
      });
      final exported = await fixture.service.exportSyncConfiguration();
      expect(exported['url'], _otherUrl);
      expect(exported['selected'], selected);
      expect(fixture.service.state.autoStart, isTrue);
      expect(fixture.service.state.phase, SteamAccelerationPhase.off);
      expect(fixture.container.read(skinProvider), AvaSkin.pixel);
      expect(fixture.container.read(hapticsProvider), isFalse);
      expect(fixture.fetches, 0);
      expect(fixture.runtime.starts, 0);
      final disk = await File(
        p.join(fixture.directory.path, 'app_settings.json'),
      ).readAsString();
      expect(disk, isNot(contains('synthetic-secret')));
      expect(disk, isNot(contains('example.invalid')));
      expect(jsonDecode(fixture.store.value!)['url'], _otherUrl);
    },
  );

  test(
    'older settings document preserves an existing subscription and node',
    () async {
      final fixture = await _Fixture.create();
      final before = await fixture.service.exportSyncConfiguration();
      final stored = fixture.store.value;
      await fixture.port.apply({'skin': AvaSkin.neon.name});
      expect(await fixture.service.exportSyncConfiguration(), before);
      expect(fixture.store.value, stored);
      expect(fixture.store.writes, 0);
      expect(fixture.container.read(skinProvider), AvaSkin.neon);
    },
  );

  test(
    'explicit remote deletion clears portable configuration while preserving local auto setting',
    () async {
      final fixture = await _Fixture.create();
      await fixture.port.apply({
        'steam_acceleration': {'v': 1, 'configured': false},
      });
      expect(await fixture.service.exportSyncConfiguration(), {
        'v': 1,
        'configured': false,
      });
      expect(fixture.service.state.configured, isFalse);
      expect(fixture.service.state.autoStart, isTrue);
      expect(fixture.fetches, 0);
      expect(fixture.runtime.starts, 0);
    },
  );

  for (final (index, malformed) in <Object?>[
    null,
    {'v': 2, 'configured': false},
    {'v': 1, 'configured': true, 'url': 'file:///synthetic'},
    {'v': 1, 'configured': true, 'url': _otherUrl, 'nodes': 123},
    {'v': 1, 'configured': false, 'url': _url},
  ].indexed) {
    test('malformed subscription $index leaves all settings intact', () async {
      final fixture = await _Fixture.create();
      final before = await fixture.port.snapshot();
      final stored = fixture.store.value;
      await expectLater(
        fixture.port.apply({
          'steam_acceleration': malformed,
          'skin': AvaSkin.pixel.name,
          'haptics': false,
        }),
        throwsA(isA<SteamAccelerationException>()),
      );
      expect(await fixture.port.snapshot(), before);
      expect(fixture.store.value, stored);
      expect(fixture.store.writes, 0);
    });
  }

  test(
    'secure storage failure cannot partially apply ordinary preferences',
    () async {
      final fixture = await _Fixture.create();
      final before = await fixture.port.snapshot();
      fixture.store.failWrite = true;
      await expectLater(
        fixture.port.apply({
          'steam_acceleration': {'v': 1, 'configured': true, 'url': _otherUrl},
          'skin': AvaSkin.pixel.name,
        }),
        throwsA(isA<SteamAccelerationException>()),
      );
      expect(await fixture.port.snapshot(), before);
    },
  );

  test(
    'locked snapshot returns null without reading subscription credentials',
    () async {
      final fixture = await _Fixture.create(locked: true);
      expect(await fixture.port.snapshot(), isNull);
      expect(fixture.store.reads, 0);
      expect(fixture.fetches, 0);
    },
  );

  test(
    'locking during a delayed secret read invalidates the snapshot',
    () async {
      final fixture = await _Fixture.create();
      fixture.store.pendingRead = Completer<void>();
      final pending = fixture.port.snapshot();
      await fixture.store.readStarted.future;
      (fixture.container.read(appControllerProvider.notifier) as _Controller)
          .setLocked(true);
      fixture.store.pendingRead!.complete();
      expect(await pending, isNull);
    },
  );

  test('locked apply refuses credentials and ordinary preferences', () async {
    final fixture = await _Fixture.create(locked: true);
    final stored = fixture.store.value;
    await expectLater(
      fixture.port.apply({
        'steam_acceleration': {'v': 1, 'configured': true, 'url': _otherUrl},
        'skin': AvaSkin.pixel.name,
      }),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'safe message',
          'Sync settings unavailable',
        ),
      ),
    );
    expect(fixture.store.value, stored);
    expect(fixture.store.reads, 0);
    expect(fixture.store.writes, 0);
    expect(
      await fixture.container.read(settingsStoreProvider).loadSkin(),
      isNull,
    );
  });

  test(
    'lock during subscription save stops the rest of the settings pull',
    () async {
      final fixture = await _Fixture.create();
      await fixture.service.load();
      fixture.store.pendingWrite = Completer<void>();
      final applying = fixture.port.apply({
        'steam_acceleration': {'v': 1, 'configured': true, 'url': _otherUrl},
        'skin': AvaSkin.pixel.name,
      });
      final checked = expectLater(applying, throwsA(isA<StateError>()));
      await fixture.store.writeStarted.future;
      (fixture.container.read(appControllerProvider.notifier) as _Controller)
          .setLocked(true);
      fixture.store.pendingWrite!.complete();
      await checked;
      expect(jsonDecode(fixture.store.value!)['url'], _otherUrl);
      expect(
        await fixture.container.read(settingsStoreProvider).loadSkin(),
        isNull,
      );
      expect(fixture.runtime.starts, 0);
      expect(fixture.fetches, 0);
    },
  );

  test(
    'provider debounces committed config changes, ignores runtime and auto-start, detaches on dispose',
    () async {
      final timers = <_DebounceTimer>[];
      await runZoned(
        () async {
          final fixture = await _Fixture.create(configured: false);
          await SyncConfigStore(
            fixture.container.read(storageProvider),
          ).saveConfig(
            const SyncConfig(
              url: 'https://sync.example.invalid/unused/',
              username: 'synthetic',
              deviceName: 'test',
              autoSync: false,
            ),
          );
          final engine = fixture.container.read(syncEngineProvider);
          await engine.statusStream.firstWhere((status) => status.configured);
          await Future<void>.delayed(Duration.zero);
          expect(timers, isEmpty);
          await fixture.service.load();
          await fixture.service.checkEnvironment();
          expect(timers, isEmpty);
          await fixture.service.configure(subscriptionUrl: _url);
          expect(timers, hasLength(1));
          await fixture.service.refreshSubscription();
          expect(timers, hasLength(2));
          expect(timers.first.isActive, isFalse);
          await fixture.service.selectNode(fixture.service.state.nodes.last.id);
          expect(timers, hasLength(3));
          expect(timers[1].isActive, isFalse);
          await fixture.service.setAutoStart(true);
          await fixture.service.start();
          expect(fixture.service.state.phase, SteamAccelerationPhase.running);
          await fixture.service.checkEnvironment();
          await fixture.service.stop();
          fixture.runtime.environment = const SteamAccelerationEnvironment(
            detectionAvailable: true,
            vpnOrTunnelDetected: true,
          );
          await fixture.service.checkEnvironment();
          expect(timers, hasLength(3));
          await fixture.service.clearConfiguration();
          expect(timers, hasLength(4));
          fixture.disposeContainer();
          expect(timers.last.isActive, isFalse);
          await fixture.service.configure(subscriptionUrl: _otherUrl);
          expect(timers, hasLength(4));
        },
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            if (duration == const Duration(seconds: 5)) {
              final timer = _DebounceTimer();
              timers.add(timer);
              return timer;
            }
            return parent.createTimer(zone, duration, callback);
          },
        ),
      );
    },
  );
}
