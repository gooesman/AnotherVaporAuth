import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'steam_acceleration_types.dart';
import 'steam_windows_core.dart';

abstract class SteamAccelerationRuntime {
  bool get supported;
  Future<SteamAccelerationEnvironment> detectEnvironment();
  Future<void> start(
    String configuration,
    SteamProxyEndpoint endpoint, {
    void Function(SteamAccelerationPhase)? onPhaseChanged,
  });
  Future<bool> isRunning();
  Future<void> stop();
}

/// No process or network work happens in this constructor.
class PlatformSteamAccelerationRuntime implements SteamAccelerationRuntime {
  static const _channel = MethodChannel('ava/steam_acceleration');
  Process? _process;
  Directory? _runDirectory;
  @override
  bool get supported => Platform.isWindows || Platform.isAndroid;

  @override
  Future<SteamAccelerationEnvironment> detectEnvironment() async {
    try {
      final value = await _channel.invokeMapMethod<String, dynamic>(
        'environment',
      );
      if (value == null) return const SteamAccelerationEnvironment();
      final proxy = parseExternalSteamProxy(value['httpProxy']);
      return SteamAccelerationEnvironment(
        detectionAvailable: value['available'] == true,
        systemProxyDetected: value['systemProxy'] == true,
        vpnOrTunnelDetected: value['vpnOrTunnel'] == true,
        pacDetected: value['pac'] == true,
        externalHttpProxy: proxy,
      );
    } catch (_) {
      return const SteamAccelerationEnvironment();
    }
  }

  @override
  Future<void> start(
    String configuration,
    SteamProxyEndpoint endpoint, {
    void Function(SteamAccelerationPhase)? onPhaseChanged,
  }) async {
    if (!supported) {
      throw const SteamAccelerationException(
        SteamAccelerationError.unsupportedPlatform,
      );
    }
    await stop();
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod<void>('start', {
          'configuration': configuration,
        });
      } else {
        final base = Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            'steam_acceleration',
          ),
        );
        await base.create(recursive: true);
        // Native verifies this exact app-support subtree, removes inherited
        // access and grants only the current user + SYSTEM before any secrets.
        await _channel.invokeMethod<void>('restrictDirectory', {
          'path': base.path,
        });
        final core = SteamWindowsCore();
        late final File executable;
        try {
          executable = await core.prepare(
            base,
            onDownload: () =>
                onPhaseChanged?.call(SteamAccelerationPhase.downloadingCore),
          );
        } finally {
          core.close();
        }
        onPhaseChanged?.call(SteamAccelerationPhase.starting);
        final run = await base.createTemp('run-');
        _runDirectory = run;
        final process = await Process.start(
          executable.path,
          ['-d', run.path, '-f', '-'],
          workingDirectory: run.path,
          environment: _cleanEnvironment(),
          includeParentEnvironment: false,
          mode: ProcessStartMode.normal,
        );
        _process = process;
        // Never retain or print core diagnostics: they can contain credentials.
        unawaited(process.stdout.drain<void>());
        unawaited(process.stderr.drain<void>());
        await _channel.invokeMethod<void>('ownProcess', {'pid': process.pid});
        // Upstream supports -f -: send secrets through the child's anonymous
        // pipe only after Job ownership, never command-line args or disk files.
        process.stdin.write(configuration);
        await process.stdin.flush();
        await process.stdin.close();
        unawaited(
          process.exitCode.then((_) {
            if (identical(_process, process)) _process = null;
          }),
        );
      }
      await _waitForAuthenticatedListener(endpoint);
    } on SteamAccelerationException {
      await stop();
      rethrow;
    } on PlatformException catch (error) {
      await stop();
      throw SteamAccelerationException(
        error.code == 'core_unavailable'
            ? SteamAccelerationError.coreUnavailable
            : error.code == 'core_integrity'
            ? SteamAccelerationError.coreIntegrity
            : SteamAccelerationError.startFailed,
      );
    } catch (_) {
      await stop();
      throw const SteamAccelerationException(
        SteamAccelerationError.startFailed,
      );
    }
  }

  Map<String, String> _cleanEnvironment() => {
    for (final key in ['SystemRoot', 'WINDIR', 'TEMP', 'TMP', 'USERPROFILE'])
      key: ?Platform.environment[key],
    // Do not inherit proxy variables or arbitrary core SAFE_PATHS overrides.
  };

  Future<void> _waitForAuthenticatedListener(
    SteamProxyEndpoint endpoint,
  ) async {
    for (var attempt = 0; attempt < 60; attempt++) {
      if (!await isRunning()) break;
      Socket? socket;
      try {
        socket = await Socket.connect(
          endpoint.host,
          endpoint.port,
          timeout: const Duration(milliseconds: 200),
        );
        // This unauthenticated origin-form probe must be rejected locally; it
        // never asks the core to contact Steam or any external destination.
        socket.write(
          'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
        );
        await socket.flush();
        final response = await socket.first.timeout(const Duration(seconds: 1));
        if (ascii
            .decode(response, allowInvalid: true)
            .startsWith('HTTP/1.1 407')) {
          return;
        }
      } catch (_) {
        // Startup readiness only; do not expose socket/core output.
      } finally {
        socket?.destroy();
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw const SteamAccelerationException(SteamAccelerationError.startFailed);
  }

  @override
  Future<bool> isRunning() async {
    if (Platform.isWindows) return _process != null;
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isRunning') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    final process = _process;
    final run = _runDirectory;
    _process = null;
    _runDirectory = null;
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('stop');
      } catch (_) {}
    }
    if (process != null) {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        process.kill(ProcessSignal.sigkill);
      }
    }
    if (run != null) {
      try {
        await run.delete(recursive: true);
      } catch (_) {}
    }
  }
}

SteamExternalProxy? parseExternalSteamProxy(dynamic raw) {
  if (raw is! String || raw.length > 512) return null;
  var text = raw.trim();
  if (text.contains(';') || text.contains('=')) {
    final entries = <String, String>{};
    for (final part in text.split(';')) {
      final split = part.split('=');
      if (split.length == 2) {
        entries[split[0].trim().toLowerCase()] = split[1].trim();
      }
    }
    text = entries['https'] ?? entries['http'] ?? '';
  }
  final uri = Uri.tryParse(text.contains('://') ? text : 'http://$text');
  if (uri == null ||
      uri.scheme != 'http' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      !uri.hasPort ||
      uri.port < 1 ||
      uri.port > 65535 ||
      uri.host.contains(RegExp(r'[\s/\\@]'))) {
    return null;
  }
  return SteamExternalProxy(host: uri.host, port: uri.port);
}
