import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ava/src/services/steam_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => SteamNetwork.configureProxy(() => null));

  test('proxy scope is limited to genuine Steam HTTPS origins', () {
    for (final url in [
      'https://steamcommunity.com/',
      'https://api.steampowered.com/',
      'https://community.akamai.steamstatic.com/',
      'https://steamcdn-a.akamaihd.net/',
      'https://STEAMCOMMUNITY.COM./',
    ]) {
      expect(SteamNetwork.isSteamRequest(Uri.parse(url)), isTrue, reason: url);
    }
    for (final url in [
      'http://steamcommunity.com/',
      'https://steamcommunity.com:444/',
      'https://steamcommunity.com.evil.example/',
      'https://notsteamcommunity.com/',
      'https://user@steamcommunity.com/',
      'https://github.com/',
      'https://my-webdav.example/',
      'https://127.0.0.1/',
      '//steamcommunity.com:443',
      '//steamcommunity.com:443/path',
    ]) {
      expect(SteamNetwork.isSteamRequest(Uri.parse(url)), isFalse, reason: url);
    }
  });

  test(
    'proxy configuration rejects directive injection and hides credentials',
    () {
      for (final host in [
        '127.0.0.1; DIRECT',
        'user@localhost',
        'local host',
        '',
      ]) {
        expect(
          () => SteamNetworkProxy(host: host, port: 8080),
          throwsArgumentError,
        );
      }
      final proxy = SteamNetworkProxy(
        host: '::1',
        port: 8080,
        username: 'test',
        password: 'secret',
      );
      expect(proxy.directive, 'PROXY [::1]:8080');
      expect(proxy.toString(), isNot(contains('secret')));
    },
  );

  test(
    'real CONNECT keeps proxy credentials outside Steam TLS requests and adopts route changes',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      final first = await fixture.proxy('first');
      final second = await fixture.proxy('second');
      var route = first.endpoint;
      SteamNetwork.configureProxy(() => route);
      final dio = SteamNetwork.createDio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
        securityContext: fixture.trust,
        socketConnector: fixture.connect,
      );
      addTearDown(() => dio.close(force: true));
      final initial = await dio.post<String>(
        'https://steamcommunity.com/check',
        data: 'synthetic-steam-body',
      );
      expect(initial.data, 'ok');
      expect(first.authorized, 1);
      expect(second.authorized, 0);
      route = second.endpoint;
      expect(
        (await dio.get<String>('https://steamcommunity.com/check')).data,
        'ok',
      );
      expect(second.authorized, 1);
      expect(fixture.proxyHeadersAtSteam, everyElement(isNull));
      expect(fixture.steamHosts, everyElement('steamcommunity.com'));
      // A different service never enters either proxy, even with one configured.
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

  test(
    'default TLS validation rejects an untrusted Steam certificate through the proxy',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      final proxy = await fixture.proxy('only');
      SteamNetwork.configureProxy(() => proxy.endpoint);
      final dio = SteamNetwork.createDio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
        socketConnector: fixture.connect,
      );
      addTearDown(() => dio.close(force: true));
      await expectLater(
        dio.get<String>('https://steamcommunity.com/check'),
        throwsA(
          isA<DioException>().having(
            (error) => error.error,
            'TLS failure',
            isA<HandshakeException>(),
          ),
        ),
      );
      expect(proxy.authorized, 1);
      expect(fixture.steamHosts, isEmpty);
    },
  );

  test(
    'wrong proxy credentials fail without retrying or sending Steam data',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      final proxy = await fixture.proxy('expected');
      SteamNetwork.configureProxy(
        () => SteamNetworkProxy(
          host: proxy.endpoint.host,
          port: proxy.endpoint.port,
          username: 'expected',
          password: 'wrong-synthetic-password',
        ),
      );
      final dio = SteamNetwork.createDio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
        securityContext: fixture.trust,
        socketConnector: fixture.connect,
      );
      addTearDown(() => dio.close(force: true));
      await expectLater(
        dio.post<String>(
          'https://steamcommunity.com/sms',
          data: 'must-not-reach-Steam',
        ),
        throwsA(isA<DioException>()),
      );
      expect(proxy.authorized, 0);
      expect(proxy.requests, 1);
      expect(fixture.steamHosts, isEmpty);
    },
  );

  test(
    'a trusted certificate for a different Steam host is still rejected',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      final proxy = await fixture.proxy(
        'wrong-host',
        target: 'api.steampowered.com:443',
      );
      SteamNetwork.configureProxy(() => proxy.endpoint);
      final dio = SteamNetwork.createDio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
        securityContext: fixture.trust,
        socketConnector: fixture.connect,
      );
      addTearDown(() => dio.close(force: true));
      await expectLater(
        dio.get<String>('https://api.steampowered.com/check'),
        throwsA(
          isA<DioException>().having(
            (error) => error.error,
            'TLS hostname failure',
            isA<HandshakeException>(),
          ),
        ),
      );
      expect(proxy.authorized, 1);
      expect(fixture.steamHosts, isEmpty);
    },
  );

  test(
    'Steam requests wait for proxy readiness while unrelated services continue',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      final proxy = await fixture.proxy('ready');
      final readiness = Completer<void>();
      SteamNetworkProxy? route;
      SteamNetwork.configureProxy(() => route, readiness: readiness.future);
      final dio = SteamNetwork.createDio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
        securityContext: fixture.trust,
        socketConnector: fixture.connect,
      );
      addTearDown(() => dio.close(force: true));
      final pending = dio.post<String>(
        'https://steamcommunity.com/sms',
        data: 'sent-once-after-ready',
      );
      final direct = await dio.get<String>(
        'https://localhost:${fixture.server.port}/direct',
      );
      expect(direct.data, 'ok');
      expect(proxy.requests, 0);
      expect(fixture.steamHosts, hasLength(1));
      route = proxy.endpoint;
      readiness.complete();
      expect((await pending).data, 'ok');
      expect(proxy.authorized, 1);
      expect(fixture.steamHosts, hasLength(2));
    },
  );

  test(
    'a failed readiness future fails the Steam request without any socket',
    () async {
      final readiness = Completer<void>();
      SteamNetwork.configureProxy(() => null, readiness: readiness.future);
      var connections = 0;
      final dio = SteamNetwork.createDio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 1),
          receiveTimeout: const Duration(seconds: 1),
        ),
        socketConnector: (host, port) {
          connections++;
          return Future<ConnectionTask<Socket>>.error(
            StateError('Unexpected socket'),
          );
        },
      );
      addTearDown(() => dio.close(force: true));
      final pending = dio.post<String>(
        'https://steamcommunity.com/sms',
        data: 'never-sent',
      );
      final assertion = expectLater(
        pending.timeout(const Duration(seconds: 3)),
        throwsA(isA<DioException>()),
      );
      // Even if readiness fails before Dio enters its separate interceptor
      // error zone, the normalized failure must not leak or hang the request.
      readiness.completeError(StateError('Synthetic startup failure'));
      await assertion;
      expect(connections, 0);
    },
  );

  test(
    'cancelled requests do not send a write when readiness later completes',
    () async {
      final fixture = await _NetworkFixture.create();
      addTearDown(fixture.close);
      final proxy = await fixture.proxy('cancelled');
      final readiness = Completer<void>();
      SteamNetwork.configureProxy(
        () => proxy.endpoint,
        readiness: readiness.future,
      );
      final dio = SteamNetwork.createDio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
        securityContext: fixture.trust,
        socketConnector: fixture.connect,
      );
      addTearDown(() => dio.close(force: true));
      final token = CancelToken();
      final pending = dio.post<String>(
        'https://steamcommunity.com/sms',
        data: 'cancelled-write',
        cancelToken: token,
      );
      final assertion = expectLater(
        pending,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'cancel type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      await assertion;
      readiness.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(proxy.requests, 0);
      expect(fixture.steamHosts, isEmpty);
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
  final proxyHeadersAtSteam = <String?>[];
  final steamHosts = <String?>[];

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
    const prefix = 'test/fixtures/steam_network/';
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
      fixture.proxyHeadersAtSteam.add(
        request.headers.value(HttpHeaders.proxyAuthorizationHeader),
      );
      fixture.steamHosts.add(request.headers.value(HttpHeaders.hostHeader));
      await request.drain<void>();
      request.response.write('ok');
      await request.response.close();
    });
    return fixture;
  }

  Future<_Proxy> proxy(
    String name, {
    String target = 'steamcommunity.com:443',
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
      expect(lines.first, 'CONNECT $target HTTP/1.1');
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
