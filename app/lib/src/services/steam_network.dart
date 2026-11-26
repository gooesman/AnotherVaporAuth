import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// This connection failed before a socket was returned for Steam HTTP bytes.
/// It is not proof about earlier redirects/retries of the same logical action.
/// Callers classifying a write as unsent must disable both of those behaviors.
class SteamConnectionSetupException implements Exception {
  const SteamConnectionSetupException([this.cause]);
  final Object? cause;
  @override
  String toString() => 'Steam connection could not be established';
}

/// A transport-only proxy. Credentials must never be copied into Steam headers
/// or exposed through logging/UI state.
class SteamNetworkProxy {
  SteamNetworkProxy({
    required this.host,
    required this.port,
    this.username,
    this.password,
  }) {
    if (host.isEmpty ||
        host.length > 253 ||
        !RegExp(r'^[a-zA-Z0-9.:-]+$').hasMatch(host) ||
        port < 1 ||
        port > 65535 ||
        ((username == null) != (password == null))) {
      throw ArgumentError('Invalid Steam proxy configuration');
    }
  }

  final String host;
  final int port;
  final String? username;
  final String? password;

  String get directive =>
      'PROXY ${host.contains(':') ? '[$host]' : host}:$port';

  @override
  bool operator ==(Object other) =>
      other is SteamNetworkProxy &&
      other.host == host &&
      other.port == port &&
      other.username == username &&
      other.password == password;

  @override
  int get hashCode => Object.hash(host, port, username, password);

  @override
  String toString() => 'SteamNetworkProxy(configured)';
}

/// Steam clients have their own routing scope. The update client reuses only
/// the low-level scoped CONNECT transport, never Steam sessions or headers.
class SteamNetwork {
  static SteamNetworkProxy? Function() _proxy = () => null;
  static Future<bool>? _readiness;
  static Object? Function()? _routeIdentity;

  static void configureProxy(
    SteamNetworkProxy? Function() proxy, {
    Future<void>? readiness,
    Object? Function()? routeIdentity,
  }) {
    _proxy = proxy;
    _routeIdentity = routeIdentity;
    // Dio runs interceptors in a child error zone. An error from a Future
    // created outside that zone cannot cross into its try/catch; the request
    // would hang and report an uncaught startup error. Normalize it here, in
    // the caller's zone, into a value with no credentials/diagnostic payload.
    _readiness = readiness?.then(
      (_) => true,
      onError: (Object _, StackTrace _) => false,
    );
  }

  static bool isSteamRequest(Uri uri) {
    if (uri.scheme != 'https' || uri.port != 443 || uri.userInfo.isNotEmpty) {
      return false;
    }
    return _isSteamHost(uri.host);
  }

  static bool _isSteamHost(String value) {
    var host = value.toLowerCase();
    if (host.endsWith('.')) host = host.substring(0, host.length - 1);
    return const [
          'steampowered.com',
          'steamcommunity.com',
          'steamstatic.com',
        ].any((domain) => host == domain || host.endsWith('.$domain')) ||
        host == 'steamcdn-a.akamaihd.net';
  }

  static Dio createDio(
    BaseOptions options, {
    SecurityContext? securityContext,
    Future<ConnectionTask<Socket>> Function(String host, int port)?
    socketConnector,
  }) => createScopedDio(
    options,
    proxy: () => _proxy(),
    routeIdentity: () => _routeIdentity?.call(),
    isAllowedRequest: isSteamRequest,
    readiness: () => _readiness,
    securityContext: securityContext,
    socketConnector: socketConnector,
  );

  /// Creates an independent client for an explicit set of HTTPS destinations.
  /// No cookies, credentials or headers are shared with any existing client.
  static Dio createScopedDio(
    BaseOptions options, {
    required SteamNetworkProxy? Function() proxy,
    required bool Function(Uri) isAllowedRequest,
    Future<bool>? Function()? readiness,
    Object? Function()? routeIdentity,
    SecurityContext? securityContext,
    Future<ConnectionTask<Socket>> Function(String host, int port)?
    socketConnector,
  }) {
    final dio = Dio(options);
    var active = proxy();
    var activeRoute = routeIdentity?.call();
    IOHttpClientAdapter adapter(SteamNetworkProxy? proxy) =>
        IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient(context: securityContext);
            // Own the CONNECT handshake: Dart's native proxy credentials can
            // also be added to requests *inside* the TLS tunnel. Never put
            // credentials in HttpClient's header/credential stores.
            client.findProxy = (_) => 'DIRECT';
            client.connectionFactory = (uri, _, _) => _connect(
              uri,
              isAllowedRequest(uri) ? proxy : null,
              securityContext,
              socketConnector ??
                  ((host, port) => Socket.startConnect(host, port)),
            );
            return client;
          },
        );
    dio.httpClientAdapter = adapter(active);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (isAllowedRequest(options.uri) &&
              await readiness?.call() == false) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'Network initialization failed',
                error: isSteamRequest(options.uri)
                    ? const SteamConnectionSetupException()
                    : const SocketException('Network initialization failed'),
              ),
            );
            return;
          }
          final current = proxy();
          final currentRoute = routeIdentity?.call();
          if (current != active || currentRoute != activeRoute) {
            final old = dio.httpClientAdapter;
            dio.httpClientAdapter = adapter(current);
            active = current;
            activeRoute = currentRoute;
            // New requests adopt the new route. Let already-started requests finish
            // without silently replaying trades, SMS requests or other writes.
            old.close(force: false);
          }
          handler.next(options);
        },
      ),
    );
    return dio;
  }

  static Future<ConnectionTask<Socket>> _connect(
    Uri uri,
    SteamNetworkProxy? proxy,
    SecurityContext? context,
    Future<ConnectionTask<Socket>> Function(String, int) connect,
  ) async {
    final ConnectionTask<Socket> task;
    try {
      task = await connect(proxy?.host ?? uri.host, proxy?.port ?? uri.port);
    } catch (error) {
      if (isSteamRequest(uri)) throw SteamConnectionSetupException(error);
      rethrow;
    }
    Socket? socket;
    var cancelled = false;
    final ready = () async {
      try {
        socket = await task.socket;
        if (cancelled) throw const SocketException('Connection cancelled');
        if (proxy != null) await _openTunnel(socket!, uri, proxy);
        if (uri.scheme == 'https') {
          // connectionFactory owns TLS too. Keep the original hostname for
          // SNI and certificate checks; no bad-certificate bypass is installed.
          socket = await SecureSocket.secure(
            socket!,
            host: uri.host,
            context: context,
          );
        }
        if (cancelled) throw const SocketException('Connection cancelled');
        return socket!;
      } catch (error) {
        socket?.destroy();
        if (isSteamRequest(uri)) throw SteamConnectionSetupException(error);
        rethrow;
      }
    }();
    return ConnectionTask.fromSocket(ready, () {
      cancelled = true;
      task.cancel();
      socket?.destroy();
    });
  }

  static Future<void> _openTunnel(
    Socket socket,
    Uri uri,
    SteamNetworkProxy proxy,
  ) async {
    final complete = Completer<void>();
    final bytes = <int>[];
    late StreamSubscription<List<int>> subscription;
    void fail() {
      if (!complete.isCompleted) {
        complete.completeError(
          const HttpException('Steam proxy connection failed'),
        );
      }
    }

    subscription = socket.listen(
      (chunk) {
        if (complete.isCompleted) return;
        bytes.addAll(chunk);
        if (bytes.length > 16384) {
          fail();
          return;
        }
        final response = latin1.decode(bytes);
        final end = response.indexOf('\r\n\r\n');
        if (end < 0) return;
        // A TLS server cannot send handshake data before our ClientHello. Reject
        // unexpected bytes instead of discarding data at the protocol boundary.
        if (end + 4 != bytes.length ||
            !RegExp(r'^HTTP/1\.[01] 200(?: |\r\n)').hasMatch(response)) {
          fail();
          return;
        }
        subscription.pause();
        complete.complete();
      },
      onError: (Object _) => fail(),
      onDone: fail,
    );
    final authority = '${uri.host}:443';
    final authorization = proxy.username == null
        ? ''
        : 'Proxy-Authorization: Basic ${base64Encode(utf8.encode('${proxy.username}:${proxy.password}'))}\r\n';
    socket.write(
      'CONNECT $authority HTTP/1.1\r\nHost: $authority\r\n$authorization\r\n',
    );
    try {
      await socket.flush();
      await complete.future.timeout(const Duration(seconds: 15));
      // SecureSocket.secure takes over the paused socket subscription.
    } catch (_) {
      socket.destroy();
      await subscription.cancel();
      rethrow;
    }
  }
}
