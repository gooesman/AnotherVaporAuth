import 'dart:async';
import 'dart:convert';

import 'package:ava/src/app/steam_acceleration_providers.dart';
import 'package:ava/src/services/steam_acceleration.dart';
import 'package:ava/src/services/steam_acceleration_runtime.dart';
import 'package:ava/src/services/steam_network.dart';
import 'package:ava/src/services/steam_connectivity.dart';
import 'package:ava/src/services/fork_update_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _nodes = '''
proxies:
  - name: Synthetic node
    type: ss
    server: node.example.invalid
    port: 443
    cipher: aes-128-gcm
    password: synthetic-only
''';
const _clear = SteamAccelerationEnvironment(detectionAvailable: true);

class _Store extends SteamAccelerationStore {
  _Store({required bool auto, bool cached = false})
    : value = jsonEncode({
        'v': 1,
        'url': 'https://example.invalid/subscription?token=synthetic',
        'auto': auto,
        if (cached) 'nodes': _nodes,
      });
  String value;
  Completer<void>? pending;
  @override
  Future<String?> read() async {
    await pending?.future;
    return value;
  }

  @override
  Future<void> write(String value) async => this.value = value;
}

class _Runtime implements SteamAccelerationRuntime {
  SteamAccelerationEnvironment environment = _clear;
  bool running = false;
  int starts = 0;
  int stops = 0;
  int detections = 0;
  @override
  bool get supported => true;
  @override
  Future<SteamAccelerationEnvironment> detectEnvironment() async {
    detections++;
    return environment;
  }

  @override
  Future<bool> isRunning() async => running;
  @override
  Future<void> start(
    String configuration,
    SteamProxyEndpoint endpoint, {
    void Function(SteamAccelerationPhase)? onPhaseChanged,
  }) async {
    starts++;
    running = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }
}

class _EmptyStore extends SteamAccelerationStore {
  @override
  Future<String?> read() async => null;
}

class _OfflineProbe extends SteamConnectivityProbe {
  @override
  Future<SteamConnectionResult> check(CancelToken cancel) async =>
      const SteamConnectionResult(api: false, community: false);
}

void main() {
  tearDown(() {
    SteamNetwork.configureProxy(() => null);
    ForkUpdateNetwork.configureProxy(() => null);
  });

  test(
    'Steam and updates use external HTTP without an internal subscription',
    () async {
      final runtime = _Runtime()
        ..environment = const SteamAccelerationEnvironment(
          detectionAvailable: true,
          systemProxyDetected: true,
          externalHttpProxy: SteamExternalProxy(host: '127.0.0.1', port: 7890),
        );
      final service = SteamAccelerationService(
        store: _EmptyStore(),
        runtime: runtime,
      );
      addTearDown(service.dispose);
      await service.load();
      await service.checkEnvironment();
      expect(service.state.configured, isFalse);
      expect(steamProxyFor(service)!.port, 7890);
      expect(steamProxyFor(service)!.username, isNull);
      expect(forkUpdateProxyFor(service)!.port, 7890);
      expect(forkUpdateProxyFor(service)!.username, isNull);
      expect(runtime.starts, 0);
    },
  );

  test('updates never start a stopped or manually configured core', () async {
    final runtime = _Runtime();
    final service = SteamAccelerationService(
      store: _Store(auto: false, cached: true),
      runtime: runtime,
    );
    addTearDown(service.dispose);
    await service.load();
    await service.checkEnvironment();
    expect(forkUpdateProxyFor(service), isNull);
    expect(runtime.starts, 0);
    await service.start();
    expect(forkUpdateProxyFor(service), isNotNull);
    expect(forkUpdateProxyFor(service)!.username, isNotEmpty);
    await service.stop();
    expect(forkUpdateProxyFor(service), isNull);
    expect(runtime.starts, 1);
  });

  test('updates hand over a running core to an external HTTP proxy', () async {
    final runtime = _Runtime();
    final service = SteamAccelerationService(
      store: _Store(auto: false, cached: true),
      runtime: runtime,
    );
    addTearDown(service.dispose);
    await service.load();
    await service.start();
    expect(forkUpdateProxyFor(service)!.username, isNotEmpty);
    runtime.environment = const SteamAccelerationEnvironment(
      detectionAvailable: true,
      systemProxyDetected: true,
      externalHttpProxy: SteamExternalProxy(host: '127.0.0.1', port: 7890),
    );
    await service.checkEnvironment();
    expect(runtime.running, isFalse);
    expect(forkUpdateProxyFor(service)!.port, 7890);
    expect(forkUpdateProxyFor(service)!.username, isNull);
    expect(runtime.starts, 1);
  });

  test(
    'unknown environment does not route updates through the internal core',
    () async {
      final runtime = _Runtime()
        ..environment = const SteamAccelerationEnvironment();
      final service = SteamAccelerationService(
        store: _Store(auto: false, cached: true),
        runtime: runtime,
      );
      addTearDown(service.dispose);
      await service.load();
      await service.start();
      expect(runtime.running, isFalse);
      expect(steamProxyFor(service), isNull);
      expect(forkUpdateProxyFor(service), isNull);
      expect(runtime.starts, 0);
    },
  );

  test('VPN and PAC keep update sockets on operating-system routing', () async {
    for (final environment in [
      const SteamAccelerationEnvironment(
        detectionAvailable: true,
        vpnOrTunnelDetected: true,
      ),
      const SteamAccelerationEnvironment(
        detectionAvailable: true,
        pacDetected: true,
      ),
    ]) {
      final runtime = _Runtime()..environment = environment;
      final service = SteamAccelerationService(
        store: _Store(auto: false, cached: true),
        runtime: runtime,
      );
      addTearDown(service.dispose);
      await service.load();
      await service.checkEnvironment();
      expect(forkUpdateProxyFor(service), isNull);
      expect(runtime.starts, 0);
    }
  });

  Future<void> pumpScope(
    WidgetTester tester,
    SteamAccelerationService service,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          steamAccelerationServiceProvider.overrideWithValue(service),
          steamConnectivityProbeProvider.overrideWithValue(_OfflineProbe()),
        ],
        child: const SteamAccelerationScope(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text('Offline account codes'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }

  Future<void> close(
    WidgetTester tester,
    SteamAccelerationService service,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
    await flush(tester);
  }

  testWidgets(
    'offline app renders during storage loading and manual startup stays offline',
    (tester) async {
      final pending = Completer<void>();
      final store = _Store(auto: false)..pending = pending;
      final runtime = _Runtime();
      var fetches = 0;
      final service = SteamAccelerationService(
        store: store,
        runtime: runtime,
        fetchSubscription: (_) async {
          fetches++;
          return _nodes;
        },
      );
      await pumpScope(tester, service);
      expect(find.text('Offline account codes'), findsOneWidget);
      expect(fetches, 0);
      expect(runtime.starts, 0);
      pending.complete();
      await flush(tester);
      expect(service.state.configured, isTrue);
      expect(service.state.autoStart, isFalse);
      expect(fetches, 0);
      expect(runtime.starts, 0);
      expect(steamProxyFor(service), isNull);
      await close(tester, service);
    },
  );

  testWidgets(
    'saved automatic mode uses cached nodes and resume yields to an external proxy',
    (tester) async {
      final runtime = _Runtime();
      var fetches = 0;
      final service = SteamAccelerationService(
        store: _Store(auto: true, cached: true),
        runtime: runtime,
        fetchSubscription: (_) async {
          fetches++;
          return _nodes;
        },
      );
      await pumpScope(tester, service);
      await flush(tester);
      expect(runtime.starts, 1);
      expect(service.state.phase, SteamAccelerationPhase.running);
      expect(fetches, 0);
      expect(steamProxyFor(service)!.username, isNotEmpty);
      runtime.environment = const SteamAccelerationEnvironment(
        detectionAvailable: true,
        systemProxyDetected: true,
        externalHttpProxy: SteamExternalProxy(host: '127.0.0.1', port: 7890),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await flush(tester);
      expect(runtime.running, isFalse);
      expect(service.proxyEndpoint, isNull);
      expect(service.state.phase, SteamAccelerationPhase.pausedExternal);
      final route = steamProxyFor(service)!;
      expect(route.port, 7890);
      expect(route.username, isNull);
      expect(route.password, isNull);
      await close(tester, service);
    },
  );

  testWidgets(
    'visible external routing refreshes without a subscription and pauses when hidden',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final runtime = _Runtime();
      final service = SteamAccelerationService(
        store: _EmptyStore(),
        runtime: runtime,
      );
      await pumpScope(tester, service);
      await flush(tester);
      expect(service.state.configured, isFalse);
      expect(steamProxyFor(service), isNull);
      final before = steamRouteIdentity(service);
      runtime.environment = const SteamAccelerationEnvironment(
        detectionAvailable: true,
        vpnOrTunnelDetected: true,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await flush(tester);
      final hiddenDetections = runtime.detections;
      await tester.pump(const Duration(seconds: 20));
      await flush(tester);
      expect(runtime.detections, hiddenDetections);
      expect(steamRouteIdentity(service), before);
      // Losing focus to an external proxy app must not disable detection.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 6));
      await flush(tester);
      expect(runtime.detections, greaterThan(hiddenDetections));
      expect(steamProxyFor(service), isNull); // VPN uses OS sockets.
      expect(steamRouteIdentity(service), isNot(before));
      expect(runtime.starts, 0);
      runtime.environment = const SteamAccelerationEnvironment(
        detectionAvailable: true,
        systemProxyDetected: true,
        externalHttpProxy: SteamExternalProxy(host: '127.0.0.1', port: 7890),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await flush(tester);
      expect(steamProxyFor(service)!.port, 7890);
      await close(tester, service);
    },
  );

  testWidgets(
    'detaching during subscription loading prevents a late core start',
    (tester) async {
      final pending = Completer<String>();
      final runtime = _Runtime();
      var fetches = 0;
      final service = SteamAccelerationService(
        store: _Store(auto: true),
        runtime: runtime,
        fetchSubscription: (_) {
          fetches++;
          return pending.future;
        },
      );
      await pumpScope(tester, service);
      await flush(tester);
      expect(fetches, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      pending.complete(_nodes);
      await flush(tester);
      expect(runtime.starts, 0);
      expect(service.proxyEndpoint, isNull);
      expect(service.state.phase, SteamAccelerationPhase.off);
      await close(tester, service);
    },
  );

  testWidgets(
    'removing the app while preferences load cannot start acceleration later',
    (tester) async {
      final pending = Completer<void>();
      final runtime = _Runtime();
      var fetches = 0;
      final service = SteamAccelerationService(
        store: _Store(auto: true)..pending = pending,
        runtime: runtime,
        fetchSubscription: (_) async {
          fetches++;
          return _nodes;
        },
      );
      await pumpScope(tester, service);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await flush(tester);
      expect(runtime.starts, 0);
      expect(fetches, 0);
      expect(service.proxyEndpoint, isNull);
      await close(tester, service);
    },
  );
}
