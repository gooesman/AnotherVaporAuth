import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/steam_notifications_provider.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_friend.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_notification.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/core/protocol/friends_client.dart';
import 'package:ava/src/core/protocol/steam_notifications_client.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/friends/friends_screen.dart'
    show friendsClientProvider;
import 'package:ava/src/ui/notifications/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoNetwork extends SteamApiClient {
  final calls = <String>[];
  String? refreshedToken;
  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    calls.add(method);
    if (method == 'GenerateAccessTokenForApp' && refreshedToken != null) {
      return ProtoReader(
        (ProtoWriter()..writeString(1, refreshedToken!)).toBytes(),
      );
    }
    throw StateError('Unexpected transport in fixture: $method');
  }
}

class _Controller extends AppController {
  _Controller(this.account);
  final SteamGuardAccount account;
  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(MemoryStorageProvider()),
    accounts: [account],
    locked: false,
  );
  @override
  Future<bool> persistSession(SteamGuardAccount account) async => true;
}

class _Notifications extends SteamNotificationsClient {
  _Notifications(super.api);
  int reads = 0;
  int countReads = 0;
  final readWrites = <List<String>>[];
  final hideWrites = <List<String>>[];
  Object? readError;
  Object? firstReadError;
  Object? writeError;
  Completer<void>? pendingRead;
  Completer<void>? pendingWrite;
  VoidCallback? beforeWrite;
  bool applyWrites = true;
  var items = [
    const SteamNotification(
      id: '1',
      type: 10,
      body: {'title': 'First notice', 'body': 'Fixture message'},
    ),
    const SteamNotification(id: '2', type: 6, body: {'title': 'Second notice'}),
    const SteamNotification(
      id: '3',
      type: 10,
      read: true,
      body: {'title': 'Read notice'},
    ),
    const SteamNotification(
      id: '4',
      type: 10,
      hidden: true,
      body: {'title': 'Hidden notice'},
    ),
  ];

  SteamNotificationCounts get counts => SteamNotificationCounts(
    unreadCount: items.where((item) => !item.hidden && !item.read).length,
    pendingFriendCount: 2,
    confirmationCount: 3,
  );

  @override
  Future<SteamNotificationInbox> fetch(SteamGuardAccount account) async {
    reads++;
    if (reads == 1 && firstReadError != null) throw firstReadError!;
    await pendingRead?.future;
    if (readError case final error?) throw error;
    return SteamNotificationInbox(notifications: [...items], counts: counts);
  }

  @override
  Future<SteamNotificationCounts> fetchCounts(SteamGuardAccount account) async {
    countReads++;
    return counts;
  }

  @override
  Future<void> markRead(SteamGuardAccount account, Iterable<String> ids) async {
    final selected = ids.toList();
    readWrites.add(selected);
    beforeWrite?.call();
    await pendingWrite?.future;
    if (writeError case final error?) throw error;
    if (!applyWrites) return;
    items = [
      for (final item in items)
        SteamNotification(
          id: item.id,
          type: item.type,
          body: item.body,
          hidden: item.hidden,
          read: item.read || selected.contains(item.id),
        ),
    ];
  }

  @override
  Future<void> hide(SteamGuardAccount account, Iterable<String> ids) async {
    final selected = ids.toList();
    hideWrites.add(selected);
    await pendingWrite?.future;
    if (writeError case final error?) throw error;
    if (!applyWrites) return;
    items.removeWhere((item) => selected.contains(item.id));
  }
}

class _Friends extends FriendsClient {
  _Friends(super.api);
  int reads = 0;
  final writes = <(String, bool)>[];
  Object? readError;
  Object? writeError;
  Completer<void>? pendingWrite;
  final requests = [
    const SteamFriendRequest(steamId: '76561198000000002'),
    const SteamFriendRequest(steamId: '76561198000000003'),
  ];

  @override
  Future<List<SteamFriendRequest>> fetchRequests(
    SteamGuardAccount account,
  ) async {
    reads++;
    if (readError case final error?) throw error;
    return [...requests];
  }

  @override
  Future<void> respondToRequest(
    SteamGuardAccount account,
    String steamId, {
    required bool accept,
  }) async {
    writes.add((steamId, accept));
    await pendingWrite?.future;
    if (writeError case final error?) throw error;
    requests.removeWhere((request) => request.steamId == steamId);
  }
}

SteamGuardAccount _account() => SteamGuardAccount(
  accountName: 'fixture',
  session: SessionData(
    steamId: 76561198000000001,
    accessToken: 'fixture-token',
  ),
);

Widget _app(
  _Notifications notifications,
  _Friends friends, {
  SteamGuardAccount? account,
  AvaThemeVariant variant = AvaThemeVariant.light,
  Future<bool> Function(Uri)? launch,
}) {
  final identity = account ?? _account();
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(notifications.api),
      appControllerProvider.overrideWith(() => _Controller(identity)),
      steamNotificationsClientProvider.overrideWithValue(notifications),
      friendsClientProvider.overrideWithValue(friends),
      notificationsLauncherProvider.overrideWithValue(
        launch ?? (_) async => true,
      ),
      steamNotificationCountsEnabledProvider.overrideWithValue(true),
      steamNotificationCountsProvider.overrideWith(
        () => SteamNotificationCountsController(minRequestGap: Duration.zero),
      ),
    ],
    child: MaterialApp(
      theme: buildAvaTheme(variant).copyWith(platform: TargetPlatform.android),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: NotificationsScreen(account: identity),
    ),
  );
}

Future<void> _openRequests(WidgetTester tester) async {
  await tester.tap(find.text('Friend requests'));
  await tester.pumpAndSettle();
}

Finder _inCard(String id, String label) =>
    find.descendant(of: find.byKey(ValueKey(id)), matching: find.text(label));

void main() {
  testWidgets('loads inbox once and friend requests only when opened', (
    tester,
  ) async {
    final api = _NoNetwork();
    final notifications = _Notifications(api);
    final friends = _Friends(api);
    final account = _account();
    await tester.pumpWidget(_app(notifications, friends, account: account));
    await tester.pumpAndSettle();
    expect(notifications.reads, 1);
    expect(notifications.countReads, 0);
    expect(friends.reads, 0);
    expect(find.text('First notice'), findsOneWidget);
    expect(find.text('Hidden notice'), findsNothing);
    final counts = ProviderScope.containerOf(
      tester.element(find.byType(NotificationsScreen)),
    ).read(steamNotificationCountsProvider)[account.steamId];
    expect(counts?.unreadCount, 2);
    await _openRequests(tester);
    expect(friends.reads, 1);
    expect(find.text('SteamID 76561198000000002'), findsOneWidget);
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(notifications.reads, 1);
    expect(api.calls, isEmpty);
  });

  testWidgets(
    'mark all snapshots only visible unread IDs, including new arrival safety',
    (tester) async {
      final api = _NoNetwork();
      final notifications = _Notifications(api);
      final friends = _Friends(api);
      notifications.beforeWrite = () => notifications.items.add(
        const SteamNotification(
          id: '5',
          type: 10,
          body: {'title': 'New arrival'},
        ),
      );
      await tester.pumpWidget(_app(notifications, friends));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark this list as read'));
      await tester.pumpAndSettle();
      expect(notifications.readWrites, [
        ['1', '2'],
      ]);
      expect(
        notifications.items.singleWhere((item) => item.id == '5').read,
        isFalse,
      );
      expect(notifications.reads, 2);
      expect(find.text('Updated.'), findsOneWidget);
      expect(api.calls, isEmpty);
    },
  );

  testWidgets('single mark read and hide target only their notification', (
    tester,
  ) async {
    final api = _NoNetwork();
    final notifications = _Notifications(api);
    await tester.pumpWidget(_app(notifications, _Friends(api)));
    await tester.pumpAndSettle();
    await tester.tap(_inCard('notification-1', 'Mark as read'));
    await tester.pumpAndSettle();
    expect(notifications.readWrites, [
      ['1'],
    ]);
    expect(_inCard('notification-1', 'Mark as read'), findsNothing);
    await tester.tap(_inCard('notification-2', 'Ignore notification'));
    await tester.pumpAndSettle();
    expect(notifications.hideWrites, [
      ['2'],
    ]);
    expect(find.text('First notice'), findsNothing);
    expect(find.text('Second notice'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('notification-history-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('First notice'), findsOneWidget);
  });

  testWidgets(
    'write in flight cannot be duplicated and does not report early success',
    (tester) async {
      final api = _NoNetwork();
      final notifications = _Notifications(api)
        ..pendingWrite = Completer<void>();
      await tester.pumpWidget(_app(notifications, _Friends(api)));
      await tester.pumpAndSettle();
      await tester.tap(_inCard('notification-1', 'Mark as read'));
      await tester.pump();
      await tester.tap(_inCard('notification-1', 'Mark as read'));
      await tester.pump();
      expect(notifications.readWrites, [
        ['1'],
      ]);
      expect(find.text('Updated.'), findsNothing);
      notifications.pendingWrite!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Updated.'), findsOneWidget);
    },
  );

  testWidgets(
    'uncertain write is not retried and requires refresh before another action',
    (tester) async {
      final api = _NoNetwork();
      final notifications = _Notifications(api)
        ..writeError = TimeoutException('fixture');
      await tester.pumpWidget(_app(notifications, _Friends(api)));
      await tester.pumpAndSettle();
      await tester.tap(_inCard('notification-1', 'Ignore notification'));
      await tester.pumpAndSettle();
      expect(notifications.hideWrites, [
        ['1'],
      ]);
      expect(find.text('Updated.'), findsNothing);
      expect(
        find.text(
          'The result could not be confirmed. Refresh to check before trying again.',
        ),
        findsOneWidget,
      );
      await tester.tap(_inCard('notification-1', 'Ignore notification'));
      await tester.pumpAndSettle();
      expect(notifications.hideWrites.length, 1);
      notifications.writeError = null;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      await tester.tap(_inCard('notification-1', 'Ignore notification'));
      await tester.pumpAndSettle();
      expect(notifications.hideWrites.length, 2);
      expect(find.text('First notice'), findsNothing);
      expect(api.calls, isEmpty);
    },
  );

  for (final hide in [true, false]) {
    testWidgets(
      'notification ${hide ? 'hide' : 'read'} must be observed, not merely acknowledged',
      (tester) async {
        final api = _NoNetwork();
        final notifications = _Notifications(api)..applyWrites = false;
        await tester.pumpWidget(_app(notifications, _Friends(api)));
        await tester.pumpAndSettle();
        final action = hide ? 'Ignore notification' : 'Mark as read';
        await tester.tap(_inCard('notification-1', action));
        await tester.pumpAndSettle();
        expect(find.text('Updated.'), findsNothing);
        expect(
          find.text(
            'The result could not be confirmed. Refresh to check before trying again.',
          ),
          findsOneWidget,
        );
        expect(find.text('First notice'), findsOneWidget);
        await tester.tap(_inCard('notification-1', action));
        await tester.pumpAndSettle();
        expect(hide ? notifications.hideWrites : notifications.readWrites, [
          ['1'],
        ]);
      },
    );
  }

  testWidgets(
    'failed post-write verification cannot show a success notification',
    (tester) async {
      final api = _NoNetwork();
      final notifications = _Notifications(api);
      await tester.pumpWidget(_app(notifications, _Friends(api)));
      await tester.pumpAndSettle();
      notifications.readError = TimeoutException('fixture verification');
      await tester.tap(_inCard('notification-1', 'Mark as read'));
      await tester.pumpAndSettle();
      expect(notifications.readWrites, [
        ['1'],
      ]);
      expect(find.text('Updated.'), findsNothing);
      expect(
        find.text(
          'The result could not be confirmed. Refresh to check before trying again.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('success waits for the refreshed notification state', (
    tester,
  ) async {
    final api = _NoNetwork();
    final notifications = _Notifications(api);
    await tester.pumpWidget(_app(notifications, _Friends(api)));
    await tester.pumpAndSettle();
    notifications.pendingRead = Completer<void>();
    await tester.tap(_inCard('notification-1', 'Mark as read'));
    await tester.pump();
    expect(find.text('Updated.'), findsNothing);
    notifications.pendingRead!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Updated.'), findsOneWidget);
  });

  for (final accept in [true, false]) {
    testWidgets(
      'friend ${accept ? 'accept' : 'decline'} is one explicit verified action',
      (tester) async {
        final api = _NoNetwork();
        final friends = _Friends(api);
        await tester.pumpWidget(_app(_Notifications(api), friends));
        await tester.pumpAndSettle();
        await _openRequests(tester);
        await tester.tap(
          _inCard(
            'friend-request-76561198000000002',
            accept ? 'Accept' : 'Decline',
          ),
        );
        await tester.pumpAndSettle();
        expect(friends.writes, [('76561198000000002', accept)]);
        expect(find.text('SteamID 76561198000000002'), findsNothing);
        expect(find.text('SteamID 76561198000000003'), findsOneWidget);
        expect(friends.reads, 2);
        expect(api.calls, isEmpty);
      },
    );
  }

  testWidgets('friend uncertain result remains visible and is never replayed', (
    tester,
  ) async {
    final api = _NoNetwork();
    final friends = _Friends(api)..writeError = TimeoutException('fixture');
    await tester.pumpWidget(_app(_Notifications(api), friends));
    await tester.pumpAndSettle();
    await _openRequests(tester);
    await tester.tap(_inCard('friend-request-76561198000000002', 'Accept'));
    await tester.pumpAndSettle();
    expect(friends.writes.length, 1);
    expect(find.text('SteamID 76561198000000002'), findsOneWidget);
    expect(find.text('Updated.'), findsNothing);
    await tester.tap(_inCard('friend-request-76561198000000002', 'Decline'));
    await tester.pumpAndSettle();
    expect(friends.writes.length, 1);
    expect(api.calls, isEmpty);
  });

  testWidgets('read failures show retry without inventing an empty inbox', (
    tester,
  ) async {
    final api = _NoNetwork();
    final notifications = _Notifications(api)
      ..readError = TimeoutException('fixture');
    await tester.pumpWidget(_app(notifications, _Friends(api)));
    await tester.pumpAndSettle();
    expect(find.text('No notifications.'), findsNothing);
    final l = AppLocalizations.of(
      tester.element(find.byType(NotificationsScreen)),
    );
    expect(find.textContaining(l.notificationsLoadFailed), findsOneWidget);
    notifications.readError = null;
    await tester.tap(find.text(l.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text('First notice'), findsOneWidget);
    expect(notifications.reads, 2);
    expect(api.calls, isEmpty);
  });

  testWidgets('expired account directs to sign in instead of an empty list', (
    tester,
  ) async {
    final api = _NoNetwork();
    final notifications = _Notifications(api)
      ..readError = const CommunityAuthException(401, '/fixture');
    await tester.pumpWidget(_app(notifications, _Friends(api)));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(NotificationsScreen)),
    );
    expect(find.text(l.loginButton), findsOneWidget);
    expect(find.text('No notifications.'), findsNothing);
    expect(api.calls, isEmpty); // Fixture has no refresh token.
  });

  testWidgets('write auth failure never renews tokens or repeats the action', (
    tester,
  ) async {
    final api = _NoNetwork();
    final account = _account()..session.refreshToken = 'fixture-refresh';
    final notifications = _Notifications(api)
      ..writeError = const CommunityAuthException(401, '/fixture');
    await tester.pumpWidget(
      _app(notifications, _Friends(api), account: account),
    );
    await tester.pumpAndSettle();
    await tester.tap(_inCard('notification-1', 'Mark as read'));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(NotificationsScreen)),
    );
    expect(notifications.readWrites, [
      ['1'],
    ]);
    expect(find.text(l.loginButton), findsOneWidget);
    expect(find.text('Updated.'), findsNothing);
    expect(api.calls, isEmpty);
  });

  testWidgets(
    'old list cannot send actions after the account session changes',
    (tester) async {
      final api = _NoNetwork();
      final account = _account();
      final notifications = _Notifications(api);
      await tester.pumpWidget(
        _app(notifications, _Friends(api), account: account),
      );
      await tester.pumpAndSettle();
      account.session.accessToken = 'fixture-relogin';
      await tester.tap(_inCard('notification-1', 'Mark as read'));
      await tester.pumpAndSettle();
      expect(notifications.readWrites, isEmpty);
      final l = AppLocalizations.of(
        tester.element(find.byType(NotificationsScreen)),
      );
      expect(
        find.textContaining(l.notificationsSessionChanged),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      await tester.tap(_inCard('notification-1', 'Mark as read'));
      await tester.pumpAndSettle();
      expect(notifications.readWrites, [
        ['1'],
      ]);
    },
  );

  testWidgets('late response from an old session is discarded', (tester) async {
    final api = _NoNetwork();
    final account = _account();
    final notifications = _Notifications(api)..pendingRead = Completer<void>();
    await tester.pumpWidget(
      _app(notifications, _Friends(api), account: account),
    );
    await tester.pump();
    account.session.accessToken = 'fixture-relogin';
    notifications.pendingRead!.complete();
    await tester.pumpAndSettle();
    expect(find.text('First notice'), findsNothing);
    final counts = ProviderScope.containerOf(
      tester.element(find.byType(NotificationsScreen)),
    ).read(steamNotificationCountsProvider);
    expect(counts, isEmpty);
    expect(notifications.readWrites, isEmpty);
  });

  testWidgets(
    'successful read retry binds the refreshed session for later actions',
    (tester) async {
      final api = _NoNetwork()..refreshedToken = 'fixture-renewed';
      final account = _account()..session.refreshToken = 'fixture-refresh';
      final notifications = _Notifications(api)
        ..firstReadError = const CommunityAuthException(401, '/fixture');
      await tester.pumpWidget(
        _app(notifications, _Friends(api), account: account),
      );
      await tester.pumpAndSettle();
      expect(account.session.accessToken, 'fixture-renewed');
      expect(notifications.reads, 2);
      await tester.tap(_inCard('notification-1', 'Mark as read'));
      await tester.pumpAndSettle();
      expect(notifications.readWrites, [
        ['1'],
      ]);
      expect(find.text('Updated.'), findsOneWidget);
      expect(api.calls, ['GenerateAccessTokenForApp']);
    },
  );

  testWidgets(
    'session changed during write cannot report success in the new session',
    (tester) async {
      final api = _NoNetwork();
      final account = _account();
      final notifications = _Notifications(api)
        ..pendingWrite = Completer<void>();
      await tester.pumpWidget(
        _app(notifications, _Friends(api), account: account),
      );
      await tester.pumpAndSettle();
      await tester.tap(_inCard('notification-1', 'Mark as read'));
      await tester.pump();
      account.session.accessToken = 'fixture-relogin';
      notifications.pendingWrite!.complete();
      await tester.pumpAndSettle();
      expect(notifications.readWrites, [
        ['1'],
      ]);
      expect(find.text('Updated.'), findsNothing);
      expect(notifications.reads, 1);
      final l = AppLocalizations.of(
        tester.element(find.byType(NotificationsScreen)),
      );
      expect(
        find.textContaining(l.notificationsSessionChanged),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'unknown notification content never displays raw body fields or follows links',
    (tester) async {
      final api = _NoNetwork();
      final notifications = _Notifications(api)
        ..items = [
          const SteamNotification(
            id: '77',
            type: 999,
            body: {
              'private_token': 'do-not-display',
              'url': 'https://untrusted.invalid',
            },
          ),
        ];
      await tester.pumpWidget(_app(notifications, _Friends(api)));
      await tester.pumpAndSettle();
      expect(find.text('Steam notification'), findsOneWidget);
      expect(find.textContaining('do-not-display'), findsNothing);
      expect(find.textContaining('untrusted.invalid'), findsNothing);
      expect(notifications.readWrites, isEmpty);
      expect(notifications.hideWrites, isEmpty);
      expect(api.calls, isEmpty);
    },
  );

  testWidgets(
    'leaving during write avoids stale UI while completing only once',
    (tester) async {
      final api = _NoNetwork();
      final notifications = _Notifications(api)
        ..pendingWrite = Completer<void>();
      await tester.pumpWidget(_app(notifications, _Friends(api)));
      await tester.pumpAndSettle();
      await tester.tap(_inCard('notification-1', 'Mark as read'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      notifications.pendingWrite!.complete();
      await tester.pumpAndSettle();
      expect(notifications.readWrites, [
        ['1'],
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'returning to the previous page still refreshes counts after a write',
    (tester) async {
      final api = _NoNetwork();
      final account = _account();
      final notifications = _Notifications(api)
        ..pendingWrite = Completer<void>();
      await tester.pumpWidget(
        _app(notifications, _Friends(api), account: account),
      );
      await tester.pumpAndSettle();
      final navigator = Navigator.of(
        tester.element(find.byType(NotificationsScreen)),
      );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => NotificationsScreen(account: account),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_inCard('notification-1', 'Mark as read'));
      await tester.pump();
      navigator.pop();
      await tester.pumpAndSettle();
      notifications.pendingWrite!.complete();
      await tester.pumpAndSettle();
      expect(notifications.readWrites, [
        ['1'],
      ]);
      expect(notifications.countReads, 1);
      final counts = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsScreen)),
      ).read(steamNotificationCountsProvider)[account.steamId];
      expect(counts?.unreadCount, 1);
      expect(counts?.stale, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('friend nickname is shown together with its exact SteamID', (
    tester,
  ) async {
    final api = _NoNetwork();
    final friends = _Friends(api);
    friends.requests[0] = const SteamFriendRequest(
      steamId: '76561198000000002',
      name: 'Fixture nickname',
    );
    await tester.pumpWidget(_app(_Notifications(api), friends));
    await tester.pumpAndSettle();
    await _openRequests(tester);
    expect(find.text('Fixture nickname'), findsOneWidget);
    expect(find.text('SteamID 76561198000000002'), findsOneWidget);
    expect(friends.reads, 1);
  });

  testWidgets(
    'comment text and inventory type render without fetching item details',
    (tester) async {
      final api = _NoNetwork();
      final notifications = _Notifications(api)
        ..items = [
          const SteamNotification(
            id: '20',
            type: 3,
            body: {'text': 'Fixture comment content'},
          ),
          const SteamNotification(
            id: '21',
            type: 4,
            body: {'app_id': 730, 'asset_id': '12345'},
          ),
        ];
      await tester.pumpWidget(_app(notifications, _Friends(api)));
      await tester.pumpAndSettle();
      expect(find.text('Comment'), findsOneWidget);
      expect(find.text('Fixture comment content'), findsOneWidget);
      expect(find.text('Inventory item'), findsOneWidget);
      expect(find.textContaining('asset_id'), findsNothing);
      expect(notifications.reads, 1);
      expect(api.calls, isEmpty);
    },
  );

  testWidgets(
    'Steam links are fixed trusted pages and open only after explicit taps',
    (tester) async {
      final api = _NoNetwork();
      final notifications = _Notifications(api)
        ..items = [
          const SteamNotification(
            id: '20',
            type: 100,
            body: {
              'url': 'https://untrusted.invalid',
              'link': 'https://steamcommunity.com.untrusted.invalid',
            },
          ),
        ];
      final opened = <Uri>[];
      await tester.pumpWidget(
        _app(
          notifications,
          _Friends(api),
          launch: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      await tester.tap(find.text('View in Steam'));
      await tester.pumpAndSettle();
      expect(
        opened.single.toString(),
        'https://steamcommunity.com/profiles/76561198000000001/notifications',
      );
      await _openRequests(tester);
      final l = AppLocalizations.of(
        tester.element(find.byType(NotificationsScreen)),
      );
      await tester.tap(
        _inCard('friend-request-76561198000000002', l.friendsProfile),
      );
      await tester.pumpAndSettle();
      expect(
        opened.last.toString(),
        'https://steamcommunity.com/profiles/76561198000000002/',
      );
      expect(opened.length, 2);
    },
  );

  for (final variant in AvaThemeVariant.values) {
    testWidgets(
      '$variant notifications and friend actions fit a narrow phone',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = _NoNetwork();
        await tester.pumpWidget(
          _app(_Notifications(api), _Friends(api), variant: variant),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _openRequests(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
