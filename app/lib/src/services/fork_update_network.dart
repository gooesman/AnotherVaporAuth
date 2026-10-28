import 'dart:io';

import 'package:dio/dio.dart';

import '../core/fork_update.dart';
import 'steam_network.dart';

/// A separate, unauthenticated client for this fork's official GitHub updater.
/// Routing may reuse an existing local proxy; it never starts one or shares a
/// Steam client, cookie, authorization header or subscription URL.
class ForkUpdateNetwork {
  static SteamNetworkProxy? Function() _proxy = () => null;
  static Future<bool>? _readiness;
  static Object? Function()? _routeIdentity;

  static const _mirrorHosts = {
    ForkUpdateDownloadSource.axisNow: 'axisnow.gh-proxy.org',
    ForkUpdateDownloadSource.v4: 'v4.gh-proxy.org',
  };

  /// Only a validated public asset in this fork may be wrapped in a mirror
  /// URL. The official URL and SHA256 stay unchanged in release metadata.
  static Uri mirrorAssetUrl(ForkUpdateDownloadSource source, Uri official) {
    final host = _mirrorHosts[source];
    if (host == null ||
        official.host != 'github.com' ||
        !isOfficialRequest(official)) {
      throw ArgumentError('Unsupported update download route');
    }
    final path = official.pathSegments.map(Uri.encodeComponent).join('/');
    return Uri.parse('https://$host/https://github.com/$path');
  }

  static bool isMirrorRequest(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery ||
        !_mirrorHosts.values.contains(uri.host)) {
      return false;
    }
    final parts = uri.pathSegments;
    if (parts.length != 9 ||
        parts[0] != 'https:' ||
        parts[1].isNotEmpty ||
        parts[2] != 'github.com') {
      return false;
    }
    return isOfficialRequest(
      Uri(scheme: 'https', host: 'github.com', pathSegments: parts.skip(3)),
    );
  }

  /// Mirrors always connect directly. This client never reads the configured
  /// Steam proxy or its readiness future and has no shared headers or cookies.
  static Dio createMirrorDio({
    SecurityContext? securityContext,
    Future<ConnectionTask<Socket>> Function(String host, int port)?
    socketConnector,
  }) => SteamNetwork.createScopedDio(
    BaseOptions(),
    proxy: () => null,
    isAllowedRequest: isMirrorRequest,
    securityContext: securityContext,
    socketConnector: socketConnector,
  );

  static void configureProxy(
    SteamNetworkProxy? Function() proxy, {
    Future<void>? readiness,
    Object? Function()? routeIdentity,
  }) {
    _proxy = proxy;
    _routeIdentity = routeIdentity;
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
    routeIdentity: () => _routeIdentity?.call(),
    isAllowedRequest: isOfficialRequest,
    readiness: () => _readiness,
    securityContext: securityContext,
    socketConnector: socketConnector,
  );
}
