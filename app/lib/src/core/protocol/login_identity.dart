import '../jwt.dart';
import '../models/session_data.dart';
import '../models/steam_friend.dart';

class LoginAccountMismatch implements Exception {
  const LoginAccountMismatch();
}

/// Checks every identity before any account/session/password is mutated.
/// Negative IDs are code-only placeholders and may bind to a real identity.
/// The expected ID is captured when the login screen opens, so changing the
/// account object during a pending login cannot silently redefine the target.
void validateRefreshIdentity({
  required int expectedSteamId,
  required int currentSteamId,
  required SessionData session,
}) {
  if (currentSteamId != expectedSteamId ||
      (expectedSteamId > 0 && session.steamId != expectedSteamId)) {
    throw const LoginAccountMismatch();
  }
  if (!isIndividualSteamId('${session.steamId}') || !session.hasTokens) {
    throw const FormatException('Steam login identity is missing');
  }
  // JWT payloads are read only as an additional consistency check on the
  // Steam response; decoding them does not replace server authentication.
  for (final token in [session.accessToken, session.refreshToken]) {
    if (token == null || token.isEmpty) continue;
    final subject = decodeJwtPayload(token)?['sub']?.toString();
    if (subject == null) {
      throw const FormatException('Steam token identity is missing');
    }
    if (subject != '${session.steamId}') {
      throw const LoginAccountMismatch();
    }
  }
}
