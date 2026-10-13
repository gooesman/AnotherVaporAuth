<h1 align="center">
  <img src="app/assets/icon/gooes_steamkit.png" height="64" width="64" />
  <br/>
  GooeSteamKit
</h1>

<p align="center">
  A lightweight Steam authenticator and account toolkit, built with <b>Flutter</b>
  and based on freefrank's <b>AVA (AnotherVaporAuth)</b>.<br/>
  <sup>Community project — not affiliated with Steam or Valve in any way.</sup>
</p>

<p align="center">
  This fork publishes installers for <b>Windows · Android</b>.
</p>

<p align="center">
  <b>English</b> · <a href="README_ZH.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/gooesman/AnotherVaporAuth/releases/latest"><img alt="Latest fork release" src="https://img.shields.io/github/v/release/gooesman/AnotherVaporAuth?style=flat-square&color=34F1FF" /></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/freefrank/AnotherVaporAuth?style=flat-square&color=FF4D9D" /></a>
  <img alt="Fork installers" src="https://img.shields.io/badge/platforms-Windows%20%C2%B7%20Android-8A93B8?style=flat-square" />
</p>

---

## This fork

**GooeSteamKit** is gooesman's independently maintained fork of freefrank's AVA. Local
features and all skins are available without Pro verification or payment.
The original author's MIT notice and credits remain intact. Stable installers
are available in this fork's [releases](https://github.com/gooesman/AnotherVaporAuth/releases/latest). Preview builds
come from this fork's [builds](https://github.com/gooesman/AnotherVaporAuth/actions/workflows/windows-preview.yml);
the download links below belong to the original project. This README describes
the current source; installable updates require a published release.
Windows and Android use **GooeSteamKit** for the app and home-screen labels, with
the same goose-and-shield design (earlier builds used **AVA-pc** and **AVA Fork**).
Android 8+ uses an adaptive vector icon with a
solid background; older Android versions use the new shield artwork as a PNG.
Settings → Software updates checks this fork's published releases and
lets you download and open the installer. Android uses the same update page;
installation still requires the system confirmation. Automatic downloads use
GH-Proxy's direct acceleration routes, with GitHub as fallback; GitHub-only
downloads remain selectable. The source selector stays visible on both platforms,
even without a new release or if the version check fails. Official requests can reuse an active proxy.
Both routes support parallel downloads, speed/remaining-time display and full
SHA-256 verification against the official GitHub metadata.

Android keeps the **AVA Fork** package (`pro.dotslash.ava.fork`) and stable signing
key in its ARM64 optimized release-mode build. Existing AVA Fork users can update
directly to GooeSteamKit, retaining accounts and settings without importing again.
The original AVA and earlier **AVA dev** remain separate apps: install alongside
them and import each account's exported `.maFile` once. Windows keeps its existing
executable and data paths. Release filenames retain the `AVA-pc-` and `AVA-Fork-`
prefixes so earlier in-app updaters can find new versions. Windows packages a
separate icon with a filename derived from its content hash; updates rename and
refresh existing desktop and Start-menu shortcuts that point to this installation.
This gives Windows a new icon path when the artwork changes while preserving
shortcuts for other installations. See the
[migration steps](docs/windows-steam-switch.md#android-installation-and-migration).

## Original project downloads

| | |
|---|---|
| **Android** | [Google Play](https://play.google.com/store/apps/details?id=pro.dotslash.ava) · [direct APK](https://ava.dotslash.pro/#download) (no Play Services needed) |
| **Windows** | [Installer](https://github.com/freefrank/AnotherVaporAuth/releases/latest) · portable single-file build in the same release |
| **macOS** | [DMG](https://github.com/freefrank/AnotherVaporAuth/releases/latest) — Apple Silicon only; see [first launch](#macos-apple-silicon) |
| **Linux** | [AppImage](https://github.com/freefrank/AnotherVaporAuth/releases/latest) |

Coming from **Steam Desktop Authenticator**? Import your whole `maFiles/`
folder, encrypted ones included — nothing to re-link, no 7-day trade
cooldown. There is a [step-by-step
guide](https://ava.dotslash.pro/guide/move-steam-authenticator/).

<p align="center">
  <img src="posts/zh/recruit/home-neon.png" width="30%" alt="Steam Guard codes" />
  <img src="posts/zh/recruit/confirmations.png" width="30%" alt="Trade confirmations" />
  <img src="posts/zh/recruit/home-pixel.png" width="30%" alt="Pixel skin" />
</p>

These screenshots show the original AVA interface; this fork uses the goose icon
shown above while retaining the existing skin styles.

---

> **Security note:** a desktop/PC authenticator defeats much of the purpose of
> two-factor authentication — if your device is compromised, so is your token.
> Prefer Steam's official mobile app where you can. Always back up your `maFiles`
> and your revocation code. Use at your own risk.

## Highlights

- **Windows Steam account switching (branch preview)** — select a locally
  remembered Steam account from the overview, Settings or the right-click menu.
  Requests a normal Steam restart, backs up settings before editing, and reports
  when a normal login is still needed. The same page can sign in a new account:
  choose its session in GooeSteamKit, drag-select Steam's on-screen QR code and review the
  login request. Screen images are decoded locally in memory. See the
  [preview guide](docs/windows-steam-switch.md).

- **Account overview (branch preview)** — Windows and Android share configurable
  wallet/pending-funds and market-listing cards, friends and two-sided trade-offer
  editing, and in-app backup login codes with Steam SMS verification. Startup
  verification can be disabled in Settings while keeping account files encrypted at rest.
  Android updates existing **AVA Fork** installations in place; it remains separate
  from the original AVA and earlier AVA dev.
  Its home screen stays focused on codes and accounts in portrait and landscape;
  tap an account to select its code, or long-press it to open its overview directly.
  Market, friends and other account tools are available in that overview.

- **Optional Steam acceleration (branch preview)** — choose a node from an HTTP
  or HTTPS Clash subscription, including Basic-auth URLs, for this app's Steam requests. Manual start is the default;
  automatic start pauses when an external proxy or VPN is detected. System
  proxy settings and other apps are untouched. A compact status entry separates
  core operation from checked API/community reachability; no system VPN icon is
  expected. Windows downloads its optional core through a primary mirror, backup
  mirror and official fallback, verifying both archive and executable SHA-256;
  Android includes the core. With encrypted settings sync enabled, subscription
  links, sanitized cached nodes and node selection follow you between devices;
  startup choices stay local. See the [scope and limitations](docs/windows-steam-switch.md#optional-steam-connectivity).

- **Inventory rarity and prices (branch preview)** — restrained rarity-colored
  icon borders in the inventory and trade picker. Right-click, long-press or
  use the item menu for a read-only Steam price reference and market-page link.
  Prices load on demand, include their currency, and do not change item selection.
  Market and trade inventories support name search and Steam-tag type/rarity
  filters, retaining selected items and quantities when filters change.
  The Windows account switcher also shows Steam's running state and an account
  verified against the active local Steam process, when it can be identified.

- **maFile compatible** — reads/writes the legacy `.maFile` format
  (PBKDF2/SHA1 + AES-256-CBC), so existing accounts migrate with no changes.
  Also imports a whole Steam Desktop Authenticator `maFiles/` folder — **including
  the encrypted ones** (select `manifest.json` along with the `.maFile`s; the salt
  and IV live in the manifest, so an encrypted maFile alone is undecryptable) — and
  other tools' variants (Steam++ / Watt Toolkit), including exports with no SteamID
  (imported as a code-only account whose codes work offline). Export an account's
  maFile at any time.
- **Steam Guard codes** — a per-account list with live countdown rings and
  tap-to-copy; tap a name to cycle username / persona / id. The choice applies
  to the home account list and selected panel, is saved on this device and
  survives app restarts on both desktop and phone.
- **In-app sign-in approval** — approve or deny Steam logins from a dialog inside
  GooeSteamKit (device + location shown), just like the official app — by polling, no push.
- **Pending center** — one tabbed screen (swipe right on a phone account, or use the desktop context menu) for everything
  awaiting a decision: **Confirmations** (trade / market, batch accept/reject, native
  JSON, no WebView), **Trade offers** (received / sent / history, expandable cards
  with both sides' items, gift / one-sided / escrow banners, accept then hand off to
  the matching mobileconf).
- **Steam Family groups** — a read-only group page (members, roles, slots, cooldown)
  from the account overview (or desktop context menu), where incoming invites also live: pre-join checks first,
  then hold-to-join. *(experimental)*
- **Hold-to-confirm** — decisions on existing trade offers and confirmations,
  joining a family and deleting an account use press-and-hold with accelerating
  haptics; each gate and the haptics have their own Settings toggles. New trade
  offers use a review dialog followed by an explicit Send action.
- **Inventory & Market** — browse an account's Steam inventory (Steam-style game
  picker, identical items stacked) and list items on the Community Market with
  live Steam fees, a high/low price trend, linked "you receive ⇄ buyer pays"
  pricing, batch listing, and optional auto-confirm; a "My listings" tab cancels
  active listings. Open it from the account overview or desktop context menu.
  A separate read-only **Market** tab searches by item name, game and currency.
  Opening the tab or typing does not fetch data: submit a search to load one page
  with its returned prices, then explicitly load more. Recent pages are cached
  for five minutes; only refreshing an item's price makes an extra price request.
  Inventory and personal listings load when their respective tabs are opened.
  Prices retain Steam's returned currency; the selected currency is a request preference.
- **Automatic session refresh** — refreshes the access token from the refresh
  token, and (optionally) does a full headless re-login with a stored password
  plus the account's own TOTP when the refresh token expires.
- **Login flows** — password + **QR**, session refresh, add authenticator, and
  approving another device's login by scanning its QR.
- **App lock** — a 6-digit PIN gates a random 256-bit key held in the
  platform's secure storage, which encrypts the local store (AES-256-GCM).
  System unlock (fingerprint, Windows Hello or device credentials) is an optional
  method under startup verification. Turning verification off also disables this
  method; turning verification back on requires enabling system unlock again.
  Verification is enabled by default. Opting out stores a device-local convenience
  credential only in platform secure storage; changing the PIN enables verification again.
- **Encrypted sync (optional)** — put your accounts on a WebDAV server you
  control (Nextcloud, Synology, any of them). Everything is encrypted on your
  device before it leaves — the server stores ciphertext and never sees a
  passphrase. Conflicts resolve per account rather than per file, so two devices
  editing different accounts both keep their work. Off until you configure it.
  **Sync app settings** also includes acceleration subscriptions and explicit
  subscription removals. Receiving a subscription does not start acceleration;
  its automatic-start preference and runtime state remain per-device. Both devices
  need this feature for full subscription sync; older documents leave the newer
  app's local subscription intact. Settings use whole-document last-writer merging.
- **Animated avatars** — pulls each account's Steam avatar and avatar frame and
  plays them (GIF natively; APNG parsed and composited by hand, honoring each
  frame's offset / blend / dispose, so offset-based frames don't flicker).
- **Appearance & skins** — a plain **Light / Dark / follow-system** appearance,
  and separately a **skin** layer (None / Neon cyberpunk / Pixel retro), each
  skin a data-driven effect pack with its own ambience. Pull-to-refresh uses
  a small circular indicator with theme-matched colors and borders.
- **Device management** — see every device and browser session signed into an
  account (platform, rough location, last activity) and sign any of them out
  remotely. The current device is marked and can't sign itself out.
- **Redeem Steam keys** — activate a product key from the account overview or desktop context menu,
  with Steam's own rejection reasons spelled out (mistyped, already owned,
  already used, wrong country, needs the base game, rate-limited). Activation is
  permanent, so it always confirms first and never retries a key by itself.
- **Desktop windows stay where you put them** — position, size and maximized
  state are remembered between launches, and a window saved on a monitor you
  have since unplugged is brought back onto a screen you still have rather
  than restored somewhere invisible.
- **First-run gesture tutorial** on touch devices (desktop gets right-click row
  menus instead).
- **i18n** — English, 简体中文, 繁體中文, Deutsch, Français, Español, Русский.
- **In-app Debug log** (Settings → Debug log) — a copyable network trace of the
  Steam flows for diagnostics.

## Project layout

```
app/        Flutter application (see app/README.md)
docs/       design specs (docs/specs/) and implementation plans (docs/plans/)
infra/      Cloudflare workers (entitlement/version, feedback)
installer/  Windows installer packaging
tool/       release tooling (Play upload, R2 publish, docs lint)
```

The **`legacy`** branch preserves the original .NET WinForms Steam Desktop
Authenticator that inspired this project — kept for reference only; AVA shares no
code with it.

## Build

Requires the Flutter SDK (3.44.x). See `app/README.md` for details.

```sh
cd app
flutter pub get --enforce-lockfile
flutter test                       # 1475 tests
flutter run -d linux               # or windows / macos

# Android ships in two flavors (play / cn); a build without --flavor fails.
flutter build apk --release --split-per-abi --flavor cn --dart-define=AVA_CHANNEL=cn
```

This fork's current Windows and Android release process is described in
[fork releases](docs/fork-releases.md). The inherited desktop release tooling
is retained in `.github/workflows/desktop-release.yml`:

- **Windows installer** — a scene-style single-file `AVA-…-setup.exe` built
  from the original project's Flutter installer app (`installer/`): frameless neon/pixel UI,
  installs per-user (no UAC), Start-menu / desktop shortcuts and a proper
  uninstall entry. Uninstalling never touches account data.
- **Linux AppImage** — single-file `AVA-…-linux-x86_64.AppImage`.

**Portable build (Windows):** a separate workflow
(`.github/workflows/windows-portable.yml`) packs the whole app into one
single-file `AVA-…-portable.exe` (NSIS, `tool/portable.nsi`). It runs from anywhere
with nothing to install. Desktop Settings includes a **Portable mode** switch:
new accounts go to `maFiles` beside the app when enabled, or to AppData when
disabled. Both libraries remain readable. Each switch offers to copy existing
accounts; source copies are retained and matching Steam IDs are skipped.
Portable accounts use a separate password (at least 12 characters), so the
whole `maFiles` folder can travel to another computer. Keep its `manifest.json`
with the encrypted account files. Settings are not carried in `maFiles`;
existing WebDAV settings sync is unchanged, and portable accounts are excluded
from account sync. On a new computer, accept the privacy notice and set a local
unlock PIN first, then unlock `maFiles` with its separate password.

## macOS (Apple Silicon)

The original AVA project's DMG builds ship on its [Releases](https://github.com/freefrank/AnotherVaporAuth/releases)
with every tagged version since v1.2.0 — **arm64 only** (M1 and later; no Intel
build). Open the DMG and drag **AVA** into **Applications**.

The app is ad-hoc signed but **not notarized** (a $99/year Apple Developer
membership; this is a free community project), so Gatekeeper will warn on first
launch. To run it anyway:

1. **Right-click** (or Control-click) `AVA.app` → **Open** → **Open**. On newer
   macOS the button may only appear the second time, or under
   **System Settings → Privacy & Security → "Open Anyway"**.
2. If macOS instead claims the app "is damaged and can't be opened" — that is
   the quarantine flag on an un-notarized download, not actual damage. Clear it:

   ```sh
   xattr -dr com.apple.quarantine /Applications/AVA.app
   ```

Both are one-time; later launches open normally. Only ever do this for software
whose origin you trust — for the original AVA that means the upstream Releases page linked above, where
every DMG is built in public by GitHub Actions from the tagged commit.

## Fonts

All fonts are **bundled** (no runtime download) and declared in
`app/pubspec.yaml`; see `app/assets/fonts/README.md` for details.

| Family | Theme | Role | Source / License |
|---|---|---|---|
| [Chakra Petch](https://fonts.google.com/specimen/Chakra+Petch) | Neon | display | OFL 1.1 |
| [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono) | Neon | code | OFL 1.1 |
| [Noto Sans SC](https://fonts.google.com/noto/specimen/Noto+Sans+SC) | Neon | Chinese (CJK) fallback | OFL 1.1 |
| [Fusion Pixel](https://github.com/TakWolf/fusion-pixel-font) | Pixel | display + code (Latin + full CJK incl. 簡/繁, kana, hangul) | OFL 1.1 |

The Pixel theme uses the **full** Fusion Pixel font for complete CJK coverage
(including rare characters in usernames). Noto Sans SC is subset to the CJK
ideograph blocks (simplified + traditional). Latin-only fonts cover ASCII.

## Credits

The original AVA by freefrank was written from scratch in Flutter. This repository
is a fork of that project. AVA was inspired by **Steam Desktop Authenticator** (by
Jessecar96 and contributors), and stays compatible with its `.maFile` format so
existing users can migrate. Steam auth protocol references:
[SteamAuth](https://github.com/geel9/SteamAuth),
[node-steam-session](https://github.com/DoctorMcKay/node-steam-session).

## Privacy

Accounts, secrets and codes stay on your device. Steam requests go to Valve,
without a backend operated by this fork. When optional acceleration is enabled,
connections use your selected node or detected external proxy with normal TLS
verification. This fork disables Pro
verification, payments and advertising, and has no default upstream update
check. Feedback opens this fork's GitHub issues without sending a report or
log automatically. Optional WebDAV synchronization uses your chosen server.
See the [fork privacy notice](docs/fork-privacy.md)
([简体中文](docs/fork-privacy-zh.md)); the original policies remain in the
repository for reference.

## License

See [LICENSE](LICENSE). Bundled fonts retain their own OFL 1.1 licenses.
