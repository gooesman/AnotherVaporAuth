import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ava/src/services/steam_acceleration_types.dart';
import 'package:ava/src/services/steam_windows_core.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _body(List<int> bytes) => ResponseBody.fromBytes(bytes, 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late List<int> executable;
  late List<int> archive;
  SteamWindowsCore? core;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('ava-core-unit-');
    executable = [0x4d, 0x5a, ...List.generate(300, (i) => i % 256)];
    final entries = Archive()
      ..addFile(
        ArchiveFile(
          'mihomo-windows-amd64-v1.exe',
          executable.length,
          executable,
        ),
      );
    archive = ZipEncoder().encode(entries);
  });
  tearDown(() async {
    core?.close();
    await folder.delete(recursive: true);
  });

  _Adapter setup(Future<ResponseBody> Function(RequestOptions) respond) {
    final adapter = _Adapter(respond);
    core = SteamWindowsCore.test(
      Dio()..httpClientAdapter = adapter,
      archiveDigest: sha256.convert(archive).toString(),
      executableDigest: sha256.convert(executable).toString(),
    );
    return adapter;
  }

  test(
    'first-use mirror download is verified and reused without a request',
    () async {
      final adapter = setup((_) async => _body(archive));
      var downloads = 0;
      final file = await core!.prepare(folder, onDownload: () => downloads++);
      expect(await file.readAsBytes(), executable);
      expect(
        file.path,
        p.join(folder.path, steamCoreVersion, 'ava-steam-core.exe'),
      );
      expect(
        await core!.prepare(folder, onDownload: () => downloads++),
        isA<File>(),
      );
      expect(downloads, 1);
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.uri.toString(),
        SteamWindowsCore.sources.first,
      );
      expect(
        adapter.requests.single.headers.keys,
        isNot(contains('Authorization')),
      );
      expect(adapter.requests.single.headers.keys, isNot(contains('Cookie')));
      expect(await File('${file.path}.pending').exists(), isFalse);
    },
  );

  test('failed first mirror falls through to the second mirror', () async {
    final adapter = setup(
      (request) async => request.uri.host == 'axisnow.gh-proxy.org'
          ? ResponseBody.fromString('unavailable', 503)
          : _body(archive),
    );
    await core!.prepare(folder);
    expect(adapter.requests.map((e) => e.uri.host), [
      'axisnow.gh-proxy.org',
      'v4.gh-proxy.org',
    ]);
  });

  test('bad mirror bytes are discarded before a verified fallback', () async {
    final adapter = setup(
      (request) async => request.uri.host == 'axisnow.gh-proxy.org'
          ? _body([1, 2, 3])
          : _body(archive),
    );
    final file = await core!.prepare(folder);
    expect(await file.readAsBytes(), executable);
    expect(adapter.requests, hasLength(2));
  });

  test(
    'mirror redirect is not followed and official CDN fallback works',
    () async {
      final adapter = setup((request) async {
        if (request.uri.host.endsWith('gh-proxy.org')) {
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': ['https://unexpected.invalid/core'],
            },
          );
        }
        if (request.uri.host == 'github.com') {
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': [
                'https://release-assets.githubusercontent.com/public-core',
              ],
            },
          );
        }
        return _body(archive);
      });
      await core!.prepare(folder);
      expect(adapter.requests.map((e) => e.uri.host), [
        'axisnow.gh-proxy.org',
        'v4.gh-proxy.org',
        'github.com',
        'release-assets.githubusercontent.com',
      ]);
    },
  );

  test(
    'unsafe official redirect is rejected without requesting its target',
    () async {
      final adapter = setup(
        (_) async => ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['http://release-assets.githubusercontent.com/core'],
          },
        ),
      );
      await expectLater(
        core!.prepare(folder),
        throwsA(
          isA<SteamAccelerationException>().having(
            (e) => e.code,
            'code',
            SteamAccelerationError.coreDownload,
          ),
        ),
      );
      expect(adapter.requests, hasLength(3));
    },
  );

  test(
    'all network failures produce a component-specific sanitized error',
    () async {
      setup(
        (request) async => throw DioException(
          requestOptions: request,
          message: 'fixture-secret-diagnostic',
        ),
      );
      try {
        await core!.prepare(folder);
        fail('Expected a component failure');
      } on SteamAccelerationException catch (error) {
        expect(error.code, SteamAccelerationError.coreDownload);
        expect(error.toString(), isNot(contains('fixture-secret')));
      }
    },
  );

  test('invalid bytes from every source never become executable', () async {
    setup((_) async => _body([9, 9]));
    await expectLater(
      core!.prepare(folder),
      throwsA(
        isA<SteamAccelerationException>().having(
          (e) => e.code,
          'code',
          SteamAccelerationError.coreIntegrity,
        ),
      ),
    );
    expect(
      await folder.list(recursive: true).where((e) => e is File).toList(),
      isEmpty,
    );
  });

  test(
    'a mismatched extracted executable is blocked despite a valid zip digest',
    () async {
      executable = [0x4d, 0x5a, 99];
      setup((_) async => _body(archive));
      await expectLater(
        core!.prepare(folder),
        throwsA(
          isA<SteamAccelerationException>().having(
            (e) => e.code,
            'code',
            SteamAccelerationError.coreIntegrity,
          ),
        ),
      );
      expect(
        await folder.list(recursive: true).where((e) => e is File).toList(),
        isEmpty,
      );
    },
  );

  test(
    'oversize and truncated declared bodies fall through without installing',
    () async {
      final adapter = setup((request) async {
        if (request.uri.host == 'axisnow.gh-proxy.org') {
          return ResponseBody.fromBytes(
            archive,
            200,
            headers: {
              'content-length': ['${33 * 1024 * 1024}'],
            },
          );
        }
        if (request.uri.host == 'v4.gh-proxy.org') {
          return ResponseBody.fromBytes(
            archive,
            200,
            headers: {
              'content-length': ['${archive.length + 1}'],
            },
          );
        }
        return _body(archive);
      });
      await core!.prepare(folder);
      expect(adapter.requests, hasLength(3));
    },
  );

  test('a corrupted cache is replaced only by a verified executable', () async {
    final destination = File(
      p.join(folder.path, steamCoreVersion, 'ava-steam-core.exe'),
    );
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes([0]);
    final adapter = setup((_) async => _body(archive));
    final file = await core!.prepare(folder);
    expect(await file.readAsBytes(), executable);
    expect(adapter.requests, hasLength(1));
  });
}
