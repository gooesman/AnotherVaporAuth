import 'dart:io';

import 'package:archive/archive.dart';
import 'package:ava_installer/engine.dart';
import 'package:ava_installer/windows_icon.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  // Enough ICO framing for the content-address check; no image is displayed.
  final first = <int>[0, 0, 1, 0, 1, 0, ...List.filled(16, 0)];
  final second = <int>[...first, 7];
  String name(List<int> bytes) =>
      'gooesteamkit-icon-${sha256.convert(bytes)}.ico';
  ArchiveFile icon(List<int> bytes) =>
      ArchiveFile(name(bytes), bytes.length, bytes);

  test('payload chooses the single verified content-addressed icon', () {
    expect(
      WindowsIcon.payloadPath([
        ArchiveFile('ava.exe', 1, [0]),
        icon(first),
      ]),
      name(first),
    );
  });

  test(
    'missing, stale duplicate, wrong hash or misplaced icon fails closed',
    () {
      expect(() => WindowsIcon.payloadPath([]), throwsStateError);
      expect(
        () => WindowsIcon.payloadPath([icon(first), icon(second)]),
        throwsStateError,
      );
      expect(
        () => WindowsIcon.payloadPath([
          ArchiveFile(name(first), second.length, second),
        ]),
        throwsStateError,
      );
      expect(
        () => WindowsIcon.payloadPath([
          ArchiveFile('../${name(first)}', first.length, first),
        ]),
        throwsStateError,
      );
    expect(
      () => WindowsIcon.payloadPath([
        ArchiveFile('${name(first)}\n', first.length, first),
      ]),
      throwsStateError,
    );
    },
  );

  test(
    'upgrade carries verified managed icons into a safe uninstall manifest',
    () async {
      final root = await Directory.systemTemp.createTemp('steamkit_icon_test_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final install = await Directory(p.join(root.path, 'AVA')).create();
      await File(p.join(install.path, name(first))).writeAsBytes(first);
      await File(p.join(install.path, name(second))).writeAsBytes(second);
      final outside = File(p.join(root.path, name(second)));
      await outside.writeAsBytes(second);
      final unrelated = File(p.join(install.path, 'personal.ico'));
      await unrelated.writeAsBytes(first);
      final retained = await WindowsIcon.retainedPaths(install.path, [
        name(first),
        name(first),
        '../${name(second)}',
        unrelated.path,
        'personal.ico',
        name(<int>[...first, 8]),
      ]);
      expect(retained, [name(first)]);
      // The installer unions the carried entries and this release's payload.
      await File(
        p.join(install.path, InstallEngine.manifestName),
      ).writeAsString(
        {...retained, name(second), InstallEngine.manifestName}.join('\n'),
      );
      await InstallEngine.removeInstalled(install.path, log: (_) {});
      expect(await File(p.join(install.path, name(first))).exists(), isFalse);
      expect(await File(p.join(install.path, name(second))).exists(), isFalse);
      expect(await unrelated.exists(), isTrue);
      expect(await outside.exists(), isTrue);
    },
  );

  test('changed old icon content is never adopted into our manifest', () async {
    final root = await Directory.systemTemp.createTemp('steamkit_icon_test_');
    addTearDown(() => root.delete(recursive: true));
    await File(p.join(root.path, name(first))).writeAsBytes(second);
    expect(await WindowsIcon.retainedPaths(root.path, [name(first)]), isEmpty);
  });
}
