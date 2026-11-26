import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/src/core/backup_codes.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/backup_codes_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _steamId = 76561198000000001;

SteamGuardAccount _account({
  int steamId = _steamId,
  String? token = 'access-only',
}) => SteamGuardAccount(
  revocationCode: 'NEVER-SEND-RECOVERY',
  sharedSecret: 'NEVER-SEND-SHARED',
  identitySecret: 'NEVER-SEND-IDENTITY',
  password: 'NEVER-SEND-PASSWORD',
  session: SessionData(
    steamId: steamId,
    accessToken: token,
    refreshToken: 'NEVER-SEND-REFRESH',
  ),
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.answer);
  final FutureOr<ResponseBody> Function(RequestOptions) answer;
  final requests = <RequestOptions>[];
  final wireBodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final chunks = await requestStream?.toList();
    wireBodies.add(
      chunks == null
          ? ''
          : utf8.decode(chunks.expand((chunk) => chunk).toList()),
    );
    return answer(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int status = 200, int? eresult}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        if (eresult != null) 'x-eresult': ['$eresult'],
      },
    );

BackupCodesService _service(_Adapter adapter) =>
    BackupCodesService(dio: Dio()..httpClientAdapter = adapter);

Matcher _error(BackupCodesError code) =>
    isA<BackupCodesException>().having((error) => error.code, 'code', code);

void main() {
  test(
    'known two-stage form protocol sends only access token then SMS',
    () async {
      final adapter = _Adapter((request) {
        final form = request.data as Map<String, dynamic>;
        return form.containsKey('code')
            ? _json({
                'response': {
                  'codes': ['01234567', 'ABCD5678'],
                },
              })
            : _json({
                'response': {'status': 1},
              });
      });
      final service = _service(adapter);
      final account = _account();
      final before = jsonEncode(account.toJson());
      expect(adapter.requests, isEmpty);
      final challenge = await service.requestSms(account);
      expect(challenge.steamId, _steamId);
      expect(challenge.phoneHint, isNull);
      final codes = await service.generate(account, challenge, ' 00123 ');
      expect(codes, ['01234567', 'ABCD5678']);
      expect(jsonEncode(account.toJson()), before);
      expect(adapter.requests, hasLength(2));
      for (final request in adapter.requests) {
        expect(request.uri.toString(), BackupCodesService.endpoint);
        expect(request.uri.query, isEmpty);
        expect(request.method, 'POST');
        expect(request.followRedirects, isFalse);
        expect(request.contentType, Headers.formUrlEncodedContentType);
        expect(request.data.toString(), isNot(contains('NEVER-SEND')));
      }
      expect(Uri.splitQueryString(adapter.wireBodies.first), {
        'access_token': 'access-only',
      });
      expect(Uri.splitQueryString(adapter.wireBodies.last), {
        'access_token': 'access-only',
        'code': '00123',
      });
    },
  );

  test(
    'first step needs an explicit acknowledgement, not any JSON object',
    () async {
      for (final body in [
        {'response': {}},
        {
          'response': {'message': 'unrecognized'},
        },
        {},
        [],
        {
          'response': {
            'codes': ['01234567'],
          },
        },
        {
          'response': {'status': 'unrecognized'},
        },
      ]) {
        final adapter = _Adapter((_) => _json(body));
        await expectLater(
          _service(adapter).requestSms(_account()),
          throwsA(_error(BackupCodesError.invalidResponse)),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'explicit OK header can acknowledge a valid empty response envelope',
    () async {
      final service = _service(
        _Adapter((_) => _json({'response': {}}, eresult: 1)),
      );
      expect((await service.requestSms(_account())).steamId, _steamId);
    },
  );

  test('OK header never masks status failure or success false', () async {
    for (final body in [
      {
        'response': {'status': 2},
      },
      {
        'response': {'success': false},
      },
      {
        'error': 'secret diagnostic',
        'response': {'status': 1},
      },
      {
        'response': {
          'codes': ['01234567'],
          'success': false,
        },
      },
    ]) {
      final adapter = _Adapter((_) => _json(body, eresult: 1));
      await expectLater(
        _service(adapter).requestSms(_account()),
        throwsA(_error(BackupCodesError.rejected)),
      );
      expect(adapter.requests, hasLength(1));
    }
  });

  test(
    'auth, wrong SMS, phone and throttling errors remain distinct, no retries',
    () async {
      for (final pair in <(int, BackupCodesError)>[
        (21, BackupCodesError.authenticationRequired),
        (65, BackupCodesError.invalidCode),
        (94, BackupCodesError.invalidCode),
        (84, BackupCodesError.rateLimited),
        (123, BackupCodesError.phoneRequired),
      ]) {
        final adapter = _Adapter(
          (_) => _json({
            'response': {'status': pair.$1},
          }),
        );
        await expectLater(
          _service(adapter).requestSms(_account()),
          throwsA(_error(pair.$2)),
        );
        expect(adapter.requests, hasLength(1));
      }
      for (final pair in <(int, BackupCodesError)>[
        (401, BackupCodesError.authenticationRequired),
        (403, BackupCodesError.authenticationRequired),
        (429, BackupCodesError.rateLimited),
        (302, BackupCodesError.rejected),
        (500, BackupCodesError.rejected),
      ]) {
        final adapter = _Adapter(
          (_) => _json({
            'response': {'status': 1},
          }, status: pair.$1),
        );
        await expectLater(
          _service(adapter).requestSms(_account()),
          throwsA(_error(pair.$2)),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test('second step requires a nonempty valid string code list', () async {
    for (final body in [
      {'response': {}},
      {
        'response': {'status': 1},
      },
      {
        'response': {'codes': []},
      },
      {
        'response': {
          'codes': [12345678],
        },
      },
      {
        'response': {
          'codes': [''],
        },
      },
      {
        'response': {
          'codes': ['<html>not codes</html>'],
        },
      },
      {
        'response': {
          'codes': ['12345678', '12345678'],
        },
      },
      {
        'response': {
          'codes': ['1234\n5678'],
        },
      },
    ]) {
      await expectLater(
        _service(_Adapter((_) => _json(body))).generate(
          _account(),
          const BackupCodesChallenge(steamId: _steamId),
          '12345',
        ),
        throwsA(_error(BackupCodesError.invalidResponse)),
      );
    }
  });

  test(
    'missing token, account mismatch and wrong JWT subject make no requests',
    () async {
      final adapter = _Adapter(
        (_) => _json({
          'response': {'status': 1},
        }),
      );
      final service = _service(adapter);
      await expectLater(
        service.requestSms(_account(token: null)),
        throwsA(_error(BackupCodesError.authenticationRequired)),
      );
      await expectLater(
        service.generate(
          _account(),
          const BackupCodesChallenge(steamId: 76561198000000002),
          '12345',
        ),
        throwsA(_error(BackupCodesError.authenticationRequired)),
      );
      final jwt =
          'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': '76561198000000002'})))}.signature';
      await expectLater(
        service.requestSms(_account(token: jwt)),
        throwsA(_error(BackupCodesError.authenticationRequired)),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'account changed during request cannot receive another account challenge',
    () async {
      final reply = Completer<ResponseBody>();
      final account = _account();
      final adapter = _Adapter((_) => reply.future);
      final request = _service(adapter).requestSms(account);
      await Future<void>.delayed(Duration.zero);
      account.session.steamId++;
      reply.complete(
        _json({
          'response': {'status': 1},
        }),
      );
      await expectLater(
        request,
        throwsA(_error(BackupCodesError.authenticationRequired)),
      );
    },
  );

  test('invalid SMS is rejected locally without submitting', () async {
    final adapter = _Adapter(
      (_) => _json({
        'response': {
          'codes': ['01234567'],
        },
      }),
    );
    for (final code in ['', '   ', '12 34', 'a' * 65, '123\n456']) {
      await expectLater(
        _service(adapter).generate(
          _account(),
          const BackupCodesChallenge(steamId: _steamId),
          code,
        ),
        throwsA(_error(BackupCodesError.invalidCode)),
      );
    }
    expect(adapter.requests, isEmpty);
  });

  test(
    'network error drops raw request and response, including SMS and token',
    () async {
      final adapter = _Adapter(
        (request) => throw DioException(
          requestOptions: request,
          type: DioExceptionType.receiveTimeout,
          message: 'access-only 00123 DO-NOT-EXPOSE',
        ),
      );
      try {
        await _service(adapter).generate(
          _account(),
          const BackupCodesChallenge(steamId: _steamId),
          '00123',
        );
        fail('Expected a sanitized failure');
      } on BackupCodesException catch (error) {
        expect(error.code, BackupCodesError.network);
        expect(error.toString(), 'BackupCodesException(network)');
      }
      expect(adapter.requests, hasLength(1));
    },
  );

  test('cancellation is typed and does not retry', () async {
    final adapter = _Adapter(
      (request) => throw DioException(
        requestOptions: request,
        type: DioExceptionType.cancel,
      ),
    );
    await expectLater(
      _service(adapter).requestSms(_account()),
      throwsA(_error(BackupCodesError.cancelled)),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('only an already masked bounded phone hint can be displayed', () async {
    for (final pair in <(Object?, String?)>[
      ('+** *** **1234', '+** *** **1234'),
      ('+8613800000000', null),
      ('<img src=x onerror=alert(1)>', null),
      ('*' * 1000, null),
      (1234, null),
    ]) {
      final service = _service(
        _Adapter(
          (_) => _json({
            'response': {'status': 1, 'phone_number_hint': pair.$1},
          }),
        ),
      );
      expect((await service.requestSms(_account())).phoneHint, pair.$2);
    }
  });
}
