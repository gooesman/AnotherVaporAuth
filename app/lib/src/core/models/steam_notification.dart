/// Counts omitted by Steam are unknown, not a confirmed zero.
class SteamNotificationCounts {
  final int? confirmationCount;
  final int? pendingFriendCount;
  final int? unreadCount;

  const SteamNotificationCounts({
    this.confirmationCount,
    this.pendingFriendCount,
    this.unreadCount,
  });
}

/// Steam's notification body is type-specific JSON. Keep it as data; callers
/// must not execute its HTML or automatically open links from it.
class SteamNotification {
  final String id;
  final int type;
  final Map<String, dynamic> body;
  final bool read;
  final bool hidden;
  final int timestamp;
  final int? expiry;

  const SteamNotification({
    required this.id,
    required this.type,
    this.body = const {},
    this.read = false,
    this.hidden = false,
    this.timestamp = 0,
    this.expiry,
  });
}

class SteamNotificationInbox {
  final List<SteamNotification> notifications;
  final SteamNotificationCounts counts;

  const SteamNotificationInbox({
    required this.notifications,
    required this.counts,
  });
}
