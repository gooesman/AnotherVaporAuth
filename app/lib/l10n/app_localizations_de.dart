// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get steamSwitchTitle => 'Steam-Konto wechseln';

  @override
  String get steamSwitchHelp =>
      'Wechsle zwischen Steam-Konten, die auf diesem PC bereits angemeldet waren und deren Anmeldedaten gespeichert sind. Der Import eines Authenticators in GooeSteamKit meldet das Konto nicht im Steam-Client an.';

  @override
  String get steamSwitchPath => 'Steam-Installationsordner';

  @override
  String get steamSwitchNotFound =>
      'Steam wurde nicht gefunden. Wähle steam.exe aus, um die Installation anzugeben.';

  @override
  String get steamSwitchBrowse => 'steam.exe auswählen';

  @override
  String get steamSwitchNoAccounts =>
      'Auf diesem PC wurden keine gespeicherten Steam-Konten gefunden. Melde dich in Steam an, lasse die Anmeldedaten speichern und lade die Liste neu.';

  @override
  String get steamSwitchNoMatch =>
      'Das in GooeSteamKit gewählte Konto ist auf diesem PC nicht in Steam gespeichert. Melde dich mit diesem Konto in Steam an, lasse die Anmeldedaten speichern und lade die Liste neu.';

  @override
  String get steamSwitchNeedsLogin =>
      'Melde dich mit diesem Konto in Steam an, lasse die Anmeldedaten speichern und lade die Liste neu.';

  @override
  String get steamSwitchButton => 'Konto wechseln';

  @override
  String steamSwitchConfirm(String account) {
    return 'Steam wird geschlossen und neu gestartet, um $account anzumelden. Beende zuerst deine Spiele und warte, bis die Spielstände mit Steam Cloud synchronisiert sind. Fortfahren?';
  }

  @override
  String get steamSwitchStopping => 'Steam wird beendet…';

  @override
  String get steamSwitchBackingUp => 'Steam-Einstellungen werden gesichert…';

  @override
  String get steamSwitchConfiguring => 'Steam-Konto wird ausgewählt…';

  @override
  String get steamSwitchStarting => 'Steam wird gestartet…';

  @override
  String get steamSwitchRestoring =>
      'Steam-Einstellungen werden wiederhergestellt…';

  @override
  String get steamSwitchLaunched =>
      'Steam wurde gestartet. Prüfe im Client, welches Konto angemeldet ist. Melde dich erneut an, falls du dazu aufgefordert wirst.';

  @override
  String get steamSwitchBackup => 'Speicherort der Einstellungssicherung';

  @override
  String get steamSwitchInvalidPath =>
      'Diese Steam-Installation oder ihre Einstellungen konnten nicht gelesen werden. Wähle die richtige steam.exe aus und versuche es erneut.';

  @override
  String get steamSwitchCloseFailed =>
      'Steam konnte nicht ordnungsgemäß beendet werden. Beende Steam manuell und versuche es erneut.';

  @override
  String get steamSwitchBusy =>
      'Ein anderer Kontowechsel läuft bereits. Versuche es gleich noch einmal.';

  @override
  String get steamSwitchChanged =>
      'Die Steam-Einstellungen wurden während des Wechsels geändert. Beende Steam, lade die Liste neu und versuche es erneut.';

  @override
  String get steamSwitchFailed =>
      'Der Kontowechsel konnte nicht abgeschlossen werden. Prüfe Steam und versuche es erneut.';

  @override
  String get steamSwitchRecoveryNeeded =>
      'Der Kontowechsel ist fehlgeschlagen und einige Einstellungen konnten nicht wiederhergestellt werden. Bewahre die unten angegebene Sicherung auf und stelle die Einstellungen wieder her, bevor du es erneut versuchst.';

  @override
  String get appTitle => 'GooeSteamKit';

  @override
  String get navAccounts => 'Konten';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get unlockTitle => 'Entsperren';

  @override
  String get unlockPrompt => 'Gib dein Verschlüsselungspasswort ein';

  @override
  String get unlockButton => 'Entsperren';

  @override
  String get unlockInvalid => 'Dieses Passwort ist ungültig.';

  @override
  String get unlockWithBiometric => 'Mit Biometrie / Geräte-PIN entsperren';

  @override
  String get unlockLoading => 'Entschlüsseln…';

  @override
  String get unlockCantUnlock => 'Entsperren klappt nicht?';

  @override
  String get resetVaultTitle => 'Verschlüsselte Daten zurücksetzen';

  @override
  String get resetVaultBody =>
      'Löscht alle Kontoeinträge und Verschlüsselungsschlüssel auf diesem Gerät; danach importierst du deine maFile-Backups erneut. Deine Steam-Konten und die damit verknüpften Authentifikatoren bleiben unberührt.\n\nDafür gedacht, wenn die richtige PIN immer wieder abgelehnt wird — meist nach einer Backup-Wiederherstellung oder einem Gerätewechsel: Der Hardware-Schlüssel verlässt das ursprüngliche Gerät nie, wiederhergestellte Daten lassen sich deshalb nie entschlüsseln.\n\nDas lässt sich nicht rückgängig machen.';

  @override
  String get resetVaultConfirm => 'Löschen & zurücksetzen';

  @override
  String get storeErrorTitle => 'Gespeicherte Daten sind nicht lesbar';

  @override
  String get storeErrorBody =>
      'Die lokale Kontodatenbank von GooeSteamKit (manifest.json) fehlt oder ist beschädigt. Das kann nach einem abgebrochenen Schreibvorgang oder einer unvollständigen Wiederherstellung passieren. Versuch es zuerst erneut; scheitert es weiter, setze zurück und importiere deine maFile-Backups neu.';

  @override
  String get storeRepair => 'Reparatur versuchen';

  @override
  String storeActionFailed(String error) {
    return 'Aktion fehlgeschlagen: $error';
  }

  @override
  String get pinSetupTitle => 'Entsperr-PIN festlegen';

  @override
  String get pinSetupPrompt =>
      'Schütze GooeSteamKit mit einer 6-stelligen PIN. Zum Entsperren gibst du sie ein (oder nutzt deinen Fingerabdruck).';

  @override
  String get pinLabel => '6-stellige PIN';

  @override
  String get pinConfirmLabel => 'PIN bestätigen';

  @override
  String get pinSetButton => 'PIN festlegen';

  @override
  String get settingsSet => 'Festlegen';

  @override
  String get pinChangeTitle => 'PIN ändern';

  @override
  String get pinCurrentLabel => 'Aktuelle PIN';

  @override
  String get pinNewLabel => 'Neue PIN';

  @override
  String get pinSixDigits => 'Gib eine 6-stellige PIN ein.';

  @override
  String get pinMismatch => 'Die PINs stimmen nicht überein.';

  @override
  String get unlockBiometricReason => 'GooeSteamKit entsperren';

  @override
  String get settingsBiometric => 'Geräteentsperrung verwenden';

  @override
  String get settingsBiometricDesc =>
      'Bei aktiver Startprüfung können Fingerabdruck, Windows Hello oder der Gerätecode die GooeSteamKit-PIN ersetzen. Das Ausschalten der Startprüfung deaktiviert auch diese Option; danach muss sie separat wieder aktiviert werden.';

  @override
  String get settingsBiometricNeedPasskey =>
      'Lege zuerst ein Verschlüsselungspasswort fest.';

  @override
  String get settingsBiometricUnavailable =>
      'Auf diesem Gerät sind weder Biometrie noch eine Gerätesperre eingerichtet.';

  @override
  String get settingsBiometricEnabled => 'Geräteentsperrung aktiviert';

  @override
  String get settingsHoldConfirm => 'Zum Bestätigen halten';

  @override
  String get settingsHoldConfirmDesc =>
      'Unwiderrufliche Zusagen (Tauschangebote, Bestätigungen) verlangen langes Drücken. Ist das aus, wirkt ein einzelner Tipp sofort; Sammelaktionen fragen weiterhin nach.';

  @override
  String get settingsDeleteHold => 'Löschen nur per Halten';

  @override
  String get settingsDeleteHoldDesc =>
      'Der Löschen-Button im Bestätigungsdialog muss gehalten werden, bis er sich auflädt — ein versehentlicher Tipp entfernt kein Konto.';

  @override
  String get accountSessionInvalid =>
      'Anmeldung ungültig — zum erneuten Anmelden tippen';

  @override
  String get settingsHaptics => 'Haptisches Feedback';

  @override
  String get settingsHapticsDesc =>
      'Vibration beim Halten zum Bestätigen und wenn es fertig ist.';

  @override
  String get settingsBlockScreenshots => 'Screenshots blockieren';

  @override
  String get settingsBlockScreenshotsDesc =>
      'Versteckt GooeSteamKit vor Screenshots, Bildschirmaufnahmen und der Vorschau zuletzt geöffneter Apps. Dafür bleibt das Fenster beim Teilen des Bildschirms schwarz, und du kannst dem Feedback keine Screenshots mehr anhängen.';

  @override
  String get passkeyLabel => 'Passwort';

  @override
  String get accountsEmpty =>
      'Noch keine Konten. Importiere ein maFile oder melde dich an, um eins hinzuzufügen.';

  @override
  String get emptyAddAccount => 'Konto hinzufügen';

  @override
  String get accountReady => 'Bereit';

  @override
  String get tutCodeTitle => 'Live-Code';

  @override
  String get tutCodeBody =>
      'Tippe auf den großen Code, um ihn zu kopieren. Tippe auf den Kontonamen, um zwischen Benutzername / Nickname / SteamID zu wechseln.';

  @override
  String get tutSwipeRightTitle => 'Nach rechts → Bestätigungen';

  @override
  String get tutSwipeRightBody =>
      'Wisch ein Konto nach rechts, um seine Tauschbestätigungen zu öffnen.';

  @override
  String get tutSwipeLeftTitle => 'Nach links → mehr Aktionen';

  @override
  String get tutSwipeLeftBody =>
      'Wisch nach links, um die Sitzung zu erneuern, das maFile zu exportieren oder das Konto zu entfernen.';

  @override
  String get tutLongPressTitle => 'Lange drücken → Inventar & Markt';

  @override
  String get tutLongPressBody =>
      'Drück lange auf ein Konto, um sein Inventar zu durchsuchen und Gegenstände auf dem Community-Markt anzubieten.';

  @override
  String get tutPullTitle => 'Zum Aktualisieren ziehen';

  @override
  String get tutPullBody =>
      'Zieh die Kontoliste nach unten, um Avatare zu aktualisieren und offene Anmeldeanfragen zu prüfen.';

  @override
  String get tutSkip => 'Überspringen';

  @override
  String get tutNext => 'Weiter';

  @override
  String get tutDone => 'Verstanden';

  @override
  String get settingsTutorial => 'Gesten-Tutorial';

  @override
  String get settingsTutorialDesc =>
      'Spiel die Einführung zum Startbildschirm noch einmal ab (Wischen, langes Drücken, Ziehen zum Aktualisieren).';

  @override
  String get settingsTutorialReplay => 'Abspielen';

  @override
  String get welcomeTitle => 'Willkommen bei GooeSteamKit';

  @override
  String get welcomeSubtitle =>
      'Dein Authentifikator liegt verschlüsselt auf diesem Gerät. Wähle, wie du starten willst.';

  @override
  String get welcomeLoginCta => 'Bei Steam anmelden';

  @override
  String get welcomeLoginSub => 'Neuen Authentifikator einrichten';

  @override
  String get welcomeImportCta => '.maFile importieren';

  @override
  String get welcomeImportSub => 'Bestehendes Konto übernehmen';

  @override
  String get welcomeSyncCta => 'Aus Sync wiederherstellen';

  @override
  String get welcomeSyncSub =>
      'Konten aus einer bestehenden Sync-Bibliothek laden';

  @override
  String get copyCode => 'Code kopieren';

  @override
  String get codeCopied => 'Anmeldecode in die Zwischenablage kopiert';

  @override
  String get copied => 'In die Zwischenablage kopiert';

  @override
  String get copySteamId => 'SteamID kopieren';

  @override
  String get pendingTitle => 'Ausstehend';

  @override
  String get pendingTabConfirmations => 'Bestätigungen';

  @override
  String get pendingTabOffers => 'Angebote';

  @override
  String get confirmationsTitle => 'Bestätigungen';

  @override
  String get confirmationsEmpty => 'Keine offenen Bestätigungen.';

  @override
  String get confirmationsRefresh => 'Aktualisieren';

  @override
  String get confAccept => 'Annehmen';

  @override
  String get confDecline => 'Ablehnen';

  @override
  String get confSelectAll => 'Alle auswählen';

  @override
  String get confAcceptSelected => 'Auswahl annehmen';

  @override
  String get confDeclineSelected => 'Auswahl ablehnen';

  @override
  String get confAcceptAll => 'Alle annehmen';

  @override
  String get confRejectAll => 'Alle ablehnen';

  @override
  String confAcceptAllConfirm(int count) {
    return 'Alle Bestätigungen annehmen ($count)?';
  }

  @override
  String confRejectAllConfirm(int count) {
    return 'Alle Bestätigungen ablehnen ($count)?';
  }

  @override
  String get confAcceptAllWarn =>
      'Damit gibst du alle offenen Tauschangebote und Marktangebote auf einmal frei. Vergewissere dich, dass du jedes einzelne kennst.';

  @override
  String get confRejectAllWarn =>
      'Damit brichst du alle offenen Bestätigungen auf einmal ab.';

  @override
  String confPending(int count) {
    return '$count offen';
  }

  @override
  String get confAllProcessed => 'Alle erledigt';

  @override
  String get confTypeTrade => 'Tausch';

  @override
  String get confTypeMarket => 'Marktangebot';

  @override
  String get confTypeOther => 'Bestätigung';

  @override
  String get confTypeFamilyJoin => 'Familien-Einladung';

  @override
  String get confTypeApiKey => 'API-Schlüssel';

  @override
  String get confTypePhoneChange => 'Nummernwechsel';

  @override
  String get confTypeAccountRecovery => 'Kontowiederherstellung';

  @override
  String get confTypeFeatureOptOut => 'Opt-out';

  @override
  String confProcessing(int count) {
    return 'Verarbeite $count Bestätigung(en)…';
  }

  @override
  String confResult(int ok, int fail) {
    return '$ok erfolgreich, $fail fehlgeschlagen';
  }

  @override
  String get confNeedsLogin =>
      'Sitzung abgelaufen — melde dich erneut an, um dieses Konto zu aktualisieren.';

  @override
  String get confRejected =>
      'Steam hat die Bestätigungsanfrage abgelehnt. Meist passt das maFile nicht zu dem Authentifikator, der aktuell auf dem Konto liegt (häufig bei gekauften Konten) — entferne den Authentifikator und verknüpfe ihn neu, oder importiere das richtige maFile. Auch eine stark abweichende Uhrzeit kann das auslösen.';

  @override
  String get offersSegReceived => 'Erhalten';

  @override
  String get offersSegSent => 'Gesendet';

  @override
  String get offersSegHistory => 'Verlauf';

  @override
  String get offersEmpty => 'Keine Tauschangebote.';

  @override
  String get offerGift => 'Geschenk — du gibst nichts ab';

  @override
  String get offerOneSided => 'Du gibst Gegenstände ab und bekommst nichts';

  @override
  String get offerEscrow =>
      'Steam hält die Gegenstände vor der Übergabe zurück';

  @override
  String get offerAcceptHold => 'Annehmen (halten)';

  @override
  String get offerDecline => 'Ablehnen';

  @override
  String get offerCancel => 'Zurückziehen';

  @override
  String get offerReceiveLabel => 'Du erhältst';

  @override
  String get offerGiveLabel => 'Du gibst';

  @override
  String get offerAccepted =>
      'Angebot angenommen — bestätige es im Tab „Bestätigungen“';

  @override
  String get offerAcceptedNoConf => 'Angebot angenommen.';

  @override
  String offerActionFailed(String msg) {
    return 'Aktion fehlgeschlagen: $msg';
  }

  @override
  String get offerDeclined => 'Angebot abgelehnt.';

  @override
  String get offerCanceled => 'Angebot zurückgezogen.';

  @override
  String get pendingTabInvites => 'Einladungen';

  @override
  String famInviteTitle(String groupName) {
    return '„$groupName“ hat dich eingeladen';
  }

  @override
  String get famInviteTitleGeneric => 'Einladung zur Familiengruppe';

  @override
  String famInviteFrom(String inviter) {
    return 'Eingeladen von $inviter';
  }

  @override
  String famInviteRole(String role) {
    return 'Rolle: $role';
  }

  @override
  String famInviteSlots(int used, int total) {
    return 'Mitglieder $used/$total';
  }

  @override
  String get famRoleAdult => 'Erwachsener';

  @override
  String get famRoleChild => 'Kind';

  @override
  String famRoleUnknown(int n) {
    return 'Rolle #$n';
  }

  @override
  String get famPreflightTitle => 'Prüfungen vor dem Beitritt';

  @override
  String get famCheckWalletMatch => 'Guthaben-Region stimmt überein';

  @override
  String get famCheckWalletMismatch =>
      'Guthaben-Region weicht ab — Steam schränkt den Beitritt ein';

  @override
  String get famCheckIpMatch => 'Übliche IP stimmt überein';

  @override
  String get famCheckIpMismatch => 'IP passt nicht zu deinem üblichen Standort';

  @override
  String get famCheckCooldown =>
      'Nach dem Beitritt ist ein Wechsel der Familiengruppe 1 Jahr lang gesperrt (Steam-Sperrfrist)';

  @override
  String famJoinRestricted(int code) {
    return 'Steam hat den Beitritt blockiert (Einschränkung $code)';
  }

  @override
  String get famInviteJoinHold => 'Beitreten (halten)';

  @override
  String get famInviteAwaiting2fa =>
      'Warte auf Bestätigung — sieh im Tab „Bestätigungen“ nach';

  @override
  String get famInviteJoined => 'Beigetreten ✓';

  @override
  String get famInviteViewGroup => 'Familiengruppe ansehen ›';

  @override
  String get famJoinSent =>
      'Beitritt angefragt — bestätige ihn im Tab „Bestätigungen“';

  @override
  String get famJoinDone => 'Der Familiengruppe beigetreten.';

  @override
  String famJoinFailed(String msg) {
    return 'Beitritt fehlgeschlagen: $msg';
  }

  @override
  String get famInvitesEmpty => 'Keine offenen Familien-Einladungen.';

  @override
  String get famAccountAction => 'Familiengruppe';

  @override
  String get famNotInGroup => 'Dieses Konto ist in keiner Familiengruppe.';

  @override
  String famSummaryMembers(int used, int total) {
    return 'Mitglieder $used/$total';
  }

  @override
  String famSummaryCooldown(int days) {
    return 'Sperre: $days Tag(e)';
  }

  @override
  String get famInvitesSection => 'Einladungen';

  @override
  String get famSectionMembers => 'Mitglieder';

  @override
  String get famMemberYou => '(du)';

  @override
  String get famSectionPending => 'Ausstehend';

  @override
  String get famPendingComingSoon =>
      'Die Kauffreigabe kommt in einem späteren Update.';

  @override
  String get deviceSessionsAction => 'Geräte';

  @override
  String get deviceSessionsTitle => 'Angemeldete Geräte';

  @override
  String get deviceSessionsEmpty => 'Keine aktiven Geräte für dieses Konto.';

  @override
  String get deviceRevokeAction => 'Abmelden';

  @override
  String deviceRevokeConfirm(String name) {
    return '„$name“ von deinem Steam-Konto abmelden? Das Gerät muss sich danach neu anmelden.';
  }

  @override
  String deviceRevokeDone(String name) {
    return '„$name“ abgemeldet.';
  }

  @override
  String deviceRevokeFailed(String error) {
    return 'Gerät konnte nicht abgemeldet werden: $error';
  }

  @override
  String get deviceCurrent => '(dieses Gerät)';

  @override
  String get deviceSignedOut => 'abgemeldet';

  @override
  String get deviceUnnamed => 'Unbekanntes Gerät';

  @override
  String deviceLastSeen(String age) {
    return 'aktiv vor $age';
  }

  @override
  String get devicePlatformSteam => 'Steam-Client';

  @override
  String get devicePlatformWeb => 'Webbrowser';

  @override
  String get devicePlatformMobile => 'Mobile App';

  @override
  String get devicePlatformUnknown => 'Unbekannt';

  @override
  String deviceAgeDays(int n) {
    return '$n Tg.';
  }

  @override
  String deviceAgeHours(int n) {
    return '$n Std.';
  }

  @override
  String deviceAgeMinutes(int n) {
    return '$n Min.';
  }

  @override
  String get deviceAgeNow => 'Kurzem';

  @override
  String get keyRedeemAction => 'Code einlösen';

  @override
  String get keyRedeemTitle => 'Steam-Produktcode einlösen';

  @override
  String keyRedeemFor(String account) {
    return 'Wird auf $account aktiviert';
  }

  @override
  String get keyRedeemHint => 'XXXXX-XXXXX-XXXXX';

  @override
  String get keyRedeemPaste => 'Einfügen';

  @override
  String get keyRedeemSubmit => 'Einlösen';

  @override
  String get keyRedeemNote =>
      'Die Aktivierung ist endgültig und fügt das Produkt diesem Konto hinzu. Nach ein paar abgelehnten Codes sperrt Steam Aktivierungen für etwa eine Stunde — prüf den Code also vor dem Absenden.';

  @override
  String keyRedeemConfirm(String account) {
    return 'Diesen Code auf $account aktivieren? Das lässt sich danach nicht rückgängig machen und nicht auf ein anderes Konto übertragen.';
  }

  @override
  String get keyRedeemDone => 'Code aktiviert.';

  @override
  String get keyRedeemGranted => 'Zur Bibliothek hinzugefügt:';

  @override
  String get keyRedeemNoProducts =>
      'Steam hat den Code angenommen, aber kein Produkt genannt. Sieh in der Bibliothek des Kontos nach.';

  @override
  String get keyRedeemNetworkError =>
      'Steam ist nicht erreichbar. Bei einer Zeitüberschreitung kann Steam die Anfrage trotzdem verarbeitet haben — prüf die Bibliothek des Kontos, bevor du den Code erneut einlöst.';

  @override
  String get keyErrInvalid =>
      'Steam kennt diesen Code nicht. Prüf ihn auf Tippfehler — Zeichen wie 0/O und 1/I verwechselt man leicht.';

  @override
  String get keyErrAlreadyOwned => 'Dieses Konto besitzt das Produkt bereits.';

  @override
  String get keyErrAlreadyActivated =>
      'Dieser Code wurde bereits benutzt — auf diesem oder einem anderen Konto.';

  @override
  String get keyErrRegionLocked =>
      'Dieses Produkt lässt sich im Land des Kontos nicht aktivieren.';

  @override
  String get keyErrNeedsBaseProduct =>
      'Das ist ein DLC oder eine Erweiterung; das Konto braucht zuerst das Hauptspiel.';

  @override
  String get keyErrNeedsPs3Login =>
      'Dieses Produkt muss erst auf einer PlayStation®3 gespielt werden, bevor es aktiviert werden kann.';

  @override
  String get keyErrRateLimited =>
      'Zuletzt wurden zu viele Codes abgelehnt. Steam sperrt Aktivierungen für etwa eine Stunde — versuch es später erneut.';

  @override
  String keyErrUnknown(int code) {
    return 'Steam hat den Produktcode abgelehnt (Fehler $code).';
  }

  @override
  String get loginOrApprove =>
      '…oder tipp einfach in der Steam-App auf „Erlauben“.';

  @override
  String get addErrPresent => 'Dieses Konto hat bereits einen Authentifikator.';

  @override
  String get addErrConfirmEmail =>
      'Bestätige bitte die E-Mail von Steam und versuch es dann erneut.';

  @override
  String get addErrLocked =>
      'Dieses Konto ist von Steam gesperrt oder eingeschränkt — stell es erst unter help.steampowered.com wieder her, bevor du einen Authentifikator hinzufügst.';

  @override
  String get addErrRateLimited =>
      'Zu viele Versuche. Warte bitte eine Weile und versuch es erneut.';

  @override
  String get addErrFailed => 'Authentifikator konnte nicht hinzugefügt werden.';

  @override
  String addErrSaveFailed(String code) {
    return 'Der Authentifikator konnte auf diesem Gerät nicht gespeichert werden, deshalb wurde die Einrichtung gestoppt, bevor sie wirksam wurde. Schreib diesen Widerrufscode auf, entferne den ausstehenden Authentifikator aus deinem Konto und versuch es dann erneut: $code';
  }

  @override
  String get addErrBadSms => 'Falscher SMS-Code, bitte versuch es erneut.';

  @override
  String get debugLog => 'Debug-Log';

  @override
  String get debugLogDesc =>
      'Netzwerkmitschnitt zur Diagnose von Anmeldung / Bestätigungen';

  @override
  String get feedbackTitle => 'Feedback';

  @override
  String get feedbackDesc =>
      'Bug gefunden oder eine Idee? Schick sie direkt an den Entwickler, oder eröffne ein GitHub-Issue für die öffentliche Diskussion.';

  @override
  String get feedbackSend => 'Feedback senden';

  @override
  String get feedbackMessageLabel => 'Dein Feedback';

  @override
  String get feedbackMessageHint => 'Was ist kaputt / was wünschst du dir?';

  @override
  String get feedbackContactLabel => 'Kontakt (optional)';

  @override
  String get feedbackContactHint =>
      'E-Mail oder Benutzername — nur wenn du eine Antwort willst';

  @override
  String feedbackAttachNote(String meta) {
    return 'Wird mitgeschickt: $meta';
  }

  @override
  String get feedbackSent => 'Feedback gesendet — danke!';

  @override
  String get feedbackFailed =>
      'Senden fehlgeschlagen. Prüf dein Netzwerk und versuch es erneut.';

  @override
  String feedbackRefused(String reason) {
    return 'Der Weiterleitungsdienst hat diesen Bericht abgelehnt: $reason';
  }

  @override
  String feedbackRelayDown(String reason) {
    return 'Der Feedback-Dienst hat gerade selbst ein Problem ($reason). An deinem Netzwerk liegt es nicht — bitte versuch es später erneut.';
  }

  @override
  String get feedbackAttachLog => 'Debug-Log anhängen';

  @override
  String get feedbackAttachLogHint =>
      'Aktueller Netzwerkmitschnitt; kann Kontonamen / SteamIDs enthalten';

  @override
  String get feedbackLogConsentBody =>
      'Das Debug-Log enthält die letzten Zeilen des Netzwerkmitschnitts dieser Sitzung. Darin können deine Kontonamen und SteamIDs stehen — niemals deine Secrets, Tokens oder Passwörter. Es wird nur zusammen mit diesem Bericht gesendet, wie in der Datenschutzerklärung beschrieben.';

  @override
  String get feedbackLogConsentAgree => 'Zustimmen';

  @override
  String get backupReminderTitle => 'Backup nicht vergessen';

  @override
  String get backupReminderBody =>
      'GooeSteamKit hält deine Authentifikator-Daten nur auf diesem Gerät. Sichere deine maFiles an einem sicheren Ort. Dein Widerrufscode (R-Code) wird nur ein einziges Mal angezeigt, nämlich wenn du einen Authentifikator hinzufügst — schreib ihn dann auf und heb ihn auf; er ist dein letztes Mittel, um den Authentifikator zu entfernen, falls dieses Gerät je verloren geht.';

  @override
  String get backupReminderOk => 'Verstanden';

  @override
  String get debugCopyAll => 'Alles kopieren';

  @override
  String get debugCopied => 'Log kopiert';

  @override
  String get debugEmpty => 'Noch kein Log.';

  @override
  String get commonOpen => 'Öffnen';

  @override
  String get commonClear => 'Leeren';

  @override
  String addErrFinalize(String detail) {
    return 'Abschluss fehlgeschlagen: $detail';
  }

  @override
  String get loginTitle => 'Bei Steam anmelden';

  @override
  String get loginUsername => 'Benutzername';

  @override
  String get loginPassword => 'Passwort';

  @override
  String get loginShowPassword => 'Passwort anzeigen';

  @override
  String get loginHidePassword => 'Passwort verbergen';

  @override
  String get loginSavePassword => 'Passwort speichern';

  @override
  String get loginSavePasswordHint =>
      'Wird im maFile dieses Kontos gespeichert, um die Sitzung automatisch zu erneuern; ein unverschlüsselter Export enthält es.';

  @override
  String get loginButton => 'Anmelden';

  @override
  String get loginErrInvalidPassword =>
      'Falscher Kontoname oder falsches Passwort.';

  @override
  String get loginErrRateLimited =>
      'Zu viele Versuche — warte bitte eine Weile und versuch es erneut.';

  @override
  String get loginErrCodeMismatch =>
      'Der Code passt nicht — prüf ihn und versuch es erneut.';

  @override
  String get loginViaQr => 'Mit QR-Code anmelden';

  @override
  String get loginViaCredentials => 'Mit Passwort anmelden';

  @override
  String get loginScanWithApp => 'Scanne diesen Code mit der Steam-App';

  @override
  String get loginNeedGuardCode => 'Gib den Steam Guard-Code ein';

  @override
  String get loginNeedEmailCode => 'Gib den Code aus deiner E-Mail ein';

  @override
  String get loginSubmitCode => 'Absenden';

  @override
  String get loginWaiting => 'Warte auf Bestätigung…';

  @override
  String get loginStepCredentials => 'Anmeldedaten';

  @override
  String get loginStepConfirm => 'Bestätigen';

  @override
  String get loginStepDone => 'Fertig';

  @override
  String get loginWaitingDesc =>
      'Bestätige diese Anmeldung in der Steam-App. Du kannst auch einen E-Mail-Code oder die QR-Anmeldung nutzen.';

  @override
  String loginFailed(String error) {
    return 'Anmeldung fehlgeschlagen: $error';
  }

  @override
  String get approveTitle => 'Anmeldung bestätigen';

  @override
  String get approveScanPrompt =>
      'Scanne den QR-Code, der auf dem Gerät angezeigt wird, das du anmelden willst.';

  @override
  String get approvePastePrompt => 'Oder füg den QR-Code-Link hier ein';

  @override
  String get approveButton => 'Bestätigen';

  @override
  String get approveReject => 'Ablehnen';

  @override
  String get approveSuccess => 'Anmeldung bestätigt.';

  @override
  String get approveRejected => 'Anmeldung abgelehnt.';

  @override
  String get approveBadCode => 'Das ist kein QR-Code für eine Steam-Anmeldung.';

  @override
  String get approveLocation => 'Ort';

  @override
  String get approveDevice => 'Gerät';

  @override
  String get approveWarnStranger =>
      'Diese Anmeldung nicht selbst gestartet? Lehn sie ab.';

  @override
  String get importTitle => 'Konto importieren';

  @override
  String get importPickFile => '.maFile auswählen';

  @override
  String get importSuccess => 'Konto importiert.';

  @override
  String importFailed(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String get importDuplicateTitle => 'Konto existiert bereits';

  @override
  String importDuplicateBody(String name) {
    return 'Dieses maFile gehört zu $name, und das Konto liegt schon auf diesem Gerät. Das gespeicherte Konto mit der importierten Datei überschreiben? Zwischengespeicherter Avatar, gespeichertes Passwort und die bestehende Sitzung bleiben erhalten, solange die Datei sie nicht selbst enthält.';
  }

  @override
  String importDuplicateBodyUnreadable(String name) {
    return 'Dieses maFile gehört zu $name. Das Konto liegt auf diesem Gerät, seine gespeicherten Daten sind aber nicht mehr lesbar. Der Import ersetzt es vollständig.';
  }

  @override
  String get importDuplicateOverwrite => 'Überschreiben';

  @override
  String get importSessionDeadTitle => 'Dieses Konto aktivieren?';

  @override
  String get importSessionDeadBody =>
      'Die Steam-Sitzung in diesem maFile ist abgelaufen. Melde dich jetzt an, um Bestätigungen und Anmeldefreigaben zu nutzen — der Steam Guard-Code wird automatisch eingetragen.';

  @override
  String get importSessionLater => 'Später';

  @override
  String get sdaImportAction => 'SDA-Ordner importieren';

  @override
  String get sdaImportHint =>
      'Wähle mehrere .maFile-Dateien zum Importieren. Für unverschlüsselte Dateien ist manifest.json optional. Wähle bei verschlüsselten SDA-Dateien auch manifest.json aus; sie enthält die Entschlüsselungsparameter.';

  @override
  String get sdaImportNoManifest =>
      'In dieser Auswahl ist keine manifest.json. Wähle sie zusammen mit den .maFile-Dateien aus.';

  @override
  String sdaImportBadManifest(String error) {
    return 'Diese manifest.json lässt sich nicht lesen: $error';
  }

  @override
  String get sdaImportPassTitle => 'SDA-Verschlüsselungspasswort';

  @override
  String get sdaImportPassBody =>
      'Diese maFiles sind verschlüsselt. Gib das Passwort ein, das du in Steam Desktop Authenticator gesetzt hast.';

  @override
  String get sdaImportWrongPass =>
      'Mit diesem Passwort ließ sich keine der Dateien entschlüsseln.';

  @override
  String sdaImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten importiert.',
      one: '1 Konto importiert.',
    );
    return '$_temp0';
  }

  @override
  String sdaImportSkipped(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten übersprungen: $names',
      one: '1 Konto übersprungen: $names',
    );
    return '$_temp0';
  }

  @override
  String get sdaImportNothing => 'Es wurde nichts importiert.';

  @override
  String updateAvailable(String version) {
    return 'Version $version ist verfügbar';
  }

  @override
  String get updateView => 'Ansehen';

  @override
  String get updateDismiss => 'Überspringen';

  @override
  String get settingsUpdateCheck => 'Beim Start nach Updates suchen';

  @override
  String get settingsUpdateCheckDesc =>
      'Eine Anfrage an den Versions-Endpunkt pro Start. Keine Kontodaten; der Endpunkt führt keine Logs.';

  @override
  String get importSessionLoginNow => 'Jetzt anmelden';

  @override
  String get actionExport => 'maFile exportieren';

  @override
  String get actionLoginRequests => 'Anmeldeanfragen';

  @override
  String get loginRequestTitle => 'Anmeldung erlauben?';

  @override
  String loginRequestBody(String device, String location) {
    return '$device meldet sich gerade von $location bei deinem Steam-Konto an.';
  }

  @override
  String get loginRequestApprove => 'Erlauben';

  @override
  String get loginRequestDeny => 'Verweigern';

  @override
  String get loginNoPending => 'Keine offenen Anmeldeanfragen.';

  @override
  String get loginNeedSession =>
      'Melde dich zuerst an, um die Sitzung dieses Kontos zu erneuern.';

  @override
  String get loginApproved => 'Anmeldung erlaubt.';

  @override
  String get loginDenied => 'Anmeldung verweigert.';

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get exportWarnTitle => 'Unverschlüsseltes maFile exportieren?';

  @override
  String get exportWarnBody =>
      'Das exportierte .maFile ist NICHT verschlüsselt. Es enthält die Steam Guard-Secrets und den Widerrufscode dieses Kontos — wer die Datei hat, kann deinen Authentifikator übernehmen. Bewahr sie sicher auf und lösch sie, wenn du fertig bist.';

  @override
  String get exportIncludePassword =>
      'Auch das gespeicherte Steam-Passwort mitexportieren (nicht empfohlen)';

  @override
  String get addAuthTitle => 'Authentifikator hinzufügen';

  @override
  String get addAuthPhonePrompt =>
      'Gib deine Telefonnummer ein (mit Ländervorwahl)';

  @override
  String get addAuthSmsPrompt => 'Gib den SMS-Code ein, den du bekommen hast';

  @override
  String get addAuthEmailPrompt =>
      'Gib den Aktivierungscode aus der Steam-E-Mail ein';

  @override
  String addAuthRevocationWarn(String code) {
    return 'Schreib deinen Widerrufscode auf: $code';
  }

  @override
  String get addAuthConfirmRevocation =>
      'Gib den Widerrufscode erneut ein, um zu bestätigen, dass du ihn gesichert hast';

  @override
  String get addAuthLinked => 'Authentifikator erfolgreich verknüpft.';

  @override
  String get addAuthStepPhone => 'Telefon';

  @override
  String get addAuthStepSms => 'Aktivieren';

  @override
  String get addAuthStepRevocation => 'Widerruf';

  @override
  String get addPresentTitle =>
      'Dieses Konto hat bereits einen Authentifikator';

  @override
  String get addPresentIntro =>
      'Steam erlaubt nur einen mobilen Authentifikator pro Konto. Entferne den vorhandenen und tipp dann auf „Erneut versuchen“.';

  @override
  String get addPresentStep1 =>
      'Altes Handy oder die Steam-App noch da? Dort öffnen → Steam Guard → Authentifikator entfernen.';

  @override
  String get addPresentStep2 =>
      'Widerrufscode (Rxxxxx) zur Hand? Öffne die Seite unten und wähle „Authentifikator entfernen“.';

  @override
  String get addPresentStep3 =>
      'Auf beides kein Zugriff? Über Steam-Support → Hilfe → Steam Guard Mobil-Authentifikator.';

  @override
  String get addPresentManageUrl => 'store.steampowered.com/twofactor/manage';

  @override
  String get addPresentCopiedUrl => 'Link kopiert';

  @override
  String get addPresentFallbackTitle => 'Keine E-Mail bekommen?';

  @override
  String get addMoveInButton => 'Authentifikator auf dieses Gerät holen';

  @override
  String get addMoveInBlurb =>
      'Steam schickt diesem Konto einen Code per E-Mail. Keine 15-tägige Handelssperre.';

  @override
  String get addMoveInSending => 'Code wird gesendet…';

  @override
  String get addMoveInCodePrompt => 'Gib den Code aus der Steam-E-Mail ein';

  @override
  String get addMoveInWarn =>
      'Sobald du bestätigst: Der Authentifikator auf deinem alten Handy funktioniert sofort nicht mehr, und dein alter Widerrufscode (Rxxxxx) wird durch einen neuen ersetzt. Das lässt sich nicht rückgängig machen.';

  @override
  String get addMoveInConfirm => 'Hierher holen';

  @override
  String get addMoveInDone => 'Authentifikator ist jetzt auf diesem Gerät.';

  @override
  String get addMoveInPopBlocked =>
      'Authentifikator wird umgezogen — bitte warten.';

  @override
  String get addErrBadChallengeCode =>
      'Dieser Code stimmt nicht. Prüf die E-Mail und versuch es erneut.';

  @override
  String addMoveInSaveFailed(String code, String secret) {
    return 'Der Authentifikator wurde zu diesem Konto umgezogen, aber GooeSteamKit konnte ihn NICHT auf diesem Gerät speichern. Dein alter Authentifikator ist bereits tot, das hier sind die einzigen Kopien — schreib sie JETZT auf, bevor du diesen Bildschirm schließt.\n\nWiderrufscode: $code\n\nSecret: $secret';
  }

  @override
  String get addMoveInCopySecrets => 'Kopieren';

  @override
  String get addMoveInCopied => 'Kopiert';

  @override
  String get moveInRescueDismiss => 'Gesichert — schließen';

  @override
  String get moveInRescueDismissTitle => 'Diese Secrets verwerfen?';

  @override
  String get moveInRescueDismissBody =>
      'GooeSteamKit hat keine andere Kopie. Wenn du Widerrufscode und Secret nicht aufgeschrieben hast, verlierst du den Zugang zu diesem Authentifikator für immer.';

  @override
  String get moveInRescueDismissConfirm => 'Ich habe sie gesichert';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonCopy => 'Link kopieren';

  @override
  String get commonRefresh => 'Neu laden';

  @override
  String get commonExport => 'Export';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get settingsEncryption => 'Verschlüsselung';

  @override
  String get settingsEncryptionDesc =>
      'Deine lokalen maFiles sind mit einem zufälligen 256-Bit-Schlüssel (AES-256-GCM) verschlüsselt, der im Keystore des Geräts liegt; deine 6-stellige PIN schaltet ihn frei.';

  @override
  String get settingsThemeDesc => 'Wechselt den gesamten UI-Stil.';

  @override
  String get settingsAppearance => 'Erscheinungsbild';

  @override
  String get settingsAppearanceDesc =>
      'Hell oder dunkel für den Standard-Look. Ein aktiver Skin setzt das außer Kraft.';

  @override
  String get settingsTextSize => 'Textgröße';

  @override
  String get settingsTextSizeDesc =>
      'Wirkt zusätzlich zur Schriftgröße des Systems.';

  @override
  String get textSizeSmall => 'Klein';

  @override
  String get textSizeMedium => 'Mittel';

  @override
  String get textSizeLarge => 'Groß';

  @override
  String get settingsSkin => 'Skins';

  @override
  String get settingsSkinDesc =>
      'Durchgestaltete Looks mit eigenen Schriften und Effekten.';

  @override
  String get themeSystem => 'System';

  @override
  String get skinNone => 'Ohne';

  @override
  String get settingsChange => 'Ändern';

  @override
  String get settingsSetPasskey => 'Verschlüsselungspasswort setzen / ändern';

  @override
  String get settingsAutoConfirmMarket =>
      'Marktverkäufe automatisch bestätigen';

  @override
  String get settingsAutoConfirmMarketDesc =>
      'Setzt beim Einstellen eines Gegenstands den Haken zum Bestätigen vorab, sodass ein neues Angebot direkt nach dem Erstellen bestätigt wird. Im Hintergrund wird nie etwas bestätigt.';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'Systemsprache';

  @override
  String get settingsTheme => 'Design';

  @override
  String get themeNeon => 'Neon';

  @override
  String get themePixel => 'Pixel';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeLight => 'Hell';

  @override
  String get settingsAbout => 'Über GooeSteamKit';

  @override
  String get aboutTagline =>
      'Ein quelloffener Steam Guard-Authentifikator, gebaut mit Flutter.';

  @override
  String get aboutSourceCode => 'Quellcode';

  @override
  String get aboutAuthor => 'Autor';

  @override
  String get aboutLicense => 'Lizenz';

  @override
  String get aboutPrivacy => 'Datenschutzerklärung';

  @override
  String get privacyConsentTitle => 'Dein Datenschutz';

  @override
  String get privacyConsentBody =>
      'AVA behält deine Steam-Konten und Geheimnisse auf diesem Gerät — hochgeladen wird nie etwas, außer du richtest die optionale Synchronisierung mit einem Server deiner Wahl ein, und auch dann wird alles zuerst auf diesem Gerät verschlüsselt. Kein Konto nötig. Steam-Anfragen gehen direkt an Valve. Zwei Dienste des Entwicklers werden nur bei Bedarf kontaktiert: Pro-Berechtigungsprüfung und Feedback (nur wenn du auf Senden tippst). Die Play-Version zeigt in der Gratis-Stufe außerdem Werbung. Kein Tracking, keine Analyse. All das steht in der Datenschutzerklärung — mit dem Fortfahren akzeptierst du sie.';

  @override
  String get privacyUpdateTitle => 'Datenschutzerklärung aktualisiert';

  @override
  String get privacyUpdateBody =>
      'Der Datenschutzhinweis hat sich geändert, seit du zugestimmt hast. Neu: GooeSteamKit kann deine Kontobibliothek jetzt über einen Server deiner Wahl zwischen deinen Geräten synchronisieren — standardmäßig aus, alles wird vor dem Upload auf diesem Gerät verschlüsselt, und der Entwickler betreibt keinen Sync-Server. Bitte lies den aktuellen Hinweis unten.';

  @override
  String get privacyConsentScrollHint => 'Zum Fortfahren bis zum Ende scrollen';

  @override
  String get privacyConsentRead => 'Vollständige Datenschutzerklärung lesen';

  @override
  String get privacyConsentAgree => 'Zustimmen & weiter';

  @override
  String get privacyConsentExit => 'Beenden';

  @override
  String get actionMarket => 'Inventar / Markt';

  @override
  String get marketTabInventory => 'Inventar';

  @override
  String get marketTabListings => 'Meine Angebote';

  @override
  String get marketSelectGame => 'Spiel auswählen';

  @override
  String get marketNoItems => 'Keine Gegenstände in diesem Inventar.';

  @override
  String get marketNotMarketable => 'Nicht marktfähig';

  @override
  String get marketSellTitle => 'Zum Verkauf anbieten';

  @override
  String get marketYouReceive => 'Du erhältst';

  @override
  String get marketBuyerPays => 'Käufer zahlt';

  @override
  String get marketLowest => 'Tiefstpreis';

  @override
  String get marketMedian => 'Median';

  @override
  String get marketHigh => 'Hoch';

  @override
  String get marketLow => 'Tief';

  @override
  String get marketPriceUnavailable => 'Marktpreis nicht verfügbar';

  @override
  String get marketListButton => 'Angebot einstellen';

  @override
  String get marketListed => 'Eingestellt — bestätige es zum Abschluss.';

  @override
  String get marketListedDone => 'Eingestellt und bestätigt.';

  @override
  String marketListedPartial(int listed, int total) {
    return '$listed von $total eingestellt — der Rest ist fehlgeschlagen; offene Punkte unter „Bestätigungen“ abschließen.';
  }

  @override
  String marketListedSessionExpired(int listed, int total) {
    return '$listed von $total eingestellt, dann lief die Sitzung ab — melde dich erneut an und bestätige sie.';
  }

  @override
  String marketConfirmPartial(int ok, int total) {
    return 'Eingestellt — $ok von $total bestätigt; den Rest unter „Bestätigungen“ abschließen.';
  }

  @override
  String get marketAutoConfirm => 'Angebot automatisch bestätigen';

  @override
  String get marketQuantity => 'Anzahl';

  @override
  String get marketMax => 'Max';

  @override
  String marketListFailed(String error) {
    return 'Einstellen fehlgeschlagen: $error';
  }

  @override
  String get marketInvalidPrice => 'Gib einen gültigen Preis ein.';

  @override
  String get marketCancel => 'Angebot zurückziehen';

  @override
  String get marketCancelled => 'Angebot zurückgezogen.';

  @override
  String get marketNoListings => 'Keine aktiven Angebote.';

  @override
  String get marketFeeNote =>
      'Steam- und Spielgebühren kommen auf deinen Auszahlungsbetrag obendrauf.';

  @override
  String get aboutLicenses => 'Open-Source-Lizenzen';

  @override
  String get aboutCredits => 'Danksagungen';

  @override
  String get aboutCreditsBody =>
      'Inspiriert vom Steam Desktop Authenticator und kompatibel mit dessen maFile-Format. Unabhängig gebaut mit Flutter, Riverpod, Dio, PointyCastle, mobile_scanner, image und weiteren Open-Source-Bibliotheken.';

  @override
  String get actionLogin => 'Anmelden / Sitzung erneuern';

  @override
  String get actionConfirmations => 'Ausstehend';

  @override
  String get actionRemove => 'Konto entfernen';

  @override
  String get actionImport => 'Importieren';

  @override
  String get actionAddAuthenticator => 'Authentifikator hinzufügen';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonOk => 'OK';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonError => 'Fehler';

  @override
  String get sessionExpired =>
      'Deine Steam-Sitzung ist abgelaufen. Bitte melde dich erneut an.';

  @override
  String get removeConfirm =>
      'Dieses Konto von diesem Gerät entfernen? Stell sicher, dass du ein Backup deines maFiles hast.';

  @override
  String get settingsPro => 'AVA Pro';

  @override
  String get proOpen => 'AVA Pro ansehen';

  @override
  String get proStatusFree => 'Kostenlose Version';

  @override
  String proStatusPro(Object date) {
    return 'Pro · bis $date';
  }

  @override
  String proStatusVip(Object date) {
    return 'VIP · bis $date';
  }

  @override
  String get proStatusLifetime => 'Pro · lebenslang';

  @override
  String proStatusActivations(Object classes) {
    return 'Aktiv auf: $classes';
  }

  @override
  String proStatusClassThisDevice(Object name) {
    return '$name (dieses Gerät)';
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
      'Pro-Vorteile — die zentralen Sicherheitsfunktionen bleiben für immer kostenlos.';

  @override
  String get paywallPerkSkins => 'Theme-Pakete: Neon- und Pixel-Skin';

  @override
  String get paywallPerkNoAds => 'Keine Banner-Werbung';

  @override
  String get paywallPerkFuture =>
      'Später: Cloud-Sync, Handelsbenachrichtigungen';

  @override
  String get paywallPlayTitle => 'Über Google Play freischalten';

  @override
  String get paywallSubscribe => 'Abo · 0,99 \$/Monat';

  @override
  String get paywallWatchAd => 'Werbung ansehen · 3 Tage VIP';

  @override
  String get paywallRestore => 'Kauf wiederherstellen';

  @override
  String get paywallCnTitle => 'Über Afdian freischalten';

  @override
  String get paywallAfdianIntro =>
      'Unterstütze Afdian mit 5 ¥/Monat und gib dann die Bestellnummer hier ein, um freizuschalten.';

  @override
  String get paywallOpenAfdian => 'Afdian öffnen';

  @override
  String get paywallOrderHint => 'Afdian-Bestellnummer';

  @override
  String get paywallRedeem => 'Freischalten';

  @override
  String get paywallBetaTitle => 'Danke fürs Testen';

  @override
  String get paywallBetaIntro =>
      'Beta-Tester bekommen Pro auf Lebenszeit — gib deinen Code ein.';

  @override
  String get paywallBetaHint => 'Lebenszeit-Code';

  @override
  String get paywallBetaRedeem => 'Einlösen';

  @override
  String get proResultSuccess => 'Freigeschaltet — danke!';

  @override
  String get proErrCanceled => 'Abgebrochen.';

  @override
  String get proErrNetwork => 'Netzwerkfehler — versuch es später erneut.';

  @override
  String get proErrNotConfigured => 'In dieser Version noch nicht verfügbar.';

  @override
  String get proErrNoSubscription =>
      'Kein aktives Abo auf dem aktuellen Play-Store-Konto. Mit einem anderen Google-Konto abonniert? Wechsle im Play Store (Avatar oben rechts) zu diesem Konto und versuch es erneut.';

  @override
  String get proErrAlreadyOwned =>
      'Das aktuelle Play-Store-Konto hat dieses Abo bereits — tippe stattdessen auf „Kauf wiederherstellen“.';

  @override
  String get proErrOrderBound =>
      'Diese Bestellung ist bereits an jemand anderen gebunden.';

  @override
  String get proErrOrderNotFound =>
      'Bestellung nicht gefunden oder Tarif passt nicht.';

  @override
  String get proErrDeviceRevoked =>
      'Der Platz dieses Geräts wurde von einer neueren Aktivierung übernommen.';

  @override
  String get proErrNoVip =>
      'Belohnung noch nicht bestätigt — versuch es in einer Minute erneut.';

  @override
  String get proErrPurchaseBound =>
      'Dieses Abo gehört zu einem anderen Google-Konto. Versuch es erneut und wähle im Kontodialog das Konto, das dein Play Store verwendet.';

  @override
  String proErrPurchaseBoundKnown(String account) {
    return 'Dieses Abo gehört zu $account. Versuch es erneut und wähle dieses Konto aus.';
  }

  @override
  String proErrGeneric(Object code) {
    return 'Fehlgeschlagen: $code';
  }

  @override
  String get proErrCodeInvalid =>
      'Code nicht erkannt — prüf ihn auf Tippfehler.';

  @override
  String get proErrCodeRedeemed =>
      'Dieser Code ist bereits auf einem anderen Gerät aktiv. Zum Umziehen schreib an hi@dotslash.pro.';

  @override
  String get proErrCodeActivationLimit =>
      'Dieser Code hat in letzter Zeit zu oft das Gerät gewechselt. Versuch es später erneut oder schreib an hi@dotslash.pro.';

  @override
  String get proErrRateLimited =>
      'Zu viele Versuche. Warte eine Minute und versuch es erneut.';

  @override
  String proErrSlotOccupied(Object slots) {
    return 'Belegt: $slots';
  }

  @override
  String proSlotEntry(Object name, Object time) {
    return '$name ($time)';
  }

  @override
  String get proSlotToday => 'heute';

  @override
  String proSlotDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'vor $n Tagen',
      one: 'vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get proErrRevoked =>
      'Diese Berechtigung ist nicht mehr aktiv. Wenn das ein Fehler ist, schreib an hi@dotslash.pro.';

  @override
  String get privacyOptions => 'Datenschutzoptionen';

  @override
  String get skinProNotice =>
      'Neon- und Pixel-Skin sind jetzt Pro-Vorteile. Deine Auswahl bleibt gespeichert und kommt mit Pro zurück.';

  @override
  String get skinProNoticeDismiss => 'Verstanden';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncSetupTitle => 'Sync einrichten';

  @override
  String get syncSettingsDesc =>
      'Hält deine Konten über einen Server, den du selbst kontrollierst, auf mehreren Geräten synchron. Alles wird verschlüsselt, bevor es dieses Gerät verlässt.';

  @override
  String get syncSetUp => 'Sync einrichten…';

  @override
  String get syncStatusOk => 'Auf dem neuesten Stand';

  @override
  String get syncStatusSyncing => 'Synchronisiere…';

  @override
  String get syncStatusErrorShort =>
      'Letzter Sync fehlgeschlagen — öffnen für Details.';

  @override
  String syncStatusConflicts(int count) {
    return '$count Konflikt(e) warten auf deine Entscheidung';
  }

  @override
  String syncLastSync(String time) {
    return 'Letzter Sync: $time';
  }

  @override
  String get syncNever => 'nie';

  @override
  String get syncBackendTitle => 'Wo sollen die Daten liegen?';

  @override
  String get syncBackendWebdav => 'WebDAV';

  @override
  String get syncBackendWebdavDesc =>
      'Nextcloud, Jianguoyun (坚果云), ein NAS — jeder WebDAV-Ordner, den du kontrollierst.';

  @override
  String get syncBackendGdrive => 'Google Drive';

  @override
  String get syncBackendGdriveSoon => 'Pro · kommt später';

  @override
  String get syncServerTitle => 'Server';

  @override
  String get syncServerHint =>
      'Jianguoyun braucht ein App-Passwort (安全选项 → 添加应用密码), nicht dein Anmeldepasswort. Eine Nextcloud-Ordner-URL sieht so aus: https://cloud.example.com/remote.php/dav/files/BENUTZER/ava/.';

  @override
  String get syncServerUrlLabel => 'WebDAV-Ordner-URL';

  @override
  String get syncServerFolderLabel => 'Ordner (optional)';

  @override
  String get syncServerFolderHint =>
      'Leer lassen, um die URL unverändert zu verwenden; ein Name legt die Bibliothek in diesem Unterordner ab und erstellt ihn bei Bedarf.';

  @override
  String get syncServerUserLabel => 'Benutzername';

  @override
  String get syncServerPasswordLabel => 'Passwort / App-Passwort';

  @override
  String get syncTestConnection => 'Verbindung testen';

  @override
  String get syncErrUrl => 'Gib eine gültige http(s)-Ordner-URL ein.';

  @override
  String get syncErrAuth =>
      'Der Server hat Benutzername oder Passwort abgelehnt.';

  @override
  String syncErrNetwork(String detail) {
    return 'Server nicht erreichbar: $detail';
  }

  @override
  String syncErrServer(String detail) {
    return 'Der Server hat mit einem Fehler geantwortet: $detail';
  }

  @override
  String get syncErrTls => 'Dem Zertifikat des Servers wird nicht vertraut.';

  @override
  String get syncTlsTitle => 'Unbekanntes Serverzertifikat';

  @override
  String syncTlsBody(String fp) {
    return 'Das System vertraut dem Zertifikat dieses Servers nicht. Wenn es dein eigener Server mit einem selbstsignierten Zertifikat ist, vergleiche diesen Fingerabdruck mit dem auf dem Server angezeigten — vertraue ihm nur, wenn beide exakt übereinstimmen.\n\nSHA-256\n$fp';
  }

  @override
  String get syncTlsTrust => 'Diesem Zertifikat vertrauen';

  @override
  String get syncHttpPrivateTitle => 'Unverschlüsselte Verbindung';

  @override
  String get syncHttpPrivateBody =>
      'Das ist eine unverschlüsselte HTTP-Adresse in einem privaten Netz. Deine Kontodaten selbst sind Ende-zu-Ende-verschlüsselt, aber das Server-Passwort läuft unverschlüsselt durch dein Netzwerk.';

  @override
  String get syncHttpPublicTitle => 'Unverschlüsseltes HTTP übers Internet';

  @override
  String get syncHttpPublicBody =>
      'Diese Adresse ist öffentlich und die Verbindung wäre unverschlüsselt: Jeder zwischen dir und dem Server kann das Server-Passwort mitlesen und sich bei deinem Server anmelden. Die Kontodaten selbst bleiben verschlüsselt. Nimm stattdessen HTTPS oder eine LAN-Adresse — fahr nur fort, wenn du dieses Risiko akzeptierst.';

  @override
  String get syncHttpPublicHold => 'Trotzdem erlauben (halten)';

  @override
  String get syncContinue => 'Weiter';

  @override
  String get syncPassphraseNewTitle => 'Sync-Passphrase festlegen';

  @override
  String get syncPassphraseNewBody =>
      'Alles wird vor dem Hochladen mit dieser Passphrase verschlüsselt; die Passphrase selbst verlässt deine Geräte nie.\n\nWenn du sie verlierst, kann niemand die synchronisierten Daten wiederherstellen — ein Zurücksetzen gibt es nicht. Mindestens 8 Zeichen; Länge zählt mehr als Sonderzeichen.';

  @override
  String get syncPassphraseExistingTitle => 'Sync-Passphrase eingeben';

  @override
  String syncPassphraseExistingBody(int count) {
    return 'Dieser Ordner enthält bereits eine Sync-Bibliothek mit $count Konto/Konten. Gib die Passphrase ein, mit der sie erstellt wurde.';
  }

  @override
  String get syncPassphraseLabel => 'Sync-Passphrase';

  @override
  String get syncPassphraseConfirmLabel => 'Passphrase bestätigen';

  @override
  String get syncPassphraseTooShort => 'Mindestens 8 Zeichen.';

  @override
  String get syncPassphraseMismatch => 'Die Passphrasen stimmen nicht überein.';

  @override
  String get syncPassphraseWrong =>
      'Diese Passphrase öffnet diese Bibliothek nicht.';

  @override
  String get syncPreviewTitle => 'Erster Sync';

  @override
  String get syncPreviewEmpty =>
      'Noch nichts zu übertragen — Konten werden ab jetzt automatisch synchronisiert.';

  @override
  String syncPreviewPull(int count) {
    return 'Auf dieses Gerät herunterladen: $count Konto/Konten';
  }

  @override
  String syncPreviewPush(int count) {
    return 'Von diesem Gerät hochladen: $count Konto/Konten';
  }

  @override
  String syncPreviewConflict(int count) {
    return 'Auf beiden Seiten mit unterschiedlichem Inhalt: $count — nach dem Verbinden entscheidest du pro Konto';
  }

  @override
  String get syncStart => 'Sync starten';

  @override
  String get syncDoneTitle => 'Sync ist aktiv';

  @override
  String get syncDoneBody =>
      'Konten werden jetzt automatisch synchronisiert. Auf einem neuen Gerät meldet sich jedes Konto bei der ersten Nutzung einmal neu an — Konten mit gespeichertem Passwort machen das von selbst, die übrigen fragen einmal nach.';

  @override
  String get syncDone => 'Fertig';

  @override
  String get syncNeedsPassphrase =>
      'Die gespeicherte Passphrase passt nicht mehr zur Bibliothek auf dem Server — gib sie erneut ein.';

  @override
  String get syncEnterPassphrase => 'Passphrase eingeben';

  @override
  String get syncConditionalWarn =>
      'Dieser Server ignoriert bedingte Schreibzugriffe; zwei Geräte, die im selben Moment synchronisieren, können sich gegenseitig überschreiben. Der Sync funktioniert trotzdem — vermeide gleichzeitige Änderungen auf zwei Geräten.';

  @override
  String get syncConflictsTitle => 'Konflikte';

  @override
  String get syncConflictTrashNote =>
      'Die Seite, die du verwirfst, bleibt 30 Tage im Sync-Papierkorb.';

  @override
  String get syncConflictEditEdit => 'Auf beiden Geräten geändert';

  @override
  String get syncConflictEditDelete =>
      'Hier geändert, auf einem anderen Gerät gelöscht';

  @override
  String get syncConflictDeleteEdit =>
      'Hier gelöscht, auf einem anderen Gerät geändert';

  @override
  String get syncConflictKeepLocal => 'Lokale Version behalten';

  @override
  String get syncConflictKeepRemote => 'Andere Version behalten';

  @override
  String get syncConflictLocalSide => 'Dieses Gerät';

  @override
  String get syncConflictRemoteSide => 'Anderes Gerät';

  @override
  String get syncDeleted => 'Gelöscht';

  @override
  String get syncConflictHasPassword => 'Passwort gespeichert';

  @override
  String get syncConflictNoPassword => 'Kein gespeichertes Passwort';

  @override
  String get syncAutoTitle => 'Automatischer Sync';

  @override
  String get syncAutoDesc =>
      'Synchronisiert beim Start und nach jeder Änderung. Ist das aus, synchronisiert nur der Button unten.';

  @override
  String get syncPasswordsTitle => 'Kontopasswörter synchronisieren';

  @override
  String get syncPasswordsDesc =>
      'Mit Passwörtern kann sich ein neues Gerät von selbst anmelden. Eine Änderung hier lädt alle Konten neu hoch.';

  @override
  String get syncAppSettingsTitle => 'App-Einstellungen synchronisieren';

  @override
  String get syncAppSettingsDesc =>
      'Darstellungs- und Verhaltenseinstellungen (Skin, Design, Halten zum Bestätigen …) begleiten dich auf jedes Gerät. Sprache und Textgröße bleiben pro Gerät.';

  @override
  String get syncNowButton => 'Jetzt synchronisieren';

  @override
  String get syncViewRemote => 'Bibliothek auf dem Server ansehen';

  @override
  String get syncRemoteEmpty => 'Die Bibliothek auf dem Server ist leer.';

  @override
  String get syncRemoteDevices => 'Geräte';

  @override
  String get syncTrashTitle => 'Sync-Papierkorb';

  @override
  String get syncTrashEmpty =>
      'Leer. Alles, was der Sync entfernt oder ersetzt, bleibt hier 30 Tage erhalten.';

  @override
  String get syncTrashRestore => 'Wiederherstellen';

  @override
  String get syncTrashRestored => 'Konto wiederhergestellt.';

  @override
  String get syncTrashRestoreFailed =>
      'Dieser Eintrag lässt sich mit der aktuellen Passphrase nicht entschlüsseln.';

  @override
  String get syncTrashReasonRemoteDelete => 'von einem anderen Gerät gelöscht';

  @override
  String get syncTrashReasonConflict => 'in einem Konflikt ersetzt';

  @override
  String get syncChangePassphrase => 'Sync-Passphrase ändern';

  @override
  String get syncPassphraseChanged =>
      'Passphrase geändert; alles wurde neu verschlüsselt. Andere Geräte fragen nach der neuen Passphrase.';

  @override
  String syncPassphraseChangeFailed(String reason) {
    return 'Passphrase nicht geändert: $reason';
  }

  @override
  String get syncDisconnect => 'Sync trennen';

  @override
  String get syncDisconnectBody =>
      'Dieses Gerät hört auf zu synchronisieren. Die Sync-Bibliothek auf dem Server kann für deine anderen Geräte bestehen bleiben — oder komplett gelöscht werden.';

  @override
  String get syncDisconnectKeep => 'Serverdaten behalten';

  @override
  String get syncDisconnectDeleteHold => 'Serverdaten löschen (halten)';

  @override
  String get netErrTls =>
      'Es ließ sich keine sichere Verbindung zu Steam aufbauen. Die Verbindung wurde während des TLS-Handshakes getrennt — meist filtert das Netzwerk sie, oder es ist instabil. Versuchen Sie ein anderes Netzwerk oder einen Proxy.';

  @override
  String get netErrUnreachable =>
      'Steam war nicht erreichbar. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get netErrTimeout =>
      'Steam hat nicht rechtzeitig geantwortet. Das Netzwerk ist womöglich langsam oder gefiltert.';

  @override
  String get netErrCert =>
      'Das Zertifikat von Steam war nicht vertrauenswürdig, deshalb hat GooeSteamKit die Verbindung beendet. Möglicherweise untersucht etwas in diesem Netzwerk den Datenverkehr.';

  @override
  String netErrServer(int code) {
    return 'Steam hat einen Fehler zurückgegeben ($code). Das ist meist vorübergehend — versuchen Sie es gleich noch einmal.';
  }

  @override
  String exportSaved(String path) {
    return 'Gespeichert unter $path';
  }

  @override
  String get accountSearchHint => 'Konten suchen';

  @override
  String get accountSearchEmpty => 'Keine passenden Konten';

  @override
  String get accountSearchClear => 'Suche löschen';

  @override
  String get portableMode => 'Portabler Modus';

  @override
  String get portableEnable => 'Portablen Modus aktivieren';

  @override
  String get portableDisable => 'Portablen Modus deaktivieren';

  @override
  String get portableOnHelp =>
      'Neue Konten werden in maFiles neben der App gespeichert. Beide Bibliotheken werden gelesen; bei Duplikaten hat die portable Kopie Vorrang.';

  @override
  String get portableOffHelp =>
      'Neue Konten werden in AppData gespeichert. Beide entsperrten Bibliotheken werden gelesen; bei Duplikaten hat die lokale Kopie Vorrang.';

  @override
  String get portableCopyToUsb =>
      'Vorhandene lokale Konten auch nach maFiles neben der App kopieren?';

  @override
  String get portableCopyToLocal =>
      'Portable Konten auch zurück nach AppData kopieren?';

  @override
  String get portableCopyHelp =>
      'Kopien werden geprüft, die Quelle bleibt als Sicherung erhalten. Bereits vorhandene Zielkonten werden übersprungen. Portable Konten nehmen nicht am WebDAV-Sync dieses Computers teil.';

  @override
  String get portableNoCopy => 'Nur umschalten';

  @override
  String get portableCopy => 'Kopieren und umschalten';

  @override
  String get portableSetPassword => 'Portables Passwort festlegen';

  @override
  String get portableUnlock => 'maFiles entsperren';

  @override
  String get portablePasswordHelp =>
      'Verwende ein eigenes Passwort mit mindestens 12 Zeichen. Bewahre es sicher auf: Es wird auf anderen Computern benötigt und kann nicht zurückgesetzt werden.';

  @override
  String get portableUnlockHelp =>
      'Gib das Passwort dieser Bibliothek ein. Für einen verschlüsselten SDA-Ordner verwende das SDA-Passwort.';

  @override
  String get portableConfirmPassword => 'Passwort bestätigen';

  @override
  String get portablePasswordMismatch =>
      'Die Passwörter stimmen nicht überein.';

  @override
  String get portableWrongPassword =>
      'Falsches Passwort oder Bibliothek nicht entsperrbar.';

  @override
  String get portableFailed =>
      'Der Vorgang konnte nicht abgeschlossen werden. Die Quellbibliothek bleibt erhalten.';

  @override
  String get portableDone => 'Modus geändert. Quellkonten bleiben erhalten.';

  @override
  String get portableSkipped => 'Vorhandene Konten übersprungen';

  @override
  String get portableUnreadable =>
      'Die Bibliothek ist beschädigt oder benötigt den Schlüssel der ursprünglichen Windows-Installation. Stelle einen maFile-Export wieder her; die Quelldateien wurden nicht verändert.';

  @override
  String get friendsTitle => 'Freunde & Handel';

  @override
  String get friendsSearch => 'Nach Name oder SteamID suchen';

  @override
  String get friendsEmpty => 'Keine Freunde zum Anzeigen';

  @override
  String get friendsProfile => 'Steam-Profil ansehen';

  @override
  String get friendsTrade => 'Handelsangebot erstellen';

  @override
  String get friendsOnline => 'Online';

  @override
  String get friendsOffline => 'Offline';

  @override
  String get friendsPlaying => 'Im Spiel';

  @override
  String get tradeNewTitle => 'Neues Handelsangebot';

  @override
  String get tradeYourItems => 'Von dir angebotene Gegenstände';

  @override
  String get tradeTheirItems => 'Gegenstände, die du erhältst';

  @override
  String get tradeSelectItems => 'Gegenstände auswählen';

  @override
  String get tradeNote => 'Nachricht (optional)';

  @override
  String get tradeReview => 'Angebot prüfen';

  @override
  String get tradeSend => 'Angebot senden';

  @override
  String get tradeReviewBody =>
      'Prüfe die SteamID des Handelspartners sowie Gegenstände und Mengen auf beiden Seiten. Steam kann eine Bestätigung verlangen oder Gegenstände zurückhalten.';

  @override
  String get tradeGiftWarning =>
      'Du verschenkst diese Gegenstände und erhältst nichts dafür.';

  @override
  String get tradeNoItems =>
      'Hier sind keine handelbaren Gegenstände verfügbar.';

  @override
  String get tradeMore => 'Mehr laden';

  @override
  String get tradeSent => 'Angebot gesendet.';

  @override
  String get tradeNeedsMobile =>
      'Angebot erstellt. Schließe die mobile Bestätigung unter „Ausstehend“ ab.';

  @override
  String get tradeNeedsEmail =>
      'Angebot erstellt. Folge zur Bestätigung der E-Mail von Steam.';

  @override
  String get tradeOpenPending => 'Ausstehende Aktionen & Angebote ansehen';

  @override
  String get tradeUnknownResult =>
      'Das Ergebnis ist unklar. Prüfe deine gesendeten Angebote, bevor du es erneut versuchst, um doppelte Angebote zu vermeiden.';

  @override
  String get tradeChooseGame => 'Inventar auswählen';

  @override
  String get tradeQuantity => 'Menge';

  @override
  String get tradeLoadFailed =>
      'Steam-Freunde oder Inventar konnten nicht geladen werden. Aktualisiere die Ansicht und versuche es erneut.';

  @override
  String get tradeSendFailed =>
      'Steam hat den Versand des Angebots nicht bestätigt. Prüfe deine Angebote, bevor du es erneut versuchst.';

  @override
  String get marketListingActive => 'Zum Verkauf';

  @override
  String get marketListingOnHold => 'Zurückgehalten';

  @override
  String get marketListingPending => 'Bestätigung ausstehend';

  @override
  String get marketListingInactive => 'Inaktiv';

  @override
  String marketHoldUntil(String date) {
    return 'Zurückgehalten bis $date';
  }

  @override
  String get marketListingsAll => 'Alle';

  @override
  String get marketCancelConfirm => 'Dieses Marktangebot zurückziehen?';

  @override
  String get settingsStartupVerification => 'Identität beim Start prüfen';

  @override
  String get settingsStartupVerificationDesc =>
      'Wenn aktiviert, erfordert das Öffnen von GooeSteamKit deine PIN oder die Systemauthentifizierung. Wenn deaktiviert, kann jeder Benutzer dieses Geräts GooeSteamKit öffnen; lokale Kontodateien bleiben verschlüsselt.';

  @override
  String get settingsStartupVerificationError =>
      'Die Startprüfung konnte nicht gespeichert werden. Prüfe den sicheren Gerätespeicher und versuche es erneut.';

  @override
  String get settingsLockNow => 'Jetzt sperren';

  @override
  String get settingsStartupVerificationPinChanged =>
      'Nach einer PIN-Änderung wird die Startprüfung wieder aktiviert.';

  @override
  String get settingsStartupVerificationDisable => 'Startprüfung deaktivieren?';

  @override
  String get dashboardTitle => 'Kontoübersicht';

  @override
  String get dashboardWallet => 'Guthaben';

  @override
  String get dashboardPendingBalance => 'Ausstehendes Guthaben';

  @override
  String get dashboardUnavailable => 'Nicht verfügbar';

  @override
  String get dashboardMarket => 'Inventar & Markt';

  @override
  String get dashboardTools => 'Kontowerkzeuge';

  @override
  String get dashboardCustomize => 'Übersichtskarten auswählen';

  @override
  String get dashboardViewAll => 'Alle anzeigen';

  @override
  String get dashboardNoListings => 'Keine Marktangebote.';

  @override
  String get dashboardFetchFailed =>
      'Diese Informationen konnten nicht geladen werden. Aktualisiere die Ansicht und versuche es erneut.';

  @override
  String get dashboardSaveFailed =>
      'Die Anzeigeeinstellung konnte nicht gespeichert werden.';

  @override
  String get backupCodesTitle => 'Backup-Anmeldecodes';

  @override
  String get backupCodesAccountCheck =>
      'Dein Browser ist möglicherweise mit einem anderen Steam-Konto angemeldet. Prüfe vor dem Erstellen der Codes, dass der Kontoname mit dem oben angezeigten übereinstimmt.';

  @override
  String get backupCodesHow => 'Codes von Steam abrufen';

  @override
  String get backupCodesSteps =>
      '1. Öffne über die Schaltfläche unten die Steam-Guard-Einstellungen.\n2. Melde dich mit dem oben angezeigten Konto an.\n3. Wähle die Option zum Abrufen von Steam-Guard-Backupcodes.\n4. Schließe die von Steam verlangte Verifizierung ab und bewahre die erstellten Codes sicher auf.';

  @override
  String get backupCodesExplanation =>
      'Dies sind einmalig verwendbare Anmeldecodes, unabhängig vom Code zum Entfernen des Authentifikators. Steam stellt sie aus und verwaltet sie. GooeSteamKit öffnet den offiziellen Ablauf und erstellt oder speichert diese Codes nicht.';

  @override
  String get backupCodesOpenSteam => 'Steam öffnen und Codes abrufen';

  @override
  String get backupCodesCopyLink => 'Offiziellen Link kopieren';

  @override
  String get backupCodesOpenFailed =>
      'Der Browser konnte nicht geöffnet werden. Kopiere den Link und öffne ihn manuell.';

  @override
  String get loginAccountMismatch =>
      'Dies ist ein anderes Steam-Konto. Melde dich mit dem ausgewählten Konto an; das ursprüngliche Konto wurde nicht geändert.';

  @override
  String get tradeFromAccount => 'Absendendes Konto';

  @override
  String get tradeToAccount => 'Handelspartner';

  @override
  String get tradeValidationFailed =>
      'Das Angebot wurde nicht gesendet. Prüfe die Gegenstände und Mengen; pro Seite sind höchstens 256 Einträge erlaubt.';

  @override
  String get friendsProfileOpenFailed =>
      'Der Browser konnte nicht geöffnet werden. Kopiere den offiziellen Steam-Link unten.';

  @override
  String get steamSwitchQrTitle => 'Mit einem GooeSteamKit-Konto anmelden';

  @override
  String get steamSwitchQrHelp =>
      'Wähle ein GooeSteamKit-Konto, zeige den Anmelde-QR-Code in Steam an, scanne ihn und prüfe die Anmeldung.';

  @override
  String get steamSwitchQrAccount => 'GooeSteamKit-Konto';

  @override
  String get steamSwitchQrNeedsSession =>
      'Melde dich zuerst in GooeSteamKit erneut bei diesem Konto an. Ein Offline-Steam-Guard-Code allein kann keine QR-Anmeldung bestätigen.';

  @override
  String get steamSwitchQrNoAccounts =>
      'Füge GooeSteamKit ein Konto hinzu, um die QR-Anmeldung zu nutzen.';

  @override
  String get approveScreenSelect => 'QR-Code auf dem Bildschirm auswählen';

  @override
  String get approveScreenHelp =>
      'GooeSteamKit wird kurz ausgeblendet. Ziehe einen Rahmen um Steams Anmelde-QR-Code und prüfe Konto und Gerät vor dem Bestätigen.';

  @override
  String get approveScreenInstruction =>
      'Einen Steam-Anmelde-QR-Code einrahmen · Esc / Rechtsklick zum Abbrechen';

  @override
  String get approveScreenNoCode =>
      'Kein QR-Code gefunden. Wähle den vollständigen Code mit etwas Rand aus und versuche es erneut.';

  @override
  String get approveScreenFailed =>
      'Bildschirmaufnahme fehlgeschlagen. Versuche es erneut oder füge den QR-Link ein.';

  @override
  String get approveSessionUnavailable =>
      'Dieser QR-Code ist abgelaufen oder seine Anmeldedaten konnten nicht geprüft werden. Aktualisiere den Code in Steam und versuche es erneut.';

  @override
  String get itemMarketActions => 'Marktoptionen des Gegenstands';

  @override
  String get itemMarketViewPrice => 'Marktpreis ansehen';

  @override
  String get itemMarketOpen => 'Steam-Markt öffnen';

  @override
  String get itemMarketVolume => 'Letzte Verkäufe';

  @override
  String get itemMarketReferenceNote =>
      'Referenzpreis pro Gegenstand auf dem Steam-Communitymarkt, nicht der Verkäufererlös. Preise können sich ändern.';

  @override
  String itemMarketCurrency(String currency) {
    return 'Währung: $currency';
  }

  @override
  String get itemMarketNoIdentity => 'Dieser Gegenstand hat keinen Marktnamen.';

  @override
  String get itemMarketOpenFailed =>
      'Die Steam-Marktseite konnte nicht geöffnet werden.';

  @override
  String get steamClientRunning => 'Steam läuft';

  @override
  String get steamClientStopped => 'Steam läuft nicht';

  @override
  String get steamClientStatusLoading => 'Steam-Status wird gelesen…';

  @override
  String get steamClientStatusUnavailable =>
      'Steam-Status ist vorübergehend nicht verfügbar';

  @override
  String steamClientCurrentAccount(String account) {
    return 'Aktuell angemeldet: $account';
  }

  @override
  String get steamClientAccountUnknown => 'Aktuelles Konto noch nicht erkannt';

  @override
  String get steamClientCurrentBadge => 'Aktuell angemeldet';

  @override
  String get forkLocalFeaturesTitle => 'Lokale Funktionen freigeschaltet';

  @override
  String get forkLocalFeaturesBody =>
      'Alle lokalen Funktionen dieses unabhängigen Forks sind ohne Pro-Prüfung verfügbar. Online-Dienste und Abonnements des ursprünglichen Autors sind nicht enthalten.';

  @override
  String get forkPrivacyConsentBody =>
      'Dieser unabhängige AVA-Fork speichert Steam-Konten und Authentifikator-Geheimnisse auf diesem Gerät. Steam-Anfragen gehen direkt an Valve. Die optionale Synchronisierung wird erst aktiviert, wenn du deinen eigenen Server einrichtest; Kontodaten werden zuvor lokal verschlüsselt. Lokale Funktionen benötigen keine Pro-Prüfung. Diese Version verwendet keine Werbung, Zahlungsdienste oder Update-Prüfung beim Originalprojekt. Feedback öffnet nur die GitHub-Issues dieses Forks; Berichte und Protokolle werden nicht automatisch gesendet. Es gibt kein Tracking und keine Nutzungsanalyse. Lies den Datenschutzhinweis dieses Forks. Mit dem Fortfahren stimmst du ihm zu.';

  @override
  String get forkUpdateTitle => 'Software-Updates';

  @override
  String forkUpdateCurrentVersion(String version) {
    return 'Aktuelle Version $version';
  }

  @override
  String get forkUpdateCheck => 'Nach Updates suchen';

  @override
  String get forkUpdateChecking => 'Suche nach Updates…';

  @override
  String get forkUpdateNoRelease => 'Noch keine Veröffentlichung verfügbar';

  @override
  String get forkUpdateUpToDate => 'Du bist auf dem neuesten Stand';

  @override
  String forkUpdateAvailable(String version) {
    return 'Neue Version $version';
  }

  @override
  String get forkUpdateReleaseNotes => 'Versionshinweise';

  @override
  String get forkUpdateNoNotes => 'Keine Versionshinweise vorhanden';

  @override
  String get forkUpdateDownload => 'Update herunterladen';

  @override
  String forkUpdateDownloading(String progress) {
    return 'Download: $progress';
  }

  @override
  String get forkUpdateCancelDownload => 'Download abbrechen';

  @override
  String get forkUpdateReady =>
      'Installationsdatei heruntergeladen und geprüft';

  @override
  String get forkUpdateInstall => 'Update installieren';

  @override
  String get forkUpdateInstallTitle => 'Dieses Update installieren?';

  @override
  String get forkUpdateInstallAndroid =>
      'Die Systeminstallation wird geöffnet. Erlaube GooeSteamKit bei Bedarf, Apps zu installieren, und folge den Anweisungen.';

  @override
  String get forkUpdateInstallWindows =>
      'Das Installationsprogramm wird geöffnet und GooeSteamKit geschlossen. Beende zuerst deine aktuelle Arbeit und folge dann den Anweisungen.';

  @override
  String get forkUpdateInstallConfirm => 'Installation fortsetzen';

  @override
  String get forkUpdateInstallStarted =>
      'Systeminstallation geöffnet; folge ihren Anweisungen';

  @override
  String get forkUpdateCheckFailed =>
      'Updates konnten nicht geprüft werden. Bitte später erneut versuchen.';

  @override
  String get forkUpdateDownloadFailed =>
      'Download fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get forkUpdateHashFailed =>
      'Prüfung fehlgeschlagen; Installation blockiert. Bitte erneut herunterladen.';

  @override
  String get forkUpdateInstallFailed =>
      'Installationsprogramm konnte nicht geöffnet werden.';

  @override
  String get forkUpdateNoCompatibleAsset =>
      'Keine passende Installationsdatei für dieses Gerät';

  @override
  String get forkUpdateUnverifiable =>
      'Ohne vertrauenswürdige Prüfsumme sind Download und Installation gesperrt';

  @override
  String get forkUpdateInvalidMetadata =>
      'Versionsinformationen unvollständig oder ungültig. Bitte später erneut versuchen.';

  @override
  String get forkUpdateUnsupported =>
      'In-App-Updates werden auf diesem Gerät nicht unterstützt';

  @override
  String get forkUpdateCancelled => 'Download abgebrochen';

  @override
  String get forkUpdatePermissionRequired =>
      'Erlaube GooeSteamKit die App-Installation und kehre dann hierher zurück';

  @override
  String get forkUpdateOpenPermissionSettings => 'App-Installation erlauben';

  @override
  String get forkUpdateWrongPackage =>
      'Diese Datei gehört zu einer anderen App; Installation blockiert';

  @override
  String get forkUpdateSignatureMismatch =>
      'Die Signatur stimmt nicht mit dieser App überein; Installation blockiert';

  @override
  String get backupCodesNativeIntro =>
      'Hier kannst du einmalige Steam-Anmeldecodes erstellen. Steam verlangt eine SMS-Bestätigung der verknüpften Telefonnummer. Neue Codes können die bisherigen ersetzen.';

  @override
  String get backupCodesSendSms => 'Bestätigungs-SMS senden';

  @override
  String get backupCodesSmsPrompt => 'Gib den Code aus der Steam-SMS ein.';

  @override
  String get backupCodesSmsLabel => 'SMS-Bestätigungscode';

  @override
  String get backupCodesGenerate => 'Bestätigen und Codes erstellen';

  @override
  String get backupCodesReady => 'Deine einmaligen Anmeldecodes';

  @override
  String get backupCodesKeepSafe =>
      'Jeder Code ist einmal nutzbar. Bewahre einen Ausdruck sicher auf. GooeSteamKit speichert diese Codes nicht; beim Verlassen der Seite oder App werden sie ausgeblendet. Steam sendet bei Erstellung und Verwendung eine E-Mail.';

  @override
  String get backupCodesClear => 'Codes löschen';

  @override
  String get backupCodesRequestFailed =>
      'Steam konnte die Anfrage nicht abschließen. Es gab keinen automatischen Wiederholungsversuch. Prüfe die Verbindung und versuche es manuell erneut.';

  @override
  String get backupCodesUnexpectedResponse =>
      'Unbekannte Steam-Antwort. Das Ergebnis ist unbestätigt; die Anfrage wurde nicht wiederholt.';

  @override
  String get backupCodesInvalidSms =>
      'Steam hat den Code abgelehnt. Prüfe die SMS und versuche es erneut.';

  @override
  String get backupCodesRateLimited =>
      'Steam begrenzt die Anfragen. Bitte warte vor einem weiteren Versuch.';

  @override
  String get backupCodesPhoneRequired =>
      'Für dieses Konto ist eine bestätigte Telefonnummer erforderlich.';

  @override
  String get backupCodesManualHelp => 'Offizielle Steam-Seite (optional)';

  @override
  String get steamAccelerationTitle => 'Steam-Beschleunigung';

  @override
  String get steamAccelerationDesc =>
      'Beschleunigt nur Steam-Anfragen von GooeSteamKit und beeinflusst keine anderen Apps.';

  @override
  String get steamAccelerationOff => 'Aus';

  @override
  String get steamAccelerationLoading => 'Abonnement wird synchronisiert…';

  @override
  String get steamAccelerationStarting => 'Wird gestartet…';

  @override
  String get steamAccelerationRunning => 'Läuft';

  @override
  String get steamAccelerationPaused => 'Interne Beschleunigung pausiert';

  @override
  String get steamAccelerationFailed => 'Beschleunigung nicht verfügbar';

  @override
  String get steamAccelerationUnsupported =>
      'Derzeit nur unter Windows und Android unterstützt.';

  @override
  String get steamAccelerationConfigured =>
      'Abonnement auf diesem Gerät gespeichert';

  @override
  String get steamAccelerationUnconfigured => 'Kein Abonnement eingerichtet';

  @override
  String get steamAccelerationConfigure => 'Abonnement hinzufügen';

  @override
  String get steamAccelerationReplace => 'Abonnement ersetzen';

  @override
  String get steamAccelerationSubscription => 'Abonnement-URL';

  @override
  String get steamAccelerationSubscriptionHelp =>
      'Dieser Link kann private Zugangsdaten enthalten und wird nur auf diesem Gerät gespeichert. Synchronisiere nach dem Speichern die verfügbaren Knoten.';

  @override
  String get steamAccelerationClear => 'Abonnement löschen';

  @override
  String get steamAccelerationClearConfirm =>
      'Interne Beschleunigung stoppen und das gespeicherte Abonnement sowie die Knoten von diesem Gerät löschen?';

  @override
  String get steamAccelerationSync => 'Knoten synchronisieren';

  @override
  String get steamAccelerationNodes => 'Knoten';

  @override
  String get steamAccelerationNoNodes =>
      'Synchronisiere das Abonnement, um verfügbare Knoten zu laden.';

  @override
  String get steamAccelerationNode => 'Ausgewählter Knoten';

  @override
  String get steamAccelerationStart => 'Beschleunigung aktivieren';

  @override
  String get steamAccelerationStop => 'Beschleunigung stoppen';

  @override
  String get steamAccelerationAuto => 'Automatisch starten';

  @override
  String get steamAccelerationAutoDesc =>
      'Beim Öffnen von GooeSteamKit starten; bei erkanntem externen Proxy die interne Beschleunigung pausieren.';

  @override
  String get steamAccelerationEnvironment => 'Erkennung externer Proxys';

  @override
  String get steamAccelerationExternalProxy => 'Systemproxy oder PAC erkannt';

  @override
  String get steamAccelerationExternalVpn => 'VPN oder Tunnel erkannt';

  @override
  String get steamAccelerationNoExternal => 'Kein externer Proxy erkannt';

  @override
  String get steamAccelerationDetectionUnavailable =>
      'Der Status externer Proxys ist unbekannt. Der automatische Start ist pausiert; ein manueller Start ist möglich.';

  @override
  String get steamAccelerationEnvironmentHelp =>
      'Die interne Beschleunigung weicht erkannten externen Proxys aus. Die Erkennung kann von Systemberechtigungen abhängen.';

  @override
  String steamAccelerationSkipped(int count) {
    return '$count nicht unterstützte Knoten übersprungen.';
  }

  @override
  String get steamAccelerationInvalidSubscription =>
      'Gib eine gültige HTTP- oder HTTPS-Abonnement-URL ein.';

  @override
  String get steamAccelerationNetworkError =>
      'Das Abonnement konnte nicht abgerufen werden. Prüfe die Verbindung und versuche es erneut.';

  @override
  String get steamAccelerationUnsupportedSubscription =>
      'Das Abonnement enthält keine unterstützten Knoten. Verwende ein kompatibles Clash-Abonnement.';

  @override
  String get steamAccelerationStorageError =>
      'Der sichere Speicher ist nicht verfügbar. Die Einstellung konnte nicht gespeichert werden.';

  @override
  String get steamAccelerationCoreUnavailable =>
      'Die Beschleunigungskomponente fehlt. Installiere ein aktualisiertes App-Paket.';

  @override
  String get steamAccelerationCoreIntegrity =>
      'Die Beschleunigungskomponente hat die Prüfung nicht bestanden und wurde blockiert.';

  @override
  String get steamAccelerationStartFailed =>
      'Die Beschleunigung konnte nicht gestartet werden. Aktualisiere die Umgebungsprüfung und versuche es erneut.';

  @override
  String get inventorySearch => 'Gegenstände suchen';

  @override
  String get inventoryFilterType => 'Typ';

  @override
  String get inventoryFilterRarity => 'Seltenheit / Qualität';

  @override
  String get inventoryFilterOther => 'Sonstige / nicht klassifiziert';

  @override
  String get inventoryFilterNoMatches => 'Keine passenden Gegenstände';

  @override
  String get inventoryFilterLoaded =>
      'Filter gelten für geladene Gegenstände. Lade weitere, um den Rest einzubeziehen.';

  @override
  String get steamConnectionTitle => 'Verbindungsprüfung';

  @override
  String get steamConnectionNotChecked => 'Noch nicht geprüft';

  @override
  String get steamConnectionChecking => 'Verbindung wird geprüft…';

  @override
  String get steamConnectionAvailable => 'Verbindung verfügbar';

  @override
  String get steamConnectionPartial =>
      'Einige Steam-Dienste sind nicht erreichbar';

  @override
  String get steamConnectionUnavailable => 'Steam-Verbindung nicht verfügbar';

  @override
  String get steamConnectionCheck => 'Verbindung prüfen';

  @override
  String get steamConnectionApi => 'Steam-Anmeldeschnittstelle';

  @override
  String get steamConnectionCommunity => 'Steam-Community und -Markt';

  @override
  String get steamConnectionReachable => 'Erreichbar';

  @override
  String get steamConnectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String get steamConnectionInternal => 'Interne GooeSteamKit-Verbindung';

  @override
  String get steamConnectionExternal => 'Externer HTTP-Proxy';

  @override
  String get steamConnectionSystem =>
      'Aktuelle Systemverbindung (externes Netzwerk erkannt)';

  @override
  String get steamConnectionDirect => 'Direkte Verbindung';

  @override
  String steamConnectionCheckedAt(String time) {
    return 'Zuletzt geprüft: $time';
  }

  @override
  String get steamConnectionNoVpnIcon =>
      'Nur Steam-Anfragen innerhalb von GooeSteamKit werden umgeleitet. Daher zeigt Android kein VPN-Symbol. Die Steam-App und andere Apps werden nicht beschleunigt.';

  @override
  String get steamConnectionScope =>
      'Prüft Steam-API und Community über AVAs aktuelle Verbindung ohne Kontozugangsdaten. Das Ergebnis gilt nur für diese Prüfung.';

  @override
  String tradeSendNotSent(String reason) {
    return 'Angebot wurde nicht gesendet. $reason';
  }

  @override
  String get tradeCheckSendResult => 'Sendeergebnis prüfen';

  @override
  String get tradeSendNotFound =>
      'Noch kein passendes neues Angebot sichtbar. Steam braucht möglicherweise Zeit. Prüfe ausstehende und gesendete Angebote vor erneutem Senden.';

  @override
  String tradeSendCheckFailed(String reason) {
    return 'Sendeergebnis konnte nicht geprüft werden. $reason';
  }

  @override
  String get tradeSendRejected =>
      'Steam hat das Angebot ohne genaue Begründung abgelehnt. Prüfe die ausgewählten Gegenstände und Handelsbeschränkungen.';

  @override
  String get tradeSendUnreadableResponse =>
      'Steam hat keine vollständige Sendebestätigung geliefert.';

  @override
  String get steamConnectionPacHelp =>
      'GooeSteamKit erkennt PAC, wertet dessen Regeln jedoch nicht aus. Diese Prüfung nutzt die aktuelle Systemverbindung.';

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
    return 'Noch ca. $seconds s';
  }

  @override
  String forkUpdateRemainingMinutes(int minutes) {
    return 'Noch ca. $minutes min';
  }

  @override
  String get forkUpdateWaitingForData => 'Warten auf Daten…';

  @override
  String get forkUpdateVerifying => 'Installationsdatei wird geprüft…';

  @override
  String get forkUpdateConnectionHint =>
      'Der automatische Modus lädt über GH-Proxy, ohne einen Proxy zu starten, und wechselt bei Bedarf zu GitHub. Dateien werden anhand des SHA-256-Werts von GitHub geprüft.';

  @override
  String get forkUpdateSourceLabel => 'Downloadquelle';

  @override
  String get forkUpdateSourceAutomatic => 'Automatische Beschleunigung';

  @override
  String get forkUpdateSourceOfficial => 'GitHub direkt';

  @override
  String forkUpdateSourceAccelerated(String provider) {
    return 'Direkte Beschleunigung · $provider';
  }

  @override
  String get marketTabSearch => 'Markt';

  @override
  String get marketSearchHint => 'Artikel suchen, z. B. AK-47';

  @override
  String get marketSearchEmpty =>
      'Spiel und Währung wählen, dann nach einem Artikel suchen. Daten werden erst bei der Suche geladen.';

  @override
  String get marketSearchButton => 'Markt durchsuchen';

  @override
  String get marketSearchAllGames => 'Alle Spiele';

  @override
  String get marketSearchGame => 'Spiel';

  @override
  String get marketSearchCurrency => 'Währung';

  @override
  String get marketSearchNoResults =>
      'Keine passenden Artikel. Versuche einen anderen Suchbegriff.';

  @override
  String get marketSearchMore => 'Mehr laden';

  @override
  String marketSearchListings(int count) {
    return 'Angebote: $count';
  }

  @override
  String get marketSearchPriceUnavailable => 'Preis nicht verfügbar';

  @override
  String get marketSearchPriceNote =>
      'Richtpreise können sich ändern. Die Währung wird wie von Steam übermittelt angezeigt.';

  @override
  String get marketSearchRefreshPrice => 'Preis aktualisieren';

  @override
  String get marketSearchRateLimited =>
      'Zu viele Anfragen an Steam. Bitte später erneut versuchen.';

  @override
  String get marketSearchUnavailable =>
      'Marktartikel sind derzeit nicht verfügbar. Bitte später erneut versuchen.';

  @override
  String marketSearchRequestedCurrency(String currency) {
    return 'Angefragte Währung: $currency';
  }
}
