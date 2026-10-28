import 'dart:async';
import 'dart:io';

import 'package:ava/src/core/fork_update.dart';
import 'package:ava/src/services/fork_update_installer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ava/app_update/test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  VerifiedForkUpdate update(ForkUpdateTarget target) => VerifiedForkUpdate(
    file: File('verified-update'),
    release: ForkUpdateRelease(
      target: target,
      tag: 'v1.5.2+100042',
      version: '1.5.2',
      buildNumber: 100042,
      notes: '',
      releaseUrl: Uri.parse(
        'https://github.com/gooesman/AnotherVaporAuth/releases/tag/v1.5.2+100042',
      ),
      asset: ForkUpdateAsset(
        name: 'test',
        url: Uri.parse('https://github.com/test'),
        size: 1,
        sha256: null,
      ),
    ),
  );

  test(
    'Windows verifies, launches interactively and closes in that order',
    () async {
      final events = <String>[];
      final installer = ForkUpdateInstaller(
        operatingSystem: 'windows',
        verify: (_) async => events.add('verify'),
        launchWindows: (_, _) async => events.add('launch'),
        closeWindows: () async => events.add('close'),
      );
      expect(await installer.canInstall(ForkUpdateTarget.windowsX64), isTrue);
      expect(events, isEmpty);
      await installer.install(update(ForkUpdateTarget.windowsX64));
      expect(events, ['verify', 'launch', 'close']);
    },
  );

  test('changed download never launches or closes Windows', () async {
    final events = <String>[];
    final installer = ForkUpdateInstaller(
      operatingSystem: 'windows',
      verify: (_) async =>
          throw const ForkUpdateException(ForkUpdateErrorCode.hashMismatch),
      launchWindows: (_, _) async => events.add('launch'),
      closeWindows: () async => events.add('close'),
    );
    await expectLater(
      installer.install(update(ForkUpdateTarget.windowsX64)),
      throwsA(isA<ForkUpdateException>()),
    );
    expect(events, isEmpty);
  });

  test(
    'Windows update passes the running directory as one literal argument',
    () async {
      final package = update(ForkUpdateTarget.windowsX64);
      final installer = ForkUpdateInstaller(
        operatingSystem: 'windows',
        windowsExecutable: r'D:\游戏工具 & apps\GooeSteamKit\ava.exe',
        windowsEnvironment: const {},
        verify: (_) async {},
        launchWindows: (path, arguments) async {
          expect(path, package.file.absolute.path);
          expect(arguments, [r'--install-dir=D:\游戏工具 & apps\GooeSteamKit']);
        },
        closeWindows: () async {},
      );
      await installer.install(package);
    },
  );

  test(
    'packed portable update does not target its temporary extraction',
    () async {
      final installer = ForkUpdateInstaller(
        operatingSystem: 'windows',
        windowsExecutable: r'C:\Temp\ns123\ava\ava.exe',
        windowsEnvironment: const {'AVA_PORTABLE_ROOT': r'D:\Portable'},
        verify: (_) async {},
        launchWindows: (_, arguments) async => expect(arguments, isEmpty),
        closeWindows: () async {},
      );
      await installer.install(update(ForkUpdateTarget.windowsX64));
    },
  );

  test('launch failure leaves Windows open', () async {
    var closed = false;
    final installer = ForkUpdateInstaller(
      operatingSystem: 'windows',
      verify: (_) async {},
      launchWindows: (_, _) async =>
          throw const ProcessException('test', [], 'failed'),
      closeWindows: () async => closed = true,
    );
    await expectLater(
      installer.install(update(ForkUpdateTarget.windowsX64)),
      throwsA(
        isA<ForkUpdateInstallException>().having(
          (e) => e.code,
          'code',
          'installer_unavailable',
        ),
      ),
    );
    expect(closed, isFalse);
  });

  test('wrong platform rejects before verification', () async {
    var verified = false;
    final installer = ForkUpdateInstaller(
      operatingSystem: 'linux',
      verify: (_) async => verified = true,
    );
    await expectLater(
      installer.install(update(ForkUpdateTarget.windowsX64)),
      throwsA(isA<ForkUpdateInstallException>()),
    );
    await expectLater(
      installer.openInstallPermissionSettings(),
      throwsA(isA<ForkUpdateInstallException>()),
    );
    expect(verified, isFalse);
  });

  test('Android permission query and settings never install', () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return call.method == 'canInstall' ? false : null;
    });
    final installer = ForkUpdateInstaller(
      operatingSystem: 'android',
      channel: channel,
    );
    expect(await installer.canInstall(ForkUpdateTarget.androidArm64), isFalse);
    await installer.openInstallPermissionSettings();
    expect(methods, ['canInstall', 'openInstallPermissionSettings']);
  });

  test('Android verifies then passes only the absolute file path', () async {
    final events = <String>[];
    final apk = update(ForkUpdateTarget.androidArm64);
    messenger.setMockMethodCallHandler(channel, (call) async {
      events.add(call.method);
      expect(call.arguments, {
        'path': apk.file.absolute.path,
        'version': apk.release.version,
        'buildNumber': apk.release.buildNumber,
      });
      return null;
    });
    final installer = ForkUpdateInstaller(
      operatingSystem: 'android',
      channel: channel,
      verify: (_) async => events.add('verify'),
    );
    await installer.install(apk);
    expect(events, ['verify', 'install']);
  });

  for (final code in [
    'signature_mismatch',
    'wrong_package',
    'install_permission_required',
  ]) {
    test('native $code remains actionable without exposing paths', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async =>
            throw PlatformException(code: code, message: 'private/path'),
      );
      final installer = ForkUpdateInstaller(
        operatingSystem: 'android',
        channel: channel,
        verify: (_) async {},
      );
      await expectLater(
        installer.install(update(ForkUpdateTarget.androidArm64)),
        throwsA(
          isA<ForkUpdateInstallException>()
              .having((e) => e.code, 'code', code)
              .having(
                (e) => e.toString(),
                'description',
                isNot(contains('private/path')),
              ),
        ),
      );
    });
  }

  test('concurrent installs rejected while first is verifying', () async {
    final verified = Completer<void>();
    var launched = 0;
    final installer = ForkUpdateInstaller(
      operatingSystem: 'windows',
      verify: (_) => verified.future,
      launchWindows: (_, _) async => launched++,
      closeWindows: () async {},
    );
    final first = installer.install(update(ForkUpdateTarget.windowsX64));
    await expectLater(
      installer.install(update(ForkUpdateTarget.windowsX64)),
      throwsA(
        isA<ForkUpdateInstallException>().having(
          (e) => e.code,
          'code',
          'install_in_progress',
        ),
      ),
    );
    verified.complete();
    await first;
    expect(launched, 1);
  });
}
