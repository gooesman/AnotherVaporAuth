import 'dart:async';
import 'dart:io';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/sync_providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/manifest.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/biometric_unlock.dart';
import 'package:ava/src/services/startup_unlock.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/services/sync/sync_engine.dart';
import 'package:ava/src/ui/settings_screen.dart';
import 'package:ava/src/ui/widgets/ava_panel.dart';
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

class _Biometric extends BiometricUnlock {
  bool enabled = true;
  bool failDelete = false;
  int disables = 0;
  int enables = 0;
  Completer<bool>? pendingEnable;

  @override
  Future<bool> get isSupported async => true;
  @override
  Future<bool> get isEnabled async => enabled;
  @override
  Future<void> disableVerified() async {
    if (failDelete) throw StateError('secure storage');
    disables++;
    enabled = false;
  }

  @override
  Future<bool> enable(String passKey, String reason) async {
    enables++;
    final ok = await (pendingEnable?.future ?? Future.value(true));
    if (ok) enabled = true;
    return ok;
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

class _SyncStatus extends SyncStatusController {
  _SyncStatus(this.value);
  final SyncEngineStatus value;
  @override
  SyncEngineStatus build() => value;
}

Future<void> _pumpSettings(
  WidgetTester tester,
  _Startup startup,
  _Biometric biometric, {
  SyncEngineStatus? syncStatus,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final temp = Directory.systemTemp.createTempSync('ava-startup-ui-');
  addTearDown(() => temp.deleteSync(recursive: true));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(
          MemoryStorageProvider('${temp.path}/maFiles'),
        ),
        appControllerProvider.overrideWith(_Unlocked.new),
        startupUnlockProvider.overrideWithValue(startup),
        biometricUnlockProvider.overrideWithValue(biometric),
        if (syncStatus != null)
          syncStatusProvider.overrideWith(() => _SyncStatus(syncStatus)),
      ],
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
}

void main() {
  for (final entry in [
    (const SyncEngineStatus(configured: true, syncing: true,
        settingsConflict: true), '正在同步…'),
    (const SyncEngineStatus(configured: true, errorKind: SyncErrorKind.network,
        settingsConflict: true), '上次同步失败——打开查看详情。'),
  ]) {
    testWidgets('settings shows current sync state before old conflicts: ${entry.$2}',
        (tester) async {
      await _pumpSettings(tester, _Startup(), _Biometric(), syncStatus: entry.$1);
      final label = find.text(entry.$2);
      await tester.scrollUntilVisible(label, 240,
          scrollable: find.byType(Scrollable).first);
      expect(label, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('settings entry shows the unresolved settings conflict', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      _Startup(),
      _Biometric(),
      syncStatus: const SyncEngineStatus(
        configured: true,
        settingsConflict: true,
      ),
    );
    final label = find.text('两端设置均有改动，请先对比再选择上传或拉取。');
    await tester.scrollUntilVisible(
      label,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(label, findsOneWidget);
    expect(find.text('已是最新'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'legacy biometric setting is unavailable while startup verification is off',
    (tester) async {
      final startup = _Startup()..pin = '123456';
      final biometric = _Biometric();
      await _pumpSettings(tester, startup, biometric);
      final toggle = find.byKey(const ValueKey('biometric-unlock-switch'));
      await tester.ensureVisible(toggle);
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(tester.widget<Switch>(toggle).onChanged, isNull);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(biometric.enables, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('system prompt blocks conflicting changes until it finishes', (
    tester,
  ) async {
    final startup = _Startup();
    final biometric = _Biometric()
      ..enabled = false
      ..pendingEnable = Completer<bool>();
    await _pumpSettings(tester, startup, biometric);
    final bioToggle = find.byKey(const ValueKey('biometric-unlock-switch'));
    final parent = find.byKey(const ValueKey('startup-verification-switch'));
    await tester.ensureVisible(bioToggle);
    await tester.tap(bioToggle);
    await tester.pumpAndSettle();
    expect(biometric.enables, 1);
    expect(tester.widget<Switch>(parent).onChanged, isNull);
    expect(tester.widget<Switch>(bioToggle).onChanged, isNull);
    biometric.pendingEnable!.complete(true);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(parent).onChanged, isNotNull);
    expect(tester.widget<Switch>(bioToggle).value, isTrue);
    expect(startup.writes, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'failed credential cleanup keeps the parent and child visibly on',
    (tester) async {
      final startup = _Startup();
      final biometric = _Biometric()..failDelete = true;
      await _pumpSettings(tester, startup, biometric);
      final parent = find.byKey(const ValueKey('startup-verification-switch'));
      final bioToggle = find.byKey(const ValueKey('biometric-unlock-switch'));
      await tester.ensureVisible(parent);
      await tester.tap(parent);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(startup.writes, 0);
      expect(tester.widget<Switch>(parent).value, isTrue);
      expect(tester.widget<Switch>(bioToggle).value, isTrue);
      final l = AppLocalizations.of(
        tester.element(find.byType(SettingsScreen)),
      );
      expect(find.text(l.settingsStartupVerificationError), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
      final biometric = _Biometric();
      final container = ProviderContainer(
        overrides: [
          storageProvider.overrideWithValue(
            MemoryStorageProvider('${temp.path}/maFiles'),
          ),
          appControllerProvider.overrideWith(_Unlocked.new),
          startupUnlockProvider.overrideWithValue(startup),
          biometricUnlockProvider.overrideWithValue(biometric),
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
      final bioToggle = find.byKey(const ValueKey('biometric-unlock-switch'));
      await tester.ensureVisible(toggle);
      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(tester.widget<Switch>(bioToggle).value, isTrue);
      expect(
        find
            .ancestor(of: toggle, matching: find.byType(AvaPanel))
            .evaluate()
            .single,
        same(
          find
              .ancestor(of: bioToggle, matching: find.byType(AvaPanel))
              .evaluate()
              .single,
        ),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(SettingsScreen)),
      );
      expect(find.text(l.settingsStartupVerificationDisable), findsOneWidget);
      await tester.tap(find.text(l.commonCancel));
      await tester.pumpAndSettle();
      expect(startup.writes, 0);
      expect(biometric.disables, 0);
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
      expect(biometric.enabled, isFalse);
      expect(tester.widget<Switch>(bioToggle).value, isFalse);
      expect(tester.widget<Switch>(bioToggle).onChanged, isNull);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(startup.writes, 2);
      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(tester.widget<Switch>(bioToggle).value, isFalse);
      expect(tester.widget<Switch>(bioToggle).onChanged, isNotNull);
      expect(biometric.enables, 0);
      // Re-enabling the parent leaves system unlock off until explicitly
      // enabled and approved in the system authentication prompt again.
      await tester.ensureVisible(bioToggle);
      await tester.tap(bioToggle);
      await tester.pumpAndSettle();
      expect(biometric.enables, 1);
      expect(tester.widget<Switch>(bioToggle).value, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
