import 'dart:convert';

import '../../services/steam_api_client.dart';
import '../models/steam_friend.dart' show isIndividualSteamId;
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

  /// Mirrors Steam's notification UI's single-asset metadata read. This never
  /// loads an inventory page, follows pagination, or uses a URL from the body.
  /// Official Econ wire schema (module 38636) and notification renderer:
  /// https://community.fastly.steamstatic.com/public/javascript/applications/community/chunk~850c81d98.js
  /// https://community.fastly.steamstatic.com/public/javascript/applications/community/chunk~8f4f68fd6.js
  /// No result/mismatched metadata returns null. Transport/auth/cancellation
  /// failures propagate for the UI's fallback; none are retried here.
  Future<SteamNotificationItem?> fetchInventoryNotificationItem(
    SteamGuardAccount account,
    SteamNotification item,
  ) async {
    final appId = item.inventoryAppId;
    final contextId = item.contextId;
    final assetId = item.assetId;
    if (appId == null || contextId == null || assetId == null) return null;
    if (!isIndividualSteamId('${account.steamId}')) {
      throw ArgumentError('Invalid SteamID');
    }
    final reader = await api.callProtobuf(
      'IEconService',
      'GetInventoryItemsWithDescriptions',
      request: ProtoWriter()
        ..writeFixed64(1, account.steamId)
        ..writeVarint(2, appId)
        ..writeUint64(3, _idValue(contextId).toSigned(64).toInt())
        ..writeBool(4, true)
        ..writeString(5, api.steamLanguage)
        ..writeMessage(
          6,
          ProtoWriter()..writeUint64(1, _idValue(assetId).toSigned(64).toInt()),
        ),
      accessToken: requireAccessToken(account),
      useGet: true,
    );
    final fields = reader.parseAll();
    List<Map<int, ProtoField>> messages(int number) => [
      for (final field in fields)
        if (field.number == number && field.wireType == 2)
          ProtoReader(field.bytes!).parse(),
    ];
    bool matchesAsset(Map<int, ProtoField> asset) =>
        _uint(asset[1]) == '$appId' &&
        _uint(asset[2]) == contextId &&
        _uint(asset[3]) == assetId;
    if (messages(3).any(matchesAsset)) return null; // missing_assets
    final assets = messages(1).where(matchesAsset).toList();
    if (assets.length != 1 ||
        (assets.single[8] != null && _uint(assets.single[8]) != '0')) {
      return null;
    }
    final classId = _uint(assets.single[4]);
    final instanceId = _uint(assets.single[5], defaultZero: true);
    if (classId == null || classId == '0' || instanceId == null) return null;
    final descriptions = messages(2)
        .where(
          (description) =>
              _uint(description[1]) == '$appId' &&
              _uint(description[2]) == classId &&
              _uint(description[3], defaultZero: true) == instanceId,
        )
        .toList();
    if (descriptions.length != 1) return null;
    final description = descriptions.single;
    final name = _descriptionText(description[14]);
    if (name.isEmpty) return null;
    final icon = _descriptionText(description[6]);
    return SteamNotificationItem(
      appId: appId,
      contextId: contextId,
      assetId: assetId,
      name: name,
      iconUrl: icon.length <= 4096 && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(icon)
          ? 'https://community.fastly.steamstatic.com/economy/image/$icon/128fx128f'
          : '',
    );
  }

  static String? _uint(ProtoField? field, {bool defaultZero = false}) {
    if (field == null) return defaultZero ? '0' : null;
    return field.wireType == 0
        ? BigInt.from(field.asInt).toUnsigned(64).toString()
        : null;
  }

  static String _descriptionText(ProtoField? field) {
    if (field?.wireType != 2) return '';
    try {
      return field!.asString.trim();
    } on FormatException {
      return '';
    }
  }

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
