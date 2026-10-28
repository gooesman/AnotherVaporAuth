import 'dart:async';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/core/protocol/community_session.dart';
import 'package:ava/src/core/protocol/friends_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

const _owner = '76561198000000001';
const _incoming = '76561198000000002';
const _second = '76561198000000003';
const _outgoing = '76561198000000004';
SteamGuardAccount _account() => SteamGuardAccount(
  session: SessionData(
    steamId: int.parse(_owner),
    accessToken: 'fixture-access',
    refreshToken: 'fixture-refresh',
  ),
);
Map<String, dynamic> _relationships(Map<String, int> items) => {
  'success': 1,
  'friendslist': {
    'friends': [
      for (final entry in items.entries)
        {'ulfriendid': entry.key, 'efriendrelationship': entry.value},
    ],
  },
};
ProtoWriter _profile(String id, {String name = 'Alice'}) => ProtoWriter()
  ..writeMessage(
    1,
    ProtoWriter()
      ..writeFixed64(1, int.parse(id))
      ..writeBytes(9, List.filled(20, 0xab))
      ..writeString(10, name),
  )
  ..writeMessage(
    2,
    ProtoWriter()..writeString(9, 'must-not-display-login-name'),
  );

class _Api extends SteamApiClient {
  final reads = <String>[];
  final readCookies = <Map<String, String>?>[];
  final writes =
      <
        ({String path, Map<String, dynamic> form, Map<String, String>? cookies})
      >[];
  final profileIds = <List<String>>[];
  List<Map<String, dynamic>> responses = [];
  Map<String, dynamic> writeResponse = {};
  ProtoWriter profiles = ProtoWriter();
  Object? profileError;
  Object? writeError;
  Future<void> Function(int)? beforeRead;
  void Function()? onWrite;

  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async {
    reads.add(path);
    readCookies.add(cookies);
    await beforeRead?.call(reads.length);
    return responses.removeAt(0);
  }

  @override
  Future<Map<String, dynamic>> communityPostJson(
    String path,
    Map<String, dynamic> form, {
    Map<String, String>? cookies,
    String? referer,
  }) async {
    writes.add((path: path, form: form, cookies: cookies));
    onWrite?.call();
    if (writeError != null) throw writeError!;
    return writeResponse;
  }

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) async {
    expect(iface, 'IPlayerService');
    expect(method, 'GetPlayerLinkDetails');
    expect(useGet, isTrue);
    expect(accessToken, 'fixture-access');
    profileIds.add(
      ProtoReader(
        request.toBytes(),
      ).parseAll().map((f) => f.asInt.toString()).toList(),
    );
    if (profileError != null) throw profileError!;
    return ProtoReader(profiles.toBytes());
  }
}

void main() {
  test(
    'lists incoming only, resolves all names in one request by exact ID',
    () async {
      final api = _Api()
        ..responses = [
          _relationships({_incoming: 2, _second: 2, _outgoing: 4}),
        ]
        ..profiles = (ProtoWriter()
          ..writeMessage(1, _profile(_second, name: 'Bob'))
          ..writeMessage(1, _profile(_incoming))
          ..writeMessage(1, _profile(_outgoing, name: 'not-incoming')));
      final requests = await FriendsClient(api).fetchRequests(_account());
      expect(requests.map((r) => r.steamId), [_incoming, _second]);
      expect(requests.map((r) => r.name), ['Alice', 'Bob']);
      expect(
        requests.first.avatarUrl,
        'https://avatars.steamstatic.com/${'ab' * 20}_medium.jpg',
      );
      expect(api.profileIds, [
        [_incoming, _second],
      ]);
      expect(
        api.readCookies.single!['steamLoginSecure'],
        '$_owner||fixture-access',
      );
    },
  );

  test('zero incoming makes no metadata requests', () async {
    final api = _Api()
      ..responses = [
        _relationships({_outgoing: 4}),
      ];
    expect(await FriendsClient(api).fetchRequests(_account()), isEmpty);
    expect(api.profileIds, isEmpty);
  });

  test(
    'metadata failure keeps explicit ID fallback without per-user retries',
    () async {
      final api = _Api()
        ..responses = [
          _relationships({_incoming: 2, _second: 2}),
        ]
        ..profileError = const FormatException('unavailable');
      final requests = await FriendsClient(api).fetchRequests(_account());
      expect(requests.map((r) => r.steamId), [_incoming, _second]);
      expect(
        requests.every((r) => r.name.isEmpty && r.avatarUrl.isEmpty),
        isTrue,
      );
      expect(api.profileIds, hasLength(1));
    },
  );

  test(
    'malformed/failed relationships never become a successful empty list',
    () async {
      for (final response in <Map<String, dynamic>>[
        {},
        {'success': 0},
        {'success': 1, 'friendslist': {}},
        _relationships({'123': 2}),
        {
          'success': 1,
          'friendslist': {
            'friends': [
              {'ulfriendid': _incoming, 'efriendrelationship': 2},
              {'ulfriendid': _incoming, 'efriendrelationship': 3},
            ],
          },
        },
      ]) {
        final api = _Api()..responses = [response];
        await expectLater(
          FriendsClient(api).fetchRequests(_account()),
          throwsFormatException,
        );
        expect(api.profileIds, isEmpty);
      }
    },
  );

  test(
    'accept posts once with matching CSRF cookie then verifies friendship',
    () async {
      final api = _Api()
        ..responses = [
          _relationships({_incoming: 2}),
          _relationships({_incoming: 3}),
        ];
      await FriendsClient(
        api,
      ).respondToRequest(_account(), _incoming, accept: true);
      final write = api.writes.single;
      expect(write.path, '/actions/AddFriendAjax');
      expect(write.form['steamid'], _incoming);
      expect(write.form['accept_invite'], 1);
      expect(write.form['sessionID'], write.cookies!['sessionid']);
      expect(write.cookies!['steamLoginSecure'], '$_owner||fixture-access');
      expect(api.reads, [
        '/textfilter/ajaxgetfriendslist',
        '/textfilter/ajaxgetfriendslist',
      ]);
      expect(api.profileIds, isEmpty);
    },
  );

  test('reject ignores invite, never calls block or friend removal', () async {
    final api = _Api()
      ..responses = [
        _relationships({_incoming: 2}),
        _relationships({}),
      ];
    await FriendsClient(
      api,
    ).respondToRequest(_account(), _incoming, accept: false);
    expect(api.writes.single.path, '/actions/IgnoreFriendInviteAjax');
    expect(api.writes.single.form.keys.toSet(), {'sessionID', 'steamid'});
  });

  test(
    'invalid/self/non-incoming IDs cannot write or send a new invite',
    () async {
      for (final id in ['123', _owner]) {
        final api = _Api();
        await expectLater(
          FriendsClient(api).respondToRequest(_account(), id, accept: true),
          throwsArgumentError,
        );
        expect(api.reads, isEmpty);
        expect(api.writes, isEmpty);
      }
      for (final relationship in [0, 1, 3, 4, 5]) {
        final api = _Api()
          ..responses = [
            _relationships({_incoming: relationship}),
          ];
        await expectLater(
          FriendsClient(
            api,
          ).respondToRequest(_account(), _incoming, accept: true),
          throwsA(isA<FriendRequestStateException>()),
        );
        expect(api.writes, isEmpty);
      }
    },
  );

  test('session changes during preflight prevent any write', () async {
    final account = _account();
    final api = _Api()
      ..responses = [
        _relationships({_incoming: 2}),
      ]
      ..beforeRead = (_) async {
        account.session.accessToken = 'changed';
      };
    await expectLater(
      FriendsClient(api).respondToRequest(account, _incoming, accept: true),
      throwsA(isA<FriendRequestStateException>()),
    );
    expect(api.writes, isEmpty);
  });

  test('uncertain write failure is not replayed', () async {
    final api = _Api()
      ..responses = [
        _relationships({_incoming: 2}),
      ]
      ..writeError = TimeoutException('synthetic');
    await expectLater(
      FriendsClient(api).respondToRequest(_account(), _incoming, accept: true),
      throwsA(isA<TimeoutException>()),
    );
    expect(api.writes, hasLength(1));
    expect(api.reads, hasLength(1));
  });

  test('soft server failure cannot be reported as accepted', () async {
    final api = _Api()
      ..responses = [
        _relationships({_incoming: 2}),
      ]
      ..writeResponse = {'success': 0};
    await expectLater(
      FriendsClient(api).respondToRequest(_account(), _incoming, accept: true),
      throwsA(isA<FriendRequestUnconfirmedException>()),
    );
    expect(api.writes, hasLength(1));
  });

  test(
    'unchanged/wrong relationship remains unconfirmed after one write',
    () async {
      for (final accept in [true, false]) {
        final api = _Api()
          ..responses = [
            _relationships({_incoming: 2}),
            _relationships({_incoming: 2}),
          ];
        await expectLater(
          FriendsClient(
            api,
          ).respondToRequest(_account(), _incoming, accept: accept),
          throwsA(isA<FriendRequestUnconfirmedException>()),
        );
        expect(api.writes, hasLength(1));
      }
    },
  );

  test(
    'session change after writing stops follow-up and reports uncertainty',
    () async {
      final account = _account();
      final api = _Api()
        ..responses = [
          _relationships({_incoming: 2}),
        ]
        ..onWrite = () {
          account.session.refreshToken = 'changed';
        };
      await expectLater(
        FriendsClient(api).respondToRequest(account, _incoming, accept: true),
        throwsA(isA<FriendRequestUnconfirmedException>()),
      );
      expect(api.writes, hasLength(1));
      expect(api.reads, hasLength(1));
    },
  );

  test('missing token prevents requests and friend writes', () async {
    final account = _account()..session.accessToken = null;
    final api = _Api();
    final client = FriendsClient(api);
    await expectLater(
      client.fetchRequests(account),
      throwsA(isA<MissingAccessTokenException>()),
    );
    await expectLater(
      client.respondToRequest(account, _incoming, accept: false),
      throwsA(isA<MissingAccessTokenException>()),
    );
    expect(api.reads, isEmpty);
    expect(api.writes, isEmpty);
  });
}
