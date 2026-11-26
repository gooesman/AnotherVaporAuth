import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ava/src/core/fork_update.dart';
import 'package:ava/src/services/fork_update_network.dart';
import 'package:ava/src/services/fork_update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _tag = 'v1.5.2+100015';
const _name = 'AVA-Fork-$_tag-android-arm64.apk';
final _official = Uri.parse(
  'https://github.com/gooesman/AnotherVaporAuth/releases/download/$_tag/$_name',
);
final _small = Uint8List.fromList(
  utf8.encode('synthetic installer, never run'),
);

ForkUpdateRelease _release(
  Uint8List bytes, {
  ForkUpdateTarget target = ForkUpdateTarget.androidArm64,
}) => ForkUpdateRelease(
  target: target,
  tag: _tag,
  version: '1.5.2',
  buildNumber: 100015,
  notes: '',
  releaseUrl: Uri.parse(
    'https://github.com/gooesman/AnotherVaporAuth/releases/tag/$_tag',
  ),
  asset: ForkUpdateAsset(
    name: target == ForkUpdateTarget.windowsX64
        ? 'AVA-pc-$_tag-windows-x64-setup.exe'
        : _name,
    url: target == ForkUpdateTarget.windowsX64
        ? _official.replace(
            pathSegments: [
              ..._official.pathSegments.take(5),
              'AVA-pc-$_tag-windows-x64-setup.exe',
            ],
          )
        : _official,
    size: bytes.length,
    sha256: sha256.convert(bytes).toString(),
  ),
);

typedef _Handler = FutureOr<ResponseBody> Function(RequestOptions);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final _Handler handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

Dio _client(_Handler handler) => Dio()..httpClientAdapter = _Adapter(handler);

Matcher _error(ForkUpdateErrorCode code) =>
    isA<ForkUpdateException>().having((error) => error.code, 'code', code);

({int start, int end}) _range(RequestOptions request) {
  final match = RegExp(
    r'^bytes=(\d+)-(\d+)$',
  ).firstMatch(request.headers['Range'] as String)!;
  return (start: int.parse(match[1]!), end: int.parse(match[2]!));
}

ResponseBody _rangeResponse(
  RequestOptions request,
  Uint8List bytes, {
  Stream<Uint8List>? stream,
}) {
  final range = _range(request);
  return ResponseBody(
    stream ??
        Stream.value(Uint8List.sublistView(bytes, range.start, range.end + 1)),
    206,
    headers: {
      'content-range': ['bytes ${range.start}-${range.end}/${bytes.length}'],
      'content-length': ['${range.end - range.start + 1}'],
      'content-encoding': ['identity'],
    },
  );
}

void main() {
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ava-mirror-test-');
  });
  tearDown(() async => temp.delete(recursive: true));

  ForkUpdateService service({required _Handler mirror, _Handler? official}) =>
      ForkUpdateService(
        dio: _client(
          official ?? (_) => throw StateError('Unexpected official request'),
        ),
        mirrorDio: _client(mirror),
        temporaryDirectory: () async => temp,
      );

  Future<void> emptyUpdates() async => expect(
    await Directory(p.join(temp.path, 'updates')).list().toList(),
    isEmpty,
  );

  for (final target in ForkUpdateTarget.values) {
    test(
      '$target metadata stays official and automatic transport uses exact encoded mirror URL',
      () async {
        final release = _release(_small, target: target);
        final events = <String>[];
        final officialRequests = <Uri>[];
        final sut = service(
          official: (request) {
            officialRequests.add(request.uri);
            expect(request.uri.toString(), kForkLatestReleaseApi);
            return ResponseBody.fromString(
              jsonEncode({
                'tag_name': release.tag,
                'draft': false,
                'prerelease': false,
                'html_url': release.releaseUrl.toString(),
                'assets': [
                  {
                    'name': release.asset.name,
                    'state': 'uploaded',
                    'size': release.asset.size,
                    'digest': 'sha256:${release.asset.sha256}',
                    'browser_download_url': release.asset.url.toString(),
                  },
                ],
              }),
              200,
            );
          },
          mirror: (request) {
            expect(
              request.uri.toString(),
              'https://axisnow.gh-proxy.org/https://github.com/gooesman/AnotherVaporAuth/releases/download/v1.5.2%2B100015/${Uri.encodeComponent(release.asset.name)}',
            );
            expect(request.followRedirects, isFalse);
            expect(request.maxRedirects, 0);
            expect(request.headers['Accept-Encoding'], 'identity');
            expect(
              request.headers.keys.map((key) => key.toLowerCase()),
              isNot(
                contains(
                  anyOf(
                    'authorization',
                    'cookie',
                    'proxy-authorization',
                    'x-github-api-version',
                  ),
                ),
              ),
            );
            expect(request.sendTimeout, const Duration(seconds: 8));
            expect(request.receiveTimeout, const Duration(seconds: 12));
            return ResponseBody.fromBytes(_small, 200);
          },
        );
        final checked = await sut.check(
          target: target,
          currentVersion: '1.5.1-fork',
          currentBuild: '100014',
        );
        expect(checked.status, ForkUpdateCheckStatus.available);
        expect(checked.release!.asset.url, release.asset.url);
        final verified = await sut.download(
          checked.release!,
          onSourceChanged: (source) => events.add(source.name),
          onProgress: (received, _) => events.add('$received'),
        );
        expect(events.take(2), ['axisNow', '0']);
        expect(events.last, '${_small.length}');
        expect(officialRequests, hasLength(1));
        expect(await verified.file.readAsBytes(), _small);
        await sut.verifyAgain(verified);
      },
    );
  }

  test(
    'failed mirrors use ordered fresh sources before the official asset',
    () async {
      final events = <String>[];
      final hosts = <String>[];
      final sut = service(
        mirror: (request) {
          hosts.add(request.uri.host);
          return ResponseBody.fromString('temporary outage', 503);
        },
        official: (request) {
          hosts.add(request.uri.host);
          expect(request.uri, _official);
          return ResponseBody.fromBytes(_small, 200);
        },
      );
      await sut.download(
        _release(_small),
        onSourceChanged: (source) => events.add(source.name),
        onProgress: (received, _) => events.add('$received'),
      );
      expect(hosts, ['axisnow.gh-proxy.org', 'v4.gh-proxy.org', 'github.com']);
      expect(events.take(6), ['axisNow', '0', 'v4', '0', 'github', '0']);
    },
  );

  test(
    'corrupt mirror bytes are discarded and backup is independently verified',
    () async {
      final sources = <ForkUpdateDownloadSource>[];
      final progress = <int>[];
      final sut = service(
        mirror: (request) {
          final bytes = request.uri.host.startsWith('axisnow')
              ? Uint8List(_small.length)
              : _small;
          return ResponseBody.fromBytes(bytes, 200);
        },
      );
      final verified = await sut.download(
        _release(_small),
        onSourceChanged: sources.add,
        onProgress: (received, _) => progress.add(received),
      );
      expect(sources, [
        ForkUpdateDownloadSource.axisNow,
        ForkUpdateDownloadSource.v4,
      ]);
      expect(progress.where((value) => value == 0), hasLength(2));
      expect(progress.where((value) => value == _small.length), hasLength(2));
      expect(await verified.file.readAsBytes(), _small);
      await sut.verifyAgain(verified);
    },
  );

  test(
    'all mirror redirects are refused without following a supplied URL',
    () async {
      for (final location in [
        'https://unknown.invalid/package.apk',
        _official.toString(),
        'https://release-assets.githubusercontent.com/unrelated',
        ForkUpdateNetwork.mirrorAssetUrl(
          ForkUpdateDownloadSource.v4,
          _official,
        ).toString(),
        '/https://github.com/another/repository/releases/download/v1/file.apk',
        'http://axisnow.gh-proxy.org/unsafe',
      ]) {
        final requested = <Uri>[];
        final sut = service(
          mirror: (request) {
            requested.add(request.uri);
            if (request.uri.host == 'v4.gh-proxy.org') {
              return ResponseBody.fromBytes(_small, 200);
            }
            return ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': [location],
              },
            );
          },
        );
        await sut.download(_release(_small));
        expect(requested, [
          ForkUpdateNetwork.mirrorAssetUrl(
            ForkUpdateDownloadSource.axisNow,
            _official,
          ),
          ForkUpdateNetwork.mirrorAssetUrl(
            ForkUpdateDownloadSource.v4,
            _official,
          ),
        ]);
      }
    },
  );

  test('official-only preference never contacts a mirror', () async {
    final sources = <ForkUpdateDownloadSource>[];
    final sut = service(
      mirror: (_) => throw StateError('Must not contact a mirror'),
      official: (_) => ResponseBody.fromBytes(_small, 200),
    );
    await sut.download(
      _release(_small),
      mode: ForkUpdateDownloadMode.github,
      onSourceChanged: sources.add,
    );
    expect(sources, [ForkUpdateDownloadSource.github]);
  });

  test(
    'injected official client alone never falls through to a real mirror',
    () async {
      final sources = <ForkUpdateDownloadSource>[];
      final sut = ForkUpdateService(
        dio: _client((_) => ResponseBody.fromBytes(_small, 200)),
        temporaryDirectory: () async => temp,
      );
      await sut.download(_release(_small), onSourceChanged: sources.add);
      expect(sources, [ForkUpdateDownloadSource.github]);
    },
  );

  test(
    'wrong length or encoded mirror response falls back without accepting data',
    () async {
      for (final headers in [
        {
          'content-length': ['${_small.length + 1}'],
        },
        {
          'content-encoding': ['gzip'],
        },
      ]) {
        final sources = <ForkUpdateDownloadSource>[];
        final sut = service(
          mirror: (request) => ResponseBody.fromBytes(
            _small,
            200,
            headers: request.uri.host.startsWith('axisnow') ? headers : {},
          ),
        );
        final verified = await sut.download(
          _release(_small),
          onSourceChanged: sources.add,
        );
        expect(sources, [
          ForkUpdateDownloadSource.axisNow,
          ForkUpdateDownloadSource.v4,
        ]);
        expect(await verified.file.readAsBytes(), _small);
      }
    },
  );

  test(
    'cancelling full but corrupt primary during verification never tries backup',
    () async {
      final token = CancelToken();
      final sources = <ForkUpdateDownloadSource>[];
      final sut = service(
        mirror: (_) => ResponseBody.fromBytes(Uint8List(_small.length), 200),
      );
      await expectLater(
        sut.download(
          _release(_small),
          cancelToken: token,
          onSourceChanged: sources.add,
          onProgress: (received, total) {
            if (received == total) token.cancel();
          },
        ),
        throwsA(_error(ForkUpdateErrorCode.cancelled)),
      );
      expect(sources, [ForkUpdateDownloadSource.axisNow]);
      await emptyUpdates();
    },
  );

  // Distinct per-offset bytes catch accidental mixing of failed mirror ranges.
  final large = Uint8List(8 * 1024 * 1024 + 301);
  for (var i = 0; i < large.length; i++) {
    large[i] = (i + i ~/ 65536) % 251;
  }

  test(
    'parallel mirror failure stops every old worker before clean backup assembly',
    () async {
      final streams = <StreamController<Uint8List>>[];
      final started = Completer<void>();
      var cancelled = 0;
      final requests = <String>[];
      final sut = service(
        mirror: (request) {
          requests.add('${request.uri.host}:${request.headers['Range']}');
          if (request.uri.host == 'v4.gh-proxy.org') {
            expect(
              cancelled,
              4,
              reason: 'Old workers must finish before backup writes',
            );
            return _rangeResponse(request, large);
          }
          if (_range(request).start == 0) return _rangeResponse(request, large);
          final controller = StreamController<Uint8List>(
            onCancel: () {
              cancelled++;
            },
          );
          streams.add(controller);
          if (streams.length == 4) started.complete();
          return _rangeResponse(request, large, stream: controller.stream);
        },
      );
      final downloading = sut.download(_release(large));
      await started.future;
      streams.first.add(Uint8List.sublistView(large, 1, 65537));
      streams.first.addError(
        const SocketException('synthetic interrupted segment'),
      );
      final verified = await downloading.timeout(const Duration(seconds: 10));
      for (final stream in streams) {
        await stream.close();
      }
      expect(
        requests.where((value) => value.startsWith('axisnow')),
        hasLength(5),
      );
      expect(requests.where((value) => value.startsWith('v4')), hasLength(6));
      expect(await verified.file.readAsBytes(), large);
      await sut.verifyAgain(verified);
    },
  );

  test(
    'malformed mirror range header selects backup without retrying it',
    () async {
      var primary = 0;
      final sut = service(
        mirror: (request) {
          if (request.uri.host.startsWith('axisnow')) {
            primary++;
            return ResponseBody.fromBytes(
              [0],
              206,
              headers: {
                'content-range': ['bytes 1-1/${large.length}'],
              },
            );
          }
          return _rangeResponse(request, large);
        },
      );
      final verified = await sut.download(_release(large));
      expect(primary, 1);
      await sut.verifyAgain(verified);
    },
  );

  test(
    'ignored range body is cancelled before serial download on same mirror',
    () async {
      var cancelled = false;
      final controller = StreamController<Uint8List>(
        onCancel: () {
          cancelled = true;
        },
      );
      final sources = <ForkUpdateDownloadSource>[];
      final sut = service(
        mirror: (request) {
          if (request.headers['Range'] != null) {
            return ResponseBody(controller.stream, 200);
          }
          expect(cancelled, isTrue);
          return ResponseBody.fromBytes(large, 200);
        },
      );
      final verified = await sut.download(
        _release(large),
        onSourceChanged: sources.add,
      );
      await controller.close();
      expect(sources, [ForkUpdateDownloadSource.axisNow]);
      await sut.verifyAgain(verified);
    },
  );

  test(
    'cancellation stops four mirror ranges without requesting backup',
    () async {
      final started = Completer<void>();
      final streams = <StreamController<Uint8List>>[];
      final token = CancelToken();
      var cancelled = 0;
      final sources = <ForkUpdateDownloadSource>[];
      final sut = service(
        mirror: (request) {
          expect(request.uri.host, 'axisnow.gh-proxy.org');
          if (_range(request).start == 0) return _rangeResponse(request, large);
          final controller = StreamController<Uint8List>(
            onCancel: () {
              cancelled++;
            },
          );
          streams.add(controller);
          if (streams.length == 4) started.complete();
          return _rangeResponse(request, large, stream: controller.stream);
        },
      );
      final failure = expectLater(
        sut.download(
          _release(large),
          cancelToken: token,
          onSourceChanged: sources.add,
        ),
        throwsA(_error(ForkUpdateErrorCode.cancelled)),
      );
      await started.future;
      token.cancel();
      await failure.timeout(const Duration(seconds: 2));
      for (final controller in streams) {
        await controller.close();
      }
      expect(cancelled, 4);
      expect(sources, [ForkUpdateDownloadSource.axisNow]);
      await emptyUpdates();
    },
  );
}
