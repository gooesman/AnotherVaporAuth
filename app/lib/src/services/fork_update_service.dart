import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/fork_update.dart';
import 'fork_update_network.dart';

const kForkReleasesUrl =
    'https://github.com/gooesman/AnotherVaporAuth/releases';
const kForkLatestReleaseApi =
    'https://api.github.com/repos/gooesman/AnotherVaporAuth/releases/latest';

/// Only this fork's public, stable GitHub release metadata is trusted. Optional
/// direct mirrors transport bytes checked against the official asset SHA256.
/// This service never installs anything or shares Steam authentication headers.
///
/// Release metadata (including asset.digest):
/// https://docs.github.com/en/rest/releases/releases#get-the-latest-release
/// Injected Dio instances must be dedicated to this service, not a signed-in
/// Steam session. Production always creates its own unauthenticated client.
class ForkUpdateService {
  ForkUpdateService({
    Dio? dio,
    Dio? mirrorDio,
    Future<Directory> Function()? temporaryDirectory,
    this.parallelDownloads = true,
  }) : _dio = dio ?? ForkUpdateNetwork.createDio(),
       // Existing injected official clients remain fully isolated: tests and
       // diagnostic callers must explicitly inject a mirror client to use it.
       _mirrorDio =
           mirrorDio ??
           (dio == null ? ForkUpdateNetwork.createMirrorDio() : null),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Dio _dio;
  final Dio? _mirrorDio;
  final Future<Directory> Function() _temporaryDirectory;

  /// Allows deterministic comparison with the serial transport in diagnostics.
  final bool parallelDownloads;

  static const maxInstallerBytes = 512 * 1024 * 1024;
  static const maxMetadataBytes = 1024 * 1024;
  static const _parallelThreshold = 8 * 1024 * 1024;
  static const _rangeBytes = 2 * 1024 * 1024;
  static const _rangeWorkers = 4;
  static const _requestTimeout = Duration(seconds: 20);
  static const _chunkTimeout = Duration(seconds: 30);
  static const _downloadTimeout = Duration(minutes: 30);
  static const _mirrorRequestTimeout = Duration(seconds: 8);
  static const _mirrorChunkTimeout = Duration(seconds: 12);
  // Fail idle mirrors quickly without discarding a steadily progressing
  // download on slower mobile networks. The overall 30-minute cap still holds.
  static const _mirrorDownloadTimeout = Duration(minutes: 10);
  static const _maxBuild = 2100000000;
  static final _releaseTag = RegExp(
    r'^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\+([1-9]\d*)$',
  );
  static final _installedVersion = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?$',
  );
  static final _hash = RegExp(r'^[0-9a-f]{64}$');

  Future<ForkUpdateCheck> check({
    required ForkUpdateTarget target,
    required String currentVersion,
    required String currentBuild,
  }) async {
    final installed = currentVersion.length <= 80
        ? _installedVersion.firstMatch(currentVersion)
        : null;
    final installedBuild = int.tryParse(currentBuild);
    if (installed == null ||
        !RegExp(r'^[1-9]\d*$').hasMatch(currentBuild) ||
        installedBuild == null ||
        installedBuild > _maxBuild) {
      return const ForkUpdateCheck(
        status: ForkUpdateCheckStatus.invalidMetadata,
      );
    }

    final cancel = CancelToken();
    final deadline = Timer(_chunkTimeout, () => cancel.cancel('timeout'));
    try {
      final response = await _get(Uri.parse(kForkLatestReleaseApi), cancel);
      if (response.statusCode == 404) {
        await _discard(response.data);
        return const ForkUpdateCheck(status: ForkUpdateCheckStatus.noRelease);
      }
      if (response.statusCode != 200 || response.data == null) {
        await _discard(response.data);
        return const ForkUpdateCheck(
          status: ForkUpdateCheckStatus.networkError,
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.data!.stream.timeout(_chunkTimeout)) {
        if (bytes.length + chunk.length > maxMetadataBytes) {
          throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
        }
        bytes.addAll(chunk);
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
      }
      return _parseCheck(decoded, target, installed, installedBuild);
    } on ForkUpdateException catch (error) {
      return ForkUpdateCheck(
        status: error.code == ForkUpdateErrorCode.networkError
            ? ForkUpdateCheckStatus.networkError
            : ForkUpdateCheckStatus.invalidMetadata,
      );
    } on FormatException {
      return const ForkUpdateCheck(
        status: ForkUpdateCheckStatus.invalidMetadata,
      );
    } catch (_) {
      // Offline, throttled, or unavailable is never described as up to date.
      return ForkUpdateCheck(
        status: cancel.cancelError?.error == 'tooLarge'
            ? ForkUpdateCheckStatus.invalidMetadata
            : ForkUpdateCheckStatus.networkError,
      );
    } finally {
      deadline.cancel();
      cancel.cancel();
    }
  }

  ForkUpdateCheck _parseCheck(
    Map<String, dynamic> data,
    ForkUpdateTarget target,
    RegExpMatch installed,
    int installedBuild,
  ) {
    final tag = data['tag_name'];
    final match = tag is String && tag.length <= 64
        ? _releaseTag.firstMatch(tag)
        : null;
    final build = match == null ? null : int.tryParse(match[4]!);
    if (data['draft'] != false ||
        data['prerelease'] != false ||
        match == null ||
        build == null ||
        build > _maxBuild) {
      throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
    }
    final releaseUrl = _releasePage(tag as String);
    if (data['html_url'] is! String ||
        !_sameUri(Uri.tryParse(data['html_url']), releaseUrl)) {
      throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
    }
    final assets = data['assets'];
    if (assets is! List) {
      throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
    }
    final names = _assetNames(target, tag);
    final matches = assets.whereType<Map<String, dynamic>>().where(
      (asset) => names.contains(asset['name']),
    );
    if (matches.isEmpty) {
      return const ForkUpdateCheck(
        status: ForkUpdateCheckStatus.noCompatibleAsset,
      );
    }
    if (matches.length != 1) {
      throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
    }
    final rawAsset = matches.single;
    final size = rawAsset['size'];
    final name = rawAsset['name'] as String;
    final url = rawAsset['browser_download_url'];
    if (rawAsset['state'] != 'uploaded' ||
        size is! int ||
        size <= 0 ||
        size > maxInstallerBytes ||
        url is! String ||
        !_sameUri(Uri.tryParse(url), _assetUrl(tag, name))) {
      throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
    }
    final digest = rawAsset['digest'];
    final digestMatch = digest is String
        ? RegExp(r'^sha256:([0-9a-fA-F]{64})$').firstMatch(digest)
        : null;
    final release = ForkUpdateRelease(
      target: target,
      tag: tag,
      version: '${match[1]}.${match[2]}.${match[3]}',
      buildNumber: build,
      notes: data['body'] is String ? data['body'] as String : '',
      releaseUrl: releaseUrl,
      asset: ForkUpdateAsset(
        name: name,
        url: _assetUrl(tag, name),
        size: size,
        sha256: digestMatch?[1]?.toLowerCase(),
      ),
    );
    var versionComparison = 0;
    for (var index = 1; index <= 3; index++) {
      versionComparison = BigInt.parse(
        match[index]!,
      ).compareTo(BigInt.parse(installed[index]!));
      if (versionComparison != 0) break;
    }
    if (versionComparison < 0 ||
        (versionComparison == 0 && build <= installedBuild)) {
      return ForkUpdateCheck(
        status: ForkUpdateCheckStatus.upToDate,
        release: release,
      );
    }
    // Every published build uses the shared, monotonic CI build number. In
    // particular Android cannot upgrade an APK with a lower versionCode.
    if (build <= installedBuild) {
      return ForkUpdateCheck(
        status: ForkUpdateCheckStatus.invalidMetadata,
        release: release,
      );
    }
    return ForkUpdateCheck(
      status: release.asset.sha256 == null
          ? ForkUpdateCheckStatus.unverifiable
          : ForkUpdateCheckStatus.available,
      release: release,
    );
  }

  /// Each call owns a random directory; cancellation or failure only removes
  /// that call's partial file. Simultaneous downloads cannot overwrite one
  /// another. The caller controls whether another download may be started.
  Future<VerifiedForkUpdate> download(
    ForkUpdateRelease release, {
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
    ForkUpdateDownloadMode mode = ForkUpdateDownloadMode.automatic,
    void Function(ForkUpdateDownloadSource source)? onSourceChanged,
  }) async {
    _validateRelease(release);
    final cancel = CancelToken();
    if (cancelToken?.isCancelled ?? false) cancel.cancel();
    unawaited(cancelToken?.whenCancel.then((_) => cancel.cancel()));
    final deadline = Timer(_downloadTimeout, () => cancel.cancel('timeout'));
    Directory? ownedDirectory;
    File? partial;
    try {
      _checkCancelled(cancel);
      final updates = await _updatesDirectory();
      _checkCancelled(cancel);
      ownedDirectory = await updates.createTemp('download-');
      await _assertDirectory(ownedDirectory);
      partial = File(p.join(ownedDirectory.path, '${release.asset.name}.part'));
      await partial.create(exclusive: true);
      await _assertFile(partial);
      final routes = [
        if (mode == ForkUpdateDownloadMode.automatic && _mirrorDio != null)
          for (final source in [
            ForkUpdateDownloadSource.axisNow,
            ForkUpdateDownloadSource.v4,
          ])
            _DownloadRoute(
              source,
              _mirrorDio,
              ForkUpdateNetwork.mirrorAssetUrl(source, release.asset.url),
            ),
        _DownloadRoute(
          ForkUpdateDownloadSource.github,
          _dio,
          release.asset.url,
        ),
      ];
      for (final route in routes) {
        _checkCancelled(cancel);
        onSourceChanged?.call(route.source);
        final attempt = CancelToken();
        unawaited(
          cancel.whenCancel.then((error) => attempt.cancel(error.error)),
        );
        final sourceDeadline = route.isMirror
            ? Timer(_mirrorDownloadTimeout, () => attempt.cancel('timeout'))
            : null;
        try {
          await _downloadFromSource(
            partial,
            ownedDirectory,
            release,
            route,
            attempt,
            onProgress,
          );
          _checkCancelled(cancel);
          break;
        } catch (error) {
          // User cancellation never starts another source. Mirror failures,
          // including corrupt data, get one clean attempt from the next route.
          _checkCancelled(cancel);
          final classified = _downloadError(error, attempt);
          if (!route.isMirror ||
              classified.code == ForkUpdateErrorCode.ioError) {
            throw classified;
          }
        } finally {
          sourceDeadline?.cancel();
          attempt.cancel();
        }
      }
      _checkCancelled(cancel);
      await _assertDirectory(ownedDirectory);
      await _assertFile(partial);
      final destination = File(p.join(ownedDirectory.path, release.asset.name));
      if (await FileSystemEntity.type(destination.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const ForkUpdateException(ForkUpdateErrorCode.ioError);
      }
      final file = await partial.rename(destination.path);
      // Keep ownership through the last asynchronous step so a cancellation
      // racing the final rename is also cleaned up by this call's finally.
      partial = file;
      _checkCancelled(cancel);
      partial = null;
      return VerifiedForkUpdate(file: file, release: release);
    } catch (error) {
      throw _downloadError(error, cancel);
    } finally {
      deadline.cancel();
      cancel.cancel();
      if (partial != null && ownedDirectory != null) {
        await _removePartial(partial, ownedDirectory);
      }
    }
  }

  Future<void> _downloadFromSource(
    File partial,
    Directory owner,
    ForkUpdateRelease release,
    _DownloadRoute route,
    CancelToken cancel,
    void Function(int received, int total)? onProgress,
  ) async {
    await _assertDirectory(owner);
    await _assertFile(partial);
    _checkCancelled(cancel);
    // Every source starts from an empty owned file; data from a failed mirror
    // cannot be mixed with the next mirror or the official package.
    RandomAccessFile? output = await partial.open(mode: FileMode.writeOnly);
    try {
      final progress = _DownloadProgress(release.asset.size, onProgress);
      progress.start();
      if (parallelDownloads && release.asset.size >= _parallelThreshold) {
        try {
          await _downloadParallel(release, route, cancel, output, progress);
        } on _RangeUnsupported {
          // All range workers stop before serial fallback reuses this file.
          _checkCancelled(cancel);
          await output.truncate(0);
          await output.setPosition(0);
          await _downloadSerial(release, route, cancel, output, progress);
        }
      } else {
        await _downloadSerial(release, route, cancel, output, progress);
      }
      progress.transferred();
      await output.flush();
      await output.close();
      output = null;
      _checkCancelled(cancel);
      await _verifyPartial(partial, release, cancel);
    } finally {
      // Each transfer waits for its workers before returning. Close the file
      // before the caller can truncate it for a different source.
      await output?.close();
    }
  }

  Future<void> _downloadSerial(
    ForkUpdateRelease release,
    _DownloadRoute route,
    CancelToken cancel,
    RandomAccessFile output,
    _DownloadProgress progress,
  ) async {
    final response = await _downloadResponse(release, route, cancel);
    final body = response.data!;
    final encoding = response.headers.value('content-encoding');
    if (route.isMirror &&
        encoding != null &&
        encoding.toLowerCase() != 'identity') {
      await _discard(body);
      throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
    }
    final length = int.tryParse(response.headers.value('content-length') ?? '');
    if (length != null && length != release.asset.size) {
      await _discard(body);
      throw ForkUpdateException(
        length > maxInstallerBytes
            ? ForkUpdateErrorCode.tooLarge
            : ForkUpdateErrorCode.invalidMetadata,
      );
    }
    var received = 0;
    await for (final chunk in body.stream.timeout(route.chunkTimeout)) {
      _checkCancelled(cancel);
      received += chunk.length;
      if (received > maxInstallerBytes || received > release.asset.size) {
        throw const ForkUpdateException(ForkUpdateErrorCode.tooLarge);
      }
      await output.writeFrom(chunk);
      progress.update(received);
    }
    _checkCancelled(cancel);
    if (received != release.asset.size) {
      throw const ForkUpdateException(ForkUpdateErrorCode.hashMismatch);
    }
  }

  Future<void> _downloadParallel(
    ForkUpdateRelease release,
    _DownloadRoute route,
    CancelToken cancel,
    RandomAccessFile output,
    _DownloadProgress progress,
  ) async {
    final group = CancelToken();
    unawaited(cancel.whenCancel.then((error) => group.cancel(error.error)));
    final writer = _RangeFileWriter(output, group);
    final highestReceived = <int, int>{};
    var aggregate = 0;
    void received(int start, int count) {
      final previous = highestReceived[start] ?? 0;
      if (count <= previous) return;
      highestReceived[start] = count;
      aggregate += count - previous;
      progress.update(aggregate);
    }

    try {
      _checkCancelled(cancel);
      // Probe one byte rather than waiting for an entire segment before the
      // other connections can start. A 200/416 is cancelled before fallback.
      final resolved = await _downloadRange(
        release,
        route,
        group,
        writer,
        0,
        0,
        onProgress: (count) => received(0, count),
      );
      var next = 1;
      Object? failure;
      Future<void> worker() async {
        try {
          while (next < release.asset.size) {
            _checkCancelled(group);
            final start = next;
            final end = (start + _rangeBytes - 1) < release.asset.size
                ? start + _rangeBytes - 1
                : release.asset.size - 1;
            next = end + 1;
            await _downloadRange(
              release,
              route,
              group,
              writer,
              start,
              end,
              initialUrl: resolved,
              onProgress: (count) => received(start, count),
            );
          }
        } catch (error) {
          failure ??= error;
          group.cancel('workerStopped');
        }
      }

      // Await every worker, including any queued disk write, before returning
      // an error or allowing serial fallback to truncate the shared file.
      await Future.wait(List.generate(_rangeWorkers, (_) => worker()));
      if (failure != null) throw failure!;
      _checkCancelled(cancel);
    } finally {
      group.cancel();
    }
  }

  Future<Uri> _downloadRange(
    ForkUpdateRelease release,
    _DownloadRoute route,
    CancelToken group,
    _RangeFileWriter writer,
    int start,
    int end, {
    Uri? initialUrl,
    required void Function(int received) onProgress,
  }) async {
    final attempts = route.isMirror ? 1 : 3;
    for (var attempt = 0; attempt < attempts; attempt++) {
      _checkCancelled(group);
      final requestCancel = CancelToken();
      unawaited(
        group.whenCancel.then((error) => requestCancel.cancel(error.error)),
      );
      ResponseBody? body;
      try {
        final response = await _downloadResponse(
          release,
          route,
          requestCancel,
          range: 'bytes=$start-$end',
          // A retry resolves the official release URL again in case GitHub's
          // short-lived signed URL has expired.
          initialUrl: attempt == 0 ? initialUrl : null,
        );
        body = response.data;
        if (response.statusCode == 200 || response.statusCode == 416) {
          await _discard(body);
          body = null;
          throw const _RangeUnsupported();
        }
        _validateRangeHeaders(response, start, end, release.asset.size);
        var received = 0;
        final expected = end - start + 1;
        final stream = body!;
        body = null; // The await-for owns and cancels its subscription.
        await for (final chunk in stream.stream.timeout(route.chunkTimeout)) {
          _checkCancelled(group);
          if (received + chunk.length > expected) {
            throw const ForkUpdateException(ForkUpdateErrorCode.tooLarge);
          }
          await writer.write(start + received, chunk);
          received += chunk.length;
          onProgress(received);
        }
        _checkCancelled(group);
        if (received != expected) {
          throw const ForkUpdateException(ForkUpdateErrorCode.networkError);
        }
        return response.requestOptions.uri;
      } on _RangeUnsupported {
        rethrow;
      } catch (error) {
        _checkCancelled(group);
        // Dio parses Content-Length before returning a streamed response.
        // Malformed metadata must not be treated as a retryable outage.
        if (error is FormatException ||
            error is DioException && error.error is FormatException) {
          throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
        }
        final classified = _downloadError(error, requestCancel);
        if (classified.code != ForkUpdateErrorCode.networkError ||
            attempt == attempts - 1) {
          throw classified;
        }
      } finally {
        await _discard(body);
        requestCancel.cancel();
      }
    }
    throw const ForkUpdateException(ForkUpdateErrorCode.networkError);
  }

  static void _validateRangeHeaders(
    Response<ResponseBody> response,
    int start,
    int end,
    int total,
  ) {
    String? header(String name) {
      final values = response.headers[name];
      if (values == null) return null;
      if (values.length != 1) {
        throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
      }
      return values.single.trim();
    }

    final range = header('content-range');
    final length = header('content-length');
    final encoding = header('content-encoding');
    if (response.statusCode != 206 ||
        response.data == null ||
        range != 'bytes $start-$end/$total' ||
        (length != null && int.tryParse(length) != end - start + 1) ||
        (encoding != null && encoding.toLowerCase() != 'identity')) {
      throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
    }
  }

  static Future<void> _verifyPartial(
    File file,
    ForkUpdateRelease release,
    CancelToken cancel,
  ) async {
    await _assertFile(file);
    final result = _DigestSink();
    final hasher = sha256.startChunkedConversion(result);
    var count = 0;
    await for (final chunk in file.openRead()) {
      _checkCancelled(cancel);
      count += chunk.length;
      if (count > release.asset.size) {
        throw const ForkUpdateException(ForkUpdateErrorCode.hashMismatch);
      }
      hasher.add(chunk);
    }
    hasher.close();
    _checkCancelled(cancel);
    if (count != release.asset.size ||
        result.digest.toString() != release.asset.sha256) {
      throw const ForkUpdateException(ForkUpdateErrorCode.hashMismatch);
    }
  }

  /// Rechecks the downloaded file just before the OS installer is launched.
  /// This also rejects links or files moved outside this app's updates folder.
  Future<void> verifyAgain(VerifiedForkUpdate update) async {
    _validateRelease(update.release);
    try {
      final updates = await _updatesDirectory();
      final parent = update.file.parent;
      if (!p.equals(p.dirname(parent.path), updates.path) ||
          !RegExp(
            r'^download-[A-Za-z0-9]+$',
          ).hasMatch(p.basename(parent.path)) ||
          p.basename(update.file.path) != update.release.asset.name) {
        throw const ForkUpdateException(ForkUpdateErrorCode.ioError);
      }
      await _assertDirectory(parent);
      await _assertFile(update.file);
      if (await update.file.length() != update.release.asset.size) {
        throw const ForkUpdateException(ForkUpdateErrorCode.hashMismatch);
      }
      final result = _DigestSink();
      final hasher = sha256.startChunkedConversion(result);
      var count = 0;
      await for (final chunk in update.file.openRead()) {
        count += chunk.length;
        if (count > update.release.asset.size || count > maxInstallerBytes) {
          throw const ForkUpdateException(ForkUpdateErrorCode.hashMismatch);
        }
        hasher.add(chunk);
      }
      hasher.close();
      await _assertFile(update.file);
      if (count != update.release.asset.size ||
          result.digest.toString() != update.release.asset.sha256) {
        throw const ForkUpdateException(ForkUpdateErrorCode.hashMismatch);
      }
    } on ForkUpdateException {
      rethrow;
    } catch (_) {
      throw const ForkUpdateException(ForkUpdateErrorCode.ioError);
    }
  }

  Future<Response<ResponseBody>> _get(
    Uri url,
    CancelToken cancel, {
    int byteLimit = maxMetadataBytes,
    String? range,
    _DownloadRoute? route,
  }) => (route?.client ?? _dio)
      .getUri<ResponseBody>(
        url,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (received > byteLimit || total > byteLimit) {
            cancel.cancel('tooLarge');
          }
        },
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          maxRedirects: 0,
          sendTimeout: route?.requestTimeout ?? _requestTimeout,
          receiveTimeout: route?.chunkTimeout ?? _chunkTimeout,
          validateStatus: (_) => true,
          headers: {
            'Accept': url.host == 'api.github.com'
                ? 'application/vnd.github+json'
                : 'application/octet-stream',
            'User-Agent': 'AVA-Fork-Updater',
            'Range': ?range,
            if (range != null || (route?.isMirror ?? false))
              'Accept-Encoding': 'identity',
            if (url.host == 'api.github.com')
              'X-GitHub-Api-Version': '2026-03-10',
          },
        ),
      )
      .timeout(
        route?.requestTimeout ?? _requestTimeout,
        onTimeout: () {
          cancel.cancel('timeout');
          throw const ForkUpdateException(ForkUpdateErrorCode.networkError);
        },
      );

  Future<Response<ResponseBody>> _downloadResponse(
    ForkUpdateRelease release,
    _DownloadRoute route,
    CancelToken cancel, {
    String? range,
    Uri? initialUrl,
  }) async {
    var url = initialUrl ?? route.url;
    if (route.isMirror ? url != route.url : !_allowedRedirect(url, release)) {
      throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
    }
    for (var redirects = 0; redirects <= 5; redirects++) {
      _checkCancelled(cancel);
      final response = await _get(
        url,
        cancel,
        byteLimit: release.asset.size,
        range: range,
        route: route,
      );
      if ((response.statusCode == 200 ||
              range != null &&
                  const [206, 416].contains(response.statusCode)) &&
          response.data != null) {
        return response;
      }
      await _discard(response.data);
      if (![301, 302, 303, 307, 308].contains(response.statusCode)) {
        throw const ForkUpdateException(ForkUpdateErrorCode.networkError);
      }
      // Mirrors may only serve the exact canonical GitHub asset wrapped by
      // their fixed prefix. Never follow a mirror-selected redirect, even back
      // to an official host; fallback starts a fresh trusted source instead.
      if (route.isMirror) {
        throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
      }
      final location = response.headers.value('location');
      if (location == null || redirects == 5) {
        throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
      }
      url = url.resolve(location);
      if (!_allowedRedirect(url, release)) {
        throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
      }
    }
    throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
  }

  static bool _allowedRedirect(Uri uri, ForkUpdateRelease release) {
    if (!_https(uri)) return false;
    if (_sameUri(uri, release.asset.url)) return true;
    // https://docs.github.com/en/actions/reference/runners/larger-runners
    // GitHub documents these exact release/runner download hosts. Never allow
    // an arbitrary *.githubusercontent.com host or another GitHub repository.
    return const {
      'release-assets.githubusercontent.com',
      'objects.githubusercontent.com',
      'objects-origin.githubusercontent.com',
      'github-releases.githubusercontent.com',
    }.contains(uri.host);
  }

  static bool _https(Uri uri) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      uri.fragment.isEmpty;

  static bool _sameUri(Uri? actual, Uri expected) =>
      actual != null &&
      _https(actual) &&
      actual.host == expected.host &&
      actual.query.isEmpty &&
      actual.pathSegments.length == expected.pathSegments.length &&
      List.generate(
        expected.pathSegments.length,
        (index) => actual.pathSegments[index] == expected.pathSegments[index],
      ).every((equal) => equal);

  static Uri _releasePage(String tag) => Uri(
    scheme: 'https',
    host: 'github.com',
    pathSegments: ['gooesman', 'AnotherVaporAuth', 'releases', 'tag', tag],
  );

  static Uri _assetUrl(String tag, String name) => Uri(
    scheme: 'https',
    host: 'github.com',
    pathSegments: [
      'gooesman',
      'AnotherVaporAuth',
      'releases',
      'download',
      tag,
      name,
    ],
  );

  static Set<String> _assetNames(ForkUpdateTarget target, String tag) =>
      switch (target) {
        ForkUpdateTarget.windowsX64 => {
          'AVA-pc-$tag-windows-x64-setup.exe',
          'AVA-$tag-windows-x64-setup.exe',
        },
        ForkUpdateTarget.androidArm64 => {'AVA-Fork-$tag-android-arm64.apk'},
      };

  static void _validateRelease(ForkUpdateRelease release) {
    final match = release.tag.length <= 64
        ? _releaseTag.firstMatch(release.tag)
        : null;
    if (match == null ||
        '${match[1]}.${match[2]}.${match[3]}' != release.version ||
        int.tryParse(match[4]!) != release.buildNumber ||
        release.buildNumber > _maxBuild ||
        !_sameUri(release.releaseUrl, _releasePage(release.tag)) ||
        !_assetNames(
          release.target,
          release.tag,
        ).contains(release.asset.name) ||
        !_sameUri(
          release.asset.url,
          _assetUrl(release.tag, release.asset.name),
        ) ||
        release.asset.size <= 0) {
      throw const ForkUpdateException(ForkUpdateErrorCode.invalidMetadata);
    }
    if (release.asset.size > maxInstallerBytes) {
      throw const ForkUpdateException(ForkUpdateErrorCode.tooLarge);
    }
    if (release.asset.sha256 == null ||
        !_hash.hasMatch(release.asset.sha256!)) {
      throw const ForkUpdateException(ForkUpdateErrorCode.unverifiable);
    }
  }

  Future<Directory> _updatesDirectory() async {
    final temp = await _temporaryDirectory();
    final root = Directory(await temp.resolveSymbolicLinks());
    final updates = Directory(p.join(root.path, 'updates'));
    final type = await FileSystemEntity.type(updates.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) await updates.create();
    await _assertDirectory(updates);
    return updates;
  }

  static Future<void> _assertDirectory(Directory directory) async {
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        !p.equals(
          await directory.resolveSymbolicLinks(),
          directory.absolute.path,
        )) {
      throw const ForkUpdateException(ForkUpdateErrorCode.ioError);
    }
  }

  static Future<void> _assertFile(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        !p.equals(await file.resolveSymbolicLinks(), file.absolute.path)) {
      throw const ForkUpdateException(ForkUpdateErrorCode.ioError);
    }
  }

  static void _checkCancelled(CancelToken cancel) {
    if (cancel.isCancelled) {
      throw ForkUpdateException(_cancelCode(cancel));
    }
  }

  static ForkUpdateException _downloadError(Object error, CancelToken cancel) {
    if (error is ForkUpdateException) return error;
    if (cancel.isCancelled) {
      return ForkUpdateException(_cancelCode(cancel));
    }
    return ForkUpdateException(
      error is FileSystemException
          ? ForkUpdateErrorCode.ioError
          : ForkUpdateErrorCode.networkError,
    );
  }

  static ForkUpdateErrorCode _cancelCode(CancelToken cancel) =>
      switch (cancel.cancelError?.error) {
        'timeout' => ForkUpdateErrorCode.networkError,
        'tooLarge' => ForkUpdateErrorCode.tooLarge,
        _ => ForkUpdateErrorCode.cancelled,
      };

  static Future<void> _discard(ResponseBody? body) async {
    await body?.stream.listen((_) {}).cancel();
  }

  static Future<void> _removePartial(File partial, Directory owner) async {
    try {
      await _assertDirectory(owner);
      // Only the exact file created by this call is removed. Never recursively
      // delete a directory that may have acquired unrelated files or links.
      if (p.equals(p.dirname(partial.path), owner.path)) {
        final type = await FileSystemEntity.type(
          partial.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.file) await partial.delete();
      }
      await owner.delete(); // Succeeds only when still empty.
    } catch (_) {
      // A failed cleanup must not hide cancellation or hash validation errors.
    }
  }
}

class _DownloadRoute {
  const _DownloadRoute(this.source, this.client, this.url);

  final ForkUpdateDownloadSource source;
  final Dio client;
  final Uri url;

  bool get isMirror => source != ForkUpdateDownloadSource.github;
  Duration get requestTimeout => isMirror
      ? ForkUpdateService._mirrorRequestTimeout
      : ForkUpdateService._requestTimeout;
  Duration get chunkTimeout => isMirror
      ? ForkUpdateService._mirrorChunkTimeout
      : ForkUpdateService._chunkTimeout;
}

class _DigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest value) => digest = value;

  @override
  void close() {}
}

class _RangeUnsupported implements Exception {
  const _RangeUnsupported();
}

/// At most one queued chunk per worker; RAF seeks/writes cannot overlap.
class _RangeFileWriter {
  _RangeFileWriter(this.output, this.cancel);

  final RandomAccessFile output;
  final CancelToken cancel;
  Future<void> _tail = Future<void>.value();

  Future<void> write(int offset, List<int> bytes) {
    final next = _tail.then((_) async {
      ForkUpdateService._checkCancelled(cancel);
      await output.setPosition(offset);
      await output.writeFrom(bytes);
    });
    _tail = next.catchError((_) {});
    return next;
  }
}

/// Per-range high water marks feed this monotonic UI value. Retried bytes and
/// serial fallback never add to progress twice. 100% starts hash verification;
/// only download() returning VerifiedForkUpdate authorizes the next UI step.
class _DownloadProgress {
  _DownloadProgress(this.total, this.callback);

  final int total;
  final void Function(int received, int total)? callback;
  int _shown = 0;

  void start() => callback?.call(0, total);

  void update(int value) {
    if (value <= _shown || value >= total) return;
    _shown = value;
    callback?.call(value, total);
  }

  void transferred() => callback?.call(total, total);
}
