import 'dart:async';
import 'dart:ui' as ui;

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/route_observer.dart';
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
import 'package:ava/src/services/steam_request_scope.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/friends/friends_screen.dart'
    show friendsClientProvider;
import 'package:ava/src/ui/notifications/notifications_screen.dart';
import 'package:ava/src/ui/widgets/steam_image_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoNetwork extends SteamApiClient {
  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) => throw StateError('Unexpected transport in fixture: $iface/$method');
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
}

class _Notifications extends SteamNotificationsClient {
  _Notifications(this.items, this.now) : super(_NoNetwork());
  final List<SteamNotification> items;
  final DateTime Function() now;
  final calls = <(int, String?, int?, String?, String?)>[];
  final times = <DateTime>[];
  final scopes = <CancelToken?>[];
  Future<SteamNotificationItem?> Function(SteamNotification)? onDetail;

  @override
  Future<SteamNotificationInbox> fetch(SteamGuardAccount account) async =>
      SteamNotificationInbox(
        notifications: items,
        counts: SteamNotificationCounts(
          unreadCount: items.where((item) => !item.read && !item.hidden).length,
        ),
      );

  @override
  Future<SteamNotificationItem?> fetchInventoryNotificationItem(
    SteamGuardAccount account,
    SteamNotification item,
  ) async {
    calls.add((
      account.steamId,
      account.session.accessToken,
      item.inventoryAppId,
      item.contextId,
      item.assetId,
    ));
    times.add(now());
    scopes.add(SteamRequestScope.currentCancelToken);
    return onDetail == null ? _detail(item) : onDetail!(item);
  }
}

class _Friends extends FriendsClient {
  _Friends(super.api);
  @override
  Future<List<SteamFriendRequest>> fetchRequests(
    SteamGuardAccount account,
  ) async => [];
}

class _DetailsEnabled extends Notifier<bool> {
  @override
  bool build() => true;
  void disable() => state = false;
}

final _detailsEnabledProvider = NotifierProvider<_DetailsEnabled, bool>(
  _DetailsEnabled.new,
);

SteamGuardAccount _account() => SteamGuardAccount(
  accountName: 'fixture',
  session: SessionData(
    steamId: 76561198000000001,
    accessToken: 'fixture-token',
  ),
);

SteamNotification _inventory(
  String id, {
  bool read = false,
  String context = '2',
  String? asset,
  int timestamp = 1,
}) => SteamNotification(
  id: id,
  type: 4,
  read: read,
  timestamp: timestamp,
  body: {'app_id': '730', 'context_id': context, 'asset_id': asset ?? '100$id'},
);

SteamNotificationItem _detail(
  SteamNotification item, {
  String? name,
  String icon = '',
}) => SteamNotificationItem(
  appId: item.inventoryAppId!,
  contextId: item.contextId!,
  assetId: item.assetId!,
  name: name ?? 'Fixture item ${item.assetId}',
  iconUrl: icon,
);

Widget _app(
  WidgetTester tester,
  _Notifications notifications, {
  SteamGuardAccount? account,
  GlobalKey<NavigatorState>? navigatorKey,
  double textScale = 1,
}) {
  final identity = account ?? _account();
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(notifications.api),
      appControllerProvider.overrideWith(() => _Controller(identity)),
      steamNotificationsClientProvider.overrideWithValue(notifications),
      friendsClientProvider.overrideWithValue(_Friends(notifications.api)),
      steamNotificationCountsEnabledProvider.overrideWith(
        (ref) => ref.watch(_detailsEnabledProvider),
      ),
      notificationDetailsClockProvider.overrideWithValue(
        tester.binding.clock.now,
      ),
      notificationsLauncherProvider.overrideWithValue(
        (_) async => throw StateError('Unexpected browser launch'),
      ),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      theme: buildAvaTheme(
        AvaThemeVariant.light,
      ).copyWith(platform: TargetPlatform.android),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: NotificationsScreen(account: identity),
    ),
  );
}

Future<void> _history(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('notification-history-toggle')));
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('read inventory history starts collapsed without detail reads', (
    tester,
  ) async {
    final client = _Notifications([
      for (var i = 1; i <= 20; i++) _inventory('$i', read: true),
    ], tester.binding.clock.now);
    await tester.pumpWidget(_app(tester, client));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(
      find.byKey(const ValueKey('notification-history-toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('notification-1')), findsNothing);
    expect(client.calls, isEmpty);
  });

  testWidgets('expanded history resolves its exact asset name and thumbnail', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final item = _inventory(
      '1',
      read: true,
      context: '16',
      asset: '18446744073709551614',
    );
    const icon =
        'https://community.fastly.steamstatic.com/economy/image/fixture/128fx128f';
    final client = _Notifications([item], tester.binding.clock.now)
      ..onDetail = (item) async =>
          _detail(item, name: 'Fixture CS2 rifle', icon: icon);
    // Seed Flutter's decoded image cache so this exercises the thumbnail widget
    // without touching the disk image cache or making an HTTP request.
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
    final picture = recorder.endRecording();
    final pixel = await tester.runAsync(() => picture.toImage(1, 1));
    final imageProvider = steamThumbnailProvider(
      icon,
      logicalSize: const Size.square(56),
      devicePixelRatio: 1,
    );
    final imageKey = await imageProvider.obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.putIfAbsent(
      imageKey,
      () =>
          OneFrameImageStreamCompleter(Future.value(ImageInfo(image: pixel!))),
    );
    addTearDown(() {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      picture.dispose();
    });
    await tester.pumpWidget(_app(tester, client));
    await tester.pumpAndSettle();
    expect(client.calls, isEmpty);
    await _history(tester);
    expect(client.calls, [
      (76561198000000001, 'fixture-token', 730, '16', '18446744073709551614'),
    ]);
    expect(find.text('Fixture CS2 rifle'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as ResizeImage).imageProvider,
      const SteamImageProvider(icon),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history is descending within read state while unread stays first',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = _Notifications(const [
        SteamNotification(
          id: 'old',
          type: 10,
          read: true,
          timestamp: 10,
          body: {'title': 'Older history'},
        ),
        SteamNotification(
          id: 'new',
          type: 10,
          read: true,
          timestamp: 30,
          body: {'title': 'Newer history'},
        ),
        SteamNotification(
          id: 'unread',
          type: 10,
          timestamp: 1,
          body: {'title': 'Unread first'},
        ),
      ], tester.binding.clock.now);
      await tester.pumpWidget(_app(tester, client));
      await tester.pumpAndSettle();
      expect(find.text('Older history'), findsNothing);
      await _history(tester);
      final unreadY = tester.getTopLeft(find.text('Unread first')).dy;
      final newerY = tester.getTopLeft(find.text('Newer history')).dy;
      final olderY = tester.getTopLeft(find.text('Older history')).dy;
      expect(unreadY, lessThan(newerY));
      expect(newerY, lessThan(olderY));
      expect(client.calls, isEmpty);
    },
  );

  testWidgets('late details from a replaced session never appear or cache', (
    tester,
  ) async {
    final pending = Completer<SteamNotificationItem?>();
    final item = _inventory('1');
    final account = _account();
    final client = _Notifications([item], tester.binding.clock.now)
      ..onDetail = (_) => pending.future;
    await tester.pumpWidget(_app(tester, client, account: account));
    await tester.pumpAndSettle();
    account.session.accessToken = 'new-fixture-token';
    pending.complete(_detail(item, name: 'Old session item'));
    await tester.pumpAndSettle();
    expect(find.text('Old session item'), findsNothing);
    client.onDetail = (item) async => _detail(item, name: 'New session item');
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(client.calls.last.$2, 'new-fixture-token');
    expect(find.text('New session item'), findsOneWidget);
    expect(find.text('Old session item'), findsNothing);
  });

  testWidgets('visible item cache survives tab switches and history folding', (
    tester,
  ) async {
    final client = _Notifications([
      _inventory('1', read: true),
    ], tester.binding.clock.now);
    await tester.pumpWidget(_app(tester, client));
    await tester.pumpAndSettle();
    await _history(tester);
    expect(client.calls, hasLength(1));
    await _history(tester);
    await _history(tester);
    await tester.tap(find.text('Friend requests'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Fixture item 1001'), findsOneWidget);
    expect(client.calls, hasLength(1));
  });

  testWidgets(
    'detail reads are serial and separated by exactly one virtual second',
    (tester) async {
      final client = _Notifications([
        _inventory('1'),
        _inventory('2'),
      ], tester.binding.clock.now);
      await tester.pumpWidget(_app(tester, client));
      await tester.pumpAndSettle();
      expect(client.calls, hasLength(1));
      final remaining = client.times.single
          .add(const Duration(seconds: 1))
          .difference(tester.binding.clock.now());
      await tester.pump(remaining - const Duration(milliseconds: 1));
      expect(client.calls, hasLength(1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(client.calls, hasLength(2));
      expect(
        client.times[1].difference(client.times[0]),
        const Duration(seconds: 1),
      );
      await _dispose(tester);
    },
  );

  testWidgets('pending read blocks later rows even after the request gap', (
    tester,
  ) async {
    final first = Completer<SteamNotificationItem?>();
    final items = [_inventory('1'), _inventory('2')];
    final client = _Notifications(items, tester.binding.clock.now)
      ..onDetail = (item) =>
          item.id == '1' ? first.future : Future.value(_detail(item));
    await tester.pumpWidget(_app(tester, client));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(client.calls, hasLength(1));
    first.complete(_detail(items.first));
    await tester.pumpAndSettle();
    expect(client.calls, hasLength(2));
  });

  testWidgets('switching tabs cancels the active read and skips queued rows', (
    tester,
  ) async {
    final pending = Completer<SteamNotificationItem?>();
    final client = _Notifications([
      _inventory('1'),
      _inventory('2'),
    ], tester.binding.clock.now)..onDetail = (_) => pending.future;
    await tester.pumpWidget(_app(tester, client));
    await tester.pumpAndSettle();
    expect(client.calls, hasLength(1));
    expect(client.scopes.single?.isCancelled, isFalse);
    await tester.tap(find.text('Friend requests'));
    await tester.pumpAndSettle();
    expect(client.scopes.single?.isCancelled, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(client.calls, hasLength(1));
    await _dispose(tester);
  });

  testWidgets('covering the route cancels details and suppresses queued rows', (
    tester,
  ) async {
    final pending = Completer<SteamNotificationItem?>();
    final client = _Notifications([
      _inventory('1'),
      _inventory('2'),
    ], tester.binding.clock.now)..onDetail = (_) => pending.future;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(tester, client, navigatorKey: navigator));
    await tester.pumpAndSettle();
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Fixture next page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(client.scopes.single?.isCancelled, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(client.calls, hasLength(1));
    await _dispose(tester);
  });

  testWidgets('backgrounding cancels the active detail request', (
    tester,
  ) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    final pending = Completer<SteamNotificationItem?>();
    final client = _Notifications([
      _inventory('1'),
      _inventory('2'),
    ], tester.binding.clock.now)..onDetail = (_) => pending.future;
    await tester.pumpWidget(_app(tester, client));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(client.scopes.single?.isCancelled, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(client.calls, hasLength(1));
    await _dispose(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('locking cancels details before another rendering frame', (
    tester,
  ) async {
    final pending = Completer<SteamNotificationItem?>();
    final client = _Notifications([
      _inventory('1'),
      _inventory('2'),
    ], tester.binding.clock.now)..onDetail = (_) => pending.future;
    await tester.pumpWidget(_app(tester, client));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NotificationsScreen)),
    );
    container.read(_detailsEnabledProvider.notifier).disable();
    expect(container.read(steamNotificationCountsEnabledProvider), isFalse);
    expect(client.scopes.single?.isCancelled, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(client.calls, hasLength(1));
    await _dispose(tester);
  });

  testWidgets(
    'eight-second timeout keeps a useful inventory event without replay',
    (tester) async {
      final pending = Completer<SteamNotificationItem?>();
      final client = _Notifications([_inventory('1')], tester.binding.clock.now)
        ..onDetail = (_) => pending.future;
      await tester.pumpWidget(_app(tester, client));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(client.scopes.single?.isCancelled, isTrue);
      expect(find.textContaining('Counter-Strike 2'), findsOneWidget);
      expect(find.text('View inventory'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(client.calls, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long item metadata wraps on a narrow large-text phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _Notifications([_inventory('1')], tester.binding.clock.now)
      ..onDetail = (item) async => _detail(
        item,
        name: 'Fixture Counter-Strike item with a long descriptive name',
      );
    await tester.pumpWidget(_app(tester, client, textScale: 1.6));
    await tester.pumpAndSettle();
    expect(
      find.text('Fixture Counter-Strike item with a long descriptive name'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
