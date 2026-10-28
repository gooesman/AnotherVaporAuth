import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/responsive.dart';
import '../../app/route_observer.dart';
import '../../app/steam_notifications_provider.dart';
import '../../app/theme.dart';
import '../../core/models/steam_friend.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/models/steam_notification.dart';
import '../../services/session_manager.dart';
import '../../services/steam_request_scope.dart';
import '../friends/friends_screen.dart' show friendsClientProvider;
import '../market/market_screen.dart';
import '../pending/pending_screen.dart';
import '../pending/session_retry.dart';
import '../widgets/ava_panel.dart';
import '../widgets/steam_image_provider.dart';

final notificationsLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

final notificationDetailsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class NotificationsScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;

  const NotificationsScreen({super.key, required this.account});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with
        SingleTickerProviderStateMixin,
        SessionRetryState,
        WidgetsBindingObserver,
        RouteAware {
  late final TabController _tabs;
  SteamNotificationInbox? _inbox;
  List<SteamFriendRequest>? _requests;
  final _loading = [false, false];
  final List<String?> _errors = [null, null];
  final _needsLogin = [false, false];
  final _writeNeedsRefresh = [false, false];
  final List<(int, String?, String?)?> _listSessions = [null, null];
  bool _busy = false;
  bool _showHistory = false;
  bool _foreground = true;
  bool _covered = false;
  PageRoute<void>? _route;
  int _detailsGeneration = 0;
  final _itemDetails = <String, SteamNotificationItem?>{};
  Future<void> _detailsQueue = Future.value();
  DateTime? _lastDetailRequest;
  final _detailReads = <SteamRequestScope>{};

  (int, String?, String?) get _session => (
    widget.account.steamId,
    widget.account.session.accessToken,
    widget.account.session.refreshToken,
  );

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(_ensureTabLoaded);
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _load(0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void> && !identical(_route, route)) {
      routeObserver.unsubscribe(this);
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancelDetails();
    if (mounted) {
      setState(() => _foreground = state == AppLifecycleState.resumed);
    }
  }

  @override
  void didPushNext() {
    _cancelDetails();
    setState(() => _covered = true);
  }

  @override
  void didPopNext() => setState(() => _covered = false);

  @override
  void dispose() {
    _cancelDetails();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    super.dispose();
  }

  void _cancelDetails() {
    _detailsGeneration++;
    for (final scope in _detailReads) {
      scope.cancel();
    }
    _detailReads.clear();
  }

  void _ensureTabLoaded() {
    if (mounted) setState(() {});
    if (_busy) return;
    final index = _tabs.index;
    if (_errors[index] == null &&
        (index == 0 ? _inbox == null : _requests == null)) {
      _load(index);
    }
  }

  Future<void> _load(int index) async {
    if (_loading[index]) return;
    setState(() {
      _loading[index] = true;
      _errors[index] = null;
      _needsLogin[index] = false;
    });
    final account = widget.account;
    (int, String?, String?)? readSession;
    try {
      if (index == 0) {
        final inbox = await fetchWithAutoRefresh(account, () {
          readSession = _session;
          return ref.read(steamNotificationsClientProvider).fetch(account);
        }, retryOnAnyError: false);
        if (!mounted) return;
        if (readSession != _session) {
          setState(
            () => _errors[index] = AppLocalizations.of(
              context,
            ).notificationsSessionChanged,
          );
          return;
        }
        setState(() {
          if (_listSessions[index] != readSession) {
            _itemDetails.clear();
          } else {
            _itemDetails.removeWhere((_, detail) => detail == null);
          }
          _detailsGeneration++;
          _inbox = inbox;
          _listSessions[index] = readSession;
          _writeNeedsRefresh[index] = false;
        });
        ref
            .read(steamNotificationCountsProvider.notifier)
            .recordCounts(account, inbox.counts);
      } else {
        final requests = await fetchWithAutoRefresh(account, () {
          readSession = _session;
          return ref.read(friendsClientProvider).fetchRequests(account);
        }, retryOnAnyError: false);
        if (!mounted) return;
        if (readSession != _session) {
          setState(
            () => _errors[index] = AppLocalizations.of(
              context,
            ).notificationsSessionChanged,
          );
          return;
        }
        setState(() {
          _requests = requests;
          _listSessions[index] = readSession;
          _writeNeedsRefresh[index] = false;
        });
        ref
            .read(steamNotificationCountsProvider.notifier)
            .recordFriendRequestCount(account, requests.length);
      }
    } catch (error) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        setState(() {
          _needsLogin[index] = SessionManager.isAuthenticationError(error);
          _errors[index] = _needsLogin[index]
              ? l.confNeedsLogin
              : l.notificationsLoadFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _loading[index] = false);
    }
  }

  Future<void> _write(
    int index,
    Future<void> Function() action, {
    bool Function()? isApplied,
  }) async {
    if (!_canWrite(index)) return;
    final l = AppLocalizations.of(context);
    final session = _session;
    if (_listSessions[index] != session) {
      setState(() => _errors[index] = l.notificationsSessionChanged);
      return;
    }
    final counts = ref.read(steamNotificationCountsProvider.notifier);
    setState(() => _busy = true);
    try {
      // Writes are sent once. A timeout may mean Steam already applied it.
      await action();
      if (_session == session) {
        counts.invalidate(widget.account);
        // Visible lists supply their own counts; after leaving, read only
        // the lightweight counters.
        if (!mounted) {
          unawaited(counts.refresh(widget.account, force: true));
        }
      }
      if (!mounted) return;
      if (_session != session) {
        setState(() {
          _errors[index] = l.notificationsSessionChanged;
          _writeNeedsRefresh[index] = true;
        });
        return;
      }
      await _load(index);
      if (!mounted) return;
      if (_errors[index] != null ||
          _listSessions[index] != session ||
          (isApplied != null && !isApplied())) {
        setState(() => _writeNeedsRefresh[index] = true);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.notificationsActionDone)));
    } catch (error) {
      if (_session == session) counts.invalidate(widget.account);
      if (!mounted) return;
      if (_session != session) {
        setState(() {
          _errors[index] = l.notificationsSessionChanged;
          _writeNeedsRefresh[index] = true;
        });
        return;
      }
      setState(() => _writeNeedsRefresh[index] = true);
      if (SessionManager.isAuthenticationError(error)) {
        setState(() {
          _needsLogin[index] = true;
          _errors[index] = l.confNeedsLogin;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _ensureTabLoaded();
      }
    }
  }

  Future<void> _updateNotifications(List<String> ids, {bool hide = false}) =>
      _write(
        0,
        () {
          final client = ref.read(steamNotificationsClientProvider);
          return hide
              ? client.hide(widget.account, ids)
              : client.markRead(widget.account, ids);
        },
        isApplied: () =>
            _inbox?.notifications.every(
              (item) =>
                  !ids.contains(item.id) || item.hidden || (!hide && item.read),
            ) ??
            false,
      );

  Future<void> _openSteam(Uri uri) async {
    var opened = false;
    try {
      opened = await ref.read(notificationsLauncherProvider)(uri);
    } catch (_) {
      // Missing browser/platform handler is reported without exposing URLs.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).notificationsOpenFailed),
        ),
      );
    }
  }

  bool get _actionsEnabled => !_busy && !_loading.any((value) => value);
  bool _canWrite(int index) => _actionsEnabled && !_writeNeedsRefresh[index];

  bool get _detailsActive =>
      mounted &&
      _foreground &&
      !_covered &&
      _tabs.index == 0 &&
      ref.read(steamNotificationCountsEnabledProvider) &&
      _listSessions[0] == _session;

  Future<SteamNotificationItem?> _loadItemDetails(
    SteamNotification item,
    SteamRequestScope scope,
    bool Function() visible,
  ) async {
    final session = _session;
    final generation = _detailsGeneration;
    final language = ref
        .read(steamNotificationsClientProvider)
        .api
        .steamLanguage;
    final key =
        '${item.inventoryAppId}/${item.contextId}/${item.assetId}/$language';
    bool current() =>
        visible() &&
        _detailsActive &&
        _session == session &&
        generation == _detailsGeneration;
    final previous = _detailsQueue;
    final done = Completer<void>();
    _detailsQueue = done.future;
    try {
      await previous;
      if (!current()) return null;
      if (_itemDetails.containsKey(key)) return _itemDetails[key];
      if (_lastDetailRequest != null) {
        final wait =
            const Duration(seconds: 1) -
            ref
                .read(notificationDetailsClockProvider)()
                .difference(_lastDetailRequest!);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      if (!current()) return null;
      _lastDetailRequest = ref.read(notificationDetailsClockProvider)();
      _detailReads.add(scope);
      final detail = await scope.run(
        () => ref
            .read(steamNotificationsClientProvider)
            .fetchInventoryNotificationItem(widget.account, item),
      );
      if (current()) _itemDetails[key] = detail;
      return current() ? detail : null;
    } finally {
      _detailReads.remove(scope);
      done.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final snapshot = ref.watch(
      steamNotificationCountsProvider.select(
        (counts) => counts[widget.account.steamId],
      ),
    );
    final unreadCount = snapshot?.matches(widget.account) == true
        ? snapshot!.unreadCount
        : null;
    final requestCount = _requests != null && _listSessions[1] == _session
        ? _requests!.length
        : snapshot?.matches(widget.account) == true
        ? snapshot!.pendingFriendCount
        : null;
    ref.watch(steamNotificationCountsEnabledProvider);
    ref.listen(steamNotificationCountsEnabledProvider, (_, enabled) {
      if (!enabled) _cancelDetails();
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: l.commonRefresh,
            onPressed: _actionsEnabled ? () => _load(_tabs.index) : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: Badge(
                isLabelVisible: (unreadCount ?? 0) > 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(l.notificationsInboxTab),
                ),
              ),
            ),
            Tab(
              child: Badge(
                isLabelVisible: (requestCount ?? 0) > 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(l.notificationsRequestsTab),
                ),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _withWriteNotice(0, _notificationList(l), l),
          _withWriteNotice(1, _requestList(l), l),
        ],
      ),
    );
  }

  Widget _withWriteNotice(int index, Widget child, AppLocalizations l) =>
      Column(
        children: [
          if (_writeNeedsRefresh[index])
            Padding(
              padding: context.rInsets(h: 16, top: 12),
              child: Text(l.notificationsActionUnconfirmed),
            ),
          Expanded(child: child),
        ],
      );

  Widget? _status(int index, AppLocalizations l) {
    if (_loading[index]) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errors[index] != null) {
      return scrollableCentered(
        sessionErrorBody(
          l,
          Theme.of(context).extension<AvaTokens>()!,
          error: _errors[index]!,
          needsLogin: _needsLogin[index],
          onSignIn: () => signInThen(widget.account, () => _load(index)),
          onRetry: () => _load(index),
        ),
      );
    }
    return null;
  }

  Widget _notificationList(AppLocalizations l) {
    final status = _status(0, l);
    if (status != null) return status;
    final all =
        _inbox?.notifications.where((item) => !item.hidden).toList() ??
        const <SteamNotification>[];
    if (all.isEmpty) return Center(child: Text(l.notificationsEmpty));
    final unread = all
        .where((item) => !item.read)
        .map((item) => item.id)
        .toList();
    final historyCount = all.length - unread.length;
    final items = all.where((item) => _showHistory || !item.read).toList()
      ..sort((a, b) {
        final readOrder = (a.read ? 1 : 0).compareTo(b.read ? 1 : 0);
        return readOrder != 0 ? readOrder : b.timestamp.compareTo(a.timestamp);
      });
    return ListView.separated(
      scrollCacheExtent: const ScrollCacheExtent.pixels(0),
      padding: context.rSafeInsets(all: 16),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (unread.isEmpty) Text(l.notificationsNoUnread),
              if (unread.isNotEmpty)
                TextButton.icon(
                  onPressed: _canWrite(0)
                      ? () => _updateNotifications(unread)
                      : null,
                  icon: const Icon(Icons.done_all),
                  label: Text(l.notificationsMarkAllRead),
                ),
              if (historyCount > 0)
                TextButton.icon(
                  key: const ValueKey('notification-history-toggle'),
                  onPressed: () => setState(() => _showHistory = !_showHistory),
                  icon: Icon(_showHistory ? Icons.expand_less : Icons.history),
                  label: Text(
                    _showHistory
                        ? l.notificationsCollapseHistory
                        : l.notificationsHistory(historyCount),
                  ),
                ),
            ],
          );
        }
        return _notificationCard(items[index - 1], l);
      },
    );
  }

  Widget _notificationCard(SteamNotification item, AppLocalizations l) {
    if (item.type == 4 &&
        item.inventoryAppId != null &&
        item.contextId != null &&
        item.assetId != null &&
        _detailsActive) {
      return _InventoryNotificationDetails(
        key: ValueKey('notification-details-${item.id}-$_detailsGeneration'),
        load: (scope, visible) => _loadItemDetails(item, scope, visible),
        builder: (detail, loading) =>
            _notificationContent(item, l, detail: detail, loading: loading),
      );
    }
    return _notificationContent(item, l);
  }

  String _gameName(int? appId) => switch (appId) {
    730 => 'Counter-Strike 2',
    570 => 'Dota 2',
    440 => 'Team Fortress 2',
    753 => 'Steam',
    null => 'Steam',
    _ => 'App $appId',
  };

  Widget _notificationContent(
    SteamNotification item,
    AppLocalizations l, {
    SteamNotificationItem? detail,
    bool loading = false,
  }) {
    final category = switch (item.type) {
      2 => l.notificationsTypeGift,
      3 => l.notificationsTypeComment,
      4 => l.notificationsTypeInventory,
      5 => l.notificationsTypeFriend,
      6 => l.notificationsTypeSale,
      8 => l.notificationsTypeWishlist,
      9 => l.notificationsTypeTrade,
      10 => l.notificationsTypeAccount,
      11 => l.notificationsTypeSupport,
      14 => l.notificationsTypeModeration,
      16 => l.notificationsTypeFamily,
      28 => l.notificationsTypePlaytest,
      29 => l.notificationsTypeTradeReversal,
      30 => l.notificationsTypeReport,
      _ => l.notificationsItemTitle,
    };
    final game = detail?.gameName.isNotEmpty == true
        ? detail!.gameName
        : _gameName(item.inventoryAppId);
    final body =
        item.displayBody ??
        switch (item.type) {
          4 => l.notificationsInventoryReceived(game),
          5 => l.notificationsFriendSummary,
          9 => l.notificationsTradeSummary,
          _ => l.notificationsItemFallback,
        };
    final title = detail?.name ?? item.displayTitle ?? category;
    final t = Theme.of(context).extension<AvaTokens>()!;
    return AvaPanel(
      key: ValueKey('notification-${item.id}'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.type == 4) ...[
                SizedBox.square(
                  dimension: 56,
                  child: detail?.iconUrl.isNotEmpty == true
                      ? Image(
                          image: steamThumbnailProvider(
                            detail!.iconUrl,
                            logicalSize: const Size.square(56),
                            devicePixelRatio: MediaQuery.devicePixelRatioOf(
                              context,
                            ),
                          ),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.inventory_2_outlined),
                        )
                      : Icon(Icons.inventory_2_outlined, color: t.muted),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(body),
                    if (item.partnerSteamId != null)
                      Text(
                        'SteamID ${item.partnerSteamId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (item.type == 4 && detail == null)
                      Text(
                        loading
                            ? l.notificationsItemLoading
                            : l.notificationsItemUnavailable,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: t.muted),
                      ),
                  ],
                ),
              ),
              if (!item.read) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: l.notificationsUnread,
                  child: Icon(Icons.circle, size: 8, color: t.accent),
                ),
              ],
            ],
          ),
          if (item.timestamp > 0) ...[
            const SizedBox(height: 8),
            Text(
              MaterialLocalizations.of(context).formatFullDate(
                DateTime.fromMillisecondsSinceEpoch(
                  item.timestamp * 1000,
                ).toLocal(),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (!item.read)
                TextButton(
                  onPressed: _canWrite(0)
                      ? () => _updateNotifications([item.id])
                      : null,
                  child: Text(l.notificationsMarkRead),
                ),
              TextButton(
                onPressed: _canWrite(0)
                    ? () => _updateNotifications([item.id], hide: true)
                    : null,
                child: Text(l.notificationsHide),
              ),
              if (item.type == 4)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MarketScreen(
                        account: widget.account,
                        initialAppId: item.inventoryAppId,
                        initialContextId: item.contextId,
                      ),
                    ),
                  ),
                  child: Text(l.notificationsOpenInventory),
                )
              else if (item.type == 9)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PendingScreen(account: widget.account, initialTab: 1),
                    ),
                  ),
                  child: Text(l.pendingTabOffers),
                )
              else if (item.type == 5)
                TextButton(
                  onPressed: () => _tabs.animateTo(1),
                  child: Text(l.notificationsRequestsTab),
                )
              else if (isIndividualSteamId('${widget.account.steamId}'))
                TextButton(
                  onPressed: () => _openSteam(
                    Uri.https(
                      'steamcommunity.com',
                      '/profiles/${widget.account.steamId}/notifications',
                    ),
                  ),
                  child: Text(l.notificationsOpenSteam),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _requestList(AppLocalizations l) {
    final status = _status(1, l);
    if (status != null) return status;
    final requests = _requests;
    if (requests == null) return const SizedBox.shrink();
    if (requests.isEmpty) {
      return Center(child: Text(l.notificationsRequestsEmpty));
    }
    return ListView.separated(
      padding: context.rSafeInsets(all: 16),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final request = requests[index];
        final hasName = request.name.trim().isNotEmpty;
        return AvaPanel(
          key: ValueKey('friend-request-${request.steamId}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasName ? request.name : 'SteamID ${request.steamId}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (hasName) Text('SteamID ${request.steamId}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _canWrite(1)
                        ? () => _write(
                            1,
                            () => ref
                                .read(friendsClientProvider)
                                .respondToRequest(
                                  widget.account,
                                  request.steamId,
                                  accept: true,
                                ),
                          )
                        : null,
                    child: Text(l.notificationsAcceptRequest),
                  ),
                  OutlinedButton(
                    onPressed: _canWrite(1)
                        ? () => _write(
                            1,
                            () => ref
                                .read(friendsClientProvider)
                                .respondToRequest(
                                  widget.account,
                                  request.steamId,
                                  accept: false,
                                ),
                          )
                        : null,
                    child: Text(l.notificationsRejectRequest),
                  ),
                  if (isIndividualSteamId(request.steamId))
                    TextButton(
                      onPressed: () => _openSteam(
                        Uri.https(
                          'steamcommunity.com',
                          '/profiles/${request.steamId}/',
                        ),
                      ),
                      child: Text(l.friendsProfile),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Mounted only for visible inventory rows. A disposed/hidden row cancels its
/// read; the parent serializes and caches requests for this account session.
class _InventoryNotificationDetails extends StatefulWidget {
  const _InventoryNotificationDetails({
    super.key,
    required this.load,
    required this.builder,
  });
  final Future<SteamNotificationItem?> Function(
    SteamRequestScope,
    bool Function(),
  )
  load;
  final Widget Function(SteamNotificationItem?, bool) builder;

  @override
  State<_InventoryNotificationDetails> createState() =>
      _InventoryNotificationDetailsState();
}

class _InventoryNotificationDetailsState
    extends State<_InventoryNotificationDetails> {
  final _scope = SteamRequestScope(timeout: const Duration(seconds: 8));
  SteamNotificationItem? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    SteamNotificationItem? detail;
    try {
      detail = await widget.load(_scope, () => mounted);
    } catch (_) {
      // Keep the specific game/event and inventory action if details expired.
    }
    if (mounted) {
      setState(() {
        _detail = detail;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _scope.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_detail, _loading);
}
