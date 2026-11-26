import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/route_observer.dart';
import 'package:ava/src/app/steam_notifications_provider.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/confirmation.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_notification.dart';
import 'package:ava/src/core/protocol/confirmations_client.dart';
import 'package:ava/src/core/protocol/steam_notifications_client.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/pending/confirmations_tab.dart';
import 'package:ava/src/ui/widgets/pending_confirmation_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends SteamNotificationsClient {
  _Client() : super(SteamApiClient());
  int calls = 0;
  Completer<SteamNotificationCounts>? pending;
  @override
  Future<SteamNotificationCounts> fetchCounts(SteamGuardAccount account) {
    calls++;
    return pending?.future ??
        Future.value(const SteamNotificationCounts(confirmationCount: 3));
  }
}

class _Controller extends AppController {
  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(MemoryStorageProvider()),
    accounts: const [],
    locked: false,
  );
}

class _HoldOff extends HoldConfirmController {
  @override
  bool build() => false;
}

class _HapticsOff extends HapticsController {
  @override
  bool build() => false;
}

class _Confirmations extends ConfirmationsClient {
  _Confirmations() : super(SteamApiClient());
  int fetches = 0;
  int responses = 0;
  final list = [
    for (var i = 0; i < 2; i++)
      Confirmation(
        id: '$i',
        nonce: 'fixture',
        type: ConfirmationType.trade,
        typeName: '',
        creatorId: '',
        headline: 'Fixture $i',
        summary: const [],
        creationTime: 0,
        icon: '',
      ),
  ];
  @override
  Future<List<Confirmation>> fetch(SteamGuardAccount account) async {
    fetches++;
    return [...list];
  }

  @override
  Future<BatchResult> respondMultiple(
    SteamGuardAccount account,
    List<Confirmation> confs,
    bool accept,
  ) async {
    responses++;
    final count = list.length;
    list.clear();
    return BatchResult(count, 0);
  }
}

SteamGuardAccount _account() => SteamGuardAccount(
  accountName: 'fixture',
  session: SessionData(
    steamId: 1,
    accessToken: 'fixture',
    refreshToken: 'fixture',
  ),
);

Future<ProviderContainer> _show(
  WidgetTester tester,
  _Client client,
  SteamGuardAccount account, {
  bool coordinator = true,
  DateTime Function()? clock,
  Widget? body,
  _Confirmations? confirmations,
  AvaThemeVariant theme = AvaThemeVariant.light,
}) async {
  final container = ProviderContainer(
    overrides: [
      steamNotificationsClientProvider.overrideWithValue(client),
      steamNotificationCountsEnabledProvider.overrideWithValue(true),
      steamNotificationCountsProvider.overrideWith(
        () => SteamNotificationCountsController(
          clock: clock,
          minRequestGap: Duration.zero,
        ),
      ),
      appControllerProvider.overrideWith(_Controller.new),
      holdConfirmProvider.overrideWith(_HoldOff.new),
      hapticsProvider.overrideWith(_HapticsOff.new),
      if (confirmations != null)
        confirmationsClientProvider.overrideWithValue(confirmations),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
  final child =
      body ??
      Builder(
        builder: (context) => Column(
          children: [
            PendingConfirmationBadge(account: account),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Covered')),
                ),
              ),
              child: const Text('Cover home'),
            ),
          ],
        ),
      );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAvaTheme(theme),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        navigatorObservers: [routeObserver],
        home: Scaffold(
          body: coordinator
              ? NotificationCountsRefresh(accounts: [account], child: child)
              : child,
        ),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('badge renders unknown/known/stale without starting requests', (
    tester,
  ) async {
    final client = _Client();
    final account = _account();
    final container = await _show(tester, client, account, coordinator: false);
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
    expect(client.calls, 0);
    final controller = container.read(steamNotificationCountsProvider.notifier);
    controller.recordConfirmationCount(account, 8);
    await tester.pump();
    expect(find.text('8'), findsOneWidget);
    controller.invalidate(account);
    await tester.pump();
    expect(
      find.byTooltip(
        'Last checked: 8 pending confirmations. Refresh to check again.',
      ),
      findsOneWidget,
    );
    expect(client.calls, 0);
  });

  testWidgets(
    'home fetches asynchronously once and background stops low-frequency refresh',
    (tester) async {
      var now = DateTime.utc(2026);
      final client = _Client();
      final account = _account();
      await _show(tester, client, account, clock: () => now);
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(client.calls, 1);
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();
      expect(client.calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 4));
      await tester.pump(const Duration(minutes: 4));
      expect(client.calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(client.calls, 3);
    },
  );

  testWidgets('covering home cancels active statistics and returning retries', (
    tester,
  ) async {
    final pending = Completer<SteamNotificationCounts>();
    final client = _Client()..pending = pending;
    final account = _account();
    final container = await _show(tester, client, account);
    await tester.pumpAndSettle();
    expect(client.calls, 1);
    await tester.tap(find.text('Cover home'));
    await tester.pumpAndSettle();
    expect(
      container.read(steamNotificationCountsProvider)[1]!.loading,
      isFalse,
    );
    client.pending = null;
    Navigator.of(tester.element(find.text('Covered'))).pop();
    await tester.pumpAndSettle();
    expect(client.calls, 2);
    expect(find.text('3'), findsOneWidget);
    pending.complete(const SteamNotificationCounts(confirmationCount: 99));
    await tester.pump();
    expect(find.text('99'), findsNothing);
  });

  testWidgets(
    'confirmation list refresh and successful action update shared count without statistics requests',
    (tester) async {
      final client = _Client();
      final account = _account();
      final confirmations = _Confirmations();
      final container = await _show(
        tester,
        client,
        account,
        coordinator: false,
        confirmations: confirmations,
        body: ConfirmationsTab(account: account),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(steamNotificationCountsProvider)[1]!.confirmationCount,
        2,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Accept all'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Accept all'),
        ),
      );
      await tester.pumpAndSettle();
      expect(confirmations.responses, 1);
      expect(confirmations.fetches, 2);
      expect(
        container.read(steamNotificationCountsProvider)[1]!.confirmationCount,
        0,
      );
      expect(client.calls, 0);
    },
  );

  for (final theme in AvaThemeVariant.values) {
    testWidgets('badge is compact in ${theme.name} theme at phone width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = _Client();
      final account = _account();
      final container = await _show(
        tester,
        client,
        account,
        coordinator: false,
        theme: theme,
      );
      container
          .read(steamNotificationCountsProvider.notifier)
          .recordConfirmationCount(account, 123);
      await tester.pumpAndSettle();
      expect(find.text('123'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
