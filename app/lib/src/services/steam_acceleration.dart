import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'steam_acceleration_runtime.dart';
import 'steam_acceleration_subscription.dart';
import 'steam_acceleration_types.dart';

export 'steam_acceleration_types.dart';

class SteamAccelerationStore {
  SteamAccelerationStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );
  final FlutterSecureStorage _storage;
  static const _key = 'ava.steam.acceleration.v1';
  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  Future<void> clear() => _storage.delete(key: _key);
}

/// Optional, app-local acceleration. Construction and load never contact a
/// subscription or start a core. Call start(automatic: true) after load on app
/// startup; a missing subscription or disabled auto-start is a strict no-op.
class SteamAccelerationService extends ChangeNotifier {
  SteamAccelerationService({
    SteamAccelerationStore? store,
    SteamAccelerationRuntime? runtime,
    Future<String> Function(Uri)? fetchSubscription,
    this.environmentInterval = const Duration(seconds: 15),
  }) : _store = store ?? SteamAccelerationStore(),
       _runtime = runtime ?? PlatformSteamAccelerationRuntime(),
       _fetchSubscription = fetchSubscription ?? _fetch;

  final SteamAccelerationStore _store;
  final SteamAccelerationRuntime _runtime;
  final Future<String> Function(Uri) _fetchSubscription;
  final Duration environmentInterval;
  SteamAccelerationState _state = const SteamAccelerationState();
  SteamAccelerationState get state => _state;
  bool get supported => _runtime.supported;
  SteamProxyEndpoint? _endpoint;
  SteamProxyEndpoint? get proxyEndpoint => _endpoint;
  String? _subscriptionUrl;
  SteamAccelerationSubscription? _catalog;
  bool _autoStart = false;
  String? _selected;
  SteamAccelerationEnvironment _environment =
      const SteamAccelerationEnvironment();
  Future<void>? _load;
  Future<void> _serial = Future<void>.value();
  Timer? _monitor;
  int _epoch = 0;
  bool _disposed = false;
  bool _checking = false;
  bool _manuallyStopped = false;
  bool _startedAutomatically = false;

  static Future<String> _fetch(Uri uri) async =>
      utf8.decode(await downloadBoundedHttps(uri, maxBytes: 2 * 1024 * 1024));

  Future<void> load() => _load ??= _enqueue(() async {
    try {
      final raw = await _store.read();
      if (raw != null) {
        final saved = jsonDecode(raw);
        if (saved is! Map || saved['v'] != 1) throw const FormatException();
        _subscriptionUrl = _validatedUrl(saved['url'] as String).toString();
        _autoStart = saved['auto'] == true;
        if (saved['nodes'] is String) {
          _catalog = SteamAccelerationSubscription.parse(
            saved['nodes'] as String,
          );
        }
        _selected = saved['selected'] is String
            ? saved['selected'] as String
            : null;
        _repairSelection();
      }
      _publish(SteamAccelerationPhase.off);
      _startMonitoring();
    } catch (_) {
      _subscriptionUrl = null;
      _catalog = null;
      _autoStart = false;
      _selected = null;
      _publish(SteamAccelerationPhase.error, SteamAccelerationError.storage);
    }
  });

  Future<void> configure({
    required String subscriptionUrl,
    bool autoStart = false,
  }) async {
    await load();
    Uri uri;
    try {
      uri = _validatedUrl(subscriptionUrl.trim());
    } catch (_) {
      _publish(
        SteamAccelerationPhase.error,
        SteamAccelerationError.invalidSubscription,
      );
      return;
    }
    final ticket = ++_epoch;
    _endpoint = null;
    await _enqueue(() async {
      await _runtime.stop();
      if (!_current(ticket)) return;
      final record = jsonEncode({
        'v': 1,
        'url': uri.toString(),
        'auto': autoStart,
      });
      try {
        await _store.write(record);
      } catch (_) {
        _publish(SteamAccelerationPhase.error, SteamAccelerationError.storage);
        return;
      }
      if (!_current(ticket)) return;
      _subscriptionUrl = uri.toString();
      _catalog = null;
      _selected = null;
      _autoStart = autoStart;
      _manuallyStopped = false;
      _publish(SteamAccelerationPhase.off);
      _startMonitoring();
    });
  }

  Future<void> refreshSubscription() async {
    await load();
    if (_subscriptionUrl == null) {
      _publish(
        SteamAccelerationPhase.error,
        SteamAccelerationError.invalidSubscription,
      );
      return;
    }
    final ticket = ++_epoch;
    _endpoint = null;
    await _enqueue(() async {
      await _runtime.stop();
      if (!_current(ticket)) return;
      _publish(SteamAccelerationPhase.loadingSubscription);
      try {
        final catalog = SteamAccelerationSubscription.parse(
          await _fetchSubscription(Uri.parse(_subscriptionUrl!)),
        );
        if (!_current(ticket)) return;
        final selected = catalog.nodes.any((e) => e.id == _selected)
            ? _selected
            : catalog.nodes.first.id;
        await _persist(catalog: catalog, selected: selected);
        if (!_current(ticket)) return;
        _catalog = catalog;
        _selected = selected;
        _publish(SteamAccelerationPhase.off);
      } catch (error) {
        if (_current(ticket)) {
          _publish(SteamAccelerationPhase.error, _error(error));
        }
      }
    });
  }

  Future<void> setAutoStart(bool value) async {
    await load();
    await _enqueue(() async {
      if (_subscriptionUrl == null) return;
      try {
        await _persist(autoStart: value);
        _autoStart = value;
        _publish(_state.phase, _state.error);
        _startMonitoring();
      } catch (_) {
        _publish(SteamAccelerationPhase.error, SteamAccelerationError.storage);
      }
    });
  }

  Future<void> selectNode(String id) async {
    await load();
    if (_catalog?.nodes.any((node) => node.id == id) != true) return;
    await stop();
    await _enqueue(() async {
      try {
        await _persist(selected: id);
        _selected = id;
        _publish(SteamAccelerationPhase.off);
      } catch (_) {
        _publish(SteamAccelerationPhase.error, SteamAccelerationError.storage);
      }
    });
  }

  Future<void> start({bool automatic = false}) async {
    await load();
    if (_disposed ||
        _subscriptionUrl == null ||
        automatic && (!_autoStart || _manuallyStopped)) {
      return;
    }
    if (_state.phase == SteamAccelerationPhase.starting ||
        _state.phase == SteamAccelerationPhase.loadingSubscription ||
        _state.phase == SteamAccelerationPhase.running) {
      return;
    }
    if (!supported) {
      _publish(
        SteamAccelerationPhase.error,
        SteamAccelerationError.unsupportedPlatform,
      );
      return;
    }
    if (!automatic) _manuallyStopped = false;
    final ticket = ++_epoch;
    await _enqueue(() async {
      if (!_current(ticket)) return;
      _publish(SteamAccelerationPhase.starting);
      try {
        _environment = await _detectEnvironment();
        if (!_current(ticket)) return;
        if (_environment.hasExternal ||
            automatic && !_environment.detectionAvailable) {
          _publish(
            SteamAccelerationPhase.pausedExternal,
            !_environment.detectionAvailable
                ? SteamAccelerationError.environmentUnknown
                : null,
          );
          return;
        }
        if (_catalog == null) {
          final catalog = SteamAccelerationSubscription.parse(
            await _fetchSubscription(Uri.parse(_subscriptionUrl!)),
          );
          if (!_current(ticket)) return;
          await _persist(catalog: catalog, selected: catalog.nodes.first.id);
          if (!_current(ticket)) return;
          _catalog = catalog;
          _selected = catalog.nodes.first.id;
        }
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = socket.port;
        await socket.close();
        if (!_current(ticket)) return;
        final random = Random.secure();
        String secret() => base64Url
            .encode(List.generate(24, (_) => random.nextInt(256)))
            .replaceAll('=', '');
        final endpoint = SteamProxyEndpoint(
          host: '127.0.0.1',
          port: port,
          username: secret(),
          password: secret(),
        );
        await _runtime.start(
          buildSteamCoreConfiguration(
            _catalog!.configuration(_selected!),
            endpoint,
          ),
          endpoint,
        );
        if (!_current(ticket)) {
          await _runtime.stop();
          return;
        }
        // A proxy/VPN may appear while the binary is downloading/starting.
        _environment = await _detectEnvironment();
        if (!_current(ticket) ||
            _environment.hasExternal ||
            automatic && !_environment.detectionAvailable) {
          await _runtime.stop();
          if (_current(ticket)) {
            _publish(
              SteamAccelerationPhase.pausedExternal,
              !_environment.detectionAvailable
                  ? SteamAccelerationError.environmentUnknown
                  : null,
            );
          }
          return;
        }
        _startedAutomatically = automatic;
        _endpoint = endpoint;
        _publish(SteamAccelerationPhase.running);
        _startMonitoring();
      } catch (error) {
        _endpoint = null;
        await _runtime.stop();
        if (_current(ticket)) {
          _publish(SteamAccelerationPhase.error, _error(error));
        }
      }
    });
  }

  /// Immediate route removal; queued network/download results cannot restart it.
  Future<void> stop() {
    _epoch++;
    _manuallyStopped = true;
    _endpoint = null;
    _publish(SteamAccelerationPhase.off);
    return _enqueue(() async {
      try {
        await _runtime.stop();
      } catch (_) {
        _publish(
          SteamAccelerationPhase.error,
          SteamAccelerationError.startFailed,
        );
      }
    });
  }

  Future<void> checkEnvironment() async {
    if (_disposed || _checking) return;
    _checking = true;
    try {
      final environment = await _detectEnvironment();
      if (_disposed) return;
      _environment = environment;
      if ((environment.hasExternal ||
              _startedAutomatically && !environment.detectionAvailable) &&
          _endpoint != null) {
        final ticket = ++_epoch;
        _endpoint = null;
        final error = !environment.detectionAvailable
            ? SteamAccelerationError.environmentUnknown
            : null;
        _publish(SteamAccelerationPhase.pausedExternal, error);
        await _enqueue(() async {
          await _runtime.stop();
          if (_current(ticket)) {
            _publish(SteamAccelerationPhase.pausedExternal, error);
          }
        });
      } else if (_endpoint != null && !await _runtime.isRunning()) {
        _endpoint = null;
        _publish(
          SteamAccelerationPhase.error,
          SteamAccelerationError.startFailed,
        );
      } else {
        _publish(_state.phase, _state.error);
      }
      if (!_environment.hasExternal &&
          _environment.detectionAvailable &&
          _state.phase == SteamAccelerationPhase.pausedExternal &&
          _autoStart &&
          !_manuallyStopped) {
        await start(automatic: true);
      }
    } catch (_) {
      _endpoint = null;
      try {
        await _runtime.stop();
      } catch (_) {}
      _publish(
        SteamAccelerationPhase.error,
        SteamAccelerationError.startFailed,
      );
    } finally {
      _checking = false;
    }
  }

  Future<void> clearConfiguration() async {
    await stop();
    await _enqueue(() async {
      try {
        await _store.clear();
        _subscriptionUrl = null;
        _catalog = null;
        _selected = null;
        _autoStart = false;
        _monitor?.cancel();
        _monitor = null;
        _publish(SteamAccelerationPhase.off);
      } catch (_) {
        _publish(SteamAccelerationPhase.error, SteamAccelerationError.storage);
      }
    });
  }

  Future<void> _persist({
    SteamAccelerationSubscription? catalog,
    String? selected,
    bool? autoStart,
  }) async {
    try {
      await _store.write(
        jsonEncode({
          'v': 1,
          'url': _subscriptionUrl,
          'auto': autoStart ?? _autoStart,
          'selected': selected ?? _selected,
          'nodes': (catalog ?? _catalog)?.toSecureCache(),
        }),
      );
    } catch (_) {
      throw const SteamAccelerationException(SteamAccelerationError.storage);
    }
  }

  void _repairSelection() {
    if (_catalog == null) {
      _selected = null;
      return;
    }
    if (!_catalog!.nodes.any((e) => e.id == _selected)) {
      _selected = _catalog!.nodes.first.id;
    }
  }

  void _startMonitoring() {
    if (_disposed || _subscriptionUrl == null || _monitor != null) return;
    _monitor = Timer.periodic(environmentInterval, (_) {
      unawaited(checkEnvironment());
    });
  }

  Future<SteamAccelerationEnvironment> _detectEnvironment() async {
    try {
      return await _runtime.detectEnvironment();
    } catch (_) {
      return const SteamAccelerationEnvironment();
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _serial.then((_) async {
      if (_disposed) return;
      try {
        await action();
      } catch (error) {
        _endpoint = null;
        try {
          await _runtime.stop();
        } catch (_) {}
        _publish(
          SteamAccelerationPhase.error,
          error is SteamAccelerationException
              ? error.code
              : SteamAccelerationError.startFailed,
        );
      }
    });
    _serial = next.catchError((_) {});
    return next;
  }

  bool _current(int ticket) => !_disposed && ticket == _epoch;
  SteamAccelerationError _error(Object error) =>
      error is SteamAccelerationException
      ? error.code
      : SteamAccelerationError.network;

  void _publish(SteamAccelerationPhase phase, [SteamAccelerationError? error]) {
    if (_disposed) return;
    if (phase != SteamAccelerationPhase.running && _endpoint != null) {
      _endpoint = null;
      unawaited(_enqueue(() => _runtime.stop()));
    }
    _state = SteamAccelerationState(
      phase: phase,
      configured: _subscriptionUrl != null,
      autoStart: _autoStart,
      nodes: _catalog?.nodes ?? const [],
      selectedNodeId: _selected,
      environment: _environment,
      error: error,
      skippedNodes: _catalog?.skipped ?? 0,
    );
    notifyListeners();
  }

  static Uri _validatedUrl(String text) {
    final uri = Uri.tryParse(text);
    if (text.length > 4096 ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535 ||
        text.contains(RegExp(r'[\x00-\x20]'))) {
      throw const FormatException();
    }
    return uri;
  }

  @override
  void dispose() {
    _epoch++;
    _endpoint = null;
    _monitor?.cancel();
    _disposed = true;
    unawaited(_runtime.stop().catchError((_) {}));
    super.dispose();
  }
}
