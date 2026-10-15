import 'dart:convert';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/protocol/login_identity.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = 76561198000000001;
const _b = 76561198000000002;
String _token(int id) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': '$id'})))}.signature';
SessionData _session(int id) =>
    SessionData(steamId: id, accessToken: _token(id), refreshToken: _token(id));

void main() {
  test(
    'existing positive identity must match before accepting either QR or password tokens',
    () {
      validateRefreshIdentity(
        expectedSteamId: _a,
        currentSteamId: _a,
        session: _session(_a),
      );
      expect(
        () => validateRefreshIdentity(
          expectedSteamId: _a,
          currentSteamId: _a,
          session: _session(_b),
        ),
        throwsA(isA<LoginAccountMismatch>()),
      );
    },
  );
  test('a negative code-only placeholder may bind to a real Steam account', () {
    validateRefreshIdentity(
      expectedSteamId: -123,
      currentSteamId: -123,
      session: _session(_a),
    );
  });
  test(
    'changing the current object cannot redefine the originally selected account',
    () {
      expect(
        () => validateRefreshIdentity(
          expectedSteamId: _a,
          currentSteamId: _b,
          session: _session(_b),
        ),
        throwsA(isA<LoginAccountMismatch>()),
      );
      expect(
        () => validateRefreshIdentity(
          expectedSteamId: -123,
          currentSteamId: _b,
          session: _session(_b),
        ),
        throwsA(isA<LoginAccountMismatch>()),
      );
    },
  );
  test(
    'both token subjects must agree with the session, not a stale prior login',
    () {
      final session = _session(_a)..refreshToken = _token(_b);
      expect(
        () => validateRefreshIdentity(
          expectedSteamId: _a,
          currentSteamId: _a,
          session: session,
        ),
        throwsA(isA<LoginAccountMismatch>()),
      );
      session
        ..refreshToken = _token(_a)
        ..accessToken = _token(_b);
      expect(
        () => validateRefreshIdentity(
          expectedSteamId: _a,
          currentSteamId: _a,
          session: session,
        ),
        throwsA(isA<LoginAccountMismatch>()),
      );
    },
  );
  test('missing or malformed identity cannot bind a code-only account', () {
    for (final session in [
      SessionData(),
      SessionData(steamId: _a),
      SessionData(steamId: _a, accessToken: 'not-a-jwt'),
    ]) {
      expect(
        () => validateRefreshIdentity(
          expectedSteamId: -1,
          currentSteamId: -1,
          session: session,
        ),
        throwsFormatException,
      );
    }
  });
}
