import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ava/src/core/fork_update.dart';
import 'package:ava/src/services/fork_update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _tag = 'v1.5.2+100042';
const _windowsName = 'AVA-pc-$_tag-windows-x64-setup.exe';
const _androidName = 'AVA-Fork-$_tag-android-arm64.apk';
final _bytes = utf8.encode('a fake installer; never execute this file');
final _digest = sha256.convert(_bytes).toString();

Uri _url(String name, {String tag = _tag}) => Uri(
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

Map<String, dynamic> _asset(String name, {String tag = _tag}) => {
  'name': name,
  'state': 'uploaded',
  'size': _bytes.length,
  'digest': 'sha256:$_digest',
  'browser_download_url': _url(name, tag: tag).toString(),
};

Map<String, dynamic> _metadata({String tag = _tag}) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': false,
  'body': 'Local fork release notes.',
  'html_url': 'https://github.com/gooesman/AnotherVaporAuth/releases/tag/$tag',
  'assets': [
    _asset('AVA-pc-$tag-windows-x64-setup.exe', tag: tag),
    _asset('AVA-Fork-$tag-android-arm64.apk', tag: tag),
  ],
};

ResponseBody _json(Object data, {int status = 200}) =>
    ResponseBody.fromString(jsonEncode(data), status);

ResponseBody _binary([List<int>? bytes]) =>
    ResponseBody.fromBytes(bytes ?? _bytes, 200);

Dio _dio(FutureOr<ResponseBody> Function(RequestOptions) handler) =>
    Dio()..httpClientAdapter = _Adapter(handler);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final FutureOr<ResponseBody> Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

Matcher _error(ForkUpdateErrorCode code) =>
    isA<ForkUpdateException>().having((error) => error.code, 'code', code);

Future<void> _directoryLink(Link link, Directory target) async {
  if (!Platform.isWindows) {
    await link.create(target.path);
    return;
  }
  // Windows symlinks require Developer Mode/admin rights; directory junctions
  // exercise the same resolved-path guard without changing machine settings.
  final result = await Process.run(
    'powershell.exe',
    [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      'New-Item -ItemType Junction -Path \$env:AVA_TEST_LINK '
          '-Target \$env:AVA_TEST_TARGET -ErrorAction Stop | Out-Null',
    ],
    environment: {'AVA_TEST_LINK': link.path, 'AVA_TEST_TARGET': target.path},
  );
  expect(result.exitCode, 0, reason: '${result.stderr}');
}

Future<ForkUpdateCheck> _check(
  ForkUpdateService service, {
  ForkUpdateTarget target = ForkUpdateTarget.windowsX64,
  String version = '1.5.1',
  String build = '100001',
}) =>
    service.check(target: target, currentVersion: version, currentBuild: build);

void main() {
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ava-update-test-');
  });
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  ForkUpdateService service(
    FutureOr<ResponseBody> Function(RequestOptions) answer,
  ) => ForkUpdateService(
    dio: _dio(answer),
    temporaryDirectory: () async => temp,
  );

  test(
    'checks only public fork endpoint and selects exact platform asset',
    () async {
      final requests = <RequestOptions>[];
      final sut = service((request) {
        requests.add(request);
        return _json(_metadata());
      });
      for (final target in ForkUpdateTarget.values) {
        final result = await _check(sut, target: target);
        expect(result.status, ForkUpdateCheckStatus.available);
        expect(result.release!.version, '1.5.2');
        expect(result.release!.buildNumber, 100042);
        expect(result.release!.tag, _tag);
        expect(result.release!.notes, 'Local fork release notes.');
        expect(result.release!.asset.sha256, _digest);
        expect(
          result.release!.asset.name,
          target == ForkUpdateTarget.windowsX64 ? _windowsName : _androidName,
        );
      }
      expect(requests, hasLength(2));
      for (final request in requests) {
        expect(request.uri.toString(), kForkLatestReleaseApi);
        expect(request.followRedirects, isFalse);
        expect(
          request.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains(anyOf('authorization', 'cookie'))),
        );
      }
      expect(await temp.list().toList(), isEmpty);
    },
  );

  test(
    'no release, offline and malformed metadata are distinct from latest',
    () async {
      final cases = <ResponseBody, ForkUpdateCheckStatus>{
        _json({}, status: 404): ForkUpdateCheckStatus.noRelease,
        _json({}, status: 403): ForkUpdateCheckStatus.networkError,
        _json({}, status: 502): ForkUpdateCheckStatus.networkError,
        _json({}, status: 302): ForkUpdateCheckStatus.networkError,
        ResponseBody.fromString('<html>portal</html>', 200):
            ForkUpdateCheckStatus.invalidMetadata,
      };
      for (final entry in cases.entries) {
        expect((await _check(service((_) => entry.key))).status, entry.value);
      }
      expect(
        (await _check(
          service((_) => throw const SocketException('offline')),
        )).status,
        ForkUpdateCheckStatus.networkError,
      );
    },
  );

  test(
    'version comparison includes same-version build and rejects build downgrade',
    () async {
      final sut = service((_) => _json(_metadata()));
      expect(
        (await _check(sut, version: '1.5.2', build: '100041')).status,
        ForkUpdateCheckStatus.available,
      );
      expect(
        (await _check(sut, version: '1.5.2', build: '100042')).status,
        ForkUpdateCheckStatus.upToDate,
      );
      expect(
        (await _check(sut, version: '1.5.2-fork', build: '100043')).status,
        ForkUpdateCheckStatus.upToDate,
      );
      expect(
        (await _check(sut, version: '1.10.0', build: '100043')).status,
        ForkUpdateCheckStatus.upToDate,
      );
      expect(
        (await _check(sut, version: '1.4.0', build: '100043')).status,
        ForkUpdateCheckStatus.invalidMetadata,
      );
      for (final version in ['1.5', 'unknown', '01.5.1', '1.5.1+100001']) {
        expect(
          (await _check(sut, version: version)).status,
          ForkUpdateCheckStatus.invalidMetadata,
        );
      }
    },
  );

  test('strict stable tags and matching metadata are required', () async {
    for (final tag in [
      'v1.5.2',
      'v1.5.2+0',
      'v1.5.2+2100000001',
      'v1.5.2-beta+100042',
      'v1.05.2+100042',
      'v1.5.2+100042/evil',
    ]) {
      expect(
        (await _check(service((_) => _json(_metadata(tag: tag))))).status,
        ForkUpdateCheckStatus.invalidMetadata,
        reason: tag,
      );
    }
    for (final field in ['draft', 'prerelease']) {
      final data = _metadata()..[field] = true;
      expect(
        (await _check(service((_) => _json(data)))).status,
        ForkUpdateCheckStatus.invalidMetadata,
      );
    }
    final wrongRepo = _metadata()
      ..['html_url'] =
          'https://github.com/freefrank/AnotherVaporAuth/releases/tag/$_tag';
    expect(
      (await _check(service((_) => _json(wrongRepo)))).status,
      ForkUpdateCheckStatus.invalidMetadata,
    );
  });

  test(
    'missing asset, duplicate assets and missing digest fail closed',
    () async {
      final missing = _metadata()..['assets'] = [_asset(_androidName)];
      expect(
        (await _check(service((_) => _json(missing)))).status,
        ForkUpdateCheckStatus.noCompatibleAsset,
      );
      final duplicate = _metadata()
        ..['assets'] = [_asset(_windowsName), _asset(_windowsName)];
      expect(
        (await _check(service((_) => _json(duplicate)))).status,
        ForkUpdateCheckStatus.invalidMetadata,
      );
      for (final digest in [null, '', 'md5:abcd', 'sha256:abcd']) {
        final data = _metadata();
        (data['assets'] as List)[0]['digest'] = digest;
        final sut = service((_) => _json(data));
        final result = await _check(sut);
        expect(result.status, ForkUpdateCheckStatus.unverifiable);
        expect(result.release, isNotNull);
        await expectLater(
          sut.download(result.release!),
          throwsA(_error(ForkUpdateErrorCode.unverifiable)),
        );
      }
    },
  );

  test(
    'legacy Windows filename only accepted from the same exact fork',
    () async {
      final name = 'AVA-$_tag-windows-x64-setup.exe';
      final asset = _asset(name);
      final data = _metadata()..['assets'] = [asset];
      expect(
        (await _check(service((_) => _json(data)))).status,
        ForkUpdateCheckStatus.available,
      );
      for (final url in [
        _url(name).toString().replaceFirst('gooesman', 'freefrank'),
        _url(name).toString().replaceFirst('https:', 'http:'),
        '${_url(name)}?download=1',
        'https://github.com.evil.invalid/gooesman/AnotherVaporAuth/$name',
        'https://user@github.com/gooesman/AnotherVaporAuth/releases/download/$_tag/$name',
      ]) {
        asset['browser_download_url'] = url;
        expect(
          (await _check(service((_) => _json(data)))).status,
          ForkUpdateCheckStatus.invalidMetadata,
          reason: url,
        );
      }
    },
  );

  test(
    'invalid and oversized metadata or asset declarations are rejected',
    () async {
      for (final size in [
        0,
        -1,
        '40',
        ForkUpdateService.maxInstallerBytes + 1,
      ]) {
        final data = _metadata();
        (data['assets'] as List)[0]['size'] = size;
        expect(
          (await _check(service((_) => _json(data)))).status,
          ForkUpdateCheckStatus.invalidMetadata,
        );
      }
      final data = _metadata()
        ..['body'] = 'x' * (ForkUpdateService.maxMetadataBytes + 1);
      expect(
        (await _check(service((_) => _json(data)))).status,
        ForkUpdateCheckStatus.invalidMetadata,
      );
    },
  );

  test(
    'allowed GitHub redirects stream bytes, report progress and reverify',
    () async {
      final requests = <Uri>[];
      final progress = <int>[];
      final sut = service((request) {
        requests.add(request.uri);
        if (request.uri.host == 'api.github.com') return _json(_metadata());
        if (request.uri.host == 'github.com') {
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': [
                'https://release-assets.githubusercontent.com/signed/asset?sig=test',
              ],
            },
          );
        }
        return ResponseBody(
          Stream.fromIterable([
            Uint8List.fromList(_bytes.sublist(0, 10)),
            Uint8List.fromList(_bytes.sublist(10)),
          ]),
          200,
          headers: {
            'content-length': ['${_bytes.length}'],
          },
        );
      });
      final release = (await _check(sut)).release!;
      final artifact = await sut.download(
        release,
        onProgress: (received, total) {
          progress.add(received);
          expect(total, _bytes.length);
        },
      );
      expect(await artifact.file.readAsBytes(), _bytes);
      expect(p.basename(artifact.file.path), _windowsName);
      expect(p.basename(artifact.file.parent.parent.path), 'updates');
      expect(progress, [0, 10, _bytes.length]);
      expect(requests.map((uri) => uri.host), [
        'api.github.com',
        'github.com',
        'release-assets.githubusercontent.com',
      ]);
      await sut.verifyAgain(artifact);
      await artifact.file.writeAsBytes(List.filled(_bytes.length, 1));
      await expectLater(
        sut.verifyAgain(artifact),
        throwsA(_error(ForkUpdateErrorCode.hashMismatch)),
      );
    },
  );

  test('unknown or insecure redirects are never requested', () async {
    for (final location in [
      'https://example.com/installer.exe',
      'http://release-assets.githubusercontent.com/file',
      'https://release-assets.githubusercontent.com.evil.invalid/file',
      'https://user:pass@release-assets.githubusercontent.com/file',
      'https://release-assets.githubusercontent.com:444/file',
      'https://github.com/freefrank/AnotherVaporAuth/releases/download/$_tag/$_windowsName',
    ]) {
      var downloadRequests = 0;
      final sut = service((request) {
        if (request.uri.host == 'api.github.com') return _json(_metadata());
        downloadRequests++;
        return ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': [location],
          },
        );
      });
      final release = (await _check(sut)).release!;
      await expectLater(
        sut.download(release),
        throwsA(_error(ForkUpdateErrorCode.invalidMetadata)),
      );
      expect(downloadRequests, 1);
      expect(
        await Directory(p.join(temp.path, 'updates')).list().toList(),
        isEmpty,
      );
    }
  });

  test(
    'hash mismatch, truncation and oversized payload remove only owned partial',
    () async {
      for (final bytes in [
        List<int>.filled(_bytes.length, 1),
        _bytes.sublist(1),
        [..._bytes, 0],
      ]) {
        final sut = service(
          (request) => request.uri.host == 'api.github.com'
              ? _json(_metadata())
              : _binary(bytes),
        );
        final release = (await _check(sut)).release!;
        final other = File(p.join(temp.path, 'keep.txt'))
          ..writeAsStringSync('keep');
        await expectLater(
          sut.download(release),
          throwsA(
            _error(
              bytes.length > _bytes.length
                  ? ForkUpdateErrorCode.tooLarge
                  : ForkUpdateErrorCode.hashMismatch,
            ),
          ),
        );
        expect(await other.readAsString(), 'keep');
        expect(
          await Directory(p.join(temp.path, 'updates')).list().toList(),
          isEmpty,
        );
      }
    },
  );

  test(
    'user cancellation interrupts a stalled stream and clears partial',
    () async {
      final stream = StreamController<Uint8List>();
      final started = Completer<void>();
      final token = CancelToken();
      final sut = service((request) {
        if (request.uri.host == 'api.github.com') return _json(_metadata());
        started.complete();
        return ResponseBody(stream.stream, 200);
      });
      final release = (await _check(sut)).release!;
      final result = sut.download(release, cancelToken: token);
      final expectation = expectLater(
        result,
        throwsA(_error(ForkUpdateErrorCode.cancelled)),
      );
      await started.future;
      token.cancel();
      await expectation.timeout(const Duration(seconds: 2));
      await stream.close();
      expect(
        await Directory(p.join(temp.path, 'updates')).list().toList(),
        isEmpty,
      );
    },
  );

  test(
    'already cancelled download makes no request or temporary file',
    () async {
      var requests = 0;
      final sut = service((_) {
        requests++;
        return _json(_metadata());
      });
      final release = (await _check(sut)).release!;
      final token = CancelToken()..cancel();
      await expectLater(
        sut.download(release, cancelToken: token),
        throwsA(_error(ForkUpdateErrorCode.cancelled)),
      );
      expect(requests, 1);
      expect(await temp.list().toList(), isEmpty);
    },
  );

  test(
    'simultaneous downloads use separate directories and preserve each file',
    () async {
      final sut = service(
        (request) => request.uri.host == 'api.github.com'
            ? _json(_metadata())
            : _binary(),
      );
      final release = (await _check(sut)).release!;
      final artifacts = await Future.wait([
        sut.download(release),
        sut.download(release),
      ]);
      expect(artifacts[0].file.path, isNot(artifacts[1].file.path));
      for (final artifact in artifacts) {
        await sut.verifyAgain(artifact);
      }
    },
  );

  test(
    'installer verification rejects arbitrary paths despite correct hash',
    () async {
      final sut = service((_) => _json(_metadata()));
      final release = (await _check(sut)).release!;
      final outside = File(p.join(temp.path, _windowsName));
      await outside.writeAsBytes(_bytes);
      await expectLater(
        sut.verifyAgain(VerifiedForkUpdate(file: outside, release: release)),
        throwsA(_error(ForkUpdateErrorCode.ioError)),
      );
      expect(await outside.readAsBytes(), _bytes);
    },
  );

  test(
    'download rejects a linked updates directory without touching its target',
    () async {
      final external = Directory(p.join(temp.path, 'unrelated'));
      await external.create();
      final sentinel = File(p.join(external.path, 'keep.txt'));
      await sentinel.writeAsString('keep');
      final link = Link(p.join(temp.path, 'updates'));
      await _directoryLink(link, external);
      var binaryRequests = 0;
      final sut = service((request) {
        if (request.uri.host == 'api.github.com') return _json(_metadata());
        binaryRequests++;
        return _binary();
      });
      final release = (await _check(sut)).release!;
      await expectLater(
        sut.download(release),
        throwsA(_error(ForkUpdateErrorCode.ioError)),
      );
      expect(binaryRequests, 0);
      expect(
        await external.list().map((entry) => p.basename(entry.path)).toList(),
        ['keep.txt'],
      );
      expect(await sentinel.readAsString(), 'keep');
      await link.delete();
    },
  );

  test(
    'verifyAgain rejects a linked download parent even with a correct file',
    () async {
      final sut = service(
        (request) => request.uri.host == 'api.github.com'
            ? _json(_metadata())
            : _binary(),
      );
      final release = (await _check(sut)).release!;
      final artifact = await sut.download(release);
      final parentPath = artifact.file.parent.path;
      final displaced = await artifact.file.parent.rename(
        p.join(temp.path, 'displaced'),
      );
      final link = Link(parentPath);
      await _directoryLink(link, displaced);
      await expectLater(
        sut.verifyAgain(artifact),
        throwsA(_error(ForkUpdateErrorCode.ioError)),
      );
      expect(
        await File(p.join(displaced.path, _windowsName)).readAsBytes(),
        _bytes,
      );
      await link.delete();
    },
  );

  test('too many redirects fail without leaving partial files', () async {
    var requests = 0;
    final sut = service((request) {
      if (request.uri.host == 'api.github.com') return _json(_metadata());
      requests++;
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['https://release-assets.githubusercontent.com/loop'],
        },
      );
    });
    final release = (await _check(sut)).release!;
    await expectLater(
      sut.download(release),
      throwsA(_error(ForkUpdateErrorCode.invalidMetadata)),
    );
    expect(requests, 6);
    expect(
      await Directory(p.join(temp.path, 'updates')).list().toList(),
      isEmpty,
    );
  });
}
