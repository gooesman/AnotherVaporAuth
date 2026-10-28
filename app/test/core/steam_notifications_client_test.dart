import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_notification.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/core/protocol/community_session.dart';
import 'package:ava/src/core/protocol/steam_notifications_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:dio/dio.dart';
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

const _inventoryNotification = SteamNotification(
  id: '123',
  type: 4,
  body: {'app_id': 730, 'context_id': '2', 'asset_id': '900'},
);

ProtoWriter _asset({
  int appId = 730,
  int contextId = 2,
  int assetId = 900,
  int classId = 300,
  int instanceId = 0,
  bool missing = false,
}) => ProtoWriter()
  ..writeVarint(1, appId)
  ..writeUint64(2, contextId)
  ..writeUint64(3, assetId)
  ..writeUint64(4, classId)
  ..writeUint64(5, instanceId)
  ..writeBool(8, missing);

ProtoWriter _description({
  int appId = 730,
  int classId = 300,
  int instanceId = 0,
  String name = 'Fixture music kit',
  String icon = 'fixture_icon-key',
}) => ProtoWriter()
  ..writeVarint(1, appId)
  ..writeUint64(2, classId)
  ..writeUint64(3, instanceId)
  ..writeString(6, icon)
  ..writeString(14, name);

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

  test(
    'inventory metadata requests exactly one asset via authenticated GET',
    () async {
      final api = _Api()
        ..steamLanguage = 'schinese'
        ..response = (ProtoWriter()
          ..writeMessage(1, _asset())
          ..writeMessage(2, _description())
          // More items must never trigger an inventory scan or pagination.
          ..writeBool(4, true)
          ..writeUint64(5, 900));
      final item = await SteamNotificationsClient(
        api,
      ).fetchInventoryNotificationItem(_account(), _inventoryNotification);
      expect(item!.name, 'Fixture music kit');
      expect(item.appId, 730);
      expect(item.contextId, '2');
      expect(item.assetId, '900');
      expect(item.gameName, isEmpty);
      expect(
        item.iconUrl,
        'https://community.fastly.steamstatic.com/economy/image/fixture_icon-key/128fx128f',
      );
      final call = api.calls.single;
      expect(call.service, 'IEconService');
      expect(call.method, 'GetInventoryItemsWithDescriptions');
      expect(call.get, isTrue);
      expect(call.token, 'fixture-access');
      final fields = {for (final field in call.fields) field.number: field};
      expect(fields.keys, [1, 2, 3, 4, 5, 6]);
      expect(fields[1]!.wireType, 1);
      expect(fields[1]!.asFixed64, 76561198000000001);
      expect(fields[2]!.asInt, 730);
      expect(fields[3]!.asInt, 2);
      expect(fields[4]!.asBool, isTrue);
      expect(fields[5]!.asString, 'schinese');
      final filter = ProtoReader(fields[6]!.bytes!).parseAll();
      expect(filter, hasLength(1));
      expect(filter.single.number, 1);
      expect(filter.single.asInt, 900);
    },
  );

  test(
    'inventory lookup preserves unsigned 64-bit context and asset IDs',
    () async {
      final api = _Api()
        ..response = (ProtoWriter()
          ..writeMessage(1, _asset(contextId: -1, assetId: -1, classId: -1))
          ..writeMessage(2, _description(classId: -1)));
      final item = await SteamNotificationsClient(api)
          .fetchInventoryNotificationItem(
            _account(),
            const SteamNotification(
              id: '123',
              type: 4,
              body: {
                'app_id': '730',
                'context_id': '18446744073709551615',
                'asset_id': '18446744073709551615',
              },
            ),
          );
      expect(item!.assetId, '18446744073709551615');
      expect(item.contextId, '18446744073709551615');
      final fields = {
        for (final field in api.calls.single.fields) field.number: field,
      };
      expect(fields[3]!.asInt, -1);
      expect(ProtoReader(fields[6]!.bytes!).parseAll().single.asInt, -1);
    },
  );

  test('missing or invalid inventory identifiers cause no request', () async {
    final api = _Api();
    final client = SteamNotificationsClient(api);
    final invalid = <SteamNotification>[
      const SteamNotification(
        id: '123',
        type: 3,
        body: {'app_id': 730, 'context_id': '2', 'asset_id': '900'},
      ),
      const SteamNotification(id: '123', type: 4),
      for (final field in ['app_id', 'context_id', 'asset_id'])
        for (final value in [
          0,
          -1,
          1.5,
          true,
          ' 2',
          '1x',
          '18446744073709551616',
        ])
          SteamNotification(
            id: '123',
            type: 4,
            body: {..._inventoryNotification.body, field: value},
          ),
      const SteamNotification(
        id: '123',
        type: 4,
        body: {'app_id': '4294967296', 'context_id': '2', 'asset_id': '900'},
      ),
    ];
    for (final notification in invalid) {
      expect(
        await client.fetchInventoryNotificationItem(_account(), notification),
        isNull,
      );
    }
    expect(api.calls, isEmpty);
    await expectLater(
      client.fetchInventoryNotificationItem(
        _account(token: null),
        _inventoryNotification,
      ),
      throwsA(isA<MissingAccessTokenException>()),
    );
    await expectLater(
      client.fetchInventoryNotificationItem(
        SteamGuardAccount(),
        _inventoryNotification,
      ),
      throwsArgumentError,
    );
    expect(api.calls, isEmpty);
  });

  test(
    'missing, mismatched and ambiguous item metadata safely returns null',
    () async {
      final responses = [
        ProtoWriter(),
        ProtoWriter()..writeMessage(2, _description()),
        ProtoWriter()
          ..writeMessage(1, _asset())
          ..writeMessage(2, _description(appId: 570)),
        ProtoWriter()
          ..writeMessage(1, _asset(assetId: 901))
          ..writeMessage(2, _description()),
        ProtoWriter()
          ..writeMessage(1, _asset())
          ..writeMessage(2, _description(classId: 301)),
        ProtoWriter()
          ..writeMessage(1, _asset())
          ..writeMessage(2, _description(instanceId: 1)),
        ProtoWriter()
          ..writeMessage(1, _asset(missing: true))
          ..writeMessage(2, _description()),
        ProtoWriter()
          ..writeMessage(1, _asset())
          ..writeMessage(2, _description())
          ..writeMessage(3, _asset()),
        ProtoWriter()
          ..writeMessage(1, _asset())
          ..writeMessage(1, _asset())
          ..writeMessage(2, _description()),
        ProtoWriter()
          ..writeMessage(1, _asset())
          ..writeMessage(2, _description())
          ..writeMessage(2, _description()),
        ProtoWriter()
          ..writeMessage(1, _asset())
          ..writeMessage(2, _description(name: '  ')),
      ];
      for (final response in responses) {
        final api = _Api()..response = response;
        expect(
          await SteamNotificationsClient(
            api,
          ).fetchInventoryNotificationItem(_account(), _inventoryNotification),
          isNull,
        );
        expect(api.calls, hasLength(1));
      }
    },
  );

  test(
    'asset identity picks matching description rather than the first one',
    () async {
      final api = _Api()
        ..response = (ProtoWriter()
          ..writeMessage(1, _asset())
          ..writeMessage(2, _description(classId: 301, name: 'Other item'))
          ..writeMessage(2, _description()));
      final item = await SteamNotificationsClient(
        api,
      ).fetchInventoryNotificationItem(_account(), _inventoryNotification);
      expect(item!.name, 'Fixture music kit');
    },
  );

  test('notification icons cannot select arbitrary URL or path', () async {
    for (final icon in [
      'https://evil.example/image',
      '//evil.example',
      '../escape',
      'key?q=secret',
      'key/other',
      'x' * 4097,
    ]) {
      final api = _Api()
        ..response = (ProtoWriter()
          ..writeMessage(1, _asset())
          ..writeMessage(2, _description(icon: icon)));
      final item = await SteamNotificationsClient(
        api,
      ).fetchInventoryNotificationItem(_account(), _inventoryNotification);
      expect(item!.iconUrl, isEmpty);
      expect(item.name, 'Fixture music kit');
    }
  });

  test(
    'inventory auth, transport and cancellation errors propagate without retry',
    () async {
      final errors = [
        SteamApiException(
          15,
          'fixture access denied',
          'GetInventoryItemsWithDescriptions',
        ),
        const FormatException('fixture malformed response'),
        DioException.requestCancelled(
          requestOptions: RequestOptions(path: 'fixture'),
          reason: 'fixture canceled',
        ),
      ];
      for (final error in errors) {
        final api = _Api()..error = error;
        await expectLater(
          SteamNotificationsClient(
            api,
          ).fetchInventoryNotificationItem(_account(), _inventoryNotification),
          throwsA(same(error)),
        );
        expect(api.calls, hasLength(1));
      }
    },
  );
}
