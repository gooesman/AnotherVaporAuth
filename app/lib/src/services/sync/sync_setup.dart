/// Read-only helpers for the setup wizard: probe a prospective remote,
/// verify a passphrase against it before saving the connection.
library;

import 'dart:convert';

import '../../core/sync/sync_payload.dart';
import '../../core/sync/sync_transport.dart';

/// What a prospective remote looks like.
class RemoteInspection {
  /// A sidecar exists — this is an existing sync library.
  final bool exists;
  final int accountCount;
  final bool includePasswords;
  final SyncSidecar? sidecar;

  const RemoteInspection({
    required this.exists,
    this.accountCount = 0,
    this.includePasswords = true,
    this.sidecar,
  });
}

Future<RemoteInspection> inspectRemote(SyncTransport transport) async {
  final file = await transport.getFile(kSyncSidecarFilename);
  if (file == null) return const RemoteInspection(exists: false);
  final sidecar = SyncSidecar.parse(utf8.decode(file.bytes));
  return RemoteInspection(
    exists: true,
    accountCount: sidecar.accounts.length,
    includePasswords: sidecar.includePasswords,
    sidecar: sidecar,
  );
}

/// Verifies [passphrase] against an existing remote: the passkey_check token
/// when present, else a test-decrypt of one account file (older remotes).
/// True on an empty remote — there is nothing to contradict it.
Future<bool> verifyRemotePassphrase(
  SyncTransport transport,
  SyncSidecar sidecar,
  String passphrase,
) async {
  final byToken = verifyPasskeyCheck(passphrase, sidecar.passkeyCheck);
  if (byToken != null) return byToken;
  if (sidecar.accounts.isEmpty) return true;
  final probe = sidecar.accounts.values.first;
  final file = await transport.getFile(probe.filename);
  if (file == null) return true; // nothing to test against
  return decryptSyncPayload(
        passphrase,
        probe.salt,
        probe.iv,
        utf8.decode(file.bytes),
      ) !=
      null;
}
