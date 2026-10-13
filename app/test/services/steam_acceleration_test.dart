import 'dart:async';
import 'dart:convert';

import 'package:ava/src/services/steam_acceleration.dart';
import 'package:ava/src/services/steam_acceleration_runtime.dart';
import 'package:ava/src/services/steam_acceleration_subscription.dart';
import 'package:flutter_test/flutter_test.dart';

const _subscription = '''
proxies:
  - name: Fixture
    type: ss
    server: node.example.invalid
    port: 443
    cipher: aes-128-gcm
    password: fixture-node-secret
rules: [MATCH,DIRECT]
external-controller: 0.0.0.0:9090
script: {code: arbitrary-code}
tun: {enable: true}
dns: {enable: true}
''';

class _Store extends SteamAccelerationStore {
  String? value;
  int reads = 0;
  @override
  Future<String?> read() async {
    reads++;
    return value;
  }

  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _Runtime implements SteamAccelerationRuntime {
  SteamAccelerationEnvironment environment = const SteamAccelerationEnvironment(
    detectionAvailable: true,
  );
  bool failDetection = false;
  int starts = 0;
  int stops = 0;
  int detections = 0;
  bool running = false;
  String? configuration;
  SteamProxyEndpoint? endpoint;
  Completer<void>? pendingStart;
  Completer<void>? pendingStop;
  Completer<void>? stopEntered;
  void Function()? afterStart;
  @override
  bool get supported => true;
  @override
  Future<SteamAccelerationEnvironment> detectEnvironment() async {
    detections++;
    if (failDetection) throw StateError('Sensitive native diagnostic');
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
    this.configuration = configuration;
    this.endpoint = endpoint;
    await pendingStart?.future;
    running = true;
    afterStart?.call();
  }

  @override
  Future<void> stop() async {
    stops++;
    final pending = pendingStop;
    pendingStop = null;
    stopEntered?.complete();
    stopEntered = null;
    await pending?.future;
    running = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;
  late _Runtime runtime;
  late SteamAccelerationService service;
  var fetches = 0;
  Future<String> Function(Uri)? fetch;

  setUp(() {
    store = _Store();
    runtime = _Runtime();
    fetches = 0;
    fetch = null;
    service = SteamAccelerationService(
      store: store,
      runtime: runtime,
      environmentInterval: const Duration(hours: 1),
      fetchSubscription: (uri) async {
        fetches++;
        return fetch == null ? _subscription : fetch!(uri);
      },
    );
  });
  tearDown(() => service.dispose());

  Future<void> configure({bool auto = false}) => service.configure(
    subscriptionUrl:
        'https://subscription.example.invalid/list?token=fixture-secret',
    autoStart: auto,
  );

  test(
    'load is idempotent and unset/default-off startup performs no network',
    () async {
      await Future.wait([service.load(), service.load()]);
      await service.start(automatic: true);
      expect(store.reads, 1);
      expect(fetches, 0);
      expect(runtime.starts, 0);
      await configure();
      await service.start(automatic: true);
      expect(fetches, 0);
      expect(runtime.starts, 0);
      expect(service.state.configured, isTrue);
    },
  );

  test(
    'manual start imports only nodes and uses private authenticated listener',
    () async {
      await configure();
      await service.start();
      expect(service.state.phase, SteamAccelerationPhase.running);
      expect(fetches, 1);
      final config = jsonDecode(runtime.configuration!) as Map;
      expect(config['bind-address'], '127.0.0.1');
      expect(config['allow-lan'], isFalse);
      expect(config['external-controller'], '');
      expect(config['script'], isNull);
      expect(config['rules'], ['MATCH,AVA-selected']);
      expect(config['tun'], {'enable': false});
      expect(config['dns'], {'enable': false});
      expect(config['authentication'], hasLength(1));
      expect(config['skip-auth-prefixes'], isEmpty);
      expect(config['log-level'], 'silent');
      expect(service.proxyEndpoint!.password.length, greaterThanOrEqualTo(32));
      expect(service.proxyEndpoint!.toString(), isNot(contains('fixture')));
      expect(service.state.nodes.single.name, 'Fixture');
      expect(store.value, contains('fixture-node-secret'));
      expect(store.value, isNot(contains(service.proxyEndpoint!.password)));
      await service.stop();
      expect(service.proxyEndpoint, isNull);
      expect(runtime.running, isFalse);
    },
  );

  test(
    'external HTTP endpoint pauses internal startup without fetching subscription',
    () async {
      await configure(auto: true);
      runtime.environment = const SteamAccelerationEnvironment(
        detectionAvailable: true,
        systemProxyDetected: true,
        externalHttpProxy: SteamExternalProxy(host: '127.0.0.1', port: 7890),
      );
      await service.start(automatic: true);
      expect(service.state.phase, SteamAccelerationPhase.pausedExternal);
      expect(service.state.environment.externalHttpProxy!.port, 7890);
      expect(runtime.starts, 0);
      expect(fetches, 0);
    },
  );

  test(
    'monitor stops on external VPN then auto resumes when it disappears',
    () async {
      await configure(auto: true);
      await service.start(automatic: true);
      runtime.environment = const SteamAccelerationEnvironment(
        detectionAvailable: true,
        vpnOrTunnelDetected: true,
      );
      await service.checkEnvironment();
      expect(service.proxyEndpoint, isNull);
      expect(runtime.running, isFalse);
      expect(service.state.phase, SteamAccelerationPhase.pausedExternal);
      runtime.environment = const SteamAccelerationEnvironment(
        detectionAvailable: true,
      );
      await service.checkEnvironment();
      expect(runtime.starts, 2);
      expect(fetches, 1); // safe cached catalog; never auto re-fetch every poll
      expect(service.state.phase, SteamAccelerationPhase.running);
    },
  );

  test(
    'manual stop prevents monitor from automatically restarting this session',
    () async {
      await configure(auto: true);
      runtime.environment = const SteamAccelerationEnvironment(
        detectionAvailable: true,
        systemProxyDetected: true,
      );
      await service.start(automatic: true);
      await service.stop();
      runtime.environment = const SteamAccelerationEnvironment(
        detectionAvailable: true,
      );
      await service.checkEnvironment();
      await service.start(automatic: true);
      expect(runtime.starts, 0);
      expect(fetches, 0);
      expect(service.state.phase, SteamAccelerationPhase.off);
    },
  );

  test(
    'read-only environment check refreshes routing without resuming a core',
    () async {
      await configure(auto: true);
      await service.start(automatic: true);
      runtime.environment = const SteamAccelerationEnvironment(
        detectionAvailable: true,
        systemProxyDetected: true,
        externalHttpProxy: SteamExternalProxy(host: '127.0.0.1', port: 7890),
      );
      await service.checkEnvironment(allowAutomaticStart: false);
      expect(service.state.environment.externalHttpProxy!.port, 7890);
      expect(service.state.phase, SteamAccelerationPhase.pausedExternal);
      expect(runtime.running, isFalse);
      runtime.environment = const SteamAccelerationEnvironment(
        detectionAvailable: true,
      );
      await service.checkEnvironment(allowAutomaticStart: false);
      expect(service.state.environment.hasExternal, isFalse);
      expect(service.state.phase, SteamAccelerationPhase.pausedExternal);
      expect(service.proxyEndpoint, isNull);
      expect(runtime.starts, 1);
      expect(fetches, 1);
      // The normal monitor still follows the saved automatic preference.
      await service.checkEnvironment();
      expect(runtime.starts, 2);
      expect(runtime.running, isTrue);
      expect(fetches, 1);
    },
  );

  test('manual mode stays paused until another explicit start', () async {
    await configure();
    await service.start();
    runtime.environment = const SteamAccelerationEnvironment(
      detectionAvailable: true,
      vpnOrTunnelDetected: true,
    );
    await service.checkEnvironment();
    runtime.environment = const SteamAccelerationEnvironment(
      detectionAvailable: true,
    );
    await service.checkEnvironment();
    expect(runtime.starts, 1);
    expect(service.state.phase, SteamAccelerationPhase.pausedExternal);
    await service.start();
    expect(runtime.starts, 2);
  });

  test(
    'unknown native detection pauses automatic mode without leaking errors',
    () async {
      await configure(auto: true);
      runtime.failDetection = true;
      await service.start(automatic: true);
      expect(service.state.phase, SteamAccelerationPhase.pausedExternal);
      expect(service.state.error, SteamAccelerationError.environmentUnknown);
      expect(runtime.starts, 0);
      runtime.failDetection = false;
      await service.checkEnvironment();
      expect(service.state.phase, SteamAccelerationPhase.running);
      runtime.failDetection = true;
      await service.checkEnvironment();
      expect(service.state.phase, SteamAccelerationPhase.pausedExternal);
      expect(runtime.running, isFalse);
      expect(service.proxyEndpoint, isNull);
    },
  );

  test(
    'second detection catches unknown state while automatic core is starting',
    () async {
      await configure(auto: true);
      runtime.afterStart = () => runtime.failDetection = true;
      await service.start(automatic: true);
      expect(service.state.phase, SteamAccelerationPhase.pausedExternal);
      expect(service.proxyEndpoint, isNull);
      expect(runtime.running, isFalse);
    },
  );

  test('stopping a delayed start discards its late endpoint', () async {
    await configure();
    final pending = Completer<void>();
    runtime.pendingStart = pending;
    final starting = service.start();
    while (runtime.starts == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final stopping = service.stop();
    expect(service.proxyEndpoint, isNull);
    pending.complete();
    await Future.wait([starting, stopping]);
    expect(runtime.running, isFalse);
    expect(service.state.phase, SteamAccelerationPhase.off);
  });

  test(
    'invalid configuration cleanup finishes before an immediate restart',
    () async {
      await configure();
      await service.start();
      final stopped = Completer<void>();
      final entered = Completer<void>();
      runtime.pendingStop = stopped;
      runtime.stopEntered = entered;
      await service.configure(subscriptionUrl: 'ftp://invalid.example/secret');
      expect(service.proxyEndpoint, isNull);
      expect(service.state.error, SteamAccelerationError.invalidSubscription);
      await entered.future;
      final previousDetections = runtime.detections;
      final restarting = service.start();
      try {
        // Drain queued microtasks: a new start must not enter the runtime while
        // the old instance still owns its process and temporary directory.
        await Future<void>.delayed(Duration.zero);
        expect(runtime.detections, previousDetections);
        expect(runtime.starts, 1);
      } finally {
        stopped.complete();
        await restarting;
      }
      expect(runtime.starts, 2);
      expect(runtime.running, isTrue);
      expect(service.state.phase, SteamAccelerationPhase.running);
      expect(service.proxyEndpoint, isNotNull);
    },
  );

  test(
    'stopping a subscription fetch prevents cache and core resurrection',
    () async {
      await configure();
      final pending = Completer<String>();
      fetch = (_) => pending.future;
      final refreshing = service.refreshSubscription();
      while (fetches == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final stopping = service.stop();
      pending.complete(_subscription);
      await Future.wait([refreshing, stopping]);
      expect(service.state.nodes, isEmpty);
      expect(store.value, isNot(contains('fixture-node-secret')));
      expect(runtime.starts, 0);
    },
  );

  test(
    'malformed subscription diagnostics never reveal URL or response line',
    () async {
      await configure();
      fetch = (_) async => 'proxies: [fixture-secret-invalid';
      await service.refreshSubscription();
      expect(service.state.error, SteamAccelerationError.invalidSubscription);
      expect(runtime.starts, 0);
      await service.configure(
        subscriptionUrl: 'ftp://untrusted.invalid/secret',
      );
      expect(service.state.error, SteamAccelerationError.invalidSubscription);
    },
  );

  test(
    'proxy parser accepts explicit HTTP endpoints and rejects credentials/PAC',
    () {
      expect(
        parseExternalSteamProxy(
          'http=127.0.0.1:7890;https=proxy.example:8080',
        )!.host,
        'proxy.example',
      );
      expect(parseExternalSteamProxy('[::1]:7890')!.port, 7890);
      for (final value in [
        'http://user:secret@localhost:80',
        'https://proxy:443',
        'file:///proxy.pac',
        'host:99999',
        'proxy:8080/path',
        'socks=host:1080',
      ]) {
        expect(parseExternalSteamProxy(value), isNull, reason: value);
      }
    },
  );

  test('unsafe or unsupported node options are excluded and counted', () {
    final parsed = SteamAccelerationSubscription.parse(
      '''$_subscription
'''
          .replaceFirst('rules:', '''  - name: Unsafe TLS
    type: trojan
    server: node.example.invalid
    port: 443
    password: secret
    skip-cert-verify: true
  - name: Unsafe plugin
    type: ss
    server: node.example.invalid
    port: 443
    cipher: aes-128-gcm
    password: secret
    plugin: executable
rules:'''),
    );
    expect(parsed.nodes, hasLength(1));
    expect(parsed.skipped, 2);
    expect(parsed.toSecureCache(), isNot(contains('script')));
    expect(parsed.toSecureCache(), isNot(contains('plugin')));
  });

  test(
    'provider-only or recursive unsupported documents never become configs',
    () {
      for (final source in [
        'proxy-providers: {x: {url: https://other.invalid}}',
        'proxies: &list [*list]',
        'proxies: []',
      ]) {
        expect(
          () => SteamAccelerationSubscription.parse(source),
          throwsA(isA<SteamAccelerationException>()),
        );
      }
    },
  );
}
