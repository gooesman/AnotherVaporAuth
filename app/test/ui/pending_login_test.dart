import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/ui/pending_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends SteamApiClient {
  _Api(this.responses);
  final List<Object> responses;
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
    if (responses.isEmpty) throw StateError('Unexpected call $method');
    final response = responses.removeAt(0);
    if (response is ProtoReader) return response;
    throw response;
  }
}

SteamGuardAccount _account() => SteamGuardAccount(
  accountName: 'synthetic-pending-account',
  password: 'synthetic-password',
  session: SessionData(
    steamId: 76561198000000001,
    accessToken: 'old-access',
    refreshToken: 'old-refresh',
  ),
);

ProtoReader _refreshed() =>
    ProtoReader((ProtoWriter()..writeString(1, 'new-access')).toBytes());
ProtoReader _empty() => ProtoReader(Uint8List(0));
SteamApiException _unauthorized() =>
    SteamApiException(2, 'HTTP 401', 'pending', httpStatus: 401);

Future<AppLocalizations> _check(
  WidgetTester tester,
  _Api api, {
  SteamGuardAccount? account,
  bool silent = false,
}) async {
  late AppLocalizations strings;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Consumer(
          builder: (context, ref, child) {
            strings = AppLocalizations.of(context);
            return Scaffold(
              body: TextButton(
                onPressed: () => checkPendingLogins(
                  context,
                  ref,
                  account ?? _account(),
                  silent: silent,
                ),
                child: const Text('Check pending logins'),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('Check pending logins'));
  await tester.pumpAndSettle();
  return strings;
}

void main() {
  testWidgets('network failure does not renew or suggest signing in', (
    tester,
  ) async {
    final account = _account();
    final api = _Api([const SocketException('Synthetic offline')]);
    final l = await _check(tester, api, account: account);
    expect(api.methods, ['GetAuthSessionsForAccount']);
    expect(find.text(l.netErrUnreachable), findsOneWidget);
    expect(find.text(l.loginNeedSession), findsNothing);
    expect(account.session.accessToken, 'old-access');
    expect(account.session.refreshToken, 'old-refresh');
  });

  testWidgets('timeout reports localized timeout without a second API call', (
    tester,
  ) async {
    final api = _Api([TimeoutException('Synthetic timeout')]);
    final l = await _check(tester, api);
    expect(api.methods, ['GetAuthSessionsForAccount']);
    expect(find.text(l.netErrTimeout), findsOneWidget);
    expect(find.text(l.loginNeedSession), findsNothing);
  });

  testWidgets('throttling stays an API error without a credentials fallback', (
    tester,
  ) async {
    final api = _Api([
      SteamApiException(84, 'Synthetic rate limit', 'pending'),
    ]);
    await _check(tester, api);
    expect(api.methods, ['GetAuthSessionsForAccount']);
    expect(find.text('Synthetic rate limit'), findsOneWidget);
  });

  testWidgets('401 renews once and retries the pending query', (tester) async {
    final api = _Api([_unauthorized(), _refreshed(), _empty()]);
    final l = await _check(tester, api);
    expect(api.methods, [
      'GetAuthSessionsForAccount',
      'GenerateAccessTokenForApp',
      'GetAuthSessionsForAccount',
    ]);
    expect(find.text(l.loginNoPending), findsOneWidget);
    expect(find.text(l.loginNeedSession), findsNothing);
  });

  testWidgets('401 then offline renewal neither logs in nor retries pending', (
    tester,
  ) async {
    final account = _account();
    final api = _Api([_unauthorized(), const SocketException('Offline')]);
    final l = await _check(tester, api, account: account);
    expect(api.methods, [
      'GetAuthSessionsForAccount',
      'GenerateAccessTokenForApp',
    ]);
    expect(find.text(l.netErrUnreachable), findsOneWidget);
    expect(find.text(l.loginNeedSession), findsNothing);
    expect(account.session.accessToken, 'old-access');
  });

  testWidgets('timeout after successful renewal is not a login error', (
    tester,
  ) async {
    final api = _Api([
      _unauthorized(),
      _refreshed(),
      TimeoutException('Offline'),
    ]);
    final l = await _check(tester, api);
    expect(api.methods, hasLength(3));
    expect(find.text(l.netErrTimeout), findsOneWidget);
    expect(find.text(l.loginNeedSession), findsNothing);
  });

  testWidgets('authentication rejected again does not retry in a loop', (
    tester,
  ) async {
    final api = _Api([_unauthorized(), _refreshed(), _unauthorized()]);
    final l = await _check(tester, api);
    expect(api.methods, hasLength(3));
    expect(find.text(l.loginNeedSession), findsOneWidget);
  });

  testWidgets(
    'revoked refresh token without a password still requires sign-in',
    (tester) async {
      final api = _Api([
        _unauthorized(),
        SteamApiException(26, 'Revoked', 'GenerateAccessTokenForApp'),
      ]);
      final l = await _check(tester, api, account: _account()..password = null);
      expect(api.methods, hasLength(2));
      expect(find.text(l.loginNeedSession), findsOneWidget);
    },
  );

  testWidgets(
    'silent background failure stays silent without extra API calls',
    (tester) async {
      final api = _Api([const SocketException('Offline')]);
      await _check(tester, api, silent: true);
      expect(api.methods, ['GetAuthSessionsForAccount']);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
