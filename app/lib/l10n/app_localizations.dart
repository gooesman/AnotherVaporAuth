import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @steamSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Steam account'**
  String get steamSwitchTitle;

  /// No description provided for @steamSwitchUnifiedHelp.
  ///
  /// In en, this message translates to:
  /// **'Select an account and switch to open Steam and sign in. Imported accounts use remembered Steam sign-in details first, then automatically approve the new local login QR code when an online session is available. Accounts not imported here can use their remembered Steam sign-in. Please exit running games first.'**
  String get steamSwitchUnifiedHelp;

  /// No description provided for @steamSwitchHelp.
  ///
  /// In en, this message translates to:
  /// **'Switch between Steam accounts that have already signed in on this PC with their sign-in details remembered. Importing an authenticator into GooeSteamKit does not sign that account in to the Steam client.'**
  String get steamSwitchHelp;

  /// No description provided for @steamSwitchPath.
  ///
  /// In en, this message translates to:
  /// **'Steam installation folder'**
  String get steamSwitchPath;

  /// No description provided for @steamSwitchNotFound.
  ///
  /// In en, this message translates to:
  /// **'Steam was not found. Choose steam.exe to locate your installation.'**
  String get steamSwitchNotFound;

  /// No description provided for @steamSwitchBrowse.
  ///
  /// In en, this message translates to:
  /// **'Choose steam.exe'**
  String get steamSwitchBrowse;

  /// No description provided for @steamSwitchNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No saved Steam accounts were found on this PC. Sign in to Steam, enable remembering your sign-in details, then refresh.'**
  String get steamSwitchNoAccounts;

  /// No description provided for @steamSwitchNoMatch.
  ///
  /// In en, this message translates to:
  /// **'The selected account has no sign-in record on this PC. Use the one-click sign-in above, then refresh after Steam remembers the account to switch from the list below.'**
  String get steamSwitchNoMatch;

  /// No description provided for @steamSwitchNeedsLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to this account in Steam and enable remembering your sign-in details, then refresh.'**
  String get steamSwitchNeedsLogin;

  /// No description provided for @steamSwitchButton.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get steamSwitchButton;

  /// Confirmation before restarting the local Steam client to select a remembered account.
  ///
  /// In en, this message translates to:
  /// **'Steam will close and restart to sign in as {account}. First close your games and wait for Steam Cloud saves to finish syncing. Continue?'**
  String steamSwitchConfirm(String account);

  /// No description provided for @steamSwitchStopping.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Steam to exit…'**
  String get steamSwitchStopping;

  /// No description provided for @steamSwitchBackingUp.
  ///
  /// In en, this message translates to:
  /// **'Backing up Steam settings…'**
  String get steamSwitchBackingUp;

  /// No description provided for @steamSwitchConfiguring.
  ///
  /// In en, this message translates to:
  /// **'Selecting the Steam account…'**
  String get steamSwitchConfiguring;

  /// No description provided for @steamSwitchStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting Steam…'**
  String get steamSwitchStarting;

  /// No description provided for @steamSwitchRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring Steam settings…'**
  String get steamSwitchRestoring;

  /// No description provided for @steamSwitchLaunched.
  ///
  /// In en, this message translates to:
  /// **'Steam has started. Check the signed-in account in the client. Sign in again if prompted.'**
  String get steamSwitchLaunched;

  /// No description provided for @steamSwitchBackup.
  ///
  /// In en, this message translates to:
  /// **'Settings backup location'**
  String get steamSwitchBackup;

  /// No description provided for @steamSwitchInvalidPath.
  ///
  /// In en, this message translates to:
  /// **'This Steam installation or its settings could not be read. Choose the correct steam.exe and try again.'**
  String get steamSwitchInvalidPath;

  /// No description provided for @steamSwitchCloseFailed.
  ///
  /// In en, this message translates to:
  /// **'Steam could not exit normally. Exit Steam manually, then try again.'**
  String get steamSwitchCloseFailed;

  /// No description provided for @steamSwitchBusy.
  ///
  /// In en, this message translates to:
  /// **'Another account switch is in progress. Try again shortly.'**
  String get steamSwitchBusy;

  /// No description provided for @steamSwitchChanged.
  ///
  /// In en, this message translates to:
  /// **'Steam settings changed during the switch. Exit Steam, refresh the list, then try again.'**
  String get steamSwitchChanged;

  /// No description provided for @steamSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'The account switch could not finish. Check Steam and try again.'**
  String get steamSwitchFailed;

  /// No description provided for @steamSwitchRecoveryNeeded.
  ///
  /// In en, this message translates to:
  /// **'The account switch failed and some settings could not be restored. Keep the backup below and restore the settings before trying again.'**
  String get steamSwitchRecoveryNeeded;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'GooeSteamKit'**
  String get appTitle;

  /// No description provided for @navAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get navAccounts;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @unlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockTitle;

  /// No description provided for @unlockPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your encryption passkey'**
  String get unlockPrompt;

  /// No description provided for @unlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockButton;

  /// No description provided for @unlockInvalid.
  ///
  /// In en, this message translates to:
  /// **'That passkey is invalid.'**
  String get unlockInvalid;

  /// No description provided for @unlockWithBiometric.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics / device PIN'**
  String get unlockWithBiometric;

  /// No description provided for @unlockLoading.
  ///
  /// In en, this message translates to:
  /// **'Decrypting…'**
  String get unlockLoading;

  /// No description provided for @unlockCantUnlock.
  ///
  /// In en, this message translates to:
  /// **'Can\'t unlock?'**
  String get unlockCantUnlock;

  /// No description provided for @resetVaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset encrypted data'**
  String get resetVaultTitle;

  /// No description provided for @resetVaultBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes every account entry and encryption key stored on this device; afterwards you re-import your maFile backups. Your Steam accounts and their authenticators are not affected.\n\nUse this when the correct PIN keeps being rejected — typically after a backup restore or phone migration, since the hardware key never leaves the original device, restored data can never be decrypted.\n\nThis cannot be undone.'**
  String get resetVaultBody;

  /// No description provided for @resetVaultConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete & reset'**
  String get resetVaultConfirm;

  /// No description provided for @storeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Stored data can\'t be read'**
  String get storeErrorTitle;

  /// No description provided for @storeErrorBody.
  ///
  /// In en, this message translates to:
  /// **'GooeSteamKit\'s local account database (manifest.json) is missing or corrupt. This can happen after an interrupted write or a partial restore. Retry first; if it keeps failing, reset and re-import your maFile backups.'**
  String get storeErrorBody;

  /// No description provided for @storeRepair.
  ///
  /// In en, this message translates to:
  /// **'Attempt repair'**
  String get storeRepair;

  /// No description provided for @storeActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String storeActionFailed(String error);

  /// No description provided for @pinSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set unlock PIN'**
  String get pinSetupTitle;

  /// No description provided for @pinSetupPrompt.
  ///
  /// In en, this message translates to:
  /// **'Protect GooeSteamKit with a 6-digit PIN. You\'ll enter it (or your fingerprint) to unlock.'**
  String get pinSetupPrompt;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit PIN'**
  String get pinLabel;

  /// No description provided for @pinConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get pinConfirmLabel;

  /// No description provided for @pinSetButton.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get pinSetButton;

  /// No description provided for @settingsSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get settingsSet;

  /// No description provided for @pinChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get pinChangeTitle;

  /// No description provided for @pinCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get pinCurrentLabel;

  /// No description provided for @pinNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get pinNewLabel;

  /// No description provided for @pinSixDigits.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit PIN.'**
  String get pinSixDigits;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs don\'t match.'**
  String get pinMismatch;

  /// No description provided for @unlockBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock GooeSteamKit'**
  String get unlockBiometricReason;

  /// No description provided for @settingsBiometric.
  ///
  /// In en, this message translates to:
  /// **'Use device unlock'**
  String get settingsBiometric;

  /// No description provided for @settingsBiometricDesc.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint, Windows Hello or your device credential instead of the GooeSteamKit PIN when startup verification is on. Turning startup verification off disables this option; enable it separately after turning verification back on.'**
  String get settingsBiometricDesc;

  /// No description provided for @settingsBiometricNeedPasskey.
  ///
  /// In en, this message translates to:
  /// **'Set an encryption passkey first.'**
  String get settingsBiometricNeedPasskey;

  /// No description provided for @settingsBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No biometrics or device lock set up on this device.'**
  String get settingsBiometricUnavailable;

  /// No description provided for @settingsBiometricEnabled.
  ///
  /// In en, this message translates to:
  /// **'Device unlock enabled'**
  String get settingsBiometricEnabled;

  /// No description provided for @settingsHoldConfirm.
  ///
  /// In en, this message translates to:
  /// **'Hold to confirm'**
  String get settingsHoldConfirm;

  /// No description provided for @settingsHoldConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'Irreversible accepts (trades, confirmations) require press-and-hold. When off, a single tap acts immediately; batch actions still ask first.'**
  String get settingsHoldConfirmDesc;

  /// No description provided for @settingsDeleteHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to delete'**
  String get settingsDeleteHold;

  /// No description provided for @settingsDeleteHoldDesc.
  ///
  /// In en, this message translates to:
  /// **'The Delete button in the removal dialog must be held until it charges up — an accidental tap can\'t remove an account.'**
  String get settingsDeleteHoldDesc;

  /// No description provided for @accountSessionInvalid.
  ///
  /// In en, this message translates to:
  /// **'Sign-in invalid — tap to log in again'**
  String get accountSessionInvalid;

  /// No description provided for @settingsHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHaptics;

  /// No description provided for @settingsHapticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Vibration ticks while holding to confirm and on completion.'**
  String get settingsHapticsDesc;

  /// No description provided for @settingsBlockScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Block screenshots'**
  String get settingsBlockScreenshots;

  /// No description provided for @settingsBlockScreenshotsDesc.
  ///
  /// In en, this message translates to:
  /// **'Hides GooeSteamKit from screenshots, screen recording and the recent-apps preview. Also blanks the window during screen sharing, and stops you attaching screenshots to feedback.'**
  String get settingsBlockScreenshotsDesc;

  /// No description provided for @passkeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Passkey'**
  String get passkeyLabel;

  /// No description provided for @accountsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet. Import a maFile or log in to add one.'**
  String get accountsEmpty;

  /// No description provided for @emptyAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get emptyAddAccount;

  /// No description provided for @accountReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get accountReady;

  /// No description provided for @tutCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Live token'**
  String get tutCodeTitle;

  /// No description provided for @tutCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the big code to copy it. Tap the account name to cycle username / nickname / SteamID.'**
  String get tutCodeBody;

  /// No description provided for @tutSwipeRightTitle.
  ///
  /// In en, this message translates to:
  /// **'Swipe right → confirmations'**
  String get tutSwipeRightTitle;

  /// No description provided for @tutSwipeRightBody.
  ///
  /// In en, this message translates to:
  /// **'Swipe an account to the right to open its trade confirmations.'**
  String get tutSwipeRightBody;

  /// No description provided for @tutSwipeLeftTitle.
  ///
  /// In en, this message translates to:
  /// **'Swipe left → more actions'**
  String get tutSwipeLeftTitle;

  /// No description provided for @tutSwipeLeftBody.
  ///
  /// In en, this message translates to:
  /// **'Swipe left to refresh the session, export the maFile, or remove the account.'**
  String get tutSwipeLeftBody;

  /// No description provided for @tutLongPressTitle.
  ///
  /// In en, this message translates to:
  /// **'Long-press → inventory & market'**
  String get tutLongPressTitle;

  /// No description provided for @tutLongPressBody.
  ///
  /// In en, this message translates to:
  /// **'Long-press an account to browse its inventory and list items on the Community Market.'**
  String get tutLongPressBody;

  /// No description provided for @tutPullTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get tutPullTitle;

  /// No description provided for @tutPullBody.
  ///
  /// In en, this message translates to:
  /// **'Pull the account list down to refresh avatars and check pending sign-ins.'**
  String get tutPullBody;

  /// No description provided for @tutSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tutSkip;

  /// No description provided for @tutNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tutNext;

  /// No description provided for @tutDone.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get tutDone;

  /// No description provided for @settingsTutorial.
  ///
  /// In en, this message translates to:
  /// **'Gesture tutorial'**
  String get settingsTutorial;

  /// No description provided for @settingsTutorialDesc.
  ///
  /// In en, this message translates to:
  /// **'Replay the home-screen walkthrough (swipes, long-press, pull-to-refresh).'**
  String get settingsTutorialDesc;

  /// No description provided for @settingsTutorialReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get settingsTutorialReplay;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to GooeSteamKit'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your authenticator is stored encrypted on this device. Choose how to begin.'**
  String get welcomeSubtitle;

  /// No description provided for @welcomeLoginCta.
  ///
  /// In en, this message translates to:
  /// **'Log in to Steam'**
  String get welcomeLoginCta;

  /// No description provided for @welcomeLoginSub.
  ///
  /// In en, this message translates to:
  /// **'Set up a new authenticator'**
  String get welcomeLoginSub;

  /// No description provided for @welcomeImportCta.
  ///
  /// In en, this message translates to:
  /// **'Import .maFile'**
  String get welcomeImportCta;

  /// No description provided for @welcomeImportSub.
  ///
  /// In en, this message translates to:
  /// **'Migrate an existing account'**
  String get welcomeImportSub;

  /// No description provided for @welcomeSyncCta.
  ///
  /// In en, this message translates to:
  /// **'Restore from sync'**
  String get welcomeSyncCta;

  /// No description provided for @welcomeSyncSub.
  ///
  /// In en, this message translates to:
  /// **'Pull your accounts from an existing sync library'**
  String get welcomeSyncSub;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Login code copied to clipboard'**
  String get codeCopied;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// No description provided for @copySteamId.
  ///
  /// In en, this message translates to:
  /// **'Copy SteamID'**
  String get copySteamId;

  /// No description provided for @pendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingTitle;

  /// No description provided for @pendingTabConfirmations.
  ///
  /// In en, this message translates to:
  /// **'Confirmations'**
  String get pendingTabConfirmations;

  /// No description provided for @pendingTabOffers.
  ///
  /// In en, this message translates to:
  /// **'Trade offers'**
  String get pendingTabOffers;

  /// No description provided for @confirmationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirmations'**
  String get confirmationsTitle;

  /// No description provided for @confirmationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending confirmations.'**
  String get confirmationsEmpty;

  /// No description provided for @confirmationsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get confirmationsRefresh;

  /// No description provided for @confAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get confAccept;

  /// No description provided for @confDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get confDecline;

  /// No description provided for @confSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get confSelectAll;

  /// No description provided for @confAcceptSelected.
  ///
  /// In en, this message translates to:
  /// **'Accept selected'**
  String get confAcceptSelected;

  /// No description provided for @confDeclineSelected.
  ///
  /// In en, this message translates to:
  /// **'Decline selected'**
  String get confDeclineSelected;

  /// No description provided for @confAcceptAll.
  ///
  /// In en, this message translates to:
  /// **'Accept all'**
  String get confAcceptAll;

  /// No description provided for @confRejectAll.
  ///
  /// In en, this message translates to:
  /// **'Reject all'**
  String get confRejectAll;

  /// No description provided for @confAcceptAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Accept all {count} confirmations?'**
  String confAcceptAllConfirm(int count);

  /// No description provided for @confRejectAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reject all {count} confirmations?'**
  String confRejectAllConfirm(int count);

  /// No description provided for @confAcceptAllWarn.
  ///
  /// In en, this message translates to:
  /// **'This approves every pending trade and market listing at once. Make sure you recognize all of them.'**
  String get confAcceptAllWarn;

  /// No description provided for @confRejectAllWarn.
  ///
  /// In en, this message translates to:
  /// **'This cancels every pending confirmation at once.'**
  String get confRejectAllWarn;

  /// No description provided for @confPending.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String confPending(int count);

  /// No description provided for @confAllProcessed.
  ///
  /// In en, this message translates to:
  /// **'All processed'**
  String get confAllProcessed;

  /// No description provided for @confTypeTrade.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get confTypeTrade;

  /// No description provided for @confTypeMarket.
  ///
  /// In en, this message translates to:
  /// **'Market listing'**
  String get confTypeMarket;

  /// No description provided for @confTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get confTypeOther;

  /// No description provided for @confTypeFamilyJoin.
  ///
  /// In en, this message translates to:
  /// **'Family invite'**
  String get confTypeFamilyJoin;

  /// No description provided for @confTypeApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get confTypeApiKey;

  /// No description provided for @confTypePhoneChange.
  ///
  /// In en, this message translates to:
  /// **'Phone change'**
  String get confTypePhoneChange;

  /// No description provided for @confTypeAccountRecovery.
  ///
  /// In en, this message translates to:
  /// **'Account recovery'**
  String get confTypeAccountRecovery;

  /// No description provided for @confTypeFeatureOptOut.
  ///
  /// In en, this message translates to:
  /// **'Feature opt-out'**
  String get confTypeFeatureOptOut;

  /// No description provided for @confProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing {count} confirmation(s)…'**
  String confProcessing(int count);

  /// No description provided for @confResult.
  ///
  /// In en, this message translates to:
  /// **'{ok} succeeded, {fail} failed'**
  String confResult(int ok, int fail);

  /// No description provided for @confNeedsLogin.
  ///
  /// In en, this message translates to:
  /// **'Session expired — sign in again to refresh this account.'**
  String get confNeedsLogin;

  /// No description provided for @confRejected.
  ///
  /// In en, this message translates to:
  /// **'Steam rejected the confirmation request. This usually means the maFile does not match the authenticator currently on the account (common with purchased accounts) — remove the authenticator and link it again, or import the right maFile. A large clock drift can also cause this.'**
  String get confRejected;

  /// No description provided for @offersSegReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get offersSegReceived;

  /// No description provided for @offersSegSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get offersSegSent;

  /// No description provided for @offersSegHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get offersSegHistory;

  /// No description provided for @offersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No trade offers.'**
  String get offersEmpty;

  /// No description provided for @offerGift.
  ///
  /// In en, this message translates to:
  /// **'Gift — you give nothing'**
  String get offerGift;

  /// No description provided for @offerOneSided.
  ///
  /// In en, this message translates to:
  /// **'You give items and receive nothing'**
  String get offerOneSided;

  /// No description provided for @offerEscrow.
  ///
  /// In en, this message translates to:
  /// **'Items will be held by Steam before delivery'**
  String get offerEscrow;

  /// No description provided for @offerAcceptHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to accept'**
  String get offerAcceptHold;

  /// No description provided for @offerDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get offerDecline;

  /// No description provided for @offerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel offer'**
  String get offerCancel;

  /// No description provided for @offerReceiveLabel.
  ///
  /// In en, this message translates to:
  /// **'You receive'**
  String get offerReceiveLabel;

  /// No description provided for @offerGiveLabel.
  ///
  /// In en, this message translates to:
  /// **'You give'**
  String get offerGiveLabel;

  /// No description provided for @offerAccepted.
  ///
  /// In en, this message translates to:
  /// **'Offer accepted — confirm it in the Confirmations tab'**
  String get offerAccepted;

  /// No description provided for @offerAcceptedNoConf.
  ///
  /// In en, this message translates to:
  /// **'Offer accepted.'**
  String get offerAcceptedNoConf;

  /// No description provided for @offerActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {msg}'**
  String offerActionFailed(String msg);

  /// No description provided for @offerDeclined.
  ///
  /// In en, this message translates to:
  /// **'Offer declined.'**
  String get offerDeclined;

  /// No description provided for @offerCanceled.
  ///
  /// In en, this message translates to:
  /// **'Offer canceled.'**
  String get offerCanceled;

  /// No description provided for @pendingTabInvites.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get pendingTabInvites;

  /// No description provided for @famInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'「{groupName}」 invited you to join'**
  String famInviteTitle(String groupName);

  /// No description provided for @famInviteTitleGeneric.
  ///
  /// In en, this message translates to:
  /// **'Family group invite'**
  String get famInviteTitleGeneric;

  /// No description provided for @famInviteFrom.
  ///
  /// In en, this message translates to:
  /// **'Invited by {inviter}'**
  String famInviteFrom(String inviter);

  /// No description provided for @famInviteRole.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}'**
  String famInviteRole(String role);

  /// No description provided for @famInviteSlots.
  ///
  /// In en, this message translates to:
  /// **'Members {used}/{total}'**
  String famInviteSlots(int used, int total);

  /// No description provided for @famRoleAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get famRoleAdult;

  /// No description provided for @famRoleChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get famRoleChild;

  /// No description provided for @famRoleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Role #{n}'**
  String famRoleUnknown(int n);

  /// No description provided for @famPreflightTitle.
  ///
  /// In en, this message translates to:
  /// **'Join checks'**
  String get famPreflightTitle;

  /// No description provided for @famCheckWalletMatch.
  ///
  /// In en, this message translates to:
  /// **'Wallet region matches'**
  String get famCheckWalletMatch;

  /// No description provided for @famCheckWalletMismatch.
  ///
  /// In en, this message translates to:
  /// **'Wallet region doesn\'t match — Steam restricts joining'**
  String get famCheckWalletMismatch;

  /// No description provided for @famCheckIpMatch.
  ///
  /// In en, this message translates to:
  /// **'Usual IP matches'**
  String get famCheckIpMatch;

  /// No description provided for @famCheckIpMismatch.
  ///
  /// In en, this message translates to:
  /// **'IP doesn\'t match your usual location'**
  String get famCheckIpMismatch;

  /// No description provided for @famCheckCooldown.
  ///
  /// In en, this message translates to:
  /// **'Joining locks family-group switching for 1 year (Steam cooldown)'**
  String get famCheckCooldown;

  /// No description provided for @famJoinRestricted.
  ///
  /// In en, this message translates to:
  /// **'Steam blocked this join (restriction {code})'**
  String famJoinRestricted(int code);

  /// No description provided for @famInviteJoinHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to join'**
  String get famInviteJoinHold;

  /// No description provided for @famInviteAwaiting2fa.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation — check the Confirmations tab'**
  String get famInviteAwaiting2fa;

  /// No description provided for @famInviteJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined ✓'**
  String get famInviteJoined;

  /// No description provided for @famInviteViewGroup.
  ///
  /// In en, this message translates to:
  /// **'View family group ›'**
  String get famInviteViewGroup;

  /// No description provided for @famJoinSent.
  ///
  /// In en, this message translates to:
  /// **'Join requested — confirm it in the Confirmations tab'**
  String get famJoinSent;

  /// No description provided for @famJoinDone.
  ///
  /// In en, this message translates to:
  /// **'Joined the family group.'**
  String get famJoinDone;

  /// No description provided for @famJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Join failed: {msg}'**
  String famJoinFailed(String msg);

  /// No description provided for @famInvitesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending family invites.'**
  String get famInvitesEmpty;

  /// No description provided for @famAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Family group'**
  String get famAccountAction;

  /// No description provided for @famNotInGroup.
  ///
  /// In en, this message translates to:
  /// **'This account isn\'t in a family group.'**
  String get famNotInGroup;

  /// No description provided for @famSummaryMembers.
  ///
  /// In en, this message translates to:
  /// **'Members {used}/{total}'**
  String famSummaryMembers(int used, int total);

  /// No description provided for @famSummaryCooldown.
  ///
  /// In en, this message translates to:
  /// **'Cooldown {days}d'**
  String famSummaryCooldown(int days);

  /// No description provided for @famInvitesSection.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get famInvitesSection;

  /// No description provided for @famSectionMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get famSectionMembers;

  /// No description provided for @famMemberYou.
  ///
  /// In en, this message translates to:
  /// **'(you)'**
  String get famMemberYou;

  /// No description provided for @famSectionPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get famSectionPending;

  /// No description provided for @famPendingComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Purchase approval is coming in a future update.'**
  String get famPendingComingSoon;

  /// No description provided for @deviceSessionsAction.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get deviceSessionsAction;

  /// No description provided for @deviceSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logged-in devices'**
  String get deviceSessionsTitle;

  /// No description provided for @deviceSessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active devices for this account.'**
  String get deviceSessionsEmpty;

  /// No description provided for @deviceRevokeAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get deviceRevokeAction;

  /// No description provided for @deviceRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign \"{name}\" out of your Steam account? It will need to log in again.'**
  String deviceRevokeConfirm(String name);

  /// No description provided for @deviceRevokeDone.
  ///
  /// In en, this message translates to:
  /// **'Signed \"{name}\" out.'**
  String deviceRevokeDone(String name);

  /// No description provided for @deviceRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign the device out: {error}'**
  String deviceRevokeFailed(String error);

  /// No description provided for @deviceCurrent.
  ///
  /// In en, this message translates to:
  /// **'(this device)'**
  String get deviceCurrent;

  /// No description provided for @deviceSignedOut.
  ///
  /// In en, this message translates to:
  /// **'signed out'**
  String get deviceSignedOut;

  /// No description provided for @deviceUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get deviceUnnamed;

  /// No description provided for @deviceLastSeen.
  ///
  /// In en, this message translates to:
  /// **'active {age} ago'**
  String deviceLastSeen(String age);

  /// No description provided for @devicePlatformSteam.
  ///
  /// In en, this message translates to:
  /// **'Steam client'**
  String get devicePlatformSteam;

  /// No description provided for @devicePlatformWeb.
  ///
  /// In en, this message translates to:
  /// **'Web browser'**
  String get devicePlatformWeb;

  /// No description provided for @devicePlatformMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile app'**
  String get devicePlatformMobile;

  /// No description provided for @devicePlatformUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get devicePlatformUnknown;

  /// No description provided for @deviceAgeDays.
  ///
  /// In en, this message translates to:
  /// **'{n}d'**
  String deviceAgeDays(int n);

  /// No description provided for @deviceAgeHours.
  ///
  /// In en, this message translates to:
  /// **'{n}h'**
  String deviceAgeHours(int n);

  /// No description provided for @deviceAgeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n}m'**
  String deviceAgeMinutes(int n);

  /// No description provided for @deviceAgeNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get deviceAgeNow;

  /// No description provided for @keyRedeemAction.
  ///
  /// In en, this message translates to:
  /// **'Redeem key'**
  String get keyRedeemAction;

  /// No description provided for @keyRedeemTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem a Steam key'**
  String get keyRedeemTitle;

  /// No description provided for @keyRedeemFor.
  ///
  /// In en, this message translates to:
  /// **'Activating on {account}'**
  String keyRedeemFor(String account);

  /// No description provided for @keyRedeemHint.
  ///
  /// In en, this message translates to:
  /// **'XXXXX-XXXXX-XXXXX'**
  String get keyRedeemHint;

  /// No description provided for @keyRedeemPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get keyRedeemPaste;

  /// No description provided for @keyRedeemSubmit.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get keyRedeemSubmit;

  /// No description provided for @keyRedeemNote.
  ///
  /// In en, this message translates to:
  /// **'Activation is permanent and adds the product to this account. Steam blocks activations for about an hour after a few rejected keys, so check the code before submitting.'**
  String get keyRedeemNote;

  /// No description provided for @keyRedeemConfirm.
  ///
  /// In en, this message translates to:
  /// **'Activate this key on {account}? It can\'t be undone or moved to another account afterwards.'**
  String keyRedeemConfirm(String account);

  /// No description provided for @keyRedeemDone.
  ///
  /// In en, this message translates to:
  /// **'Key activated.'**
  String get keyRedeemDone;

  /// No description provided for @keyRedeemGranted.
  ///
  /// In en, this message translates to:
  /// **'Added to the library:'**
  String get keyRedeemGranted;

  /// No description provided for @keyRedeemNoProducts.
  ///
  /// In en, this message translates to:
  /// **'Steam accepted the key but didn\'t name the product. Check the account\'s library.'**
  String get keyRedeemNoProducts;

  /// No description provided for @keyRedeemNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Steam. If the request timed out, Steam may still have processed it — check the account\'s library before trying the key again.'**
  String get keyRedeemNetworkError;

  /// No description provided for @keyErrInvalid.
  ///
  /// In en, this message translates to:
  /// **'Steam doesn\'t recognize this code. Check it for typos — letters and digits like 0/O and 1/I are easy to mix up.'**
  String get keyErrInvalid;

  /// No description provided for @keyErrAlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'This account already owns the product.'**
  String get keyErrAlreadyOwned;

  /// No description provided for @keyErrAlreadyActivated.
  ///
  /// In en, this message translates to:
  /// **'This key has already been used — on this account or another one.'**
  String get keyErrAlreadyActivated;

  /// No description provided for @keyErrRegionLocked.
  ///
  /// In en, this message translates to:
  /// **'This product can\'t be activated in the account\'s country.'**
  String get keyErrRegionLocked;

  /// No description provided for @keyErrNeedsBaseProduct.
  ///
  /// In en, this message translates to:
  /// **'This is DLC or an expansion; the account needs the base game first.'**
  String get keyErrNeedsBaseProduct;

  /// No description provided for @keyErrNeedsPs3Login.
  ///
  /// In en, this message translates to:
  /// **'This product has to be played on a PlayStation®3 system before it can be activated.'**
  String get keyErrNeedsPs3Login;

  /// No description provided for @keyErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many rejected keys recently. Steam blocks activations for about an hour — try again later.'**
  String get keyErrRateLimited;

  /// No description provided for @keyErrUnknown.
  ///
  /// In en, this message translates to:
  /// **'Steam rejected the key (code {code}).'**
  String keyErrUnknown(int code);

  /// No description provided for @loginOrApprove.
  ///
  /// In en, this message translates to:
  /// **'…or just tap “Allow” in your Steam mobile app.'**
  String get loginOrApprove;

  /// No description provided for @addErrPresent.
  ///
  /// In en, this message translates to:
  /// **'This account already has an authenticator.'**
  String get addErrPresent;

  /// No description provided for @addErrConfirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Please confirm the email Steam sent, then retry.'**
  String get addErrConfirmEmail;

  /// No description provided for @addErrLocked.
  ///
  /// In en, this message translates to:
  /// **'This account is locked/restricted by Steam — recover it at help.steampowered.com before adding an authenticator.'**
  String get addErrLocked;

  /// No description provided for @addErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a while and try again.'**
  String get addErrRateLimited;

  /// No description provided for @addErrFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add authenticator.'**
  String get addErrFailed;

  /// No description provided for @addErrSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the authenticator to this device, so setup was stopped before it took effect. Write down this revocation code and remove the pending authenticator from your account, then try again: {code}'**
  String addErrSaveFailed(String code);

  /// No description provided for @addErrBadSms.
  ///
  /// In en, this message translates to:
  /// **'Wrong SMS code, please try again.'**
  String get addErrBadSms;

  /// No description provided for @debugLog.
  ///
  /// In en, this message translates to:
  /// **'Debug log'**
  String get debugLog;

  /// No description provided for @debugLogDesc.
  ///
  /// In en, this message translates to:
  /// **'Network trace for diagnosing login / confirmations'**
  String get debugLogDesc;

  /// No description provided for @feedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedbackTitle;

  /// No description provided for @feedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Found a bug or have an idea? Send it straight to the developer, or open a GitHub issue for public discussion.'**
  String get feedbackDesc;

  /// No description provided for @feedbackSend.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get feedbackSend;

  /// No description provided for @feedbackMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Your feedback'**
  String get feedbackMessageLabel;

  /// No description provided for @feedbackMessageHint.
  ///
  /// In en, this message translates to:
  /// **'What broke / what would you like?'**
  String get feedbackMessageHint;

  /// No description provided for @feedbackContactLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact (optional)'**
  String get feedbackContactLabel;

  /// No description provided for @feedbackContactHint.
  ///
  /// In en, this message translates to:
  /// **'Email or username — only if you want a reply'**
  String get feedbackContactHint;

  /// No description provided for @feedbackAttachNote.
  ///
  /// In en, this message translates to:
  /// **'Sent along with your message: {meta}'**
  String feedbackAttachNote(String meta);

  /// No description provided for @feedbackSent.
  ///
  /// In en, this message translates to:
  /// **'Feedback sent — thank you!'**
  String get feedbackSent;

  /// No description provided for @feedbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Check your network and try again.'**
  String get feedbackFailed;

  /// No description provided for @feedbackRefused.
  ///
  /// In en, this message translates to:
  /// **'The relay refused this report: {reason}'**
  String feedbackRefused(String reason);

  /// No description provided for @feedbackRelayDown.
  ///
  /// In en, this message translates to:
  /// **'The feedback service is having trouble on its end ({reason}). Your network is fine — please try again later.'**
  String feedbackRelayDown(String reason);

  /// No description provided for @feedbackAttachLog.
  ///
  /// In en, this message translates to:
  /// **'Attach debug log'**
  String get feedbackAttachLog;

  /// No description provided for @feedbackAttachLogHint.
  ///
  /// In en, this message translates to:
  /// **'Recent network trace; may include account names / SteamIDs'**
  String get feedbackAttachLogHint;

  /// No description provided for @feedbackLogConsentBody.
  ///
  /// In en, this message translates to:
  /// **'The debug log contains recent network-trace lines from this session. It may include your account names and SteamIDs — never your secrets, tokens or passwords. It is sent only together with this report, as described in the Privacy Policy.'**
  String get feedbackLogConsentBody;

  /// No description provided for @feedbackLogConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get feedbackLogConsentAgree;

  /// No description provided for @backupReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your secrets'**
  String get backupReminderTitle;

  /// No description provided for @backupReminderBody.
  ///
  /// In en, this message translates to:
  /// **'GooeSteamKit keeps your authenticator data on this device only. Back up your maFiles somewhere safe. Your revocation code (R-code) is shown only once, when you first add an authenticator — write it down and keep it then; it is your last resort for removing the authenticator if this device is ever lost.'**
  String get backupReminderBody;

  /// No description provided for @backupReminderOk.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get backupReminderOk;

  /// No description provided for @debugCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get debugCopyAll;

  /// No description provided for @debugCopied.
  ///
  /// In en, this message translates to:
  /// **'Log copied'**
  String get debugCopied;

  /// No description provided for @debugEmpty.
  ///
  /// In en, this message translates to:
  /// **'No log yet.'**
  String get debugEmpty;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @addErrFinalize.
  ///
  /// In en, this message translates to:
  /// **'Finalize failed: {detail}'**
  String addErrFinalize(String detail);

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to Steam'**
  String get loginTitle;

  /// No description provided for @loginUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get loginUsername;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get loginHidePassword;

  /// No description provided for @loginSavePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get loginSavePassword;

  /// No description provided for @loginSavePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Kept in this account\'s maFile for automatic session refresh; an unencrypted export will contain it.'**
  String get loginSavePasswordHint;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButton;

  /// No description provided for @loginErrInvalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong account name or password.'**
  String get loginErrInvalidPassword;

  /// No description provided for @loginErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts — please wait a while and try again.'**
  String get loginErrRateLimited;

  /// No description provided for @loginErrCodeMismatch.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t match — check it and try again.'**
  String get loginErrCodeMismatch;

  /// No description provided for @loginViaQr.
  ///
  /// In en, this message translates to:
  /// **'Log in with QR code'**
  String get loginViaQr;

  /// No description provided for @loginViaCredentials.
  ///
  /// In en, this message translates to:
  /// **'Log in with password'**
  String get loginViaCredentials;

  /// No description provided for @loginScanWithApp.
  ///
  /// In en, this message translates to:
  /// **'Scan this code with the Steam mobile app'**
  String get loginScanWithApp;

  /// No description provided for @loginNeedGuardCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the Steam Guard code'**
  String get loginNeedGuardCode;

  /// No description provided for @loginNeedEmailCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to your email'**
  String get loginNeedEmailCode;

  /// No description provided for @loginSubmitCode.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get loginSubmitCode;

  /// No description provided for @loginWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation…'**
  String get loginWaiting;

  /// No description provided for @loginStepCredentials.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get loginStepCredentials;

  /// No description provided for @loginStepConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get loginStepConfirm;

  /// No description provided for @loginStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get loginStepDone;

  /// No description provided for @loginWaitingDesc.
  ///
  /// In en, this message translates to:
  /// **'Approve this sign in on the Steam mobile app. You can also use an email code or QR sign-in.'**
  String get loginWaitingDesc;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String loginFailed(String error);

  /// No description provided for @approveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve sign in'**
  String get approveTitle;

  /// No description provided for @approveScanPrompt.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code shown on the device you want to sign in.'**
  String get approveScanPrompt;

  /// No description provided for @approvePastePrompt.
  ///
  /// In en, this message translates to:
  /// **'Or paste the QR code link here'**
  String get approvePastePrompt;

  /// No description provided for @approveButton.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approveButton;

  /// No description provided for @approveReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get approveReject;

  /// No description provided for @approveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sign in approved.'**
  String get approveSuccess;

  /// No description provided for @approveRejected.
  ///
  /// In en, this message translates to:
  /// **'Sign in rejected.'**
  String get approveRejected;

  /// No description provided for @approveBadCode.
  ///
  /// In en, this message translates to:
  /// **'That\'s not a Steam sign-in QR code.'**
  String get approveBadCode;

  /// No description provided for @approveLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get approveLocation;

  /// No description provided for @approveDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get approveDevice;

  /// No description provided for @approveWarnStranger.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t start this sign-in yourself? Reject it.'**
  String get approveWarnStranger;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import account'**
  String get importTitle;

  /// No description provided for @importPickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a .maFile'**
  String get importPickFile;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account imported.'**
  String get importSuccess;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import: {error}'**
  String importFailed(String error);

  /// No description provided for @importDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Account already exists'**
  String get importDuplicateTitle;

  /// No description provided for @importDuplicateBody.
  ///
  /// In en, this message translates to:
  /// **'This maFile is for {name}, which is already on this device. Overwrite the stored account with the imported file? Its cached avatar, saved password, and existing session are kept when the file doesn\'t include them.'**
  String importDuplicateBody(String name);

  /// No description provided for @importDuplicateBodyUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This maFile is for {name}, which exists on this device but its stored data can no longer be read. Importing will replace it entirely.'**
  String importDuplicateBodyUnreadable(String name);

  /// No description provided for @importDuplicateOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get importDuplicateOverwrite;

  /// No description provided for @importSessionDeadTitle.
  ///
  /// In en, this message translates to:
  /// **'Activate this account?'**
  String get importSessionDeadTitle;

  /// No description provided for @importSessionDeadBody.
  ///
  /// In en, this message translates to:
  /// **'The Steam session in this maFile has expired. Sign in now to enable confirmations and login approvals — the Steam Guard code will be filled in automatically.'**
  String get importSessionDeadBody;

  /// No description provided for @importSessionLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get importSessionLater;

  /// No description provided for @sdaImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import an SDA folder'**
  String get sdaImportAction;

  /// No description provided for @sdaImportHint.
  ///
  /// In en, this message translates to:
  /// **'Select .maFile files to import in bulk. manifest.json is optional for unencrypted files. For encrypted SDA files, select manifest.json too; it contains the decryption parameters.'**
  String get sdaImportHint;

  /// No description provided for @sdaImportNoManifest.
  ///
  /// In en, this message translates to:
  /// **'No manifest.json in that selection. Select it together with the .maFile files.'**
  String get sdaImportNoManifest;

  /// No description provided for @sdaImportBadManifest.
  ///
  /// In en, this message translates to:
  /// **'That manifest.json can\'t be read: {error}'**
  String sdaImportBadManifest(String error);

  /// No description provided for @sdaImportPassTitle.
  ///
  /// In en, this message translates to:
  /// **'SDA encryption passphrase'**
  String get sdaImportPassTitle;

  /// No description provided for @sdaImportPassBody.
  ///
  /// In en, this message translates to:
  /// **'These maFiles are encrypted. Enter the passphrase you set in Steam Desktop Authenticator.'**
  String get sdaImportPassBody;

  /// No description provided for @sdaImportWrongPass.
  ///
  /// In en, this message translates to:
  /// **'That passphrase didn\'t decrypt any of the files.'**
  String get sdaImportWrongPass;

  /// No description provided for @sdaImportDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 account imported.} other{{count} accounts imported.}}'**
  String sdaImportDone(int count);

  /// No description provided for @sdaImportSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 account was skipped: {names}} other{{count} accounts were skipped: {names}}}'**
  String sdaImportSkipped(int count, String names);

  /// No description provided for @sdaImportNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing was imported.'**
  String get sdaImportNothing;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get updateView;

  /// No description provided for @updateDismiss.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get updateDismiss;

  /// No description provided for @settingsUpdateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates on launch'**
  String get settingsUpdateCheck;

  /// No description provided for @settingsUpdateCheckDesc.
  ///
  /// In en, this message translates to:
  /// **'One request to the version endpoint per launch. No account data; the endpoint keeps no logs.'**
  String get settingsUpdateCheckDesc;

  /// No description provided for @importSessionLoginNow.
  ///
  /// In en, this message translates to:
  /// **'Sign in now'**
  String get importSessionLoginNow;

  /// No description provided for @actionExport.
  ///
  /// In en, this message translates to:
  /// **'Export maFile'**
  String get actionExport;

  /// No description provided for @actionLoginRequests.
  ///
  /// In en, this message translates to:
  /// **'Sign-in requests'**
  String get actionLoginRequests;

  /// No description provided for @loginRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve sign-in?'**
  String get loginRequestTitle;

  /// No description provided for @loginRequestBody.
  ///
  /// In en, this message translates to:
  /// **'{device} is signing in to your Steam account from {location}.'**
  String loginRequestBody(String device, String location);

  /// No description provided for @loginRequestApprove.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get loginRequestApprove;

  /// No description provided for @loginRequestDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get loginRequestDeny;

  /// No description provided for @loginNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending sign-in requests.'**
  String get loginNoPending;

  /// No description provided for @loginNeedSession.
  ///
  /// In en, this message translates to:
  /// **'Sign in to refresh this account\'s session first.'**
  String get loginNeedSession;

  /// No description provided for @loginApproved.
  ///
  /// In en, this message translates to:
  /// **'Sign-in allowed.'**
  String get loginApproved;

  /// No description provided for @loginDenied.
  ///
  /// In en, this message translates to:
  /// **'Sign-in denied.'**
  String get loginDenied;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export: {error}'**
  String exportFailed(String error);

  /// No description provided for @exportWarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Export unencrypted maFile?'**
  String get exportWarnTitle;

  /// No description provided for @exportWarnBody.
  ///
  /// In en, this message translates to:
  /// **'The exported .maFile is NOT encrypted. It holds this account’s Steam Guard secrets and revocation code — anyone with the file can take over your authenticator. Store it somewhere safe and delete it when done.'**
  String get exportWarnBody;

  /// No description provided for @exportIncludePassword.
  ///
  /// In en, this message translates to:
  /// **'Also include the saved Steam password (not recommended)'**
  String get exportIncludePassword;

  /// No description provided for @addAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Add authenticator'**
  String get addAuthTitle;

  /// No description provided for @addAuthPhonePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number (with country code)'**
  String get addAuthPhonePrompt;

  /// No description provided for @addAuthSmsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the SMS code sent to your phone'**
  String get addAuthSmsPrompt;

  /// No description provided for @addAuthEmailPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the activation code Steam emailed you'**
  String get addAuthEmailPrompt;

  /// No description provided for @addAuthRevocationWarn.
  ///
  /// In en, this message translates to:
  /// **'Write down your revocation code: {code}'**
  String addAuthRevocationWarn(String code);

  /// No description provided for @addAuthConfirmRevocation.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your revocation code to confirm you saved it'**
  String get addAuthConfirmRevocation;

  /// No description provided for @addAuthLinked.
  ///
  /// In en, this message translates to:
  /// **'Authenticator linked successfully.'**
  String get addAuthLinked;

  /// No description provided for @addAuthStepPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get addAuthStepPhone;

  /// No description provided for @addAuthStepSms.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get addAuthStepSms;

  /// No description provided for @addAuthStepRevocation.
  ///
  /// In en, this message translates to:
  /// **'Revocation'**
  String get addAuthStepRevocation;

  /// No description provided for @addPresentTitle.
  ///
  /// In en, this message translates to:
  /// **'This account already has an authenticator'**
  String get addPresentTitle;

  /// No description provided for @addPresentIntro.
  ///
  /// In en, this message translates to:
  /// **'Steam allows only one mobile authenticator per account. Remove the existing one, then tap Retry.'**
  String get addPresentIntro;

  /// No description provided for @addPresentStep1.
  ///
  /// In en, this message translates to:
  /// **'Still have the old phone or Steam app? Open it → Steam Guard → Remove Authenticator.'**
  String get addPresentStep1;

  /// No description provided for @addPresentStep2.
  ///
  /// In en, this message translates to:
  /// **'Have your revocation code (Rxxxxx)? Open the page below and choose “Remove Authenticator”.'**
  String get addPresentStep2;

  /// No description provided for @addPresentStep3.
  ///
  /// In en, this message translates to:
  /// **'Lost access to both? Use Steam Support → Help → Steam Guard Mobile Authenticator.'**
  String get addPresentStep3;

  /// No description provided for @addPresentManageUrl.
  ///
  /// In en, this message translates to:
  /// **'store.steampowered.com/twofactor/manage'**
  String get addPresentManageUrl;

  /// No description provided for @addPresentCopiedUrl.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get addPresentCopiedUrl;

  /// No description provided for @addPresentFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t receive the email?'**
  String get addPresentFallbackTitle;

  /// No description provided for @addMoveInButton.
  ///
  /// In en, this message translates to:
  /// **'Move the authenticator to this device'**
  String get addMoveInButton;

  /// No description provided for @addMoveInBlurb.
  ///
  /// In en, this message translates to:
  /// **'Steam will email this account a code. No 15-day trade hold.'**
  String get addMoveInBlurb;

  /// No description provided for @addMoveInSending.
  ///
  /// In en, this message translates to:
  /// **'Sending the code…'**
  String get addMoveInSending;

  /// No description provided for @addMoveInCodePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the code Steam emailed you'**
  String get addMoveInCodePrompt;

  /// No description provided for @addMoveInWarn.
  ///
  /// In en, this message translates to:
  /// **'Once you confirm: the authenticator on your old phone stops working immediately, and your old revocation code (Rxxxxx) is replaced by a new one. This cannot be undone.'**
  String get addMoveInWarn;

  /// No description provided for @addMoveInConfirm.
  ///
  /// In en, this message translates to:
  /// **'Move it here'**
  String get addMoveInConfirm;

  /// No description provided for @addMoveInDone.
  ///
  /// In en, this message translates to:
  /// **'Authenticator moved to this device.'**
  String get addMoveInDone;

  /// No description provided for @addMoveInPopBlocked.
  ///
  /// In en, this message translates to:
  /// **'Moving the authenticator — please wait.'**
  String get addMoveInPopBlocked;

  /// No description provided for @addErrBadChallengeCode.
  ///
  /// In en, this message translates to:
  /// **'That code isn\'t right. Check the email and try again.'**
  String get addErrBadChallengeCode;

  /// No description provided for @addMoveInSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The authenticator moved to this account, but GooeSteamKit could NOT save it to this device. Your old authenticator is already dead, so these are the only copies — write them down NOW before closing this screen.\n\nRevocation code: {code}\n\nSecret: {secret}'**
  String addMoveInSaveFailed(String code, String secret);

  /// No description provided for @addMoveInCopySecrets.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get addMoveInCopySecrets;

  /// No description provided for @addMoveInCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get addMoveInCopied;

  /// No description provided for @moveInRescueDismiss.
  ///
  /// In en, this message translates to:
  /// **'I saved them — dismiss'**
  String get moveInRescueDismiss;

  /// No description provided for @moveInRescueDismissTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard these secrets?'**
  String get moveInRescueDismissTitle;

  /// No description provided for @moveInRescueDismissBody.
  ///
  /// In en, this message translates to:
  /// **'GooeSteamKit holds no other copy. If you haven\'t written down the revocation code and secret, you will permanently lose access to this authenticator.'**
  String get moveInRescueDismissBody;

  /// No description provided for @moveInRescueDismissConfirm.
  ///
  /// In en, this message translates to:
  /// **'I saved them'**
  String get moveInRescueDismissConfirm;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get commonCopy;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get commonExport;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @settingsEncryption.
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get settingsEncryption;

  /// No description provided for @settingsEncryptionDesc.
  ///
  /// In en, this message translates to:
  /// **'Your local maFiles are encrypted with a random 256-bit key (AES-256-GCM) held in the device Keystore; your 6-digit PIN unlocks it.'**
  String get settingsEncryptionDesc;

  /// No description provided for @settingsThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Switch the whole UI style.'**
  String get settingsThemeDesc;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceDesc.
  ///
  /// In en, this message translates to:
  /// **'Light or dark for the standard look. A skin overrides this while active.'**
  String get settingsAppearanceDesc;

  /// No description provided for @settingsTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsTextSize;

  /// No description provided for @settingsTextSizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Applies on top of the system font size.'**
  String get settingsTextSizeDesc;

  /// No description provided for @textSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get textSizeSmall;

  /// No description provided for @textSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get textSizeMedium;

  /// No description provided for @textSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get textSizeLarge;

  /// No description provided for @settingsSkin.
  ///
  /// In en, this message translates to:
  /// **'Skins'**
  String get settingsSkin;

  /// No description provided for @settingsSkinDesc.
  ///
  /// In en, this message translates to:
  /// **'Full-styled looks with their own fonts and effects.'**
  String get settingsSkinDesc;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @skinNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get skinNone;

  /// No description provided for @settingsChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get settingsChange;

  /// No description provided for @settingsSetPasskey.
  ///
  /// In en, this message translates to:
  /// **'Set / change encryption passkey'**
  String get settingsSetPasskey;

  /// No description provided for @settingsAutoConfirmMarket.
  ///
  /// In en, this message translates to:
  /// **'Auto-confirm market transactions'**
  String get settingsAutoConfirmMarket;

  /// No description provided for @settingsAutoConfirmMarketDesc.
  ///
  /// In en, this message translates to:
  /// **'Pre-ticks the confirm box when you list an item, so a new listing is confirmed right after it\'s created. It never confirms anything in the background.'**
  String get settingsAutoConfirmMarketDesc;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeNeon.
  ///
  /// In en, this message translates to:
  /// **'Neon'**
  String get themeNeon;

  /// No description provided for @themePixel.
  ///
  /// In en, this message translates to:
  /// **'Pixel'**
  String get themePixel;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'An open-source Steam Guard authenticator, built with Flutter.'**
  String get aboutTagline;

  /// No description provided for @aboutSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get aboutSourceCode;

  /// No description provided for @aboutAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get aboutAuthor;

  /// No description provided for @aboutLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get aboutLicense;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacy;

  /// No description provided for @privacyConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Your privacy'**
  String get privacyConsentTitle;

  /// No description provided for @privacyConsentBody.
  ///
  /// In en, this message translates to:
  /// **'AVA keeps your Steam accounts and secrets on this device — they are never uploaded, unless you set up the optional sync to a server you choose, where everything is encrypted on this device first. There is no account to create. Steam requests go straight to Valve. Two of the developer\'s own services are contacted only when they are needed: Pro entitlement checks, and feedback (only when you press send). The Play version also shows ads on the free tier. There is no tracking or analytics. All of it is spelled out in the Privacy Policy — by continuing, you accept it.'**
  String get privacyConsentBody;

  /// No description provided for @privacyUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy updated'**
  String get privacyUpdateTitle;

  /// No description provided for @privacyUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'The privacy notice has changed since you accepted it. New: GooeSteamKit can now sync your account library between your devices, through a server you choose — off by default, everything encrypted on this device before upload, and the developer runs no sync server. Please read the current notice below.'**
  String get privacyUpdateBody;

  /// No description provided for @privacyConsentScrollHint.
  ///
  /// In en, this message translates to:
  /// **'Scroll to the end to continue'**
  String get privacyConsentScrollHint;

  /// No description provided for @privacyConsentRead.
  ///
  /// In en, this message translates to:
  /// **'Read the full Privacy Policy'**
  String get privacyConsentRead;

  /// No description provided for @privacyConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'Agree & continue'**
  String get privacyConsentAgree;

  /// No description provided for @privacyConsentExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get privacyConsentExit;

  /// No description provided for @actionMarket.
  ///
  /// In en, this message translates to:
  /// **'Inventory / Market'**
  String get actionMarket;

  /// No description provided for @marketTabInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get marketTabInventory;

  /// No description provided for @marketTabListings.
  ///
  /// In en, this message translates to:
  /// **'My listings'**
  String get marketTabListings;

  /// No description provided for @marketSelectGame.
  ///
  /// In en, this message translates to:
  /// **'Select a game'**
  String get marketSelectGame;

  /// No description provided for @marketNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items in this inventory.'**
  String get marketNoItems;

  /// No description provided for @marketNotMarketable.
  ///
  /// In en, this message translates to:
  /// **'Not marketable'**
  String get marketNotMarketable;

  /// No description provided for @marketSellTitle.
  ///
  /// In en, this message translates to:
  /// **'List for sale'**
  String get marketSellTitle;

  /// No description provided for @marketYouReceive.
  ///
  /// In en, this message translates to:
  /// **'You receive'**
  String get marketYouReceive;

  /// No description provided for @marketBuyerPays.
  ///
  /// In en, this message translates to:
  /// **'Buyer pays'**
  String get marketBuyerPays;

  /// No description provided for @marketLowest.
  ///
  /// In en, this message translates to:
  /// **'Lowest'**
  String get marketLowest;

  /// No description provided for @marketMedian.
  ///
  /// In en, this message translates to:
  /// **'Median'**
  String get marketMedian;

  /// No description provided for @marketHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get marketHigh;

  /// No description provided for @marketLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get marketLow;

  /// No description provided for @marketPriceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Market price unavailable'**
  String get marketPriceUnavailable;

  /// No description provided for @marketListButton.
  ///
  /// In en, this message translates to:
  /// **'List for sale'**
  String get marketListButton;

  /// No description provided for @marketListed.
  ///
  /// In en, this message translates to:
  /// **'Listed — confirm it to finish.'**
  String get marketListed;

  /// No description provided for @marketListedDone.
  ///
  /// In en, this message translates to:
  /// **'Listed and confirmed.'**
  String get marketListedDone;

  /// No description provided for @marketListedPartial.
  ///
  /// In en, this message translates to:
  /// **'Listed {listed} of {total} — the rest failed; confirm any pending in Confirmations.'**
  String marketListedPartial(int listed, int total);

  /// No description provided for @marketListedSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Listed {listed} of {total}, then the session expired — sign in again and confirm them.'**
  String marketListedSessionExpired(int listed, int total);

  /// No description provided for @marketConfirmPartial.
  ///
  /// In en, this message translates to:
  /// **'Listed — {ok} of {total} confirmed; finish the rest in Confirmations.'**
  String marketConfirmPartial(int ok, int total);

  /// No description provided for @marketAutoConfirm.
  ///
  /// In en, this message translates to:
  /// **'Auto-confirm the listing'**
  String get marketAutoConfirm;

  /// No description provided for @marketQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get marketQuantity;

  /// No description provided for @marketMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get marketMax;

  /// No description provided for @marketListFailed.
  ///
  /// In en, this message translates to:
  /// **'Listing failed: {error}'**
  String marketListFailed(String error);

  /// No description provided for @marketInvalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price.'**
  String get marketInvalidPrice;

  /// No description provided for @marketCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel listing'**
  String get marketCancel;

  /// No description provided for @marketCancelled.
  ///
  /// In en, this message translates to:
  /// **'Listing cancelled.'**
  String get marketCancelled;

  /// No description provided for @marketNoListings.
  ///
  /// In en, this message translates to:
  /// **'No active listings.'**
  String get marketNoListings;

  /// No description provided for @marketFeeNote.
  ///
  /// In en, this message translates to:
  /// **'Steam + game fees are added on top of what you receive.'**
  String get marketFeeNote;

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get aboutLicenses;

  /// No description provided for @aboutCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get aboutCredits;

  /// No description provided for @aboutCreditsBody.
  ///
  /// In en, this message translates to:
  /// **'Inspired by Steam Desktop Authenticator and compatible with its maFile format. Independently built with Flutter, Riverpod, Dio, PointyCastle, mobile_scanner, image and other open-source libraries.'**
  String get aboutCreditsBody;

  /// No description provided for @actionLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in / refresh session'**
  String get actionLogin;

  /// No description provided for @actionConfirmations.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get actionConfirmations;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove account'**
  String get actionRemove;

  /// No description provided for @actionImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get actionImport;

  /// No description provided for @actionAddAuthenticator.
  ///
  /// In en, this message translates to:
  /// **'Add authenticator'**
  String get actionAddAuthenticator;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your Steam session has expired. Please log in again.'**
  String get sessionExpired;

  /// No description provided for @removeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this account from this device? Make sure you have your maFile backed up.'**
  String get removeConfirm;

  /// No description provided for @settingsPro.
  ///
  /// In en, this message translates to:
  /// **'AVA Pro'**
  String get settingsPro;

  /// No description provided for @proOpen.
  ///
  /// In en, this message translates to:
  /// **'View AVA Pro'**
  String get proOpen;

  /// No description provided for @proStatusFree.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get proStatusFree;

  /// No description provided for @proStatusPro.
  ///
  /// In en, this message translates to:
  /// **'Pro · until {date}'**
  String proStatusPro(Object date);

  /// No description provided for @proStatusVip.
  ///
  /// In en, this message translates to:
  /// **'VIP · until {date}'**
  String proStatusVip(Object date);

  /// No description provided for @proStatusLifetime.
  ///
  /// In en, this message translates to:
  /// **'Pro · lifetime'**
  String get proStatusLifetime;

  /// No description provided for @proStatusActivations.
  ///
  /// In en, this message translates to:
  /// **'Active on: {classes}'**
  String proStatusActivations(Object classes);

  /// No description provided for @proStatusClassThisDevice.
  ///
  /// In en, this message translates to:
  /// **'{name} (this device)'**
  String proStatusClassThisDevice(Object name);

  /// No description provided for @proDeviceClassAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android'**
  String get proDeviceClassAndroid;

  /// No description provided for @proDeviceClassWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get proDeviceClassWindows;

  /// No description provided for @proDeviceClassLinux.
  ///
  /// In en, this message translates to:
  /// **'Linux'**
  String get proDeviceClassLinux;

  /// No description provided for @proDeviceClassMacos.
  ///
  /// In en, this message translates to:
  /// **'macOS'**
  String get proDeviceClassMacos;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'AVA Pro'**
  String get paywallTitle;

  /// No description provided for @paywallPerksTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro perks — core security features stay free forever.'**
  String get paywallPerksTitle;

  /// No description provided for @paywallPerkSkins.
  ///
  /// In en, this message translates to:
  /// **'Theme packs: Neon & Pixel skins'**
  String get paywallPerkSkins;

  /// No description provided for @paywallPerkNoAds.
  ///
  /// In en, this message translates to:
  /// **'No banner ads'**
  String get paywallPerkNoAds;

  /// No description provided for @paywallPerkFuture.
  ///
  /// In en, this message translates to:
  /// **'Coming later: cloud sync, trade notifications'**
  String get paywallPerkFuture;

  /// No description provided for @paywallPlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock via Google Play'**
  String get paywallPlayTitle;

  /// No description provided for @paywallSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe · \$0.99/mo'**
  String get paywallSubscribe;

  /// No description provided for @paywallWatchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad · 3-day VIP'**
  String get paywallWatchAd;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get paywallRestore;

  /// No description provided for @paywallCnTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock via Afdian'**
  String get paywallCnTitle;

  /// No description provided for @paywallAfdianIntro.
  ///
  /// In en, this message translates to:
  /// **'Sponsor ¥5/month on Afdian, then enter the order number here to unlock.'**
  String get paywallAfdianIntro;

  /// No description provided for @paywallOpenAfdian.
  ///
  /// In en, this message translates to:
  /// **'Open Afdian'**
  String get paywallOpenAfdian;

  /// No description provided for @paywallOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Afdian order number'**
  String get paywallOrderHint;

  /// No description provided for @paywallRedeem.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get paywallRedeem;

  /// No description provided for @paywallBetaTitle.
  ///
  /// In en, this message translates to:
  /// **'Beta thank-you'**
  String get paywallBetaTitle;

  /// No description provided for @paywallBetaIntro.
  ///
  /// In en, this message translates to:
  /// **'Beta testers get lifetime Pro — enter your code.'**
  String get paywallBetaIntro;

  /// No description provided for @paywallBetaHint.
  ///
  /// In en, this message translates to:
  /// **'Lifetime code'**
  String get paywallBetaHint;

  /// No description provided for @paywallBetaRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get paywallBetaRedeem;

  /// No description provided for @proResultSuccess.
  ///
  /// In en, this message translates to:
  /// **'Unlocked — thank you!'**
  String get proResultSuccess;

  /// No description provided for @proErrCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled.'**
  String get proErrCanceled;

  /// No description provided for @proErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error — try again later.'**
  String get proErrNetwork;

  /// No description provided for @proErrNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not available in this build yet.'**
  String get proErrNotConfigured;

  /// No description provided for @proErrNoSubscription.
  ///
  /// In en, this message translates to:
  /// **'No active subscription on your Play Store\'s current account. Subscribed with a different Google account? Switch to it in the Play Store app (top-right avatar), then retry.'**
  String get proErrNoSubscription;

  /// No description provided for @proErrAlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'Your Play Store\'s current account already holds this subscription — tap Restore purchase instead.'**
  String get proErrAlreadyOwned;

  /// No description provided for @proErrOrderBound.
  ///
  /// In en, this message translates to:
  /// **'This order is already bound to another user.'**
  String get proErrOrderBound;

  /// No description provided for @proErrOrderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found or plan mismatch.'**
  String get proErrOrderNotFound;

  /// No description provided for @proErrDeviceRevoked.
  ///
  /// In en, this message translates to:
  /// **'This device\'s slot was taken by a newer activation.'**
  String get proErrDeviceRevoked;

  /// No description provided for @proErrNoVip.
  ///
  /// In en, this message translates to:
  /// **'Reward not confirmed yet — try again in a minute.'**
  String get proErrNoVip;

  /// No description provided for @proErrPurchaseBound.
  ///
  /// In en, this message translates to:
  /// **'This subscription is tied to a different Google account. Retry, and in the account chooser pick the one your Play Store uses.'**
  String get proErrPurchaseBound;

  /// No description provided for @proErrPurchaseBoundKnown.
  ///
  /// In en, this message translates to:
  /// **'This subscription is tied to {account}. Retry, and pick that account in the chooser.'**
  String proErrPurchaseBoundKnown(String account);

  /// No description provided for @proErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed: {code}'**
  String proErrGeneric(Object code);

  /// No description provided for @proErrCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Code not recognized — check it for typos.'**
  String get proErrCodeInvalid;

  /// No description provided for @proErrCodeRedeemed.
  ///
  /// In en, this message translates to:
  /// **'This code is already active on another device. To move it here, email hi@dotslash.pro.'**
  String get proErrCodeRedeemed;

  /// No description provided for @proErrCodeActivationLimit.
  ///
  /// In en, this message translates to:
  /// **'This code has switched devices too often recently. Try again later, or email hi@dotslash.pro.'**
  String get proErrCodeActivationLimit;

  /// No description provided for @proErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get proErrRateLimited;

  /// No description provided for @proErrSlotOccupied.
  ///
  /// In en, this message translates to:
  /// **'In use: {slots}'**
  String proErrSlotOccupied(Object slots);

  /// No description provided for @proSlotEntry.
  ///
  /// In en, this message translates to:
  /// **'{name} ({time})'**
  String proSlotEntry(Object name, Object time);

  /// No description provided for @proSlotToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get proSlotToday;

  /// No description provided for @proSlotDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 day ago} other{{n} days ago}}'**
  String proSlotDaysAgo(int n);

  /// No description provided for @proErrRevoked.
  ///
  /// In en, this message translates to:
  /// **'This entitlement is no longer active. If you think this is a mistake, email hi@dotslash.pro.'**
  String get proErrRevoked;

  /// No description provided for @privacyOptions.
  ///
  /// In en, this message translates to:
  /// **'Privacy options'**
  String get privacyOptions;

  /// No description provided for @skinProNotice.
  ///
  /// In en, this message translates to:
  /// **'Neon & Pixel skins are now Pro perks. Your selection is kept and comes back with Pro.'**
  String get skinProNotice;

  /// No description provided for @skinProNoticeDismiss.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get skinProNoticeDismiss;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @syncSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up sync'**
  String get syncSetupTitle;

  /// No description provided for @syncSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep accounts in sync across devices through a server you control. Everything is encrypted before it leaves this device.'**
  String get syncSettingsDesc;

  /// No description provided for @syncSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up sync…'**
  String get syncSetUp;

  /// No description provided for @syncStatusOk.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get syncStatusOk;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusErrorShort.
  ///
  /// In en, this message translates to:
  /// **'Last sync failed — open for details.'**
  String get syncStatusErrorShort;

  /// No description provided for @syncStatusConflicts.
  ///
  /// In en, this message translates to:
  /// **'{count} conflict(s) need your decision'**
  String syncStatusConflicts(int count);

  /// No description provided for @syncLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {time}'**
  String syncLastSync(String time);

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get syncNever;

  /// No description provided for @syncBackendTitle.
  ///
  /// In en, this message translates to:
  /// **'Where should the data live?'**
  String get syncBackendTitle;

  /// No description provided for @syncBackendWebdav.
  ///
  /// In en, this message translates to:
  /// **'WebDAV'**
  String get syncBackendWebdav;

  /// No description provided for @syncBackendWebdavDesc.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud, Jianguoyun (坚果云), a NAS — any WebDAV folder you control.'**
  String get syncBackendWebdavDesc;

  /// No description provided for @syncBackendGdrive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get syncBackendGdrive;

  /// No description provided for @syncBackendGdriveSoon.
  ///
  /// In en, this message translates to:
  /// **'Pro · coming later'**
  String get syncBackendGdriveSoon;

  /// No description provided for @syncServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get syncServerTitle;

  /// No description provided for @syncServerHint.
  ///
  /// In en, this message translates to:
  /// **'Jianguoyun needs an app password (安全选项 → 添加应用密码), not your login password. A Nextcloud folder URL looks like https://cloud.example.com/remote.php/dav/files/USER/ava/.'**
  String get syncServerHint;

  /// No description provided for @syncServerUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'WebDAV folder URL'**
  String get syncServerUrlLabel;

  /// No description provided for @syncServerFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder (optional)'**
  String get syncServerFolderLabel;

  /// No description provided for @syncServerFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the URL as-is; a name places the library in that subfolder, created if missing.'**
  String get syncServerFolderHint;

  /// No description provided for @syncServerUserLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get syncServerUserLabel;

  /// No description provided for @syncServerPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password / app password'**
  String get syncServerPasswordLabel;

  /// No description provided for @syncTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get syncTestConnection;

  /// No description provided for @syncErrUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http(s) folder URL.'**
  String get syncErrUrl;

  /// No description provided for @syncErrAuth.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the username or password.'**
  String get syncErrAuth;

  /// No description provided for @syncErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server: {detail}'**
  String syncErrNetwork(String detail);

  /// No description provided for @syncErrServer.
  ///
  /// In en, this message translates to:
  /// **'The server answered with an error: {detail}'**
  String syncErrServer(String detail);

  /// No description provided for @syncErrTls.
  ///
  /// In en, this message translates to:
  /// **'The server\'s certificate is not trusted.'**
  String get syncErrTls;

  /// No description provided for @syncTlsTitle.
  ///
  /// In en, this message translates to:
  /// **'Unknown server certificate'**
  String get syncTlsTitle;

  /// No description provided for @syncTlsBody.
  ///
  /// In en, this message translates to:
  /// **'This server\'s certificate is not trusted by the system. If it is your own server with a self-signed certificate, compare this fingerprint with the one shown on the server, and only trust it if they match exactly.\n\nSHA-256\n{fp}'**
  String syncTlsBody(String fp);

  /// No description provided for @syncTlsTrust.
  ///
  /// In en, this message translates to:
  /// **'Trust this certificate'**
  String get syncTlsTrust;

  /// No description provided for @syncHttpPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Unencrypted connection'**
  String get syncHttpPrivateTitle;

  /// No description provided for @syncHttpPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'This is a plain-HTTP address on a private network. Your account data itself is encrypted end-to-end, but the server password travels unencrypted on your network.'**
  String get syncHttpPrivateBody;

  /// No description provided for @syncHttpPublicTitle.
  ///
  /// In en, this message translates to:
  /// **'Plain HTTP across the internet'**
  String get syncHttpPublicTitle;

  /// No description provided for @syncHttpPublicBody.
  ///
  /// In en, this message translates to:
  /// **'This address is public and the connection would be unencrypted: anyone between you and the server can read the server password and sign in to your server. The account data itself stays encrypted. Use HTTPS or a LAN address instead — continue only if you accept this risk.'**
  String get syncHttpPublicBody;

  /// No description provided for @syncHttpPublicHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to allow anyway'**
  String get syncHttpPublicHold;

  /// No description provided for @syncContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get syncContinue;

  /// No description provided for @syncPassphraseNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a sync passphrase'**
  String get syncPassphraseNewTitle;

  /// No description provided for @syncPassphraseNewBody.
  ///
  /// In en, this message translates to:
  /// **'Everything is encrypted with this passphrase before upload; the passphrase itself never leaves your devices.\n\nIf you lose it, the synced data cannot be recovered by anyone — there is no reset. At least 8 characters; length matters more than symbols.'**
  String get syncPassphraseNewBody;

  /// No description provided for @syncPassphraseExistingTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the sync passphrase'**
  String get syncPassphraseExistingTitle;

  /// No description provided for @syncPassphraseExistingBody.
  ///
  /// In en, this message translates to:
  /// **'This folder already holds a sync library with {count} account(s). Enter the passphrase it was created with.'**
  String syncPassphraseExistingBody(int count);

  /// No description provided for @syncPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync passphrase'**
  String get syncPassphraseLabel;

  /// No description provided for @syncPassphraseConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm passphrase'**
  String get syncPassphraseConfirmLabel;

  /// No description provided for @syncPassphraseTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get syncPassphraseTooShort;

  /// No description provided for @syncPassphraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passphrases don\'t match.'**
  String get syncPassphraseMismatch;

  /// No description provided for @syncPassphraseWrong.
  ///
  /// In en, this message translates to:
  /// **'That passphrase doesn\'t open this library.'**
  String get syncPassphraseWrong;

  /// No description provided for @syncPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'First sync'**
  String get syncPreviewTitle;

  /// No description provided for @syncPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to transfer yet — accounts will sync automatically from now on.'**
  String get syncPreviewEmpty;

  /// No description provided for @syncPreviewPull.
  ///
  /// In en, this message translates to:
  /// **'Download to this device: {count} account(s)'**
  String syncPreviewPull(int count);

  /// No description provided for @syncPreviewPush.
  ///
  /// In en, this message translates to:
  /// **'Upload from this device: {count} account(s)'**
  String syncPreviewPush(int count);

  /// No description provided for @syncPreviewConflict.
  ///
  /// In en, this message translates to:
  /// **'On both sides with different content: {count} — you\'ll choose per account after connecting'**
  String syncPreviewConflict(int count);

  /// No description provided for @syncStart.
  ///
  /// In en, this message translates to:
  /// **'Start syncing'**
  String get syncStart;

  /// No description provided for @syncDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync is on'**
  String get syncDoneTitle;

  /// No description provided for @syncDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Accounts now sync automatically. On a new device each account signs in again the first time you use it — accounts with a saved password do that by themselves; the others ask once.'**
  String get syncDoneBody;

  /// No description provided for @syncDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get syncDone;

  /// No description provided for @syncNeedsPassphrase.
  ///
  /// In en, this message translates to:
  /// **'The stored passphrase no longer matches the remote library — enter it again.'**
  String get syncNeedsPassphrase;

  /// No description provided for @syncEnterPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Enter passphrase'**
  String get syncEnterPassphrase;

  /// No description provided for @syncConditionalWarn.
  ///
  /// In en, this message translates to:
  /// **'This server ignores conditional writes, so two devices syncing at the same moment may overwrite each other. Syncing still works; avoid simultaneous changes on two devices.'**
  String get syncConditionalWarn;

  /// No description provided for @syncConflictsTitle.
  ///
  /// In en, this message translates to:
  /// **'Conflicts'**
  String get syncConflictsTitle;

  /// No description provided for @syncConflictTrashNote.
  ///
  /// In en, this message translates to:
  /// **'Whichever side you discard is kept in the sync trash for 30 days.'**
  String get syncConflictTrashNote;

  /// No description provided for @syncConflictEditEdit.
  ///
  /// In en, this message translates to:
  /// **'Changed on both devices'**
  String get syncConflictEditEdit;

  /// No description provided for @syncConflictEditDelete.
  ///
  /// In en, this message translates to:
  /// **'Changed here, deleted on another device'**
  String get syncConflictEditDelete;

  /// No description provided for @syncConflictDeleteEdit.
  ///
  /// In en, this message translates to:
  /// **'Deleted here, changed on another device'**
  String get syncConflictDeleteEdit;

  /// No description provided for @syncConflictKeepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep this device\'s'**
  String get syncConflictKeepLocal;

  /// No description provided for @syncConflictKeepRemote.
  ///
  /// In en, this message translates to:
  /// **'Keep the other\'s'**
  String get syncConflictKeepRemote;

  /// No description provided for @syncConflictLocalSide.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get syncConflictLocalSide;

  /// No description provided for @syncConflictRemoteSide.
  ///
  /// In en, this message translates to:
  /// **'Other device'**
  String get syncConflictRemoteSide;

  /// No description provided for @syncDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get syncDeleted;

  /// No description provided for @syncConflictHasPassword.
  ///
  /// In en, this message translates to:
  /// **'Password saved'**
  String get syncConflictHasPassword;

  /// No description provided for @syncConflictNoPassword.
  ///
  /// In en, this message translates to:
  /// **'No saved password'**
  String get syncConflictNoPassword;

  /// No description provided for @syncAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic sync'**
  String get syncAutoTitle;

  /// No description provided for @syncAutoDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync at launch and after every change. Off means only the button below syncs.'**
  String get syncAutoDesc;

  /// No description provided for @syncPasswordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync account passwords'**
  String get syncPasswordsTitle;

  /// No description provided for @syncPasswordsDesc.
  ///
  /// In en, this message translates to:
  /// **'Passwords let a new device sign in by itself. Changing this re-uploads every account.'**
  String get syncPasswordsDesc;

  /// No description provided for @syncAppSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync app settings'**
  String get syncAppSettingsTitle;

  /// No description provided for @syncAppSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync appearance and behavior preferences plus encrypted Steam acceleration subscriptions, nodes and the selected node. Language, text size and acceleration auto-start stay per-device.'**
  String get syncAppSettingsDesc;

  /// No description provided for @syncNowButton.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNowButton;

  /// No description provided for @syncViewRemote.
  ///
  /// In en, this message translates to:
  /// **'View remote library'**
  String get syncViewRemote;

  /// No description provided for @syncRemoteEmpty.
  ///
  /// In en, this message translates to:
  /// **'The remote library is empty.'**
  String get syncRemoteEmpty;

  /// No description provided for @syncRemoteDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get syncRemoteDevices;

  /// No description provided for @syncTrashTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync trash'**
  String get syncTrashTitle;

  /// No description provided for @syncTrashEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty. Anything sync removes or replaces is kept here for 30 days.'**
  String get syncTrashEmpty;

  /// No description provided for @syncTrashRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get syncTrashRestore;

  /// No description provided for @syncTrashRestored.
  ///
  /// In en, this message translates to:
  /// **'Account restored.'**
  String get syncTrashRestored;

  /// No description provided for @syncTrashRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'This entry can\'t be decrypted with the current passphrase.'**
  String get syncTrashRestoreFailed;

  /// No description provided for @syncTrashReasonRemoteDelete.
  ///
  /// In en, this message translates to:
  /// **'deleted by another device'**
  String get syncTrashReasonRemoteDelete;

  /// No description provided for @syncTrashReasonConflict.
  ///
  /// In en, this message translates to:
  /// **'replaced in a conflict'**
  String get syncTrashReasonConflict;

  /// No description provided for @syncChangePassphrase.
  ///
  /// In en, this message translates to:
  /// **'Change sync passphrase'**
  String get syncChangePassphrase;

  /// No description provided for @syncPassphraseChanged.
  ///
  /// In en, this message translates to:
  /// **'Passphrase changed; everything re-encrypted. Other devices will ask for the new passphrase.'**
  String get syncPassphraseChanged;

  /// No description provided for @syncPassphraseChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Passphrase not changed: {reason}'**
  String syncPassphraseChangeFailed(String reason);

  /// No description provided for @syncDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect sync'**
  String get syncDisconnect;

  /// No description provided for @syncDisconnectBody.
  ///
  /// In en, this message translates to:
  /// **'This device stops syncing. The remote library can stay for your other devices — or be deleted from the server entirely.'**
  String get syncDisconnectBody;

  /// No description provided for @syncDisconnectKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep remote data'**
  String get syncDisconnectKeep;

  /// No description provided for @syncDisconnectDeleteHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to delete remote data'**
  String get syncDisconnectDeleteHold;

  /// Shown when the TLS handshake to Steam is cut — the issue-#6 case.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open a secure connection to Steam. The connection was cut during the TLS handshake, which usually means the network is filtering it or is unstable. Try another network — or a proxy — and retry.'**
  String get netErrTls;

  /// Shown when the socket to Steam could not be opened at all.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Steam. Check your connection and retry.'**
  String get netErrUnreachable;

  /// Shown when Steam did not answer within the client timeout.
  ///
  /// In en, this message translates to:
  /// **'Steam didn\'t answer in time. The network may be slow or filtered.'**
  String get netErrTimeout;

  /// Shown when Steam's TLS certificate failed verification.
  ///
  /// In en, this message translates to:
  /// **'Steam\'s certificate wasn\'t trusted, so GooeSteamKit closed the connection. Something on this network may be inspecting traffic.'**
  String get netErrCert;

  /// Shown for a non-2xx HTTP status from Steam.
  ///
  /// In en, this message translates to:
  /// **'Steam returned an error ({code}). This is usually temporary — try again shortly.'**
  String netErrServer(int code);

  /// Snackbar after a desktop maFile export, naming the file the user chose.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String exportSaved(String path);

  /// No description provided for @accountSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search accounts'**
  String get accountSearchHint;

  /// No description provided for @accountSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching accounts'**
  String get accountSearchEmpty;

  /// No description provided for @accountSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get accountSearchClear;

  /// No description provided for @portableMode.
  ///
  /// In en, this message translates to:
  /// **'Portable mode'**
  String get portableMode;

  /// No description provided for @portableEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable portable mode'**
  String get portableEnable;

  /// No description provided for @portableDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable portable mode'**
  String get portableDisable;

  /// No description provided for @portableOnHelp.
  ///
  /// In en, this message translates to:
  /// **'New accounts go to maFiles beside the app. Both libraries are read; portable copies take priority for duplicate accounts.'**
  String get portableOnHelp;

  /// No description provided for @portableOffHelp.
  ///
  /// In en, this message translates to:
  /// **'New accounts go to AppData. Both unlocked libraries are read; local copies take priority for duplicate accounts.'**
  String get portableOffHelp;

  /// No description provided for @portableCopyToUsb.
  ///
  /// In en, this message translates to:
  /// **'Also copy existing local accounts to maFiles beside the app?'**
  String get portableCopyToUsb;

  /// No description provided for @portableCopyToLocal.
  ///
  /// In en, this message translates to:
  /// **'Also copy portable accounts back to AppData?'**
  String get portableCopyToLocal;

  /// No description provided for @portableCopyHelp.
  ///
  /// In en, this message translates to:
  /// **'Copies are verified and the source is kept as a backup. Accounts already in the destination are skipped. Portable accounts are not included in this computer’s WebDAV sync.'**
  String get portableCopyHelp;

  /// No description provided for @portableNoCopy.
  ///
  /// In en, this message translates to:
  /// **'Switch only'**
  String get portableNoCopy;

  /// No description provided for @portableCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy and switch'**
  String get portableCopy;

  /// No description provided for @portableSetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set portable password'**
  String get portableSetPassword;

  /// No description provided for @portableUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock maFiles'**
  String get portableUnlock;

  /// No description provided for @portablePasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Use a separate password with at least 12 characters. Keep it safe: it is needed on other computers and cannot be reset.'**
  String get portablePasswordHelp;

  /// No description provided for @portableUnlockHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter this library’s password. For an encrypted SDA folder, use its SDA passphrase.'**
  String get portableUnlockHelp;

  /// No description provided for @portableConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get portableConfirmPassword;

  /// No description provided for @portablePasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get portablePasswordMismatch;

  /// No description provided for @portableWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password, or this library cannot be unlocked.'**
  String get portableWrongPassword;

  /// No description provided for @portableFailed.
  ///
  /// In en, this message translates to:
  /// **'The operation could not finish. The source library was kept.'**
  String get portableFailed;

  /// No description provided for @portableDone.
  ///
  /// In en, this message translates to:
  /// **'Mode updated. Source accounts were kept.'**
  String get portableDone;

  /// No description provided for @portableSkipped.
  ///
  /// In en, this message translates to:
  /// **'Existing accounts skipped'**
  String get portableSkipped;

  /// No description provided for @portableUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This library is damaged or still depends on another Windows installation’s key. Restore a maFile export; the source files have not been changed.'**
  String get portableUnreadable;

  /// No description provided for @friendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends & trades'**
  String get friendsTitle;

  /// No description provided for @friendsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search name or SteamID'**
  String get friendsSearch;

  /// No description provided for @friendsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No friends to show'**
  String get friendsEmpty;

  /// No description provided for @friendsProfile.
  ///
  /// In en, this message translates to:
  /// **'View Steam profile'**
  String get friendsProfile;

  /// No description provided for @friendsTrade.
  ///
  /// In en, this message translates to:
  /// **'Create trade offer'**
  String get friendsTrade;

  /// No description provided for @friendsOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get friendsOnline;

  /// No description provided for @friendsOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get friendsOffline;

  /// No description provided for @friendsPlaying.
  ///
  /// In en, this message translates to:
  /// **'In game'**
  String get friendsPlaying;

  /// No description provided for @tradeNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New trade offer'**
  String get tradeNewTitle;

  /// No description provided for @tradeYourItems.
  ///
  /// In en, this message translates to:
  /// **'Items you give'**
  String get tradeYourItems;

  /// No description provided for @tradeTheirItems.
  ///
  /// In en, this message translates to:
  /// **'Items you receive'**
  String get tradeTheirItems;

  /// No description provided for @tradeSelectItems.
  ///
  /// In en, this message translates to:
  /// **'Select items'**
  String get tradeSelectItems;

  /// No description provided for @tradeNote.
  ///
  /// In en, this message translates to:
  /// **'Message (optional)'**
  String get tradeNote;

  /// No description provided for @tradeReview.
  ///
  /// In en, this message translates to:
  /// **'Review offer'**
  String get tradeReview;

  /// No description provided for @tradeSend.
  ///
  /// In en, this message translates to:
  /// **'Send offer'**
  String get tradeSend;

  /// No description provided for @tradeReviewBody.
  ///
  /// In en, this message translates to:
  /// **'Check the partner SteamID, items and quantities on both sides. Steam may require confirmation or place items on hold.'**
  String get tradeReviewBody;

  /// No description provided for @tradeGiftWarning.
  ///
  /// In en, this message translates to:
  /// **'You are giving these items away and will receive nothing.'**
  String get tradeGiftWarning;

  /// No description provided for @tradeNoItems.
  ///
  /// In en, this message translates to:
  /// **'No tradable items available here.'**
  String get tradeNoItems;

  /// No description provided for @tradeMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get tradeMore;

  /// No description provided for @tradeSent.
  ///
  /// In en, this message translates to:
  /// **'Offer sent.'**
  String get tradeSent;

  /// No description provided for @tradeNeedsMobile.
  ///
  /// In en, this message translates to:
  /// **'Offer created. Complete its mobile confirmation in Pending.'**
  String get tradeNeedsMobile;

  /// No description provided for @tradeNeedsEmail.
  ///
  /// In en, this message translates to:
  /// **'Offer created. Follow Steam’s email to confirm it.'**
  String get tradeNeedsEmail;

  /// No description provided for @tradeOpenPending.
  ///
  /// In en, this message translates to:
  /// **'View pending & offers'**
  String get tradeOpenPending;

  /// No description provided for @tradeUnknownResult.
  ///
  /// In en, this message translates to:
  /// **'The send result is unknown. Check your sent offers before trying again to avoid duplicates.'**
  String get tradeUnknownResult;

  /// No description provided for @tradeChooseGame.
  ///
  /// In en, this message translates to:
  /// **'Choose inventory'**
  String get tradeChooseGame;

  /// No description provided for @tradeQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get tradeQuantity;

  /// No description provided for @tradeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read Steam friends or inventory. Refresh to try again.'**
  String get tradeLoadFailed;

  /// No description provided for @tradeSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Steam did not confirm the offer was sent. Check your offers before trying again.'**
  String get tradeSendFailed;

  /// No description provided for @marketListingActive.
  ///
  /// In en, this message translates to:
  /// **'For sale'**
  String get marketListingActive;

  /// No description provided for @marketListingOnHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get marketListingOnHold;

  /// No description provided for @marketListingPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation'**
  String get marketListingPending;

  /// No description provided for @marketListingInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get marketListingInactive;

  /// No description provided for @marketHoldUntil.
  ///
  /// In en, this message translates to:
  /// **'On hold until {date}'**
  String marketHoldUntil(String date);

  /// No description provided for @marketListingsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get marketListingsAll;

  /// No description provided for @marketCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel this market listing?'**
  String get marketCancelConfirm;

  /// No description provided for @settingsStartupVerification.
  ///
  /// In en, this message translates to:
  /// **'Verify identity at startup'**
  String get settingsStartupVerification;

  /// No description provided for @settingsStartupVerificationDesc.
  ///
  /// In en, this message translates to:
  /// **'When enabled, opening GooeSteamKit requires your PIN or system authentication. When disabled, anyone using this device can open GooeSteamKit; local account files remain encrypted.'**
  String get settingsStartupVerificationDesc;

  /// No description provided for @settingsStartupVerificationError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the startup verification setting. Check device secure storage and try again.'**
  String get settingsStartupVerificationError;

  /// No description provided for @settingsLockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get settingsLockNow;

  /// No description provided for @settingsStartupVerificationPinChanged.
  ///
  /// In en, this message translates to:
  /// **'Changing your PIN turns startup verification back on.'**
  String get settingsStartupVerificationPinChanged;

  /// No description provided for @settingsStartupVerificationDisable.
  ///
  /// In en, this message translates to:
  /// **'Turn off startup verification?'**
  String get settingsStartupVerificationDisable;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Account overview'**
  String get dashboardTitle;

  /// No description provided for @dashboardWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance'**
  String get dashboardWallet;

  /// No description provided for @dashboardPendingBalance.
  ///
  /// In en, this message translates to:
  /// **'Pending funds'**
  String get dashboardPendingBalance;

  /// No description provided for @dashboardUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get dashboardUnavailable;

  /// No description provided for @dashboardMarket.
  ///
  /// In en, this message translates to:
  /// **'Inventory & market'**
  String get dashboardMarket;

  /// No description provided for @dashboardTools.
  ///
  /// In en, this message translates to:
  /// **'Account tools'**
  String get dashboardTools;

  /// No description provided for @dashboardCustomize.
  ///
  /// In en, this message translates to:
  /// **'Choose overview cards'**
  String get dashboardCustomize;

  /// No description provided for @dashboardViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get dashboardViewAll;

  /// No description provided for @dashboardNoListings.
  ///
  /// In en, this message translates to:
  /// **'No market listings.'**
  String get dashboardNoListings;

  /// No description provided for @dashboardFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this information. Refresh to try again.'**
  String get dashboardFetchFailed;

  /// No description provided for @dashboardSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the display preference.'**
  String get dashboardSaveFailed;

  /// No description provided for @backupCodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup login codes'**
  String get backupCodesTitle;

  /// No description provided for @backupCodesAccountCheck.
  ///
  /// In en, this message translates to:
  /// **'Your browser may be signed in to a different Steam account. Check that its account name matches the one above before generating codes.'**
  String get backupCodesAccountCheck;

  /// No description provided for @backupCodesHow.
  ///
  /// In en, this message translates to:
  /// **'Get codes from Steam'**
  String get backupCodesHow;

  /// No description provided for @backupCodesSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Open Steam Guard settings with the button below.\n2. Sign in to the account shown above.\n3. Choose “Get Backup Steam Guard Codes”.\n4. Complete the verification requested by Steam and keep the generated codes in a safe place.'**
  String get backupCodesSteps;

  /// No description provided for @backupCodesExplanation.
  ///
  /// In en, this message translates to:
  /// **'These are one-use login codes, separate from the authenticator removal code. Steam issues and manages them. GooeSteamKit opens the official flow and does not generate or store these codes.'**
  String get backupCodesExplanation;

  /// No description provided for @backupCodesOpenSteam.
  ///
  /// In en, this message translates to:
  /// **'Open Steam to get codes'**
  String get backupCodesOpenSteam;

  /// No description provided for @backupCodesCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy official link'**
  String get backupCodesCopyLink;

  /// No description provided for @backupCodesOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser. Copy the link and open it manually.'**
  String get backupCodesOpenFailed;

  /// No description provided for @loginAccountMismatch.
  ///
  /// In en, this message translates to:
  /// **'This is a different Steam account. Sign in to the selected account; the original account has not been changed.'**
  String get loginAccountMismatch;

  /// No description provided for @tradeFromAccount.
  ///
  /// In en, this message translates to:
  /// **'Sending account'**
  String get tradeFromAccount;

  /// No description provided for @tradeToAccount.
  ///
  /// In en, this message translates to:
  /// **'Trading partner'**
  String get tradeToAccount;

  /// No description provided for @tradeValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'The offer has not been sent. Check the selected items and quantities; each side allows up to 256 items.'**
  String get tradeValidationFailed;

  /// No description provided for @friendsProfileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open a browser. Copy the official Steam link below.'**
  String get friendsProfileOpenFailed;

  /// No description provided for @steamSwitchQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a GooeSteamKit account'**
  String get steamSwitchQrTitle;

  /// No description provided for @steamSwitchQrHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a GooeSteamKit account, show Steam’s sign-in QR code, then scan it and review the login request.'**
  String get steamSwitchQrHelp;

  /// No description provided for @steamSwitchQrAccount.
  ///
  /// In en, this message translates to:
  /// **'GooeSteamKit account'**
  String get steamSwitchQrAccount;

  /// No description provided for @steamSwitchQrNeedsSession.
  ///
  /// In en, this message translates to:
  /// **'Sign in to this account again in GooeSteamKit first. An offline Steam Guard code alone cannot approve a QR login.'**
  String get steamSwitchQrNeedsSession;

  /// No description provided for @steamSwitchQrNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'Add an account to GooeSteamKit to use QR sign-in.'**
  String get steamSwitchQrNoAccounts;

  /// No description provided for @approveScreenSelect.
  ///
  /// In en, this message translates to:
  /// **'Select a QR code on screen'**
  String get approveScreenSelect;

  /// No description provided for @approveScreenHelp.
  ///
  /// In en, this message translates to:
  /// **'GooeSteamKit will briefly hide. Drag around the Steam sign-in QR code, then review the account and device before approving.'**
  String get approveScreenHelp;

  /// No description provided for @approveScreenInstruction.
  ///
  /// In en, this message translates to:
  /// **'Drag around one Steam sign-in QR code · Esc / right-click to cancel'**
  String get approveScreenInstruction;

  /// No description provided for @approveScreenNoCode.
  ///
  /// In en, this message translates to:
  /// **'No QR code found. Select the complete code with a little space around it and try again.'**
  String get approveScreenNoCode;

  /// No description provided for @approveScreenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not capture the screen. Try again or paste the QR code link.'**
  String get approveScreenFailed;

  /// No description provided for @approveSessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This QR code has expired or its login details could not be verified. Refresh the code in Steam and try again.'**
  String get approveSessionUnavailable;

  /// No description provided for @itemMarketActions.
  ///
  /// In en, this message translates to:
  /// **'Item market options'**
  String get itemMarketActions;

  /// No description provided for @itemMarketViewPrice.
  ///
  /// In en, this message translates to:
  /// **'View market price'**
  String get itemMarketViewPrice;

  /// No description provided for @itemMarketOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Steam Market'**
  String get itemMarketOpen;

  /// No description provided for @itemMarketVolume.
  ///
  /// In en, this message translates to:
  /// **'Recent volume'**
  String get itemMarketVolume;

  /// No description provided for @itemMarketReferenceNote.
  ///
  /// In en, this message translates to:
  /// **'Steam Community Market reference price per item; not seller proceeds. Prices may change.'**
  String get itemMarketReferenceNote;

  /// No description provided for @itemMarketCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency: {currency}'**
  String itemMarketCurrency(String currency);

  /// No description provided for @itemMarketNoIdentity.
  ///
  /// In en, this message translates to:
  /// **'This item has no market listing name.'**
  String get itemMarketNoIdentity;

  /// No description provided for @itemMarketOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Steam Market page.'**
  String get itemMarketOpenFailed;

  /// No description provided for @steamClientRunning.
  ///
  /// In en, this message translates to:
  /// **'Steam is running'**
  String get steamClientRunning;

  /// No description provided for @steamClientStopped.
  ///
  /// In en, this message translates to:
  /// **'Steam is not running'**
  String get steamClientStopped;

  /// No description provided for @steamClientStatusLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading Steam status…'**
  String get steamClientStatusLoading;

  /// No description provided for @steamClientStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Steam status is temporarily unavailable'**
  String get steamClientStatusUnavailable;

  /// No description provided for @steamClientCurrentAccount.
  ///
  /// In en, this message translates to:
  /// **'Currently signed in: {account}'**
  String steamClientCurrentAccount(String account);

  /// No description provided for @steamClientAccountUnknown.
  ///
  /// In en, this message translates to:
  /// **'Current account not yet identified'**
  String get steamClientAccountUnknown;

  /// No description provided for @steamClientCurrentBadge.
  ///
  /// In en, this message translates to:
  /// **'Currently signed in'**
  String get steamClientCurrentBadge;

  /// No description provided for @forkLocalFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Local features unlocked'**
  String get forkLocalFeaturesTitle;

  /// No description provided for @forkLocalFeaturesBody.
  ///
  /// In en, this message translates to:
  /// **'All local features in this independent fork are available without Pro verification. The original author’s online services and subscriptions are not included.'**
  String get forkLocalFeaturesBody;

  /// No description provided for @forkPrivacyConsentBody.
  ///
  /// In en, this message translates to:
  /// **'This independent AVA fork stores your Steam accounts and authenticator secrets on this device. Steam requests go directly to Valve. Optional synchronization is off until you configure your own server; account data is encrypted locally before synchronization. Local features require no Pro verification. This build uses no advertising, payment service or upstream update check. Feedback only opens this fork’s GitHub issue page; reports and logs are not sent automatically. There is no tracking or analytics. Read this fork’s privacy notice below. By continuing, you accept it.'**
  String get forkPrivacyConsentBody;

  /// No description provided for @forkUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Software updates'**
  String get forkUpdateTitle;

  /// No description provided for @forkUpdateCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version {version}'**
  String forkUpdateCurrentVersion(String version);

  /// No description provided for @forkUpdateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get forkUpdateCheck;

  /// No description provided for @forkUpdateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get forkUpdateChecking;

  /// No description provided for @forkUpdateNoRelease.
  ///
  /// In en, this message translates to:
  /// **'No published release is available yet'**
  String get forkUpdateNoRelease;

  /// No description provided for @forkUpdateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You are up to date'**
  String get forkUpdateUpToDate;

  /// No description provided for @forkUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'New version {version}'**
  String forkUpdateAvailable(String version);

  /// No description provided for @forkUpdateReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get forkUpdateReleaseNotes;

  /// No description provided for @forkUpdateNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No release notes were provided'**
  String get forkUpdateNoNotes;

  /// No description provided for @forkUpdateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get forkUpdateDownload;

  /// No description provided for @forkUpdateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {progress}'**
  String forkUpdateDownloading(String progress);

  /// No description provided for @forkUpdateCancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get forkUpdateCancelDownload;

  /// No description provided for @forkUpdateReady.
  ///
  /// In en, this message translates to:
  /// **'The installer is downloaded and verified'**
  String get forkUpdateReady;

  /// No description provided for @forkUpdateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install update'**
  String get forkUpdateInstall;

  /// No description provided for @forkUpdateInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Install this update?'**
  String get forkUpdateInstallTitle;

  /// No description provided for @forkUpdateInstallAndroid.
  ///
  /// In en, this message translates to:
  /// **'The system installer will open. If prompted, allow GooeSteamKit to install apps, then follow the system instructions.'**
  String get forkUpdateInstallAndroid;

  /// No description provided for @forkUpdateInstallWindows.
  ///
  /// In en, this message translates to:
  /// **'The installer will open and GooeSteamKit will close. Finish your current work first, then follow the installer instructions.'**
  String get forkUpdateInstallWindows;

  /// No description provided for @forkUpdateInstallConfirm.
  ///
  /// In en, this message translates to:
  /// **'Continue installation'**
  String get forkUpdateInstallConfirm;

  /// No description provided for @forkUpdateInstallStarted.
  ///
  /// In en, this message translates to:
  /// **'The system installer is open; follow its instructions'**
  String get forkUpdateInstallStarted;

  /// No description provided for @forkUpdateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates. Try again later.'**
  String get forkUpdateCheckFailed;

  /// No description provided for @forkUpdateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please retry.'**
  String get forkUpdateDownloadFailed;

  /// No description provided for @forkUpdateHashFailed.
  ///
  /// In en, this message translates to:
  /// **'The installer failed verification and was blocked. Download it again.'**
  String get forkUpdateHashFailed;

  /// No description provided for @forkUpdateInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the installer. Please retry.'**
  String get forkUpdateInstallFailed;

  /// No description provided for @forkUpdateNoCompatibleAsset.
  ///
  /// In en, this message translates to:
  /// **'This release has no installer for this device'**
  String get forkUpdateNoCompatibleAsset;

  /// No description provided for @forkUpdateUnverifiable.
  ///
  /// In en, this message translates to:
  /// **'This installer has no trusted checksum and cannot be downloaded or installed'**
  String get forkUpdateUnverifiable;

  /// No description provided for @forkUpdateInvalidMetadata.
  ///
  /// In en, this message translates to:
  /// **'Release information is incomplete or invalid. Try again later.'**
  String get forkUpdateInvalidMetadata;

  /// No description provided for @forkUpdateUnsupported.
  ///
  /// In en, this message translates to:
  /// **'In-app updates are not supported on this device'**
  String get forkUpdateUnsupported;

  /// No description provided for @forkUpdateCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled'**
  String get forkUpdateCancelled;

  /// No description provided for @forkUpdatePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Allow GooeSteamKit to install apps, then return here to install'**
  String get forkUpdatePermissionRequired;

  /// No description provided for @forkUpdateOpenPermissionSettings.
  ///
  /// In en, this message translates to:
  /// **'Allow app installs'**
  String get forkUpdateOpenPermissionSettings;

  /// No description provided for @forkUpdateWrongPackage.
  ///
  /// In en, this message translates to:
  /// **'This installer belongs to another app and was blocked'**
  String get forkUpdateWrongPackage;

  /// No description provided for @forkUpdateSignatureMismatch.
  ///
  /// In en, this message translates to:
  /// **'The installer signature does not match this app and was blocked'**
  String get forkUpdateSignatureMismatch;

  /// No description provided for @backupCodesNativeIntro.
  ///
  /// In en, this message translates to:
  /// **'Generate one-time Steam login codes here. Steam requires SMS verification of the phone linked to this account. Generating a new set may replace existing codes.'**
  String get backupCodesNativeIntro;

  /// No description provided for @backupCodesSendSms.
  ///
  /// In en, this message translates to:
  /// **'Send verification SMS'**
  String get backupCodesSendSms;

  /// No description provided for @backupCodesSmsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code from Steam\'s SMS.'**
  String get backupCodesSmsPrompt;

  /// No description provided for @backupCodesSmsLabel.
  ///
  /// In en, this message translates to:
  /// **'SMS verification code'**
  String get backupCodesSmsLabel;

  /// No description provided for @backupCodesGenerate.
  ///
  /// In en, this message translates to:
  /// **'Verify and generate codes'**
  String get backupCodesGenerate;

  /// No description provided for @backupCodesReady.
  ///
  /// In en, this message translates to:
  /// **'Your one-time login codes'**
  String get backupCodesReady;

  /// No description provided for @backupCodesKeepSafe.
  ///
  /// In en, this message translates to:
  /// **'Each code can be used once. Keep a printed copy somewhere safe. GooeSteamKit does not save these codes; leaving this page or switching apps clears them. Steam emails you when codes are generated or used.'**
  String get backupCodesKeepSafe;

  /// No description provided for @backupCodesClear.
  ///
  /// In en, this message translates to:
  /// **'Clear codes'**
  String get backupCodesClear;

  /// No description provided for @backupCodesRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Steam could not complete this request. No request was retried automatically. Check your connection and try again when ready.'**
  String get backupCodesRequestFailed;

  /// No description provided for @backupCodesUnexpectedResponse.
  ///
  /// In en, this message translates to:
  /// **'Steam returned an unrecognized response. The result could not be confirmed; the request was not retried.'**
  String get backupCodesUnexpectedResponse;

  /// No description provided for @backupCodesInvalidSms.
  ///
  /// In en, this message translates to:
  /// **'Steam rejected the verification code. Check the SMS and try again.'**
  String get backupCodesInvalidSms;

  /// No description provided for @backupCodesRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Steam is limiting requests. Please wait before trying again.'**
  String get backupCodesRateLimited;

  /// No description provided for @backupCodesPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Steam requires a verified phone number on this account.'**
  String get backupCodesPhoneRequired;

  /// No description provided for @backupCodesManualHelp.
  ///
  /// In en, this message translates to:
  /// **'Official Steam page (optional)'**
  String get backupCodesManualHelp;

  /// No description provided for @steamAccelerationTitle.
  ///
  /// In en, this message translates to:
  /// **'Steam acceleration'**
  String get steamAccelerationTitle;

  /// No description provided for @steamAccelerationDesc.
  ///
  /// In en, this message translates to:
  /// **'Use an external proxy first, then built-in acceleration when it closes. Only Steam requests in GooeSteamKit use the built-in route.'**
  String get steamAccelerationDesc;

  /// No description provided for @steamAccelerationOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get steamAccelerationOff;

  /// No description provided for @steamAccelerationLoading.
  ///
  /// In en, this message translates to:
  /// **'Syncing subscription…'**
  String get steamAccelerationLoading;

  /// No description provided for @steamAccelerationStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get steamAccelerationStarting;

  /// No description provided for @steamAccelerationRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get steamAccelerationRunning;

  /// No description provided for @steamAccelerationPaused.
  ///
  /// In en, this message translates to:
  /// **'Built-in acceleration is on standby'**
  String get steamAccelerationPaused;

  /// No description provided for @steamAccelerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Acceleration unavailable'**
  String get steamAccelerationFailed;

  /// No description provided for @steamAccelerationUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Currently supported on Windows and Android only.'**
  String get steamAccelerationUnsupported;

  /// No description provided for @steamAccelerationConfigured.
  ///
  /// In en, this message translates to:
  /// **'Subscription saved on this device'**
  String get steamAccelerationConfigured;

  /// No description provided for @steamAccelerationUnconfigured.
  ///
  /// In en, this message translates to:
  /// **'No subscription configured'**
  String get steamAccelerationUnconfigured;

  /// No description provided for @steamAccelerationConfigure.
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get steamAccelerationConfigure;

  /// No description provided for @steamAccelerationReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace subscription'**
  String get steamAccelerationReplace;

  /// No description provided for @steamAccelerationSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL'**
  String get steamAccelerationSubscription;

  /// No description provided for @steamAccelerationSubscriptionHelp.
  ///
  /// In en, this message translates to:
  /// **'This link may contain private credentials and is stored securely on your device. With Sync app settings enabled, subscriptions and nodes are also encrypted with your sync passphrase and synced. After saving, select Refresh nodes.'**
  String get steamAccelerationSubscriptionHelp;

  /// No description provided for @steamAccelerationClear.
  ///
  /// In en, this message translates to:
  /// **'Clear subscription'**
  String get steamAccelerationClear;

  /// No description provided for @steamAccelerationClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop built-in acceleration and delete the saved subscription and nodes? With settings sync enabled, this deletion also syncs to your other devices.'**
  String get steamAccelerationClearConfirm;

  /// No description provided for @steamAccelerationSync.
  ///
  /// In en, this message translates to:
  /// **'Refresh nodes'**
  String get steamAccelerationSync;

  /// No description provided for @steamAccelerationDownloadingCore.
  ///
  /// In en, this message translates to:
  /// **'Downloading acceleration component…'**
  String get steamAccelerationDownloadingCore;

  /// No description provided for @steamAccelerationCoreDownload.
  ///
  /// In en, this message translates to:
  /// **'Could not download the acceleration component after trying mirrors and the official source. Try again later.'**
  String get steamAccelerationCoreDownload;

  /// No description provided for @steamAccelerationExternalActiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Using the external connection. With automatic switching enabled, the built-in route takes over when it closes. No manual switching is needed.'**
  String get steamAccelerationExternalActiveHelp;

  /// No description provided for @steamAccelerationNodes.
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get steamAccelerationNodes;

  /// No description provided for @steamAccelerationNoNodes.
  ///
  /// In en, this message translates to:
  /// **'Sync the subscription to load available nodes.'**
  String get steamAccelerationNoNodes;

  /// No description provided for @steamAccelerationNode.
  ///
  /// In en, this message translates to:
  /// **'Selected node'**
  String get steamAccelerationNode;

  /// No description provided for @steamAccelerationStart.
  ///
  /// In en, this message translates to:
  /// **'Enable automatic switching'**
  String get steamAccelerationStart;

  /// No description provided for @steamAccelerationStop.
  ///
  /// In en, this message translates to:
  /// **'Pause automatic switching'**
  String get steamAccelerationStop;

  /// No description provided for @steamAccelerationAuto.
  ///
  /// In en, this message translates to:
  /// **'Enable on launch'**
  String get steamAccelerationAuto;

  /// No description provided for @steamAccelerationAutoDesc.
  ///
  /// In en, this message translates to:
  /// **'Prefer an external proxy or VPN; resume the built-in route when it closes. Pausing applies until the next launch.'**
  String get steamAccelerationAutoDesc;

  /// No description provided for @steamAccelerationEnvironment.
  ///
  /// In en, this message translates to:
  /// **'External proxy detection'**
  String get steamAccelerationEnvironment;

  /// No description provided for @steamAccelerationExternalProxy.
  ///
  /// In en, this message translates to:
  /// **'System proxy or PAC detected'**
  String get steamAccelerationExternalProxy;

  /// No description provided for @steamAccelerationExternalVpn.
  ///
  /// In en, this message translates to:
  /// **'VPN or tunnel detected'**
  String get steamAccelerationExternalVpn;

  /// No description provided for @steamAccelerationNoExternal.
  ///
  /// In en, this message translates to:
  /// **'No external proxy detected'**
  String get steamAccelerationNoExternal;

  /// No description provided for @steamAccelerationDetectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'External proxy status is unknown, so the built-in route will not start. Check the system proxy settings, then check again.'**
  String get steamAccelerationDetectionUnavailable;

  /// No description provided for @steamAccelerationEnvironmentHelp.
  ///
  /// In en, this message translates to:
  /// **'Checks the local connection settings while the app is visible. System proxy and VPN settings are never changed.'**
  String get steamAccelerationEnvironmentHelp;

  /// No description provided for @steamAccelerationSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped {count} unsupported nodes.'**
  String steamAccelerationSkipped(int count);

  /// No description provided for @steamAccelerationInvalidSubscription.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP or HTTPS subscription URL.'**
  String get steamAccelerationInvalidSubscription;

  /// No description provided for @steamAccelerationNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch the subscription. Check your connection and try again.'**
  String get steamAccelerationNetworkError;

  /// No description provided for @steamAccelerationUnsupportedSubscription.
  ///
  /// In en, this message translates to:
  /// **'The subscription has no supported nodes. Use a compatible Clash subscription.'**
  String get steamAccelerationUnsupportedSubscription;

  /// No description provided for @steamAccelerationStorageError.
  ///
  /// In en, this message translates to:
  /// **'Secure storage is unavailable. The setting could not be saved.'**
  String get steamAccelerationStorageError;

  /// No description provided for @steamAccelerationCoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The acceleration component is missing. Install an updated app package.'**
  String get steamAccelerationCoreUnavailable;

  /// No description provided for @steamAccelerationCoreIntegrity.
  ///
  /// In en, this message translates to:
  /// **'The acceleration component failed verification and was blocked.'**
  String get steamAccelerationCoreIntegrity;

  /// No description provided for @steamAccelerationStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start acceleration. Refresh the environment check and try again.'**
  String get steamAccelerationStartFailed;

  /// No description provided for @inventorySearch.
  ///
  /// In en, this message translates to:
  /// **'Search items'**
  String get inventorySearch;

  /// No description provided for @inventoryFilterType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get inventoryFilterType;

  /// No description provided for @inventoryFilterRarity.
  ///
  /// In en, this message translates to:
  /// **'Rarity / quality'**
  String get inventoryFilterRarity;

  /// No description provided for @inventoryFilterOther.
  ///
  /// In en, this message translates to:
  /// **'Other / unclassified'**
  String get inventoryFilterOther;

  /// No description provided for @inventoryFilterNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No items match these filters'**
  String get inventoryFilterNoMatches;

  /// No description provided for @inventoryFilterLoaded.
  ///
  /// In en, this message translates to:
  /// **'Filters apply to loaded items. Load more to include the rest.'**
  String get inventoryFilterLoaded;

  /// No description provided for @steamConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection check'**
  String get steamConnectionTitle;

  /// No description provided for @steamConnectionNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get steamConnectionNotChecked;

  /// No description provided for @steamConnectionChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking connection…'**
  String get steamConnectionChecking;

  /// No description provided for @steamConnectionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Connection available'**
  String get steamConnectionAvailable;

  /// No description provided for @steamConnectionPartial.
  ///
  /// In en, this message translates to:
  /// **'Some Steam services are unavailable'**
  String get steamConnectionPartial;

  /// No description provided for @steamConnectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Steam connection unavailable'**
  String get steamConnectionUnavailable;

  /// No description provided for @steamConnectionCheck.
  ///
  /// In en, this message translates to:
  /// **'Check connection'**
  String get steamConnectionCheck;

  /// No description provided for @steamConnectionApi.
  ///
  /// In en, this message translates to:
  /// **'Steam sign-in API'**
  String get steamConnectionApi;

  /// No description provided for @steamConnectionCommunity.
  ///
  /// In en, this message translates to:
  /// **'Steam Community and Market'**
  String get steamConnectionCommunity;

  /// No description provided for @steamConnectionReachable.
  ///
  /// In en, this message translates to:
  /// **'Reachable'**
  String get steamConnectionReachable;

  /// No description provided for @steamConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get steamConnectionFailed;

  /// No description provided for @steamConnectionInternal.
  ///
  /// In en, this message translates to:
  /// **'Built-in route'**
  String get steamConnectionInternal;

  /// No description provided for @steamConnectionExternal.
  ///
  /// In en, this message translates to:
  /// **'External HTTP proxy'**
  String get steamConnectionExternal;

  /// No description provided for @steamConnectionSystem.
  ///
  /// In en, this message translates to:
  /// **'External VPN / tunnel'**
  String get steamConnectionSystem;

  /// No description provided for @steamConnectionDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct connection'**
  String get steamConnectionDirect;

  /// No description provided for @steamConnectionCheckedAt.
  ///
  /// In en, this message translates to:
  /// **'Last checked: {time}'**
  String steamConnectionCheckedAt(String time);

  /// No description provided for @steamConnectionNoVpnIcon.
  ///
  /// In en, this message translates to:
  /// **'This only routes Steam requests inside GooeSteamKit, so Android does not show a system VPN icon. It does not accelerate the Steam app or other apps.'**
  String get steamConnectionNoVpnIcon;

  /// No description provided for @steamConnectionScope.
  ///
  /// In en, this message translates to:
  /// **'Checks Steam API and Community over GooeSteamKit’s current route without account credentials. Results describe this check, not continuous availability.'**
  String get steamConnectionScope;

  /// No description provided for @tradeSendNotSent.
  ///
  /// In en, this message translates to:
  /// **'Offer was not sent. {reason}'**
  String tradeSendNotSent(String reason);

  /// No description provided for @tradeCheckSendResult.
  ///
  /// In en, this message translates to:
  /// **'Check send result'**
  String get tradeCheckSendResult;

  /// No description provided for @tradeSendNotFound.
  ///
  /// In en, this message translates to:
  /// **'No matching new offer is visible yet. Steam may take time to update. Check Pending and sent offers before sending again.'**
  String get tradeSendNotFound;

  /// No description provided for @tradeSendCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify the send result. {reason}'**
  String tradeSendCheckFailed(String reason);

  /// No description provided for @tradeSendRejected.
  ///
  /// In en, this message translates to:
  /// **'Steam rejected this offer without a detailed reason. Check the selected items and trading restrictions.'**
  String get tradeSendRejected;

  /// No description provided for @tradeSendUnreadableResponse.
  ///
  /// In en, this message translates to:
  /// **'Steam did not return a complete send receipt.'**
  String get tradeSendUnreadableResponse;

  /// No description provided for @steamConnectionPacHelp.
  ///
  /// In en, this message translates to:
  /// **'A system proxy setting was found, but no usable HTTP endpoint or VPN route is available. PAC scripts are not evaluated. Enable the external app’s HTTP proxy or VPN mode.'**
  String get steamConnectionPacHelp;

  /// No description provided for @forkUpdateTransferSize.
  ///
  /// In en, this message translates to:
  /// **'{received} / {total} MiB'**
  String forkUpdateTransferSize(String received, String total);

  /// No description provided for @forkUpdateTransferSpeed.
  ///
  /// In en, this message translates to:
  /// **'{speed} {unit}/s'**
  String forkUpdateTransferSpeed(String speed, String unit);

  /// No description provided for @forkUpdateRemainingSeconds.
  ///
  /// In en, this message translates to:
  /// **'About {seconds}s left'**
  String forkUpdateRemainingSeconds(int seconds);

  /// No description provided for @forkUpdateRemainingMinutes.
  ///
  /// In en, this message translates to:
  /// **'About {minutes}min left'**
  String forkUpdateRemainingMinutes(int minutes);

  /// No description provided for @forkUpdateWaitingForData.
  ///
  /// In en, this message translates to:
  /// **'Waiting for data…'**
  String get forkUpdateWaitingForData;

  /// No description provided for @forkUpdateVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying installer…'**
  String get forkUpdateVerifying;

  /// No description provided for @forkUpdateConnectionHint.
  ///
  /// In en, this message translates to:
  /// **'Automatic mode downloads through GH-Proxy without starting a proxy, then falls back to GitHub if needed. Files are checked against GitHub’s SHA-256.'**
  String get forkUpdateConnectionHint;

  /// No description provided for @forkUpdateSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Download source'**
  String get forkUpdateSourceLabel;

  /// No description provided for @forkUpdateSourceAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic acceleration'**
  String get forkUpdateSourceAutomatic;

  /// No description provided for @forkUpdateSourceOfficial.
  ///
  /// In en, this message translates to:
  /// **'GitHub official'**
  String get forkUpdateSourceOfficial;

  /// No description provided for @forkUpdateSourceAccelerated.
  ///
  /// In en, this message translates to:
  /// **'Direct acceleration · {provider}'**
  String forkUpdateSourceAccelerated(String provider);

  /// No description provided for @marketTabSearch.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get marketTabSearch;

  /// No description provided for @marketSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search items, e.g. AK-47'**
  String get marketSearchHint;

  /// No description provided for @marketSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Choose a game and currency, then search for an item. Data loads only when you search.'**
  String get marketSearchEmpty;

  /// No description provided for @marketSearchButton.
  ///
  /// In en, this message translates to:
  /// **'Search market'**
  String get marketSearchButton;

  /// No description provided for @marketSearchAllGames.
  ///
  /// In en, this message translates to:
  /// **'All games'**
  String get marketSearchAllGames;

  /// No description provided for @marketSearchGame.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get marketSearchGame;

  /// No description provided for @marketSearchCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get marketSearchCurrency;

  /// No description provided for @marketSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching items. Try another search.'**
  String get marketSearchNoResults;

  /// No description provided for @marketSearchMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get marketSearchMore;

  /// No description provided for @marketSearchListings.
  ///
  /// In en, this message translates to:
  /// **'Listings: {count}'**
  String marketSearchListings(int count);

  /// No description provided for @marketSearchPriceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Price unavailable'**
  String get marketSearchPriceUnavailable;

  /// No description provided for @marketSearchPriceNote.
  ///
  /// In en, this message translates to:
  /// **'Reference prices load in the selected currency only for visible items and may change.'**
  String get marketSearchPriceNote;

  /// No description provided for @marketSearchRefreshPrice.
  ///
  /// In en, this message translates to:
  /// **'Refresh price'**
  String get marketSearchRefreshPrice;

  /// No description provided for @marketSearchRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Steam is receiving too many requests. Please try again later.'**
  String get marketSearchRateLimited;

  /// No description provided for @marketSearchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Market items are unavailable right now. Please try again later.'**
  String get marketSearchUnavailable;

  /// No description provided for @marketSearchRequestedCurrency.
  ///
  /// In en, this message translates to:
  /// **'Requested currency: {currency}'**
  String marketSearchRequestedCurrency(String currency);

  /// No description provided for @steamConnectionUnresolvedProxy.
  ///
  /// In en, this message translates to:
  /// **'System proxy unavailable'**
  String get steamConnectionUnresolvedProxy;

  /// No description provided for @steamDesktopLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Open Steam and sign in'**
  String get steamDesktopLoginButton;

  /// No description provided for @steamDesktopLoginHelp.
  ///
  /// In en, this message translates to:
  /// **'Open or switch Steam to the selected account and automatically approve the QR code in this computer\'s Steam sign-in window. Please exit any running games first.'**
  String get steamDesktopLoginHelp;

  /// No description provided for @steamDesktopLoginPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the selected account…'**
  String get steamDesktopLoginPreparing;

  /// No description provided for @steamDesktopLoginWaitingQr.
  ///
  /// In en, this message translates to:
  /// **'Waiting for this computer\'s Steam sign-in QR code…'**
  String get steamDesktopLoginWaitingQr;

  /// No description provided for @steamDesktopLoginApproving.
  ///
  /// In en, this message translates to:
  /// **'Approving this computer\'s sign-in…'**
  String get steamDesktopLoginApproving;

  /// No description provided for @steamDesktopLoginWaitingAccount.
  ///
  /// In en, this message translates to:
  /// **'Confirming Steam sign-in status…'**
  String get steamDesktopLoginWaitingAccount;

  /// No description provided for @steamDesktopLoginComplete.
  ///
  /// In en, this message translates to:
  /// **'Verified that the Steam client\'s current account matches the selected account.'**
  String get steamDesktopLoginComplete;

  /// No description provided for @steamDesktopLoginManual.
  ///
  /// In en, this message translates to:
  /// **'Steam is open, but its local sign-in QR code could not be verified. Use the QR scanning option below to continue.'**
  String get steamDesktopLoginManual;

  /// No description provided for @steamDesktopLoginUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'A sign-in approval request was submitted, but Steam sign-in has not been confirmed. Check the Steam window, then refresh the status.'**
  String get steamDesktopLoginUnconfirmed;

  /// No description provided for @steamDesktopLoginCancelled.
  ///
  /// In en, this message translates to:
  /// **'Automatic sign-in stopped'**
  String get steamDesktopLoginCancelled;

  /// No description provided for @steamDesktopLoginCancel.
  ///
  /// In en, this message translates to:
  /// **'Stop automatic approval'**
  String get steamDesktopLoginCancel;

  /// No description provided for @steamDesktopLoginWrongAccount.
  ///
  /// In en, this message translates to:
  /// **'Steam is signed in to a different account. Automatic approval has stopped.'**
  String get steamDesktopLoginWrongAccount;

  /// No description provided for @steamClientOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Steam'**
  String get steamClientOpen;

  /// No description provided for @steamSwitchLaunchFailed.
  ///
  /// In en, this message translates to:
  /// **'Steam could not start. Check the installation path and make sure Steam can run normally.'**
  String get steamSwitchLaunchFailed;

  /// No description provided for @steamSwitchFileAccessFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not back up or change Steam settings. Check read and write permissions for the installation folder.'**
  String get steamSwitchFileAccessFailed;

  /// No description provided for @steamDesktopLoginSession.
  ///
  /// In en, this message translates to:
  /// **'Steam is open. Connecting to the selected account…'**
  String get steamDesktopLoginSession;

  /// No description provided for @steamSwitchInspecting.
  ///
  /// In en, this message translates to:
  /// **'Checking Steam on this PC'**
  String get steamSwitchInspecting;

  /// Safe diagnostics only: an allowlisted stage and error code, plus a Win32 error number or a placeholder when unavailable. Never pass raw exception text, paths or account data.
  ///
  /// In en, this message translates to:
  /// **'Stage: {stage}; error code: {code}; Windows: {systemError}.'**
  String steamSwitchErrorDetails(String stage, String code, String systemError);

  /// No description provided for @approveScreenBusy.
  ///
  /// In en, this message translates to:
  /// **'Another screen capture is in progress. Finish or cancel it first.'**
  String get approveScreenBusy;

  /// No description provided for @approveScreenDisplayChanged.
  ///
  /// In en, this message translates to:
  /// **'The display layout has changed. Select the QR code area again.'**
  String get approveScreenDisplayChanged;

  /// No description provided for @approveScreenRegionTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The selected area is too large. Select only the QR code area.'**
  String get approveScreenRegionTooLarge;

  /// Screen capture failure with safe diagnostics containing only allowlisted error codes, stages and Win32 error numbers. Never pass raw exception text, paths or account data.
  ///
  /// In en, this message translates to:
  /// **'Could not capture the screen. Try again. Error details: {detail}.'**
  String approveScreenFailedDetail(String detail);

  /// No description provided for @marketFavoriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get marketFavoriteTitle;

  /// No description provided for @marketFavoriteAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get marketFavoriteAdd;

  /// No description provided for @marketFavoriteRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get marketFavoriteRemove;

  /// No description provided for @marketFavoriteEmpty.
  ///
  /// In en, this message translates to:
  /// **'Save items from market search to see their prices here without searching again.'**
  String get marketFavoriteEmpty;

  /// No description provided for @marketFavoriteSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load or save market favorites. Please try again.'**
  String get marketFavoriteSaveFailed;

  /// No description provided for @syncCompareTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare local and remote'**
  String get syncCompareTitle;

  /// No description provided for @syncCompareRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh comparison'**
  String get syncCompareRefresh;

  /// No description provided for @syncCompareHelp.
  ///
  /// In en, this message translates to:
  /// **'Compare each item before choosing a direction. Newer means changed since the last shared version; times below are last sync times, for reference. Pull or upload affects only the selected row.'**
  String get syncCompareHelp;

  /// No description provided for @syncCompareStale.
  ///
  /// In en, this message translates to:
  /// **'Local or remote data changed. Refresh the comparison before trying again.'**
  String get syncCompareStale;

  /// No description provided for @syncCompareFailed.
  ///
  /// In en, this message translates to:
  /// **'Comparison or transfer failed. Check the connection and sync passphrase, then refresh. No successful transfer has been confirmed.'**
  String get syncCompareFailed;

  /// No description provided for @syncCompareSame.
  ///
  /// In en, this message translates to:
  /// **'Same content'**
  String get syncCompareSame;

  /// No description provided for @syncCompareLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Only on this device'**
  String get syncCompareLocalOnly;

  /// No description provided for @syncCompareRemoteOnly.
  ///
  /// In en, this message translates to:
  /// **'Only on remote'**
  String get syncCompareRemoteOnly;

  /// No description provided for @syncCompareLocalNewer.
  ///
  /// In en, this message translates to:
  /// **'Local has newer changes'**
  String get syncCompareLocalNewer;

  /// No description provided for @syncCompareRemoteNewer.
  ///
  /// In en, this message translates to:
  /// **'Remote has newer changes'**
  String get syncCompareRemoteNewer;

  /// No description provided for @syncCompareBothChanged.
  ///
  /// In en, this message translates to:
  /// **'Different on both sides — choose a direction'**
  String get syncCompareBothChanged;

  /// No description provided for @syncCompareRemoteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted on remote; upload restores this account'**
  String get syncCompareRemoteDeleted;

  /// No description provided for @syncCompareSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings, favorites and acceleration subscription'**
  String get syncCompareSettings;

  /// No description provided for @syncCompareSettingsConflict.
  ///
  /// In en, this message translates to:
  /// **'Settings changed on both devices. Compare before choosing upload or pull.'**
  String get syncCompareSettingsConflict;

  /// No description provided for @syncComparePull.
  ///
  /// In en, this message translates to:
  /// **'Pull remote → local'**
  String get syncComparePull;

  /// No description provided for @syncCompareUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload local → remote'**
  String get syncCompareUpload;

  /// No description provided for @syncCompareHidden.
  ///
  /// In en, this message translates to:
  /// **'Changed private value (hidden)'**
  String get syncCompareHidden;

  /// No description provided for @syncCompareCurrency.
  ///
  /// In en, this message translates to:
  /// **'Market currency'**
  String get syncCompareCurrency;

  /// No description provided for @syncCompareFavorites.
  ///
  /// In en, this message translates to:
  /// **'Market favorites'**
  String get syncCompareFavorites;

  /// No description provided for @syncCompareSubscription.
  ///
  /// In en, this message translates to:
  /// **'Acceleration subscription URL'**
  String get syncCompareSubscription;

  /// No description provided for @syncCompareNodes.
  ///
  /// In en, this message translates to:
  /// **'Acceleration node configuration'**
  String get syncCompareNodes;

  /// No description provided for @syncCompareSelectedNode.
  ///
  /// In en, this message translates to:
  /// **'Selected acceleration node'**
  String get syncCompareSelectedNode;

  /// No description provided for @marketFavoriteSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get marketFavoriteSearch;

  /// No description provided for @inventoryCooldownDetails.
  ///
  /// In en, this message translates to:
  /// **'Trade and market restrictions'**
  String get inventoryCooldownDetails;

  /// No description provided for @inventoryCooldownUntil.
  ///
  /// In en, this message translates to:
  /// **'Cooldown until {time}'**
  String inventoryCooldownUntil(String time);

  /// No description provided for @inventoryCooldownTradable.
  ///
  /// In en, this message translates to:
  /// **'Tradable'**
  String get inventoryCooldownTradable;

  /// No description provided for @inventoryCooldownNotTradable.
  ///
  /// In en, this message translates to:
  /// **'Not tradable'**
  String get inventoryCooldownNotTradable;

  /// No description provided for @inventoryCooldownMarketable.
  ///
  /// In en, this message translates to:
  /// **'Marketable'**
  String get inventoryCooldownMarketable;

  /// No description provided for @inventoryCooldownLocalTime.
  ///
  /// In en, this message translates to:
  /// **'Time shown in your device’s local time zone.'**
  String get inventoryCooldownLocalTime;

  /// No description provided for @inventoryCooldownUnknown.
  ///
  /// In en, this message translates to:
  /// **'Steam has not provided a readable unlock time. No date is estimated.'**
  String get inventoryCooldownUnknown;

  /// No description provided for @inventoryCooldownElapsed.
  ///
  /// In en, this message translates to:
  /// **'This date has passed. Refresh the inventory to check Steam’s current restrictions.'**
  String get inventoryCooldownElapsed;

  /// No description provided for @inventoryCooldownRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining: {days}d {hours}h {minutes}m'**
  String inventoryCooldownRemaining(int days, int hours, int minutes);

  /// No description provided for @deviceRevokeOthersAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke other device authorizations'**
  String get deviceRevokeOthersAction;

  /// No description provided for @deviceRevokeOthersConfirm.
  ///
  /// In en, this message translates to:
  /// **'Revoke the {count} other device authorizations listed below? Keep the current GooeSteamKit session. Those devices will need to sign in again. This does not remove your Steam authenticator.'**
  String deviceRevokeOthersConfirm(int count);

  /// No description provided for @deviceRevokeOthersCurrentUnknown.
  ///
  /// In en, this message translates to:
  /// **'The current GooeSteamKit session could not be identified. Refresh before revoking device authorizations.'**
  String get deviceRevokeOthersCurrentUnknown;

  /// No description provided for @deviceRevokeOthersNone.
  ///
  /// In en, this message translates to:
  /// **'No other device authorizations to revoke.'**
  String get deviceRevokeOthersNone;

  /// No description provided for @deviceRevokeOthersBusy.
  ///
  /// In en, this message translates to:
  /// **'Revoking other device authorizations…'**
  String get deviceRevokeOthersBusy;

  /// No description provided for @deviceRevokeOthersDone.
  ///
  /// In en, this message translates to:
  /// **'Confirmed: {count} other device authorizations revoked.'**
  String deviceRevokeOthersDone(int count);

  /// No description provided for @deviceRevokeOthersPartial.
  ///
  /// In en, this message translates to:
  /// **'Confirmed revoked: {done}. Not completed or not confirmed: {failed}. Check the details below and the refreshed device list before trying again.'**
  String deviceRevokeOthersPartial(int done, int failed);

  /// No description provided for @accountCopyInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy account information'**
  String get accountCopyInfoTitle;

  /// No description provided for @accountCopyPersonaName.
  ///
  /// In en, this message translates to:
  /// **'Copy Steam nickname'**
  String get accountCopyPersonaName;

  /// No description provided for @accountCopyLoginName.
  ///
  /// In en, this message translates to:
  /// **'Copy login name'**
  String get accountCopyLoginName;

  /// No description provided for @accountCopyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get accountCopyUnavailable;

  /// No description provided for @accountCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy. Please try again.'**
  String get accountCopyFailed;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Steam notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsInboxTab.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsInboxTab;

  /// No description provided for @notificationsRequestsTab.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get notificationsRequestsTab;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsRequestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending friend requests.'**
  String get notificationsRequestsEmpty;

  /// No description provided for @notificationsMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get notificationsMarkRead;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark this list as read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsHide.
  ///
  /// In en, this message translates to:
  /// **'Ignore notification'**
  String get notificationsHide;

  /// No description provided for @notificationsItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Steam notification'**
  String get notificationsItemTitle;

  /// No description provided for @notificationsItemFallback.
  ///
  /// In en, this message translates to:
  /// **'No displayable details are available for this notification type.'**
  String get notificationsItemFallback;

  /// No description provided for @notificationsOpenSteam.
  ///
  /// In en, this message translates to:
  /// **'View in Steam'**
  String get notificationsOpenSteam;

  /// No description provided for @notificationsAcceptRequest.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get notificationsAcceptRequest;

  /// No description provided for @notificationsRejectRequest.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get notificationsRejectRequest;

  /// No description provided for @notificationsActionUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The result could not be confirmed. Refresh to check before trying again.'**
  String get notificationsActionUnconfirmed;

  /// No description provided for @notificationsActionDone.
  ///
  /// In en, this message translates to:
  /// **'Updated.'**
  String get notificationsActionDone;

  /// No description provided for @notificationsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load notifications. Please refresh or sign in again.'**
  String get notificationsLoadFailed;

  /// No description provided for @notificationsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open Steam.'**
  String get notificationsOpenFailed;

  /// No description provided for @notificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationsUnread;

  /// No description provided for @notificationsSessionChanged.
  ///
  /// In en, this message translates to:
  /// **'The account session changed. Refresh this list before continuing.'**
  String get notificationsSessionChanged;

  /// No description provided for @confirmationBadgeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending confirmations'**
  String confirmationBadgeCount(int count);

  /// No description provided for @confirmationBadgeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Pending confirmations have not been checked.'**
  String get confirmationBadgeUnknown;

  /// No description provided for @confirmationBadgeStale.
  ///
  /// In en, this message translates to:
  /// **'Last checked: {count} pending confirmations. Refresh to check again.'**
  String confirmationBadgeStale(int count);

  /// No description provided for @notificationsTypeGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get notificationsTypeGift;

  /// No description provided for @notificationsTypeComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get notificationsTypeComment;

  /// No description provided for @notificationsTypeInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory item'**
  String get notificationsTypeInventory;

  /// No description provided for @notificationsTypeFriend.
  ///
  /// In en, this message translates to:
  /// **'Friend request'**
  String get notificationsTypeFriend;

  /// No description provided for @notificationsTypeSale.
  ///
  /// In en, this message translates to:
  /// **'Promotion'**
  String get notificationsTypeSale;

  /// No description provided for @notificationsTypeWishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get notificationsTypeWishlist;

  /// No description provided for @notificationsTypeTrade.
  ///
  /// In en, this message translates to:
  /// **'Trade offer'**
  String get notificationsTypeTrade;

  /// No description provided for @notificationsTypeAccount.
  ///
  /// In en, this message translates to:
  /// **'Account notice'**
  String get notificationsTypeAccount;

  /// No description provided for @notificationsTypeSupport.
  ///
  /// In en, this message translates to:
  /// **'Steam Support'**
  String get notificationsTypeSupport;

  /// No description provided for @notificationsTypeModeration.
  ///
  /// In en, this message translates to:
  /// **'Moderation notice'**
  String get notificationsTypeModeration;

  /// No description provided for @notificationsTypeFamily.
  ///
  /// In en, this message translates to:
  /// **'Family invitation'**
  String get notificationsTypeFamily;

  /// No description provided for @notificationsTypePlaytest.
  ///
  /// In en, this message translates to:
  /// **'Playtest invitation'**
  String get notificationsTypePlaytest;

  /// No description provided for @notificationsTypeTradeReversal.
  ///
  /// In en, this message translates to:
  /// **'Trade reversal'**
  String get notificationsTypeTradeReversal;

  /// No description provided for @notificationsTypeReport.
  ///
  /// In en, this message translates to:
  /// **'Report result'**
  String get notificationsTypeReport;

  /// No description provided for @notificationsNoUnread.
  ///
  /// In en, this message translates to:
  /// **'No unread notifications.'**
  String get notificationsNoUnread;

  /// No description provided for @notificationsHistory.
  ///
  /// In en, this message translates to:
  /// **'Read notifications ({count})'**
  String notificationsHistory(int count);

  /// No description provided for @notificationsCollapseHistory.
  ///
  /// In en, this message translates to:
  /// **'Hide read notifications'**
  String get notificationsCollapseHistory;

  /// No description provided for @notificationsInventoryReceived.
  ///
  /// In en, this message translates to:
  /// **'New inventory item in {game}.'**
  String notificationsInventoryReceived(String game);

  /// No description provided for @notificationsItemLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading item details…'**
  String get notificationsItemLoading;

  /// No description provided for @notificationsItemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Item details are currently unavailable.'**
  String get notificationsItemUnavailable;

  /// No description provided for @notificationsOpenInventory.
  ///
  /// In en, this message translates to:
  /// **'View inventory'**
  String get notificationsOpenInventory;

  /// No description provided for @notificationsFriendSummary.
  ///
  /// In en, this message translates to:
  /// **'Open friend requests to check and respond to current invitations.'**
  String get notificationsFriendSummary;

  /// No description provided for @notificationsTradeSummary.
  ///
  /// In en, this message translates to:
  /// **'Open trade offers to view the items and current status.'**
  String get notificationsTradeSummary;

  /// No description provided for @deviceRevokeOthersVerifyPending.
  ///
  /// In en, this message translates to:
  /// **'Removal could not be verified in the refreshed device list. Refresh and check before trying again.'**
  String get deviceRevokeOthersVerifyPending;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
