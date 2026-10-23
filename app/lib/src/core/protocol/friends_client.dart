import '../../services/steam_api_client.dart';
import '../models/steam_friend.dart';
import '../models/steam_guard_account.dart';
import '../proto/protobuf_wire.dart';
import 'community_session.dart';

/// Reads the same authenticated community page as Steam's friends UI. Unlike
/// ISteamUser/GetFriendList this does not ask users for a separate API key.
/// Verified against `steamcommunity.com/profiles/<id>/friends/` (2026-10-10).
class FriendsClient {
  final SteamApiClient api;
  FriendsClient(this.api);

  // Relationship endpoint/schema: node-steamcommunity/index.js getFriendsList.
  // Profile batch: SteamTracking/Protobufs webui/service_player.proto.
  Future<List<SteamFriendRequest>> fetchRequests(
    SteamGuardAccount account,
  ) async {
    final token = requireAccessToken(account);
    final relationships = await _relationships(account);
    final requests = <String, SteamFriendRequest>{
      for (final entry in relationships.entries)
        if (entry.value == 2) entry.key: SteamFriendRequest(steamId: entry.key),
    };
    if (requests.isEmpty) return const [];
    try {
      final request = ProtoWriter();
      for (final id in requests.keys) {
        request.writeUint64(1, int.parse(id));
      }
      final response = await api.callProtobuf(
        'IPlayerService',
        'GetPlayerLinkDetails',
        request: request,
        accessToken: token,
        useGet: true,
      );
      for (final field in response.parseAll()) {
        if (field.number != 1 || field.bytes == null) continue;
        final public = ProtoReader(field.bytes!).parse()[1]?.bytes;
        if (public == null) continue;
        final profile = ProtoReader(public).parse();
        final id = profile[1]?.asFixed64.toString();
        if (!requests.containsKey(id)) continue;
        final avatar = profile[9]?.bytes;
        final hash = avatar != null && avatar.length == 20
            ? avatar.map((b) => b.toRadixString(16).padLeft(2, '0')).join()
            : '';
        requests[id!] = SteamFriendRequest(
          steamId: id,
          name: profile[10]?.asString ?? '',
          avatarUrl: hash.isEmpty
              ? ''
              : 'https://avatars.steamstatic.com/${hash}_medium.jpg',
        );
      }
    } catch (_) {
      // Profile metadata is optional; do not hide valid incoming requests or
      // retry individual profiles when this one batch lookup is unavailable.
    }
    return List.unmodifiable(requests.values);
  }

  Future<Map<String, int>> _relationships(SteamGuardAccount account) async {
    requireAccessToken(account);
    if (!isIndividualSteamId('${account.steamId}')) {
      throw ArgumentError('Invalid SteamID');
    }
    final response = await api.communityGetJson(
      '/textfilter/ajaxgetfriendslist',
      const {},
      cookies: communityCookies(account),
    );
    final list = response['friendslist'];
    final friends = list is Map ? list['friends'] : null;
    if (response['success'] != 1 || friends is! List) {
      throw const FormatException('Steam friend relationships unavailable');
    }
    final result = <String, int>{};
    for (final friend in friends) {
      if (friend is! Map) {
        throw const FormatException('Invalid Steam friend relationship');
      }
      final id = '${friend['ulfriendid']}';
      final relationship = friend['efriendrelationship'];
      if (!isIndividualSteamId(id) ||
          relationship is! int ||
          result.containsKey(id)) {
        throw const FormatException('Invalid Steam friend relationship');
      }
      result[id] = relationship;
    }
    return result;
  }

  /// Official community profile.js uses AddFriendAjax(accept_invite=1) and
  /// IgnoreFriendInviteAjax. Ignoring an invite does not block the inviter.
  /// A write is sent once; uncertain responses must never replay it.
  Future<void> respondToRequest(
    SteamGuardAccount account,
    String steamId, {
    required bool accept,
  }) async {
    if (!isIndividualSteamId(steamId) || steamId == '${account.steamId}') {
      throw ArgumentError('Invalid incoming friend SteamID');
    }
    final owner = account.steamId;
    final token = requireAccessToken(account);
    final refreshToken = account.session.refreshToken;
    bool sameSession() =>
        account.steamId == owner &&
        account.session.accessToken == token &&
        account.session.refreshToken == refreshToken;
    final before = await _relationships(account);
    if (!sameSession() || before[steamId] != 2) {
      throw const FriendRequestStateException();
    }
    final sessionId = newCommunitySessionId();
    final response = await api.communityPostJson(
      accept ? '/actions/AddFriendAjax' : '/actions/IgnoreFriendInviteAjax',
      {
        'sessionID': sessionId,
        'steamid': steamId,
        if (accept) 'accept_invite': 1,
      },
      cookies: communityCookies(account, sessionId: sessionId),
      referer: 'https://steamcommunity.com/profiles/$steamId',
    );
    // These endpoints can return an empty successful body. Do not invent a
    // success field requirement; verify the authoritative relationship next.
    final success = response['success'];
    if (!sameSession() ||
        (success != null && success != 1 && success != true)) {
      throw const FriendRequestUnconfirmedException();
    }
    try {
      final after = await _relationships(account);
      final relation = after[steamId] ?? 0;
      if (!sameSession() || (accept ? relation != 3 : relation != 0)) {
        throw const FriendRequestUnconfirmedException();
      }
    } catch (_) {
      throw const FriendRequestUnconfirmedException();
    }
  }

  Future<List<SteamFriend>> fetch(SteamGuardAccount account) async {
    requireAccessToken(account);
    final id = '${account.steamId}';
    if (!isIndividualSteamId(id)) throw ArgumentError('Invalid SteamID');
    final path = '/profiles/$id/friends/?l=${api.steamLanguage}';
    final html = await api.communityGetText(
      path,
      cookies: communityCookies(account),
    );
    // Steam may render a public profile instead of redirecting after a stale
    // cookie. Do not silently treat that page as the authenticated account.
    final viewer = RegExp(
      r'''g_steamID\s*=\s*(["']?)(\d+|false)\1''',
    ).firstMatch(html)?.group(2);
    if (viewer != null && viewer != id) {
      throw CommunityAuthException(401, path);
    }
    return parseFriends(html);
  }

  static List<SteamFriend> parseFriends(String html) {
    final starts = RegExp(
      r'''<div\b[^>]*\bclass\s*=\s*["'][^"']*\bfriend_block_v2\b[^"']*["'][^>]*>''',
      caseSensitive: false,
    ).allMatches(html).toList();
    if (starts.isEmpty) {
      // A real empty friends list has the list container. Private/error/login
      // pages do not: preserve that distinction instead of returning zero.
      if (!RegExp(r'''class=["'][^"']*\bprofile_friends\b''').hasMatch(html)) {
        throw const FormatException('Steam friends page unavailable');
      }
      return const [];
    }
    final friends = <String, SteamFriend>{};
    for (var i = 0; i < starts.length; i++) {
      final header = starts[i].group(0)!;
      final id = RegExp(
        r'''\bdata-steamid\s*=\s*["'](\d+)["']''',
      ).firstMatch(header)?.group(1);
      if (id == null || !isIndividualSteamId(id)) {
        throw const FormatException('Invalid friend SteamID');
      }
      final block = html.substring(
        starts[i].end,
        i + 1 < starts.length ? starts[i + 1].start : html.length,
      );
      final name = RegExp(
        r'''class=["'][^"']*\bfriend_block_content\b[^"']*["'][^>]*>([\s\S]*?)(?:<br\s*/?>|</div>)''',
        caseSensitive: false,
      ).firstMatch(block)?.group(1);
      if (name == null) {
        throw const FormatException('Steam friends page changed');
      }
      final image =
          RegExp(
            r'''<img\b[^>]*\bsrc=["']([^"']+)["']''',
          ).firstMatch(block)?.group(1) ??
          '';
      final url = Uri.tryParse(image);
      final safeImage =
          url != null &&
              url.scheme == 'https' &&
              (url.host.endsWith('.steamstatic.com') ||
                  url.host.endsWith('.steamusercontent.com'))
          ? image
          : '';
      final game =
          RegExp(
            r'''class=["']friend_game_link["'][^>]*>([\s\S]*?)</span>''',
          ).firstMatch(block)?.group(1) ??
          '';
      friends[id] = SteamFriend(
        steamId: id,
        name: _text(name),
        avatarUrl: safeImage,
        state: header.contains('in-game')
            ? SteamFriendState.playing
            : RegExp(r'\bonline\b').hasMatch(header)
            ? SteamFriendState.online
            : SteamFriendState.offline,
        game: _text(game),
      );
    }
    return friends.values.toList();
  }

  static String _text(String value) =>
      value.replaceAll(RegExp(r'<[^>]*>'), '').replaceAllMapped(
        RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos|nbsp);'),
        (m) {
          final entity = m.group(1)!;
          if (entity.startsWith('#')) {
            final code = entity.startsWith('#x')
                ? int.tryParse(entity.substring(2), radix: 16)
                : int.tryParse(entity.substring(1));
            return code != null &&
                    code > 0 &&
                    code <= 0x10ffff &&
                    !(code >= 0xd800 && code <= 0xdfff)
                ? String.fromCharCode(code)
                : '\uFFFD';
          }
          return const {
            'amp': '&',
            'lt': '<',
            'gt': '>',
            'quot': '"',
            'apos': "'",
            'nbsp': ' ',
          }[entity]!;
        },
      ).trim();
}

class FriendRequestStateException implements Exception {
  const FriendRequestStateException();
}

class FriendRequestUnconfirmedException implements Exception {
  const FriendRequestUnconfirmedException();
}
