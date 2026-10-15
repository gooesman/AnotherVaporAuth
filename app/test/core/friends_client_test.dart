import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_friend.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/protocol/community_session.dart';
import 'package:ava/src/core/protocol/friends_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

const _owner = '76561198000000001';
const _friend = '76561198000000002';
String _block({
  String id = _friend,
  String state = 'online',
  String avatar = 'https://avatars.fastly.steamstatic.com/test.jpg',
}) =>
    '''
<div class="selectable friend_block_v2 persona $state" id="fr_2" data-steamid="$id">
<a class="selectable_overlay" href="https://steamcommunity.com/profiles/$id"></a>
<div class="player_avatar"><img src="$avatar"></div>
<div class="friend_block_content">Alice &amp; &#x732B;<br>
<span class="friend_small_text"><span class="friend_game_link">Dota 2</span></span>
</div></div>''';

class _Api extends SteamApiClient {
  String html = '';
  String? path;
  Map<String, String>? cookies;
  @override
  Future<String> communityGetText(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? cookies,
  }) async {
    this.path = path;
    this.cookies = cookies;
    return html;
  }
}

void main() {
  test(
    'friend markup decodes names and state without confusing numeric identities',
    () {
      final friends = FriendsClient.parseFriends(_block(state: 'in-game'));
      expect(friends.single.steamId, _friend);
      expect(friends.single.name, 'Alice & 猫');
      expect(friends.single.game, 'Dota 2');
      expect(friends.single.state, SteamFriendState.playing);
    },
  );
  test('same nickname keeps distinct IDs; repeated ID is deduplicated', () {
    final friends = FriendsClient.parseFriends(
      '${_block()}${_block(id: _owner)}${_block()}',
    );
    expect(friends, hasLength(2));
  });
  test('foreign avatar URLs are not loaded', () {
    expect(
      FriendsClient.parseFriends(
        _block(avatar: 'https://evil.example/a.jpg'),
      ).single.avatarUrl,
      isEmpty,
    );
  });
  test('genuine empty page differs from login/private/unrecognized page', () {
    expect(
      FriendsClient.parseFriends(
        '<div class="profile_friends search_results"></div>',
      ),
      isEmpty,
    );
    expect(
      () => FriendsClient.parseFriends('<html>private profile</html>'),
      throwsFormatException,
    );
    expect(
      () => FriendsClient.parseFriends(_block(id: '123')),
      throwsFormatException,
    );
  });
  test('individual SteamID boundaries and account-id conversion', () {
    expect(isIndividualSteamId('76561197960265728'), isFalse);
    expect(isIndividualSteamId('76561197960265729'), isTrue);
    expect(isIndividualSteamId('76561202255233023'), isTrue);
    expect(isIndividualSteamId('76561202255233024'), isFalse);
    expect(steamAccountId('76561202255233023'), '4294967295');
    expect(() => steamAccountId('123'), throwsArgumentError);
  });
  test(
    'fetch uses selected-account cookies and rejects stale public fallback',
    () async {
      final api = _Api()..html = 'var g_steamID = false;${_block()}';
      final account = SteamGuardAccount(
        session: SessionData(steamId: int.parse(_owner), accessToken: 'token'),
      );
      await expectLater(
        FriendsClient(api).fetch(account),
        throwsA(isA<CommunityAuthException>()),
      );
      expect(api.path, '/profiles/$_owner/friends/?l=english');
      expect(api.cookies!['steamLoginSecure'], '$_owner||token');
      api.html = 'var g_steamID = "$_owner";${_block()}';
      expect(await FriendsClient(api).fetch(account), hasLength(1));
      api.html = 'var g_steamID = "$_friend";${_block()}';
      await expectLater(
        FriendsClient(api).fetch(account),
        throwsA(isA<CommunityAuthException>()),
      );
    },
  );
  test('missing token stops before HTTP', () async {
    final api = _Api();
    await expectLater(
      FriendsClient(api).fetch(
        SteamGuardAccount(session: SessionData(steamId: int.parse(_owner))),
      ),
      throwsA(isA<MissingAccessTokenException>()),
    );
    expect(api.path, isNull);
  });
}
