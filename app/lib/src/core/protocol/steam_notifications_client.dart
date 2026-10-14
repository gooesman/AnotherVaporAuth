import 'dart:convert';

import '../../services/steam_api_client.dart';
import '../models/steam_guard_account.dart';
import '../models/steam_notification.dart';
import '../proto/protobuf_wire.dart';
import 'community_session.dart';

/// Wire fields and const/write semantics are from Steam's web UI protocol:
/// https://github.com/SteamTracking/Protobufs/blob/master/webui/service_steamnotification.proto
/// Reads use the existing access token; this does not create an API key or a
/// persistent connection. Writes are sent once, without token refresh/replay.
class SteamNotificationsClient {
  final SteamApiClient api;
  SteamNotificationsClient(this.api);

  Future<SteamNotificationCounts> fetchCounts(
    SteamGuardAccount account,
  ) async => (await _fetch(account, countOnly: true)).counts;

  Future<SteamNotificationInbox> fetch(SteamGuardAccount account) =>
      _fetch(account, countOnly: false);

  Future<SteamNotificationInbox> _fetch(
    SteamGuardAccount account, {
    required bool countOnly,
  }) async {
    final reader = await api.callProtobuf(
      'ISteamNotificationService',
      'GetSteamNotifications',
      request: ProtoWriter()
        ..writeBool(1, false) // include_hidden
        ..writeBool(3, true) // include_confirmation_count
        ..writeBool(4, true) // include_pinned_counts
        ..writeBool(5, true) // include_read
        ..writeBool(6, countOnly),
      accessToken: requireAccessToken(account),
      useGet: true,
    );
    final notifications = <SteamNotification>[];
    int? confirmations;
    int? friends;
    int? unread;
    for (final field in reader.parseAll()) {
      switch (field.number) {
        case 1:
          if (!countOnly && field.bytes != null) {
            notifications.add(_notification(ProtoReader(field.bytes!)));
          }
        case 2:
          confirmations = _count(field);
        case 5:
          friends = _count(field);
        case 6:
          unread = _count(field);
      }
    }
    return SteamNotificationInbox(
      notifications: List.unmodifiable(notifications),
      counts: SteamNotificationCounts(
        confirmationCount: confirmations,
        pendingFriendCount: friends,
        unreadCount: unread,
      ),
    );
  }

  /// Marks only the reviewed IDs. An empty set is a no-op, never "mark all".
  /// The protocol's mark_all_read flag is deliberately not used: a new
  /// notification arriving during confirmation must remain unread.
  Future<void> markRead(SteamGuardAccount account, Iterable<String> ids) =>
      _write(account, ids, method: 'MarkNotificationsRead', field: 3);

  Future<void> hide(SteamGuardAccount account, Iterable<String> ids) =>
      _write(account, ids, method: 'HideNotification', field: 1);

  Future<void> _write(
    SteamGuardAccount account,
    Iterable<String> ids, {
    required String method,
    required int field,
  }) async {
    final values = ids.toSet().map(_idValue).toList(growable: false);
    if (values.isEmpty) return;
    final request = ProtoWriter();
    for (final id in values) {
      request.writeUint64(field, id.toSigned(64).toInt());
    }
    await api.callProtobuf(
      'ISteamNotificationService',
      method,
      request: request,
      accessToken: requireAccessToken(account),
    );
  }

  static int? _count(ProtoField field) =>
      field.wireType == 0 && field.asInt >= 0 ? field.asInt : null;

  static BigInt _idValue(String id) {
    final parsed = RegExp(r'^[1-9]\d*$').hasMatch(id)
        ? BigInt.tryParse(id)
        : null;
    if (parsed == null || parsed > (BigInt.one << 64) - BigInt.one) {
      throw const FormatException('Invalid Steam notification ID');
    }
    return parsed;
  }

  static SteamNotification _notification(ProtoReader reader) {
    final fields = reader.parse();
    final idField = fields[1];
    if (idField == null || idField.wireType != 0 || idField.asInt == 0) {
      throw const FormatException('Steam notification has no valid ID');
    }
    final id = BigInt.from(idField.asInt).toUnsigned(64).toString();
    Map<String, dynamic> body = const {};
    // An unknown/malformed body still has a valid notification identity and
    // may be read or dismissed. Never turn it into a fabricated text/link.
    try {
      final raw = fields[4]?.asString;
      if (raw != null && raw.isNotEmpty) {
        final value = jsonDecode(raw);
        if (value is Map<String, dynamic>) body = Map.unmodifiable(value);
      }
    } on FormatException {
      // The UI can show a generic label for this notification type.
    }
    return SteamNotification(
      id: id,
      type: fields[3]?.asInt ?? 0,
      body: body,
      read: fields[7]?.asBool ?? false,
      timestamp: fields[8]?.asInt ?? 0,
      hidden: fields[9]?.asBool ?? false,
      expiry: fields[10]?.asInt,
    );
  }
}
