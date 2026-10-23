param(
    [Parameter(Mandatory)][string]$Setup,
    [Parameter(Mandatory)][string]$PayloadDirectory
)

$ErrorActionPreference = 'Stop'
trap {
    Write-Host $_.Exception.ToString()
    Write-Host $_.InvocationInfo.PositionMessage
    Write-Host $_.ScriptStackTrace
    throw
}
# This exercises real HKCU registration and shell shortcuts. Never run it on
# a developer's machine or on a persistent/self-hosted CI account.
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or -not $env:RUNNER_TEMP) {
    throw 'Full setup tests require a disposable GitHub-hosted Windows runner'
}
# Use the Unicode Shell API: WScript.Shell rejects targets outside the system
# ANSI code page, including Chinese paths on an English Windows runner.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
[ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ISetupTestShellLink {
    void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder path, int size, IntPtr data, uint flags);
    void GetIDList(out IntPtr list);
    void SetIDList(IntPtr list);
    void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder value, int size);
    void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string value);
    void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder value, int size);
    void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string value);
    void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder value, int size);
    void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string value);
    void GetHotkey(out short value);
    void SetHotkey(short value);
    void GetShowCmd(out int value);
    void SetShowCmd(int value);
    void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder value, int size, out int index);
    void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string value, int index);
    void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string value, uint reserved);
    void Resolve(IntPtr window, uint flags);
    void SetPath([MarshalAs(UnmanagedType.LPWStr)] string value);
}
public static class SetupTestShortcut {
    static object Create() {
        return Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("00021401-0000-0000-C000-000000000046")));
    }
    public static void Seed(string file, string target) {
        object instance = Create();
        try {
            ((ISetupTestShellLink)instance).SetPath(target);
            ((IPersistFile)instance).Save(file, true);
        } finally { Marshal.FinalReleaseComObject(instance); }
    }
    public static string Target(string file) {
        object instance = Create();
        try {
            ((IPersistFile)instance).Load(file, 0);
            var path = new StringBuilder(32768);
            ((ISetupTestShellLink)instance).GetPath(path, path.Capacity, IntPtr.Zero, 0);
            return path.ToString();
        } finally { Marshal.FinalReleaseComObject(instance); }
    }
}
'@
$setupPath = (Resolve-Path -LiteralPath $Setup).Path
$payload = (Resolve-Path -LiteralPath $PayloadDirectory).Path
$registry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\AVA'
$newRegistry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GooeSteamKit'
$defaults = @('AVA', 'GooeSteamKit') | ForEach-Object { Join-Path $env:LOCALAPPDATA "Programs\$_" }
$accountData = Join-Path $env:APPDATA 'dotslash.pro\AVA'
$shortcutFolders = @(
    [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory, [Environment+SpecialFolderOption]::DoNotVerify)
    [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs, [Environment+SpecialFolderOption]::DoNotVerify)
)
$shortcutNames = @('AVA.lnk', 'AVA-pc.lnk', 'gooes SteamKit.lnk', 'GooeSteamKit.lnk')
foreach ($path in @($registry, $newRegistry, $accountData) + $defaults) {
    if (Test-Path -LiteralPath $path) { throw "Refusing to overwrite an existing installation or data: $path" }
}
Write-Host 'Verified empty installation, registry and data locations.'
if (Get-Process -Name ava,ava_installer -ErrorAction SilentlyContinue) { throw 'Existing app process found' }
foreach ($folder in $shortcutFolders) {
    foreach ($name in $shortcutNames) {
        if (Test-Path -LiteralPath (Join-Path $folder $name)) { throw 'Existing app shortcut found' }
    }
}
Write-Host 'Verified empty shortcut locations.'

$testRoot = Join-Path (Resolve-Path -LiteralPath $env:RUNNER_TEMP).Path "steamkit-setup-$([guid]::NewGuid().ToString('N'))"
$installDir = Join-Path $testRoot '中文 𠮷 🦆 自定义目录\GooeSteamKit'
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Get-ChildItem -LiteralPath $payload -Force | Copy-Item -Destination $installDir -Recurse
Write-Host 'Created isolated installation fixture.'
# Seed the old registration and shortcut, as an existing AVA installation would.
New-Item -Path $registry -Force | Out-Null
New-ItemProperty -LiteralPath $registry -Name InstallLocation -Value $installDir -PropertyType String | Out-Null
New-ItemProperty -LiteralPath $registry -Name DisplayName -Value 'AVA' -PropertyType String | Out-Null
foreach ($folder in $shortcutFolders) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    [SetupTestShortcut]::Seed((Join-Path $folder 'AVA.lnk'), (Join-Path $installDir 'ava.exe'))
}
New-Item -ItemType Directory -Path $accountData -Force | Out-Null
$sentinels = @((Join-Path $installDir 'user-note.txt'), (Join-Path $accountData 'setup-test-sentinel.txt'))
$sentinelContent = 'Synthetic preserved user data. No real accounts or credentials.'
foreach ($file in $sentinels) { Set-Content -LiteralPath $file -Value $sentinelContent -Encoding utf8 }

function Invoke-Setup([string[]]$Arguments) {
    $process = Start-Process -FilePath $setupPath -ArgumentList $Arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(180000)) { throw 'Setup timed out' }
    if ($process.ExitCode -ne 0) { throw "Setup failed with exit code $($process.ExitCode)" }
}

function Assert-PreservedData {
    foreach ($file in $sentinels) {
        if (-not (Test-Path -LiteralPath $file) -or (Get-Content -LiteralPath $file -Raw).TrimEnd() -cne $sentinelContent) {
            throw 'Setup modified user data'
        }
    }
}

function Assert-Installed {
    foreach ($source in Get-ChildItem -LiteralPath $payload -File -Recurse) {
        $relative = [IO.Path]::GetRelativePath($payload, $source.FullName)
        $target = Join-Path $installDir $relative
        if (-not (Test-Path -LiteralPath $target) -or
            (Get-FileHash -LiteralPath $target).Hash -cne (Get-FileHash -LiteralPath $source.FullName).Hash) {
            throw "Installed payload differs: $relative"
        }
    }
    if ((Get-FileHash -LiteralPath (Join-Path $installDir 'uninstall.exe')).Hash -cne (Get-FileHash -LiteralPath $setupPath).Hash) {
        throw 'Uninstaller is not a copy of the outer setup image'
    }
    $registration = Get-ItemProperty -LiteralPath $registry
    if ($registration.DisplayName -cne 'GooeSteamKit' -or $registration.InstallLocation -ine $installDir -or
        $registration.UninstallString -cne ('"' + (Join-Path $installDir 'uninstall.exe') + '" --uninstall')) {
        throw 'Installation registration has the wrong name or directory'
    }
    foreach ($folder in $shortcutFolders) {
        $newLink = Join-Path $folder 'GooeSteamKit.lnk'
        if (-not (Test-Path -LiteralPath $newLink)) { throw 'Branded shortcut is missing' }
        if ([SetupTestShortcut]::Target($newLink) -ine (Join-Path $installDir 'ava.exe')) { throw 'Shortcut targets another installation' }
        foreach ($legacy in $shortcutNames | Where-Object { $_ -ne 'GooeSteamKit.lnk' }) {
            if (Test-Path -LiteralPath (Join-Path $folder $legacy)) { throw 'Legacy shortcut was not migrated' }
        }
    }
    foreach ($path in $defaults) {
        if (Test-Path -LiteralPath $path) { throw 'Setup created a second installation in the default directory' }
    }
    Assert-PreservedData
}

# Explicit in-app update target; quoting survives both Start-Process and NSIS.
Invoke-Setup @('--auto', ('"--install-dir=' + $installDir + '"'))
Assert-Installed
# A manually downloaded update must rediscover the registered custom directory.
Set-Content -LiteralPath (Join-Path $installDir 'data\icudtl.dat') -Value 'stale payload fixture'
Invoke-Setup @('--auto')
Assert-Installed

Start-Process -FilePath (Join-Path $installDir 'uninstall.exe') -ArgumentList '--auto' -WindowStyle Hidden | Out-Null
$deadline = (Get-Date).AddMinutes(3)
while ((Test-Path -LiteralPath (Join-Path $installDir 'ava-install.manifest')) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
if ((Test-Path -LiteralPath $registry) -or (Test-Path -LiteralPath $newRegistry) -or
    (Get-ChildItem -LiteralPath $installDir -File -Recurse).Count -ne 1) {
    throw 'Manifest uninstall did not remove exactly the installed payload'
}
foreach ($folder in $shortcutFolders) {
    if (Test-Path -LiteralPath (Join-Path $folder 'GooeSteamKit.lnk')) { throw 'Shortcut survived uninstall' }
}
Assert-PreservedData
# Only our unique fixture directory and synthetic data file are cleaned up.
$resolvedRoot = (Resolve-Path -LiteralPath $testRoot).Path
$temporaryRoot = (Resolve-Path -LiteralPath $env:RUNNER_TEMP).Path.TrimEnd('\') + '\'
if (-not $resolvedRoot.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture cleanup escaped RUNNER_TEMP' }
Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
Remove-Item -LiteralPath $sentinels[1]
Write-Host 'Verified custom-directory updates, GooeSteamKit branding, payload hashes, preserved data and uninstall.'
