import '../core/models/session_data.dart';
import '../core/proto/protobuf_wire.dart';
import 'debug_log.dart';
import 'steam_api_client.dart';

/// A failed exchange is not proof that the stored refresh token is invalid.
enum SessionRefreshOutcome { refreshed, missingRefreshToken, rejected, failed }

/// Manages refreshing the short-lived access token from the refresh token.
class SessionManager {
  final SteamApiClient api;
  SessionManager(this.api);

  /// Returns true if the access token looks present (a JWT is opaque to us;
  /// real expiry is enforced server-side, so we refresh on 401-style failures).
  bool hasUsableToken(SessionData session) => session.hasTokens;

  /// Exchanges the refresh token for a fresh access token, updating [session]
  /// in place. Returns false if there is no refresh token or the call fails.
  Future<bool> refresh(SessionData session) async =>
      await refreshResult(session) == SessionRefreshOutcome.refreshed;

  /// Only explicit authentication failures justify trying saved credentials.
  /// InvalidParam, throttling, server errors and transport errors do not tell
  /// us whether the token is still valid and must not trigger another login.
  static bool isAuthenticationError(Object error) =>
      isSessionDeadError(error) ||
      (error is SteamApiException &&
          const {
            5, // InvalidPassword (invalid token on a token exchange)
            15, // AccessDenied
            21, // NotLoggedOn
            26, // Revoked
            27, // Expired
            34, // LogonSessionReplaced
            77, // RequirePasswordReEntry
            126, // CachedCredentialInvalid
          }.contains(error.eresult));

  /// Exchanges tokens without conflating a network failure with rejection.
  /// Existing tokens are retained unless a complete replacement is returned.
  Future<SessionRefreshOutcome> refreshResult(SessionData session) async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      dlog('session refresh: no refresh_token (old maFile) — login required');
      return SessionRefreshOutcome.missingRefreshToken;
    }
    dlog('session refresh: exchanging refresh_token for new access_token…');
    try {
      final req = ProtoWriter()
        ..writeString(1, refreshToken) // refresh_token
        ..writeFixed64(2, session.steamId); // steamid (fixed64!)
      final fields = (await api.callProtobuf(
        'IAuthenticationService',
        'GenerateAccessTokenForApp',
        request: req,
      )).parse();
      final newAccess = fields[1]?.asString;
      if (newAccess != null && newAccess.isNotEmpty) {
        final newRefresh = fields[2]?.asString;
        session.accessToken = newAccess;
        if (newRefresh != null && newRefresh.isNotEmpty) {
          session.refreshToken = newRefresh;
        }
        dlog('session refresh: ok (new access_token)');
        return SessionRefreshOutcome.refreshed;
      }
      dlog('session refresh: failed (no access_token in response)');
      return SessionRefreshOutcome.failed;
    } catch (e) {
      dlog('session refresh: error $e');
      return isAuthenticationError(e)
          ? SessionRefreshOutcome.rejected
          : SessionRefreshOutcome.failed;
    }
  }
}
