import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/core/protocol/community_session.dart';
import 'package:ava/src/core/protocol/steam_notifications_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends SteamApiClient {
  final calls =
      <
        ({
          String service,
          String method,
          bool get,
          String? token,
          List<ProtoField> fields,
        })
      >[];
  ProtoWriter response = ProtoWriter();
  Object? error;

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    calls.add((
      service: iface,
      method: method,
      get: useGet,
      token: accessToken,
      fields: ProtoReader(request.toBytes()).parseAll(),
    ));
    if (error != null) throw error!;
    return ProtoReader(response.toBytes());
  }
}

SteamGuardAccount _account({String? token = 'fixture-access'}) =>
    SteamGuardAccount(
      session: SessionData(steamId: 76561198000000001, accessToken: token),
    );

ProtoWriter _notification({
  int id = 123,
  String body = '{"title":"Sale"}',
  bool read = false,
  bool hidden = false,
}) => ProtoWriter()
  ..writeUint64(1, id)
  ..writeVarint(3, 6)
  ..writeString(4, body)
  ..writeBool(7, read)
  ..writeVarint(8, 1700000000)
  ..writeBool(9, hidden)
  ..writeVarint(10, 1800000000);

void main() {
  test(
    'count-only uses explicit flags, preserves missing counts as unknown',
    () async {
      final api = _Api()
        ..response = (ProtoWriter()
          ..writeVarint(2, 4)
          ..writeVarint(5, 0)
          // count-only must not decode notification bodies, even malformed ones.
          ..writeBytes(1, [0xff]));
      final counts = await SteamNotificationsClient(
        api,
      ).fetchCounts(_account());
      expect(counts.confirmationCount, 4);
      expect(counts.pendingFriendCount, 0);
      expect(counts.unreadCount, isNull);
      final call = api.calls.single;
      expect(call.service, 'ISteamNotificationService');
      expect(call.method, 'GetSteamNotifications');
      expect(call.get, isTrue);
      expect(call.token, 'fixture-access');
      expect(
        {for (final field in call.fields) field.number: field.asInt},
        {1: 0, 3: 1, 4: 1, 5: 1, 6: 1},
      );
    },
  );

  test('negative/mistyped counts are unknown, not fabricated zeros', () async {
    final api = _Api()
      ..response = (ProtoWriter()
        ..writeVarint(2, -1)
        ..writeString(5, '3'));
    final counts = await SteamNotificationsClient(api).fetchCounts(_account());
    expect(counts.confirmationCount, isNull);
    expect(counts.pendingFriendCount, isNull);
    expect(counts.unreadCount, isNull);
  });

  test(
    'inbox parses repeated notifications and full unsigned 64-bit identity',
    () async {
      final api = _Api()
        ..response = (ProtoWriter()
          ..writeMessage(1, _notification(id: -1, read: true))
          ..writeMessage(1, _notification(id: 124, hidden: true))
          ..writeVarint(6, 1));
      final inbox = await SteamNotificationsClient(api).fetch(_account());
      expect(inbox.notifications, hasLength(2));
      final notification = inbox.notifications.first;
      expect(notification.id, '18446744073709551615');
      expect(notification.type, 6);
      expect(notification.body, {'title': 'Sale'});
      expect(notification.read, isTrue);
      expect(notification.timestamp, 1700000000);
      expect(notification.expiry, 1800000000);
      expect(inbox.notifications.last.hidden, isTrue);
      expect(inbox.counts.unreadCount, 1);
      expect(
        api.calls.single.fields.singleWhere((f) => f.number == 6).asBool,
        isFalse,
      );
    },
  );

  test(
    'malformed/array body remains generic without exposing raw content',
    () async {
      for (final body in ['not-json secret-content', '["secret-content"]']) {
        final api = _Api()
          ..response = (ProtoWriter()
            ..writeMessage(1, _notification(body: body)));
        final inbox = await SteamNotificationsClient(api).fetch(_account());
        expect(inbox.notifications.single.body, isEmpty);
      }
    },
  );

  test('notification without an identity is rejected', () async {
    final api = _Api()
      ..response = (ProtoWriter()..writeMessage(1, _notification(id: 0)));
    await expectLater(
      SteamNotificationsClient(api).fetch(_account()),
      throwsFormatException,
    );
  });

  test(
    'mark-read writes exact deduplicated IDs, never broad mark-all flag',
    () async {
      final api = _Api();
      await SteamNotificationsClient(
        api,
      ).markRead(_account(), ['123', '18446744073709551615', '123']);
      final call = api.calls.single;
      expect(call.method, 'MarkNotificationsRead');
      expect(call.get, isFalse);
      expect(call.fields.map((f) => f.number), [3, 3]);
      expect(call.fields.map((f) => f.asInt), [123, -1]);
    },
  );

  test('hide uses its own repeated field and no all action', () async {
    final api = _Api();
    await SteamNotificationsClient(api).hide(_account(), ['123', '124']);
    expect(api.calls.single.method, 'HideNotification');
    expect(api.calls.single.fields.map((f) => f.number), [1, 1]);
    expect(api.calls.single.fields.map((f) => f.asInt), [123, 124]);
  });

  test(
    'empty writes are no-ops and all IDs validate before sending any write',
    () async {
      final api = _Api();
      final client = SteamNotificationsClient(api);
      await client.markRead(_account(token: null), []);
      await client.hide(_account(token: null), []);
      for (final bad in ['0', '-1', '1.0', ' 123', '18446744073709551616']) {
        await expectLater(
          client.markRead(_account(), ['123', bad]),
          throwsFormatException,
        );
      }
      expect(api.calls, isEmpty);
    },
  );

  test('missing token prevents reads and writes before HTTP', () async {
    final api = _Api();
    final client = SteamNotificationsClient(api);
    await expectLater(
      client.fetch(_account(token: null)),
      throwsA(isA<MissingAccessTokenException>()),
    );
    await expectLater(
      client.hide(_account(token: null), ['123']),
      throwsA(isA<MissingAccessTokenException>()),
    );
    expect(api.calls, isEmpty);
  });

  test(
    'failed write does not refresh, replay or mask the transport error',
    () async {
      final api = _Api()..error = const FormatException('synthetic failure');
      await expectLater(
        SteamNotificationsClient(api).markRead(_account(), ['123']),
        throwsFormatException,
      );
      expect(api.calls, hasLength(1));
    },
  );

  test(
    'invalid UTF-8 body keeps identity and permits generic display',
    () async {
      final api = _Api()
        ..response = (ProtoWriter()
          ..writeMessage(
            1,
            ProtoWriter()
              ..writeUint64(1, 123)
              ..writeBytes(4, [0xff]),
          ));
      final inbox = await SteamNotificationsClient(api).fetch(_account());
      expect(inbox.notifications.single.id, '123');
      expect(inbox.notifications.single.body, isEmpty);
    },
  );
}
