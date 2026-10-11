import 'dart:async';
import 'dart:io';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/fork_update.dart';
import 'package:ava/src/core/models/manifest.dart';
import 'package:ava/src/core/update_check.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/fork_update_installer.dart';
import 'package:ava/src/services/fork_update_service.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/fork_update_screen.dart';
import 'package:ava/src/ui/settings_screen.dart';
import 'package:ava/src/ui/widgets/update_banner.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

ForkUpdateRelease _release({
  ForkUpdateTarget target = ForkUpdateTarget.androidArm64,
  int size = 100,
}) => ForkUpdateRelease(
  target: target,
  tag: 'v1.5.1+161',
  version: '1.5.1',
  buildNumber: 161,
  notes: 'Smaller phone home.\nInventory price lookup improvements.',
  releaseUrl: Uri.parse(
    'https://github.com/gooesman/AnotherVaporAuth/releases/tag/v1.5.1%2B161',
  ),
  asset: ForkUpdateAsset(
    name: 'ava-fork-android-arm64.apk',
    url: Uri.parse(
      'https://github.com/gooesman/AnotherVaporAuth/releases/download/v1.5.1%2B161/ava-fork-android-arm64.apk',
    ),
    size: size,
    sha256: 'a' * 64,
  ),
);

class _Service extends ForkUpdateService {
  _Service(this.result);
  ForkUpdateCheck result;
  int checks = 0;
  int downloads = 0;
  String? currentVersion;
  String? currentBuild;
  Object? checkError;
  Completer<ForkUpdateCheck>? pendingCheck;
  Object? downloadError;
  Completer<VerifiedForkUpdate>? pendingDownload;
  CancelToken? downloadCancel;
  void Function(int, int)? progress;

  @override
  Future<ForkUpdateCheck> check({
    required ForkUpdateTarget target,
    required String currentVersion,
    required String currentBuild,
  }) async {
    checks++;
    this.currentVersion = currentVersion;
    this.currentBuild = currentBuild;
    if (checkError != null) throw checkError!;
    if (pendingCheck case final pending?) return pending.future;
    return result;
  }

  @override
  Future<VerifiedForkUpdate> download(
    ForkUpdateRelease release, {
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    downloads++;
    downloadCancel = cancelToken;
    progress = onProgress;
    if (downloadError != null) throw downloadError!;
    if (pendingDownload case final pending?) return pending.future;
    return VerifiedForkUpdate(
      file: File('synthetic-never-install.apk'),
      release: release,
    );
  }
}

class _Installer extends ForkUpdateInstaller {
  bool permission = true;
  int permissionRequests = 0;
  int installs = 0;
  Object? error;
  VerifiedForkUpdate? installed;

  @override
  Future<bool> canInstall(ForkUpdateTarget target) async => permission;

  @override
  Future<void> openInstallPermissionSettings() async {
    permissionRequests++;
  }

  @override
  Future<void> install(VerifiedForkUpdate update) async {
    if (error != null) throw error!;
    installs++;
    installed = update;
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

Future<void> _show(
  WidgetTester tester,
  _Service service,
  _Installer installer, {
  ForkUpdateTarget? target = ForkUpdateTarget.androidArm64,
  Widget home = const ForkUpdateScreen(),
  AvaThemeVariant variant = AvaThemeVariant.light,
  double width = 393,
  double textScale = 1,
  Locale locale = const Locale('en'),
  Future<void> Function()? prepareNetwork,
}) async {
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        forkUpdateServiceProvider.overrideWithValue(service),
        forkUpdateInstallerProvider.overrideWithValue(installer),
        forkUpdatePrepareNetworkProvider.overrideWithValue(
          prepareNetwork ?? () async {},
        ),
        forkUpdateTargetProvider.overrideWithValue(target),
        forkUpdatePackageInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'AVA Fork',
            packageName: 'pro.dotslash.ava.fork',
            version: '1.5.0',
            buildNumber: '150',
          ),
        ),
        storageProvider.overrideWithValue(MemoryStorageProvider()),
        appControllerProvider.overrideWith(_Unlocked.new),
      ],
      child: MaterialApp(
        theme: buildAvaTheme(variant).copyWith(
          platform: target == ForkUpdateTarget.windowsX64
              ? TargetPlatform.windows
              : TargetPlatform.android,
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

_Service _available({
  ForkUpdateTarget target = ForkUpdateTarget.androidArm64,
  int size = 100,
}) => _Service(
  ForkUpdateCheck(
    status: ForkUpdateCheckStatus.available,
    release: _release(target: target, size: size),
  ),
);

void main() {
  testWidgets('refreshes routing before checking and downloading', (
    tester,
  ) async {
    final service = _available();
    final checkReady = Completer<void>();
    final downloadReady = Completer<void>();
    var preparations = 0;
    await _show(
      tester,
      service,
      _Installer(),
      prepareNetwork: () {
        preparations++;
        return preparations == 1 ? checkReady.future : downloadReady.future;
      },
    );
    expect(preparations, 1);
    expect(service.checks, 0);
    checkReady.complete();
    await tester.pump();
    expect(service.checks, 1);
    await _tap(tester, 'fork-update-download');
    expect(preparations, 2);
    expect(service.downloads, 0);
    await _tap(tester, 'fork-update-cancel-download');
    downloadReady.complete();
    await tester.pump();
    expect(service.downloads, 0);
    expect(find.byKey(const ValueKey('fork-update-install')), findsNothing);
  });

  testWidgets(
    'checking state disables repeated checks and exposes no download',
    (tester) async {
      final pending = Completer<ForkUpdateCheck>();
      final service = _available()..pendingCheck = pending;
      await _show(tester, service, _Installer());
      final l = AppLocalizations.of(
        tester.element(find.byType(ForkUpdateScreen)),
      );
      expect(find.text(l.forkUpdateChecking), findsOneWidget);
      final check = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('fork-update-check')),
      );
      expect(check.onPressed, isNull);
      expect(find.byKey(const ValueKey('fork-update-download')), findsNothing);
      pending.complete(service.result);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('fork-update-download')),
        findsOneWidget,
      );
    },
  );

  for (final status in [
    ForkUpdateCheckStatus.noRelease,
    ForkUpdateCheckStatus.upToDate,
    ForkUpdateCheckStatus.noCompatibleAsset,
    ForkUpdateCheckStatus.unverifiable,
    ForkUpdateCheckStatus.invalidMetadata,
    ForkUpdateCheckStatus.networkError,
  ]) {
    testWidgets('$status is explicit and cannot download or install', (
      tester,
    ) async {
      final service = _Service(ForkUpdateCheck(status: status));
      final installer = _Installer();
      await _show(tester, service, installer);
      final l = AppLocalizations.of(
        tester.element(find.byType(ForkUpdateScreen)),
      );
      final message = switch (status) {
        ForkUpdateCheckStatus.noRelease => l.forkUpdateNoRelease,
        ForkUpdateCheckStatus.upToDate => l.forkUpdateUpToDate,
        ForkUpdateCheckStatus.noCompatibleAsset =>
          l.forkUpdateNoCompatibleAsset,
        ForkUpdateCheckStatus.unverifiable => l.forkUpdateUnverifiable,
        ForkUpdateCheckStatus.invalidMetadata => l.forkUpdateInvalidMetadata,
        _ => l.forkUpdateCheckFailed,
      };
      expect(find.text(message), findsOneWidget);
      expect(find.byKey(const ValueKey('fork-update-download')), findsNothing);
      expect(find.byKey(const ValueKey('fork-update-install')), findsNothing);
      expect(service.downloads, 0);
      expect(installer.installs, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unsupported target makes no release request', (tester) async {
    final service = _available();
    await _show(tester, service, _Installer(), target: null);
    expect(service.checks, 0);
    expect(find.byKey(const ValueKey('fork-update-download')), findsNothing);
  });

  testWidgets(
    'check failures are retryable and pass the installed version/build',
    (tester) async {
      final service = _available()..checkError = StateError('offline');
      await _show(tester, service, _Installer());
      expect(find.byKey(const ValueKey('fork-update-download')), findsNothing);
      service.checkError = null;
      await _tap(tester, 'fork-update-check');
      expect(service.checks, 2);
      expect(service.currentVersion, '1.5.0');
      expect(service.currentBuild, '150');
      expect(find.textContaining('v1.5.1+161'), findsOneWidget);
      expect(find.textContaining('Inventory price lookup'), findsOneWidget);
      expect(service.downloads, 0);
    },
  );

  testWidgets(
    'verified download never auto-installs and confirmation can be cancelled',
    (tester) async {
      final service = _available();
      final installer = _Installer();
      await _show(tester, service, installer);
      await _tap(tester, 'fork-update-download');
      expect(service.downloads, 1);
      expect(installer.installs, 0);
      await _tap(tester, 'fork-update-install');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(installer.installs, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(installer.installs, 0);
      await _tap(tester, 'fork-update-install');
      await _tap(tester, 'fork-update-install-confirm');
      expect(installer.installs, 1);
      expect(installer.installed!.release.tag, 'v1.5.1+161');
    },
  );

  testWidgets('progress cancel rejects even a late successful result', (
    tester,
  ) async {
    final pending = Completer<VerifiedForkUpdate>();
    final service = _available()..pendingDownload = pending;
    final installer = _Installer();
    await _show(tester, service, installer);
    await _tap(tester, 'fork-update-download');
    service.progress!(42, 100);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('42%'), findsOneWidget);
    await _tap(tester, 'fork-update-cancel-download');
    expect(service.downloadCancel!.isCancelled, isTrue);
    pending.complete(
      VerifiedForkUpdate(file: File('synthetic-late.apk'), release: _release()),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('fork-update-install')), findsNothing);
    expect(find.byKey(const ValueKey('fork-update-download')), findsOneWidget);
    expect(installer.installs, 0);
  });

  testWidgets('chunk bursts repaint at most four times per second with recent '
      'speed and ETA, then clear stalled estimates', (tester) async {
    const mib = 1024 * 1024;
    final service = _available(size: 10 * mib)
      ..pendingDownload = Completer<VerifiedForkUpdate>();
    await _show(tester, service, _Installer());
    await _tap(tester, 'fork-update-download');
    var rebuilds = 0;
    final previousRebuildHook = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is ForkUpdateScreen) rebuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousRebuildHook);
    // 200 transport callbacks in two seconds, observed across 200 frames.
    for (var chunk = 1; chunk <= 200; chunk++) {
      service.progress!(chunk * mib ~/ 100, 10 * mib);
      await tester.pump(const Duration(milliseconds: 10));
    }
    debugOnRebuildDirtyWidget = previousRebuildHook;
    expect(rebuilds, inInclusiveRange(1, 8));
    expect(find.text('2.0 / 10.0 MiB'), findsOneWidget);
    expect(find.text('1.0 MiB/s'), findsOneWidget);
    expect(find.text('About 8s left'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    final l = AppLocalizations.of(
      tester.element(find.byType(ForkUpdateScreen)),
    );
    expect(find.text(l.forkUpdateWaitingForData), findsOneWidget);
    expect(find.byKey(const ValueKey('fork-update-remaining')), findsNothing);
    await _tap(tester, 'fork-update-cancel-download');
    expect(tester.takeException(), isNull);
  });

  testWidgets('complete bytes show verification until the service succeeds', (
    tester,
  ) async {
    const mib = 1024 * 1024;
    final pending = Completer<VerifiedForkUpdate>();
    final service = _available(size: 2 * mib)..pendingDownload = pending;
    await _show(tester, service, _Installer());
    await _tap(tester, 'fork-update-download');
    service.progress!(2 * mib, 2 * mib);
    await tester.pump(const Duration(milliseconds: 250));
    final l = AppLocalizations.of(
      tester.element(find.byType(ForkUpdateScreen)),
    );
    expect(find.text(l.forkUpdateVerifying), findsOneWidget);
    expect(find.text('2.0 / 2.0 MiB'), findsOneWidget);
    expect(find.byKey(const ValueKey('fork-update-speed')), findsNothing);
    expect(find.byKey(const ValueKey('fork-update-install')), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(l.forkUpdateVerifying), findsOneWidget);
    pending.complete(
      VerifiedForkUpdate(
        file: File('synthetic-verified.apk'),
        release: service.result.release!,
      ),
    );
    await tester.pump();
    expect(find.text(l.forkUpdateVerifying), findsNothing);
    expect(find.text(l.forkUpdateReady), findsOneWidget);
    expect(find.byKey(const ValueKey('fork-update-install')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'retry resets progress and ignores the cancelled download callbacks',
    (tester) async {
      const mib = 1024 * 1024;
      final oldPending = Completer<VerifiedForkUpdate>();
      final service = _available(size: 8 * mib)..pendingDownload = oldPending;
      await _show(tester, service, _Installer());
      await _tap(tester, 'fork-update-download');
      final oldProgress = service.progress!;
      oldProgress(4 * mib, 8 * mib);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('4.0 / 8.0 MiB'), findsOneWidget);
      // Leave one sample queued when cancelling; its timer must not affect retry.
      oldProgress(6 * mib, 8 * mib);
      await _tap(tester, 'fork-update-cancel-download');
      final nextPending = Completer<VerifiedForkUpdate>();
      service.pendingDownload = nextPending;
      await _tap(tester, 'fork-update-download');
      expect(find.text('0.0 / 8.0 MiB'), findsOneWidget);
      oldProgress(8 * mib, 8 * mib);
      oldPending.complete(
        VerifiedForkUpdate(
          file: File('synthetic-cancelled.apk'),
          release: service.result.release!,
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('0.0 / 8.0 MiB'), findsOneWidget);
      expect(find.byKey(const ValueKey('fork-update-install')), findsNothing);
      service.progress!(2 * mib, 8 * mib);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('2.0 / 8.0 MiB'), findsOneWidget);
      await _tap(tester, 'fork-update-cancel-download');
      expect(service.downloadCancel!.isCancelled, isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.byKey(const ValueKey('fork-update-transfer-size')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in [
    const Locale('en'),
    const Locale('zh'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    const Locale('de'),
    const Locale('fr'),
    const Locale('es'),
    const Locale('ru'),
  ]) {
    testWidgets('download statistics fit narrow large-text phone in $locale', (
      tester,
    ) async {
      const mib = 1024 * 1024;
      final service = _available(size: 100 * mib)
        ..pendingDownload = Completer<VerifiedForkUpdate>();
      await _show(
        tester,
        service,
        _Installer(),
        width: 320,
        textScale: 1.8,
        locale: locale,
      );
      await _tap(tester, 'fork-update-download');
      service.progress!(128 * 1024, 100 * mib);
      await tester.pump(const Duration(milliseconds: 250));
      final speed = tester.widget<Text>(
        find.byKey(const ValueKey('fork-update-speed')),
      );
      expect(speed.data, contains('KiB'));
      expect(
        find.byKey(const ValueKey('fork-update-remaining')),
        findsOneWidget,
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(ForkUpdateScreen)),
      );
      expect(find.text(l.forkUpdateConnectionHint), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tap(tester, 'fork-update-cancel-download');
    });
  }

  testWidgets(
    'leaving the screen cancels download without late state updates',
    (tester) async {
      final pending = Completer<VerifiedForkUpdate>();
      final service = _available()..pendingDownload = pending;
      await _show(tester, service, _Installer());
      await _tap(tester, 'fork-update-download');
      service.progress!(42, 100);
      await tester.pumpWidget(const SizedBox());
      expect(service.downloadCancel!.isCancelled, isTrue);
      service.progress!(90, 100);
      pending.complete(
        VerifiedForkUpdate(
          file: File('synthetic-late.apk'),
          release: _release(),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed hash blocks installation and offers a fresh download', (
    tester,
  ) async {
    final service = _available()
      ..downloadError = ForkUpdateException(ForkUpdateErrorCode.hashMismatch);
    final installer = _Installer();
    await _show(tester, service, installer);
    await _tap(tester, 'fork-update-download');
    final l = AppLocalizations.of(
      tester.element(find.byType(ForkUpdateScreen)),
    );
    expect(find.text(l.forkUpdateHashFailed), findsOneWidget);
    expect(find.byKey(const ValueKey('fork-update-install')), findsNothing);
    expect(installer.installs, 0);
    service.downloadError = null;
    await _tap(tester, 'fork-update-download');
    expect(service.downloads, 2);
    expect(find.byKey(const ValueKey('fork-update-install')), findsOneWidget);
  });

  testWidgets(
    'network download failures remain retryable without installation',
    (tester) async {
      final service = _available()
        ..downloadError = const ForkUpdateException(
          ForkUpdateErrorCode.networkError,
        );
      final installer = _Installer();
      await _show(tester, service, installer);
      await _tap(tester, 'fork-update-download');
      final l = AppLocalizations.of(
        tester.element(find.byType(ForkUpdateScreen)),
      );
      expect(find.text(l.forkUpdateDownloadFailed), findsOneWidget);
      expect(find.byKey(const ValueKey('fork-update-install')), findsNothing);
      expect(installer.installs, 0);
      service.downloadError = null;
      await _tap(tester, 'fork-update-download');
      expect(service.downloads, 2);
      expect(find.byKey(const ValueKey('fork-update-install')), findsOneWidget);
    },
  );

  testWidgets(
    'Android permission settings never start installation automatically',
    (tester) async {
      final installer = _Installer()..permission = false;
      await _show(tester, _available(), installer);
      await _tap(tester, 'fork-update-download');
      await _tap(tester, 'fork-update-install');
      expect(find.byType(AlertDialog), findsNothing);
      await _tap(tester, 'fork-update-permission');
      expect(installer.permissionRequests, 1);
      installer.permission = true;
      await tester.pump();
      expect(installer.installs, 0);
      await _tap(tester, 'fork-update-install');
      await _tap(tester, 'fork-update-install-confirm');
      expect(installer.installs, 1);
    },
  );

  testWidgets('installer signature mismatch removes the install action', (
    tester,
  ) async {
    final installer = _Installer()
      ..error = ForkUpdateInstallException('signature_mismatch');
    await _show(tester, _available(), installer);
    await _tap(tester, 'fork-update-download');
    await _tap(tester, 'fork-update-install');
    await _tap(tester, 'fork-update-install-confirm');
    final l = AppLocalizations.of(
      tester.element(find.byType(ForkUpdateScreen)),
    );
    expect(find.text(l.forkUpdateSignatureMismatch), findsOneWidget);
    expect(find.byKey(const ValueKey('fork-update-install')), findsNothing);
    expect(installer.installs, 0);
  });

  for (final variant in AvaThemeVariant.values) {
    testWidgets(
      'Windows installer confirmation fits $variant with large German text',
      (tester) async {
        final installer = _Installer();
        await _show(
          tester,
          _available(target: ForkUpdateTarget.windowsX64),
          installer,
          target: ForkUpdateTarget.windowsX64,
          variant: variant,
          width: 320,
          textScale: 1.8,
          locale: const Locale('de'),
        );
        await _tap(tester, 'fork-update-download');
        await _tap(tester, 'fork-update-install');
        final l = AppLocalizations.of(
          tester.element(find.byType(ForkUpdateScreen)),
        );
        expect(find.text(l.forkUpdateInstallWindows), findsOneWidget);
        expect(installer.installs, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('settings provides the manual update route', (tester) async {
    final service = _Service(
      const ForkUpdateCheck(status: ForkUpdateCheckStatus.noRelease),
    );
    await _show(tester, service, _Installer(), home: const SettingsScreen());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'fork-update-settings-open');
    expect(find.byType(ForkUpdateScreen), findsOneWidget);
    expect(service.checks, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fork never renders the upstream webpage update banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [updateDecisionProvider.overrideWith(_OldDecision.new)],
        child: MaterialApp(
          theme: buildAvaTheme(AvaThemeVariant.light),
          home: const Scaffold(body: UpdateBanner()),
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.textContaining('99.0.0'), findsNothing);
  });
}

class _OldDecision extends UpdateController {
  @override
  UpdateDecision build() =>
      const UpdateDecision(available: true, latest: '99.0.0');
}
