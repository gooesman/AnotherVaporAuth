# Windows Steam account switching (preview)

This branch adds **Switch Steam account** to the Windows account-row context
menu and to Settings. It opens a list of accounts remembered by the local Steam installation,
preselecting the matching AVA account by SteamID (or login name when an imported
authenticator has no SteamID). The local account list can include accounts that
have no authenticator in AVA.

## Trying the preview

1. Extract the complete Windows preview ZIP to its own directory. Keep the
   `data` folder and DLLs beside `ava.exe`.
2. Unlock AVA, right-click an account, and choose **Switch Steam account**. The
   same page is available from Settings without importing an authenticator.
3. Check the Steam installation path. **Choose steam.exe** can select another
   installation; this path is stored only on this computer and is not synced.
4. Select a local account, choose **Switch Steam**, and confirm. Finish any game
   and let cloud saves complete before restarting Steam.
5. Check the resulting account in Steam. AVA reports that Steam was started;
   it does not claim that the Steam servers accepted the login.

An account must first have been logged into the Steam client on this computer
with **Remember me** enabled. Importing a maFile into AVA does not establish that
desktop login. If Steam has forgotten or revoked the credentials, log in through
Steam normally, then refresh this page. AVA's existing login approval feature can
assist with that normal login.

## File and process handling

- The Windows bridge discovers the installation from the current user's Steam
  registry settings. Dart reads `config/loginusers.vdf`; it does not extract or
  inject Steam passwords or client refresh tokens.
- A switch requests `steam.exe -shutdown` and waits up to 30 seconds. It does not
  force-kill Steam or games. Files are reread after Steam exits.
- A restricted backup directory beneath `config/ava-switch-backups/` holds the
  original VDF files and `auto-login.json`, which records the previous registry
  selection. Backups remain local and may contain account information.
- Only selection-related VDF token spans are patched. Unknown fields, comments,
  and existing formatting are retained. The existing user-chooser preference,
  when present, is adjusted so Steam can use the selected remembered account.
- Private temporary files and Windows `ReplaceFileW` preserve the destination
  file permissions. Changed source files or a restarted Steam process cause the
  operation to stop instead of overwriting those changes.
- Write or launch failures trigger restoration of changes still owned by this
  operation. If concurrent changes prevent full restoration, the UI reports
  that recovery is needed and shows the backup directory. Backups are not
  automatically deleted or silently restored over a running Steam client.

## Validation

The automated tests use synthetic accounts, files, and a fake Windows bridge.
They cover configuration preservation, shutdown timeout, missing credentials,
partial failures, rollback, concurrent changes, and UI cancellation/selection.
The Windows preview workflow analyzes, tests, and compiles the full application.

Real two-account switching, expired credentials, and behavior after future
Steam client updates still require a manual check on a suitable Steam setup.
The Android interface does not expose this Windows-only action.
