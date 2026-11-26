import 'dart:convert';
import 'dart:io';

import 'package:ava_installer/engine.dart';
import 'package:ava_installer/windows_shortcuts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

String _quote(String text) => text.replaceAll("'", "''");

// Read actual .lnk files through the Unicode COM interface independently of the
// production helper; WScript.Shell loses paths outside the Windows code page.
const _unicodeShortcutReader = r'''
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
[ComImport, Guid("00021401-0000-0000-C000-000000000046")]
class TestShellLink {}
[ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface TestShellLinkW {
  void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder path, int capacity, IntPtr data, uint flags);
  void GetIDList(out IntPtr pidl);
  void SetIDList(IntPtr pidl);
  void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder text, int capacity);
  void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string text);
  void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder text, int capacity);
  void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string text);
  void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder text, int capacity);
  void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string text);
  void GetHotkey(out short key);
  void SetHotkey(short key);
  void GetShowCmd(out int show);
  void SetShowCmd(int show);
  void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder text, int capacity, out int index);
  void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string text, int index);
  void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string text, uint reserved);
  void Resolve(IntPtr window, uint flags);
  void SetPath([MarshalAs(UnmanagedType.LPWStr)] string text);
}
public sealed class TestShortcutInfo {
  public string Target;
  public string WorkDir;
  public string Icon;
}
public static class TestShortcutReader {
  public static TestShortcutInfo Read(string path) {
    var instance = new TestShellLink();
    try {
      ((IPersistFile)instance).Load(path, 0);
      var link = (TestShellLinkW)instance;
      var target = new StringBuilder(32768);
      var directory = new StringBuilder(32768);
      var icon = new StringBuilder(32768);
      int index;
      link.GetPath(target, target.Capacity, IntPtr.Zero, 0);
      link.GetWorkingDirectory(directory, directory.Capacity);
      link.GetIconLocation(icon, icon.Capacity, out index);
      return new TestShortcutInfo {
        Target = target.ToString(), WorkDir = directory.ToString(),
        Icon = icon.ToString() + "," + index
      };
    } finally { Marshal.FinalReleaseComObject(instance); }
  }
}
'@
''';

Future<String> _powershell(String script) async {
  final result = await Process.run(
    'powershell',
    [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      "\$ErrorActionPreference = 'Stop'; "
          '[Console]::OutputEncoding = [Text.UTF8Encoding]::new(\$false); '
          '\$ws = New-Object -ComObject WScript.Shell; $script',
    ],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError('Test shortcut operation failed: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

void main() {
  group('Windows shortcut migration', skip: !Platform.isWindows, () {
    late Directory tmp;
    late String programs;
    late String desktop;
    late String target;
    late String otherTarget;
    late String icon;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('steamkit_shortcuts_test_');
      // Hosted Windows runners expose TEMP via RUNNER~1; expectations use the
      // actual long name, while the dedicated regression below passes 8.3.
      tmp = Directory(await tmp.resolveSymbolicLinks());
      // PowerShell-sensitive characters are valid in user-selected paths.
      final root = p.join(tmp.path, "owner's \$apps ` directory");
      programs = p.join(root, 'Start menu');
      desktop = p.join(root, 'Desktop');
      target = p.join(root, 'AVA', 'ava.exe');
      otherTarget = p.join(root, 'Other install', 'ava.exe');
      icon = p.join(p.dirname(target), 'gooesteamkit-icon-fixture.ico');
      for (final path in [
        programs,
        desktop,
        p.dirname(target),
        p.dirname(otherTarget),
      ]) {
        await Directory(path).create(recursive: true);
      }
      await File(target).writeAsString('test fixture, not executable');
      await File(icon).writeAsString('inert icon fixture');
      await File(
        otherTarget,
      ).writeAsString('unrelated fixture, not executable');
    });

    tearDown(() async {
      // tmp is the exact fresh test directory; never a special user folder.
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<void> createLinks(Map<String, String> links) async {
      await _powershell(
        links.entries
            .map(
              (entry) =>
                  '''
\$link = \$ws.CreateShortcut('${_quote(entry.key)}')
\$link.TargetPath = '${_quote(entry.value)}'
\$link.Save()
''',
            )
            .join('\n'),
      );
    }

    Future<Map<String, dynamic>> readLink(String path) async {
      final json = await _powershell('''
$_unicodeShortcutReader
[TestShortcutReader]::Read('${_quote(path)}') | ConvertTo-Json -Compress
''');
      return jsonDecode(json) as Map<String, dynamic>;
    }

    Future<void> update({bool withDesktop = true, bool uninstall = false}) =>
        WindowsShortcuts.update(
          displayName: appDisplayName,
          target: target,
          workDir: p.dirname(target),
          iconPath: icon,
          desktopShortcut: withDesktop,
          uninstall: uninstall,
          programsDirectory: programs,
          desktopDirectory: desktop,
        );

    String current(String folder) => p.join(folder, '$appDisplayName.lnk');

    test(
      'non-code-page paths survive create, migration, update and uninstall',
      () async {
        final unicodeRoot = p.join(tmp.path, "中文 אב กข अआ 𠮷 🦆's & directory");
        programs = p.join(unicodeRoot, 'Start menu');
        desktop = p.join(unicodeRoot, 'Desktop');
        target = p.join(unicodeRoot, 'GooeSteamKit', 'ava.exe');
        icon = p.join(p.dirname(target), '图标-𠮷.ico');
        otherTarget = p.join(unicodeRoot, 'other install', 'ava.exe');
        final otherIcon = p.join(p.dirname(otherTarget), 'foreign.ico');
        for (final file in [target, icon, otherTarget, otherIcon]) {
          await File(file).parent.create(recursive: true);
          await File(file).writeAsString('inert Unicode fixture');
        }
        await update();
        for (final folder in [programs, desktop]) {
          expect(
            (await readLink(current(folder)))['Target'],
            equalsIgnoringCase(target),
          );
          await File(current(folder)).rename(p.join(folder, 'AVA.lnk'));
        }
        // Seed a different Unicode installation's link; our migration must leave it.
        await WindowsShortcuts.update(
          displayName: 'AVA-pc',
          target: otherTarget,
          workDir: p.dirname(otherTarget),
          iconPath: otherIcon,
          desktopShortcut: true,
          programsDirectory: programs,
          desktopDirectory: desktop,
        );
        await update();
        icon = p.join(p.dirname(target), '更新-🦆.ico');
        await File(icon).writeAsString('changed Unicode icon');
        await update(withDesktop: false);
        for (final folder in [programs, desktop]) {
          final link = await readLink(current(folder));
          expect(link['Target'], equalsIgnoringCase(target));
          expect(link['WorkDir'], equalsIgnoringCase(p.dirname(target)));
          expect(link['Icon'], equalsIgnoringCase('$icon,0'));
          expect(File(p.join(folder, 'AVA.lnk')).existsSync(), isFalse);
        }
        await update(uninstall: true);
        for (final folder in [programs, desktop]) {
          expect(File(current(folder)).existsSync(), isFalse);
          expect(
            (await readLink(p.join(folder, 'AVA-pc.lnk')))['Target'],
            equalsIgnoringCase(otherTarget),
          );
        }
        expect(File(target).existsSync(), isTrue);
        expect(File(otherTarget).existsSync(), isTrue);
      },
    );

    test(
      'migrates legacy names and retains usable target and distinct icon',
      () async {
        final legacy = {
          for (final folder in [programs, desktop])
            for (final name in ['AVA', 'AVA-pc', 'gooes SteamKit'])
              p.join(folder, '$name.lnk'): target,
        };
        await createLinks(legacy);
        await update();
        await update(); // Later upgrades are idempotent.

        for (final folder in [programs, desktop]) {
          expect(File(current(folder)).existsSync(), isTrue);
          final link = await readLink(current(folder));
          expect(link['Target'], equalsIgnoringCase(target));
          expect(link['WorkDir'], equalsIgnoringCase(p.dirname(target)));
          expect(link['Icon'], equalsIgnoringCase('$icon,0'));
        }
        for (final path in legacy.keys) {
          expect(File(path).existsSync(), isFalse);
        }
      },
    );

    test('preserves legacy links pointing to another installation', () async {
      final unrelated = {
        p.join(programs, 'AVA.lnk'): otherTarget,
        p.join(desktop, 'AVA-pc.lnk'): otherTarget,
      };
      await createLinks(unrelated);
      await update();

      for (final entry in unrelated.entries) {
        expect(File(entry.key).existsSync(), isTrue);
        expect(
          (await readLink(entry.key))['Target'],
          equalsIgnoringCase(entry.value),
        );
      }
      for (final folder in [programs, desktop]) {
        expect(File(current(folder)).existsSync(), isTrue);
      }
    });

    test('keeps same-name conflicts and their existing legacy entry', () async {
      final oldOwned = p.join(programs, 'AVA-pc.lnk');
      await createLinks({current(programs): otherTarget, oldOwned: target});
      await update();

      expect(
        (await readLink(current(programs)))['Target'],
        equalsIgnoringCase(otherTarget),
      );
      expect(File(oldOwned).existsSync(), isTrue);
      expect((await readLink(oldOwned))['Target'], equalsIgnoringCase(target));
      expect(File(current(desktop)).existsSync(), isTrue);
    });

    test('desktop opt-out still migrates an existing owned link', () async {
      final owned = p.join(desktop, 'AVA-pc.lnk');
      final unrelated = p.join(desktop, 'AVA.lnk');
      await createLinks({owned: target, unrelated: otherTarget});
      await update(withDesktop: false);

      expect(File(current(programs)).existsSync(), isTrue);
      expect(File(current(desktop)).existsSync(), isTrue);
      expect(
        (await readLink(current(desktop)))['Icon'],
        equalsIgnoringCase('$icon,0'),
      );
      expect(File(owned).existsSync(), isFalse);
      expect(File(unrelated).existsSync(), isTrue);
      expect(
        (await readLink(unrelated))['Target'],
        equalsIgnoringCase(otherTarget),
      );
    });

    test('desktop opt-out creates no link when there was none', () async {
      await update(withDesktop: false);
      expect(File(current(programs)).existsSync(), isTrue);
      expect(File(current(desktop)).existsSync(), isFalse);
    });

    test(
      'desktop opt-out refreshes the current owned link on icon change',
      () async {
        await update();
        icon = p.join(p.dirname(target), 'gooesteamkit-icon-changed.ico');
        await File(icon).writeAsString('updated inert icon fixture');
        await update(withDesktop: false);
        for (final folder in [programs, desktop]) {
          expect(
            (await readLink(current(folder)))['Icon'],
            equalsIgnoringCase('$icon,0'),
          );
        }
      },
    );

    test(
      'desktop opt-out preserves a name conflict and owned legacy link',
      () async {
        final oldOwned = p.join(desktop, 'gooes SteamKit.lnk');
        await createLinks({current(desktop): otherTarget, oldOwned: target});
        await update(withDesktop: false);
        expect(
          (await readLink(current(desktop)))['Target'],
          equalsIgnoringCase(otherTarget),
        );
        expect(File(oldOwned).existsSync(), isTrue);
      },
    );

    test(
      'missing or out-of-install icon leaves existing links untouched',
      () async {
        final oldOwned = p.join(programs, 'gooes SteamKit.lnk');
        await createLinks({oldOwned: target});
        await File(icon).delete();
        await expectLater(update(), throwsStateError);
        expect(File(oldOwned).existsSync(), isTrue);
        expect(File(current(programs)).existsSync(), isFalse);
        icon = p.join(p.dirname(otherTarget), 'foreign.ico');
        await File(icon).writeAsString('foreign icon fixture');
        await expectLater(update(), throwsStateError);
        expect(File(oldOwned).existsSync(), isTrue);
        expect(File(current(programs)).existsSync(), isFalse);
      },
    );

    test('uninstall cleans owned current and legacy links only', () async {
      final owned = {
        current(programs): target,
        p.join(programs, 'AVA.lnk'): target,
        p.join(programs, 'gooes SteamKit.lnk'): target,
        p.join(desktop, 'AVA-pc.lnk'): target,
      };
      final unrelated = {
        current(desktop): otherTarget,
        p.join(desktop, 'AVA.lnk'): otherTarget,
        p.join(programs, 'AVA-pc.lnk'): otherTarget,
      };
      await createLinks({...owned, ...unrelated});
      await update(uninstall: true);

      for (final path in owned.keys) {
        expect(File(path).existsSync(), isFalse);
      }
      for (final entry in unrelated.entries) {
        expect(File(entry.key).existsSync(), isTrue);
        expect(
          (await readLink(entry.key))['Target'],
          equalsIgnoringCase(entry.value),
        );
      }
      expect(File(target).existsSync(), isTrue);
      expect(File(otherTarget).existsSync(), isTrue);
    });

    test(
      '8.3 install path migrates and removes the same long-path target',
      () async {
        final shortDir = await _powershell(
          "(New-Object -ComObject Scripting.FileSystemObject).GetFolder('${_quote(p.dirname(target))}').ShortPath",
        );
        if (shortDir.toLowerCase() == p.dirname(target).toLowerCase()) {
          markTestSkipped('8.3 names are unavailable on this test volume');
          return;
        }
        final owned = p.join(programs, 'AVA-pc.lnk');
        final unrelated = p.join(programs, 'AVA.lnk');
        await createLinks({owned: target, unrelated: otherTarget});
        Future<void> updateViaShortPath({bool uninstall = false}) =>
            WindowsShortcuts.update(
              displayName: appDisplayName,
              target: p.join(shortDir, 'ava.exe'),
              workDir: shortDir,
              iconPath: icon,
              desktopShortcut: false,
              uninstall: uninstall,
              programsDirectory: programs,
              desktopDirectory: desktop,
            );
        await updateViaShortPath();
        expect(File(owned).existsSync(), isFalse);
        expect(
          (await readLink(current(programs)))['Target'],
          equalsIgnoringCase(target),
        );
        expect(File(unrelated).existsSync(), isTrue);
        await updateViaShortPath(uninstall: true);
        expect(File(current(programs)).existsSync(), isFalse);
        expect(
          (await readLink(unrelated))['Target'],
          equalsIgnoringCase(otherTarget),
        );
      },
    );

    test(
      'missing install target fails before changing any shortcuts',
      () async {
        final owned = p.join(programs, 'AVA-pc.lnk');
        await createLinks({owned: target});
        await File(target).delete();
        await expectLater(update(), throwsStateError);
        expect(File(owned).existsSync(), isTrue);
        expect(File(current(programs)).existsSync(), isFalse);
      },
    );

    test(
      'missing uninstall target does not claim unrelated or broken links',
      () async {
        final owned = p.join(programs, 'AVA-pc.lnk');
        final unrelated = current(programs);
        await createLinks({owned: target, unrelated: otherTarget});
        await File(target).delete();
        await update(uninstall: true);
        expect(File(owned).existsSync(), isTrue);
        expect(
          (await readLink(unrelated))['Target'],
          equalsIgnoringCase(otherTarget),
        );
      },
    );
  });
}
