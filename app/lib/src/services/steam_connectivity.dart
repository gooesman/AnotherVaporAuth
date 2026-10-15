import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'steam_acceleration.dart';
import 'steam_network.dart';

enum SteamConnectionStatus {
  unchecked,
  checking,
  available,
  partial,
  unavailable,
}

enum SteamConnectionRoute {
  direct,
  internal,
  externalProxy,
  system,
  unresolvedProxy,
}

class SteamConnectionResult {
  const SteamConnectionResult({required this.api, required this.community});
  final bool api;
  final bool community;
  SteamConnectionStatus get status => api && community
      ? SteamConnectionStatus.available
      : api || community
      ? SteamConnectionStatus.partial
      : SteamConnectionStatus.unavailable;
}

class SteamConnectionState {
  const SteamConnectionState({
    this.status = SteamConnectionStatus.unchecked,
    this.route = SteamConnectionRoute.direct,
    this.result,
    this.checkedAt,
  });
  final SteamConnectionStatus status;
  final SteamConnectionRoute route;
  final SteamConnectionResult? result;
  final DateTime? checkedAt;
}

/// Anonymous read-only checks over the very same route used by AVA's clients.
/// No account, cookie, subscription URL or proxy credential is added to Steam
/// headers. A local listener/process alone never counts as connectivity.
class SteamConnectivityProbe {
  SteamConnectivityProbe({Dio Function()? createClient})
    : _createClient = createClient ?? _client;

  final Dio Function() _createClient;
  static Dio _client() => SteamNetwork.createDio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      followRedirects: false,
    ),
  );

  Future<SteamConnectionResult> check(CancelToken cancel) async {
    final client = _createClient();
    try {
      final result = await Future.wait([
        _api(
          client,
          cancel,
        ).timeout(const Duration(seconds: 12), onTimeout: () => false),
        _community(
          client,
          cancel,
        ).timeout(const Duration(seconds: 12), onTimeout: () => false),
      ]);
      return SteamConnectionResult(api: result[0], community: result[1]);
    } catch (_) {
      return const SteamConnectionResult(api: false, community: false);
    } finally {
      cancel.cancel();
      client.close(force: true);
    }
  }

  Future<bool> _api(Dio client, CancelToken cancel) async {
    try {
      // The existing anonymous clock endpoint; checking does not alter TOTP
      // time alignment or request any authentication challenge.
      final response = await client.post<Map<String, dynamic>>(
        'https://api.steampowered.com/ITwoFactorService/QueryTime/v0001',
        data: FormData.fromMap({'steamid': '0'}),
        options: Options(responseType: ResponseType.json),
        cancelToken: cancel,
      );
      final body = response.data?['response'];
      final serverTime = body is Map
          ? int.tryParse('${body['server_time'] ?? ''}')
          : null;
      return response.statusCode == 200 && serverTime != null && serverTime > 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _community(Dio client, CancelToken cancel) async {
    try {
      final response = await client.get<ResponseBody>(
        'https://steamcommunity.com/',
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
        cancelToken: cancel,
      );
      // TLS authenticates Steam. The response headers are enough to establish
      // reachability; don't download the whole Community home page or redirect.
      await response.data?.stream.listen((_) {}).cancel();
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 400;
    } catch (_) {
      return false;
    }
  }
}

typedef _RouteStamp = (
  SteamConnectionRoute,
  SteamNetworkProxy?,
  (bool, bool, bool, bool),
);

/// One check when an accelerated route becomes active, on stale foreground
/// resumes, and on explicit checks.
/// No timer, retries or background polling: a timestamped result is a snapshot.
class SteamConnectivityMonitor extends ChangeNotifier {
  SteamConnectivityMonitor(
    this._service, {
    required this.effectiveProxy,
    SteamConnectivityProbe? probe,
    DateTime Function()? now,
  }) : _probe = probe ?? SteamConnectivityProbe(),
       _now = now ?? DateTime.now {
    _service.addListener(_routeChanged);
    _routeChanged();
  }

  final SteamAccelerationService _service;
  final SteamNetworkProxy? Function() effectiveProxy;
  final SteamConnectivityProbe _probe;
  final DateTime Function() _now;
  SteamConnectionState _state = const SteamConnectionState();
  SteamConnectionState get state => _state;
  _RouteStamp? _route;
  CancelToken? _cancel;
  int _generation = 0;
  bool _disposed = false;

  _RouteStamp _currentRoute() {
    final acceleration = _service.state;
    final environment = acceleration.environment;
    final proxy = effectiveProxy();
    final route = environment.externalHttpProxy != null && proxy != null
        ? SteamConnectionRoute.externalProxy
        : environment.vpnOrTunnelDetected
        ? SteamConnectionRoute.system
        : environment.hasExternal
        ? SteamConnectionRoute.unresolvedProxy
        : acceleration.phase == SteamAccelerationPhase.running && proxy != null
        ? SteamConnectionRoute.internal
        : SteamConnectionRoute.direct;
    return (
      route,
      proxy,
      (
        environment.vpnOrTunnelDetected,
        environment.pacDetected,
        environment.systemProxyDetected,
        environment.detectionAvailable,
      ),
    );
  }

  void _routeChanged() {
    if (_disposed) return;
    final route = _currentRoute();
    if (route == _route) return;
    _route = route;
    _generation++;
    _cancel?.cancel();
    _cancel = null;
    _state = SteamConnectionState(route: route.$1);
    notifyListeners();
    if (route.$1 != SteamConnectionRoute.direct) unawaited(check());
  }

  Future<void> check() async {
    if (_disposed || _state.status == SteamConnectionStatus.checking) return;
    final generation = ++_generation;
    final route = _currentRoute();
    _route = route;
    // Dart sockets do not evaluate system PAC rules. A detected setting is
    // not evidence that these requests use an external proxy or VPN.
    if (route.$1 == SteamConnectionRoute.unresolvedProxy) {
      _cancel?.cancel();
      _cancel = null;
      _state = SteamConnectionState(
        route: route.$1,
        status: SteamConnectionStatus.unavailable,
      );
      notifyListeners();
      return;
    }
    final cancel = CancelToken();
    _cancel = cancel;
    _state = SteamConnectionState(
      route: route.$1,
      status: SteamConnectionStatus.checking,
    );
    notifyListeners();
    SteamConnectionResult result;
    try {
      result = await _probe.check(cancel);
    } catch (_) {
      result = const SteamConnectionResult(api: false, community: false);
    }
    if (_disposed || generation != _generation || route != _currentRoute()) {
      return;
    }
    _cancel = null;
    _state = SteamConnectionState(
      route: route.$1,
      status: result.status,
      result: result,
      checkedAt: _now(),
    );
    notifyListeners();
  }

  /// Foreground-only freshness check. A brief app switch does not send another
  /// probe, while an old success cannot remain green after a long suspension.
  Future<void> refreshIfStale() async {
    if (_disposed ||
        _currentRoute().$1 == SteamConnectionRoute.direct ||
        _currentRoute().$1 == SteamConnectionRoute.unresolvedProxy) {
      return;
    }
    final checkedAt = _state.checkedAt;
    if (checkedAt == null ||
        _now().difference(checkedAt) >= const Duration(minutes: 1)) {
      await check();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancel?.cancel();
    _service.removeListener(_routeChanged);
    super.dispose();
  }
}
