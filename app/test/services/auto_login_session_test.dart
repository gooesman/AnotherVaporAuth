import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/auto_login.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends SteamApiClient {
  _Api(this.answer);
  final Future<ProtoReader> Function(String method) answer;
  final methods = <String>[];

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    methods.add(method);
    return answer(method);
  }
}

class _Login extends AutoLogin {
  _Login(super.api);
  int passwordAttempts = 0;

  @override
  Future<AutoLoginOutcome> reloginWithPassword(
    SteamGuardAccount account,
    String password,
  ) async {
    passwordAttempts++;
    return AutoLoginOutcome.ok;
  }
}

SteamGuardAccount _account() => SteamGuardAccount(
  accountName: 'synthetic-user',
  password: 'synthetic-password',
  session: SessionData(
    steamId: 76561198000000001,
    accessToken: 'old-access',
    refreshToken: 'old-refresh',
  ),
);

ProtoReader _success() =>
    ProtoReader((ProtoWriter()..writeString(1, 'new-access')).toBytes());

void main() {
  test('offline exchange stops without trying the saved password', () async {
    final api = _Api((_) async => throw const SocketException('Offline'));
    final login = _Login(api);
    final account = _account();
    expect(await login.ensureSession(account), AutoLoginOutcome.failed);
    expect(login.passwordAttempts, 0);
    expect(api.methods, ['GenerateAccessTokenForApp']);
    expect(account.session.accessToken, 'old-access');
    expect(account.session.refreshToken, 'old-refresh');
  });

  test(
    'offline account without saved password is still a network failure',
    () async {
      final login = _Login(
        _Api((_) async => throw TimeoutException('Offline')),
      );
      expect(
        await login.ensureSession(_account()..password = null),
        AutoLoginOutcome.failed,
      );
      expect(login.passwordAttempts, 0);
    },
  );

  test('invalid response does not trigger a password login', () async {
    final login = _Login(_Api((_) async => ProtoReader(Uint8List(0))));
    expect(await login.ensureSession(_account()), AutoLoginOutcome.failed);
    expect(login.passwordAttempts, 0);
  });

  test('rejected refresh token falls back exactly once', () async {
    final login = _Login(
      _Api(
        (_) async =>
            throw SteamApiException(26, 'Revoked', 'GenerateAccessTokenForApp'),
      ),
    );
    expect(await login.ensureSession(_account()), AutoLoginOutcome.ok);
    expect(login.passwordAttempts, 1);
  });

  test('rejected refresh without password requests a password', () async {
    final login = _Login(
      _Api(
        (_) async =>
            throw SteamApiException(27, 'Expired', 'GenerateAccessTokenForApp'),
      ),
    );
    expect(
      await login.ensureSession(_account()..password = null),
      AutoLoginOutcome.needsPassword,
    );
    expect(login.passwordAttempts, 0);
  });

  test(
    'missing refresh token can use saved credentials without API exchange',
    () async {
      final api = _Api((_) async => throw StateError('Unexpected API request'));
      final login = _Login(api);
      expect(
        await login.ensureSession(_account()..session.refreshToken = null),
        AutoLoginOutcome.ok,
      );
      expect(login.passwordAttempts, 1);
      expect(api.methods, isEmpty);
    },
  );

  test('refresh-only session can renew without password', () async {
    final login = _Login(_Api((_) async => _success()));
    final account = _account()
      ..password = null
      ..session.accessToken = null;
    expect(await login.ensureSession(account), AutoLoginOutcome.ok);
    expect(account.session.accessToken, 'new-access');
    expect(login.passwordAttempts, 0);
  });

  test(
    'same account instance shares in-flight work and can retry after failure',
    () async {
      final pending = Completer<ProtoReader>();
      var attempt = 0;
      final api = _Api(
        (_) async => ++attempt == 1 ? pending.future : _success(),
      );
      final login = _Login(api);
      final account = _account();
      final first = login.ensureSession(account);
      final second = login.ensureSession(account);
      expect(api.methods, hasLength(1));
      pending.completeError(const SocketException('Offline'));
      expect(await first, AutoLoginOutcome.failed);
      expect(await second, AutoLoginOutcome.failed);
      expect(await login.ensureSession(account), AutoLoginOutcome.ok);
      expect(api.methods, hasLength(2));
      expect(login.passwordAttempts, 0);
    },
  );

  test(
    'local and portable instances with the same Steam ID stay independent',
    () async {
      final pending = <Completer<ProtoReader>>[];
      final api = _Api((_) {
        final response = Completer<ProtoReader>();
        pending.add(response);
        return response.future;
      });
      final login = _Login(api);
      final local = _account();
      final portable = _account()..fromPortable = true;
      final first = login.ensureSession(local);
      final second = login.ensureSession(portable);
      expect(api.methods, hasLength(2));
      pending[0].complete(_success());
      pending[1].completeError(
        const SocketException('Portable source offline'),
      );
      expect(await first, AutoLoginOutcome.ok);
      expect(await second, AutoLoginOutcome.failed);
      expect(local.session.accessToken, 'new-access');
      expect(portable.session.accessToken, 'old-access');
    },
  );

  test('different clients never share requests for the same account', () async {
    final firstPending = Completer<ProtoReader>();
    final secondPending = Completer<ProtoReader>();
    final firstApi = _Api((_) => firstPending.future);
    final secondApi = _Api((_) => secondPending.future);
    final account = _account();
    final first = _Login(firstApi).ensureSession(account);
    final second = _Login(secondApi).ensureSession(account);
    expect(firstApi.methods, hasLength(1));
    expect(secondApi.methods, hasLength(1));
    firstPending.complete(_success());
    secondPending.complete(_success());
    expect(await first, AutoLoginOutcome.ok);
    expect(await second, AutoLoginOutcome.ok);
  });

  for (final result in [5, 84]) {
    test(
      'password endpoint verdict $result retains account health semantics',
      () async {
        final api = _Api((method) async {
          if (method == 'GenerateAccessTokenForApp') {
            throw SteamApiException(26, 'Revoked', method);
          }
          if (method == 'GetPasswordRSAPublicKey') {
            return ProtoReader(
              (ProtoWriter()
                    ..writeString(1, List.filled(512, 'f').join())
                    ..writeString(2, '10001')
                    ..writeVarint(3, 123))
                  .toBytes(),
            );
          }
          if (method == 'BeginAuthSessionViaCredentials') {
            throw SteamApiException(
              result,
              'Synthetic credentials verdict',
              method,
            );
          }
          throw StateError('Unexpected method $method');
        });
        final account = _account();
        expect(
          await AutoLogin(api).ensureSession(account),
          result == 5
              ? AutoLoginOutcome.invalidCredentials
              : AutoLoginOutcome.failed,
        );
        expect(api.methods, [
          'GenerateAccessTokenForApp',
          'GetPasswordRSAPublicKey',
          'BeginAuthSessionViaCredentials',
        ]);
        expect(account.session.accessToken, 'old-access');
        expect(account.password, 'synthetic-password');
      },
    );
  }
}
