import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/credential_store.dart';
import 'package:ava/src/services/steam_client_service.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/approve_login_screen.dart';
import 'package:ava/src/ui/login_screen.dart';
import 'package:ava/src/ui/steam_client_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Settings extends SettingsStore {
  _Settings() : super(MemoryStorageProvider('unused'));

  @override
  Future<String?> loadSteamClientPath() async => null;
}

class _Controller extends AppController {
  _Controller(this.accounts);
  final List<SteamGuardAccount> accounts;

  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(MemoryStorageProvider()),
    accounts: accounts,
    locked: false,
  );

  void replaceAccounts(List<SteamGuardAccount> next, {bool locked = false}) {
    state = AsyncData(
      AppData(
        store: AccountStore(MemoryStorageProvider()),
        accounts: next,
        locked: locked,
      ),
    );
  }
}

class _Credentials extends CredentialStore {
  @override
  Future<String?> password(int steamId) async => null;
}

class _Service extends SteamClientService {
  final List<SteamClientAccount> accounts;
  int switches = 0;

  _Service(this.accounts);

  @override
  Future<String?> discoverPath() async => r'C:\Steam';

  @override
  Future<List<SteamClientAccount>> listAccounts(String path) async => accounts;

  @override
  Future<SteamSwitchResult> switchAccount({
    required String path,
    required String steamId,
    void Function(SteamSwitchStage)? onProgress,
  }) async {
    switches++;
    return const SteamSwitchResult(backupPath: r'C:\Steam\backup');
  }
}

SteamClientAccount _account({bool remembered = true}) => SteamClientAccount(
  steamId: '76561198000000001',
  accountName: 'test-account',
  personaName: 'Test player',
  rememberPassword: remembered,
  isMostRecent: true,
);

SteamGuardAccount _avaAccount({
  String steamId = '76561198000000001',
  String name = 'test-account',
  String? accessToken,
  String? refreshToken,
}) => SteamGuardAccount(
  accountName: name,
  session: SessionData(
    steamId: int.parse(steamId),
    accessToken: accessToken,
    refreshToken: refreshToken,
  ),
);

Future<void> _show(
  WidgetTester tester,
  _Service service, {
  String steamId = '76561198000000001',
  List<SteamGuardAccount>? avaAccounts,
  _Controller? controller,
}) async {
  final initial = _avaAccount(steamId: steamId);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        steamClientServiceProvider.overrideWithValue(service),
        settingsStoreProvider.overrideWithValue(_Settings()),
        credentialStoreProvider.overrideWithValue(_Credentials()),
        appControllerProvider.overrideWith(
          () => controller ?? _Controller(avaAccounts ?? [initial]),
        ),
      ],
      child: MaterialApp(
        theme: buildAvaTheme(AvaThemeVariant.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: SteamClientScreen(initialAccount: initial),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<Finder> _switchButton(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('steam-client-switch'));
  await tester.scrollUntilVisible(
    button,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  return button;
}

void main() {
  testWidgets('opening and cancelling do not switch Steam', (tester) async {
    final service = _Service([_account()]);
    await _show(tester, service);
    expect(service.switches, 0);
    final switchButton = await _switchButton(tester);
    await tester.tap(switchButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.switches, 0);
  });

  testWidgets('same username never overrides a conflicting SteamID', (
    tester,
  ) async {
    final service = _Service([_account()]);
    await _show(tester, service, steamId: '76561198000000002');
    final switchButton = await _switchButton(tester);
    expect(tester.widget<FilledButton>(switchButton).onPressed, isNull);
    expect(service.switches, 0);
  });

  testWidgets('a remembered-account record is required for switching', (
    tester,
  ) async {
    await _show(tester, _Service([_account(remembered: false)]));
    final switchButton = await _switchButton(tester);
    expect(tester.widget<FilledButton>(switchButton).onPressed, isNull);
  });

  testWidgets('successful launch asks the user to verify Steam login', (
    tester,
  ) async {
    final service = _Service([_account()]);
    await _show(tester, service);
    final switchButton = await _switchButton(tester);
    await tester.tap(switchButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.switches, 1);
    final context = tester.element(find.byType(SteamClientScreen));
    expect(
      find.text(AppLocalizations.of(context).steamSwitchLaunched),
      findsOneWidget,
    );
  });

  testWidgets('QR entry works with no locally remembered Steam accounts', (
    tester,
  ) async {
    final service = _Service([]);
    final account = _avaAccount(accessToken: 'synthetic-access');
    await _show(tester, service, avaAccounts: [account]);
    final button = find.byKey(const ValueKey('steam-client-qr-login'));
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ApproveLoginScreen>(find.byType(ApproveLoginScreen))
          .initialAccount,
      same(account),
    );
    expect(service.switches, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('initial SteamID preselects the live refresh-only AVA account', (
    tester,
  ) async {
    final service = _Service([]);
    final first = _avaAccount(accessToken: 'synthetic-access');
    final chosen = _avaAccount(
      steamId: '76561198000000002',
      name: 'refresh-only',
      refreshToken: 'synthetic-refresh',
    );
    await _show(
      tester,
      service,
      steamId: '${chosen.steamId}',
      avaAccounts: [first, chosen],
    );
    await tester.tap(find.byKey(const ValueKey('steam-client-qr-login')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ApproveLoginScreen>(find.byType(ApproveLoginScreen))
          .initialAccount,
      same(chosen),
    );
    expect(service.switches, 0);
  });

  testWidgets('changing AVA account passes that account to the QR screen', (
    tester,
  ) async {
    final service = _Service([]);
    final first = _avaAccount(accessToken: 'synthetic-access');
    final second = _avaAccount(
      steamId: '76561198000000002',
      name: 'another-account',
      accessToken: 'another-synthetic-access',
    );
    await _show(tester, service, avaAccounts: [first, second]);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('another-account').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('steam-client-qr-login')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ApproveLoginScreen>(find.byType(ApproveLoginScreen))
          .initialAccount,
      same(second),
    );
    expect(service.switches, 0);
  });

  testWidgets(
    'offline-only account explains the requirement and opens AVA re-login',
    (tester) async {
      final service = _Service([]);
      final account = _avaAccount();
      await _show(tester, service, avaAccounts: [account]);
      final context = tester.element(find.byType(SteamClientScreen));
      expect(
        find.text(AppLocalizations.of(context).steamSwitchQrNeedsSession),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('steam-client-qr-login')),
            )
            .onPressed,
        isNull,
      );
      final login = find.byKey(const ValueKey('steam-client-ava-login'));
      await tester.ensureVisible(login);
      await tester.tap(login);
      // The login form keeps its focused cursor animating.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final screen = tester.widget<LoginScreen>(find.byType(LoginScreen));
      expect(screen.reason, LoginReason.refresh);
      expect(screen.account, same(account));
      expect(service.switches, 0);
    },
  );

  testWidgets(
    'returning from re-login uses the refreshed object and hides removed accounts',
    (tester) async {
      final service = _Service([]);
      final old = _avaAccount();
      final controller = _Controller([old]);
      await _show(tester, service, controller: controller);
      await tester.tap(find.byKey(const ValueKey('steam-client-ava-login')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final renewed = _avaAccount(refreshToken: 'synthetic-refresh');
      controller.replaceAccounts([renewed]);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('steam-client-qr-login')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ApproveLoginScreen>(find.byType(ApproveLoginScreen))
            .initialAccount,
        same(renewed),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      controller.replaceAccounts([]);
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('steam-client-qr-login')),
            )
            .onPressed,
        isNull,
      );
      expect(service.switches, 0);
    },
  );

  testWidgets(
    'locking AVA removes its account choice without using the initial object',
    (tester) async {
      final account = _avaAccount(accessToken: 'synthetic-access');
      final controller = _Controller([account]);
      await _show(tester, _Service([]), controller: controller);
      controller.replaceAccounts([account], locked: true);
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('steam-client-qr-login')),
            )
            .onPressed,
        isNull,
      );
    },
  );
}
