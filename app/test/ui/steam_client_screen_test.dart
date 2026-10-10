import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/steam_client_service.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/steam_client_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Settings extends SettingsStore {
  _Settings() : super(MemoryStorageProvider('unused'));

  @override
  Future<String?> loadSteamClientPath() async => null;
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

Future<void> _show(
  WidgetTester tester,
  _Service service, {
  String steamId = '76561198000000001',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        steamClientServiceProvider.overrideWithValue(service),
        settingsStoreProvider.overrideWithValue(_Settings()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: SteamClientScreen(
          initialAccount: SteamGuardAccount(
            accountName: 'test-account',
            session: SessionData(steamId: int.parse(steamId)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening and cancelling do not switch Steam', (tester) async {
    final service = _Service([_account()]);
    await _show(tester, service);
    expect(service.switches, 0);
    final switchButton = find.byType(FilledButton).first;
    await tester.ensureVisible(switchButton);
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
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(service.switches, 0);
  });

  testWidgets('a remembered-account record is required for switching', (
    tester,
  ) async {
    await _show(tester, _Service([_account(remembered: false)]));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('successful launch asks the user to verify Steam login', (
    tester,
  ) async {
    final service = _Service([_account()]);
    await _show(tester, service);
    final switchButton = find.byType(FilledButton).first;
    await tester.ensureVisible(switchButton);
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
}
