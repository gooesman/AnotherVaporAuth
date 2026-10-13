// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get steamSwitchTitle => 'Switch Steam account';

  @override
  String get steamSwitchHelp =>
      'Switch between Steam accounts that have already signed in on this PC with their sign-in details remembered. Importing an authenticator into GooeSteamKit does not sign that account in to the Steam client.';

  @override
  String get steamSwitchPath => 'Steam installation folder';

  @override
  String get steamSwitchNotFound =>
      'Steam was not found. Choose steam.exe to locate your installation.';

  @override
  String get steamSwitchBrowse => 'Choose steam.exe';

  @override
  String get steamSwitchNoAccounts =>
      'No saved Steam accounts were found on this PC. Sign in to Steam, enable remembering your sign-in details, then refresh.';

  @override
  String get steamSwitchNoMatch =>
      'The selected account has no sign-in record on this PC. Use the one-click sign-in above, then refresh after Steam remembers the account to switch from the list below.';

  @override
  String get steamSwitchNeedsLogin =>
      'Sign in to this account in Steam and enable remembering your sign-in details, then refresh.';

  @override
  String get steamSwitchButton => 'Switch account';

  @override
  String steamSwitchConfirm(String account) {
    return 'Steam will close and restart to sign in as $account. First close your games and wait for Steam Cloud saves to finish syncing. Continue?';
  }

  @override
  String get steamSwitchStopping => 'Waiting for Steam to exit…';

  @override
  String get steamSwitchBackingUp => 'Backing up Steam settings…';

  @override
  String get steamSwitchConfiguring => 'Selecting the Steam account…';

  @override
  String get steamSwitchStarting => 'Starting Steam…';

  @override
  String get steamSwitchRestoring => 'Restoring Steam settings…';

  @override
  String get steamSwitchLaunched =>
      'Steam has started. Check the signed-in account in the client. Sign in again if prompted.';

  @override
  String get steamSwitchBackup => 'Settings backup location';

  @override
  String get steamSwitchInvalidPath =>
      'This Steam installation or its settings could not be read. Choose the correct steam.exe and try again.';

  @override
  String get steamSwitchCloseFailed =>
      'Steam could not exit normally. Exit Steam manually, then try again.';

  @override
  String get steamSwitchBusy =>
      'Another account switch is in progress. Try again shortly.';

  @override
  String get steamSwitchChanged =>
      'Steam settings changed during the switch. Exit Steam, refresh the list, then try again.';

  @override
  String get steamSwitchFailed =>
      'The account switch could not finish. Check Steam and try again.';

  @override
  String get steamSwitchRecoveryNeeded =>
      'The account switch failed and some settings could not be restored. Keep the backup below and restore the settings before trying again.';

  @override
  String get appTitle => 'GooeSteamKit';

  @override
  String get navAccounts => 'Accounts';

  @override
  String get navSettings => 'Settings';

  @override
  String get unlockTitle => 'Unlock';

  @override
  String get unlockPrompt => 'Enter your encryption passkey';

  @override
  String get unlockButton => 'Unlock';

  @override
  String get unlockInvalid => 'That passkey is invalid.';

  @override
  String get unlockWithBiometric => 'Unlock with biometrics / device PIN';

  @override
  String get unlockLoading => 'Decrypting…';

  @override
  String get unlockCantUnlock => 'Can\'t unlock?';

  @override
  String get resetVaultTitle => 'Reset encrypted data';

  @override
  String get resetVaultBody =>
      'This deletes every account entry and encryption key stored on this device; afterwards you re-import your maFile backups. Your Steam accounts and their authenticators are not affected.\n\nUse this when the correct PIN keeps being rejected — typically after a backup restore or phone migration, since the hardware key never leaves the original device, restored data can never be decrypted.\n\nThis cannot be undone.';

  @override
  String get resetVaultConfirm => 'Delete & reset';

  @override
  String get storeErrorTitle => 'Stored data can\'t be read';

  @override
  String get storeErrorBody =>
      'GooeSteamKit\'s local account database (manifest.json) is missing or corrupt. This can happen after an interrupted write or a partial restore. Retry first; if it keeps failing, reset and re-import your maFile backups.';

  @override
  String get storeRepair => 'Attempt repair';

  @override
  String storeActionFailed(String error) {
    return 'Action failed: $error';
  }

  @override
  String get pinSetupTitle => 'Set unlock PIN';

  @override
  String get pinSetupPrompt =>
      'Protect GooeSteamKit with a 6-digit PIN. You\'ll enter it (or your fingerprint) to unlock.';

  @override
  String get pinLabel => '6-digit PIN';

  @override
  String get pinConfirmLabel => 'Confirm PIN';

  @override
  String get pinSetButton => 'Set PIN';

  @override
  String get settingsSet => 'Set';

  @override
  String get pinChangeTitle => 'Change PIN';

  @override
  String get pinCurrentLabel => 'Current PIN';

  @override
  String get pinNewLabel => 'New PIN';

  @override
  String get pinSixDigits => 'Enter a 6-digit PIN.';

  @override
  String get pinMismatch => 'The PINs don\'t match.';

  @override
  String get unlockBiometricReason => 'Unlock GooeSteamKit';

  @override
  String get settingsBiometric => 'Use device unlock';

  @override
  String get settingsBiometricDesc =>
      'Use fingerprint, Windows Hello or your device credential instead of the GooeSteamKit PIN when startup verification is on. Turning startup verification off disables this option; enable it separately after turning verification back on.';

  @override
  String get settingsBiometricNeedPasskey => 'Set an encryption passkey first.';

  @override
  String get settingsBiometricUnavailable =>
      'No biometrics or device lock set up on this device.';

  @override
  String get settingsBiometricEnabled => 'Device unlock enabled';

  @override
  String get settingsHoldConfirm => 'Hold to confirm';

  @override
  String get settingsHoldConfirmDesc =>
      'Irreversible accepts (trades, confirmations) require press-and-hold. When off, a single tap acts immediately; batch actions still ask first.';

  @override
  String get settingsDeleteHold => 'Hold to delete';

  @override
  String get settingsDeleteHoldDesc =>
      'The Delete button in the removal dialog must be held until it charges up — an accidental tap can\'t remove an account.';

  @override
  String get accountSessionInvalid => 'Sign-in invalid — tap to log in again';

  @override
  String get settingsHaptics => 'Haptic feedback';

  @override
  String get settingsHapticsDesc =>
      'Vibration ticks while holding to confirm and on completion.';

  @override
  String get settingsBlockScreenshots => 'Block screenshots';

  @override
  String get settingsBlockScreenshotsDesc =>
      'Hides GooeSteamKit from screenshots, screen recording and the recent-apps preview. Also blanks the window during screen sharing, and stops you attaching screenshots to feedback.';

  @override
  String get passkeyLabel => 'Passkey';

  @override
  String get accountsEmpty =>
      'No accounts yet. Import a maFile or log in to add one.';

  @override
  String get emptyAddAccount => 'Add account';

  @override
  String get accountReady => 'Ready';

  @override
  String get tutCodeTitle => 'Live token';

  @override
  String get tutCodeBody =>
      'Tap the big code to copy it. Tap the account name to cycle username / nickname / SteamID.';

  @override
  String get tutSwipeRightTitle => 'Swipe right → confirmations';

  @override
  String get tutSwipeRightBody =>
      'Swipe an account to the right to open its trade confirmations.';

  @override
  String get tutSwipeLeftTitle => 'Swipe left → more actions';

  @override
  String get tutSwipeLeftBody =>
      'Swipe left to refresh the session, export the maFile, or remove the account.';

  @override
  String get tutLongPressTitle => 'Long-press → inventory & market';

  @override
  String get tutLongPressBody =>
      'Long-press an account to browse its inventory and list items on the Community Market.';

  @override
  String get tutPullTitle => 'Pull to refresh';

  @override
  String get tutPullBody =>
      'Pull the account list down to refresh avatars and check pending sign-ins.';

  @override
  String get tutSkip => 'Skip';

  @override
  String get tutNext => 'Next';

  @override
  String get tutDone => 'Got it';

  @override
  String get settingsTutorial => 'Gesture tutorial';

  @override
  String get settingsTutorialDesc =>
      'Replay the home-screen walkthrough (swipes, long-press, pull-to-refresh).';

  @override
  String get settingsTutorialReplay => 'Replay';

  @override
  String get welcomeTitle => 'Welcome to GooeSteamKit';

  @override
  String get welcomeSubtitle =>
      'Your authenticator is stored encrypted on this device. Choose how to begin.';

  @override
  String get welcomeLoginCta => 'Log in to Steam';

  @override
  String get welcomeLoginSub => 'Set up a new authenticator';

  @override
  String get welcomeImportCta => 'Import .maFile';

  @override
  String get welcomeImportSub => 'Migrate an existing account';

  @override
  String get welcomeSyncCta => 'Restore from sync';

  @override
  String get welcomeSyncSub =>
      'Pull your accounts from an existing sync library';

  @override
  String get copyCode => 'Copy code';

  @override
  String get codeCopied => 'Login code copied to clipboard';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get copySteamId => 'Copy SteamID';

  @override
  String get pendingTitle => 'Pending';

  @override
  String get pendingTabConfirmations => 'Confirmations';

  @override
  String get pendingTabOffers => 'Trade offers';

  @override
  String get confirmationsTitle => 'Confirmations';

  @override
  String get confirmationsEmpty => 'No pending confirmations.';

  @override
  String get confirmationsRefresh => 'Refresh';

  @override
  String get confAccept => 'Accept';

  @override
  String get confDecline => 'Decline';

  @override
  String get confSelectAll => 'Select all';

  @override
  String get confAcceptSelected => 'Accept selected';

  @override
  String get confDeclineSelected => 'Decline selected';

  @override
  String get confAcceptAll => 'Accept all';

  @override
  String get confRejectAll => 'Reject all';

  @override
  String confAcceptAllConfirm(int count) {
    return 'Accept all $count confirmations?';
  }

  @override
  String confRejectAllConfirm(int count) {
    return 'Reject all $count confirmations?';
  }

  @override
  String get confAcceptAllWarn =>
      'This approves every pending trade and market listing at once. Make sure you recognize all of them.';

  @override
  String get confRejectAllWarn =>
      'This cancels every pending confirmation at once.';

  @override
  String confPending(int count) {
    return '$count pending';
  }

  @override
  String get confAllProcessed => 'All processed';

  @override
  String get confTypeTrade => 'Trade';

  @override
  String get confTypeMarket => 'Market listing';

  @override
  String get confTypeOther => 'Confirmation';

  @override
  String get confTypeFamilyJoin => 'Family invite';

  @override
  String get confTypeApiKey => 'API key';

  @override
  String get confTypePhoneChange => 'Phone change';

  @override
  String get confTypeAccountRecovery => 'Account recovery';

  @override
  String get confTypeFeatureOptOut => 'Feature opt-out';

  @override
  String confProcessing(int count) {
    return 'Processing $count confirmation(s)…';
  }

  @override
  String confResult(int ok, int fail) {
    return '$ok succeeded, $fail failed';
  }

  @override
  String get confNeedsLogin =>
      'Session expired — sign in again to refresh this account.';

  @override
  String get confRejected =>
      'Steam rejected the confirmation request. This usually means the maFile does not match the authenticator currently on the account (common with purchased accounts) — remove the authenticator and link it again, or import the right maFile. A large clock drift can also cause this.';

  @override
  String get offersSegReceived => 'Received';

  @override
  String get offersSegSent => 'Sent';

  @override
  String get offersSegHistory => 'History';

  @override
  String get offersEmpty => 'No trade offers.';

  @override
  String get offerGift => 'Gift — you give nothing';

  @override
  String get offerOneSided => 'You give items and receive nothing';

  @override
  String get offerEscrow => 'Items will be held by Steam before delivery';

  @override
  String get offerAcceptHold => 'Hold to accept';

  @override
  String get offerDecline => 'Decline';

  @override
  String get offerCancel => 'Cancel offer';

  @override
  String get offerReceiveLabel => 'You receive';

  @override
  String get offerGiveLabel => 'You give';

  @override
  String get offerAccepted =>
      'Offer accepted — confirm it in the Confirmations tab';

  @override
  String get offerAcceptedNoConf => 'Offer accepted.';

  @override
  String offerActionFailed(String msg) {
    return 'Action failed: $msg';
  }

  @override
  String get offerDeclined => 'Offer declined.';

  @override
  String get offerCanceled => 'Offer canceled.';

  @override
  String get pendingTabInvites => 'Invites';

  @override
  String famInviteTitle(String groupName) {
    return '「$groupName」 invited you to join';
  }

  @override
  String get famInviteTitleGeneric => 'Family group invite';

  @override
  String famInviteFrom(String inviter) {
    return 'Invited by $inviter';
  }

  @override
  String famInviteRole(String role) {
    return 'Role: $role';
  }

  @override
  String famInviteSlots(int used, int total) {
    return 'Members $used/$total';
  }

  @override
  String get famRoleAdult => 'Adult';

  @override
  String get famRoleChild => 'Child';

  @override
  String famRoleUnknown(int n) {
    return 'Role #$n';
  }

  @override
  String get famPreflightTitle => 'Join checks';

  @override
  String get famCheckWalletMatch => 'Wallet region matches';

  @override
  String get famCheckWalletMismatch =>
      'Wallet region doesn\'t match — Steam restricts joining';

  @override
  String get famCheckIpMatch => 'Usual IP matches';

  @override
  String get famCheckIpMismatch => 'IP doesn\'t match your usual location';

  @override
  String get famCheckCooldown =>
      'Joining locks family-group switching for 1 year (Steam cooldown)';

  @override
  String famJoinRestricted(int code) {
    return 'Steam blocked this join (restriction $code)';
  }

  @override
  String get famInviteJoinHold => 'Hold to join';

  @override
  String get famInviteAwaiting2fa =>
      'Waiting for confirmation — check the Confirmations tab';

  @override
  String get famInviteJoined => 'Joined ✓';

  @override
  String get famInviteViewGroup => 'View family group ›';

  @override
  String get famJoinSent =>
      'Join requested — confirm it in the Confirmations tab';

  @override
  String get famJoinDone => 'Joined the family group.';

  @override
  String famJoinFailed(String msg) {
    return 'Join failed: $msg';
  }

  @override
  String get famInvitesEmpty => 'No pending family invites.';

  @override
  String get famAccountAction => 'Family group';

  @override
  String get famNotInGroup => 'This account isn\'t in a family group.';

  @override
  String famSummaryMembers(int used, int total) {
    return 'Members $used/$total';
  }

  @override
  String famSummaryCooldown(int days) {
    return 'Cooldown ${days}d';
  }

  @override
  String get famInvitesSection => 'Invites';

  @override
  String get famSectionMembers => 'Members';

  @override
  String get famMemberYou => '(you)';

  @override
  String get famSectionPending => 'Pending';

  @override
  String get famPendingComingSoon =>
      'Purchase approval is coming in a future update.';

  @override
  String get deviceSessionsAction => 'Devices';

  @override
  String get deviceSessionsTitle => 'Logged-in devices';

  @override
  String get deviceSessionsEmpty => 'No active devices for this account.';

  @override
  String get deviceRevokeAction => 'Sign out';

  @override
  String deviceRevokeConfirm(String name) {
    return 'Sign \"$name\" out of your Steam account? It will need to log in again.';
  }

  @override
  String deviceRevokeDone(String name) {
    return 'Signed \"$name\" out.';
  }

  @override
  String deviceRevokeFailed(String error) {
    return 'Couldn\'t sign the device out: $error';
  }

  @override
  String get deviceCurrent => '(this device)';

  @override
  String get deviceSignedOut => 'signed out';

  @override
  String get deviceUnnamed => 'Unknown device';

  @override
  String deviceLastSeen(String age) {
    return 'active $age ago';
  }

  @override
  String get devicePlatformSteam => 'Steam client';

  @override
  String get devicePlatformWeb => 'Web browser';

  @override
  String get devicePlatformMobile => 'Mobile app';

  @override
  String get devicePlatformUnknown => 'Unknown';

  @override
  String deviceAgeDays(int n) {
    return '${n}d';
  }

  @override
  String deviceAgeHours(int n) {
    return '${n}h';
  }

  @override
  String deviceAgeMinutes(int n) {
    return '${n}m';
  }

  @override
  String get deviceAgeNow => 'just now';

  @override
  String get keyRedeemAction => 'Redeem key';

  @override
  String get keyRedeemTitle => 'Redeem a Steam key';

  @override
  String keyRedeemFor(String account) {
    return 'Activating on $account';
  }

  @override
  String get keyRedeemHint => 'XXXXX-XXXXX-XXXXX';

  @override
  String get keyRedeemPaste => 'Paste';

  @override
  String get keyRedeemSubmit => 'Redeem';

  @override
  String get keyRedeemNote =>
      'Activation is permanent and adds the product to this account. Steam blocks activations for about an hour after a few rejected keys, so check the code before submitting.';

  @override
  String keyRedeemConfirm(String account) {
    return 'Activate this key on $account? It can\'t be undone or moved to another account afterwards.';
  }

  @override
  String get keyRedeemDone => 'Key activated.';

  @override
  String get keyRedeemGranted => 'Added to the library:';

  @override
  String get keyRedeemNoProducts =>
      'Steam accepted the key but didn\'t name the product. Check the account\'s library.';

  @override
  String get keyRedeemNetworkError =>
      'Couldn\'t reach Steam. If the request timed out, Steam may still have processed it — check the account\'s library before trying the key again.';

  @override
  String get keyErrInvalid =>
      'Steam doesn\'t recognize this code. Check it for typos — letters and digits like 0/O and 1/I are easy to mix up.';

  @override
  String get keyErrAlreadyOwned => 'This account already owns the product.';

  @override
  String get keyErrAlreadyActivated =>
      'This key has already been used — on this account or another one.';

  @override
  String get keyErrRegionLocked =>
      'This product can\'t be activated in the account\'s country.';

  @override
  String get keyErrNeedsBaseProduct =>
      'This is DLC or an expansion; the account needs the base game first.';

  @override
  String get keyErrNeedsPs3Login =>
      'This product has to be played on a PlayStation®3 system before it can be activated.';

  @override
  String get keyErrRateLimited =>
      'Too many rejected keys recently. Steam blocks activations for about an hour — try again later.';

  @override
  String keyErrUnknown(int code) {
    return 'Steam rejected the key (code $code).';
  }

  @override
  String get loginOrApprove => '…or just tap “Allow” in your Steam mobile app.';

  @override
  String get addErrPresent => 'This account already has an authenticator.';

  @override
  String get addErrConfirmEmail =>
      'Please confirm the email Steam sent, then retry.';

  @override
  String get addErrLocked =>
      'This account is locked/restricted by Steam — recover it at help.steampowered.com before adding an authenticator.';

  @override
  String get addErrRateLimited =>
      'Too many attempts. Please wait a while and try again.';

  @override
  String get addErrFailed => 'Failed to add authenticator.';

  @override
  String addErrSaveFailed(String code) {
    return 'Couldn\'t save the authenticator to this device, so setup was stopped before it took effect. Write down this revocation code and remove the pending authenticator from your account, then try again: $code';
  }

  @override
  String get addErrBadSms => 'Wrong SMS code, please try again.';

  @override
  String get debugLog => 'Debug log';

  @override
  String get debugLogDesc =>
      'Network trace for diagnosing login / confirmations';

  @override
  String get feedbackTitle => 'Feedback';

  @override
  String get feedbackDesc =>
      'Found a bug or have an idea? Send it straight to the developer, or open a GitHub issue for public discussion.';

  @override
  String get feedbackSend => 'Send feedback';

  @override
  String get feedbackMessageLabel => 'Your feedback';

  @override
  String get feedbackMessageHint => 'What broke / what would you like?';

  @override
  String get feedbackContactLabel => 'Contact (optional)';

  @override
  String get feedbackContactHint =>
      'Email or username — only if you want a reply';

  @override
  String feedbackAttachNote(String meta) {
    return 'Sent along with your message: $meta';
  }

  @override
  String get feedbackSent => 'Feedback sent — thank you!';

  @override
  String get feedbackFailed =>
      'Couldn\'t send. Check your network and try again.';

  @override
  String feedbackRefused(String reason) {
    return 'The relay refused this report: $reason';
  }

  @override
  String feedbackRelayDown(String reason) {
    return 'The feedback service is having trouble on its end ($reason). Your network is fine — please try again later.';
  }

  @override
  String get feedbackAttachLog => 'Attach debug log';

  @override
  String get feedbackAttachLogHint =>
      'Recent network trace; may include account names / SteamIDs';

  @override
  String get feedbackLogConsentBody =>
      'The debug log contains recent network-trace lines from this session. It may include your account names and SteamIDs — never your secrets, tokens or passwords. It is sent only together with this report, as described in the Privacy Policy.';

  @override
  String get feedbackLogConsentAgree => 'Agree';

  @override
  String get backupReminderTitle => 'Back up your secrets';

  @override
  String get backupReminderBody =>
      'GooeSteamKit keeps your authenticator data on this device only. Back up your maFiles somewhere safe. Your revocation code (R-code) is shown only once, when you first add an authenticator — write it down and keep it then; it is your last resort for removing the authenticator if this device is ever lost.';

  @override
  String get backupReminderOk => 'Got it';

  @override
  String get debugCopyAll => 'Copy all';

  @override
  String get debugCopied => 'Log copied';

  @override
  String get debugEmpty => 'No log yet.';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonClear => 'Clear';

  @override
  String addErrFinalize(String detail) {
    return 'Finalize failed: $detail';
  }

  @override
  String get loginTitle => 'Log in to Steam';

  @override
  String get loginUsername => 'Username';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginShowPassword => 'Show password';

  @override
  String get loginHidePassword => 'Hide password';

  @override
  String get loginSavePassword => 'Save password';

  @override
  String get loginSavePasswordHint =>
      'Kept in this account\'s maFile for automatic session refresh; an unencrypted export will contain it.';

  @override
  String get loginButton => 'Log in';

  @override
  String get loginErrInvalidPassword => 'Wrong account name or password.';

  @override
  String get loginErrRateLimited =>
      'Too many attempts — please wait a while and try again.';

  @override
  String get loginErrCodeMismatch =>
      'That code didn\'t match — check it and try again.';

  @override
  String get loginViaQr => 'Log in with QR code';

  @override
  String get loginViaCredentials => 'Log in with password';

  @override
  String get loginScanWithApp => 'Scan this code with the Steam mobile app';

  @override
  String get loginNeedGuardCode => 'Enter the Steam Guard code';

  @override
  String get loginNeedEmailCode => 'Enter the code sent to your email';

  @override
  String get loginSubmitCode => 'Submit';

  @override
  String get loginWaiting => 'Waiting for confirmation…';

  @override
  String get loginStepCredentials => 'Credentials';

  @override
  String get loginStepConfirm => 'Confirm';

  @override
  String get loginStepDone => 'Done';

  @override
  String get loginWaitingDesc =>
      'Approve this sign in on the Steam mobile app. You can also use an email code or QR sign-in.';

  @override
  String loginFailed(String error) {
    return 'Login failed: $error';
  }

  @override
  String get approveTitle => 'Approve sign in';

  @override
  String get approveScanPrompt =>
      'Scan the QR code shown on the device you want to sign in.';

  @override
  String get approvePastePrompt => 'Or paste the QR code link here';

  @override
  String get approveButton => 'Approve';

  @override
  String get approveReject => 'Reject';

  @override
  String get approveSuccess => 'Sign in approved.';

  @override
  String get approveRejected => 'Sign in rejected.';

  @override
  String get approveBadCode => 'That\'s not a Steam sign-in QR code.';

  @override
  String get approveLocation => 'Location';

  @override
  String get approveDevice => 'Device';

  @override
  String get approveWarnStranger =>
      'Didn\'t start this sign-in yourself? Reject it.';

  @override
  String get importTitle => 'Import account';

  @override
  String get importPickFile => 'Choose a .maFile';

  @override
  String get importSuccess => 'Account imported.';

  @override
  String importFailed(String error) {
    return 'Failed to import: $error';
  }

  @override
  String get importDuplicateTitle => 'Account already exists';

  @override
  String importDuplicateBody(String name) {
    return 'This maFile is for $name, which is already on this device. Overwrite the stored account with the imported file? Its cached avatar, saved password, and existing session are kept when the file doesn\'t include them.';
  }

  @override
  String importDuplicateBodyUnreadable(String name) {
    return 'This maFile is for $name, which exists on this device but its stored data can no longer be read. Importing will replace it entirely.';
  }

  @override
  String get importDuplicateOverwrite => 'Overwrite';

  @override
  String get importSessionDeadTitle => 'Activate this account?';

  @override
  String get importSessionDeadBody =>
      'The Steam session in this maFile has expired. Sign in now to enable confirmations and login approvals — the Steam Guard code will be filled in automatically.';

  @override
  String get importSessionLater => 'Later';

  @override
  String get sdaImportAction => 'Import an SDA folder';

  @override
  String get sdaImportHint =>
      'Select .maFile files to import in bulk. manifest.json is optional for unencrypted files. For encrypted SDA files, select manifest.json too; it contains the decryption parameters.';

  @override
  String get sdaImportNoManifest =>
      'No manifest.json in that selection. Select it together with the .maFile files.';

  @override
  String sdaImportBadManifest(String error) {
    return 'That manifest.json can\'t be read: $error';
  }

  @override
  String get sdaImportPassTitle => 'SDA encryption passphrase';

  @override
  String get sdaImportPassBody =>
      'These maFiles are encrypted. Enter the passphrase you set in Steam Desktop Authenticator.';

  @override
  String get sdaImportWrongPass =>
      'That passphrase didn\'t decrypt any of the files.';

  @override
  String sdaImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts imported.',
      one: '1 account imported.',
    );
    return '$_temp0';
  }

  @override
  String sdaImportSkipped(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts were skipped: $names',
      one: '1 account was skipped: $names',
    );
    return '$_temp0';
  }

  @override
  String get sdaImportNothing => 'Nothing was imported.';

  @override
  String updateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get updateView => 'View';

  @override
  String get updateDismiss => 'Skip';

  @override
  String get settingsUpdateCheck => 'Check for updates on launch';

  @override
  String get settingsUpdateCheckDesc =>
      'One request to the version endpoint per launch. No account data; the endpoint keeps no logs.';

  @override
  String get importSessionLoginNow => 'Sign in now';

  @override
  String get actionExport => 'Export maFile';

  @override
  String get actionLoginRequests => 'Sign-in requests';

  @override
  String get loginRequestTitle => 'Approve sign-in?';

  @override
  String loginRequestBody(String device, String location) {
    return '$device is signing in to your Steam account from $location.';
  }

  @override
  String get loginRequestApprove => 'Allow';

  @override
  String get loginRequestDeny => 'Deny';

  @override
  String get loginNoPending => 'No pending sign-in requests.';

  @override
  String get loginNeedSession =>
      'Sign in to refresh this account\'s session first.';

  @override
  String get loginApproved => 'Sign-in allowed.';

  @override
  String get loginDenied => 'Sign-in denied.';

  @override
  String exportFailed(String error) {
    return 'Failed to export: $error';
  }

  @override
  String get exportWarnTitle => 'Export unencrypted maFile?';

  @override
  String get exportWarnBody =>
      'The exported .maFile is NOT encrypted. It holds this account’s Steam Guard secrets and revocation code — anyone with the file can take over your authenticator. Store it somewhere safe and delete it when done.';

  @override
  String get exportIncludePassword =>
      'Also include the saved Steam password (not recommended)';

  @override
  String get addAuthTitle => 'Add authenticator';

  @override
  String get addAuthPhonePrompt =>
      'Enter your phone number (with country code)';

  @override
  String get addAuthSmsPrompt => 'Enter the SMS code sent to your phone';

  @override
  String get addAuthEmailPrompt =>
      'Enter the activation code Steam emailed you';

  @override
  String addAuthRevocationWarn(String code) {
    return 'Write down your revocation code: $code';
  }

  @override
  String get addAuthConfirmRevocation =>
      'Re-enter your revocation code to confirm you saved it';

  @override
  String get addAuthLinked => 'Authenticator linked successfully.';

  @override
  String get addAuthStepPhone => 'Phone';

  @override
  String get addAuthStepSms => 'Activate';

  @override
  String get addAuthStepRevocation => 'Revocation';

  @override
  String get addPresentTitle => 'This account already has an authenticator';

  @override
  String get addPresentIntro =>
      'Steam allows only one mobile authenticator per account. Remove the existing one, then tap Retry.';

  @override
  String get addPresentStep1 =>
      'Still have the old phone or Steam app? Open it → Steam Guard → Remove Authenticator.';

  @override
  String get addPresentStep2 =>
      'Have your revocation code (Rxxxxx)? Open the page below and choose “Remove Authenticator”.';

  @override
  String get addPresentStep3 =>
      'Lost access to both? Use Steam Support → Help → Steam Guard Mobile Authenticator.';

  @override
  String get addPresentManageUrl => 'store.steampowered.com/twofactor/manage';

  @override
  String get addPresentCopiedUrl => 'Link copied';

  @override
  String get addPresentFallbackTitle => 'Can\'t receive the email?';

  @override
  String get addMoveInButton => 'Move the authenticator to this device';

  @override
  String get addMoveInBlurb =>
      'Steam will email this account a code. No 15-day trade hold.';

  @override
  String get addMoveInSending => 'Sending the code…';

  @override
  String get addMoveInCodePrompt => 'Enter the code Steam emailed you';

  @override
  String get addMoveInWarn =>
      'Once you confirm: the authenticator on your old phone stops working immediately, and your old revocation code (Rxxxxx) is replaced by a new one. This cannot be undone.';

  @override
  String get addMoveInConfirm => 'Move it here';

  @override
  String get addMoveInDone => 'Authenticator moved to this device.';

  @override
  String get addMoveInPopBlocked => 'Moving the authenticator — please wait.';

  @override
  String get addErrBadChallengeCode =>
      'That code isn\'t right. Check the email and try again.';

  @override
  String addMoveInSaveFailed(String code, String secret) {
    return 'The authenticator moved to this account, but GooeSteamKit could NOT save it to this device. Your old authenticator is already dead, so these are the only copies — write them down NOW before closing this screen.\n\nRevocation code: $code\n\nSecret: $secret';
  }

  @override
  String get addMoveInCopySecrets => 'Copy';

  @override
  String get addMoveInCopied => 'Copied';

  @override
  String get moveInRescueDismiss => 'I saved them — dismiss';

  @override
  String get moveInRescueDismissTitle => 'Discard these secrets?';

  @override
  String get moveInRescueDismissBody =>
      'GooeSteamKit holds no other copy. If you haven\'t written down the revocation code and secret, you will permanently lose access to this authenticator.';

  @override
  String get moveInRescueDismissConfirm => 'I saved them';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCopy => 'Copy link';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonExport => 'Export';

  @override
  String get commonDelete => 'Delete';

  @override
  String get settingsEncryption => 'Encryption';

  @override
  String get settingsEncryptionDesc =>
      'Your local maFiles are encrypted with a random 256-bit key (AES-256-GCM) held in the device Keystore; your 6-digit PIN unlocks it.';

  @override
  String get settingsThemeDesc => 'Switch the whole UI style.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceDesc =>
      'Light or dark for the standard look. A skin overrides this while active.';

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get settingsTextSizeDesc => 'Applies on top of the system font size.';

  @override
  String get textSizeSmall => 'Small';

  @override
  String get textSizeMedium => 'Medium';

  @override
  String get textSizeLarge => 'Large';

  @override
  String get settingsSkin => 'Skins';

  @override
  String get settingsSkinDesc =>
      'Full-styled looks with their own fonts and effects.';

  @override
  String get themeSystem => 'System';

  @override
  String get skinNone => 'None';

  @override
  String get settingsChange => 'Change';

  @override
  String get settingsSetPasskey => 'Set / change encryption passkey';

  @override
  String get settingsAutoConfirmMarket => 'Auto-confirm market transactions';

  @override
  String get settingsAutoConfirmMarketDesc =>
      'Pre-ticks the confirm box when you list an item, so a new listing is confirmed right after it\'s created. It never confirms anything in the background.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeNeon => 'Neon';

  @override
  String get themePixel => 'Pixel';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get settingsAbout => 'About';

  @override
  String get aboutTagline =>
      'An open-source Steam Guard authenticator, built with Flutter.';

  @override
  String get aboutSourceCode => 'Source code';

  @override
  String get aboutAuthor => 'Author';

  @override
  String get aboutLicense => 'License';

  @override
  String get aboutPrivacy => 'Privacy policy';

  @override
  String get privacyConsentTitle => 'Your privacy';

  @override
  String get privacyConsentBody =>
      'AVA keeps your Steam accounts and secrets on this device — they are never uploaded, unless you set up the optional sync to a server you choose, where everything is encrypted on this device first. There is no account to create. Steam requests go straight to Valve. Two of the developer\'s own services are contacted only when they are needed: Pro entitlement checks, and feedback (only when you press send). The Play version also shows ads on the free tier. There is no tracking or analytics. All of it is spelled out in the Privacy Policy — by continuing, you accept it.';

  @override
  String get privacyUpdateTitle => 'Privacy Policy updated';

  @override
  String get privacyUpdateBody =>
      'The privacy notice has changed since you accepted it. New: GooeSteamKit can now sync your account library between your devices, through a server you choose — off by default, everything encrypted on this device before upload, and the developer runs no sync server. Please read the current notice below.';

  @override
  String get privacyConsentScrollHint => 'Scroll to the end to continue';

  @override
  String get privacyConsentRead => 'Read the full Privacy Policy';

  @override
  String get privacyConsentAgree => 'Agree & continue';

  @override
  String get privacyConsentExit => 'Exit';

  @override
  String get actionMarket => 'Inventory / Market';

  @override
  String get marketTabInventory => 'Inventory';

  @override
  String get marketTabListings => 'My listings';

  @override
  String get marketSelectGame => 'Select a game';

  @override
  String get marketNoItems => 'No items in this inventory.';

  @override
  String get marketNotMarketable => 'Not marketable';

  @override
  String get marketSellTitle => 'List for sale';

  @override
  String get marketYouReceive => 'You receive';

  @override
  String get marketBuyerPays => 'Buyer pays';

  @override
  String get marketLowest => 'Lowest';

  @override
  String get marketMedian => 'Median';

  @override
  String get marketHigh => 'High';

  @override
  String get marketLow => 'Low';

  @override
  String get marketPriceUnavailable => 'Market price unavailable';

  @override
  String get marketListButton => 'List for sale';

  @override
  String get marketListed => 'Listed — confirm it to finish.';

  @override
  String get marketListedDone => 'Listed and confirmed.';

  @override
  String marketListedPartial(int listed, int total) {
    return 'Listed $listed of $total — the rest failed; confirm any pending in Confirmations.';
  }

  @override
  String marketListedSessionExpired(int listed, int total) {
    return 'Listed $listed of $total, then the session expired — sign in again and confirm them.';
  }

  @override
  String marketConfirmPartial(int ok, int total) {
    return 'Listed — $ok of $total confirmed; finish the rest in Confirmations.';
  }

  @override
  String get marketAutoConfirm => 'Auto-confirm the listing';

  @override
  String get marketQuantity => 'Quantity';

  @override
  String get marketMax => 'Max';

  @override
  String marketListFailed(String error) {
    return 'Listing failed: $error';
  }

  @override
  String get marketInvalidPrice => 'Enter a valid price.';

  @override
  String get marketCancel => 'Cancel listing';

  @override
  String get marketCancelled => 'Listing cancelled.';

  @override
  String get marketNoListings => 'No active listings.';

  @override
  String get marketFeeNote =>
      'Steam + game fees are added on top of what you receive.';

  @override
  String get aboutLicenses => 'Open-source licenses';

  @override
  String get aboutCredits => 'Credits';

  @override
  String get aboutCreditsBody =>
      'Inspired by Steam Desktop Authenticator and compatible with its maFile format. Independently built with Flutter, Riverpod, Dio, PointyCastle, mobile_scanner, image and other open-source libraries.';

  @override
  String get actionLogin => 'Log in / refresh session';

  @override
  String get actionConfirmations => 'Pending';

  @override
  String get actionRemove => 'Remove account';

  @override
  String get actionImport => 'Import';

  @override
  String get actionAddAuthenticator => 'Add authenticator';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonClose => 'Close';

  @override
  String get commonError => 'Error';

  @override
  String get sessionExpired =>
      'Your Steam session has expired. Please log in again.';

  @override
  String get removeConfirm =>
      'Remove this account from this device? Make sure you have your maFile backed up.';

  @override
  String get settingsPro => 'AVA Pro';

  @override
  String get proOpen => 'View AVA Pro';

  @override
  String get proStatusFree => 'Free plan';

  @override
  String proStatusPro(Object date) {
    return 'Pro · until $date';
  }

  @override
  String proStatusVip(Object date) {
    return 'VIP · until $date';
  }

  @override
  String get proStatusLifetime => 'Pro · lifetime';

  @override
  String proStatusActivations(Object classes) {
    return 'Active on: $classes';
  }

  @override
  String proStatusClassThisDevice(Object name) {
    return '$name (this device)';
  }

  @override
  String get proDeviceClassAndroid => 'Android';

  @override
  String get proDeviceClassWindows => 'Windows';

  @override
  String get proDeviceClassLinux => 'Linux';

  @override
  String get proDeviceClassMacos => 'macOS';

  @override
  String get paywallTitle => 'AVA Pro';

  @override
  String get paywallPerksTitle =>
      'Pro perks — core security features stay free forever.';

  @override
  String get paywallPerkSkins => 'Theme packs: Neon & Pixel skins';

  @override
  String get paywallPerkNoAds => 'No banner ads';

  @override
  String get paywallPerkFuture =>
      'Coming later: cloud sync, trade notifications';

  @override
  String get paywallPlayTitle => 'Unlock via Google Play';

  @override
  String get paywallSubscribe => 'Subscribe · \$0.99/mo';

  @override
  String get paywallWatchAd => 'Watch an ad · 3-day VIP';

  @override
  String get paywallRestore => 'Restore purchase';

  @override
  String get paywallCnTitle => 'Unlock via Afdian';

  @override
  String get paywallAfdianIntro =>
      'Sponsor ¥5/month on Afdian, then enter the order number here to unlock.';

  @override
  String get paywallOpenAfdian => 'Open Afdian';

  @override
  String get paywallOrderHint => 'Afdian order number';

  @override
  String get paywallRedeem => 'Unlock';

  @override
  String get paywallBetaTitle => 'Beta thank-you';

  @override
  String get paywallBetaIntro =>
      'Beta testers get lifetime Pro — enter your code.';

  @override
  String get paywallBetaHint => 'Lifetime code';

  @override
  String get paywallBetaRedeem => 'Redeem';

  @override
  String get proResultSuccess => 'Unlocked — thank you!';

  @override
  String get proErrCanceled => 'Canceled.';

  @override
  String get proErrNetwork => 'Network error — try again later.';

  @override
  String get proErrNotConfigured => 'Not available in this build yet.';

  @override
  String get proErrNoSubscription =>
      'No active subscription on your Play Store\'s current account. Subscribed with a different Google account? Switch to it in the Play Store app (top-right avatar), then retry.';

  @override
  String get proErrAlreadyOwned =>
      'Your Play Store\'s current account already holds this subscription — tap Restore purchase instead.';

  @override
  String get proErrOrderBound => 'This order is already bound to another user.';

  @override
  String get proErrOrderNotFound => 'Order not found or plan mismatch.';

  @override
  String get proErrDeviceRevoked =>
      'This device\'s slot was taken by a newer activation.';

  @override
  String get proErrNoVip => 'Reward not confirmed yet — try again in a minute.';

  @override
  String get proErrPurchaseBound =>
      'This subscription is tied to a different Google account. Retry, and in the account chooser pick the one your Play Store uses.';

  @override
  String proErrPurchaseBoundKnown(String account) {
    return 'This subscription is tied to $account. Retry, and pick that account in the chooser.';
  }

  @override
  String proErrGeneric(Object code) {
    return 'Failed: $code';
  }

  @override
  String get proErrCodeInvalid => 'Code not recognized — check it for typos.';

  @override
  String get proErrCodeRedeemed =>
      'This code is already active on another device. To move it here, email hi@dotslash.pro.';

  @override
  String get proErrCodeActivationLimit =>
      'This code has switched devices too often recently. Try again later, or email hi@dotslash.pro.';

  @override
  String get proErrRateLimited =>
      'Too many attempts. Wait a minute and try again.';

  @override
  String proErrSlotOccupied(Object slots) {
    return 'In use: $slots';
  }

  @override
  String proSlotEntry(Object name, Object time) {
    return '$name ($time)';
  }

  @override
  String get proSlotToday => 'today';

  @override
  String proSlotDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get proErrRevoked =>
      'This entitlement is no longer active. If you think this is a mistake, email hi@dotslash.pro.';

  @override
  String get privacyOptions => 'Privacy options';

  @override
  String get skinProNotice =>
      'Neon & Pixel skins are now Pro perks. Your selection is kept and comes back with Pro.';

  @override
  String get skinProNoticeDismiss => 'Got it';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncSetupTitle => 'Set up sync';

  @override
  String get syncSettingsDesc =>
      'Keep accounts in sync across devices through a server you control. Everything is encrypted before it leaves this device.';

  @override
  String get syncSetUp => 'Set up sync…';

  @override
  String get syncStatusOk => 'Up to date';

  @override
  String get syncStatusSyncing => 'Syncing…';

  @override
  String get syncStatusErrorShort => 'Last sync failed — open for details.';

  @override
  String syncStatusConflicts(int count) {
    return '$count conflict(s) need your decision';
  }

  @override
  String syncLastSync(String time) {
    return 'Last sync: $time';
  }

  @override
  String get syncNever => 'never';

  @override
  String get syncBackendTitle => 'Where should the data live?';

  @override
  String get syncBackendWebdav => 'WebDAV';

  @override
  String get syncBackendWebdavDesc =>
      'Nextcloud, Jianguoyun (坚果云), a NAS — any WebDAV folder you control.';

  @override
  String get syncBackendGdrive => 'Google Drive';

  @override
  String get syncBackendGdriveSoon => 'Pro · coming later';

  @override
  String get syncServerTitle => 'Server';

  @override
  String get syncServerHint =>
      'Jianguoyun needs an app password (安全选项 → 添加应用密码), not your login password. A Nextcloud folder URL looks like https://cloud.example.com/remote.php/dav/files/USER/ava/.';

  @override
  String get syncServerUrlLabel => 'WebDAV folder URL';

  @override
  String get syncServerFolderLabel => 'Folder (optional)';

  @override
  String get syncServerFolderHint =>
      'Leave empty to use the URL as-is; a name places the library in that subfolder, created if missing.';

  @override
  String get syncServerUserLabel => 'Username';

  @override
  String get syncServerPasswordLabel => 'Password / app password';

  @override
  String get syncTestConnection => 'Test connection';

  @override
  String get syncErrUrl => 'Enter a valid http(s) folder URL.';

  @override
  String get syncErrAuth => 'The server rejected the username or password.';

  @override
  String syncErrNetwork(String detail) {
    return 'Could not reach the server: $detail';
  }

  @override
  String syncErrServer(String detail) {
    return 'The server answered with an error: $detail';
  }

  @override
  String get syncErrTls => 'The server\'s certificate is not trusted.';

  @override
  String get syncTlsTitle => 'Unknown server certificate';

  @override
  String syncTlsBody(String fp) {
    return 'This server\'s certificate is not trusted by the system. If it is your own server with a self-signed certificate, compare this fingerprint with the one shown on the server, and only trust it if they match exactly.\n\nSHA-256\n$fp';
  }

  @override
  String get syncTlsTrust => 'Trust this certificate';

  @override
  String get syncHttpPrivateTitle => 'Unencrypted connection';

  @override
  String get syncHttpPrivateBody =>
      'This is a plain-HTTP address on a private network. Your account data itself is encrypted end-to-end, but the server password travels unencrypted on your network.';

  @override
  String get syncHttpPublicTitle => 'Plain HTTP across the internet';

  @override
  String get syncHttpPublicBody =>
      'This address is public and the connection would be unencrypted: anyone between you and the server can read the server password and sign in to your server. The account data itself stays encrypted. Use HTTPS or a LAN address instead — continue only if you accept this risk.';

  @override
  String get syncHttpPublicHold => 'Hold to allow anyway';

  @override
  String get syncContinue => 'Continue';

  @override
  String get syncPassphraseNewTitle => 'Set a sync passphrase';

  @override
  String get syncPassphraseNewBody =>
      'Everything is encrypted with this passphrase before upload; the passphrase itself never leaves your devices.\n\nIf you lose it, the synced data cannot be recovered by anyone — there is no reset. At least 8 characters; length matters more than symbols.';

  @override
  String get syncPassphraseExistingTitle => 'Enter the sync passphrase';

  @override
  String syncPassphraseExistingBody(int count) {
    return 'This folder already holds a sync library with $count account(s). Enter the passphrase it was created with.';
  }

  @override
  String get syncPassphraseLabel => 'Sync passphrase';

  @override
  String get syncPassphraseConfirmLabel => 'Confirm passphrase';

  @override
  String get syncPassphraseTooShort => 'At least 8 characters.';

  @override
  String get syncPassphraseMismatch => 'The passphrases don\'t match.';

  @override
  String get syncPassphraseWrong =>
      'That passphrase doesn\'t open this library.';

  @override
  String get syncPreviewTitle => 'First sync';

  @override
  String get syncPreviewEmpty =>
      'Nothing to transfer yet — accounts will sync automatically from now on.';

  @override
  String syncPreviewPull(int count) {
    return 'Download to this device: $count account(s)';
  }

  @override
  String syncPreviewPush(int count) {
    return 'Upload from this device: $count account(s)';
  }

  @override
  String syncPreviewConflict(int count) {
    return 'On both sides with different content: $count — you\'ll choose per account after connecting';
  }

  @override
  String get syncStart => 'Start syncing';

  @override
  String get syncDoneTitle => 'Sync is on';

  @override
  String get syncDoneBody =>
      'Accounts now sync automatically. On a new device each account signs in again the first time you use it — accounts with a saved password do that by themselves; the others ask once.';

  @override
  String get syncDone => 'Done';

  @override
  String get syncNeedsPassphrase =>
      'The stored passphrase no longer matches the remote library — enter it again.';

  @override
  String get syncEnterPassphrase => 'Enter passphrase';

  @override
  String get syncConditionalWarn =>
      'This server ignores conditional writes, so two devices syncing at the same moment may overwrite each other. Syncing still works; avoid simultaneous changes on two devices.';

  @override
  String get syncConflictsTitle => 'Conflicts';

  @override
  String get syncConflictTrashNote =>
      'Whichever side you discard is kept in the sync trash for 30 days.';

  @override
  String get syncConflictEditEdit => 'Changed on both devices';

  @override
  String get syncConflictEditDelete =>
      'Changed here, deleted on another device';

  @override
  String get syncConflictDeleteEdit =>
      'Deleted here, changed on another device';

  @override
  String get syncConflictKeepLocal => 'Keep this device\'s';

  @override
  String get syncConflictKeepRemote => 'Keep the other\'s';

  @override
  String get syncConflictLocalSide => 'This device';

  @override
  String get syncConflictRemoteSide => 'Other device';

  @override
  String get syncDeleted => 'Deleted';

  @override
  String get syncConflictHasPassword => 'Password saved';

  @override
  String get syncConflictNoPassword => 'No saved password';

  @override
  String get syncAutoTitle => 'Automatic sync';

  @override
  String get syncAutoDesc =>
      'Sync at launch and after every change. Off means only the button below syncs.';

  @override
  String get syncPasswordsTitle => 'Sync account passwords';

  @override
  String get syncPasswordsDesc =>
      'Passwords let a new device sign in by itself. Changing this re-uploads every account.';

  @override
  String get syncAppSettingsTitle => 'Sync app settings';

  @override
  String get syncAppSettingsDesc =>
      'Sync appearance and behavior preferences plus encrypted Steam acceleration subscriptions, nodes and the selected node. Language, text size and acceleration auto-start stay per-device.';

  @override
  String get syncNowButton => 'Sync now';

  @override
  String get syncViewRemote => 'View remote library';

  @override
  String get syncRemoteEmpty => 'The remote library is empty.';

  @override
  String get syncRemoteDevices => 'Devices';

  @override
  String get syncTrashTitle => 'Sync trash';

  @override
  String get syncTrashEmpty =>
      'Empty. Anything sync removes or replaces is kept here for 30 days.';

  @override
  String get syncTrashRestore => 'Restore';

  @override
  String get syncTrashRestored => 'Account restored.';

  @override
  String get syncTrashRestoreFailed =>
      'This entry can\'t be decrypted with the current passphrase.';

  @override
  String get syncTrashReasonRemoteDelete => 'deleted by another device';

  @override
  String get syncTrashReasonConflict => 'replaced in a conflict';

  @override
  String get syncChangePassphrase => 'Change sync passphrase';

  @override
  String get syncPassphraseChanged =>
      'Passphrase changed; everything re-encrypted. Other devices will ask for the new passphrase.';

  @override
  String syncPassphraseChangeFailed(String reason) {
    return 'Passphrase not changed: $reason';
  }

  @override
  String get syncDisconnect => 'Disconnect sync';

  @override
  String get syncDisconnectBody =>
      'This device stops syncing. The remote library can stay for your other devices — or be deleted from the server entirely.';

  @override
  String get syncDisconnectKeep => 'Keep remote data';

  @override
  String get syncDisconnectDeleteHold => 'Hold to delete remote data';

  @override
  String get netErrTls =>
      'Couldn\'t open a secure connection to Steam. The connection was cut during the TLS handshake, which usually means the network is filtering it or is unstable. Try another network — or a proxy — and retry.';

  @override
  String get netErrUnreachable =>
      'Couldn\'t reach Steam. Check your connection and retry.';

  @override
  String get netErrTimeout =>
      'Steam didn\'t answer in time. The network may be slow or filtered.';

  @override
  String get netErrCert =>
      'Steam\'s certificate wasn\'t trusted, so GooeSteamKit closed the connection. Something on this network may be inspecting traffic.';

  @override
  String netErrServer(int code) {
    return 'Steam returned an error ($code). This is usually temporary — try again shortly.';
  }

  @override
  String exportSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String get accountSearchHint => 'Search accounts';

  @override
  String get accountSearchEmpty => 'No matching accounts';

  @override
  String get accountSearchClear => 'Clear search';

  @override
  String get portableMode => 'Portable mode';

  @override
  String get portableEnable => 'Enable portable mode';

  @override
  String get portableDisable => 'Disable portable mode';

  @override
  String get portableOnHelp =>
      'New accounts go to maFiles beside the app. Both libraries are read; portable copies take priority for duplicate accounts.';

  @override
  String get portableOffHelp =>
      'New accounts go to AppData. Both unlocked libraries are read; local copies take priority for duplicate accounts.';

  @override
  String get portableCopyToUsb =>
      'Also copy existing local accounts to maFiles beside the app?';

  @override
  String get portableCopyToLocal =>
      'Also copy portable accounts back to AppData?';

  @override
  String get portableCopyHelp =>
      'Copies are verified and the source is kept as a backup. Accounts already in the destination are skipped. Portable accounts are not included in this computer’s WebDAV sync.';

  @override
  String get portableNoCopy => 'Switch only';

  @override
  String get portableCopy => 'Copy and switch';

  @override
  String get portableSetPassword => 'Set portable password';

  @override
  String get portableUnlock => 'Unlock maFiles';

  @override
  String get portablePasswordHelp =>
      'Use a separate password with at least 12 characters. Keep it safe: it is needed on other computers and cannot be reset.';

  @override
  String get portableUnlockHelp =>
      'Enter this library’s password. For an encrypted SDA folder, use its SDA passphrase.';

  @override
  String get portableConfirmPassword => 'Confirm password';

  @override
  String get portablePasswordMismatch => 'Passwords do not match.';

  @override
  String get portableWrongPassword =>
      'Wrong password, or this library cannot be unlocked.';

  @override
  String get portableFailed =>
      'The operation could not finish. The source library was kept.';

  @override
  String get portableDone => 'Mode updated. Source accounts were kept.';

  @override
  String get portableSkipped => 'Existing accounts skipped';

  @override
  String get portableUnreadable =>
      'This library is damaged or still depends on another Windows installation’s key. Restore a maFile export; the source files have not been changed.';

  @override
  String get friendsTitle => 'Friends & trades';

  @override
  String get friendsSearch => 'Search name or SteamID';

  @override
  String get friendsEmpty => 'No friends to show';

  @override
  String get friendsProfile => 'View Steam profile';

  @override
  String get friendsTrade => 'Create trade offer';

  @override
  String get friendsOnline => 'Online';

  @override
  String get friendsOffline => 'Offline';

  @override
  String get friendsPlaying => 'In game';

  @override
  String get tradeNewTitle => 'New trade offer';

  @override
  String get tradeYourItems => 'Items you give';

  @override
  String get tradeTheirItems => 'Items you receive';

  @override
  String get tradeSelectItems => 'Select items';

  @override
  String get tradeNote => 'Message (optional)';

  @override
  String get tradeReview => 'Review offer';

  @override
  String get tradeSend => 'Send offer';

  @override
  String get tradeReviewBody =>
      'Check the partner SteamID, items and quantities on both sides. Steam may require confirmation or place items on hold.';

  @override
  String get tradeGiftWarning =>
      'You are giving these items away and will receive nothing.';

  @override
  String get tradeNoItems => 'No tradable items available here.';

  @override
  String get tradeMore => 'Load more';

  @override
  String get tradeSent => 'Offer sent.';

  @override
  String get tradeNeedsMobile =>
      'Offer created. Complete its mobile confirmation in Pending.';

  @override
  String get tradeNeedsEmail =>
      'Offer created. Follow Steam’s email to confirm it.';

  @override
  String get tradeOpenPending => 'View pending & offers';

  @override
  String get tradeUnknownResult =>
      'The send result is unknown. Check your sent offers before trying again to avoid duplicates.';

  @override
  String get tradeChooseGame => 'Choose inventory';

  @override
  String get tradeQuantity => 'Quantity';

  @override
  String get tradeLoadFailed =>
      'Unable to read Steam friends or inventory. Refresh to try again.';

  @override
  String get tradeSendFailed =>
      'Steam did not confirm the offer was sent. Check your offers before trying again.';

  @override
  String get marketListingActive => 'For sale';

  @override
  String get marketListingOnHold => 'On hold';

  @override
  String get marketListingPending => 'Awaiting confirmation';

  @override
  String get marketListingInactive => 'Inactive';

  @override
  String marketHoldUntil(String date) {
    return 'On hold until $date';
  }

  @override
  String get marketListingsAll => 'All';

  @override
  String get marketCancelConfirm => 'Cancel this market listing?';

  @override
  String get settingsStartupVerification => 'Verify identity at startup';

  @override
  String get settingsStartupVerificationDesc =>
      'When enabled, opening GooeSteamKit requires your PIN or system authentication. When disabled, anyone using this device can open GooeSteamKit; local account files remain encrypted.';

  @override
  String get settingsStartupVerificationError =>
      'Could not save the startup verification setting. Check device secure storage and try again.';

  @override
  String get settingsLockNow => 'Lock now';

  @override
  String get settingsStartupVerificationPinChanged =>
      'Changing your PIN turns startup verification back on.';

  @override
  String get settingsStartupVerificationDisable =>
      'Turn off startup verification?';

  @override
  String get dashboardTitle => 'Account overview';

  @override
  String get dashboardWallet => 'Wallet balance';

  @override
  String get dashboardPendingBalance => 'Pending funds';

  @override
  String get dashboardUnavailable => 'Unavailable';

  @override
  String get dashboardMarket => 'Inventory & market';

  @override
  String get dashboardTools => 'Account tools';

  @override
  String get dashboardCustomize => 'Choose overview cards';

  @override
  String get dashboardViewAll => 'View all';

  @override
  String get dashboardNoListings => 'No market listings.';

  @override
  String get dashboardFetchFailed =>
      'Could not load this information. Refresh to try again.';

  @override
  String get dashboardSaveFailed => 'Could not save the display preference.';

  @override
  String get backupCodesTitle => 'Backup login codes';

  @override
  String get backupCodesAccountCheck =>
      'Your browser may be signed in to a different Steam account. Check that its account name matches the one above before generating codes.';

  @override
  String get backupCodesHow => 'Get codes from Steam';

  @override
  String get backupCodesSteps =>
      '1. Open Steam Guard settings with the button below.\n2. Sign in to the account shown above.\n3. Choose “Get Backup Steam Guard Codes”.\n4. Complete the verification requested by Steam and keep the generated codes in a safe place.';

  @override
  String get backupCodesExplanation =>
      'These are one-use login codes, separate from the authenticator removal code. Steam issues and manages them. GooeSteamKit opens the official flow and does not generate or store these codes.';

  @override
  String get backupCodesOpenSteam => 'Open Steam to get codes';

  @override
  String get backupCodesCopyLink => 'Copy official link';

  @override
  String get backupCodesOpenFailed =>
      'Could not open the browser. Copy the link and open it manually.';

  @override
  String get loginAccountMismatch =>
      'This is a different Steam account. Sign in to the selected account; the original account has not been changed.';

  @override
  String get tradeFromAccount => 'Sending account';

  @override
  String get tradeToAccount => 'Trading partner';

  @override
  String get tradeValidationFailed =>
      'The offer has not been sent. Check the selected items and quantities; each side allows up to 256 items.';

  @override
  String get friendsProfileOpenFailed =>
      'Unable to open a browser. Copy the official Steam link below.';

  @override
  String get steamSwitchQrTitle => 'Sign in with a GooeSteamKit account';

  @override
  String get steamSwitchQrHelp =>
      'Choose a GooeSteamKit account, show Steam’s sign-in QR code, then scan it and review the login request.';

  @override
  String get steamSwitchQrAccount => 'GooeSteamKit account';

  @override
  String get steamSwitchQrNeedsSession =>
      'Sign in to this account again in GooeSteamKit first. An offline Steam Guard code alone cannot approve a QR login.';

  @override
  String get steamSwitchQrNoAccounts =>
      'Add an account to GooeSteamKit to use QR sign-in.';

  @override
  String get approveScreenSelect => 'Select a QR code on screen';

  @override
  String get approveScreenHelp =>
      'GooeSteamKit will briefly hide. Drag around the Steam sign-in QR code, then review the account and device before approving.';

  @override
  String get approveScreenInstruction =>
      'Drag around one Steam sign-in QR code · Esc / right-click to cancel';

  @override
  String get approveScreenNoCode =>
      'No QR code found. Select the complete code with a little space around it and try again.';

  @override
  String get approveScreenFailed =>
      'Could not capture the screen. Try again or paste the QR code link.';

  @override
  String get approveSessionUnavailable =>
      'This QR code has expired or its login details could not be verified. Refresh the code in Steam and try again.';

  @override
  String get itemMarketActions => 'Item market options';

  @override
  String get itemMarketViewPrice => 'View market price';

  @override
  String get itemMarketOpen => 'Open Steam Market';

  @override
  String get itemMarketVolume => 'Recent volume';

  @override
  String get itemMarketReferenceNote =>
      'Steam Community Market reference price per item; not seller proceeds. Prices may change.';

  @override
  String itemMarketCurrency(String currency) {
    return 'Currency: $currency';
  }

  @override
  String get itemMarketNoIdentity => 'This item has no market listing name.';

  @override
  String get itemMarketOpenFailed => 'Could not open the Steam Market page.';

  @override
  String get steamClientRunning => 'Steam is running';

  @override
  String get steamClientStopped => 'Steam is not running';

  @override
  String get steamClientStatusLoading => 'Reading Steam status…';

  @override
  String get steamClientStatusUnavailable =>
      'Steam status is temporarily unavailable';

  @override
  String steamClientCurrentAccount(String account) {
    return 'Currently signed in: $account';
  }

  @override
  String get steamClientAccountUnknown => 'Current account not yet identified';

  @override
  String get steamClientCurrentBadge => 'Currently signed in';

  @override
  String get forkLocalFeaturesTitle => 'Local features unlocked';

  @override
  String get forkLocalFeaturesBody =>
      'All local features in this independent fork are available without Pro verification. The original author’s online services and subscriptions are not included.';

  @override
  String get forkPrivacyConsentBody =>
      'This independent AVA fork stores your Steam accounts and authenticator secrets on this device. Steam requests go directly to Valve. Optional synchronization is off until you configure your own server; account data is encrypted locally before synchronization. Local features require no Pro verification. This build uses no advertising, payment service or upstream update check. Feedback only opens this fork’s GitHub issue page; reports and logs are not sent automatically. There is no tracking or analytics. Read this fork’s privacy notice below. By continuing, you accept it.';

  @override
  String get forkUpdateTitle => 'Software updates';

  @override
  String forkUpdateCurrentVersion(String version) {
    return 'Current version $version';
  }

  @override
  String get forkUpdateCheck => 'Check for updates';

  @override
  String get forkUpdateChecking => 'Checking for updates…';

  @override
  String get forkUpdateNoRelease => 'No published release is available yet';

  @override
  String get forkUpdateUpToDate => 'You are up to date';

  @override
  String forkUpdateAvailable(String version) {
    return 'New version $version';
  }

  @override
  String get forkUpdateReleaseNotes => 'Release notes';

  @override
  String get forkUpdateNoNotes => 'No release notes were provided';

  @override
  String get forkUpdateDownload => 'Download update';

  @override
  String forkUpdateDownloading(String progress) {
    return 'Downloading $progress';
  }

  @override
  String get forkUpdateCancelDownload => 'Cancel download';

  @override
  String get forkUpdateReady => 'The installer is downloaded and verified';

  @override
  String get forkUpdateInstall => 'Install update';

  @override
  String get forkUpdateInstallTitle => 'Install this update?';

  @override
  String get forkUpdateInstallAndroid =>
      'The system installer will open. If prompted, allow GooeSteamKit to install apps, then follow the system instructions.';

  @override
  String get forkUpdateInstallWindows =>
      'The installer will open and GooeSteamKit will close. Finish your current work first, then follow the installer instructions.';

  @override
  String get forkUpdateInstallConfirm => 'Continue installation';

  @override
  String get forkUpdateInstallStarted =>
      'The system installer is open; follow its instructions';

  @override
  String get forkUpdateCheckFailed =>
      'Could not check for updates. Try again later.';

  @override
  String get forkUpdateDownloadFailed => 'Download failed. Please retry.';

  @override
  String get forkUpdateHashFailed =>
      'The installer failed verification and was blocked. Download it again.';

  @override
  String get forkUpdateInstallFailed =>
      'Could not open the installer. Please retry.';

  @override
  String get forkUpdateNoCompatibleAsset =>
      'This release has no installer for this device';

  @override
  String get forkUpdateUnverifiable =>
      'This installer has no trusted checksum and cannot be downloaded or installed';

  @override
  String get forkUpdateInvalidMetadata =>
      'Release information is incomplete or invalid. Try again later.';

  @override
  String get forkUpdateUnsupported =>
      'In-app updates are not supported on this device';

  @override
  String get forkUpdateCancelled => 'Download cancelled';

  @override
  String get forkUpdatePermissionRequired =>
      'Allow GooeSteamKit to install apps, then return here to install';

  @override
  String get forkUpdateOpenPermissionSettings => 'Allow app installs';

  @override
  String get forkUpdateWrongPackage =>
      'This installer belongs to another app and was blocked';

  @override
  String get forkUpdateSignatureMismatch =>
      'The installer signature does not match this app and was blocked';

  @override
  String get backupCodesNativeIntro =>
      'Generate one-time Steam login codes here. Steam requires SMS verification of the phone linked to this account. Generating a new set may replace existing codes.';

  @override
  String get backupCodesSendSms => 'Send verification SMS';

  @override
  String get backupCodesSmsPrompt =>
      'Enter the verification code from Steam\'s SMS.';

  @override
  String get backupCodesSmsLabel => 'SMS verification code';

  @override
  String get backupCodesGenerate => 'Verify and generate codes';

  @override
  String get backupCodesReady => 'Your one-time login codes';

  @override
  String get backupCodesKeepSafe =>
      'Each code can be used once. Keep a printed copy somewhere safe. GooeSteamKit does not save these codes; leaving this page or switching apps clears them. Steam emails you when codes are generated or used.';

  @override
  String get backupCodesClear => 'Clear codes';

  @override
  String get backupCodesRequestFailed =>
      'Steam could not complete this request. No request was retried automatically. Check your connection and try again when ready.';

  @override
  String get backupCodesUnexpectedResponse =>
      'Steam returned an unrecognized response. The result could not be confirmed; the request was not retried.';

  @override
  String get backupCodesInvalidSms =>
      'Steam rejected the verification code. Check the SMS and try again.';

  @override
  String get backupCodesRateLimited =>
      'Steam is limiting requests. Please wait before trying again.';

  @override
  String get backupCodesPhoneRequired =>
      'Steam requires a verified phone number on this account.';

  @override
  String get backupCodesManualHelp => 'Official Steam page (optional)';

  @override
  String get steamAccelerationTitle => 'Steam acceleration';

  @override
  String get steamAccelerationDesc =>
      'Use an external proxy first, then built-in acceleration when it closes. Only Steam requests in GooeSteamKit use the built-in route.';

  @override
  String get steamAccelerationOff => 'Off';

  @override
  String get steamAccelerationLoading => 'Syncing subscription…';

  @override
  String get steamAccelerationStarting => 'Starting…';

  @override
  String get steamAccelerationRunning => 'Running';

  @override
  String get steamAccelerationPaused => 'Built-in acceleration is on standby';

  @override
  String get steamAccelerationFailed => 'Acceleration unavailable';

  @override
  String get steamAccelerationUnsupported =>
      'Currently supported on Windows and Android only.';

  @override
  String get steamAccelerationConfigured => 'Subscription saved on this device';

  @override
  String get steamAccelerationUnconfigured => 'No subscription configured';

  @override
  String get steamAccelerationConfigure => 'Add subscription';

  @override
  String get steamAccelerationReplace => 'Replace subscription';

  @override
  String get steamAccelerationSubscription => 'Subscription URL';

  @override
  String get steamAccelerationSubscriptionHelp =>
      'This link may contain private credentials and is stored securely on your device. With Sync app settings enabled, subscriptions and nodes are also encrypted with your sync passphrase and synced. After saving, select Refresh nodes.';

  @override
  String get steamAccelerationClear => 'Clear subscription';

  @override
  String get steamAccelerationClearConfirm =>
      'Stop built-in acceleration and delete the saved subscription and nodes? With settings sync enabled, this deletion also syncs to your other devices.';

  @override
  String get steamAccelerationSync => 'Refresh nodes';

  @override
  String get steamAccelerationDownloadingCore =>
      'Downloading acceleration component…';

  @override
  String get steamAccelerationCoreDownload =>
      'Could not download the acceleration component after trying mirrors and the official source. Try again later.';

  @override
  String get steamAccelerationExternalActiveHelp =>
      'Using the external connection. With automatic switching enabled, the built-in route takes over when it closes. No manual switching is needed.';

  @override
  String get steamAccelerationNodes => 'Nodes';

  @override
  String get steamAccelerationNoNodes =>
      'Sync the subscription to load available nodes.';

  @override
  String get steamAccelerationNode => 'Selected node';

  @override
  String get steamAccelerationStart => 'Enable automatic switching';

  @override
  String get steamAccelerationStop => 'Pause automatic switching';

  @override
  String get steamAccelerationAuto => 'Enable on launch';

  @override
  String get steamAccelerationAutoDesc =>
      'Prefer an external proxy or VPN; resume the built-in route when it closes. Pausing applies until the next launch.';

  @override
  String get steamAccelerationEnvironment => 'External proxy detection';

  @override
  String get steamAccelerationExternalProxy => 'System proxy or PAC detected';

  @override
  String get steamAccelerationExternalVpn => 'VPN or tunnel detected';

  @override
  String get steamAccelerationNoExternal => 'No external proxy detected';

  @override
  String get steamAccelerationDetectionUnavailable =>
      'External proxy status is unknown, so the built-in route will not start. Check the system proxy settings, then check again.';

  @override
  String get steamAccelerationEnvironmentHelp =>
      'Checks the local connection settings while the app is visible. System proxy and VPN settings are never changed.';

  @override
  String steamAccelerationSkipped(int count) {
    return 'Skipped $count unsupported nodes.';
  }

  @override
  String get steamAccelerationInvalidSubscription =>
      'Enter a valid HTTP or HTTPS subscription URL.';

  @override
  String get steamAccelerationNetworkError =>
      'Could not fetch the subscription. Check your connection and try again.';

  @override
  String get steamAccelerationUnsupportedSubscription =>
      'The subscription has no supported nodes. Use a compatible Clash subscription.';

  @override
  String get steamAccelerationStorageError =>
      'Secure storage is unavailable. The setting could not be saved.';

  @override
  String get steamAccelerationCoreUnavailable =>
      'The acceleration component is missing. Install an updated app package.';

  @override
  String get steamAccelerationCoreIntegrity =>
      'The acceleration component failed verification and was blocked.';

  @override
  String get steamAccelerationStartFailed =>
      'Could not start acceleration. Refresh the environment check and try again.';

  @override
  String get inventorySearch => 'Search items';

  @override
  String get inventoryFilterType => 'Type';

  @override
  String get inventoryFilterRarity => 'Rarity / quality';

  @override
  String get inventoryFilterOther => 'Other / unclassified';

  @override
  String get inventoryFilterNoMatches => 'No items match these filters';

  @override
  String get inventoryFilterLoaded =>
      'Filters apply to loaded items. Load more to include the rest.';

  @override
  String get steamConnectionTitle => 'Connection check';

  @override
  String get steamConnectionNotChecked => 'Not checked';

  @override
  String get steamConnectionChecking => 'Checking connection…';

  @override
  String get steamConnectionAvailable => 'Connection available';

  @override
  String get steamConnectionPartial => 'Some Steam services are unavailable';

  @override
  String get steamConnectionUnavailable => 'Steam connection unavailable';

  @override
  String get steamConnectionCheck => 'Check connection';

  @override
  String get steamConnectionApi => 'Steam sign-in API';

  @override
  String get steamConnectionCommunity => 'Steam Community and Market';

  @override
  String get steamConnectionReachable => 'Reachable';

  @override
  String get steamConnectionFailed => 'Connection failed';

  @override
  String get steamConnectionInternal => 'Built-in route';

  @override
  String get steamConnectionExternal => 'External HTTP proxy';

  @override
  String get steamConnectionSystem => 'External VPN / tunnel';

  @override
  String get steamConnectionDirect => 'Direct connection';

  @override
  String steamConnectionCheckedAt(String time) {
    return 'Last checked: $time';
  }

  @override
  String get steamConnectionNoVpnIcon =>
      'This only routes Steam requests inside GooeSteamKit, so Android does not show a system VPN icon. It does not accelerate the Steam app or other apps.';

  @override
  String get steamConnectionScope =>
      'Checks Steam API and Community over GooeSteamKit’s current route without account credentials. Results describe this check, not continuous availability.';

  @override
  String tradeSendNotSent(String reason) {
    return 'Offer was not sent. $reason';
  }

  @override
  String get tradeCheckSendResult => 'Check send result';

  @override
  String get tradeSendNotFound =>
      'No matching new offer is visible yet. Steam may take time to update. Check Pending and sent offers before sending again.';

  @override
  String tradeSendCheckFailed(String reason) {
    return 'Could not verify the send result. $reason';
  }

  @override
  String get tradeSendRejected =>
      'Steam rejected this offer without a detailed reason. Check the selected items and trading restrictions.';

  @override
  String get tradeSendUnreadableResponse =>
      'Steam did not return a complete send receipt.';

  @override
  String get steamConnectionPacHelp =>
      'A system proxy setting was found, but no usable HTTP endpoint or VPN route is available. PAC scripts are not evaluated. Enable the external app’s HTTP proxy or VPN mode.';

  @override
  String forkUpdateTransferSize(String received, String total) {
    return '$received / $total MiB';
  }

  @override
  String forkUpdateTransferSpeed(String speed, String unit) {
    return '$speed $unit/s';
  }

  @override
  String forkUpdateRemainingSeconds(int seconds) {
    return 'About ${seconds}s left';
  }

  @override
  String forkUpdateRemainingMinutes(int minutes) {
    return 'About ${minutes}min left';
  }

  @override
  String get forkUpdateWaitingForData => 'Waiting for data…';

  @override
  String get forkUpdateVerifying => 'Verifying installer…';

  @override
  String get forkUpdateConnectionHint =>
      'Automatic mode downloads through GH-Proxy without starting a proxy, then falls back to GitHub if needed. Files are checked against GitHub’s SHA-256.';

  @override
  String get forkUpdateSourceLabel => 'Download source';

  @override
  String get forkUpdateSourceAutomatic => 'Automatic acceleration';

  @override
  String get forkUpdateSourceOfficial => 'GitHub official';

  @override
  String forkUpdateSourceAccelerated(String provider) {
    return 'Direct acceleration · $provider';
  }

  @override
  String get marketTabSearch => 'Market';

  @override
  String get marketSearchHint => 'Search items, e.g. AK-47';

  @override
  String get marketSearchEmpty =>
      'Choose a game and currency, then search for an item. Data loads only when you search.';

  @override
  String get marketSearchButton => 'Search market';

  @override
  String get marketSearchAllGames => 'All games';

  @override
  String get marketSearchGame => 'Game';

  @override
  String get marketSearchCurrency => 'Currency';

  @override
  String get marketSearchNoResults => 'No matching items. Try another search.';

  @override
  String get marketSearchMore => 'Load more';

  @override
  String marketSearchListings(int count) {
    return 'Listings: $count';
  }

  @override
  String get marketSearchPriceUnavailable => 'Price unavailable';

  @override
  String get marketSearchPriceNote =>
      'Reference prices load in the selected currency only for visible items and may change.';

  @override
  String get marketSearchRefreshPrice => 'Refresh price';

  @override
  String get marketSearchRateLimited =>
      'Steam is receiving too many requests. Please try again later.';

  @override
  String get marketSearchUnavailable =>
      'Market items are unavailable right now. Please try again later.';

  @override
  String marketSearchRequestedCurrency(String currency) {
    return 'Requested currency: $currency';
  }

  @override
  String get steamConnectionUnresolvedProxy => 'System proxy unavailable';

  @override
  String get steamDesktopLoginButton => 'Open Steam and sign in';

  @override
  String get steamDesktopLoginHelp =>
      'Open or switch Steam to the selected account and automatically approve the QR code in this computer\'s Steam sign-in window. Please exit any running games first.';

  @override
  String get steamDesktopLoginPreparing => 'Preparing the selected account…';

  @override
  String get steamDesktopLoginWaitingQr =>
      'Waiting for this computer\'s Steam sign-in QR code…';

  @override
  String get steamDesktopLoginApproving =>
      'Approving this computer\'s sign-in…';

  @override
  String get steamDesktopLoginWaitingAccount =>
      'Confirming Steam sign-in status…';

  @override
  String get steamDesktopLoginComplete =>
      'Verified that the Steam client\'s current account matches the selected account.';

  @override
  String get steamDesktopLoginManual =>
      'Steam is open, but its local sign-in QR code could not be verified. Use the QR scanning option below to continue.';

  @override
  String get steamDesktopLoginUnconfirmed =>
      'A sign-in approval request was submitted, but Steam sign-in has not been confirmed. Check the Steam window, then refresh the status.';

  @override
  String get steamDesktopLoginCancelled => 'Automatic sign-in stopped';

  @override
  String get steamDesktopLoginCancel => 'Stop automatic approval';

  @override
  String get steamDesktopLoginWrongAccount =>
      'Steam is signed in to a different account. Automatic approval has stopped.';

  @override
  String get steamClientOpen => 'Open Steam';

  @override
  String get steamSwitchLaunchFailed =>
      'Steam could not start. Check the installation path and make sure Steam can run normally.';

  @override
  String get steamSwitchFileAccessFailed =>
      'Could not back up or change Steam settings. Check read and write permissions for the installation folder.';

  @override
  String get steamDesktopLoginSession =>
      'Steam is open. Connecting to the selected account…';

  @override
  String get steamSwitchInspecting => 'Checking Steam on this PC';

  @override
  String steamSwitchErrorDetails(
    String stage,
    String code,
    String systemError,
  ) {
    return 'Stage: $stage; error code: $code; Windows: $systemError.';
  }

  @override
  String get approveScreenBusy =>
      'Another screen capture is in progress. Finish or cancel it first.';

  @override
  String get approveScreenDisplayChanged =>
      'The display layout has changed. Select the QR code area again.';

  @override
  String get approveScreenRegionTooLarge =>
      'The selected area is too large. Select only the QR code area.';

  @override
  String approveScreenFailedDetail(String detail) {
    return 'Could not capture the screen. Try again. Error details: $detail.';
  }
}
