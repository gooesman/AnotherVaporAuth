import 'dart:io';

import 'package:ava_installer/engine.dart';
import 'package:ava_installer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late String fresh;
  late String legacy;
  late List<List<String>> queries;
  late Map<String, ProcessResult> registrations;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('steamkit_install_discovery_');
    fresh = p.join(tmp.path, 'Programs', 'GooeSteamKit');
    legacy = p.join(tmp.path, 'Programs', 'AVA');
    queries = [];
    registrations = {};
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  String existing(String dir) {
    Directory(p.join(dir, 'data')).createSync(recursive: true);
    File(p.join(dir, 'ava.exe')).writeAsStringSync('synthetic app');
    return dir;
  }

  void register(String product, String dir, {int exitCode = 0}) {
    registrations[product] = ProcessResult(1, exitCode, dir, '');
  }

  Future<ProcessResult> query(String executable, List<String> args) async {
    expect(executable, 'powershell');
    expect(args.length, 4);
    expect(args.take(3), ['-NoProfile', '-NonInteractive', '-Command']);
    final script = args.last;
    expect(
      script,
      contains(r'[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)'),
    );
    expect(script, contains(r"$key.GetValue('InstallLocation')"));
    expect(script, contains(r'[Console]::Out.Write($dir)'));
    final key = RegExp(
      r"OpenSubKey\('Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\(GooeSteamKit|AVA)'\)",
    ).firstMatch(script);
    expect(key, isNotNull);
    queries.add(args);
    return registrations[key!.group(1)] ??
        ProcessResult(1, 1, '', 'No registration');
  }

  Future<String> resolve([List<String> args = const []]) =>
      InstallEngine.resolveInstallDir(
        args,
        runProcess: query,
        freshInstallDir: fresh,
        legacyInstallDir: legacy,
      );

  test('explicit update path wins over registration and old default', () async {
    final target = existing(p.join(tmp.path, "我的 程序's", 'SteamKit'));
    register('AVA', existing(p.join(tmp.path, 'other registered install')));
    existing(legacy);
    expect(await resolve(['--auto', '--install-dir=$target']), target);
    expect(queries, isEmpty);
  });

  test(
    'invalid explicit targets fail without querying or falling back',
    () async {
      existing(legacy);
      register('AVA', legacy);
      final unrelated = Directory(p.join(tmp.path, 'unrelated'))..createSync();
      File(p.join(unrelated.path, 'notes.txt')).writeAsStringSync('keep');
      for (final target in [
        '',
        'relative',
        p.join(tmp.path, 'missing'),
        unrelated.path,
      ]) {
        await expectLater(resolve(['--install-dir=$target']), throwsStateError);
      }
      expect(queries, isEmpty);
      expect(
        File(p.join(unrelated.path, 'notes.txt')).readAsStringSync(),
        'keep',
      );
    },
  );

  test('conflicting explicit update directories fail', () async {
    final first = existing(p.join(tmp.path, 'one'));
    final second = existing(p.join(tmp.path, 'two'));
    await expectLater(
      resolve(['--install-dir=$first', '--install-dir=$second']),
      throwsStateError,
    );
  });

  test(
    'registered path retains characters outside the Windows code page',
    () async {
      final target = existing(
        p.join(tmp.path, '中文 软件目录', "𠮷 🦆 测试's & GooeSteamKit"),
      );
      register('AVA', target);
      expect(await resolve(), target);
      expect(queries.length, 2);
      for (final args in queries) {
        expect(args.last, isNot(contains(target)));
      }
    },
  );

  test('new registration is recognized before a legacy registration', () async {
    final target = existing(p.join(tmp.path, 'registered current'));
    register('GooeSteamKit', target);
    register('AVA', existing(legacy));
    expect(await resolve(), target);
    expect(queries.length, 1);
  });

  test(
    'stale and unrelated registrations fall back to old installed default',
    () async {
      register('GooeSteamKit', p.join(tmp.path, 'missing'));
      register(
        'AVA',
        (Directory(p.join(tmp.path, 'unrelated'))..createSync()).path,
      );
      existing(legacy);
      expect(await resolve(), legacy);
    },
  );

  test('failed registry query does not trust its output', () async {
    register('AVA', existing(p.join(tmp.path, 'not trusted')), exitCode: 1);
    expect(await resolve(), fresh);
  });

  test('fresh install uses branded default, without creating it', () async {
    register('AVA', p.join(tmp.path, 'missing'));
    expect(await resolve(), fresh);
    expect(Directory(fresh).existsSync(), isFalse);
  });

  test(
    'unavailable registry command falls back to installed old default',
    () async {
      existing(legacy);
      final target = await InstallEngine.resolveInstallDir(
        const [],
        runProcess: (exe, args) async => throw ProcessException(exe, args),
        freshInstallDir: fresh,
        legacyInstallDir: legacy,
      );
      expect(target, legacy);
    },
  );

  testWidgets('installer shows resolved existing path', (tester) async {
    tester.view.physicalSize = const Size(760, 460);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final target = existing(p.join(tmp.path, '自定义 软件目录'));
    await tester.pumpWidget(
      InstallerApp(
        uninstall: false,
        auto: false,
        staged: false,
        initialInstallDir: target,
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      target,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('discovery failure blocks installation even in auto mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 460);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const InstallerApp(
        uninstall: false,
        auto: true,
        staged: false,
        initializationError: 'Existing update target is missing.',
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Existing update target is missing.'), findsOneWidget);
    expect(find.text('INSTALL'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('uninstall does not use install discovery or its errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 460);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const InstallerApp(
        uninstall: true,
        auto: false,
        staged: false,
        initializationError: 'Not used during uninstall.',
      ),
    );
    expect(find.text('REMOVE GooeSteamKit FROM THIS MACHINE?'), findsOneWidget);
    expect(find.text('Not used during uninstall.'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
