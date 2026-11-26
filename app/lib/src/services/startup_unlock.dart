import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vault_key_store.dart';

/// An opt-in, device-local convenience credential. The vault remains encrypted
/// and its PIN wrap remains intact. Nothing is written to app settings, account
/// exports or sync; unavailable secure storage always falls back to manual PIN.
class StartupUnlock {
  StartupUnlock({FlutterSecureStorage? store, VaultKeyStore? vaultKeys})
    : _vaultKeys = vaultKeys ?? VaultKeyStore(store: store),
      _store =
          store ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _store;
  final VaultKeyStore _vaultKeys;
  static const _key = 'ava.startup.passkey';

  Future<String?> readPasskey() async {
    try {
      final raw = await _store.read(key: _key);
      if (raw == null) return null;
      final record = jsonDecode(raw) as Map<String, dynamic>;
      final pin = record['pin'];
      final binding = await _vaultKeys.binding;
      return record['v'] == 1 && binding != null &&
              record['binding'] == binding &&
              pin is String &&
              RegExp(r'^\d{6}$').hasMatch(pin)
          ? pin
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> get verificationRequired async => await readPasskey() == null;

  /// Called only after the controller has verified an unlocked vault session.
  Future<void> remember(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('A six-digit vault PIN is required');
    }
    final binding = await _vaultKeys.binding;
    if (binding == null) throw StateError('A vault must be set up first');
    final record = jsonEncode({'v': 1, 'binding': binding, 'pin': pin});
    await _store.write(key: _key, value: record);
    if (await _store.read(key: _key) != record) {
      throw StateError('Secure storage did not save the startup preference');
    }
  }

  /// Failure is deliberately propagated: the UI must never say verification
  /// is enabled while a usable convenience credential remains stored.
  Future<void> forget() async {
    await _store.delete(key: _key);
    if (await _store.read(key: _key) != null) {
      throw StateError('Secure storage did not clear the startup preference');
    }
  }
}
