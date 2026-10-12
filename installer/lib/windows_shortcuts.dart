import 'dart:io';

/// Only known shortcut names pointing at this exact installation are ours.
/// Folder overrides let integration tests exercise real .lnk files without
/// touching the user's Desktop or Start menu.
abstract final class WindowsShortcuts {
  // WScript expands DOS 8.3 paths when reading .lnk targets. Normalize both
  // existing files through Windows rather than weakening ownership checks.
  // A missing/inaccessible file never proves that a shortcut belongs to us.
  static const _canonicalPathType = r'''
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class AvaShortcutPath {
  [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  private static extern uint GetFinalPathNameByHandle(SafeFileHandle file, StringBuilder path, uint capacity, uint flags);
  public static string ExistingFile(string path) {
    if (String.IsNullOrWhiteSpace(path) || !Path.IsPathRooted(path)) return null;
    try {
      using (var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete)) {
        var buffer = new StringBuilder(32768);
        uint length = GetFinalPathNameByHandle(file.SafeFileHandle, buffer, (uint)buffer.Capacity, 0);
        return length > 0 && length < buffer.Capacity ? buffer.ToString() : null;
      }
    } catch { return null; }
  }
}
'@
''';

  static Future<void> update({
    required String displayName,
    required String target,
    required String workDir,
    required bool desktopShortcut,
    bool uninstall = false,
    String? programsDirectory,
    String? desktopDirectory,
  }) async {
    String folder(String name, String? override) => override == null
        ? "\$ws.SpecialFolders('$name')"
        : "'${_quote(override)}'";
    final current = '${_quote(displayName)}.lnk';
    final removals = [
      if (uninstall) current,
      'AVA.lnk',
      'AVA-pc.lnk',
    ].map((name) => "'$name'").join(',');
    final script =
        '''
\$ErrorActionPreference = 'Stop'
$_canonicalPathType
\$ws = New-Object -ComObject WScript.Shell
\$target = '${_quote(target)}'
\$canonicalTarget = [AvaShortcutPath]::ExistingFile(\$target)
if (\$null -eq \$canonicalTarget) {
  if (\$$uninstall) { return }
  throw 'Cannot identify the installed executable; shortcuts were not changed'
}
function Test-OwnedShortcut(\$link) {
  \$actual = [AvaShortcutPath]::ExistingFile(\$link.TargetPath)
  return \$null -ne \$actual -and [string]::Equals(\$actual, \$canonicalTarget, [StringComparison]::OrdinalIgnoreCase)
}
\$folders = @(
  [pscustomobject]@{ Path = ${folder('Programs', programsDirectory)}; Create = \$${!uninstall} }
  [pscustomobject]@{ Path = ${folder('Desktop', desktopDirectory)}; Create = \$${!uninstall && desktopShortcut} }
)
foreach (\$entry in \$folders) {
  if ([string]::IsNullOrWhiteSpace(\$entry.Path)) { continue }
  if (\$entry.Create) {
    [IO.Directory]::CreateDirectory(\$entry.Path) | Out-Null
    \$path = Join-Path \$entry.Path '$current'
    \$exists = Test-Path -LiteralPath \$path
    \$link = \$ws.CreateShortcut(\$path)
    # Keep an unrelated same-name link, and the old entry it would replace.
    if (\$exists -and -not (Test-OwnedShortcut \$link)) { continue }
    \$link.TargetPath = \$target
    \$link.WorkingDirectory = '${_quote(workDir)}'
    \$link.IconLocation = '${_quote(target)},0'
    \$link.Save()
  }
  foreach (\$name in @($removals)) {
    \$path = Join-Path \$entry.Path \$name
    if (Test-Path -LiteralPath \$path -PathType Leaf) {
      \$link = \$ws.CreateShortcut(\$path)
      if (Test-OwnedShortcut \$link) {
        Remove-Item -LiteralPath \$path -Force
      }
    }
  }
}
''';
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ]);
    if (result.exitCode != 0) {
      throw StateError('Shortcut update failed: ${result.stderr}');
    }
  }

  static String _quote(String value) => value.replaceAll("'", "''");
}
