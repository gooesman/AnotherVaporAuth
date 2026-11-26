import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/manifest.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/biometric_unlock.dart';
import 'package:ava/src/services/startup_unlock.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/unlock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Startup extends StartupUnlock {
  _Startup(this.required);
  bool required;

  @override
  Future<bool> get verificationRequired async => required;
}

class _Biometric extends BiometricUnlock {
  int prompts = 0;
  Future<String?> Function() authenticate = () async => '123456';

  @override
  Future<bool> get isEnabled async => true;

  @override
  Future<bool> get isSupported async => true;

  @override
  Future<String?> unlock(String reason) {
    prompts++;
    return authenticate();
  }
}

class _LockedController extends AppController {
  _LockedController({this.manual = false});
  final bool manual;
  final passkeys = <String>[];

  @override
  bool get manuallyLocked => manual;

  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(
      MemoryStorageProvider(),
      Manifest(encrypted: true, vault: true),
    ),
    accounts: const [],
    locked: true,
    privacyVersion: 0,
  );

  @override
  Future<bool> unlock(String passKey) async {
    passkeys.add(passKey);
    return true;
  }
}

Future<void> _mount(
  WidgetTester tester, {
  required _Startup startup,
  required _Biometric biometric,
  required _LockedController controller,
}) async {
  final container = ProviderContainer(
    overrides: [
      startupUnlockProvider.overrideWithValue(startup),
      biometricUnlockProvider.overrideWithValue(biometric),
      appControllerProvider.overrideWith(() => controller),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAvaTheme(AvaThemeVariant.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const UnlockScreen(),
      ),
    ),
  );
  // The lock logo deliberately animates forever; settling would never finish.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _unmount(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
}

void main() {
  for (final manual in [false, true]) {
    testWidgets('startup verification off ignores old biometric credentials '
        '(manual lock: $manual)', (tester) async {
      final biometric = _Biometric();
      final controller = _LockedController(manual: manual);
      await _mount(
        tester,
        startup: _Startup(false),
        biometric: biometric,
        controller: controller,
      );

      expect(biometric.prompts, 0);
      expect(find.byIcon(Icons.fingerprint), findsNothing);
      expect(controller.passkeys, isEmpty);
      // A manually reached locked screen still has its PIN fallback.
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      expect(controller.passkeys, ['123456']);
      expect(biometric.prompts, 0);
      await _unmount(tester);
    });
  }

  testWidgets('manual lock suppresses automatic biometrics but permits a tap', (
    tester,
  ) async {
    final biometric = _Biometric();
    final controller = _LockedController(manual: true);
    await _mount(
      tester,
      startup: _Startup(true),
      biometric: biometric,
      controller: controller,
    );

    expect(biometric.prompts, 0);
    expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pump();

    expect(biometric.prompts, 1);
    expect(controller.passkeys, ['123456']);
    await _unmount(tester);
  });

  testWidgets('automatic biometric cancel leaves the manual choices usable', (
    tester,
  ) async {
    final pending = Completer<String?>();
    final biometric = _Biometric()..authenticate = () => pending.future;
    final controller = _LockedController();
    await _mount(
      tester,
      startup: _Startup(true),
      biometric: biometric,
      controller: controller,
    );

    expect(biometric.prompts, 1);
    expect(controller.passkeys, isEmpty);
    pending.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.passkeys, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
    await _unmount(tester);
  });

  testWidgets(
    'rapid repeated biometric activation opens only one system prompt',
    (tester) async {
      final pending = Completer<String?>();
      final biometric = _Biometric()..authenticate = () => pending.future;
      final controller = _LockedController(manual: true);
      await _mount(
        tester,
        startup: _Startup(true),
        biometric: biometric,
        controller: controller,
      );
      final activate = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .onPressed!;

      // Two queued activations may use the same callback before UI rebuilds.
      activate();
      activate();
      await tester.pump();
      expect(biometric.prompts, 1);

      pending.complete('123456');
      await tester.pump();
      expect(controller.passkeys, ['123456']);
      await _unmount(tester);
    },
  );

  for (final result in <String?>['123456', null]) {
    testWidgets(
      'late biometric ${result == null ? 'cancel' : 'success'} respects '
      'a disabled parent setting',
      (tester) async {
        final pending = Completer<String?>();
        final biometric = _Biometric()..authenticate = () => pending.future;
        final controller = _LockedController();
        final startup = _Startup(true);
        await _mount(
          tester,
          startup: startup,
          biometric: biometric,
          controller: controller,
        );
        expect(biometric.prompts, 1);

        startup.required = false;
        pending.complete(result);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.passkeys, isEmpty);
        expect(find.byIcon(Icons.fingerprint), findsNothing);
        expect(find.byType(TextField), findsOneWidget);
        await _unmount(tester);
      },
    );
  }
}
