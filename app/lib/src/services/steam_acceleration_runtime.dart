import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'steam_acceleration_types.dart';

const steamCoreVersion = 'v1.19.32';
const _windowsArchiveUrl =
    'https://github.com/MetaCubeX/mihomo/releases/download/'
    'v1.19.32/mihomo-windows-amd64-v1-v1.19.32.zip';
const _windowsArchiveHash =
    '00549b347d8e124600e46cac67d59293358454f465e9d86d2511567da56b7029';
const _windowsExecutableHash =
    '0b54ea7b10e26f6ca628b49e77c13ad9b2587b23393a5b715769cbaeed012af6';

abstract class SteamAccelerationRuntime {
  bool get supported;
  Future<SteamAccelerationEnvironment> detectEnvironment();
  Future<void> start(String configuration, SteamProxyEndpoint endpoint);
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
  Future<void> start(String configuration, SteamProxyEndpoint endpoint) async {
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
        final executable = await _prepareWindowsCore(base);
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

  Future<File> _prepareWindowsCore(Directory base) async {
    final folder = Directory(p.join(base.path, steamCoreVersion));
    await folder.create(recursive: true);
    final executable = File(p.join(folder.path, 'ava-steam-core.exe'));
    if (await executable.exists() &&
        await _fileHash(executable) == _windowsExecutableHash) {
      return executable;
    }
    final bytes = await downloadBoundedHttps(
      Uri.parse(_windowsArchiveUrl),
      maxBytes: 32 * 1024 * 1024,
      allowedHosts: const {
        'github.com',
        'release-assets.githubusercontent.com',
        'objects.githubusercontent.com',
      },
      timeout: const Duration(minutes: 5),
    );
    if (sha256.convert(bytes).toString() != _windowsArchiveHash) {
      throw const SteamAccelerationException(
        SteamAccelerationError.coreIntegrity,
      );
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    // Fixed upstream archive has exactly one flat executable. No path extraction.
    if (archive.length != 1 ||
        archive.first.name != 'mihomo-windows-amd64-v1.exe' ||
        !archive.first.isFile ||
        archive.first.size > 80 * 1024 * 1024) {
      throw const SteamAccelerationException(
        SteamAccelerationError.coreIntegrity,
      );
    }
    final content = archive.first.content;
    if (sha256.convert(content).toString() != _windowsExecutableHash) {
      throw const SteamAccelerationException(
        SteamAccelerationError.coreIntegrity,
      );
    }
    final temporary = File('${executable.path}.pending');
    await temporary.writeAsBytes(content, flush: true);
    if (await executable.exists()) await executable.delete();
    await temporary.rename(executable.path);
    return executable;
  }

  Future<String> _fileHash(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

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

/// Bounded direct client, separate from Steam sessions. Diagnostics never escape
/// as Dio exceptions because request URLs may include subscription credentials.
Future<List<int>> downloadBoundedHttps(
  Uri uri, {
  required int maxBytes,
  Set<String>? allowedHosts,
  Duration timeout = const Duration(seconds: 40),
}) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: false,
      validateStatus: (_) => true,
      headers: {'User-Agent': 'AVA-Steam-Acceleration/1'},
    ),
  );
  final cancellation = CancelToken();
  final deadline = Timer(timeout, () => cancellation.cancel());
  try {
    var target = uri;
    for (var redirects = 0; redirects <= 4; redirects++) {
      if (target.scheme != 'https' ||
          target.host.isEmpty ||
          target.userInfo.isNotEmpty ||
          allowedHosts != null && !allowedHosts.contains(target.host)) {
        throw const FormatException();
      }
      final response = await dio.getUri<ResponseBody>(
        target,
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancellation,
      );
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value('location');
        await response.data?.stream.drain<void>();
        if (location == null) throw const FormatException();
        target = target.resolve(location);
        continue;
      }
      if (response.statusCode != 200 || response.data == null) {
        throw const FormatException();
      }
      final data = <int>[];
      await for (final chunk in response.data!.stream) {
        if (data.length + chunk.length > maxBytes) {
          throw const FormatException();
        }
        data.addAll(chunk);
      }
      return data;
    }
    throw const FormatException();
  } catch (_) {
    throw const SteamAccelerationException(SteamAccelerationError.network);
  } finally {
    deadline.cancel();
    cancellation.cancel();
    dio.close(force: true);
  }
}
