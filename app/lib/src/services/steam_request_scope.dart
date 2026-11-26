import 'dart:async';

import 'package:dio/dio.dart';

/// An explicit read operation's lifetime, including redirects and pagination.
/// Existing callers have no scope, so their transport behavior is unchanged.
class SteamRequestScope {
  SteamRequestScope({this.timeout = const Duration(seconds: 12)});

  final Duration timeout;
  final CancelToken _cancel = CancelToken();
  static final _zoneKey = Object();

  static CancelToken? get currentCancelToken =>
      (Zone.current[_zoneKey] as SteamRequestScope?)?._cancel;

  Future<T> run<T>(Future<T> Function() operation) async {
    if (_cancel.isCancelled) throw _cancel.cancelError!;
    return Future.any<T>([
      runZoned(operation, zoneValues: {_zoneKey: this}),
      _cancel.whenCancel.then<T>((error) => throw error),
    ]).timeout(
      timeout,
      onTimeout: () {
        cancel();
        throw TimeoutException('Steam read timed out', timeout);
      },
    );
  }

  void cancel() => _cancel.cancel('Steam read is no longer needed');
}
