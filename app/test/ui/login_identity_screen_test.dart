import 'dart:convert';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/credential_store.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/ui/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoCredentials extends CredentialStore {
  @override
  Future<String?> password(int steamId) async => null;
}

class _NoSkin extends SkinSpecController {
  @override
  build() => null;
}

class _QrApi extends SteamApiClient {
  int polls = 0;
  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    final response = ProtoWriter();
    if (method == 'BeginAuthSessionViaQR') {
      response
        ..writeUint64(1, 7)
        ..writeString(2, 'https://s.team/q/1/7')
        ..writeBytes(3, [1]);
    } else if (method == 'PollAuthSessionStatus') {
      polls++;
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '76561198000000002'})),
      );
      response
        ..writeString(3, 'header.$payload.signature')
        ..writeString(4, 'header.$payload.signature')
        ..writeString(6, 'Other account');
    } else {
      throw StateError('Unexpected request $method');
    }
    return ProtoReader(response.toBytes());
  }
}

void main() {
  testWidgets(
    'refreshing A with a QR approved by B does not mutate A or leave the login screen',
    (tester) async {
      final account = SteamGuardAccount(
        accountName: 'Selected A',
        sharedSecret: 'saved-secret',
        session: SessionData(
          steamId: 76561198000000001,
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
        ),
      );
      final before = jsonEncode(account.toJson());
      final api = _QrApi();
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            credentialStoreProvider.overrideWithValue(_NoCredentials()),
            skinSpecProvider.overrideWith(_NoSkin.new),
          ],
          child: MaterialApp(
            theme: buildAvaTheme(AvaThemeVariant.neon),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: LoginScreen(reason: LoginReason.refresh, account: account),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Log in with QR code'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 200));
      expect(api.polls, 1);
      expect(
        find.text(
          'This is a different Steam account. Sign in to the selected account; the original account has not been changed.',
        ),
        findsOneWidget,
      );
      expect(jsonEncode(account.toJson()), before);
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(api.polls, 1);
    },
  );
}
