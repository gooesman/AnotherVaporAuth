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

  // Steam's notification renderer uses type-specific keys. Unknown bodies
  // stay generic instead of exposing arbitrary JSON fields as visible text.
  String? get displayTitle => switch (type) {
    3 || 6 => _text(body['title']),
    10 => _text(body['title']) ?? _text(body['display_name']),
    _ => null,
  };

  String? get displayBody => switch (type) {
    3 => _text(body['text']),
    6 || 10 => _text(body['body']),
    _ => null,
  };

  /// These four notification fields contain account IDs, not SteamID64s.
  /// A historical friend notification does not prove a current pending invite.
  String? get partnerSteamId {
    final raw = switch (type) {
      2 => body['gifter_account'],
      3 => body['account_id'],
      5 => body['requestor_id'],
      9 => body['sender'],
      _ => null,
    };
    final id = _positiveId(raw, bits: 32);
    return id == null ? null : '${76561197960265728 + int.parse(id)}';
  }

  int? get inventoryAppId {
    final id = type == 4 ? _positiveId(body['app_id'], bits: 32) : null;
    return id == null ? null : int.parse(id);
  }

  String? get contextId => type == 4 ? _positiveId(body['context_id']) : null;
  String? get assetId => type == 4 ? _positiveId(body['asset_id']) : null;

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static String? _positiveId(Object? value, {int bits = 64}) {
    final text = value is int || value is String ? '$value' : '';
    if (!RegExp(r'^[1-9]\d{0,19}$').hasMatch(text)) return null;
    final id = BigInt.parse(text);
    return id < (BigInt.one << bits) ? text : null;
  }
}

/// Optional metadata for exactly the asset named by an inventory notification.
/// This endpoint has no game name; callers may use their local app-name map.
class SteamNotificationItem {
  final int appId;
  final String contextId;
  final String assetId;
  final String name;
  final String iconUrl;
  final String gameName;

  const SteamNotificationItem({
    required this.appId,
    required this.contextId,
    required this.assetId,
    required this.name,
    this.iconUrl = '',
    this.gameName = '',
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
