import '../../services/steam_api_client.dart';
import '../models/steam_friend.dart';
import '../models/steam_guard_account.dart';
import 'community_session.dart';

/// Reads the same authenticated community page as Steam's friends UI. Unlike
/// ISteamUser/GetFriendList this does not ask users for a separate API key.
/// Verified against `steamcommunity.com/profiles/<id>/friends/` (2026-10-10).
class FriendsClient {
  final SteamApiClient api;
  FriendsClient(this.api);

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
