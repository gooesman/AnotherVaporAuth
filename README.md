<p align="center">
  <img src="app/assets/icon/gooes_steamkit.png" width="128" height="128" alt="GooeSteamKit goose and shield icon" />
</p>

<h1 align="center">GooeSteamKit</h1>

<p align="center">
  <b>Steam Guard, accounts, inventory and market — in one app.</b><br/>
  A Flutter-based Steam toolkit for Windows and Android.
</p>

<p align="center">
  <b>English</b> · <a href="README_ZH.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/gooesman/AnotherVaporAuth/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/gooesman/AnotherVaporAuth?style=flat-square&color=4C7FFF" /></a>
  <img alt="Windows x64 and Android ARM64" src="https://img.shields.io/badge/platforms-Windows%20x64%20%7C%20Android%20ARM64-58677D?style=flat-square" />
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-58677D?style=flat-square" /></a>
</p>

<p align="center">
  <a href="https://github.com/gooesman/AnotherVaporAuth/releases/latest">Download</a> ·
  <a href="https://github.com/gooesman/AnotherVaporAuth/releases">Release notes</a> ·
  <a href="https://github.com/gooesman/AnotherVaporAuth/issues">Report an issue</a>
</p>

GooeSteamKit is **gooesman's independently maintained fork** of
[AVA / AnotherVaporAuth](https://github.com/freefrank/AnotherVaporAuth), created by
freefrank. It adds account tools, inventory and market improvements, optional
connectivity and in-app updates while retaining AVA's themes and maFile support.
Local features and skins require no Pro verification; payments and ads are disabled
in this fork. This is a community project, unaffiliated with Valve or Steam.

## Download and update

| Platform | Download from this fork | File to choose |
|---|---|---|
| **Windows x64** | [Windows installer](https://github.com/gooesman/AnotherVaporAuth/releases/latest) | `AVA-pc-…-windows-x64-setup.exe` |
| **Android ARM64** | [Android APK](https://github.com/gooesman/AnotherVaporAuth/releases/latest) | `AVA-Fork-…-android-arm64.apk` |

Both apps are named **GooeSteamKit**. Download filenames retain their earlier
prefixes so existing in-app updaters can recognize them. This fork currently
publishes Windows and Android packages.

Already installed? Open **Settings → Software updates**. Both platforms offer
automatic download acceleration through third-party GH-Proxy routes, with GitHub
as fallback, or a GitHub-only option. Downloads show progress and speed and are
checked against GitHub's file size and SHA-256 before you confirm installation.
Android completes installation through its system installer.

Update checks still need GitHub's official metadata; mirror availability and speed
depend on your network. See the [update and release guide][releases-guide].

## What you can do

| Feature | What it provides |
|---|---|
| **Accounts and Steam Guard** | Multiple accounts, offline codes, countdowns, copy, maFile import/export and a remembered username/nickname/Steam ID display choice. |
| **Account overview** | Wallet balance, pending funds, market activity, and optional friends, inventory and market-favorite previews. Enable each card in Settings or the overview's tune menu; the phone home screen stays focused on codes and accounts. |
| **Windows Steam sign-in** | Select an imported account and use either sign-in button to open/switch Steam and approve this attempt's verified local sign-in QR. Manual screen-region QR selection is also available. |
| **Friends and trades** | Friends list, friend-request acceptance/decline, received/sent offers, both sides' inventories, offer review and trade confirmations. |
| **Notifications and pending counts** | Home account rows show pending confirmations. Notifications and friend requests load when opened; unread messages appear first and read history is collapsed by default. Visible inventory notifications fetch individual item names and thumbnails on demand. Inventory, trade-offer and friend-request actions open the relevant in-app page; other types link to Steam's notification center. Notifications can be marked read or ignored. |
| **Inventory and listings** | Game/context selection, name search, type/rarity filters, subtle rarity borders, Steam-provided cooldown details, batch listing, and active/held/pending listings. |
| **Market prices** | Search by item, game and currency; save favorites for direct price viewing in your selected currency, view item details, or open the Steam market page. |
| **Backup login codes** | Request and verify Steam's SMS code inside the app, then display the one-time backup login codes. |
| **Optional connectivity** | Follow detected external proxy routes first, with a built-in fallback using your Clash subscription and a visible current-route status. |
| **App lock and sync** | Optional startup PIN verification and system unlock; encrypted WebDAV account/settings sync, including market favorites, currency and acceleration subscriptions, with local/remote comparison and explicit upload/pull. |
| **Appearance and other tools** | Light/dark/system appearance, skins, compact refresh indicators, device sessions, Steam key redemption and seven languages. |

### Everyday controls

- **Phone:** tap an account to select its home-screen code; long-press to open its overview for inventory, market, friends and backup codes.
- **Desktop:** select an account from the list and use the inline overview or right-click menu. The avatar does not open a duplicate full-screen overview; a narrow window retains an overview menu entry. Account rows do not use left/right swipe actions.
- **Copy account information:** right-click the selected name on desktop or long-press it on a phone to copy the exact Steam nickname, login name or SteamID. A normal tap still cycles the remembered display choice.
- **Device sessions:** revoke other device authorizations after reviewing the listed targets, while retaining this GooeSteamKit session and the authenticator. Unconfirmed or failed operations are reported rather than retried silently.
- **App lock:** system unlock is an option under startup verification. Turning startup verification off also turns system unlock off; local account files remain encrypted.

### Market prices in your selected currency

Choose a game and currency, enter an item name, then select **Search market**.
Visible results automatically request the **lowest asking price in that currency**;
you do not need to refresh each item. Changing currency updates visible quotes.
Item details show recent median sale prices separately from asking prices.

Use the star beside a result to save it. **Favorites** opens your saved products
without another search and remembers the selected currency. Only visible rows
load quotes; hidden favorites do not make background price requests.
The optional overview card previews up to four favorites in the same currency,
with a shortcut to the complete list. New preview cards are off by default.

Searches are explicit, results are paged, and recent quotes are cached. The app
does not continuously poll prices or convert an unverified USD search result into
a CNY label. If Steam limits requests or a quote is unavailable, it shows the
unavailable state and lets you retry. Prices are references, not a promise of a
trade at that price.

Inventory and trade selections also show Steam's restriction notes. When Steam
provides a recognizable expiry time, details show local time and the remaining
duration when opened. An unavailable expiry is not guessed from the item type.

### Compare and synchronize devices

In **Settings → Sync → Compare local and remote**, expand a row to inspect its
differences, then choose **Pull remote → local** or **Upload local → remote**.
Each action handles that row only: an account is one row; enabled app settings,
market favorites/currency and acceleration subscription form one settings row.
Account secrets and subscription credentials are hidden in the comparison.

Changes are compared with the last shared version; displayed sync times are
for reference. When settings changed on both devices, synchronization waits for
your choice. An outdated comparison must be refreshed before applying it.
Favorites and currency sync when **Sync app settings** is enabled; cached prices
are not synchronized. See the [sync design and behavior][sync-guide].

### Optional Steam connectivity

Add your **HTTP or HTTPS Clash subscription**, select a supported node, and enable
automatic switching for this session or at startup. Detected external HTTP
proxies or VPN/TUN routes take priority. When an external route disappears, the
enabled built-in fallback takes over if the network environment can be identified.
The app shows the current route separately from Steam connection-check results.

This applies to **Steam requests inside GooeSteamKit**. It does not accelerate the
Steam desktop client or games, or change system proxy/DNS settings. App-local
acceleration does not create a system VPN icon. PAC/unknown environments and some
subscription node types have limitations; see [connectivity details][connectivity].

## Install and migrate

| Your current app | How to move to GooeSteamKit |
|---|---|
| **GooeSteamKit / AVA-pc on Windows** | Install the newer package over the existing installation; the existing data location is retained. |
| **GooeSteamKit / AVA Fork on Android** | Install the newer official fork APK with the same package and signature; accounts and settings are retained. |
| **Original AVA / older AVA dev on Android** | Keep the old app, install GooeSteamKit alongside it, then export/import your accounts' `.maFile` files. PIN and local settings are separate. |
| **Steam Desktop Authenticator** | Import the `maFiles` folder. For encrypted accounts, include `manifest.json` and supply the original password. |

Keep a backup of your account files and revocation code. Importing a code-only
account does not establish an online Steam session; sign-in, trading and market
actions still depend on Steam's session and account requirements.
See the [installation and migration steps][migration] and [Windows sign-in guide][switch-guide].

## Privacy

Accounts and authenticator keys are stored locally. Steam operations use Valve's
services over the selected network route. Optional WebDAV sync sends encrypted
account data and enabled settings to a server you choose. Backup login codes and
QR screenshots are held in memory, not saved to logs or synced. Reports are not
uploaded automatically; feedback opens this repository's Issues page.

Read the [fork privacy notice][privacy] for network routes, subscriptions, update
mirrors and sync metadata. The root `PRIVACY.md` files describe the original AVA.

## Source and development

The fork's application development is on
[`feature/windows-steam-account-switch`][source]. Use that branch or a published
release tag to build the fork. Requires **Flutter 3.44.4 / Dart 3.12.2** and the
platform's build tools.

```sh
git clone --branch feature/windows-steam-account-switch https://github.com/gooesman/AnotherVaporAuth.git
cd AnotherVaporAuth/app
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run -d windows
```

Android uses `cn` / `play` flavors. The distributed fork uses the **CN ARM64**
build, a separate package identity and a persistent signing key. Follow the
[build notes][build-guide] and [release workflow][releases-guide] for those settings;
self-signed builds cannot replace the distributed APK in place.

## Credits and licenses

Thanks to **freefrank**, the creator of AVA, and its contributors. AVA was inspired
by Steam Desktop Authenticator; protocol references include
[SteamAuth](https://github.com/geel9/SteamAuth) and
[node-steam-session](https://github.com/DoctorMcKay/node-steam-session).

Application source retains the original author's [MIT license](LICENSE).
[Bundled fonts][fonts] retain their own licenses. The optional Mihomo component is
covered by its [third-party notices][mihomo]; matching source and license files
are included with fork releases. Local feature availability does not grant access
to the original project's paid online services.

[source]: https://github.com/gooesman/AnotherVaporAuth/tree/feature/windows-steam-account-switch
[build-guide]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/app/README.md
[releases-guide]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/docs/fork-releases.md
[switch-guide]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/docs/windows-steam-switch.md
[sync-guide]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/docs/specs/2026-08-12-config-sync-design.md
[connectivity]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/docs/windows-steam-switch.md#optional-steam-connectivity
[migration]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/docs/windows-steam-switch.md#android-installation-and-migration
[privacy]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/docs/fork-privacy.md
[fonts]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/app/assets/fonts/README.md
[mihomo]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/third_party/mihomo/NOTICE
