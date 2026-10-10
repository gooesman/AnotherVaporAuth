import 'dart:io';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/manifest.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/startup_unlock.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Startup extends StartupUnlock {
  String? pin;
  int writes = 0;
  @override
  Future<String?> readPasskey() async => pin;
  @override
  Future<void> remember(String pin) async {
    this.pin = pin;
    writes++;
  }

  @override
  Future<void> forget() async {
    pin = null;
    writes++;
  }
}

class _Unlocked extends AppController {
  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(
      ref.read(storageProvider),
      Manifest(encrypted: true, vault: true),
    ),
    accounts: const [],
    locked: false,
    passKey: '123456',
    privacyVersion: 0,
  );
}

void main() {
  testWidgets(
    'narrow settings can cancel, disable and re-enable startup verification',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final temp = Directory.systemTemp.createTempSync('ava-startup-ui-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final startup = _Startup();
      final container = ProviderContainer(
        overrides: [
          storageProvider.overrideWithValue(
            MemoryStorageProvider('${temp.path}/maFiles'),
          ),
          appControllerProvider.overrideWith(_Unlocked.new),
          startupUnlockProvider.overrideWithValue(startup),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAvaTheme(AvaThemeVariant.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('startup-verification-switch'));
      await tester.ensureVisible(toggle);
      expect(tester.widget<Switch>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(SettingsScreen)),
      );
      expect(find.text(l.settingsStartupVerificationDisable), findsOneWidget);
      await tester.tap(find.text(l.commonCancel));
      await tester.pumpAndSettle();
      expect(startup.writes, 0);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(startup.writes, 1);
      expect(tester.widget<Switch>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(startup.writes, 2);
      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
