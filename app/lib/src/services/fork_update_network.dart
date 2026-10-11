import 'dart:io';

import 'package:dio/dio.dart';

import 'steam_network.dart';

/// A separate, unauthenticated client for this fork's official GitHub updater.
/// Routing may reuse an existing local proxy; it never starts one or shares a
/// Steam client, cookie, authorization header or subscription URL.
class ForkUpdateNetwork {
  static SteamNetworkProxy? Function() _proxy = () => null;
  static Future<bool>? _readiness;

  static void configureProxy(
    SteamNetworkProxy? Function() proxy, {
    Future<void>? readiness,
  }) {
    _proxy = proxy;
    // Normalize in the caller's zone, as with the Steam transport.
    _readiness = readiness?.then(
      (_) => true,
      onError: (Object _, StackTrace _) => false,
    );
  }

  static bool isOfficialRequest(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return false;
    }
    if (const {
      'release-assets.githubusercontent.com',
      'objects.githubusercontent.com',
      'objects-origin.githubusercontent.com',
      'github-releases.githubusercontent.com',
    }.contains(uri.host)) {
      return true;
    }
    if (uri.hasQuery) return false;
    final parts = uri.pathSegments;
    if (uri.host == 'api.github.com') {
      return parts.length == 5 &&
          parts[0] == 'repos' &&
          parts[1] == 'gooesman' &&
          parts[2] == 'AnotherVaporAuth' &&
          parts[3] == 'releases' &&
          parts[4] == 'latest';
    }
    return uri.host == 'github.com' &&
        parts.length == 6 &&
        parts[0] == 'gooesman' &&
        parts[1] == 'AnotherVaporAuth' &&
        parts[2] == 'releases' &&
        parts[3] == 'download' &&
        parts[4].isNotEmpty &&
        parts[5].isNotEmpty;
  }

  static Dio createDio({
    BaseOptions? options,
    SecurityContext? securityContext,
    Future<ConnectionTask<Socket>> Function(String host, int port)?
    socketConnector,
  }) => SteamNetwork.createScopedDio(
    options ?? BaseOptions(),
    proxy: () => _proxy(),
    isAllowedRequest: isOfficialRequest,
    readiness: () => _readiness,
    securityContext: securityContext,
    socketConnector: socketConnector,
  );
}
