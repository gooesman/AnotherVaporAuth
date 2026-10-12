# gooes SteamKit — Steam authenticator and account toolkit (Flutter)

gooes SteamKit is a lightweight Steam authenticator and account toolkit based on
freefrank's AVA (AnotherVaporAuth), built with Flutter. This fork publishes
**Windows / Android** installers; the shared codebase retains the original
project's macOS and Linux support. **maFiles are fully
compatible** with the legacy Steam Desktop Authenticator format for zero-cost
migration.

See the design spec: `../docs/specs/2026-06-29-flutter-rewrite-design.md`

Windows and Android both display **gooes SteamKit**, using
[`assets/icon/gooes_steamkit.png`](assets/icon/gooes_steamkit.png). Windows keeps
the existing executable and data paths. Android keeps the AVA Fork package and
signing identity, so existing **AVA Fork** installations update in place without
reimporting accounts. The original AVA and earlier AVA dev use separate packages
and require the one-time migration described below. Release filenames keep the
`AVA-pc-` and `AVA-Fork-` prefixes for older in-app updaters.

## Architecture

```
lib/src/
  core/                 # pure Dart, no Flutter — unit-testable
    crypto/             # MaFileCrypto (PBKDF2+AES-CBC), SteamRsa
    proto/              # minimal protobuf wire codec
    models/             # SteamGuardAccount, SessionData, Manifest, Confirmation
    protocol/           # 10 Steam clients — SteamAuthSession, Confirmations,
                        #   AuthenticatorLinker, QrApproval, TradeOffers,
                        #   Market, Inventory, FamilyGroups, Sessions, StoreKey
                        #   (+ eresult / community_session: shared helpers)
    steam_totp.dart     # auth code + confirmation hash
  services/             # StorageProvider, AccountStore, SteamApiClient,
                        #   SteamTime, SessionManager
  app/                  # Riverpod providers, app shell, settings store
  ui/                   # Material 3 screens (visual style intentionally minimal)
l10n/                   # ARB localizations (en, zh, zh_Hant, de, fr, es, ru)
```

## Status (1.5.5)

Implemented and statically verified end-to-end:

- maFile compatibility (PBKDF2 50k/SHA1 + AES-256-CBC, byte-compatible)
- TOTP codes + countdown, copy, account list/reorder
- Username / nickname / Steam ID display choice for the home panel and account
  list, remembered on this device across desktop and phone app restarts
- Phone account tap selects the home token; long-press opens that account's
  overview directly, with no intermediate menu. Desktop selection and right-click
  actions remain available.
- Encryption: mandatory local PIN, PIN changes, and optional startup verification
  (disabling verification keeps the account files encrypted)
- System unlock is a subordinate startup-verification option; disabling the
  parent clears its credential. Re-enabling the parent does not restore system
  unlock until the user enables and authorizes it again.
- Backup login codes: explicit in-app SMS request, verification and memory-only
  display, with no automatic retry or persistent code cache.
- Optional Steam app connectivity via an HTTP/HTTPS Clash node subscription;
  manual start by default, optional automatic start, external-proxy detection.
  Update files default to GH-Proxy direct routes with GitHub fallback and an
  official-only option. Official metadata/requests can reuse an active proxy.
  Large packages use up to four ranges and the official SHA-256 for full hashing.
  It never writes system proxy/DNS settings or routes other apps.
- Import existing `.maFile`
- **Pending center** (tabbed): trade/market confirmations with **batch**
  accept/reject; **trade offers** (received/sent/history, expandable cards,
  accept via `IEconService` + community endpoints). Two tabs since v0.92.0 —
  family-group invites moved to the family group screen
- **Hold-to-confirm** control (settings-aware) for every irreversible action —
  accepts and account deletion — with accelerating haptics; **Hold to
  confirm** / **Hold to delete** / **Haptic feedback** toggles
- **Session-invalid notice**: a definitive InvalidPassword from the background
  refresh (password changed elsewhere) marks the account on the home screen
  and routes to re-login; network errors never mark or absolve
- **Family group** page (members, roles, slots, cooldown) — read-only apart
  from the incoming invites it now hosts: pre-join checks, then hold-to-join
  (`IFamilyGroupsService`)
- Desktop window geometry persisted and refitted to the displays present
- Inventory browse + Community Market list/cancel with live fees
- A read-only Market search tab with explicit searches, currency/game filters,
  paged prices and item details. No startup requests or per-row price polling;
  five-minute bounded page caching and cancellation when hidden. Inventory and
  personal listings load only on their active tabs.
- Login (username/password + **QR login**), Steam Guard code, session refresh
- Add authenticator (phone → SMS → revocation confirm)
- **Move an existing authenticator to this device** (`RemoveAuthenticatorViaChallenge*`;
  no 15-day trade hold, unlike removing it on the website)
- **QR approve** external sign-ins (direction B; scan on mobile / paste on desktop)
- **Device sessions** — list every signed-in device/browser and remotely sign one
  out (`IAuthenticationService/EnumerateTokens` + `RevokeRefreshToken`)
- **Redeem Steam product keys** — the store's own `/account/ajaxregisterkey/`
  (there is no Web API equivalent; see `docs/specs/2026-07-27-redeem-key-design.md`),
  with `EPurchaseResultDetail` mapped to per-reason copy. **Success path verified
  on a live account** (2026-07-29); the individual rejection codes and the
  receipt's field spelling are still unconfirmed
- **Fork local features** — all skins work without Pro verification; payments,
  ads and upstream entitlement requests are disabled. Legacy entitlement code
  remains isolated for compatibility testing, with no user-facing enable switch.
  The CN preview contains no ads or billing classes.
- **Phone home** — token and account list in both orientations; select an account
  without opening its overview. Long-press for overview, market, friends or backup
  login codes. Wallet and market requests begin when those tools are opened.
  Desktop keeps the overview beside the account list.
- **Android back gestures** — no page movement during the gesture; a short fade
  after a committed back action, with the current page retained on cancellation.
  Xiaomi 15 Pro behavior still needs a device check.
- **Software updates** — Settings opens this fork's public GitHub release check.
  Download is explicit and cancellable; file size and SHA-256 are verified before
  a separate install confirmation. Android uses its system permission and installer,
  while Windows starts the installer and then closes gooes SteamKit. No release, network
  failure and an unverifiable package are distinct states, never silent installation.
- **Block screenshots** — opt-in `FLAG_SECURE` toggle (Android only; off by
  default, since it also blanks screen sharing and feedback screenshots)
- **Versioned privacy consent** — the first-run notice is tracked by revision,
  not a boolean, so changing what it *says* re-asks instead of relying on
  agreement to different wording. Someone who accepted an earlier revision
  gets a "what changed" screen rather than the first-run welcome, and Agree
  stays disabled until the notice has been scrolled to the end (a notice that
  fits the viewport enables it immediately — see
  `test/widget/app_smoke_test.dart`)
- i18n — **seven locales**: English, 简体中文, 繁體中文, Deutsch, Français,
  Español, Русский. Each is translated from the English template, not machine
  converted; `zh_Hant` uses Taiwan vocabulary and `zh_HK` matches it by script
  rather than falling back to Simplified. System or manual language; the
  stored choice is a full BCP-47 tag, so the script subtag survives a restart.
  Adding a locale means touching **three** unconnected places — the ARB, the
  `kSelectableLocales` picker list, and `steamLanguageFor()` (miss the last
  and Steam-served item names stay English); `test/app/locales_test.dart`
  fails if they drift apart

Verification: `flutter analyze` clean, **1420 tests pass** (crypto RFC vectors,
TOTP/confirmation cross-impl vectors, protobuf round-trip incl. family-groups
codec, trade-offer/model JSON, hold-button haptics, AccountStore end-to-end,
entitlement signature/grace/clock-skew, sessions-client revoke HMAC vectors,
pending-center + family-screen widget tests, app smoke render).

### Not yet verifiable here

Network flows (login, confirmations, trade offers, linking, QR-approve,
family groups) are implemented to the documented Steam protocol but require
**live Steam credentials** to integration test. Two surfaces are still
protocol-speculative until validated on a real account (see
`../docs/plans/archive/2026-07-15-family-groups.md` 执行后记): the family **join** nonce
(sent as `invite_id`) and the ePrivilege=5 pre-join **check** endpoint's
availability to ordinary user tokens. The QR-approve (direction B) signature
scheme should likewise be checked against a live capture before production use.

The original project's recorded **Linux desktop and Android release checks**:

- Linux desktop: release bundle ~27 MB (AOT).
- Android release: cn universal APK 91 MiB, play AAB 85 MiB (v1.2.3). Debug
  builds are far larger — 186 MB universal, 119 MB with
  `--target-platform android-arm64`, since `lib/` is ~71% of them.
  Android builds use the NDK version selected by Flutter.

This fork's Android workflow produces an **ARM64 CN optimized release-mode preview** named
**gooes SteamKit** (`pro.dotslash.ava.fork`), signed with the same stable private
fork key as earlier **AVA Fork** builds. A higher Android version code updates
an existing AVA Fork installation directly, retaining its accounts and settings.
It installs alongside the original AVA and earlier AVA dev preview. Only that
first migration starts with an empty vault and requires importing exported
`.maFile` files; local settings and the app PIN are separate from those old apps.
Do not uninstall the old app to bypass a signature mismatch. See the
[installation and migration guide](../docs/windows-steam-switch.md#android-installation-and-migration).

```sh
flutter pub get --enforce-lockfile
flutter test                       # 1420 tests
flutter build linux --release      # build/linux/x64/release/bundle (~27MB)
flutter run -d linux               # or windows / macos

# Android is flavor-split (play / cn) — a build with no --flavor FAILS.
# --flavor and --dart-define must agree; the define defaults to cn.
flutter build appbundle --flavor play --dart-define=AVA_CHANNEL=play  # Play Store
flutter build apk --flavor cn --dart-define=AVA_CHANNEL=cn            # GitHub release
flutter run --flavor cn --dart-define=AVA_CHANNEL=cn                  # day-to-day
```

Manjaro/Arch toolchain:

```sh
# desktop
sudo pacman -S --needed clang cmake ninja gtk3
# android
sudo pacman -S --needed jdk17-openjdk
# + Android cmdline-tools in ~/Android/Sdk, then:
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
flutter config --android-sdk ~/Android/Sdk
```

Notes:
- `android/build.gradle.kts` forces every plugin's `compileSdk` to 36 in
  `afterEvaluate` (file_picker 8.x pins 34, which breaks the release build).
- The fork preview workflow sets `ORG_GRADLE_PROJECT_avaForkPreview=true`
  (equivalent to Gradle `-PavaForkPreview=true`). This selects the existing AVA Fork
  package with the gooes SteamKit display name and uses `android/key.properties`
  (git-ignored) to sign the optimized release APK. Missing signing fields or the
  keystore fail the build; no temporary debug
  key is substituted. Without that property, ordinary debug builds remain
  **AVA dev** and do not update the AVA Fork / gooes SteamKit package.
- Release signing also comes from `android/key.properties`. Release artifacts
  fail closed without it; `-PallowDebugSigning=true` explicitly permits the
  public debug-key fallback for local experiments only.

## Toolchain

Flutter 3.44.4 · Dart 3.12.2.
