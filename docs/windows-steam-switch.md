# Windows Steam sign-in and account switching (preview)

The Windows app is displayed as **AVA-pc**; the Android preview is **AVA Fork**.
Windows keeps `ava.exe` and the existing AVA data paths so the name change does
not create a new account library.

## Sign in by selecting Steam's QR code on screen

Open an account's overview and choose **Switch Steam account**, or use the
existing account menu / Settings entry. The QR sign-in card lets you choose an AVA
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
overview beside the account list. The phone home focuses on codes and accounts
in both portrait and landscape, with a compact acceleration status beside Settings;
tapping an account selects its code. Long-press the account to open its overview
directly, without an intermediate menu. Market, friends, backup codes, family,
devices and key redemption are reached from that overview. Long-pressing the
large selected-account avatar also opens the overview on phones (desktop keeps
its avatar click). Wallet and market data are not fetched just to show
the phone home. Swipe actions are phone-only; desktop account cards do not
slide and retain their right-click context menu, including in narrow windows.
Wallet, market listings and account-tool cards can be hidden using the tune menu.
Unavailable balances are never presented as zero. Market records include active,
held and awaiting-confirmation listings, with separate inventory-context labels.

Friends & trades supports friend search, both sides' inventory selections and
quantities, review and explicit submission. SteamID/account identity is checked
when signing back in. No live offers were sent during development. Private
inventories, Steam restrictions and additional verification can still prevent a
trade. Definite Steam rejections (including JSON diagnostics on HTTP errors),
failures before establishing a connection, and uncertain responses have separate
messages. The client submits only once. For an uncertain result it performs a
bounded read-only check against a pre-send snapshot, matching a new offer's
partner, message, assets and quantities. A matching receipt still distinguishes
mobile/email confirmation from a completed send. **Check send result** can repeat
the read-only check; an incomplete query or no match never proves failure and
never enables an automatic resend. Check sent offers before making another offer.

Settings offers startup verification (on by default) and Lock now. Disabling
verification stores a convenience credential in the device's secure storage;
account files stay encrypted. Changing the PIN re-enables verification. The
setting and credential are not account-sync data. System unlock (fingerprint,
Windows Hello or device credentials) is a child of this setting. Disabling
verification clears and disables system unlock as well. Re-enabling verification
leaves system unlock off until you enable and authorize it again. Failure to
clear a credential is reported instead of falsely showing the setting as saved.

Backup login codes has an in-app SMS flow: explicitly request a message, enter
the received verification code, then display the returned one-use codes. It uses
the selected account's existing Steam session and does not substitute the
authenticator removal/recovery code. Opening the page sends nothing. Codes and
verification text are not stored or synced; displayed codes are cleared when
the app is hidden, the vault locks, the account changes or the page is left.
There is no automatic retry of an SMS or generation request. An optional help
section retains the official Steam website as a fallback. This undocumented
Steam endpoint was checked with simulated protocol responses, not a real SMS;
real-account compatibility still requires a manual check.

## Optional Steam connectivity

Settings → Steam acceleration accepts HTTP or HTTPS Clash-format subscriptions,
including URL-encoded Basic authentication and custom ports, and a selected
supported node. Subscription requests identify as Clash so providers return
Clash YAML instead of a generic link list. Credentials are not forwarded across
origins; HTTPS certificate checks remain enabled. It starts manually by default; **Start automatically**
is optional. AVA's Steam HTTPS requests use the connection, including QR
approval, community, market, images and backup codes. The app's official GitHub
update checks/downloads can also reuse the already-active connection, with
external proxies taking priority. Opening updates does not start another core.
Automatic package downloads first try GH-Proxy's direct acceleration routes,
independent of this app proxy, and fall back to GitHub. GitHub-only downloading
is selectable; metadata and SHA-256 remain sourced from official GitHub.
It does not accelerate the
Steam desktop client, games, a browser or other apps, and never changes the
system proxy, DNS, certificates or TUN routing. Unsupported nodes are reported;
subscription rules, scripts, plugins and listeners are not imported.

This app-only proxy does not create Android's system VPN icon. A compact home
status entry and the acceleration page show the current route and a separate
connectivity result. Checks use the same active route for anonymous Steam API
and community HTTPS requests, after route changes, when returning to the foreground
with a result over one minute old, or on manual request. A running
core alone is not considered a successful connection; a successful connection
does not establish that the account is signed in or allowed to trade.

Detected external HTTP proxy settings take priority. A detected VPN/TUN already
routes operating-system sockets, so AVA pauses its own core. PAC is detected but
not evaluated; the UI reports its presence and pauses internal acceleration.
Environment checks run on entry, foreground return and
periodically while configured. Detection cannot identify every VPN product or
eliminate the short interval before a change is noticed. Unknown environments
do not automatically start a second core, but allow an explicit manual start.
Manually stopping prevents automatic
restart for the rest of that app session.

Windows downloads a fixed, SHA-256-verified Mihomo component (about 22 MB) on
first use. Android includes the ARM64 component because downloaded executable
code cannot be launched from its writable app storage; this adds about 22 MB
compressed to the APK. The core listens only on an authenticated random local
port and is stopped with AVA. Subscription links and sanitized node credentials
stay in local secure storage; they are not synced with accounts or logged.
Steam's normal TLS certificate checks remain enabled. See the
[privacy notice](fork-privacy.md) and [component notices](../third_party/mihomo/NOTICE).

The Android artifact is an **ARM64 release-mode preview**, package
`pro.dotslash.ava.fork`, labelled **AVA Fork**. It uses a stable private fork
signing key and installs alongside both the original AVA and the earlier
**AVA dev** preview. Its separate vault is empty on first installation. It is
an optimized AOT build with debugging disabled, distributed outside Play.
It updates earlier AVA Fork previews in place; see the migration steps below.
Android pages stay still while a system back gesture is in progress, and use a
short fade after it is committed. Cancelling the gesture keeps the current page.
The Activity opts out of predictive system previews as well. Simulated gestures,
pixel checks and navigation guards are covered; Xiaomi 15 Pro validation,
including any launcher-specific final animation, remains a manual step.

Windows preview ZIPs keep DLLs and the `data` directory beside `ava.exe`.
They use the current Windows user's existing AVA data directory. Close other
AVA instances before running a preview; this is not an isolated vault.

This branch adds **Switch Steam account** to the Windows account-row context
menu and to Settings. It opens a list of accounts remembered by the local Steam installation,
preselecting the matching AVA account by SteamID. The local account list can include accounts that
have no authenticator in AVA.

## Performance and presentation

The fork keeps Flutter and ships Android previews in optimized AOT release mode,
with the same package/signing identity as earlier AVA Fork builds. Debug/JIT
builds are not representative of delivered performance; real-device frame-time
profiling is still needed before claiming a particular frame rate.

The home clock now updates only countdown/token widgets. In an offline test
with three synthetic accounts, 20 one-second clock updates within one token
window previously caused 20 home rebuilds, 60 account-row rebuilds, 20 desktop
dashboard rebuilds and 80 HMAC computations. The updated implementation avoids
all of those repeat operations after initial rendering; countdown updates and
code rollover still run. Tests also cover time correction and replacing a
secret within the same window. This measures work avoided, not user-device FPS.

Friend and trade-inventory rows are constructed on demand, and inventory/offer
thumbnails decode to their displayed physical dimensions. Animated profile
images use a bounded decoded-frame cache; visible widgets retain independent
image handles when cached entries are evicted. Avatar playback pauses when
hidden, backgrounded or system animation reduction is enabled.

Plain light/dark surfaces use consistent rounded corners and flat cards;
shadows are reserved for raised overlays. Ambient motion is disabled for quiet
plain widgets, and page/token transitions finish quickly without page scaling.
Neon and pixel skins keep their own palettes and visual identity. The Android
back-gesture policy described above remains unchanged.

## Android installation and migration

AVA Fork cannot update the earlier AVA dev app in place: that preview used a
temporary CI debug key which is no longer available. The new package identity
keeps the old app and its data intact. Do not uninstall the old app or clear its
data as part of migration.

1. In the old **AVA dev**, unlock the app, swipe an account row **left**, and
   choose **Export**. Confirm the unencrypted `.maFile` export and use Android's
   share sheet to save a copy through a trusted file app. Repeat for each account;
   there is no single all-account backup button. A saved Steam password is
   excluded unless explicitly selected.
2. Install **AVA Fork**, accept its privacy notice and set its own local PIN.
   On the welcome screen choose **Import .maFile** and select the first exported
   file. Once the account list appears, **+ → Import** imports another file,
   or **+ → Import SDA folder** opens a file multi-selector for the remaining
   exported `.maFile` files.
   These plain exports need no `manifest.json`; encrypted SDA files do require
   their matching manifest and encryption password.
3. Check that every expected account and its codes appear. A saved Steam session
   may need a normal sign-in before online features work; this does not require
   removing or re-linking the authenticator. The single-file import offers to
   activate an expired session; after a batch import use the account's refresh
   action if needed. App settings, the local unlock PIN and WebDAV configuration
   are not included in a `.maFile` export and must be configured separately.
4. Keep the old app until the new one works. The exported files contain
   authenticator secrets and Steam session data: store any retained backup
   securely and remove temporary migration copies after verification. Export
   alone is not a backup unless the share destination actually saved the file.

Later **AVA Fork** APKs signed with the same fork key and a higher Android
version code can update it directly, retaining its app data. APKs with another
signature cannot. Keep the signing key secure and backed up when maintaining
this fork; generating a new key does not preserve update compatibility.

## Trying the preview

The switcher shows whether the selected Steam installation is running. When the
active process and its local account ID can be verified, it displays the current
account and marks its matching row. A remembered/most-recent account is never
presented as the current login just because it was used previously. If the
active account cannot be identified, the UI says so; this does not establish
whether Steam's servers consider the client online. Refresh updates the status,
as do returning to the page after QR login, completing an account switch, and
bringing AVA back to the foreground while this page is open.

1. Extract the complete Windows preview ZIP to its own directory. Keep the
   `data` folder and DLLs beside `ava.exe`.
2. Unlock AVA, right-click an account, and choose **Switch Steam account**. The
   same page is available from Settings without importing an authenticator.
3. Check the Steam installation path. **Choose steam.exe** can select another
   installation; this path is stored only on this computer and is not synced.
4. Select a local account, choose **Switch account**, and confirm. Finish any game
   and let cloud saves complete before restarting Steam.
5. Check the resulting account in Steam. AVA reports that Steam was started;
   it does not claim that the Steam servers accepted the login.

An account must first have been logged into the Steam client on this computer
with **Remember me** enabled. Importing a maFile into AVA does not establish that
desktop login. If Steam has forgotten or revoked the credentials, log in through
Steam normally, then refresh this page. AVA's existing login approval feature can
assist with that normal login.

## In-app software updates

On Windows or Android, open **Settings → Software updates**. Opening this page
checks this fork's public GitHub releases and displays the current version,
available version and release notes. No published release, an unavailable
connection and an already-current version have separate messages. CI artifacts
alone are not published releases and will not appear as available updates.

Choose **Download update** to fetch an installer; progress and cancellation are
shown. The download must match the release's size and SHA-256 digest. Missing
verification information or a failed check blocks installation. Downloading does
not run the file: **Install update** opens a separate confirmation, and the file
is checked again before it is handed to the operating system.

On Android, an **Allow app installs** button opens the system permission page
when needed. After returning, choose **Install update** again; installation does
not start just because permission was enabled. Android also checks the app's
package identity, version and current signing certificate, then asks you to
confirm installation. On Windows, finish current work before confirming: AVA-pc
opens the installer and then closes to release its files. Follow the installer
prompts to complete the update. The app does not silently install updates or
send Steam credentials to GitHub.

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

## Local features in this fork

All local features and skins are available without Pro verification. The settings
page has no purchase, redemption, restore or paid-skin entry. Existing entitlement
tokens remain on disk for compatibility but are not read, refreshed or transmitted;
no entitlement is forged and no subscription to the author's services is granted.
The Play bridge and advertising auto-initialization are disabled. Accounts,
encryption and user-configured WebDAV synchronization keep their existing storage.

This fork has no default upstream update check, so it will not recommend replacing
itself with the original app. Feedback opens this repository's issue page without
automatically sending account details or logs. Original copyright and license
notices are retained. See the [fork privacy notice](fork-privacy.md).

## Inventory rarity and read-only market prices

The market inventory and both sides of a trade offer support name search plus
type and rarity filters. Categories come from Steam's inventory tags and use
its localized labels, so CS weapon types, graffiti, music kits and other item
types can be selected separately. Items with missing metadata remain accessible.
Changing a filter does not discard already selected trade items or quantities.

On phones, a compact game/context menu remains visible in portrait and landscape,
including screens with large corner insets or enlarged text. Desktop retains
horizontal game tabs and an all-context menu. The interior selector does not
consume the bottom system/corner safe area. Category options and filtered stacks
are cached until inventory, filters or relevant localized labels change;
reselecting the current context keeps its items, while Refresh reloads them.

Inventory thumbnails and trade selections use a thin rarity-colored border and
a faint tint, retaining the existing skin and selection styling. Colors come
from Steam's Rarity/Quality tags, with its item-name color as a fallback. Missing
or malformed colors keep a neutral frame; localized names are not used to guess
rarity.

Right-click an item on desktop, long-press on mobile, or choose its **…** menu to
view a Steam market reference or open the exact market listing. A lookup shows
the available lowest price, median and recent volume, with the requested currency.
It also leaves a compact reference below that item's name. This is a single-item
market quote, not the seller's net proceeds or a guaranteed trade valuation.
Temporarily unmarketable items can still be queried when they have a market name.
Unavailable quotes are shown as unavailable, never invented as a zero price.

Prices are requested only when chosen, with identical requests combined and
memory-only caching (five minutes for quotes, thirty seconds for failures).
Reopening the price action after expiry fetches a fresh quote; displayed labels
are not continuously polled. Queries are keyed by game, exact market name,
currency and language. These actions do not select items, submit offers or list
items for sale.
