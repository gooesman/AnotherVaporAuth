# Privacy notice for this AVA fork

Updated: 2026-10-10. This notice describes gooesman's independent fork of
freefrank's AVA, including its **AVA-pc** Windows and **AVA Fork** Android preview
builds.

Steam accounts and authenticator secrets are stored on your device. Steam
authentication, inventory, market and trading requests go directly to Valve's
services. Those operations require the relevant account/session information;
they do not go through a server operated by this fork.

Optional WebDAV synchronization sends encrypted account data to the server you
choose. It is disabled until you configure it. Local debug logs may include
account names and SteamIDs; the app does not automatically upload those logs.
Screen selections for Steam QR login are decoded locally in memory, and are
not saved or uploaded as screenshots.

This fork does not verify Pro subscriptions, redeem purchases, load ads or
refresh existing entitlement tokens. Local features do not require an upstream
subscription. Existing entitlement records are left untouched for compatibility.
No token is fabricated and no access to the author's online services is granted.

Opening the update page in Settings checks this fork's public GitHub releases.
Downloading an update contacts GitHub's release asset servers; no Steam account,
authenticator secret or entitlement token is sent with those requests. The app
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
