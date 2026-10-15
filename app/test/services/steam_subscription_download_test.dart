import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ava/src/services/steam_acceleration_types.dart';
import 'package:ava/src/services/steam_subscription_download.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final servers = <HttpServer>[];
  final rawServers = <ServerSocket>[];
  final sockets = <Socket>[];

  // A half-finished HTTP response lets tests observe actual socket shutdown;
  // HttpServerResponse.done only completes when the server itself closes it.
  Future<({Uri uri, Future<void> disconnected})> stalledStream(
    String firstChunk,
  ) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    rawServers.add(server);
    final disconnected = Completer<void>();
    server.listen((socket) {
      sockets.add(socket);
      var sent = false;
      final input = <int>[];
      socket.listen(
        (chunk) {
          input.addAll(chunk);
          if (sent || !ascii.decode(input).contains('\r\n\r\n')) return;
          sent = true;
          socket.write(
            'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n'
            '${firstChunk.length.toRadixString(16)}\r\n$firstChunk\r\n',
          );
        },
        onDone: () {
          if (!disconnected.isCompleted) disconnected.complete();
        },
        onError: (Object _) {
          if (!disconnected.isCompleted) disconnected.complete();
        },
      );
    });
    return (
      uri: Uri.parse('http://127.0.0.1:${server.port}/list'),
      disconnected: disconnected.future,
    );
  }

  Future<HttpServer> serve(
    FutureOr<void> Function(HttpRequest) handler, {
    bool tls = false,
  }) async {
    final server = tls
        ? await HttpServer.bindSecure(
            InternetAddress.loopbackIPv4,
            0,
            SecurityContext()
              ..useCertificateChain(
                'test/fixtures/steam_network/certificate.pem',
              )
              ..usePrivateKey('test/fixtures/steam_network/test-key.pem'),
          )
        : await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servers.add(server);
    server.listen((request) async {
      try {
        await handler(request);
      } on SocketException {
        // Size/deadline tests intentionally close a response mid-stream.
      }
    });
    return server;
  }

  HttpClient trustedClient() => HttpClient(
    context: SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates('test/fixtures/steam_network/certificate.pem'),
  );

  Uri url(HttpServer server, [String path = '/list']) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: server.port, path: path);

  TypeMatcher<SteamSubscriptionDownloadException> failed(
    SteamSubscriptionDownloadFailure reason,
  ) => isA<SteamSubscriptionDownloadException>().having(
    (error) => error.reason,
    'reason',
    reason,
  );

  tearDown(() async {
    for (final socket in sockets) {
      socket.destroy();
    }
    sockets.clear();
    for (final server in rawServers) {
      await server.close();
    }
    rawServers.clear();
    for (final server in servers) {
      await server.close(force: true);
    }
    servers.clear();
  });

  test(
    'validator accepts HTTP Basic and HTTPS IP custom-port subscriptions',
    () {
      final basic = validateSteamSubscriptionUrl(
        ' http://reader:p%40ss%3Aword@127.0.0.1:8088/clash.yaml ',
      );
      expect(basic.scheme, 'http');
      expect(basic.port, 8088);
      expect(basic.userInfo, 'reader:p%40ss%3Aword');
      final secure = validateSteamSubscriptionUrl(
        'https://192.0.2.1:55356/api/subscribe?token=synthetic-token',
      );
      expect(secure.port, 55356);
      expect(secure.queryParameters['token'], 'synthetic-token');
    },
  );

  test('validator rejects malformed links without reflecting any input', () {
    for (final invalid in [
      'ftp://host.invalid/synthetic-token',
      'https:///synthetic-token',
      'https://host.invalid:0/synthetic-token',
      'https://host.invalid:65536/synthetic-token',
      'https://host.invalid/list#synthetic-token',
      'https://host.invalid/a synthetic-token',
      'http://reader%3Aother:synthetic-token@host.invalid/',
      'http://:synthetic-token@host.invalid/',
      'http://reader:synthetic-token%0D%0A@host.invalid/',
      'http://reader:synthetic-token%GG@host.invalid/',
    ]) {
      expect(
        () => validateSteamSubscriptionUrl(invalid),
        throwsA(
          isA<SteamAccelerationException>()
              .having(
                (error) => error.code,
                'code',
                SteamAccelerationError.invalidSubscription,
              )
              .having(
                (error) => error.toString(),
                'redacted',
                isNot(contains('synthetic-token')),
              ),
        ),
      );
    }
  });

  test(
    'HTTP decodes Basic credentials once and sends the Clash client UA',
    () async {
      String? authorization;
      String? userAgent;
      Uri? requestUri;
      final server = await serve((request) async {
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        userAgent = request.headers.value(HttpHeaders.userAgentHeader);
        requestUri = request.uri;
        request.response.write('proxies: []');
        await request.response.close();
      });
      final endpoint = url(server).replace(
        userInfo: 'r%65ader:p%40ss%3Aword%2520',
        query: 'token=synthetic-token',
      );
      expect(await downloadSteamSubscription(endpoint), 'proxies: []');
      expect(
        authorization,
        'Basic ${base64.encode(utf8.encode('reader:p@ss:word%20'))}',
      );
      expect(userAgent, 'clash.meta');
      expect(requestUri!.userInfo, isEmpty);
      expect(requestUri!.queryParameters['token'], 'synthetic-token');
    },
  );

  test(
    'same-origin redirects preserve authorization and skip redirect body',
    () async {
      final seen = <String?>[];
      final server = await serve((request) async {
        seen.add(request.headers.value(HttpHeaders.authorizationHeader));
        if (request.uri.path == '/list') {
          request.response.statusCode = HttpStatus.found;
          request.response.headers.set(HttpHeaders.locationHeader, '/final');
          request.response.write('x' * 1024);
        } else {
          request.response.write('ok');
        }
        await request.response.close();
      });
      expect(
        await downloadSteamSubscription(
          url(server).replace(userInfo: 'reader:password'),
          maxBytes: 16,
        ),
        'ok',
      );
      expect(seen.length, 2);
      expect(seen.first, isNotNull);
      expect(seen.last, seen.first);
    },
  );

  test(
    'origin change drops credentials permanently, even on return redirect',
    () async {
      final seen = <String?>[];
      late HttpServer first;
      late HttpServer second;
      first = await serve((request) async {
        seen.add(request.headers.value(HttpHeaders.authorizationHeader));
        if (request.uri.path == '/list') {
          request.response.statusCode = HttpStatus.found;
          request.response.headers.set(HttpHeaders.locationHeader, url(second));
        } else {
          request.response.write('ok');
        }
        await request.response.close();
      });
      second = await serve((request) async {
        seen.add(request.headers.value(HttpHeaders.authorizationHeader));
        request.response.statusCode = HttpStatus.temporaryRedirect;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          url(first, '/final'),
        );
        await request.response.close();
      });
      expect(
        await downloadSteamSubscription(
          url(first).replace(userInfo: 'reader:password'),
        ),
        'ok',
      );
      expect(seen.length, 3);
      expect(seen.first, isNotNull);
      expect(seen.skip(1), everyElement(isNull));
    },
  );

  test('redirects cannot introduce credentials', () async {
    var hits = 0;
    late HttpServer server;
    server = await serve((request) async {
      hits++;
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(
        HttpHeaders.locationHeader,
        url(server, '/final').replace(userInfo: 'injected:synthetic-token'),
      );
      await request.response.close();
    });
    await expectLater(
      downloadSteamSubscription(url(server)),
      throwsA(failed(SteamSubscriptionDownloadFailure.unsafeRedirect)),
    );
    expect(hits, 1);
  });

  test('redirect loops stop after four redirects', () async {
    var hits = 0;
    final server = await serve((request) async {
      hits++;
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(HttpHeaders.locationHeader, '/list');
      await request.response.close();
    });
    await expectLater(
      downloadSteamSubscription(url(server)),
      throwsA(failed(SteamSubscriptionDownloadFailure.tooManyRedirects)),
    );
    expect(hits, 5);
  });

  test('four redirects may resolve successfully', () async {
    var hits = 0;
    final server = await serve((request) async {
      hits++;
      if (hits <= 4) {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(HttpHeaders.locationHeader, '/list');
      } else {
        request.response.write('ok');
      }
      await request.response.close();
    });
    expect(await downloadSteamSubscription(url(server)), 'ok');
    expect(hits, 5);
  });

  test('HTTPS custom ports retain normal certificate verification', () async {
    final server = await serve((request) async {
      expect(request.uri.queryParameters['token'], 'synthetic-token');
      request.response.write('ok');
      await request.response.close();
    }, tls: true);
    final endpoint = url(server).replace(
      scheme: 'https',
      host: 'localhost',
      query: 'token=synthetic-token',
    );
    expect(
      await downloadSteamSubscription(endpoint, createClient: trustedClient),
      'ok',
    );
    await expectLater(
      downloadSteamSubscription(endpoint),
      throwsA(failed(SteamSubscriptionDownloadFailure.network)),
    );
  });

  test('HTTPS redirect cannot downgrade to HTTP', () async {
    var plainHits = 0;
    final plain = await serve((request) async {
      plainHits++;
      await request.response.close();
    });
    final secure = await serve((request) async {
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(HttpHeaders.locationHeader, url(plain));
      await request.response.close();
    }, tls: true);
    await expectLater(
      downloadSteamSubscription(
        url(secure).replace(
          scheme: 'https',
          host: 'localhost',
          userInfo: 'reader:password',
        ),
        createClient: trustedClient,
      ),
      throwsA(failed(SteamSubscriptionDownloadFailure.unsafeRedirect)),
    );
    expect(plainHits, 0);
  });

  test('known-size response is bounded before reading', () async {
    final server = await serve((request) async {
      request.response.contentLength = 2048;
      request.response.add(List.filled(2048, 120));
      await request.response.close();
    });
    await expectLater(
      downloadSteamSubscription(url(server), maxBytes: 64),
      throwsA(failed(SteamSubscriptionDownloadFailure.tooLarge)),
    );
  });

  test('chunked responses are bounded and cancelled mid-stream', () async {
    final stream = await stalledStream('x' * 256);
    await expectLater(
      downloadSteamSubscription(stream.uri, maxBytes: 64),
      throwsA(failed(SteamSubscriptionDownloadFailure.tooLarge)),
    );
    await stream.disconnected.timeout(const Duration(seconds: 2));
  });

  test('decompressed response bytes are bounded', () async {
    final compressed = gzip.encode(List.filled(4096, 120));
    expect(compressed.length, lessThan(128));
    final server = await serve((request) async {
      request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      request.response.contentLength = compressed.length;
      request.response.add(compressed);
      await request.response.close();
    });
    await expectLater(
      downloadSteamSubscription(url(server), maxBytes: 128),
      throwsA(failed(SteamSubscriptionDownloadFailure.tooLarge)),
    );
  });

  test('one deadline also cancels stalled response streams', () async {
    final stream = await stalledStream('first');
    await expectLater(
      downloadSteamSubscription(
        stream.uri,
        timeout: const Duration(milliseconds: 150),
      ),
      throwsA(failed(SteamSubscriptionDownloadFailure.timeout)),
    );
    await stream.disconnected.timeout(const Duration(seconds: 2));
  });

  test('one deadline bounds a server that sends no response headers', () async {
    await expectLater(
      downloadSteamSubscription(
        url(await serve((_) {})),
        timeout: const Duration(milliseconds: 150),
      ),
      throwsA(failed(SteamSubscriptionDownloadFailure.timeout)),
    );
  });

  test('HTTP error details, query and credentials never escape', () async {
    final server = await serve((request) async {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.write('Server failure for synthetic-token');
      await request.response.close();
    });
    await expectLater(
      downloadSteamSubscription(
        url(server).replace(
          userInfo: 'reader:synthetic-password',
          query: 'token=synthetic-token',
        ),
      ),
      throwsA(
        failed(SteamSubscriptionDownloadFailure.invalidResponse).having(
          (error) => error.toString(),
          'diagnostic',
          allOf(isNot(contains('synthetic')), isNot(contains('127.0.0.1'))),
        ),
      ),
    );
  });

  test('invalid UTF-8 is a sanitized response error', () async {
    final server = await serve((request) async {
      request.response.add([0xff, 0xfe]);
      await request.response.close();
    });
    await expectLater(
      downloadSteamSubscription(url(server)),
      throwsA(failed(SteamSubscriptionDownloadFailure.invalidResponse)),
    );
  });
}
