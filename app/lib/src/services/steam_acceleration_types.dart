/// Public status intentionally excludes subscription URLs and node credentials.
enum SteamAccelerationPhase {
  off,
  loadingSubscription,
  downloadingCore,
  starting,
  running,
  pausedExternal,
  error,
}

enum SteamAccelerationError {
  invalidSubscription,
  network,
  unsupportedSubscription,
  storage,
  coreUnavailable,
  coreDownload,
  coreIntegrity,
  startFailed,
  unsupportedPlatform,
  environmentUnknown,
}

class SteamExternalProxy {
  const SteamExternalProxy({required this.host, required this.port});
  final String host;
  final int port;
  @override
  String toString() => 'SteamExternalProxy(redacted)';
}

class SteamProxyEndpoint extends SteamExternalProxy {
  const SteamProxyEndpoint({
    required super.host,
    required super.port,
    required this.username,
    required this.password,
  });
  final String username;
  final String password;
  @override
  String toString() => 'SteamProxyEndpoint(redacted)';
}

class SteamAccelerationEnvironment {
  const SteamAccelerationEnvironment({
    this.systemProxyDetected = false,
    this.vpnOrTunnelDetected = false,
    this.detectionAvailable = false,
    this.pacDetected = false,
    this.externalHttpProxy,
  });
  final bool systemProxyDetected;
  final bool vpnOrTunnelDetected;
  final bool detectionAvailable;
  final bool pacDetected;
  final SteamExternalProxy? externalHttpProxy;
  bool get hasExternal =>
      systemProxyDetected || vpnOrTunnelDetected || pacDetected;
}

class SteamAccelerationNode {
  const SteamAccelerationNode({
    required this.id,
    required this.name,
    required this.type,
  });
  final String id;
  final String name;
  final String type;
}

class SteamAccelerationState {
  const SteamAccelerationState({
    this.phase = SteamAccelerationPhase.off,
    this.configured = false,
    this.autoStart = false,
    this.nodes = const [],
    this.selectedNodeId,
    this.environment = const SteamAccelerationEnvironment(),
    this.error,
    this.skippedNodes = 0,
  });
  final SteamAccelerationPhase phase;
  final bool configured;
  final bool autoStart;
  final List<SteamAccelerationNode> nodes;
  final String? selectedNodeId;
  final SteamAccelerationEnvironment environment;
  final SteamAccelerationError? error;
  final int skippedNodes;
}

class SteamAccelerationException implements Exception {
  const SteamAccelerationException(this.code);
  final SteamAccelerationError code;
  @override
  String toString() => 'SteamAccelerationException(${code.name})';
}
