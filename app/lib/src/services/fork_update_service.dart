import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/fork_update.dart';

const kForkReleasesUrl =
    'https://github.com/gooesman/AnotherVaporAuth/releases';
const kForkLatestReleaseApi =
    'https://api.github.com/repos/gooesman/AnotherVaporAuth/releases/latest';

/// Only this fork's public, stable GitHub releases are accepted. This service
/// never installs anything and never shares Steam authentication headers.
///
/// Release metadata (including asset.digest):
/// https://docs.github.com/en/rest/releases/releases#get-the-latest-release
/// Injected Dio instances must be dedicated to this service, not a signed-in
/// Steam session. Production always creates its own unauthenticated client.
class ForkUpdateService {
  ForkUpdateService({
    Dio? dio,
    Future<Directory> Function()? temporaryDirectory,
  }) : _dio = dio ?? Dio(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectory;

  static const maxInstallerBytes = 512 * 1024 * 1024;
  static const maxMetadataBytes = 1024 * 1024;
  static const _requestTimeout = Duration(seconds: 20);
  static const _chunkTimeout = Duration(seconds: 30);
  static const _downloadTimeout = Duration(minutes: 30);
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
  }) async {
    _validateRelease(release);
    final cancel = CancelToken();
    if (cancelToken?.isCancelled ?? false) cancel.cancel();
    unawaited(cancelToken?.whenCancel.then((_) => cancel.cancel()));
    final deadline = Timer(_downloadTimeout, () => cancel.cancel('timeout'));
    Directory? ownedDirectory;
    File? partial;
    RandomAccessFile? output;
    try {
      _checkCancelled(cancel);
      final updates = await _updatesDirectory();
      _checkCancelled(cancel);
      ownedDirectory = await updates.createTemp('download-');
      await _assertDirectory(ownedDirectory);
      partial = File(p.join(ownedDirectory.path, '${release.asset.name}.part'));
      await partial.create(exclusive: true);
      await _assertFile(partial);
      output = await partial.open(mode: FileMode.writeOnly);
      final response = await _downloadResponse(release, cancel);
      final body = response.data!;
      final length = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      if (length != null && length != release.asset.size) {
        await _discard(body);
        throw ForkUpdateException(
          length > maxInstallerBytes
              ? ForkUpdateErrorCode.tooLarge
              : ForkUpdateErrorCode.invalidMetadata,
        );
      }
      var received = 0;
      final result = _DigestSink();
      final hasher = sha256.startChunkedConversion(result);
      onProgress?.call(0, release.asset.size);
      await for (final chunk in body.stream.timeout(_chunkTimeout)) {
        _checkCancelled(cancel);
        received += chunk.length;
        if (received > maxInstallerBytes || received > release.asset.size) {
          throw const ForkUpdateException(ForkUpdateErrorCode.tooLarge);
        }
        hasher.add(chunk);
        await output.writeFrom(chunk);
        onProgress?.call(received, release.asset.size);
      }
      _checkCancelled(cancel);
      hasher.close();
      if (received != release.asset.size ||
          result.digest.toString() != release.asset.sha256) {
        throw const ForkUpdateException(ForkUpdateErrorCode.hashMismatch);
      }
      await output.flush();
      await output.close();
      output = null;
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
      try {
        await output?.close();
      } catch (_) {
        // Preserve the original failure while still trying to remove partials.
      }
      if (partial != null && ownedDirectory != null) {
        await _removePartial(partial, ownedDirectory);
      }
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
  }) => _dio
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
          sendTimeout: _requestTimeout,
          receiveTimeout: _chunkTimeout,
          validateStatus: (_) => true,
          headers: {
            'Accept': url.host == 'api.github.com'
                ? 'application/vnd.github+json'
                : 'application/octet-stream',
            'User-Agent': 'AVA-Fork-Updater',
            if (url.host == 'api.github.com')
              'X-GitHub-Api-Version': '2026-03-10',
          },
        ),
      )
      .timeout(
        _requestTimeout,
        onTimeout: () {
          cancel.cancel('timeout');
          throw const ForkUpdateException(ForkUpdateErrorCode.networkError);
        },
      );

  Future<Response<ResponseBody>> _downloadResponse(
    ForkUpdateRelease release,
    CancelToken cancel,
  ) async {
    var url = release.asset.url;
    for (var redirects = 0; redirects <= 5; redirects++) {
      _checkCancelled(cancel);
      final response = await _get(url, cancel, byteLimit: release.asset.size);
      if (response.statusCode == 200 && response.data != null) return response;
      await _discard(response.data);
      if (![301, 302, 303, 307, 308].contains(response.statusCode)) {
        throw const ForkUpdateException(ForkUpdateErrorCode.networkError);
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

class _DigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest value) => digest = value;

  @override
  void close() {}
}
