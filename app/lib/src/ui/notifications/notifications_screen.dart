import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/responsive.dart';
import '../../app/steam_notifications_provider.dart';
import '../../app/theme.dart';
import '../../core/models/steam_friend.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/models/steam_notification.dart';
import '../../services/session_manager.dart';
import '../friends/friends_screen.dart' show friendsClientProvider;
import '../pending/session_retry.dart';
import '../widgets/ava_panel.dart';

final notificationsLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class NotificationsScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;

  const NotificationsScreen({super.key, required this.account});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin, SessionRetryState {
  late final TabController _tabs;
  SteamNotificationInbox? _inbox;
  List<SteamFriendRequest>? _requests;
  final _loading = [false, false];
  final List<String?> _errors = [null, null];
  final _needsLogin = [false, false];
  final _writeNeedsRefresh = [false, false];
  final List<(int, String?, String?)?> _listSessions = [null, null];
  bool _busy = false;

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
    _load(0);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _ensureTabLoaded() {
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
        // A visible inbox reload supplies its own counters; after leaving,
        // or after a friend action, only the lightweight counters are read.
        if (!mounted || index == 1) {
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
            Tab(text: l.notificationsInboxTab),
            Tab(text: l.notificationsRequestsTab),
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
    final items =
        _inbox?.notifications.where((item) => !item.hidden).toList() ??
        const <SteamNotification>[];
    if (items.isEmpty) return Center(child: Text(l.notificationsEmpty));
    final unread = items
        .where((item) => !item.read)
        .map((item) => item.id)
        .toList();
    return ListView.separated(
      padding: context.rSafeInsets(all: 16),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _canWrite(0) && unread.isNotEmpty
                  ? () => _updateNotifications(unread)
                  : null,
              icon: const Icon(Icons.done_all),
              label: Text(l.notificationsMarkAllRead),
            ),
          );
        }
        return _notificationCard(items[index - 1], l);
      },
    );
  }

  Widget _notificationCard(SteamNotification item, AppLocalizations l) {
    String? text(String key) {
      final value = item.body[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

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

    final t = Theme.of(context).extension<AvaTokens>()!;
    return AvaPanel(
      key: ValueKey('notification-${item.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text('title') ?? category,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!item.read)
            Text(l.notificationsUnread, style: TextStyle(color: t.accent)),
          const SizedBox(height: 8),
          Text(
            text('body') ??
                text('message') ??
                (item.type == 3 ? text('text') : null) ??
                l.notificationsItemFallback,
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
              if (isIndividualSteamId('${widget.account.steamId}'))
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
