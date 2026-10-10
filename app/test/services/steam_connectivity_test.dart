import 'dart:async';
import 'dart:typed_data';

import 'package:ava/src/app/steam_acceleration_providers.dart';
import 'package:ava/src/services/steam_acceleration.dart';
import 'package:ava/src/services/steam_connectivity.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool api = true;
  int communityStatus = 200;
  bool closed = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.uri.host == 'api.steampowered.com') {
      return ResponseBody.fromString(
        api ? '{"response":{"server_time":1900000000}}' : '{"response":{}}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString('', communityStatus);
  }

  @override
  void close({bool force = false}) => closed = true;
}

class _Service extends SteamAccelerationService {
  SteamAccelerationState value = const SteamAccelerationState();
  SteamProxyEndpoint? endpoint;
  @override
  SteamAccelerationState get state => value;
  @override
  SteamProxyEndpoint? get proxyEndpoint => endpoint;
  void emit(SteamAccelerationState state) {
    value = state;
    notifyListeners();
  }
}

class _Probe extends SteamConnectivityProbe {
  final pending = <Completer<SteamConnectionResult>>[];
  final cancellations = <CancelToken>[];
  @override
  Future<SteamConnectionResult> check(CancelToken cancel) {
    cancellations.add(cancel);
    final request = Completer<SteamConnectionResult>();
    pending.add(request);
    return request.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const connected = SteamConnectionResult(api: true, community: true);
  const running = SteamAccelerationState(
    configured: true,
    phase: SteamAccelerationPhase.running,
  );
  const endpoint = SteamProxyEndpoint(
    host: '127.0.0.1',
    port: 7890,
    username: 'synthetic',
    password: 'synthetic',
  );

  test(
    'probe checks anonymous API and Community without account credentials',
    () async {
      final adapter = _Adapter();
      final probe = SteamConnectivityProbe(
        createClient: () =>
            Dio(BaseOptions(followRedirects: false))
              ..httpClientAdapter = adapter,
      );
      final result = await probe.check(CancelToken());
      expect(result.status, SteamConnectionStatus.available);
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.map((r) => r.uri.host).toSet(), {
        'api.steampowered.com',
        'steamcommunity.com',
      });
      for (final request in adapter.requests) {
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('cookie')),
        );
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('proxy-authorization')),
        );
        expect(request.uri.query, isEmpty);
        expect(request.followRedirects, isFalse);
      }
      expect(adapter.closed, isTrue);
    },
  );

  test('probe distinguishes partial failure from an available route', () async {
    final adapter = _Adapter()..api = false;
    final probe = SteamConnectivityProbe(
      createClient: () =>
          Dio(BaseOptions(followRedirects: false))..httpClientAdapter = adapter,
    );
    final result = await probe.check(CancelToken());
    expect(result.api, isFalse);
    expect(result.community, isTrue);
    expect(result.status, SteamConnectionStatus.partial);
  });

  test(
    'HTTP rejection and an invalid API response never count as available',
    () async {
      final adapter = _Adapter()
        ..api = false
        ..communityStatus = 503;
      final probe = SteamConnectivityProbe(
        createClient: () =>
            Dio(BaseOptions(followRedirects: false))
              ..httpClientAdapter = adapter,
      );
      expect(
        (await probe.check(CancelToken())).status,
        SteamConnectionStatus.unavailable,
      );
    },
  );

  test(
    'running is checking until both endpoints complete; no repeated poll probes',
    () async {
      final service = _Service();
      final probe = _Probe();
      final monitor = SteamConnectivityMonitor(
        service,
        effectiveProxy: () => steamProxyFor(service),
        probe: probe,
        now: () => DateTime(2026, 10, 11, 12),
      );
      addTearDown(monitor.dispose);
      addTearDown(service.dispose);
      expect(probe.pending, isEmpty);
      service.endpoint = endpoint;
      service.emit(running);
      expect(monitor.state.route, SteamConnectionRoute.internal);
      expect(monitor.state.status, SteamConnectionStatus.checking);
      await monitor.check(); // Concurrent requests are coalesced.
      expect(probe.pending, hasLength(1));
      probe.pending.single.complete(connected);
      await Future<void>.delayed(Duration.zero);
      expect(monitor.state.status, SteamConnectionStatus.available);
      expect(monitor.state.checkedAt, DateTime(2026, 10, 11, 12));
      for (var i = 0; i < 10; i++) {
        service.emit(running); // Existing 15-second environment notifications.
      }
      expect(probe.pending, hasLength(1));
    },
  );

  test(
    'stop cancels and discards an earlier successful connection check',
    () async {
      final service = _Service()..endpoint = endpoint;
      final probe = _Probe();
      final monitor = SteamConnectivityMonitor(
        service,
        effectiveProxy: () => steamProxyFor(service),
        probe: probe,
      );
      addTearDown(monitor.dispose);
      addTearDown(service.dispose);
      service.emit(running);
      service.endpoint = null;
      service.emit(const SteamAccelerationState(configured: true));
      expect(probe.cancellations.single.isCancelled, isTrue);
      probe.pending.single.complete(connected);
      await Future<void>.delayed(Duration.zero);
      expect(monitor.state.route, SteamConnectionRoute.direct);
      expect(monitor.state.status, SteamConnectionStatus.unchecked);
      expect(monitor.state.checkedAt, isNull);
    },
  );

  test(
    'external proxy takes priority and invalidates old internal results',
    () async {
      final service = _Service()..endpoint = endpoint;
      final probe = _Probe();
      final monitor = SteamConnectivityMonitor(
        service,
        effectiveProxy: () => steamProxyFor(service),
        probe: probe,
      );
      addTearDown(monitor.dispose);
      addTearDown(service.dispose);
      service.emit(running);
      service.emit(
        const SteamAccelerationState(
          configured: true,
          phase: SteamAccelerationPhase.pausedExternal,
          environment: SteamAccelerationEnvironment(
            systemProxyDetected: true,
            externalHttpProxy: SteamExternalProxy(
              host: '127.0.0.1',
              port: 7891,
            ),
          ),
        ),
      );
      expect(probe.pending, hasLength(2));
      expect(probe.cancellations.first.isCancelled, isTrue);
      probe.pending.first.complete(connected);
      await Future<void>.delayed(Duration.zero);
      expect(monitor.state.status, SteamConnectionStatus.checking);
      expect(monitor.state.route, SteamConnectionRoute.externalProxy);
      probe.pending.last.complete(
        const SteamConnectionResult(api: true, community: false),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.state.status, SteamConnectionStatus.partial);
    },
  );

  test('explicit direct check works and disposal ignores completion', () async {
    final service = _Service();
    final probe = _Probe();
    final monitor = SteamConnectivityMonitor(
      service,
      effectiveProxy: () => steamProxyFor(service),
      probe: probe,
    );
    final check = monitor.check();
    expect(monitor.state.route, SteamConnectionRoute.direct);
    expect(probe.pending, hasLength(1));
    monitor.dispose();
    expect(probe.cancellations.single.isCancelled, isTrue);
    probe.pending.single.complete(connected);
    await check;
    service.dispose();
  });

  test(
    'foreground rechecks stale active routes without polling brief app switches',
    () async {
      final service = _Service()..endpoint = endpoint;
      final probe = _Probe();
      var now = DateTime(2026, 10, 11, 12);
      final monitor = SteamConnectivityMonitor(
        service,
        effectiveProxy: () => steamProxyFor(service),
        probe: probe,
        now: () => now,
      );
      addTearDown(monitor.dispose);
      addTearDown(service.dispose);
      service.emit(running);
      probe.pending.single.complete(connected);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 59));
      await monitor.refreshIfStale();
      expect(probe.pending, hasLength(1));
      now = now.add(const Duration(hours: 2));
      final resumed = monitor.refreshIfStale();
      expect(monitor.state.status, SteamConnectionStatus.checking);
      expect(probe.pending, hasLength(2));
      probe.pending.last.complete(
        const SteamConnectionResult(api: false, community: false),
      );
      await resumed;
      expect(monitor.state.status, SteamConnectionStatus.unavailable);
      expect(monitor.state.checkedAt, now);
      service.endpoint = null;
      service.emit(const SteamAccelerationState(configured: true));
      now = now.add(const Duration(hours: 2));
      await monitor.refreshIfStale();
      expect(probe.pending, hasLength(2));
    },
  );
}
