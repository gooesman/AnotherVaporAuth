import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ava/src/core/fork_update.dart';
import 'package:ava/src/services/fork_update_network.dart';
import 'package:ava/src/services/steam_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _latest =
    'https://api.github.com/repos/gooesman/AnotherVaporAuth/releases/latest';

void main() {
  tearDown(() {
    ForkUpdateNetwork.configureProxy(() => null);
    SteamNetwork.configureProxy(() => null);
  });

  test('update routing is restricted to this fork and exact official hosts', () {
    for (final url in [
      _latest,
      'https://github.com/gooesman/AnotherVaporAuth/releases/download/v1.5.1%2B100014/package.apk',
      'https://release-assets.githubusercontent.com/path?synthetic=signed-query',
      'https://objects.githubusercontent.com/path',
      'https://objects-origin.githubusercontent.com/path',
      'https://github-releases.githubusercontent.com/path',
    ]) {
      expect(
        ForkUpdateNetwork.isOfficialRequest(Uri.parse(url)),
        isTrue,
        reason: url,
      );
    }
    for (final url in [
      'http://api.github.com/repos/gooesman/AnotherVaporAuth/releases/latest',
      'https://api.github.com:444/repos/gooesman/AnotherVaporAuth/releases/latest',
      'https://user@api.github.com/repos/gooesman/AnotherVaporAuth/releases/latest',
      '$_latest?private=token',
      '$_latest#fragment',
      'https://api.github.com/repos/another/repository/releases/latest',
      'https://api.github.com/repos%2Fgooesman%2FAnotherVaporAuth%2Freleases%2Flatest',
      'https://github.com/another/repository/releases/download/v1/file.exe',
      'https://github.com/gooesman/AnotherVaporAuth/issues',
      'https://release-assets.githubusercontent.com.evil.example/file',
      'https://unlisted.githubusercontent.com/file',
      'https://steamcommunity.com/',
      'https://my-webdav.example/',
    ]) {
      expect(
        ForkUpdateNetwork.isOfficialRequest(Uri.parse(url)),
        isFalse,
        reason: url,
      );
    }
  });

  test('mirror mapping permits only the exact public fork asset wrapper', () {
    final official = Uri.parse(
      'https://github.com/gooesman/AnotherVaporAuth/releases/download/v1.5.2+100015/AVA-Fork-v1.5.2+100015-android-arm64.apk',
    );
    for (final source in [
      ForkUpdateDownloadSource.axisNow,
      ForkUpdateDownloadSource.v4,
    ]) {
      final url = ForkUpdateNetwork.mirrorAssetUrl(source, official);
      expect(
        url.toString(),
        contains('v1.5.2%2B100015/AVA-Fork-v1.5.2%2B100015-android-arm64.apk'),
      );
      expect(ForkUpdateNetwork.isMirrorRequest(url), isTrue);
      for (final invalid in [
        url.replace(scheme: 'http'),
        url.replace(host: 'unlisted.gh-proxy.org'),
        url.replace(host: '${url.host}.evil.example'),
        url.replace(userInfo: 'private:credential'),
        url.replace(port: 444),
        url.replace(query: 'private=token'),
        url.replace(fragment: 'fragment'),
        Uri.parse(
          'https://${url.host}/https://api.github.com/repos/gooesman/AnotherVaporAuth/releases/latest',
        ),
        Uri.parse(
          'https://${url.host}/https://github.com/other/project/releases/download/v1/package.apk',
        ),
        Uri.parse(
          'https://${url.host}/https://github.com/gooesman/AnotherVaporAuth/releases/download/v1/file.apk/extra',
        ),
      ]) {
        expect(
          ForkUpdateNetwork.isMirrorRequest(invalid),
          isFalse,
          reason: invalid.toString(),
        );
      }
    }
    for (final invalid in [
      Uri.parse(_latest),
      official.replace(scheme: 'http'),
      official.replace(query: 'private=token'),
      Uri.parse(
        'https://github.com/other/project/releases/download/v1/package.apk',
      ),
      Uri.parse('https://release-assets.githubusercontent.com/asset'),
    ]) {
      expect(
        () => ForkUpdateNetwork.mirrorAssetUrl(
          ForkUpdateDownloadSource.axisNow,
          invalid,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => ForkUpdateNetwork.mirrorAssetUrl(
        ForkUpdateDownloadSource.github,
        official,
      ),
      throwsArgumentError,
    );
  });

  test(
    'mirror factory connects directly despite pending readiness and active proxies',
    () async {
      final ready = Completer<void>();
      final steamReady = Completer<void>();
      final proxy = SteamNetworkProxy(
        host: '127.0.0.1',
        port: 34567,
        username: 'synthetic',
        password: 'never-forward',
      );
      ForkUpdateNetwork.configureProxy(() => proxy, readiness: ready.future);
      SteamNetwork.configureProxy(() => proxy, readiness: steamReady.future);
      final destinations = <String>[];
      final dio = ForkUpdateNetwork.createMirrorDio(
        socketConnector: (host, port) async {
          destinations.add('$host:$port');
          // No external traffic is permitted by this test seam.
          throw const SocketException('synthetic direct connection reached');
        },
      );
      addTearDown(() => dio.close(force: true));
      final headers = <String, dynamic>{};
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            headers.addAll(request.headers);
            handler.next(request);
          },
        ),
      );
      await expectLater(
        dio
            .get<String>(
              'https://axisnow.gh-proxy.org/https://github.com/gooesman/AnotherVaporAuth/releases/download/v1/file.apk',
            )
            .timeout(const Duration(seconds: 2)),
        throwsA(isA<DioException>()),
      );
      expect(destinations, ['axisnow.gh-proxy.org:443']);
      expect(ready.isCompleted, isFalse);
      expect(steamReady.isCompleted, isFalse);
      expect(
        headers.keys.map((key) => key.toLowerCase()),
        isNot(
          contains(anyOf('authorization', 'cookie', 'proxy-authorization')),
        ),
      );
      ready.complete();
      steamReady.complete();
    },
  );

  test(
    'direct mirror transport retains certificate and hostname validation',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      final destinations = <String>[];
      final dio = ForkUpdateNetwork.createMirrorDio(
        securityContext: fixture.trust,
        socketConnector: (host, port) {
          destinations.add('$host:$port');
          return Socket.startConnect(
            InternetAddress.loopbackIPv4,
            fixture.server.port,
          );
        },
      );
      addTearDown(() => dio.close(force: true));
      await expectLater(
        dio.get<String>(
          'https://axisnow.gh-proxy.org/https://github.com/gooesman/AnotherVaporAuth/releases/download/v1/file.apk',
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.error,
            'TLS error',
            isA<HandshakeException>(),
          ),
        ),
      );
      expect(destinations, ['axisnow.gh-proxy.org:443']);
      expect(fixture.originHosts, isEmpty);
    },
  );

  test(
    'real update CONNECT isolates credentials and adopts route changes',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      final first = await fixture.proxy('first');
      final second = await fixture.proxy('second');
      var route = first.endpoint;
      ForkUpdateNetwork.configureProxy(() => route);
      SteamNetwork.configureProxy(() => second.endpoint);
      final dio = ForkUpdateNetwork.createDio(
        securityContext: fixture.trust,
        socketConnector: fixture.connect,
      );
      addTearDown(() => dio.close(force: true));
      expect((await dio.get<String>(_latest)).data, 'ok');
      expect(first.authorized, 1);
      expect(second.authorized, 0);
      route = second.endpoint;
      expect((await dio.get<String>(_latest)).data, 'ok');
      expect(second.authorized, 1);
      expect(fixture.proxyHeadersAtOrigin, everyElement(isNull));
      expect(fixture.authorizationAtOrigin, everyElement(isNull));
      expect(fixture.cookiesAtOrigin, everyElement(isNull));
      expect(fixture.originHosts, everyElement('api.github.com'));
      expect(
        (await dio.get<String>(
          'https://localhost:${fixture.server.port}/direct',
        )).data,
        'ok',
      );
      expect(first.authorized, 1);
      expect(second.authorized, 1);
    },
  );

  test('official asset CDN uses the same authenticated transport', () async {
    final fixture = await _NetworkFixture.create();
    addTearDown(fixture.close);
    final proxy = await fixture.proxy(
      'asset',
      target: 'release-assets.githubusercontent.com:443',
    );
    ForkUpdateNetwork.configureProxy(() => proxy.endpoint);
    final dio = ForkUpdateNetwork.createDio(
      securityContext: fixture.trust,
      socketConnector: fixture.connect,
    );
    addTearDown(() => dio.close(force: true));
    expect(
      (await dio.get<String>(
        'https://release-assets.githubusercontent.com/asset?fixture=only',
      )).data,
      'ok',
    );
    expect(proxy.authorized, 1);
    expect(fixture.proxyHeadersAtOrigin, [null]);
  });

  test(
    'update connection pool follows a direct to TUN route identity change',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      var systemRoute = false;
      var connections = 0;
      ForkUpdateNetwork.configureProxy(
        () => null,
        routeIdentity: () => systemRoute,
      );
      final dio = ForkUpdateNetwork.createDio(
        securityContext: fixture.trust,
        socketConnector: (host, port) {
          expect(host, 'api.github.com');
          expect(port, 443);
          connections++;
          return Socket.startConnect(
            InternetAddress.loopbackIPv4,
            fixture.server.port,
          );
        },
      );
      addTearDown(() => dio.close(force: true));
      expect((await dio.get<String>(_latest)).data, 'ok');
      expect((await dio.get<String>(_latest)).data, 'ok');
      expect(connections, 1);
      systemRoute = true;
      expect((await dio.get<String>(_latest)).data, 'ok');
      expect(connections, 2);
      expect(fixture.authorizationAtOrigin, everyElement(isNull));
      expect(fixture.cookiesAtOrigin, everyElement(isNull));
    },
  );

  test(
    'default TLS rejects an untrusted certificate through update proxy',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      final proxy = await fixture.proxy('tls');
      ForkUpdateNetwork.configureProxy(() => proxy.endpoint);
      final dio = ForkUpdateNetwork.createDio(socketConnector: fixture.connect);
      addTearDown(() => dio.close(force: true));
      await expectLater(
        dio.get<String>(_latest),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'cause',
            isA<HandshakeException>(),
          ),
        ),
      );
      expect(proxy.authorized, 1);
      expect(fixture.originHosts, isEmpty);
    },
  );

  test(
    'trusted certificate cannot authenticate a different CDN hostname',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      final proxy = await fixture.proxy(
        'host',
        target: 'objects.githubusercontent.com:443',
      );
      ForkUpdateNetwork.configureProxy(() => proxy.endpoint);
      final dio = ForkUpdateNetwork.createDio(
        securityContext: fixture.trust,
        socketConnector: fixture.connect,
      );
      addTearDown(() => dio.close(force: true));
      await expectLater(
        dio.get<String>('https://objects.githubusercontent.com/asset'),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'cause',
            isA<HandshakeException>(),
          ),
        ),
      );
      expect(proxy.authorized, 1);
      expect(fixture.originHosts, isEmpty);
    },
  );

  test(
    'update readiness is separate from Steam core startup readiness',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      final proxy = await fixture.proxy('ready');
      final environment = Completer<void>();
      final steamCore = Completer<void>();
      ForkUpdateNetwork.configureProxy(
        () => proxy.endpoint,
        readiness: environment.future,
      );
      SteamNetwork.configureProxy(() => null, readiness: steamCore.future);
      final dio = ForkUpdateNetwork.createDio(
        securityContext: fixture.trust,
        socketConnector: fixture.connect,
      );
      addTearDown(() => dio.close(force: true));
      final pending = dio.get<String>(_latest);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(proxy.requests, 0);
      environment.complete();
      expect((await pending).data, 'ok');
      expect(steamCore.isCompleted, isFalse);
      steamCore.complete();
    },
  );

  test(
    'cancel during readiness prevents a late update network request',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      final proxy = await fixture.proxy('cancel');
      final ready = Completer<void>();
      ForkUpdateNetwork.configureProxy(
        () => proxy.endpoint,
        readiness: ready.future,
      );
      final dio = ForkUpdateNetwork.createDio(
        securityContext: fixture.trust,
        socketConnector: fixture.connect,
      );
      addTearDown(() => dio.close(force: true));
      final cancel = CancelToken();
      final pending = dio.get<String>(_latest, cancelToken: cancel);
      final failed = expectLater(
        pending,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      cancel.cancel();
      await failed;
      ready.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(proxy.requests, 0);
    },
  );
}

class _Proxy {
  _Proxy(this.server, this.name);
  final ServerSocket server;
  final String name;
  int authorized = 0;
  int challenges = 0;
  int requests = 0;
  SteamNetworkProxy get endpoint => SteamNetworkProxy(
    host: '127.0.0.1',
    port: server.port,
    username: name,
    password: 'synthetic-password',
  );
}

class _NetworkFixture {
  _NetworkFixture(this.server, this.trust);
  final HttpServer server;
  final SecurityContext trust;
  final proxies = <_Proxy>[];
  final sockets = <Socket>[];
  final proxyHeadersAtOrigin = <String?>[];
  final originHosts = <String?>[];
  final authorizationAtOrigin = <String?>[];
  final cookiesAtOrigin = <String?>[];

  /// Every socket stays on loopback, even if production incorrectly bypasses
  /// the proxy. TLS still uses the original URI host for certificate checks.
  Future<ConnectionTask<Socket>> connect(String host, int port) {
    if (host != 'localhost' && host != '127.0.0.1') {
      return Future<ConnectionTask<Socket>>.error(
        StateError('Test refuses a non-loopback connection: $host'),
      );
    }
    return Socket.startConnect(InternetAddress.loopbackIPv4, port);
  }

  static Future<_NetworkFixture> create() async {
    const prefix = 'test/fixtures/fork_update_network/';
    final serverContext = SecurityContext()
      ..useCertificateChain('${prefix}certificate.pem')
      ..usePrivateKey('${prefix}test-key.pem');
    final trust = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates('${prefix}certificate.pem');
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext,
    );
    final fixture = _NetworkFixture(server, trust);
    server.listen((request) async {
      fixture.proxyHeadersAtOrigin.add(
        request.headers.value(HttpHeaders.proxyAuthorizationHeader),
      );
      fixture.originHosts.add(request.headers.value(HttpHeaders.hostHeader));
      fixture.authorizationAtOrigin.add(
        request.headers.value(HttpHeaders.authorizationHeader),
      );
      fixture.cookiesAtOrigin.add(
        request.headers.value(HttpHeaders.cookieHeader),
      );
      await request.drain<void>();
      request.response.write('ok');
      await request.response.close();
    });
    return fixture;
  }

  Future<_Proxy> proxy(
    String name, {
    String? target = 'api.github.com:443',
  }) async {
    // Parse CONNECT's authority-form target directly. This fixture must not
    // depend on HttpServer's origin-form URI normalization or detach semantics.
    final proxyServer = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final result = _Proxy(proxyServer, name);
    proxies.add(result);
    proxyServer.listen((client) async {
      sockets.add(client);
      final input = StreamIterator<List<int>>(client);
      final buffer = <int>[];
      var headerEnd = -1;
      while (await input.moveNext()) {
        buffer.addAll(input.current);
        expect(buffer.length, lessThan(16384));
        for (var i = 0; i + 3 < buffer.length; i++) {
          if (buffer[i] == 13 &&
              buffer[i + 1] == 10 &&
              buffer[i + 2] == 13 &&
              buffer[i + 3] == 10) {
            headerEnd = i + 4;
            break;
          }
        }
        if (headerEnd >= 0) break;
      }
      if (headerEnd < 0) {
        await input.cancel();
        return;
      }
      final lines = ascii.decode(buffer.sublist(0, headerEnd)).split('\r\n');
      if (target != null) {
        expect(lines.first, 'CONNECT $target HTTP/1.1');
      } else {
        expect(
          lines.first,
          anyOf(
            'CONNECT api.github.com:443 HTTP/1.1',
            'CONNECT release-assets.githubusercontent.com:443 HTTP/1.1',
          ),
        );
      }
      final headers = <String, String>{};
      for (final line in lines.skip(1)) {
        if (line.isEmpty) continue;
        final colon = line.indexOf(':');
        expect(colon, greaterThan(0));
        headers[line.substring(0, colon).toLowerCase()] = line
            .substring(colon + 1)
            .trim();
      }
      result.requests++;
      final expected =
          'Basic ${base64Encode(utf8.encode('$name:synthetic-password'))}';
      if (headers[HttpHeaders.proxyAuthorizationHeader] != expected) {
        result.challenges++;
        client.write(
          'HTTP/1.1 407 Proxy Authentication Required\r\n'
          'Proxy-Authenticate: Basic realm="AVA test"\r\n'
          'Content-Length: 0\r\nConnection: close\r\n\r\n',
        );
        await client.flush();
        await client.close();
        await input.cancel();
        return;
      }
      result.authorized++;
      final upstream = await Socket.connect(
        InternetAddress.loopbackIPv4,
        server.port,
      );
      sockets.add(upstream);
      client.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      await client.flush();
      unawaited(
        upstream
            .cast<List<int>>()
            .pipe(client)
            .then<void>((_) {}, onError: (Object _) => client.destroy()),
      );
      try {
        if (buffer.length > headerEnd) upstream.add(buffer.sublist(headerEnd));
        while (await input.moveNext()) {
          upstream.add(input.current);
        }
        await upstream.close();
      } on SocketException {
        // An intentionally rejected TLS handshake closes the peer connection.
        upstream.destroy();
      } finally {
        await input.cancel();
      }
    });
    return result;
  }

  Future<void> close() async {
    for (final socket in sockets) {
      socket.destroy();
    }
    for (final proxy in proxies) {
      await proxy.server.close();
    }
    await server.close(force: true);
  }
}
