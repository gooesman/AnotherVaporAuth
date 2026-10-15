import 'dart:async';

import 'package:ava/src/app/steam_notifications_provider.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_notification.dart';
import 'package:ava/src/core/protocol/steam_notifications_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Enabled extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool enabled) => state = enabled;
}

final _enabledProvider = NotifierProvider<_Enabled, bool>(_Enabled.new);

class _Client extends SteamNotificationsClient {
  _Client() : super(SteamApiClient());
  final calls = <String?>[];
  Future<SteamNotificationCounts> Function(SteamGuardAccount)? answer;

  @override
  Future<SteamNotificationCounts> fetchCounts(SteamGuardAccount account) {
    calls.add(account.session.accessToken);
    return answer?.call(account) ??
        Future.value(
          const SteamNotificationCounts(
            confirmationCount: 3,
            pendingFriendCount: 2,
            unreadCount: 1,
          ),
        );
  }
}

SteamGuardAccount _account([int id = 1, String? token = 'fixture-token']) =>
    SteamGuardAccount(
      accountName: 'fixture',
      session: SessionData(
        steamId: id,
        accessToken: token,
        refreshToken: 'fixture-refresh',
      ),
    );

ProviderContainer _container(
  _Client client, {
  DateTime Function()? clock,
  Duration gap = Duration.zero,
}) {
  final container = ProviderContainer(
    overrides: [
      steamNotificationsClientProvider.overrideWithValue(client),
      steamNotificationCountsEnabledProvider.overrideWith(
        (ref) => ref.watch(_enabledProvider),
      ),
      steamNotificationCountsProvider.overrideWith(
        () =>
            SteamNotificationCountsController(clock: clock, minRequestGap: gap),
      ),
    ],
  );
  container.listen(steamNotificationCountsProvider, (_, _) {});
  return container;
}

void main() {
  test(
    'concurrent callers share one request and different accounts are serialized',
    () async {
      final first = Completer<SteamNotificationCounts>();
      final second = Completer<SteamNotificationCounts>();
      final client = _Client()
        ..answer = (a) => a.steamId == 1 ? first.future : second.future;
      final container = _container(client);
      addTearDown(container.dispose);
      final controller = container.read(
        steamNotificationCountsProvider.notifier,
      );
      final account = _account();
      final a = controller.refresh(account);
      final duplicate = controller.refresh(account);
      final b = controller.refresh(_account(2, 'fixture-other'));
      expect(identical(a, duplicate), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(client.calls, ['fixture-token']);
      first.complete(const SteamNotificationCounts(confirmationCount: 5));
      await a;
      await Future<void>.delayed(Duration.zero);
      expect(client.calls, ['fixture-token', 'fixture-other']);
      second.complete(const SteamNotificationCounts(confirmationCount: 9));
      await b;
      final state = container.read(steamNotificationCountsProvider);
      expect(state[1]!.confirmationCount, 5);
      expect(state[2]!.confirmationCount, 9);
    },
  );

  test(
    'rebuild/foreground requests reuse counts until the low-frequency interval expires',
    () async {
      var now = DateTime.utc(2026, 1, 1);
      final client = _Client();
      final container = _container(client, clock: () => now);
      addTearDown(container.dispose);
      final controller = container.read(
        steamNotificationCountsProvider.notifier,
      );
      final account = _account();
      await controller.refresh(account);
      for (var i = 0; i < 20; i++) {
        await controller.refresh(account);
      }
      expect(client.calls, hasLength(1));
      now = now.add(const Duration(minutes: 2));
      await controller.refresh(account);
      expect(client.calls, hasLength(2));
    },
  );

  test('failed reads stay unknown or stale and never become zero', () async {
    final client = _Client()
      ..answer = (_) => Future.error(TimeoutException('fixture'));
    final container = _container(client);
    addTearDown(container.dispose);
    final controller = container.read(steamNotificationCountsProvider.notifier);
    final account = _account();
    await controller.refresh(account);
    var state = container.read(steamNotificationCountsProvider)[1]!;
    expect(state.confirmationCount, isNull);
    expect(state.unreadCount, isNull);
    expect(state.stale, isTrue);
    await controller.refresh(account);
    expect(client.calls, hasLength(1));
    controller.recordCounts(
      account,
      const SteamNotificationCounts(confirmationCount: 7),
    );
    await controller.refresh(account, force: true);
    state = container.read(steamNotificationCountsProvider)[1]!;
    expect(state.confirmationCount, 7);
    expect(state.confirmationStale, isTrue);
  });

  test('locking clears counts and ignores an in-flight response', () async {
    final pending = Completer<SteamNotificationCounts>();
    final client = _Client()..answer = (_) => pending.future;
    final container = _container(client);
    addTearDown(container.dispose);
    final controller = container.read(steamNotificationCountsProvider.notifier);
    final request = controller.refresh(_account());
    await Future<void>.delayed(Duration.zero);
    container.read(_enabledProvider.notifier).set(false);
    await container.pump();
    expect(container.read(steamNotificationCountsProvider), isEmpty);
    await request;
    pending.complete(const SteamNotificationCounts(confirmationCount: 12));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(steamNotificationCountsProvider), isEmpty);
    await controller.refresh(_account(), force: true);
    expect(client.calls, hasLength(1));
  });

  test(
    'different sessions with the same SteamID cannot publish each other counts',
    () async {
      final old = Completer<SteamNotificationCounts>();
      final next = Completer<SteamNotificationCounts>();
      final client = _Client()
        ..answer = (a) =>
            a.session.accessToken == 'old' ? old.future : next.future;
      final container = _container(client);
      addTearDown(container.dispose);
      final controller = container.read(
        steamNotificationCountsProvider.notifier,
      );
      final a = controller.refresh(_account(1, 'old'));
      await Future<void>.delayed(Duration.zero);
      final b = controller.refresh(_account(1, 'new'));
      old.complete(const SteamNotificationCounts(confirmationCount: 99));
      await a;
      expect(
        container.read(steamNotificationCountsProvider)[1]!.confirmationCount,
        isNull,
      );
      next.complete(const SteamNotificationCounts(confirmationCount: 2));
      await b;
      expect(
        container.read(steamNotificationCountsProvider)[1]!.confirmationCount,
        2,
      );
    },
  );

  test(
    'post-action invalidation discards old reads and permits a fresh count',
    () async {
      final old = Completer<SteamNotificationCounts>();
      final client = _Client()..answer = (_) => old.future;
      final container = _container(client);
      addTearDown(container.dispose);
      final controller = container.read(
        steamNotificationCountsProvider.notifier,
      );
      final account = _account();
      final request = controller.refresh(account);
      await Future<void>.delayed(Duration.zero);
      controller.invalidate(account);
      client.answer = (_) async =>
          const SteamNotificationCounts(confirmationCount: 0);
      await controller.refresh(account, force: true);
      old.complete(const SteamNotificationCounts(confirmationCount: 99));
      await request;
      expect(
        container.read(steamNotificationCountsProvider)[1]!.confirmationCount,
        0,
      );
      expect(client.calls, hasLength(2));
    },
  );

  test(
    'confirmation list writes back only its known count and cancels older reads',
    () async {
      final old = Completer<SteamNotificationCounts>();
      final client = _Client()..answer = (_) => old.future;
      final container = _container(client);
      addTearDown(container.dispose);
      final controller = container.read(
        steamNotificationCountsProvider.notifier,
      );
      final account = _account();
      final request = controller.refresh(account);
      await Future<void>.delayed(Duration.zero);
      controller.recordConfirmationCount(account, 4);
      await request;
      old.complete(const SteamNotificationCounts(confirmationCount: 99));
      await Future<void>.delayed(Duration.zero);
      final state = container.read(steamNotificationCountsProvider)[1]!;
      expect(state.confirmationCount, 4);
      expect(state.pendingFriendCount, isNull);
      expect(state.unreadCount, isNull);
      expect(state.confirmationStale, isFalse);
      expect(client.calls, hasLength(1));
    },
  );

  test('inbox counts update memory without fetching again', () async {
    final client = _Client();
    final container = _container(client);
    addTearDown(container.dispose);
    final controller = container.read(steamNotificationCountsProvider.notifier);
    final account = _account();
    controller.recordCounts(
      account,
      const SteamNotificationCounts(
        confirmationCount: 8,
        pendingFriendCount: 5,
        unreadCount: 3,
      ),
    );
    controller.recordConfirmationCount(account, 2);
    await controller.refresh(account);
    final state = container.read(steamNotificationCountsProvider)[1]!;
    expect(state.confirmationCount, 2);
    expect(state.pendingFriendCount, 5);
    expect(state.unreadCount, 3);
    expect(client.calls, isEmpty);
  });

  test('accounts without an access token issue no network read', () async {
    final client = _Client();
    final container = _container(client);
    addTearDown(container.dispose);
    await container
        .read(steamNotificationCountsProvider.notifier)
        .refresh(_account(1, null));
    expect(client.calls, isEmpty);
    expect(container.read(steamNotificationCountsProvider), isEmpty);
  });

  test(
    'suspending home cancels active and queued counts and resumes without waiting for TTL',
    () async {
      final pending = Completer<SteamNotificationCounts>();
      final client = _Client()..answer = (_) => pending.future;
      final container = _container(client);
      addTearDown(container.dispose);
      final controller = container.read(
        steamNotificationCountsProvider.notifier,
      );
      final all = controller.refreshAll([_account(1), _account(2)]);
      await Future<void>.delayed(Duration.zero);
      controller.cancelRefreshes();
      await all;
      expect(client.calls, hasLength(1));
      expect(
        container.read(steamNotificationCountsProvider)[1]!.loading,
        isFalse,
      );
      client.answer = null;
      await controller.refreshAll([_account(1), _account(2)]);
      expect(client.calls, hasLength(3));
      pending.complete(const SteamNotificationCounts(confirmationCount: 99));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(steamNotificationCountsProvider)[1]!.confirmationCount,
        3,
      );
    },
  );

  testWidgets('global rate limit spaces requests across accounts', (
    tester,
  ) async {
    final client = _Client();
    final container = _container(
      client,
      clock: tester.binding.clock.now,
      gap: const Duration(seconds: 1),
    );
    final controller = container.read(steamNotificationCountsProvider.notifier);
    unawaited(controller.refreshAll([_account(1), _account(2), _account(3)]));
    await tester.pump();
    expect(client.calls, hasLength(1));
    await tester.pump(const Duration(milliseconds: 999));
    expect(client.calls, hasLength(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(client.calls, hasLength(2));
    await tester.pump(const Duration(seconds: 1));
    expect(client.calls, hasLength(3));
    container.dispose();
  });

  test(
    'late user-action completion is harmless after the scope is disposed',
    () async {
      final client = _Client();
      final container = _container(client);
      final controller = container.read(
        steamNotificationCountsProvider.notifier,
      );
      final account = _account();
      container.dispose();
      controller.invalidate(account);
      await controller.refresh(account, force: true);
      expect(client.calls, isEmpty);
    },
  );
}
