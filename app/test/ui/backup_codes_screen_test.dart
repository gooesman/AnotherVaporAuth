import 'dart:async';
import 'dart:convert';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/route_observer.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/backup_codes.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/backup_codes_service.dart';
import 'package:ava/src/ui/backup_codes_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SteamGuardAccount _account([int steamId = 76561198000000001]) =>
    SteamGuardAccount(
      accountName: 'demo_primary',
      revocationCode: 'DO-NOT-SHOW',
      session: SessionData(steamId: steamId, accessToken: 'DO-NOT-TRANSFER'),
    );

class _Service extends BackupCodesService {
  int starts = 0;
  int submits = 0;
  int? steamId;
  String? submittedCode;
  BackupCodesException? startError;
  BackupCodesException? submitError;
  Completer<BackupCodesChallenge>? pendingStart;
  Completer<List<String>>? pendingSubmit;

  @override
  Future<BackupCodesChallenge> requestSms(
    SteamGuardAccount account, {
    CancelToken? cancelToken,
  }) async {
    starts++;
    steamId = account.steamId;
    if (startError != null) throw startError!;
    if (pendingStart != null) return pendingStart!.future;
    return BackupCodesChallenge(steamId: account.steamId, phoneHint: '***1234');
  }

  @override
  Future<List<String>> generate(
    SteamGuardAccount account,
    BackupCodesChallenge challenge,
    String smsCode, {
    CancelToken? cancelToken,
  }) async {
    submits++;
    expect(challenge.steamId, account.steamId);
    submittedCode = smsCode;
    if (submitError != null) throw submitError!;
    if (pendingSubmit != null) return pendingSubmit!.future;
    return ['01234567', '87654321'];
  }
}

class _Locked extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final _lockedProvider = NotifierProvider<_Locked, bool>(_Locked.new);

Widget _app(
  _Service service, {
  SteamGuardAccount? account,
  Future<bool> Function(Uri)? launch,
  AvaThemeVariant theme = AvaThemeVariant.light,
}) => ProviderScope(
  overrides: [
    backupCodesServiceProvider.overrideWithValue(service),
    backupCodesLockedProvider.overrideWith((ref) => ref.watch(_lockedProvider)),
    backupCodesLauncherProvider.overrideWithValue(launch ?? (_) async => true),
  ],
  child: MaterialApp(
    theme: buildAvaTheme(theme),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    navigatorObservers: [routeObserver],
    home: BackupCodesScreen(account: account ?? _account()),
  ),
);

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump();
}

Future<void> _generate(WidgetTester tester) async {
  await _tap(tester, 'Send verification SMS');
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('backup-sms-code')),
    '00123',
  );
  await _tap(tester, 'Verify and generate codes');
}

void main() {
  testWidgets(
    'native two-step flow requires both clicks, preserves account and no browser',
    (tester) async {
      final service = _Service();
      final opened = <Uri>[];
      final account = _account();
      final before = jsonEncode(account.toJson());
      await tester.pumpWidget(
        _app(
          service,
          account: account,
          launch: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(service.starts, 0);
      expect(service.submits, 0);
      expect(find.text('demo_primary'), findsOneWidget);
      expect(find.textContaining('DO-NOT-'), findsNothing);
      await _tap(tester, 'Send verification SMS');
      await tester.pumpAndSettle();
      expect(service.starts, 1);
      expect(service.steamId, account.steamId);
      expect(service.submits, 0);
      expect(find.text('***1234'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('backup-sms-code')),
        '00123',
      );
      expect(service.submits, 0);
      await _tap(tester, 'Verify and generate codes');
      await tester.pumpAndSettle();
      expect(service.submits, 1);
      expect(service.submittedCode, '00123');
      expect(find.text('01234567'), findsOneWidget);
      expect(find.text('87654321'), findsOneWidget);
      expect(find.text('00123'), findsNothing);
      expect(find.textContaining('DO-NOT-'), findsNothing);
      expect(opened, isEmpty);
      expect(jsonEncode(account.toJson()), before);
      await _tap(tester, 'Clear codes');
      await tester.pumpAndSettle();
      expect(find.text('01234567'), findsNothing);
      expect(service.starts, 1);
      expect(service.submits, 1);
    },
  );

  testWidgets('duplicate clicks cannot send or generate twice while busy', (
    tester,
  ) async {
    final service = _Service()
      ..pendingStart = Completer<BackupCodesChallenge>();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _tap(tester, 'Send verification SMS');
    await _tap(tester, 'Send verification SMS');
    expect(service.starts, 1);
    service.pendingStart!.complete(
      const BackupCodesChallenge(steamId: 76561198000000001),
    );
    await tester.pumpAndSettle();
    service.pendingSubmit = Completer<List<String>>();
    await tester.enterText(
      find.byKey(const ValueKey('backup-sms-code')),
      '12345',
    );
    await _tap(tester, 'Verify and generate codes');
    await _tap(tester, 'Verify and generate codes');
    expect(service.submits, 1);
    service.pendingSubmit!.complete(['01234567']);
    await tester.pumpAndSettle();
    expect(find.text('01234567'), findsOneWidget);
  });

  testWidgets(
    'failed generation retains input step but never resends SMS or shows raw errors',
    (tester) async {
      final service = _Service()
        ..submitError = const BackupCodesException(
          BackupCodesError.invalidCode,
        );
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await _generate(tester);
      await tester.pumpAndSettle();
      expect(service.starts, 1);
      expect(service.submits, 1);
      expect(
        find.textContaining('Steam rejected the verification code.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('backup-sms-code')), findsOneWidget);
      expect(find.text('01234567'), findsNothing);
      expect(find.text('00123'), findsNothing);
    },
  );

  testWidgets(
    'unknown response does not claim success and expired session offers login',
    (tester) async {
      final service = _Service()
        ..startError = const BackupCodesException(
          BackupCodesError.invalidResponse,
        );
      final account = _account();
      await tester.pumpWidget(_app(service, account: account));
      await tester.pumpAndSettle();
      await _tap(tester, 'Send verification SMS');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Steam returned an unrecognized response.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('backup-sms-code')), findsNothing);
      expect(service.starts, 1);
      service.startError = const BackupCodesException(
        BackupCodesError.authenticationRequired,
      );
      await _tap(tester, 'Send verification SMS');
      await tester.pumpAndSettle();
      expect(
        find.text('Your Steam session has expired. Please log in again.'),
        findsOneWidget,
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(BackupCodesScreen)),
      );
      expect(find.text(l.loginButton), findsOneWidget);
      expect(find.text('Send verification SMS'), findsNothing);
      expect(service.starts, 2);
    },
  );

  testWidgets(
    'reading SMS in another app keeps challenge but visible codes clear on blur',
    (tester) async {
      final service = _Service();
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await _tap(tester, 'Send verification SMS');
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('backup-sms-code')), findsOneWidget);
      expect(service.starts, 1);
      await tester.enterText(
        find.byKey(const ValueKey('backup-sms-code')),
        '12345',
      );
      await _tap(tester, 'Verify and generate codes');
      await tester.pumpAndSettle();
      expect(find.text('01234567'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.text('01234567'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('01234567'), findsNothing);
      expect(service.submits, 1);
    },
  );

  testWidgets('late generated codes after background are discarded', (
    tester,
  ) async {
    final service = _Service()..pendingSubmit = Completer<List<String>>();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _generate(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    service.pendingSubmit!.complete(['01234567']);
    await tester.pumpAndSettle();
    expect(find.text('01234567'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('01234567'), findsNothing);
    expect(service.submits, 1);
  });

  testWidgets(
    'locking clears codes and prevents actions under the lock screen',
    (tester) async {
      final service = _Service();
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await _generate(tester);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BackupCodesScreen)),
      );
      container.read(_lockedProvider.notifier).set(true);
      await tester.pumpAndSettle();
      expect(find.text('01234567'), findsNothing);
      expect(find.text('Send verification SMS'), findsNothing);
      container.read(_lockedProvider.notifier).set(false);
      await tester.pumpAndSettle();
      expect(find.text('01234567'), findsNothing);
      expect(service.starts, 1);
      expect(service.submits, 1);
    },
  );

  testWidgets('switching the selected account discards an in-flight result', (
    tester,
  ) async {
    final service = _Service()..pendingSubmit = Completer<List<String>>();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _generate(tester);
    await tester.pumpWidget(
      _app(service, account: _account(76561198000000002)),
    );
    await tester.pumpAndSettle();
    service.pendingSubmit!.complete(['01234567']);
    await tester.pumpAndSettle();
    expect(find.text('01234567'), findsNothing);
    expect(find.text('SteamID 76561198000000002'), findsOneWidget);
    expect(service.starts, 1);
  });

  testWidgets(
    'manual browser fallback is optional, credential-free and handles failure',
    (tester) async {
      final service = _Service();
      final opened = <Uri>[];
      await tester.pumpWidget(
        _app(
          service,
          launch: (uri) async {
            opened.add(uri);
            return false;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      await _tap(tester, 'Official Steam page (optional)');
      await tester.pumpAndSettle();
      await _tap(tester, 'Open Steam to get codes');
      await tester.pumpAndSettle();
      expect(
        opened.single.toString(),
        'https://store.steampowered.com/twofactor/emergency_codes',
      );
      expect(opened.single.query, isEmpty);
      expect(service.starts, 0);
      expect(
        find.textContaining('Could not open the browser.'),
        findsOneWidget,
      );
      expect(find.text('Copy official link'), findsOneWidget);
    },
  );

  for (final theme in AvaThemeVariant.values) {
    testWidgets('native backup codes fit 320px with ${theme.name} theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(_Service(), theme: theme));
      await tester.pumpAndSettle();
      await _generate(tester);
      await tester.pumpAndSettle();
      expect(find.text('01234567'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
