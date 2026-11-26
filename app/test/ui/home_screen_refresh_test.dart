import 'dart:async';
import 'dart:typed_data';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_screen_dashboard_test.dart'
    show dashboardHomePreviewApp, pumpDashboardHome;

class _RefreshController extends AppController {
  final StorageProvider storage;
  final List<SteamGuardAccount> accounts;
  int refreshes = 0;
  Completer<void>? pending;

  _RefreshController(this.storage, this.accounts);

  @override
  Future<AppData> build() async =>
      AppData(store: AccountStore(storage), accounts: accounts, locked: false);

  @override
  Future<void> refreshAvatars({Iterable<int>? steamIds}) {
    refreshes++;
    pending = Completer<void>();
    return pending!.future;
  }
}

class _PendingApi extends SteamApiClient {
  final tokens = <String?>[];
  Completer<ProtoReader>? nextResponse;

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    expect(method, 'GetAuthSessionsForAccount');
    tokens.add(accessToken);
    final response = nextResponse;
    nextResponse = null;
    return response == null ? ProtoReader(Uint8List(0)) : response.future;
  }
}

final _indicator = find.byKey(const ValueKey('home-pull-refresh-indicator'));
final _desktopButton = find.byKey(const ValueKey('home-refresh-button'));

CircularProgressIndicator _ring(WidgetTester tester, Finder parent) =>
    tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: parent,
        matching: find.byType(CircularProgressIndicator),
      ),
    );

Future<_RefreshController> _showHome(
  WidgetTester tester, {
  AvaThemeVariant variant = AvaThemeVariant.light,
  bool mobile = true,
  bool reduceMotion = false,
  SteamApiClient? api,
  List<SteamGuardAccount>? accounts,
}) async {
  tester.view.physicalSize = mobile
      ? const Size(393, 852)
      : const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late _RefreshController controller;
  await tester.pumpWidget(
    dashboardHomePreviewApp(
      variant: variant,
      mobile: mobile,
      disableAnimations: reduceMotion,
      api: api,
      accounts: accounts,
      controllerFactory: (storage, accounts) =>
          controller = _RefreshController(storage, accounts),
    ),
  );
  await pumpDashboardHome(tester);
  return controller;
}

Future<TestGesture> _pull(WidgetTester tester, double travel) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.text('demo_primary').last),
  );
  // Claim the vertical scroll gesture before measuring the visible pull.
  await gesture.moveBy(const Offset(0, 20));
  await tester.pump();
  for (var i = 0; i < 5; i++) {
    await gesture.moveBy(Offset(0, travel / 5));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return gesture;
}

Future<void> _finishRefresh(
  WidgetTester tester,
  _RefreshController controller,
) async {
  controller.pending!.complete();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets(
    'sign-in checks start alongside avatars and keep the starting account',
    (tester) async {
      final api = _PendingApi();
      final accounts = [
        for (var i = 0; i < 2; i++)
          SteamGuardAccount(
            accountName: 'parallel_$i',
            sharedSecret: 'c3ludGhldGljLXRlc3Qtc2VjcmV0',
            session: SessionData(
              steamId: 76561198000000001 + i,
              accessToken: 'synthetic-$i',
            ),
          ),
      ];
      final controller = await _showHome(
        tester,
        mobile: false,
        api: api,
        accounts: accounts,
      );
      api.tokens.clear(); // The silent check on open has already completed.
      final signInResponse = Completer<ProtoReader>();
      api.nextResponse = signInResponse;
      await tester.tap(_desktopButton);
      await tester.pump();
      expect(controller.refreshes, 1);
      expect(api.tokens, ['synthetic-0']);
      expect(controller.pending!.isCompleted, isFalse);

      await tester.tap(find.text('parallel_1'));
      await tester.pump();
      expect(api.tokens, ['synthetic-0', 'synthetic-1']);
      await _finishRefresh(tester, controller);
      expect(
        _ring(tester, _desktopButton).value,
        isNull,
        reason: 'The pending sign-in read is still running.',
      );
      expect(
        api.tokens,
        ['synthetic-0', 'synthetic-1'],
        reason:
            'Avatar completion must not start a check for a changed selection.',
      );
      signInResponse.complete(ProtoReader(Uint8List(0)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.descendant(
          of: _desktopButton,
          matching: find.byIcon(Icons.refresh),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final variant in AvaThemeVariant.values) {
    testWidgets(
      '${variant.name} uses a bounded ring and refreshes once on release',
      (tester) async {
        final controller = await _showHome(tester, variant: variant);
        expect(_desktopButton, findsNothing);
        expect(_indicator, findsNothing);

        final shortPull = await _pull(tester, 60);
        expect(controller.refreshes, 0);
        expect(_indicator, findsOneWidget);
        expect(tester.getSize(_indicator), const Size(44, 44));
        final header = tester.getRect(
          find.byKey(const ValueKey('home-account-list-header')),
        );
        final indicator = tester.getRect(_indicator);
        expect(header.contains(indicator.center), isTrue);
        expect(
          indicator.overlaps(tester.getRect(find.text('demo_primary').first)),
          isFalse,
          reason: 'The refresh ring must not cover the selected name.',
        );
        expect(_ring(tester, _indicator).color, AvaTokens.of(variant).accent);
        expect(_ring(tester, _indicator).value, inExclusiveRange(0, 1));
        await shortPull.up();
        await tester.pump(const Duration(seconds: 1));
        expect(controller.refreshes, 0);
        expect(_indicator, findsNothing);

        final charged = await _pull(tester, 160);
        expect(_ring(tester, _indicator).value, 1);
        expect(
          controller.refreshes,
          0,
          reason: 'Crossing the threshold is not release.',
        );
        await charged.up();
        await tester.pump();
        expect(controller.refreshes, 1);
        expect(_ring(tester, _indicator).value, isNull);

        await tester.pump(const Duration(seconds: 1));
        final whileBusy = await _pull(tester, 160);
        await whileBusy.up();
        await tester.pump();
        expect(controller.refreshes, 1);
        expect(_indicator, findsOneWidget);
        await _finishRefresh(tester, controller);
        expect(_indicator, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'system pointer cancellation clears an armed pull without refreshing',
    (tester) async {
      final controller = await _showHome(tester);
      final gesture = await _pull(tester, 160);
      expect(_ring(tester, _indicator).value, 1);
      await gesture.cancel();
      await tester.pump(const Duration(seconds: 1));
      expect(_indicator, findsNothing);
      expect(controller.refreshes, 0);

      // A later short gesture must not inherit the cancelled gesture's charge.
      final next = await _pull(tester, 40);
      await next.up();
      await tester.pump(const Duration(seconds: 1));
      expect(controller.refreshes, 0);
      expect(_indicator, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'refresh fits a narrow phone with large text without covering controls',
    (tester) async {
      final controller = await _showHome(tester);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      final gesture = await _pull(tester, 160);
      await gesture.up();
      await tester.pump();
      final bounds = tester.getRect(_indicator);
      final header = tester.getRect(
        find.byKey(const ValueKey('home-account-list-header')),
      );
      expect(header.contains(bounds.topLeft), isTrue);
      expect(header.contains(bounds.bottomRight), isTrue);
      for (final icon in [Icons.search, Icons.add, Icons.swap_vert]) {
        expect(bounds.overlaps(tester.getRect(find.byIcon(icon))), isFalse);
      }
      expect(tester.takeException(), isNull);
      await _finishRefresh(tester, controller);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('retreating below the threshold cancels an armed pull', (
    tester,
  ) async {
    final controller = await _showHome(tester);
    final gesture = await _pull(tester, 160);
    expect(_ring(tester, _indicator).value, 1);
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.refreshes, 0);
    expect(_indicator, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'desktop refresh stays in its button and rejects duplicate taps',
    (tester) async {
      final controller = await _showHome(tester, mobile: false);
      await tester.tap(_desktopButton);
      await tester.pump();
      expect(controller.refreshes, 1);
      expect(_indicator, findsNothing);
      expect(_ring(tester, _desktopButton).value, isNull);
      await tester.tap(_desktopButton);
      await tester.pump();
      expect(controller.refreshes, 1);
      await _finishRefresh(tester, controller);
      expect(
        find.descendant(
          of: _desktopButton,
          matching: find.byIcon(Icons.refresh),
        ),
        findsOneWidget,
      );
      await tester.tap(_desktopButton);
      await tester.pump();
      expect(controller.refreshes, 2);
      await _finishRefresh(tester, controller);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('reduced motion uses a stationary ring while refreshing', (
    tester,
  ) async {
    final controller = await _showHome(tester, reduceMotion: true);
    final gesture = await _pull(tester, 160);
    await gesture.up();
    await tester.pump();
    final value = _ring(tester, _indicator).value;
    expect(value, inExclusiveRange(0, 1));
    await tester.pump(const Duration(seconds: 1));
    expect(_ring(tester, _indicator).value, value);
    await _finishRefresh(tester, controller);
    expect(_indicator, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('disposing during a refresh safely ignores its late completion', (
    tester,
  ) async {
    final controller = await _showHome(tester);
    final gesture = await _pull(tester, 160);
    await gesture.up();
    await tester.pump();
    expect(controller.refreshes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await _finishRefresh(tester, controller);
    expect(tester.takeException(), isNull);
  });
}
