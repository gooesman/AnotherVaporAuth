import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/ui/backup_codes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Future<bool> Function(Uri) launch) => ProviderScope(
  overrides: [backupCodesLauncherProvider.overrideWithValue(launch)],
  child: MaterialApp(
    theme: buildAvaTheme(AvaThemeVariant.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: BackupCodesScreen(
      account: SteamGuardAccount(
        accountName: 'demo_primary',
        revocationCode: 'DO-NOT-SHOW',
        session: SessionData(
          steamId: 76561198000000001,
          accessToken: 'DO-NOT-TRANSFER',
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('only explicit action opens official flow without credentials', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      _app((uri) async {
        opened.add(uri);
        return true;
      }),
    );
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.text('demo_primary'), findsOneWidget);
    expect(find.textContaining('DO-NOT-'), findsNothing);
    await tester.ensureVisible(find.text('Open Steam to get codes'));
    await tester.tap(find.text('Open Steam to get codes'));
    await tester.pumpAndSettle();
    expect(
      opened.single.toString(),
      'https://store.steampowered.com/twofactor/manage',
    );
    expect(opened.single.query, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing browser offers a copyable official link', (
    tester,
  ) async {
    await tester.pumpWidget(_app((_) async => false));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open Steam to get codes'));
    await tester.tap(find.text('Open Steam to get codes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not open the browser.'), findsOneWidget);
    expect(find.text('Copy official link'), findsOneWidget);
  });
}
