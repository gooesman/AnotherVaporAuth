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
public static class AvaShortcutNotify {
  [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
  private static extern void SHChangeNotify(uint change, uint flags, string item, IntPtr unused);
  public static void Changed(string path, uint change) {
    // SHCNF_PATHW | SHCNF_FLUSHNOWAIT: notify only this item, without waiting
    // for Explorer or disrupting other apps with a global cache reset.
    SHChangeNotify(change, 0x2005, path, IntPtr.Zero);
  }
}
'@
''';

  static Future<void> update({
    required String displayName,
    required String target,
    required String workDir,
    required bool desktopShortcut,
    String? iconPath,
    bool uninstall = false,
    String? programsDirectory,
    String? desktopDirectory,
  }) async {
    String folder(String name, String? override) => override == null
        ? "\$ws.SpecialFolders('$name')"
        : "'${_quote(override)}'";
    final current = '${_quote(displayName)}.lnk';
    final legacy = [
      'AVA.lnk',
      'AVA-pc.lnk',
      'gooes SteamKit.lnk',
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
function Get-OwnedShortcut([string]\$path) {
  if (-not (Test-Path -LiteralPath \$path -PathType Leaf)) { return \$null }
  if ((Get-Item -LiteralPath \$path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { return \$null }
  \$link = \$ws.CreateShortcut(\$path)
  if (Test-OwnedShortcut \$link) { return \$link }
  return \$null
}
\$icon = '${_quote(iconPath ?? '')}'
if (-not \$$uninstall) {
  \$canonicalIcon = [AvaShortcutPath]::ExistingFile(\$icon)
  if (\$null -eq \$canonicalIcon -or -not [string]::Equals(
      [IO.Path]::GetDirectoryName(\$canonicalIcon),
      [IO.Path]::GetDirectoryName(\$canonicalTarget), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The installed shortcut icon is missing or outside this installation'
  }
}
\$folders = @(
  [pscustomobject]@{ Path = ${folder('Programs', programsDirectory)}; Create = \$${!uninstall} }
  [pscustomobject]@{ Path = ${folder('Desktop', desktopDirectory)}; Create = \$${!uninstall && desktopShortcut} }
)
foreach (\$entry in \$folders) {
  if ([string]::IsNullOrWhiteSpace(\$entry.Path)) { continue }
  \$path = Join-Path \$entry.Path '$current'
  \$ownedLegacy = @()
  foreach (\$name in @($legacy)) {
    \$old = Join-Path \$entry.Path \$name
    if (\$null -ne (Get-OwnedShortcut \$old)) { \$ownedLegacy += \$old }
  }
  \$existingOwned = Get-OwnedShortcut \$path
  if (\$$uninstall) {
    foreach (\$owned in @(\$ownedLegacy) + @(\$path)) {
      if (\$null -ne (Get-OwnedShortcut \$owned)) {
        Remove-Item -LiteralPath \$owned -Force
        [AvaShortcutNotify]::Changed(\$owned, 0x4) # SHCNE_DELETE
      }
    }
    continue
  }
  # An unchecked desktop option avoids NEW shortcuts, while preserving and
  # refreshing the existing shortcut the user still has after an upgrade.
  if (-not \$entry.Create -and \$null -eq \$existingOwned -and \$ownedLegacy.Count -eq 0) { continue }
  \$exists = Test-Path -LiteralPath \$path
  # Keep an unrelated same-name link, and the old entry it would replace.
  if (\$exists -and \$null -eq \$existingOwned) { continue }
  [IO.Directory]::CreateDirectory(\$entry.Path) | Out-Null
  \$link = \$ws.CreateShortcut(\$path)
    \$link.TargetPath = \$target
    \$link.WorkingDirectory = '${_quote(workDir)}'
    \$link.IconLocation = "\$icon,0"
    \$link.Save()
  \$saved = Get-OwnedShortcut \$path
  if (\$null -eq \$saved -or -not \$saved.IconLocation.EndsWith(',0') -or
      -not [string]::Equals([AvaShortcutPath]::ExistingFile(\$saved.IconLocation.Substring(0, \$saved.IconLocation.Length - 2)),
          \$canonicalIcon, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'New shortcut failed verification; old links were retained'
  }
  if (\$exists) { [AvaShortcutNotify]::Changed(\$path, 0x2000) } # SHCNE_UPDATEITEM
  else { [AvaShortcutNotify]::Changed(\$path, 0x2) } # SHCNE_CREATE
  foreach (\$old in \$ownedLegacy) {
    if (\$null -ne (Get-OwnedShortcut \$old)) {
      Remove-Item -LiteralPath \$old -Force
      [AvaShortcutNotify]::Changed(\$old, 0x4)
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
