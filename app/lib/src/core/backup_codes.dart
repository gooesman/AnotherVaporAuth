/// The SMS step is bound to the selected Steam account, never another account
/// opened later in the app. This object contains no session token or SMS code.
class BackupCodesChallenge {
  final int steamId;
  final String? phoneHint;

  const BackupCodesChallenge({required this.steamId, this.phoneHint});
}

enum BackupCodesError {
  authenticationRequired,
  invalidCode,
  rateLimited,
  phoneRequired,
  rejected,
  invalidResponse,
  network,
  cancelled,
}

/// Deliberately excludes the request, response, token, phone and returned codes.
/// Even accidental logging of this exception cannot serialize those secrets.
class BackupCodesException implements Exception {
  final BackupCodesError code;

  const BackupCodesException(this.code);

  @override
  String toString() => 'BackupCodesException(${code.name})';
}
