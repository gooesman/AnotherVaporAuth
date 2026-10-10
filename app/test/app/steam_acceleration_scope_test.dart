import 'dart:async';
import 'dart:convert';

import 'package:ava/src/app/steam_acceleration_providers.dart';
import 'package:ava/src/services/steam_acceleration.dart';
import 'package:ava/src/services/steam_acceleration_runtime.dart';
import 'package:ava/src/services/steam_network.dart';
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
  @override
  bool get supported => true;
  @override
  Future<SteamAccelerationEnvironment> detectEnvironment() async => environment;
  @override
  Future<bool> isRunning() async => running;
  @override
  Future<void> start(String configuration, SteamProxyEndpoint endpoint) async {
    starts++;
    running = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }
}

void main() {
  tearDown(() => SteamNetwork.configureProxy(() => null));

  Future<void> pumpScope(
    WidgetTester tester,
    SteamAccelerationService service,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          steamAccelerationServiceProvider.overrideWithValue(service),
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
