import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ava/src/app/account_name_mode.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'home_screen_dashboard_test.dart'
    show dashboardHomePreviewApp, homePreviewAccounts, pumpDashboardHome;

class _TemporaryStorage extends StorageProvider {
  _TemporaryStorage(this.directory);
  final Directory directory;
  @override
  Future<String> maFilesDir() async => p.join(directory.path, 'maFiles');
}

class _DelayedSettings extends SettingsStore {
  _DelayedSettings(super.storage);
  final loaded = Completer<String?>();
  @override
  Future<String?> loadAccountNameMode() => loaded.future;
}

class _ObservedSettings extends SettingsStore {
  _ObservedSettings(super.storage);
  Future<String?>? firstNameRead;

  @override
  Future<String?> loadAccountNameMode() {
    final read = super.loadAccountNameMode();
    firstNameRead ??= read;
    return read;
  }
}

File _settingsFile(Directory directory) =>
    File(p.join(directory.path, 'app_settings.json'));

Future<void> _persisted(
  WidgetTester tester,
  Directory directory,
  String mode,
) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < const Duration(seconds: 3)) {
    await tester.pump();
    final persisted = await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final file = _settingsFile(directory);
      if (!await file.exists()) return false;
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data['account_name_mode'] == mode;
    });
    if (persisted == true) return;
  }
  fail('The selected account name mode was not persisted: $mode');
}

void main() {
  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'Android' : 'Windows'} name mode is shared and survives a fresh app/settings instance',
      (tester) async {
        final directory = await tester.runAsync(
          () => Directory.systemTemp.createTemp('ava_name_mode_'),
        );
        addTearDown(() => directory!.delete(recursive: true));
        tester.view.physicalSize = mobile
            ? const Size(393, 852)
            : const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final accounts = [
          for (final account in homePreviewAccounts)
            SteamGuardAccount.fromJson(account.toJson()),
        ];
        // Flutter's Ahem font gives every character a full-em width. Short
        // synthetic labels keep this persistence test independent of fonts.
        accounts[0]
          ..accountName = 'main'
          ..personaName = '甲';
        accounts[1]
          ..accountName = 'trade'
          ..personaName = '乙';
        accounts[2].accountName = 'backup';
        accounts.last.personaName = null;
        final storage = _TemporaryStorage(directory!);
        await tester.runAsync(() async {
          final seed = SettingsStore(storage);
          await seed.saveTutorialSeen();
          await seed.saveDashboardSections([]);
        });

        Future<void> openHome() async {
          // Both objects are new on every open: no Riverpod or SettingsStore
          // cache can supply the remembered choice after this simulated exit.
          await tester.pumpWidget(const SizedBox.shrink());
          final settings = SettingsStore(_TemporaryStorage(directory));
          await tester.runAsync(() => settings.loadAccountNameMode());
          await tester.pumpWidget(
            dashboardHomePreviewApp(
              variant: AvaThemeVariant.light,
              mobile: mobile,
              settings: settings,
              accounts: accounts,
            ),
          );
          await pumpDashboardHome(tester);
        }

        Future<void> switchMode(String expected) async {
          await tester.tap(find.byIcon(Icons.swap_horiz));
          await _persisted(tester, directory, expected);
          await pumpDashboardHome(tester);
        }

        AccountNameMode selectedMode() => ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        ).read(accountNameModeProvider);

        await openHome();
        expect(find.text('main'), findsNWidgets(2));
        await switchMode('persona');
        expect(find.text('甲'), findsNWidgets(2));
        expect(find.text('乙'), findsOneWidget);
        await tester.tap(find.text('乙'));
        await pumpDashboardHome(tester);
        expect(find.text('乙'), findsNWidgets(2));
        expect(find.text('甲'), findsOneWidget);

        // No nickname falls back for this account without changing the mode
        // used by other accounts or the next app launch.
        await tester.tap(find.text('backup'));
        await pumpDashboardHome(tester);
        expect(find.text('backup'), findsNWidgets(2));
        expect(selectedMode(), AccountNameMode.persona);
        await openHome();
        expect(selectedMode(), AccountNameMode.persona);
        expect(find.text('甲'), findsNWidgets(2));

        await switchMode('id');
        expect(find.text('${accounts.first.steamId}'), findsNWidgets(2));
        expect(find.text('${accounts[1].steamId}'), findsOneWidget);
        await tester.tap(find.text('${accounts[1].steamId}'));
        await pumpDashboardHome(tester);
        expect(find.text('${accounts[1].steamId}'), findsNWidgets(2));
        await openHome();
        expect(selectedMode(), AccountNameMode.id);
        expect(find.text('${accounts.first.steamId}'), findsNWidgets(2));
        expect(find.text('main'), findsNothing);
        expect(find.text('甲'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test(
    'a delayed initial read cannot replace the mode selected by the user',
    () async {
      final directory = await Directory.systemTemp.createTemp('ava_name_mode_');
      addTearDown(() => directory.delete(recursive: true));
      final settings = _DelayedSettings(_TemporaryStorage(directory));
      final container = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(settings)],
      );
      addTearDown(container.dispose);
      expect(container.read(accountNameModeProvider), AccountNameMode.username);
      await container.read(accountNameModeProvider.notifier).cycle();
      settings.loaded.complete('id');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(accountNameModeProvider), AccountNameMode.persona);
      expect(
        await SettingsStore(_TemporaryStorage(directory)).loadAccountNameMode(),
        'persona',
      );
    },
  );

  test(
    'rapid successive changes persist the last choice for a new provider',
    () async {
      final directory = await Directory.systemTemp.createTemp('ava_name_mode_');
      addTearDown(() => directory.delete(recursive: true));
      final settings = SettingsStore(_TemporaryStorage(directory));
      final container = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(settings)],
      );
      final controller = container.read(accountNameModeProvider.notifier);
      final writes = [for (var i = 0; i < 10; i++) controller.cycle()];
      expect(container.read(accountNameModeProvider), AccountNameMode.persona);
      await Future.wait(writes);
      container.dispose();
      final reopened = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(
            SettingsStore(_TemporaryStorage(directory)),
          ),
        ],
      );
      addTearDown(reopened.dispose);
      final restored = Completer<void>();
      final subscription = reopened.listen(accountNameModeProvider, (_, mode) {
        if (mode == AccountNameMode.persona && !restored.isCompleted) {
          restored.complete();
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);
      await restored.future.timeout(const Duration(seconds: 3));
      expect(reopened.read(accountNameModeProvider), AccountNameMode.persona);
      final stored = jsonDecode(await _settingsFile(directory).readAsString());
      expect(stored['account_name_mode'], 'persona');
    },
  );

  for (final value in [null, 'unsupported', 42]) {
    test(
      'missing or invalid account name mode ($value) defaults to username',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'ava_name_mode_',
        );
        addTearDown(() => directory.delete(recursive: true));
        await _settingsFile(
          directory,
        ).writeAsString(jsonEncode({'account_name_mode': ?value}));
        final settings = _ObservedSettings(_TemporaryStorage(directory));
        final container = ProviderContainer(
          overrides: [settingsStoreProvider.overrideWithValue(settings)],
        );
        addTearDown(container.dispose);
        expect(
          container.read(accountNameModeProvider),
          AccountNameMode.username,
        );
        // Await the actual read started by provider.build. A second load can
        // finish first and leave the original Windows file handle open when
        // teardown tries to remove this temporary directory.
        await settings.firstNameRead!;
        expect(
          container.read(accountNameModeProvider),
          AccountNameMode.username,
        );
      },
    );
  }
}
