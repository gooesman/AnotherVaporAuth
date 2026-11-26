import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ava/src/core/fork_update.dart';
import 'package:ava/src/services/fork_update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _tag = 'v1.5.1+100014';
const _name = 'AVA-Fork-$_tag-android-arm64.apk';
final _assetUrl = Uri.parse(
  'https://github.com/gooesman/AnotherVaporAuth/releases/download/$_tag/$_name',
);
final _cdnUrl = Uri.parse(
  'https://release-assets.githubusercontent.com/asset?synthetic-signature=ok',
);

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

void main() {
  // Each range contains different bytes, so out-of-order completion cannot
  // accidentally pass assembly/hash verification with an all-zero fixture.
  final bytes = Uint8List(8 * 1024 * 1024 + 301);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = (i + i ~/ 65536) % 251;
  }
  final release = ForkUpdateRelease(
    target: ForkUpdateTarget.androidArm64,
    tag: _tag,
    version: '1.5.1',
    buildNumber: 100014,
    notes: '',
    releaseUrl: Uri.parse(
      'https://github.com/gooesman/AnotherVaporAuth/releases/tag/$_tag',
    ),
    asset: ForkUpdateAsset(
      name: _name,
      url: _assetUrl,
      size: bytes.length,
      sha256: sha256.convert(bytes).toString(),
    ),
  );
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ava-parallel-update-');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  ForkUpdateService service(
    FutureOr<ResponseBody> Function(RequestOptions) handler, {
    bool parallel = true,
  }) => ForkUpdateService(
    dio: Dio()..httpClientAdapter = _Adapter(handler),
    temporaryDirectory: () async => temp,
    parallelDownloads: parallel,
  );

  ({int start, int end}) range(RequestOptions request) {
    final value = request.headers['Range'] as String;
    final match = RegExp(r'^bytes=(\d+)-(\d+)$').firstMatch(value)!;
    return (start: int.parse(match[1]!), end: int.parse(match[2]!));
  }

  ResponseBody response(
    RequestOptions request, {
    Stream<Uint8List>? stream,
    Map<String, List<String>>? replaceHeaders,
  }) {
    final segment = range(request);
    return ResponseBody(
      stream ??
          Stream.value(
            Uint8List.sublistView(bytes, segment.start, segment.end + 1),
          ),
      206,
      headers:
          replaceHeaders ??
          {
            'content-range': [
              'bytes ${segment.start}-${segment.end}/${bytes.length}',
            ],
            'content-length': ['${segment.end - segment.start + 1}'],
            'content-encoding': ['identity'],
          },
    );
  }

  Matcher error(ForkUpdateErrorCode code) =>
      isA<ForkUpdateException>().having((error) => error.code, 'code', code);

  Future<void> emptyUpdates() async {
    expect(
      await Directory(p.join(temp.path, 'updates')).list().toList(),
      isEmpty,
    );
  }

  test(
    'four concurrent ranges assemble out of order with bounded workers',
    () async {
      final requests = <RequestOptions>[];
      final activeGate = Completer<void>();
      var active = 0;
      var peak = 0;
      var started = 0;
      final progress = <int>[];
      final sut = service((request) async {
        requests.add(request);
        expect(request.headers['Accept-Encoding'], 'identity');
        expect(request.followRedirects, isFalse);
        if (request.uri.host == 'github.com') {
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': [_cdnUrl.toString()],
            },
          );
        }
        final segment = range(request);
        if (segment.start == 0) return response(request);
        active++;
        started++;
        if (active > peak) peak = active;
        if (started == 4) activeGate.complete();
        await activeGate.future;
        Stream<Uint8List> body() async* {
          try {
            // Later offsets finish first, exercising positioned writes.
            await Future<void>.delayed(
              Duration(milliseconds: 10 - segment.start ~/ (1024 * 1024)),
            );
            for (
              var offset = segment.start;
              offset <= segment.end;
              offset += 65536
            ) {
              final end = offset + 65536 <= segment.end + 1
                  ? offset + 65536
                  : segment.end + 1;
              yield Uint8List.sublistView(bytes, offset, end);
            }
          } finally {
            active--;
          }
        }

        return response(request, stream: body());
      });
      final verified = await sut.download(
        release,
        onProgress: (received, total) {
          expect(total, bytes.length);
          progress.add(received);
        },
      );
      expect(peak, 4);
      expect(active, 0);
      expect(requests.where((r) => r.uri.host == 'github.com'), hasLength(1));
      expect(requests.where((r) => r.uri.host == _cdnUrl.host), hasLength(6));
      expect(await verified.file.readAsBytes(), bytes);
      expect(progress.first, 0);
      expect(progress.last, bytes.length);
      expect(progress.where((value) => value == bytes.length), hasLength(1));
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThan(progress[i - 1]));
      }
      await sut.verifyAgain(verified);
    },
  );

  test(
    'probe 200 is cancelled without reading, then one serial request succeeds',
    () async {
      var requests = 0;
      var ignoredRangeCancelled = false;
      final ignored = StreamController<Uint8List>(
        onCancel: () {
          ignoredRangeCancelled = true;
        },
      );
      final sut = service((request) {
        requests++;
        if (request.headers['Range'] != null) {
          return ResponseBody(
            ignored.stream,
            200,
            headers: {
              'content-length': ['${bytes.length}'],
            },
          );
        }
        expect(ignoredRangeCancelled, isTrue);
        return ResponseBody.fromBytes(bytes, 200);
      });
      final verified = await sut.download(release);
      await ignored.close();
      expect(requests, 2);
      expect(await verified.file.readAsBytes(), bytes);
    },
  );

  test('explicit 416 probe falls back safely to serial download', () async {
    var requests = 0;
    final sut = service((request) {
      requests++;
      return request.headers['Range'] != null
          ? ResponseBody.fromString('', 416)
          : ResponseBody.fromBytes(bytes, 200);
    });
    await sut.download(release);
    expect(requests, 2);
  });

  test(
    'mid-download unsupported ranges cancel peers before serial fallback',
    () async {
      final gate = Completer<void>();
      final peers = <StreamController<Uint8List>>[];
      var rangeRequests = 0;
      var activePeers = 0;
      var serialRequests = 0;
      final sut = service((request) async {
        if (request.headers['Range'] == null) {
          serialRequests++;
          expect(activePeers, 0);
          return ResponseBody.fromBytes(bytes, 200);
        }
        final segment = range(request);
        if (segment.start == 0) return response(request);
        rangeRequests++;
        if (rangeRequests == 4) gate.complete();
        await gate.future;
        if (segment.start == 1) return ResponseBody.fromString('', 200);
        activePeers++;
        final controller = StreamController<Uint8List>(
          onCancel: () {
            activePeers--;
          },
        );
        peers.add(controller);
        return response(request, stream: controller.stream);
      });
      final verified = await sut.download(release);
      for (final peer in peers) {
        await peer.close();
      }
      expect(serialRequests, 1);
      expect(await verified.file.readAsBytes(), bytes);
    },
  );

  test('malformed 206 headers fail closed without retry or fallback', () async {
    for (final headers in [
      <String, List<String>>{},
      {
        'content-range': ['bytes 1-1/${bytes.length}'],
      },
      {
        'content-range': ['bytes 0-0/${bytes.length + 1}'],
      },
      {
        'content-range': ['bytes 0-0/*'],
      },
      {
        'content-range': [
          'bytes 0-0/${bytes.length}',
          'bytes 0-0/${bytes.length}',
        ],
      },
      {
        'content-range': ['bytes 0-0/${bytes.length}'],
        'content-length': ['2'],
      },
      {
        'content-range': ['bytes 0-0/${bytes.length}'],
        'content-length': ['invalid'],
      },
      {
        'content-range': ['bytes 0-0/${bytes.length}'],
        'content-encoding': ['gzip'],
      },
    ]) {
      var requests = 0;
      final sut = service((request) {
        requests++;
        return response(request, replaceHeaders: headers);
      });
      await expectLater(
        sut.download(release),
        throwsA(error(ForkUpdateErrorCode.invalidMetadata)),
        reason: headers.toString(),
      );
      expect(requests, 1);
      await emptyUpdates();
    }
  });

  test(
    'unsafe range redirects never reach a second host or serial fallback',
    () async {
      var requests = 0;
      final sut = service((request) {
        requests++;
        return ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['https://unknown.invalid/synthetic-signed-url'],
          },
        );
      });
      await expectLater(
        sut.download(release),
        throwsA(error(ForkUpdateErrorCode.invalidMetadata)),
      );
      expect(requests, 1);
      await emptyUpdates();
    },
  );

  test('range body cannot exceed its declared interval', () async {
    final sut = service(
      (request) =>
          response(request, stream: Stream.value(Uint8List.fromList([0, 1]))),
    );
    await expectLater(
      sut.download(release),
      throwsA(error(ForkUpdateErrorCode.tooLarge)),
    );
    await emptyUpdates();
  });

  test(
    'completed corrupted ranges enter verification but never return a verified file',
    () async {
      final progress = <int>[];
      final sut = service((request) {
        final segment = range(request);
        final data = Uint8List.fromList(
          bytes.sublist(segment.start, segment.end + 1),
        );
        if (segment.start == 1) data[0] ^= 0xff;
        return response(request, stream: Stream.value(data));
      });
      await expectLater(
        sut.download(
          release,
          onProgress: (received, _) => progress.add(received),
        ),
        throwsA(error(ForkUpdateErrorCode.hashMismatch)),
      );
      expect(progress.last, bytes.length);
      expect(progress.where((value) => value == bytes.length), hasLength(1));
      await emptyUpdates();
    },
  );

  test(
    'transient range retry overwrites its interval without double-counting progress',
    () async {
      final tries = <int, int>{};
      final progress = <int>[];
      var redirects = 0;
      final sut = service((request) {
        if (request.uri.host == 'github.com') {
          redirects++;
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': [_cdnUrl.toString()],
            },
          );
        }
        final segment = range(request);
        final attempt = tries.update(
          segment.start,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        if (segment.start == 1 && attempt == 1) {
          Stream<Uint8List> interrupted() async* {
            yield Uint8List.sublistView(bytes, 1, 65537);
            throw const SocketException('synthetic network interruption');
          }

          return response(request, stream: interrupted());
        }
        return response(request);
      });
      final verified = await sut.download(
        release,
        onProgress: (received, _) => progress.add(received),
      );
      expect(tries[1], 2);
      expect(
        redirects,
        2,
      ); // Initial probe plus fresh official URL for the retry.
      expect(await verified.file.readAsBytes(), bytes);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThan(progress[i - 1]));
        expect(progress[i], lessThanOrEqualTo(bytes.length));
      }
    },
  );

  test(
    'truncated range retries are bounded to three attempts and cleaned',
    () async {
      var requests = 0;
      final sut = service((request) {
        requests++;
        return response(request, stream: const Stream<Uint8List>.empty());
      });
      await expectLater(
        sut.download(release),
        throwsA(error(ForkUpdateErrorCode.networkError)),
      );
      expect(requests, 3);
      await emptyUpdates();
    },
  );

  test(
    'cancellation stops all four in-flight ranges and deletes only owned file',
    () async {
      final started = Completer<void>();
      final streams = <StreamController<Uint8List>>[];
      final token = CancelToken();
      var cancelled = 0;
      final sentinel = File(p.join(temp.path, 'keep.txt'))
        ..writeAsStringSync('keep');
      final sut = service((request) {
        if (range(request).start == 0) return response(request);
        final controller = StreamController<Uint8List>(
          onCancel: () {
            cancelled++;
          },
        );
        streams.add(controller);
        if (streams.length == 4) started.complete();
        return response(request, stream: controller.stream);
      });
      final future = sut.download(release, cancelToken: token);
      final expectation = expectLater(
        future,
        throwsA(error(ForkUpdateErrorCode.cancelled)),
      );
      await started.future;
      token.cancel();
      await expectation.timeout(const Duration(seconds: 2));
      for (final controller in streams) {
        await controller.close();
      }
      expect(cancelled, 4);
      expect(await sentinel.readAsString(), 'keep');
      await emptyUpdates();
    },
  );

  test(
    'serial diagnostic switch keeps the same verification pipeline',
    () async {
      var requests = 0;
      final sut = service((request) {
        expect(request.headers['Range'], isNull);
        requests++;
        return ResponseBody.fromBytes(bytes, 200);
      }, parallel: false);
      final verified = await sut.download(release);
      expect(requests, 1);
      await sut.verifyAgain(verified);
    },
  );
}
