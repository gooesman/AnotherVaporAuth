import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/steam_acceleration.dart';
import '../services/steam_connectivity.dart';
import '../services/steam_network.dart';

final steamAccelerationServiceProvider = Provider<SteamAccelerationService>((
  ref,
) {
  final service = SteamAccelerationService();
  ref.onDispose(service.dispose);
  return service;
});

final steamConnectivityProbeProvider = Provider<SteamConnectivityProbe>(
  (ref) => SteamConnectivityProbe(),
);

final steamConnectivityProvider = Provider<SteamConnectivityMonitor>((ref) {
  final service = ref.watch(steamAccelerationServiceProvider);
  final monitor = SteamConnectivityMonitor(
    service,
    effectiveProxy: () => steamProxyFor(service),
    probe: ref.watch(steamConnectivityProbeProvider),
  );
  ref.onDispose(monitor.dispose);
  return monitor;
});

/// Only the real application installs this scope. Offline rendering and TOTP
/// startup never wait for a core download; Steam requests wait for the user's
/// saved automatic routing choice to settle before opening a connection.
class SteamAccelerationScope extends ConsumerStatefulWidget {
  const SteamAccelerationScope({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<SteamAccelerationScope> createState() =>
      _SteamAccelerationScopeState();
}

class _SteamAccelerationScopeState extends ConsumerState<SteamAccelerationScope>
    with WidgetsBindingObserver {
  late final SteamAccelerationService _service;
  late final SteamConnectivityMonitor _connectivity;

  @override
  void initState() {
    super.initState();
    _service = ref.read(steamAccelerationServiceProvider);
    WidgetsBinding.instance.addObserver(this);
    SteamNetwork.configureProxy(
      () => steamProxyFor(_service),
      readiness: _initialize(),
    );
    // Start observing after installing routing. Its asynchronous probe waits
    // for readiness without holding up initialization, avoiding a dependency
    // cycle when automatic acceleration is still starting.
    _connectivity = ref.read(steamConnectivityProvider);
  }

  Future<void> _initialize() async {
    if (!_service.supported) return;
    try {
      await _service.load();
      await _service.checkEnvironment();
      if (mounted) await _service.start(automatic: true);
    } catch (_) {
      // The service reports credential-free status to its settings page.
      // Optional routing must never prevent offline app use or expose secrets.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _service.supported) {
      unawaited(
        _service.checkEnvironment().then((_) => _connectivity.refreshIfStale()),
      );
    } else if (state == AppLifecycleState.detached) {
      unawaited(_service.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SteamNetwork.configureProxy(() => null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A VPN/TUN already routes operating-system sockets. PAC is detected but not
/// evaluated here; its presence pauses the internal core without pretending an
/// HTTP endpoint was discovered. No system proxy settings are ever written.
SteamNetworkProxy? steamProxyFor(SteamAccelerationService service) {
  if (!service.state.configured) return null;
  final environment = service.state.environment;
  final external = environment.externalHttpProxy;
  if (external != null) {
    try {
      return SteamNetworkProxy(host: external.host, port: external.port);
    } on ArgumentError {
      // Malformed third-party settings must not crash a Steam request. The
      // detected external configuration still prevents starting a second core.
      return null;
    }
  }
  if (environment.hasExternal) return null;
  final internal = service.proxyEndpoint;
  if (internal == null) return null;
  return SteamNetworkProxy(
    host: internal.host,
    port: internal.port,
    username: internal.username,
    password: internal.password,
  );
}
