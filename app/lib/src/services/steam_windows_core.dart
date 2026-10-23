import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'steam_acceleration_types.dart';

const steamCoreVersion = 'v1.19.32';

/// Optional Windows component, downloaded only when acceleration is started.
/// Mirrors carry this one public archive only; credentials never enter this
/// client. Both the archive and extracted executable use pinned upstream hashes.
class SteamWindowsCore {
  SteamWindowsCore({Dio? dio})
    : _dio = dio ?? _directClient(),
      _archiveHash = archiveHash,
      _executableHash = executableHash;

  @visibleForTesting
  SteamWindowsCore.test(
    this._dio, {
    required String archiveDigest,
    required String executableDigest,
  }) : _archiveHash = archiveDigest,
       _executableHash = executableDigest;

  static const officialUrl =
      'https://github.com/MetaCubeX/mihomo/releases/download/'
      'v1.19.32/mihomo-windows-amd64-v1-v1.19.32.zip';
  static const archiveHash =
      '00549b347d8e124600e46cac67d59293358454f465e9d86d2511567da56b7029';
  static const executableHash =
      '0b54ea7b10e26f6ca628b49e77c13ad9b2587b23393a5b715769cbaeed012af6';
  static const sources = [
    'https://axisnow.gh-proxy.org/$officialUrl',
    'https://v4.gh-proxy.org/$officialUrl',
    officialUrl,
  ];
  static const _officialHosts = {
    'github.com',
    'release-assets.githubusercontent.com',
    'objects.githubusercontent.com',
    'objects-origin.githubusercontent.com',
    'github-releases.githubusercontent.com',
  };
  static const _archiveLimit = 32 * 1024 * 1024;
  final Dio _dio;
  final String _archiveHash;
  final String _executableHash;

  static Dio _directClient() {
    final dio = Dio();
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
    );
    return dio;
  }

  Future<File> prepare(Directory base, {VoidCallback? onDownload}) async {
    final folder = Directory(p.join(base.path, steamCoreVersion));
    await folder.create(recursive: true);
    final executable = File(p.join(folder.path, 'ava-steam-core.exe'));
    if (await executable.exists() &&
        await _fileHash(executable) == _executableHash) {
      return executable;
    }
    onDownload?.call();
    var integrityFailure = false;
    for (final source in sources) {
      try {
        final bytes = await _download(Uri.parse(source));
        // Hashing and decompressing a 60 MB executable must not stall frames.
        final content = await compute(_extractWindowsCore, (
          bytes,
          _archiveHash,
          _executableHash,
        ));
        final temporary = File('${executable.path}.pending');
        try {
          await temporary.writeAsBytes(content, flush: true);
          if (await executable.exists()) await executable.delete();
          await temporary.rename(executable.path);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
        return executable;
      } on SteamAccelerationException catch (error) {
        if (error.code == SteamAccelerationError.coreIntegrity) {
          integrityFailure = true;
        } else if (error.code != SteamAccelerationError.coreDownload) {
          rethrow;
        }
      }
    }
    throw SteamAccelerationException(
      integrityFailure
          ? SteamAccelerationError.coreIntegrity
          : SteamAccelerationError.coreDownload,
    );
  }

  Future<List<int>> _download(Uri source) async {
    final mirror = source.host != 'github.com';
    final cancel = CancelToken();
    // Failed/idle sources give way quickly; a progressing download has a
    // bounded total duration and does not block the UI isolate.
    final deadline = Timer(const Duration(minutes: 2), () => cancel.cancel());
    try {
      var target = source;
      for (var redirects = 0; redirects <= 4; redirects++) {
        final response = await _dio
            .getUri<ResponseBody>(
              target,
              cancelToken: cancel,
              options: Options(
                responseType: ResponseType.stream,
                followRedirects: false,
                validateStatus: (_) => true,
                sendTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
                headers: const {'User-Agent': 'GooeSteamKit-Component/1'},
              ),
            )
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                cancel.cancel();
                throw const SteamAccelerationException(
                  SteamAccelerationError.coreDownload,
                );
              },
            );
        if (const [301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers.value('location');
          await response.data?.stream.listen(null).cancel();
          // A mirror cannot choose another endpoint. Only official GitHub
          // redirects may reach the explicitly approved asset CDN hosts.
          if (mirror || location == null || redirects == 4) {
            throw const FormatException();
          }
          final next = target.resolve(location);
          if (next.scheme != 'https' ||
              next.port != 443 ||
              next.userInfo.isNotEmpty ||
              next.hasFragment ||
              !_officialHosts.contains(next.host)) {
            throw const FormatException();
          }
          target = next;
          continue;
        }
        if (response.statusCode != 200 || response.data == null) {
          await response.data?.stream.listen(null).cancel();
          throw const FormatException();
        }
        final declared = int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        );
        if (declared != null && (declared <= 0 || declared > _archiveLimit)) {
          await response.data!.stream.listen(null).cancel();
          throw const FormatException();
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.data!.stream.timeout(
          const Duration(seconds: 12),
        )) {
          if (bytes.length + chunk.length > _archiveLimit) {
            throw const FormatException();
          }
          bytes.add(chunk);
        }
        if (bytes.isEmpty || declared != null && bytes.length != declared) {
          throw const FormatException();
        }
        return bytes.takeBytes();
      }
      throw const FormatException();
    } catch (_) {
      throw const SteamAccelerationException(
        SteamAccelerationError.coreDownload,
      );
    } finally {
      deadline.cancel();
      cancel.cancel();
    }
  }

  Future<String> _fileHash(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  void close() => _dio.close(force: true);
}

List<int> _extractWindowsCore((List<int>, String, String) input) {
  try {
    final (bytes, archiveHash, executableHash) = input;
    if (sha256.convert(bytes).toString() != archiveHash) {
      throw const FormatException();
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    // No archive paths are extracted to disk, even after digest verification.
    if (archive.length != 1 ||
        archive.first.name != 'mihomo-windows-amd64-v1.exe' ||
        !archive.first.isFile ||
        archive.first.isSymbolicLink ||
        archive.first.size > 80 * 1024 * 1024) {
      throw const FormatException();
    }
    final content = archive.first.content;
    if (sha256.convert(content).toString() != executableHash) {
      throw const FormatException();
    }
    return content;
  } catch (_) {
    throw const SteamAccelerationException(
      SteamAccelerationError.coreIntegrity,
    );
  }
}
