/// A friend shown by Steam's authenticated community friends page.
class SteamFriend {
  final String steamId;
  final String name;
  final String avatarUrl;
  final SteamFriendState state;
  final String game;

  const SteamFriend({
    required this.steamId,
    required this.name,
    this.avatarUrl = '',
    this.state = SteamFriendState.offline,
    this.game = '',
  });
}

enum SteamFriendState { offline, online, playing }

/// Public individual SteamIDs use universe 1, type 1, instance 1.
/// Keeping IDs as decimal strings avoids precision loss on other targets.
bool isIndividualSteamId(String value) {
  if (!RegExp(r'^[1-9]\d{16}$').hasMatch(value)) return false;
  final id = BigInt.tryParse(value);
  final base = BigInt.parse('76561197960265728');
  return id != null && id > base && id <= base + BigInt.from(0xffffffff);
}

String steamAccountId(String value) {
  if (!isIndividualSteamId(value)) throw ArgumentError('Invalid SteamID');
  return (BigInt.parse(value) - BigInt.parse('76561197960265728')).toString();
}
