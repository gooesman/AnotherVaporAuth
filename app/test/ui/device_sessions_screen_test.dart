import 'dart:async';
import 'dart:typed_data';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/device_sessions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _bulkAction = 'Revoke other device authorizations';

class _Controller extends AppController {
  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(MemoryStorageProvider()),
    accounts: const [],
    locked: false,
  );
}

class _NoSkin extends SkinSpecController {
  @override
  build() => null;
}

class _Api extends SteamApiClient {
  final devices = <int, String>{1: 'GooeSteamKit', 2: 'Old PC', 3: 'Browser'};
  final revoked = <int>[];
  final actions = <int>[];
  final methods = <String>[];
  final errors = <int, Object>{};
  final retainedAfterRevoke = <int>{};
  final removedBeforeError = <int>{};
  int? requestingToken = 1;
  int enumerations = 0;
  Completer<void>? pendingRevoke;
  bool failRefresh = false;
  bool duplicateCurrent = false;
  void Function()? beforeRefresh;

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    methods.add('$iface/$method');
    expect(iface, 'IAuthenticationService');
    expect(useGet, isFalse);
    if (method == 'EnumerateTokens') {
      enumerations++;
      if (enumerations > 1) beforeRefresh?.call();
      if (failRefresh && enumerations > 1) {
        throw SteamApiException(2, 'Refresh unavailable', 'EnumerateTokens');
      }
      final response = ProtoWriter();
      for (final entry in [
        ...devices.entries,
        if (duplicateCurrent) const MapEntry(1, 'Duplicate current'),
      ]) {
        response.writeMessage(
          1,
          ProtoWriter()
            ..writeFixed64(1, entry.key)
            ..writeString(2, entry.value)
            ..writeVarint(4, 2)
            ..writeBool(5, entry.key != 3),
        );
      }
      if (requestingToken != null) response.writeFixed64(2, requestingToken!);
      return ProtoReader(response.toBytes());
    }
    if (method == 'RevokeRefreshToken') {
      final fields = ProtoReader(request.toBytes()).parse();
      final id = fields[1]!.asFixed64;
      revoked.add(id);
      actions.add(fields[3]!.asInt);
      await pendingRevoke?.future;
      if (removedBeforeError.contains(id)) devices.remove(id);
      if (errors[id] case final error?) throw error;
      if (!retainedAfterRevoke.contains(id)) devices.remove(id);
      return ProtoReader(Uint8List(0));
    }
    // A revoke must never trigger a token refresh or an authenticator API.
    throw StateError('Unexpected API method: $iface/$method');
  }
}

SteamGuardAccount _account() => SteamGuardAccount(
  accountName: 'fixture',
  sharedSecret: 'YQ==',
  session: SessionData(
    steamId: 76561198000000123,
    accessToken: 'fixture-token',
    refreshToken: 'fixture-refresh',
  ),
);

Widget _app(_Api api, {SteamGuardAccount? account}) => ProviderScope(
  overrides: [
    apiClientProvider.overrideWithValue(api),
    appControllerProvider.overrideWith(_Controller.new),
    skinSpecProvider.overrideWith(_NoSkin.new),
  ],
  child: MaterialApp(
    theme: buildAvaTheme(AvaThemeVariant.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: DeviceSessionsScreen(account: account ?? _account()),
  ),
);

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.text(_bulkAction));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, _bulkAction));
  await tester.pump();
}

void main() {
  testWidgets(
    'bulk confirmation preserves current session and revokes other remembered devices',
    (tester) async {
      final api = _Api();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_bulkAction));
      await tester.pumpAndSettle();
      expect(api.revoked, isEmpty);
      expect(
        find.textContaining('Keep the current GooeSteamKit session'),
        findsOneWidget,
      );
      expect(
        find.textContaining('does not remove your Steam authenticator'),
        findsOneWidget,
      );
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Old PC')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Browser')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('GooeSteamKit')),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(FilledButton, _bulkAction));
      await tester.pumpAndSettle();
      expect(api.revoked, [2, 3]);
      expect(api.actions, [1, 1]);
      expect(api.devices.keys, [1]);
      expect(api.enumerations, 2);
      expect(
        find.text('Confirmed: 2 other device authorizations revoked.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('cancelling confirmation sends no revoke requests', (
    tester,
  ) async {
    final api = _Api();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_bulkAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.revoked, isEmpty);
    expect(api.enumerations, 1);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, _bulkAction),
          )
          .onPressed,
      isNotNull,
    );
  });

  for (final token in <int?>[null, 0, 999]) {
    testWidgets('unknown requesting token $token disables all revocation', (
      tester,
    ) async {
      final api = _Api()..requestingToken = token;
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be identified'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, _bulkAction),
            )
            .onPressed,
        isNull,
      );
      for (final button in tester.widgetList<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Sign out',
        ),
      )) {
        expect(button.onPressed, isNull);
      }
      expect(api.revoked, isEmpty);
    });
  }

  testWidgets('ambiguous requesting token disables all revocation', (
    tester,
  ) async {
    final api = _Api()..duplicateCurrent = true;
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be identified'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, _bulkAction),
          )
          .onPressed,
      isNull,
    );
    expect(api.revoked, isEmpty);
  });

  testWidgets('current session alone has no bulk target', (tester) async {
    final api = _Api()..devices.removeWhere((key, _) => key != 1);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(
      find.text('No other device authorizations to revoke.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, _bulkAction),
          )
          .onPressed,
      isNull,
    );
    expect(find.byTooltip('Sign out'), findsNothing);
    expect(api.revoked, isEmpty);
  });

  testWidgets(
    'bulk requests run sequentially and busy state prevents refresh and duplicate actions',
    (tester) async {
      final pending = Completer<void>();
      final api = _Api()..pendingRevoke = pending;
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      final start = tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, _bulkAction),
          )
          .onPressed!;
      await _confirm(tester);
      expect(api.revoked, [2]);
      expect(
        find.text('Revoking other device authorizations…'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.refresh))
            .onPressed,
        isNull,
      );
      for (final button in tester.widgetList<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Sign out',
        ),
      )) {
        expect(button.onPressed, isNull);
      }
      start(); // A queued second activation must be ignored by the handler too.
      await tester.pump();
      expect(api.revoked, [2]);
      pending.complete();
      await tester.pumpAndSettle();
      expect(api.revoked, [2, 3]);
      expect(api.enumerations, 2);
    },
  );

  testWidgets(
    'partial failure reports the affected device without replaying writes and refreshes',
    (tester) async {
      final api = _Api()..errors[2] = TimeoutException('lost response');
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      await _confirm(tester);
      await tester.pumpAndSettle();
      expect(api.revoked, [2, 3]);
      expect(api.actions, [1, 1]);
      expect(api.enumerations, 2);
      expect(
        find.textContaining(
          'Confirmed revoked: 1. Not completed or not confirmed: 1.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Old PC:'), findsOneWidget);
      expect(find.textContaining('Confirmed: 2 other'), findsNothing);
      expect(api.devices.keys, [1, 2]);
      expect(
        api.methods,
        everyElement(
          anyOf(
            'IAuthenticationService/EnumerateTokens',
            'IAuthenticationService/RevokeRefreshToken',
          ),
        ),
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Browser'), findsNothing);
      expect(find.text('Old PC'), findsOneWidget);
    },
  );

  testWidgets('refresh failure cannot claim confirmed revocations', (
    tester,
  ) async {
    final api = _Api()..failRefresh = true;
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await _confirm(tester);
    await tester.pumpAndSettle();
    expect(api.revoked, [2, 3]);
    expect(api.enumerations, 2);
    expect(
      find.text('Confirmed: 2 other device authorizations revoked.'),
      findsNothing,
    );
    expect(
      find.textContaining(
        'Confirmed revoked: 0. Not completed or not confirmed: 2.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Refresh unavailable'), findsOneWidget);
  });

  testWidgets(
    'successful revoke response still requires the token to disappear',
    (tester) async {
      final api = _Api()..retainedAfterRevoke.add(2);
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      await _confirm(tester);
      await tester.pumpAndSettle();
      expect(api.revoked, [2, 3]);
      expect(api.enumerations, 2);
      expect(
        find.textContaining(
          'Confirmed revoked: 1. Not completed or not confirmed: 1.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Old PC:'), findsOneWidget);
      expect(
        find.text('Confirmed: 2 other device authorizations revoked.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'lost revoke response is confirmed only when the refreshed token is absent',
    (tester) async {
      final api = _Api()
        ..removedBeforeError.add(2)
        ..errors[2] = TimeoutException('lost response');
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      await _confirm(tester);
      await tester.pumpAndSettle();
      expect(api.revoked, [2, 3]);
      expect(api.enumerations, 2);
      expect(
        find.text('Confirmed: 2 other device authorizations revoked.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'session change during verification cannot confirm the old batch',
    (tester) async {
      final account = _account();
      final api = _Api()
        ..beforeRefresh = () {
          account.session.accessToken = 'new-fixture-token';
        };
      await tester.pumpWidget(_app(api, account: account));
      await tester.pumpAndSettle();
      await _confirm(tester);
      await tester.pumpAndSettle();
      expect(api.revoked, [2, 3]);
      expect(api.enumerations, 2);
      expect(
        find.textContaining(
          'Confirmed revoked: 0. Not completed or not confirmed: 2.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Confirmed: 2 other device authorizations revoked.'),
        findsNothing,
      );
    },
  );

  testWidgets('single revoke also never refreshes and replays a failed write', (
    tester,
  ) async {
    final api = _Api()..errors[2] = TimeoutException('lost response');
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sign out').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(api.revoked, [2]);
    expect(api.enumerations, 2);
    expect(
      find.textContaining(
        'Confirmed revoked: 0. Not completed or not confirmed: 1.',
      ),
      findsOneWidget,
    );
    expect(
      api.methods,
      everyElement(
        anyOf(
          'IAuthenticationService/EnumerateTokens',
          'IAuthenticationService/RevokeRefreshToken',
        ),
      ),
    );
  });

  testWidgets(
    'background sign-in during confirmation requires a new reviewed list',
    (tester) async {
      final api = _Api();
      final account = _account();
      await tester.pumpWidget(_app(api, account: account));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_bulkAction));
      await tester.pumpAndSettle();
      account.session.accessToken = 'new-fixture-token';
      api.requestingToken = 2;
      await tester.tap(find.widgetWithText(FilledButton, _bulkAction));
      await tester.pumpAndSettle();
      expect(api.revoked, isEmpty);
      expect(api.enumerations, 2);
      expect(find.textContaining('could not be identified'), findsOneWidget);
    },
  );

  testWidgets('background sign-in during a batch stops remaining targets', (
    tester,
  ) async {
    final pending = Completer<void>();
    final api = _Api()..pendingRevoke = pending;
    final account = _account();
    await tester.pumpWidget(_app(api, account: account));
    await tester.pumpAndSettle();
    await _confirm(tester);
    expect(api.revoked, [2]);
    account.session.accessToken = 'new-fixture-token';
    api.requestingToken = 3;
    pending.complete();
    await tester.pumpAndSettle();
    expect(api.revoked, [2]);
    expect(api.enumerations, 2);
    expect(
      find.textContaining(
        'Confirmed revoked: 0. Not completed or not confirmed: 2.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Browser: The current GooeSteamKit session could not be identified',
      ),
      findsOneWidget,
    );
    expect(api.devices.keys, [1, 3]);
  });
}
