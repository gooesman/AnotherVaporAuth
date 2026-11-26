import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'steam_acceleration_types.dart';

/// Shared by subscription settings and persistence. Subscription links may use
/// HTTP, HTTPS, a custom port, and percent-encoded HTTP Basic credentials. These
/// allowances deliberately do not apply to executable/core downloads.
Uri validateSteamSubscriptionUrl(String text) {
  try {
    final value = text.trim();
    final uri = Uri.tryParse(value);
    if (value.length > 4096 ||
        value.contains(RegExp(r'[\x00-\x20\x7f]')) ||
        RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(value) ||
        uri == null ||
        !uri.hasAuthority ||
        !const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw const FormatException();
    }
    if (uri.userInfo.isNotEmpty) _basicAuthorization(uri.userInfo);
    return uri;
  } catch (_) {
    // Uri and decoder exceptions can contain the original URL or password.
    throw const SteamAccelerationException(
      SteamAccelerationError.invalidSubscription,
    );
  }
}

enum SteamSubscriptionDownloadFailure {
  network,
  timeout,
  invalidResponse,
  tooLarge,
  tooManyRedirects,
  unsafeRedirect,
}

/// Carries a bounded reason only, never an endpoint, header, response or cause.
class SteamSubscriptionDownloadException extends SteamAccelerationException {
  const SteamSubscriptionDownloadException(this.reason)
    : super(SteamAccelerationError.network);

  final SteamSubscriptionDownloadFailure reason;

  @override
  String toString() => 'SteamSubscriptionDownloadException(${reason.name})';
}

String _basicAuthorization(String userInfo) {
  final separator = userInfo.indexOf(':');
  final username = Uri.decodeComponent(
    separator < 0 ? userInfo : userInfo.substring(0, separator),
  );
  final password = separator < 0
      ? ''
      : Uri.decodeComponent(userInfo.substring(separator + 1));
  if (username.isEmpty ||
      username.contains(':') ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch('$username$password')) {
    throw const FormatException();
  }
  return 'Basic ${base64.encode(utf8.encode('$username:$password'))}';
}

bool _sameOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme && a.host == b.host && a.port == b.port;

/// Direct, app-local subscription fetch. The normal client retains platform TLS
/// certificate verification. The factory exists for isolated loopback tests.
///
/// Authorization is taken out of the request URI, retained only on same-origin
/// redirects, and permanently dropped after an origin change. Redirects cannot
/// introduce credentials or downgrade HTTPS. No ambient cookies are shared.
Future<String> downloadSteamSubscription(
  Uri uri, {
  int maxBytes = 2 * 1024 * 1024,
  Duration timeout = const Duration(seconds: 40),
  HttpClient Function()? createClient,
}) async {
  final validated = validateSteamSubscriptionUrl(uri.toString());
  if (maxBytes <= 0 || timeout <= Duration.zero) {
    throw const SteamSubscriptionDownloadException(
      SteamSubscriptionDownloadFailure.invalidResponse,
    );
  }

  HttpClient? client;
  HttpClientRequest? activeRequest;
  StreamIterator<List<int>>? activeBody;
  var cancelled = false;
  try {
    final http = client = createClient?.call() ?? HttpClient();
    http.connectionTimeout = const Duration(seconds: 15);
    http.findProxy = (_) => 'DIRECT';
    // Some subscription providers select Clash YAML using this exact UA.
    http.userAgent = 'clash.meta';
    var target = validated.replace(userInfo: '');
    String? authorization = validated.userInfo.isEmpty
        ? null
        : _basicAuthorization(validated.userInfo);

    Future<String> receive() async {
      for (var redirects = 0; redirects <= 4; redirects++) {
        if (cancelled) {
          throw const SteamSubscriptionDownloadException(
            SteamSubscriptionDownloadFailure.timeout,
          );
        }
        final request = activeRequest = await http.getUrl(target);
        if (cancelled) {
          request.abort();
          throw const SteamSubscriptionDownloadException(
            SteamSubscriptionDownloadFailure.timeout,
          );
        }
        request.followRedirects = false;
        if (authorization != null) {
          request.headers.set(HttpHeaders.authorizationHeader, authorization!);
        }
        final response = await request.close();
        if (const [301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          // Cancel rather than drain an untrusted, possibly unbounded body.
          await response.listen(null).cancel();
          if (redirects == 4) {
            throw const SteamSubscriptionDownloadException(
              SteamSubscriptionDownloadFailure.tooManyRedirects,
            );
          }
          if (location == null) {
            throw const SteamSubscriptionDownloadException(
              SteamSubscriptionDownloadFailure.invalidResponse,
            );
          }
          Uri next;
          try {
            next = validateSteamSubscriptionUrl(
              target.resolve(location).toString(),
            );
          } catch (_) {
            throw const SteamSubscriptionDownloadException(
              SteamSubscriptionDownloadFailure.unsafeRedirect,
            );
          }
          if (next.userInfo.isNotEmpty ||
              target.scheme == 'https' && next.scheme != 'https') {
            throw const SteamSubscriptionDownloadException(
              SteamSubscriptionDownloadFailure.unsafeRedirect,
            );
          }
          if (!_sameOrigin(target, next)) authorization = null;
          target = next;
          continue;
        }
        if (response.statusCode != HttpStatus.ok) {
          await response.listen(null).cancel();
          throw const SteamSubscriptionDownloadException(
            SteamSubscriptionDownloadFailure.invalidResponse,
          );
        }
        if (response.contentLength > maxBytes) {
          await response.listen(null).cancel();
          throw const SteamSubscriptionDownloadException(
            SteamSubscriptionDownloadFailure.tooLarge,
          );
        }
        final bytes = BytesBuilder(copy: false);
        final body = activeBody = StreamIterator(response);
        try {
          while (await body.moveNext()) {
            if (bytes.length + body.current.length > maxBytes) {
              throw const SteamSubscriptionDownloadException(
                SteamSubscriptionDownloadFailure.tooLarge,
              );
            }
            bytes.add(body.current);
          }
        } finally {
          await body.cancel();
          activeBody = null;
        }
        try {
          return utf8.decode(bytes.takeBytes());
        } on FormatException {
          throw const SteamSubscriptionDownloadException(
            SteamSubscriptionDownloadFailure.invalidResponse,
          );
        }
      }
      throw const SteamSubscriptionDownloadException(
        SteamSubscriptionDownloadFailure.tooManyRedirects,
      );
    }

    return await receive().timeout(
      timeout,
      onTimeout: () {
        cancelled = true;
        activeRequest?.abort();
        unawaited(activeBody?.cancel());
        http.close(force: true);
        throw const SteamSubscriptionDownloadException(
          SteamSubscriptionDownloadFailure.timeout,
        );
      },
    );
  } on SteamSubscriptionDownloadException {
    rethrow;
  } catch (_) {
    throw const SteamSubscriptionDownloadException(
      SteamSubscriptionDownloadFailure.network,
    );
  } finally {
    cancelled = true;
    client?.close(force: true);
  }
}
