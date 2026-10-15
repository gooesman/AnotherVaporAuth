# GooeSteamKit privacy notice

Updated: 2026-10-14. This notice describes **GooeSteamKit**, gooesman's independent
fork of freefrank's AVA for Windows and Android. Earlier builds were named
**AVA-pc** and **AVA Fork**. The new name and icon retain the existing data paths
and Android package/signing identity; existing AVA Fork users do not need to
reimport accounts.

Steam accounts and authenticator secrets are stored on your device. Steam
authentication, inventory, market and trading requests use Valve's services.
Those operations require the relevant account/session information; they do not
go through a server operated by this fork. Detected external HTTP proxies and
system VPN/TUN routes take priority even without a subscription. The optional
built-in fallback uses your selected subscription node when no external route
is detected. A proxy operator can see connection metadata, including destinations, timing
and volume; normal Steam TLS certificate validation remains enabled.

Steam backup login codes are requested only when you choose the in-app SMS and
verification steps. The selected account's session and entered verification code
are sent to Valve over HTTPS. Returned codes stay in page memory and are cleared
on leaving, hiding or locking the app; they are not written to account files,
logs or WebDAV.

While the home screen is visible and the account library is unlocked, existing
sessions query Valve for pending-confirmation, unread-notification and friend-request
counts. Reads are infrequent and reuse an in-memory cache. Notifications
and friend requests load when opened, with unread messages first and read history
collapsed by default. Notification text and item-detail responses stay in page
memory and are not included in sync. Visible inventory notifications request
only the referenced item's details from Valve, including its name and image key;
they do not load the whole inventory. Public thumbnails use the existing Steam
CDN image cache on the device. Inventory, trade-offer and friend-request actions
open their relevant in-app pages; other types can be viewed in Steam's notification center.
Marking read, ignoring notifications, responding to friend requests and revoking
other device authorizations require your explicit action. This does not automatically
handle trades or remove the authenticator. Copying a name or SteamID writes only
to the device clipboard and makes no network request.

Steam acceleration is optional and starts manually by default. Subscription
URLs and sanitized node credentials are kept in local secure storage, separately
from account files. When WebDAV synchronization and **Sync app settings** are
enabled, the subscription URL, sanitized cached nodes and selected node are
included in the settings document encrypted with your synchronization passphrase.
Clearing a subscription also synchronizes its removal. Automatic startup and
running state, local listener credentials/ports and detected proxy/VPN information
stay on each device. Applying a synchronized subscription does not fetch nodes
or start acceleration. Older apps cannot synchronize these fields; an older
document missing them leaves the newer app's local subscription intact. Update
both devices to synchronize subscriptions reliably.
Choosing **Refresh nodes** contacts your subscription provider; automatic startup
may fetch it when no cached node is available.
HTTP and HTTPS subscriptions are supported; credentials in the URL are sent as
HTTP Basic authentication to that origin only. An HTTP subscription sends its
URL, credentials and response without transport encryption. This does not change
the TLS validation used by Steam connections or component downloads.
Windows downloads its fixed-version component on first use, trying
`axisnow.gh-proxy.org`, then `v4.gh-proxy.org`, then the upstream GitHub release.
These requests use an independent direct client without subscription or app-proxy
credentials; an existing system VPN/TUN may still carry them. Providers can see
the client IP, public component path, timing and traffic volume. Both the archive
and extracted executable must match SHA-256 values pinned in the app before use.
The Android package includes the same core. The core uses a private local
listener and receives its configuration in memory, with no retained diagnostics.
GooeSteamKit checks system proxy/VPN information locally every five seconds while
visible and on foreground return. It does not upload that information or modify
system proxy, DNS or certificates. An enabled session fallback pauses its core
for an external route and resumes after the external route disappears and the
environment is known-clear. Pausing automatic switching cancels that session's
fallback, while external routing remains in effect. The startup preference stays
local. Unknown or unresolved PAC/automatic-discovery settings prevent internal
startup; the app does not run PAC scripts. Local checks pause while the app is
hidden. Changing routes does not automatically repeat an in-flight write.
Connectivity checks contact Steam's public API and community over the same
current route, without account cookies or tokens. They run after relevant route
changes, on foreground return when the last result is stale, or when you choose
to check, rather than continuously polling Steam.
Results describe reachability, not account authentication or trading permission.

Market favorites store public product identities, display metadata and your
selected quote currency in a local `market_favorites.json` file. With **Sync app
settings** enabled, these fields are also included in the encrypted settings
document; cached prices and availability counts are not synchronized. Only
visible market rows, including rows in an enabled overview favorites card,
request quotes from Steam, with no background price polling. Overview card
visibility is a device-local preference and is not synchronized.

Optional WebDAV synchronization sends encrypted account payloads and, when
enabled, the curated settings document to the server you choose. It is disabled
until you configure it. Server-visible synchronization metadata includes SteamIDs,
revisions and payload hashes, not plaintext subscription credentials.
The local/remote comparison decrypts payloads locally. It can show public account
names, SteamIDs, favorite products and ordinary preference differences. Account
secrets, authenticator URIs, subscription URLs and node credentials are hidden;
the page only indicates that private values differ. Each explicit upload/pull
handles one account or the whole settings document, including favorites and the
subscription. Settings changed on both sides wait for this choice.
Local debug logs may include
account names and SteamIDs; the app does not automatically upload those logs.
Screen selections for Steam QR login are decoded locally in memory, and are
not saved or uploaded as screenshots. After an explicit **Open Steam and sign
in** or **Switch account** action for an imported account, the app can also read
the visible client area of the verified local
Steam sign-in window created for that attempt. It verifies the same window and
QR challenge twice, then sends one approval to Valve using the selected account.
It does not automatically approve unrelated pending login requests. Cancellation,
locking or leaving the page stops further approval; a request already submitted
cannot be revoked by stopping. The result verifies the Steam client's current
local account, not server-side session availability. Images stay in local memory.

This fork does not verify Pro subscriptions, redeem purchases, load ads or
refresh existing entitlement tokens. Local features do not require an upstream
subscription. Existing entitlement records are left untouched for compatibility.
No token is fabricated and no access to the author's online services is granted.

Opening the update page in Settings checks this fork's public GitHub releases.
Automatic downloads first contact GH-Proxy's `axisnow.gh-proxy.org`, then
`v4.gh-proxy.org`, falling back to GitHub. You can select GitHub only before
downloading. The download-source selector remains visible on Windows and Android
even when no update is available or the version check fails. Mirror requests use
a separate direct client without application
proxy credentials; an existing system VPN/TUN may still carry that traffic.
The mirror operator can see your IP address, public file path, user agent,
request timing and traffic volume. No Steam account, authenticator secret,
entitlement token or subscription URL is sent. Version metadata and trusted
digests still come directly from GitHub's official API. Official requests prefer
a detected system HTTP proxy or can reuse an already-running internal
accelerator; its operator can see connection destinations, timing and volume.
Normal TLS checks remain enabled, and updates never start an extra proxy.
Large files may be requested in parallel byte ranges. The app
verifies the download against GitHub's SHA-256 digest before handing it to the
system installer after your confirmation. It does not check the original
project's update service or install updates in the background.
Feedback opens this fork's GitHub issue page in your browser. It does not create
an issue or attach a report automatically. Information you choose to submit on
GitHub follows GitHub's own rules and may be public. Other external links open
their respective sites in your browser.

There is no analytics or tracking added by this fork. The original author's
copyright, MIT license and third-party notices are retained. The root
PRIVACY.md and PRIVACY_ZH.md describe the original project and remain for
reference; the disabled payment, advertising and feedback-relay services in
those documents are not used by this fork's default build.

[简体中文](fork-privacy-zh.md)
