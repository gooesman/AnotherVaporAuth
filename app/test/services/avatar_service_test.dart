import 'dart:async';
import 'dart:typed_data';

import 'package:ava/src/services/avatar_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(Future<void>? cancel) respond;
  _Adapter(this.respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(cancelFuture);

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final equipped in [false, true]) {
    test(
      '${equipped ? 'equipped items' : 'profile'} timeout cancels transfer',
      () async {
        final cancelled = Completer<void>();
        final response = Completer<ResponseBody>();
        final dio = Dio()
          ..httpClientAdapter = _Adapter((cancel) {
            cancel!.then((_) => cancelled.complete());
            return response.future;
          });
        addTearDown(() => dio.close(force: true));
        final service = AvatarService(
          dio: dio,
          requestTimeout: const Duration(milliseconds: 50),
        );

        if (equipped) {
          final result = await service.fetchEquippedItems(123, 'test-token');
          expect(result.frameUrl, isNull);
          expect(result.animatedAvatarUrl, isNull);
        } else {
          final result = await service.fetchProfile(123);
          expect(result.personaName, isNull);
          expect(result.avatarUrl, isNull);
        }
        await cancelled.future.timeout(const Duration(seconds: 1));
        // A late server response cannot turn the completed timeout into success.
        response.complete(ResponseBody.fromString('{}', 200));
        await Future<void>.delayed(Duration.zero);
      },
    );
  }

  test(
    'only an explicit unauthorized response requests session refresh',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _Adapter(
          (_) async => ResponseBody.fromString('', 401),
        );
      addTearDown(() => dio.close(force: true));
      final service = AvatarService(dio: dio);
      await expectLater(
        service.fetchEquippedItems(123, 'test-token'),
        throwsA(isA<FrameUnauthorized>()),
      );
    },
  );
}
