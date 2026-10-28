import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/steam_notifications_provider.dart';
import '../../core/models/steam_guard_account.dart';

/// Uses the shared home counts; opening this button is what loads the inbox.
class SteamNotificationsButton extends ConsumerWidget {
  final SteamGuardAccount account;
  final VoidCallback onPressed;
  final bool compact;

  const SteamNotificationsButton({
    super.key,
    required this.account,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final snapshot = ref.watch(
      steamNotificationCountsProvider.select((counts) => counts[account.steamId]),
    );
    final counts = snapshot != null && snapshot.matches(account) ? snapshot : null;
    final unread = counts?.unreadCount;
    final requests = counts?.pendingFriendCount;
    final icon = Badge(
      isLabelVisible: (unread ?? 0) > 0,
      child: const Icon(Icons.notifications_outlined, size: 20),
    );
    final tooltip = '${l.notificationsTitle}\n'
        '${l.notificationsUnread}: ${unread ?? '…'} · '
        '${l.notificationsRequestsTab}: ${requests ?? '…'}';
    if (compact) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
      );
    }
    return Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(l.notificationsTitle),
      ),
    );
  }
}
