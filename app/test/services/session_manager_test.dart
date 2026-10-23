import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/session_manager.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends SteamApiClient {
  _Api(this.answer);
  final Future<ProtoReader> Function(ProtoWriter) answer;
  int exchanges = 0;

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    expect(iface, 'IAuthenticationService');
    expect(method, 'GenerateAccessTokenForApp');
    exchanges++;
    return answer(request);
  }
}

SessionData _session() => SessionData(
  steamId: 76561198000000001,
  accessToken: 'synthetic-access',
  refreshToken: 'synthetic-refresh',
);

void main() {
  test(
    'successful exchange rotates both tokens and encodes account identity',
    () async {
      final session = _session();
      final api = _Api((request) async {
        final fields = ProtoReader(request.toBytes()).parse();
        expect(fields[1]?.asString, 'synthetic-refresh');
        expect(fields[2]?.asFixed64, session.steamId);
        return ProtoReader(
          (ProtoWriter()
                ..writeString(1, 'replacement-access')
                ..writeString(2, 'replacement-refresh'))
              .toBytes(),
        );
      });
      expect(
        await SessionManager(api).refreshResult(session),
        SessionRefreshOutcome.refreshed,
      );
      expect(session.accessToken, 'replacement-access');
      expect(session.refreshToken, 'replacement-refresh');
    },
  );

  test(
    'bool refresh remains compatible and keeps unrotated refresh token',
    () async {
      final session = _session();
      final api = _Api(
        (_) async => ProtoReader(
          (ProtoWriter()..writeString(1, 'replacement-access')).toBytes(),
        ),
      );
      expect(await SessionManager(api).refresh(session), isTrue);
      expect(session.refreshToken, 'synthetic-refresh');
    },
  );

  test('missing refresh token does not send an exchange', () async {
    final api = _Api((_) async => throw StateError('Unexpected request'));
    final session = _session()..refreshToken = null;
    expect(
      await SessionManager(api).refreshResult(session),
      SessionRefreshOutcome.missingRefreshToken,
    );
    expect(await SessionManager(api).refresh(session), isFalse);
    expect(api.exchanges, 0);
    expect(session.accessToken, 'synthetic-access');
  });

  final failures = <String, Object>{
    'offline': const SocketException('Synthetic offline'),
    'timeout': TimeoutException('Synthetic timeout'),
    'TLS': const HandshakeException('Synthetic TLS error'),
    'cancelled': DioException(
      requestOptions: RequestOptions(path: '/synthetic'),
      type: DioExceptionType.cancel,
    ),
    for (final status in [429, 500, 503])
      'HTTP $status': SteamApiException(
        2,
        'Synthetic HTTP error',
        'exchange',
        httpStatus: status,
      ),
    for (final result in [2, 3, 8, 10, 16, 20, 35, 36, 38, 84, 87])
      'EResult $result': SteamApiException(
        result,
        'Synthetic API error',
        'exchange',
      ),
  };
  for (final entry in failures.entries) {
    test('${entry.key} retains tokens without declaring rejection', () async {
      final api = _Api((_) async => throw entry.value);
      final session = _session();
      expect(
        await SessionManager(api).refreshResult(session),
        SessionRefreshOutcome.failed,
      );
      expect(session.accessToken, 'synthetic-access');
      expect(session.refreshToken, 'synthetic-refresh');
    });
  }

  for (final error in [
    for (final result in [5, 15, 21, 26, 27, 34, 77, 126])
      SteamApiException(
        result,
        'Synthetic authentication rejection',
        'exchange',
      ),
    for (final status in [401, 403])
      SteamApiException(
        2,
        'Synthetic HTTP rejection',
        'exchange',
        httpStatus: status,
      ),
  ]) {
    test('explicit rejection ${error.eresult}/${error.httpStatus}', () async {
      final api = _Api((_) async => throw error);
      final session = _session();
      expect(
        await SessionManager(api).refreshResult(session),
        SessionRefreshOutcome.rejected,
      );
      expect(session.accessToken, 'synthetic-access');
      expect(session.refreshToken, 'synthetic-refresh');
    });
  }

  test(
    'empty successful response remains a failure, not token rejection',
    () async {
      final session = _session();
      final api = _Api((_) async => ProtoReader(Uint8List(0)));
      expect(
        await SessionManager(api).refreshResult(session),
        SessionRefreshOutcome.failed,
      );
      expect(await SessionManager(api).refresh(session), isFalse);
      expect(session.accessToken, 'synthetic-access');
      expect(session.refreshToken, 'synthetic-refresh');
    },
  );

  test(
    'malformed rotated token cannot partly replace existing credentials',
    () async {
      final session = _session();
      final api = _Api(
        (_) async => ProtoReader(
          (ProtoWriter()
                ..writeString(1, 'replacement-access')
                ..writeBytes(2, Uint8List.fromList([0xff])))
              .toBytes(),
        ),
      );
      expect(
        await SessionManager(api).refreshResult(session),
        SessionRefreshOutcome.failed,
      );
      expect(session.accessToken, 'synthetic-access');
      expect(session.refreshToken, 'synthetic-refresh');
    },
  );
}
