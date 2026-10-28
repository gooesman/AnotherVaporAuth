import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/responsive.dart';
import '../../app/route_observer.dart';
import '../../app/steam_notifications_provider.dart';
import '../../app/theme.dart';
import '../../core/models/steam_guard_account.dart';

/// Display only: rebuilding or scrolling an account row never starts a fetch.
class PendingConfirmationBadge extends ConsumerWidget {
  const PendingConfirmationBadge({
    super.key,
    required this.account,
    this.showIcon = true,
  });

  final SteamGuardAccount account;
  final bool showIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(steamNotificationCountsEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final cached = ref.watch(
      steamNotificationCountsProvider.select(
        (counts) => counts[account.steamId],
      ),
    );
    final snapshot = cached?.matches(account) == true ? cached : null;
    final count = snapshot?.confirmationCount;
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final stale = snapshot?.confirmationStale ?? false;
    final label = count == null
        ? l.confirmationBadgeUnknown
        : stale
        ? l.confirmationBadgeStale(count)
        : l.confirmationBadgeCount(count);
    final color = count != null && count > 0 && !stale ? t.accent : t.muted;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: Container(
          padding: context.rInsets(left: 6, right: 6, top: 2, bottom: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(t.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(
                  Icons.fact_check_outlined,
                  size: context.r(13),
                  color: color,
                ),
                SizedBox(width: context.r(4)),
              ],
              Text(
                count?.toString() ?? (snapshot?.loading == true ? '…' : '—'),
                style: TextStyle(color: color, fontSize: context.r(11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One coordinator around the home screen, not one timer per account row.
/// Hidden/background/locked screens do not poll. The shared cache also limits
/// repeated foreground events, so returning to the app cannot flood Steam.
class NotificationCountsRefresh extends ConsumerStatefulWidget {
  const NotificationCountsRefresh({
    super.key,
    required this.accounts,
    required this.child,
  });

  final List<SteamGuardAccount> accounts;
  final Widget child;

  @override
  ConsumerState<NotificationCountsRefresh> createState() =>
      _NotificationCountsRefreshState();
}

class _NotificationCountsRefreshState
    extends ConsumerState<NotificationCountsRefresh>
    with WidgetsBindingObserver, RouteAware {
  Timer? _timer;
  PageRoute<void>? _route;
  bool _covered = false;
  bool _foreground = true;
  List<Object?> _sessions = const [];
  late final SteamNotificationCountsController _counts;

  List<Object?> get _currentSessions => [
    for (final account in widget.accounts)
      (
        account.steamId,
        account.session.accessToken,
        account.session.refreshToken,
      ),
  ];

  @override
  void initState() {
    super.initState();
    _counts = ref.read(steamNotificationCountsProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _sessions = _currentSessions;
    _schedule();
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
  void didUpdateWidget(covariant NotificationCountsRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessions = _currentSessions;
    if (!listEquals(_sessions, sessions)) {
      _sessions = sessions;
      _schedule();
    }
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resume();
    });
  }

  bool get _active =>
      mounted &&
      _foreground &&
      !_covered &&
      ref.read(steamNotificationCountsEnabledProvider);

  void _resume() {
    _timer?.cancel();
    _timer = null;
    if (!_active) {
      _counts.cancelRefreshes();
      return;
    }
    _refresh();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _refresh());
  }

  void _refresh() {
    if (!_active) return;
    unawaited(_counts.refreshAll(widget.accounts));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _resume();
  }

  @override
  void didPushNext() {
    _covered = true;
    _resume();
  }

  @override
  void didPopNext() {
    _covered = false;
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _counts.cancelRefreshes();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(steamNotificationCountsEnabledProvider, (_, enabled) {
      if (enabled) {
        _schedule();
      } else {
        _timer?.cancel();
        _timer = null;
        _counts.cancelRefreshes();
      }
    });
    return widget.child;
  }
}
