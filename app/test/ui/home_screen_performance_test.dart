import 'dart:async';

import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/steam_totp.dart';
import 'package:ava/src/ui/widgets/countdown_ring.dart';
import 'package:ava/src/ui/widgets/flip_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_screen_dashboard_test.dart' show dashboardHomePreviewApp;

class _CountingAccount extends SteamGuardAccount {
  int codeComputations = 0;

  _CountingAccount(int index)
    : super(
        accountName: 'performance_$index',
        sharedSecret: 'c3ludGhldGljLXRlc3Qtc2VjcmV0',
        session: SessionData(
          steamId: 76561198000000001 + index,
          accessToken: 'synthetic',
        ),
      );

  @override
  String generateCode(int time) {
    codeComputations++;
    return super.generateCode(time);
  }
}

void main() {
  for (final mobile in [false, true]) {
    testWidgets(
      'countdown updates do not rebuild home chrome on ${mobile ? 'phone' : 'desktop'}',
      (tester) async {
        tester.view.physicalSize = mobile
            ? const Size(393, 852)
            : const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final accounts = List.generate(3, _CountingAccount.new);
        final ticks = StreamController<int>();
        addTearDown(ticks.close);
        await tester.pumpWidget(
          dashboardHomePreviewApp(
            variant: AvaThemeVariant.light,
            mobile: mobile,
            accounts: accounts,
            ticks: ticks.stream,
          ),
        );
        const windowStart = 1900000020; // Exactly divisible by 30.
        ticks.add(windowStart + 1);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        final initialComputations = accounts.fold<int>(
          0,
          (total, account) => total + account.codeComputations,
        );
        final rebuilds = <String, int>{};
        debugOnRebuildDirtyWidget = (element, _) {
          final name = element.widget.runtimeType.toString();
          rebuilds.update(name, (value) => value + 1, ifAbsent: () => 1);
        };
        addTearDown(() => debugOnRebuildDirtyWidget = null);
        for (var second = 2; second <= 21; second++) {
          ticks.add(windowStart + second);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));
        }
        debugOnRebuildDirtyWidget = null;
        final computations =
            accounts.fold<int>(
              0,
              (total, account) => total + account.codeComputations,
            ) -
            initialComputations;
        // This measures widget work, not device frame rate. Only synthetic
        // accounts and an explicitly controlled clock are used.
        debugPrint(
          'Home 20-second sample (${mobile ? 'phone' : 'desktop'}): '
          'home=${rebuilds['HomeScreen'] ?? 0}, '
          'rows=${rebuilds['_SidebarRow'] ?? 0}, '
          'dashboard=${rebuilds['AccountDashboard'] ?? 0}, '
          'HMAC=$computations',
        );
        expect(rebuilds['HomeScreen'] ?? 0, 0);
        expect(rebuilds['_SidebarRow'] ?? 0, 0);
        expect(rebuilds['AccountDashboard'] ?? 0, 0);
        expect(computations, 0);
        expect(
          tester.widget<CountdownRing>(find.byType(CountdownRing)).remaining,
          9,
        );

        // A real boundary and a backwards Steam time correction must both
        // change the code immediately; memoization cannot freeze the token.
        for (final time in [windowStart + 30, windowStart - 1]) {
          ticks.add(time);
          await tester.pump();
          expect(
            tester.widget<FlipCode>(find.byType(FlipCode)).code,
            SteamTotp.generateAuthCode(accounts.first.sharedSecret!, time),
          );
          expect(
            tester.widget<CountdownRing>(find.byType(CountdownRing)).remaining,
            SteamTotp.secondsRemaining(time),
          );
        }
        // Switching accounts and replacing a secret in the same window must
        // never reuse the previously displayed account's cached token.
        accounts[1].sharedSecret = 'YW5vdGhlci1zeW50aGV0aWMtc2VjcmV0';
        await tester.tap(find.text('performance_1'));
        await tester.pump();
        expect(
          tester.widget<FlipCode>(find.byType(FlipCode)).code,
          SteamTotp.generateAuthCode(
            accounts[1].sharedSecret!,
            windowStart - 1,
          ),
        );
        accounts[1].sharedSecret = 'cmVwbGFjZWQtc3ludGhldGljLXNlY3JldA==';
        await tester.tap(find.text('performance_1').at(mobile ? 1 : 0));
        await tester.pump();
        expect(
          tester.widget<FlipCode>(find.byType(FlipCode)).code,
          SteamTotp.generateAuthCode(
            accounts[1].sharedSecret!,
            windowStart - 1,
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('pull progress does not rebuild the account list or home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      dashboardHomePreviewApp(
        variant: AvaThemeVariant.light,
        mobile: true,
        accounts: List.generate(3, _CountingAccount.new),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    var homeBuilds = 0;
    var rowBuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      final name = element.widget.runtimeType.toString();
      if (name == 'HomeScreen') homeBuilds++;
      if (name == '_SidebarRow') rowBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('performance_0').last),
    );
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      find.byKey(const ValueKey('home-pull-refresh-indicator')),
      findsOneWidget,
      reason: 'The gesture must actually drive the refresh overlay.',
    );
    await gesture.up();
    await tester.pump();
    debugOnRebuildDirtyWidget = null;
    expect(homeBuilds, 0);
    expect(rowBuilds, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('large account libraries only compute visible row tokens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final accounts = List.generate(200, _CountingAccount.new);
    await tester.pumpWidget(
      dashboardHomePreviewApp(
        variant: AvaThemeVariant.light,
        mobile: true,
        accounts: accounts,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      accounts.where((account) => account.codeComputations > 0).length,
      lessThan(15),
    );
    expect(accounts.last.codeComputations, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
