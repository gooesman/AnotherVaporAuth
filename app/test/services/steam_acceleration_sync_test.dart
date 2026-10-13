import 'dart:async';
import 'dart:convert';

import 'package:ava/src/services/steam_acceleration.dart';
import 'package:ava/src/services/steam_acceleration_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

const _url =
    'http://fixture:password@subscription.example.invalid/list?token=fixture-token';
const _nodes = '''
proxies:
  - name: First
    type: ss
    server: first.example.invalid
    port: 443
    cipher: aes-128-gcm
    password: fixture-node-secret
  - name: Second
    type: trojan
    server: second.example.invalid
    port: 443
    password: fixture-second-secret
tun: {enable: true}
external-controller: 0.0.0.0:9090
rules: [MATCH,DIRECT]
''';

class _Store extends SteamAccelerationStore {
  String? value;
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('private diagnostic');
    return value;
  }

  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('private diagnostic');
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _Runtime implements SteamAccelerationRuntime {
  int starts = 0;
  int stops = 0;
  bool running = false;
  Completer<void>? nextStop;
  Completer<void>? stopEntered;
  @override
  bool get supported => true;
  @override
  Future<SteamAccelerationEnvironment> detectEnvironment() async =>
      const SteamAccelerationEnvironment(detectionAvailable: true);
  @override
  Future<bool> isRunning() async => running;
  @override
  Future<void> start(
    String configuration,
    SteamProxyEndpoint endpoint, {
    void Function(SteamAccelerationPhase phase)? onPhaseChanged,
  }) async {
    starts++;
    running = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    final pending = nextStop;
    nextStop = null;
    if (pending != null) {
      stopEntered?.complete();
      await pending.future;
    }
    running = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;
  late _Runtime runtime;
  late SteamAccelerationService service;
  var fetches = 0;
  SteamAccelerationService make(_Store store, _Runtime runtime) {
    final result = SteamAccelerationService(
      store: store,
      runtime: runtime,
      environmentInterval: const Duration(hours: 1),
      fetchSubscription: (_) async {
        fetches++;
        return _nodes;
      },
    );
    addTearDown(result.dispose);
    return result;
  }

  setUp(() {
    store = _Store();
    runtime = _Runtime();
    fetches = 0;
    service = make(store, runtime);
  });
  Future<void> configured({bool auto = false}) async {
    await service.configure(subscriptionUrl: _url, autoStart: auto);
    await service.refreshSubscription();
    await service.selectNode(service.state.nodes.last.id);
  }

  test(
    'a queued node choice cannot corrupt a concurrently imported catalog',
    () async {
      await configured();
      final staleNode = service.state.nodes.first.id;
      final pendingStop = Completer<void>();
      runtime.nextStop = pendingStop;
      runtime.stopEntered = Completer<void>();
      final selection = service.selectNode(staleNode);
      await runtime.stopEntered!.future;
      final imported = service.applySyncConfiguration({
        'v': 1,
        'configured': true,
        'url': 'https://new.example.invalid/subscription',
        'nodes': _nodes.replaceAll('.example.invalid', '.new.example.invalid'),
      });
      // The import queues behind the blocked stop; selectNode must re-check
      // against that imported catalog when its own persist action gets a turn.
      await Future<void>.delayed(Duration.zero);
      pendingStop.complete();
      await Future.wait([selection, imported]);
      final current = await service.exportSyncConfiguration();
      expect(current['selected'], service.state.nodes.first.id);
      expect(current['selected'], isNot(staleNode));
      final reloaded = make(store, _Runtime());
      expect(await reloaded.exportSyncConfiguration(), current);
      await service.start();
      expect(service.state.phase, SteamAccelerationPhase.running);
    },
  );

  test(
    'exports portable credentials and selection, never runtime or policy',
    () async {
      await configured(auto: true);
      await service.start();
      final doc = await service.exportSyncConfiguration();
      expect(doc.keys.toSet(), {'v', 'configured', 'url', 'nodes', 'selected'});
      expect(doc['url'], _url);
      expect(doc['selected'], service.state.nodes.last.id);
      final cache = jsonDecode(doc['nodes'] as String) as Map;
      expect(cache.keys, ['proxies']);
      expect(cache['proxies'], hasLength(2));
      expect(jsonEncode(doc), contains('fixture-node-secret'));
      expect(jsonEncode(doc), isNot(contains(service.proxyEndpoint!.password)));
      expect(jsonEncode(doc), isNot(contains('external-controller')));
      expect(jsonEncode(doc), isNot(contains('tun')));
    },
  );

  test(
    'cross-device import persists without network or startup and keeps local auto',
    () async {
      await configured();
      final doc = await service.exportSyncConfiguration();
      final targetStore = _Store();
      final targetRuntime = _Runtime();
      final target = make(targetStore, targetRuntime);
      await target.configure(
        subscriptionUrl: 'https://old.example.invalid/sub',
        autoStart: true,
      );
      final beforeFetches = fetches;
      await target.applySyncConfiguration(doc);
      expect(await target.exportSyncConfiguration(), doc);
      expect(target.state.autoStart, isTrue);
      expect(target.proxyEndpoint, isNull);
      expect(targetRuntime.starts, 0);
      expect(fetches, beforeFetches);
      await target.start(automatic: true);
      expect(targetRuntime.starts, 0); // A pull must not activate routing.
      final reloaded = make(targetStore, _Runtime());
      expect(await reloaded.exportSyncConfiguration(), doc);
      expect(reloaded.state.autoStart, isTrue);
    },
  );

  test(
    'explicit remote clear persists across reload without resetting local auto',
    () async {
      await configured(auto: true);
      await service.start();
      await service.applySyncConfiguration({'v': 1, 'configured': false});
      expect(service.state.configured, isFalse);
      expect(service.state.autoStart, isTrue);
      expect(runtime.running, isFalse);
      expect(service.proxyEndpoint, isNull);
      final reloaded = make(store, _Runtime());
      expect(await reloaded.exportSyncConfiguration(), {
        'v': 1,
        'configured': false,
      });
      expect(reloaded.state.autoStart, isTrue);
      await reloaded.start(automatic: true);
      expect(reloaded.state.phase, SteamAccelerationPhase.off);
    },
  );

  test(
    'invalid imports cannot stop or overwrite an existing connection',
    () async {
      await configured();
      await service.start();
      final original = store.value;
      final stops = runtime.stops;
      for (final doc in [
        null,
        {'v': 2, 'configured': false},
        {'v': 1, 'configured': 'false'},
        {'v': 1, 'configured': false, 'url': _url},
        {'v': 1, 'configured': true, 'url': 'file:///secret'},
        {
          'v': 1,
          'configured': true,
          'url': _url,
          'nodes': 'private invalid yaml',
        },
        {'v': 1, 'configured': true, 'url': _url, 'selected': 1},
      ]) {
        await expectLater(
          service.applySyncConfiguration(doc),
          throwsA(
            isA<SteamAccelerationException>().having(
              (e) => e.toString(),
              'redacted',
              isNot(contains('private')),
            ),
          ),
        );
        expect(store.value, original);
        expect(runtime.stops, stops);
        expect(runtime.running, isTrue);
      }
    },
  );

  test(
    'secure write failure is observable and preserves saved and exported data',
    () async {
      await configured();
      final original = store.value;
      final before = await service.exportSyncConfiguration();
      store.failWrite = true;
      await expectLater(
        service.applySyncConfiguration({'v': 1, 'configured': false}),
        throwsA(
          isA<SteamAccelerationException>().having(
            (e) => e.code,
            'code',
            SteamAccelerationError.storage,
          ),
        ),
      );
      expect(store.value, original);
      expect(await service.exportSyncConfiguration(), before);
    },
  );

  test(
    'unavailable secure storage cannot be exported as a deletion marker',
    () async {
      store.failRead = true;
      await expectLater(
        service.exportSyncConfiguration(),
        throwsA(isA<SteamAccelerationException>()),
      );
      expect(fetches, 0);
      expect(runtime.starts, 0);
    },
  );

  test(
    'identical pull does not interrupt a running core or notify another change',
    () async {
      await configured();
      await service.start();
      final doc = await service.exportSyncConfiguration();
      final stops = runtime.stops;
      var changes = 0;
      service.configurationChanges.addListener(() => changes++);
      await service.applySyncConfiguration(doc);
      expect(runtime.stops, stops);
      expect(runtime.running, isTrue);
      expect(changes, 0);
    },
  );

  test(
    'sync notifications exclude local auto preference, environment and lifecycle',
    () async {
      var changes = 0;
      service.configurationChanges.addListener(() => changes++);
      await service.load();
      expect(changes, 0);
      await configured();
      expect(changes, 3);
      final snapshot = await service.exportSyncConfiguration();
      await service.setAutoStart(true);
      await service.start();
      await service.checkEnvironment();
      await service.stop();
      expect(changes, 3);
      expect(await service.exportSyncConfiguration(), snapshot);
      await service.clearConfiguration();
      expect(changes, 4);
      expect(await service.exportSyncConfiguration(), {
        'v': 1,
        'configured': false,
      });
    },
  );
}
