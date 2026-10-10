import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/screen_qr_capture.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/approve_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _qr = 'https://s.team/q/1/123456';
const _steamId = 76561198000000001;
const _captureKey = ValueKey('screen-qr-capture');

SteamGuardAccount _account({int id = _steamId, bool session = true}) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': '$id',
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          }),
        ),
      )
      .replaceAll('=', '');
  return SteamGuardAccount(
    accountName: 'Synthetic account $id',
    sharedSecret: base64.encode(List<int>.filled(20, 7)),
    session: SessionData(
      steamId: id,
      accessToken: session ? 'e30.$payload.synthetic-signature' : null,
    ),
  );
}

class _Controller extends AppController {
  _Controller(this.accounts, {this.ready});
  final List<SteamGuardAccount> accounts;
  final Future<void>? ready;

  AppData _data(List<SteamGuardAccount> accounts, {bool locked = false}) =>
      AppData(
        store: AccountStore(MemoryStorageProvider()),
        accounts: accounts,
        locked: locked,
      );

  @override
  Future<AppData> build() async {
    await ready;
    return _data(accounts);
  }

  void replace(List<SteamGuardAccount> accounts, {bool locked = false}) {
    state = AsyncData(_data(accounts, locked: locked));
  }
}

class _Capture extends ScreenQrCapture {
  _Capture({this.code = _qr, this.error, this.supported = true});
  final String? code;
  final Object? error;
  final bool supported;
  Future<String?>? pending;
  int calls = 0;

  @override
  bool get available => supported;

  @override
  Future<String?> capture({
    required String instruction,
    required int accent,
  }) async {
    calls++;
    if (error != null) throw error!;
    return pending ?? Future.value(code);
  }
}

class _Api extends SteamApiClient {
  final calls = <String>[];
  final approvals = <Uint8List>[];
  int infoVersion = 1;
  bool failInfo = false;
  Future<void>? pendingApproval;

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    calls.add(method);
    if (method == 'GetAuthSessionInfo') {
      if (failInfo) throw StateError('Synthetic unavailable session');
      final response = ProtoWriter()
        ..writeString(1, '192.0.2.10')
        ..writeString(3, 'Test City')
        ..writeString(5, 'Test Country')
        ..writeString(7, 'Synthetic Steam desktop')
        ..writeVarint(8, infoVersion);
      return ProtoReader(response.toBytes());
    }
    if (method == 'UpdateAuthSessionWithMobileConfirmation') {
      approvals.add(request.toBytes());
      await pendingApproval;
      return ProtoReader(Uint8List(0));
    }
    throw StateError('Unexpected API call: $method');
  }
}

class _Harness {
  _Harness(this.api, this.capture, this.controller, this.accounts);
  final _Api api;
  final _Capture capture;
  final _Controller controller;
  final List<SteamGuardAccount> accounts;
}

Future<_Harness> _show(
  WidgetTester tester, {
  _Capture? capture,
  _Api? api,
  List<SteamGuardAccount>? accounts,
  SteamGuardAccount? initial,
  Future<void>? accountLoad,
  bool awaitAccounts = true,
  AvaThemeVariant theme = AvaThemeVariant.light,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final chosenAccounts = accounts ?? [_account()];
  final controller = _Controller(chosenAccounts, ready: accountLoad);
  final fakeApi = api ?? _Api();
  final fakeCapture = capture ?? _Capture();
  final container = ProviderContainer(
    overrides: [
      appControllerProvider.overrideWith(() => controller),
      apiClientProvider.overrideWithValue(fakeApi),
      screenQrCaptureProvider.overrideWithValue(fakeCapture),
      storageProvider.overrideWithValue(MemoryStorageProvider()),
    ],
  );
  addTearDown(container.dispose);
  // Most entry points already have loaded accounts; one regression test
  // deliberately exercises the first frame before account loading finishes.
  if (awaitAccounts) await container.read(appControllerProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAvaTheme(theme),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ApproveLoginScreen(
          initialAccount: initial ?? chosenAccounts.first,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(fakeApi, fakeCapture, controller, chosenAccounts);
}

Future<void> _capture(WidgetTester tester) async {
  final button = find.byKey(_captureKey);
  await tester.ensureVisible(button);
  await tester.tap(button);
  // A pending operation intentionally has a continuously animated spinner.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'delayed account loading preserves the requested second account',
    (tester) async {
      final ready = Completer<void>();
      final first = _account();
      final second = _account(id: _steamId + 1);
      final harness = await _show(
        tester,
        accounts: [first, second],
        initial: second,
        accountLoad: ready.future,
        awaitAccounts: false,
      );
      expect(
        find.byType(DropdownButtonFormField<SteamGuardAccount>),
        findsNothing,
      );
      ready.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<SteamGuardAccount>>(
              find.byType(DropdownButtonFormField<SteamGuardAccount>),
            )
            .initialValue,
        same(second),
      );
      expect(harness.api.calls, isEmpty);
      expect(harness.capture.calls, 0);
    },
  );

  testWidgets(
    'cancelled, missing, non-Steam or failed capture never calls Steam',
    (tester) async {
      for (final capture in [
        _Capture(code: null),
        _Capture(error: const ScreenQrNotFound()),
        _Capture(code: 'https://example.com/q/1/123456'),
        _Capture(error: StateError('Synthetic capture error')),
      ]) {
        final harness = await _show(tester, capture: capture);
        await _capture(tester);
        expect(harness.capture.calls, 1);
        expect(harness.api.calls, isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'capture shows login details and submits exactly once after confirmation',
    (tester) async {
      final harness = await _show(tester);
      final submitted = Completer<void>();
      harness.api.pendingApproval = submitted.future;
      await _capture(tester);
      expect(harness.api.calls, ['GetAuthSessionInfo']);
      expect(harness.api.approvals, isEmpty);
      expect(find.text('IP: 192.0.2.10'), findsOneWidget);
      expect(find.textContaining('Synthetic Steam desktop'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      await _confirm(tester);
      expect(harness.api.calls, [
        'GetAuthSessionInfo',
        'UpdateAuthSessionWithMobileConfirmation',
      ]);
      expect(harness.api.approvals, hasLength(1));
      final request = ProtoReader(harness.api.approvals.single).parse();
      expect(request[3]?.asFixed64, _steamId);
      expect(request[5]?.asBool, true);
      expect(
        tester.widget<FilledButton>(find.byKey(_captureKey)).onPressed,
        isNull,
      );
      await tester.tap(find.byKey(_captureKey));
      expect(harness.capture.calls, 1);
      submitted.complete();
      await tester.pumpAndSettle();
      expect(harness.api.approvals, hasLength(1));
    },
  );

  testWidgets(
    'unavailable or changed-version login details cannot be approved',
    (tester) async {
      for (final api in [_Api()..failInfo = true, _Api()..infoVersion = 2]) {
        final harness = await _show(tester, api: api);
        await _capture(tester);
        expect(harness.api.calls, ['GetAuthSessionInfo']);
        expect(harness.api.approvals, isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
        final l = AppLocalizations.of(
          tester.element(find.byType(ApproveLoginScreen)),
        );
        expect(find.text(l.approveSessionUnavailable), findsOneWidget);
      }
    },
  );

  testWidgets(
    'a sessionless initial account never falls back to another live account',
    (tester) async {
      final live = _account();
      final offline = _account(id: _steamId + 1, session: false);
      final harness = await _show(
        tester,
        accounts: [live, offline],
        initial: offline,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<SteamGuardAccount>>(
              find.byType(DropdownButtonFormField<SteamGuardAccount>),
            )
            .initialValue,
        same(offline),
      );
      expect(
        tester.widget<FilledButton>(find.byKey(_captureKey)).onPressed,
        isNull,
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(ApproveLoginScreen)),
      );
      expect(find.text(l.steamSwitchQrNeedsSession), findsOneWidget);
      expect(find.text(l.loginButton), findsOneWidget);
      expect(harness.api.calls, isEmpty);
    },
  );

  testWidgets(
    'locking, deleting, replacing or changing account identity cancels pending approval',
    (tester) async {
      for (final change in ['lock', 'delete', 'replace', 'identity']) {
        final harness = await _show(tester);
        await _capture(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        switch (change) {
          case 'lock':
            harness.controller.replace(harness.accounts, locked: true);
          case 'delete':
            harness.controller.replace([]);
          case 'replace':
            harness.controller.replace([_account()]);
          case 'identity':
            harness.accounts.single.session.steamId++;
            harness.controller.replace(harness.accounts);
        }
        await tester.pump();
        await _confirm(tester);
        expect(harness.api.calls, ['GetAuthSessionInfo'], reason: change);
        expect(harness.api.approvals, isEmpty, reason: change);
        expect(tester.takeException(), isNull, reason: change);
      }
    },
  );

  testWidgets('pending capture prevents repeat capture and changing accounts', (
    tester,
  ) async {
    final pending = Completer<String?>();
    final capture = _Capture()..pending = pending.future;
    final harness = await _show(tester, capture: capture);
    final originalCallback = tester
        .widget<FilledButton>(find.byKey(_captureKey))
        .onPressed!;
    originalCallback();
    originalCallback();
    await tester.pump();
    expect(capture.calls, 1);
    expect(
      tester.widget<FilledButton>(find.byKey(_captureKey)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<SteamGuardAccount>>(
            find.byType(DropdownButtonFormField<SteamGuardAccount>),
          )
          .onChanged,
      isNull,
    );
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(harness.api.calls, isEmpty);
    expect(
      tester.widget<FilledButton>(find.byKey(_captureKey)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'unsupported capture platform keeps paste flow without a capture button',
    (tester) async {
      final harness = await _show(tester, capture: _Capture(supported: false));
      expect(find.byKey(_captureKey), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, true);
      expect(harness.api.calls, isEmpty);
      expect(harness.capture.calls, 0);
    },
  );

  testWidgets(
    'narrow plain and styled screens show a cancellable confirmation without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final theme in [AvaThemeVariant.light, AvaThemeVariant.neon]) {
        final harness = await _show(tester, theme: theme);
        await _capture(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
        await tester.pumpAndSettle();
        expect(harness.api.calls, ['GetAuthSessionInfo']);
        expect(harness.api.approvals, isEmpty);
      }
    },
  );
}
