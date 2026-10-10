# Windows Steam sign-in and account switching (preview)

## Sign in by selecting Steam's QR code on screen

Open an account's overview and choose **Switch Steam account**, or use the
existing account menu / Settings entry. The top card lets you choose an AVA
account and open **Sign in with an AVA account**, even if Steam has never
remembered that account on this PC.

1. Show the Steam client's sign-in QR code. If Steam is already logged in,
   use Steam's own account menu to reach sign-in when ready.
2. In AVA choose the intended account, then **Select a QR code on screen**.
3. AVA briefly hides. Drag around the complete QR code and release; Esc or
   right-click cancels. The selector supports multiple monitors and follows
   the current skin's accent color.
4. AVA decodes the selection locally, shows the chosen account and Steam's
   login details, and waits for approval. Steam then completes its own sign-in.

Screen images stay in memory and are not uploaded or saved. Invalid codes,
expired/unverifiable requests, cancellation, a locked vault or a changed
account cannot submit an approval. An offline TOTP secret alone is not enough:
the account also needs a usable Steam login session in AVA. The same screen
offers re-login when that session is missing. Existing remembered-account
switching remains available below this card.

Synthetic QR images cover scale, rotation and dark backgrounds; UI tests cover
confirmation and account changes. Real desktop selection, mixed-DPI displays,
and an actual Steam sign-in still require a manual preview check.

## Account overview and Android preview additions

The same feature branch now also includes an account overview on Windows and
Android. It uses the existing theme/skin components. Desktop accounts show the
overview beside the account list; tapping a phone account opens its full overview.
Wallet, market listings and account-tool cards can be hidden using the tune menu.
Unavailable balances are never presented as zero. Market records include active,
held and awaiting-confirmation listings, with separate inventory-context labels.

Friends & trades supports friend search, both sides' inventory selections and
quantities, review and explicit submission. SteamID/account identity is checked
when signing back in. No live offers were sent during development. Private
inventories, Steam restrictions and additional verification can still prevent a
trade. An uncertain send result must be checked in sent offers before retrying.

Settings offers startup verification (on by default) and Lock now. Disabling
verification stores a convenience credential in the device's secure storage;
account files stay encrypted. Changing the PIN re-enables verification. The
setting and credential are not account-sync data.

Backup login codes opens Steam's official `https://store.steampowered.com/twofactor/manage`
flow. Check the browser's account and complete Steam's verification there. AVA
does not generate, retrieve or cache one-use codes in its own UI, and does not
substitute the authenticator removal/recovery code for them.

The Android artifact is an **ARM64 debug preview**, package
`pro.dotslash.ava.dev`, labelled **AVA dev**. Its separate vault is empty on first
installation; it does not upgrade the installed production app. This is a development
build, not a Play release. Builds from separate CI runs may have different debug
signatures. Keep the production app and its data; do not uninstall it to test.
The predictive-back regression is covered with simulated system gestures and
pixel checks; Xiaomi 15 Pro validation remains a manual step.

Windows preview ZIPs keep DLLs and the `data` directory beside `ava.exe`.
They use the current Windows user's existing AVA data directory. Close other
AVA instances before running a preview; this is not an isolated vault.

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
