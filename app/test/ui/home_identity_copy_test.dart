import 'package:ava/src/app/account_name_mode.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/ui/account_dashboard.dart';
import 'package:ava/src/ui/home_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_screen_dashboard_test.dart'
    show dashboardHomePreviewApp, homePreviewAccounts, pumpDashboardHome;

void main() {
  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'Android' : 'Windows'} name copy preserves cycling and account gestures',
      (tester) async {
        tester.view.physicalSize = mobile
            ? const Size(393, 852)
            : const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final writes = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              writes.add((call.arguments as Map)['text'] as String);
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });
        final accounts = [
          for (final account in homePreviewAccounts)
            SteamGuardAccount.fromJson(account.toJson()),
        ];
        accounts[0]
          ..accountName = 'main'
          ..personaName = '甲';
        accounts[1]
          ..accountName = 'trade'
          ..personaName = '乙';
        accounts[2]
          ..accountName = 'backup'
          ..personaName = '丙';
        await tester.pumpWidget(
          dashboardHomePreviewApp(
            variant: AvaThemeVariant.dark,
            mobile: mobile,
            accounts: accounts,
          ),
        );
        await pumpDashboardHome(tester);
        final home = tester.element(find.byType(HomeScreen));
        final container = ProviderScope.containerOf(home);
        final name = find.byKey(const ValueKey('selected-account-name'));
        await tester.tap(name);
        await pumpDashboardHome(tester);
        expect(
          container.read(accountNameModeProvider),
          AccountNameMode.persona,
        );
        if (mobile) {
          await tester.longPress(name);
        } else {
          await tester.tap(
            name,
            buttons: kSecondaryMouseButton,
            kind: PointerDeviceKind.mouse,
          );
        }
        await pumpDashboardHome(tester);
        expect(find.byType(AccountDashboardScreen), findsNothing);
        expect(find.text('main'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('account-copy-login')));
        await pumpDashboardHome(tester);
        expect(writes, ['main']);
        expect(
          container.read(accountNameModeProvider),
          AccountNameMode.persona,
        );
        await tester.tap(name);
        await pumpDashboardHome(tester);
        expect(container.read(accountNameModeProvider), AccountNameMode.id);
        if (mobile) {
          // Account-row holding still navigates. Its overview title offers
          // the same copy menu without requiring a separate copy button.
          await tester.longPress(find.text('${accounts[1].steamId}'));
          await pumpDashboardHome(tester);
          expect(find.byType(AccountDashboardScreen), findsOneWidget);
          await tester.longPress(
            find.descendant(of: find.byType(AppBar), matching: find.text('乙')),
          );
          await pumpDashboardHome(tester);
          await tester.tap(find.byKey(const ValueKey('account-copy-persona')));
          await pumpDashboardHome(tester);
          expect(writes, ['main', '乙']);
          expect(find.byType(AccountDashboardScreen), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
