import 'dart:io';

/// Only known shortcut names pointing at this exact installation are ours.
/// Folder overrides let integration tests exercise real .lnk files without
/// touching the user's Desktop or Start menu.
abstract final class WindowsShortcuts {
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
\$ws = New-Object -ComObject WScript.Shell
\$target = '${_quote(target)}'
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
    if (\$exists -and -not [string]::Equals(\$link.TargetPath, \$target, [StringComparison]::OrdinalIgnoreCase)) { continue }
    \$link.TargetPath = \$target
    \$link.WorkingDirectory = '${_quote(workDir)}'
    \$link.IconLocation = '${_quote(target)},0'
    \$link.Save()
  }
  foreach (\$name in @($removals)) {
    \$path = Join-Path \$entry.Path \$name
    if (Test-Path -LiteralPath \$path -PathType Leaf) {
      \$link = \$ws.CreateShortcut(\$path)
      if ([string]::Equals(\$link.TargetPath, \$target, [StringComparison]::OrdinalIgnoreCase)) {
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
