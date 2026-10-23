import 'package:ava/src/core/crypto/vault_crypto.dart';
import 'package:ava/src/services/startup_unlock.dart';
import 'package:ava/src/services/vault_key_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnavailableStorage implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Platform secure storage unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> secureData;
  late VaultKeyStore keys;
  late StartupUnlock startup;

  setUp(() async {
    secureData = {};
    FlutterSecureStorage.setMockInitialValues(secureData);
    keys = VaultKeyStore();
    startup = StartupUnlock(vaultKeys: keys);
    await keys.storePinWrap('123456', VaultCrypto.generateDek());
  });

  test(
    'verification defaults on and explicit convenience opt-in round-trips',
    () async {
      expect(await startup.verificationRequired, isTrue);
      await startup.remember('123456');
      expect(await startup.verificationRequired, isFalse);
      expect(await StartupUnlock().readPasskey(), '123456');
      await startup.forget();
      expect(await startup.verificationRequired, isTrue);
      expect(await keys.unwrapWithPin('123456'), isNotNull);
    },
  );

  test(
    'a changed PIN invalidates a leftover credential without needing deletion',
    () async {
      await startup.remember('123456');
      expect(await keys.rewrapPin('123456', '654321'), isTrue);
      expect(secureData.containsKey('ava.startup.passkey'), isTrue);
      expect(await startup.readPasskey(), isNull);
      expect(await startup.verificationRequired, isTrue);
    },
  );

  test(
    'recreated vault reusing the PIN cannot reuse the old convenience credential',
    () async {
      await startup.remember('123456');
      await keys.clear();
      await keys.storePinWrap('123456', VaultCrypto.generateDek());
      expect(await startup.readPasskey(), isNull);
    },
  );

  test('invalid convenience record falls back to verification', () async {
    secureData['ava.startup.passkey'] = '{broken';
    expect(await startup.verificationRequired, isTrue);
    secureData['ava.startup.passkey'] = '{"pin":123456}';
    expect(await startup.readPasskey(), isNull);
  });

  test(
    'secure storage failure cannot silently disable or claim to enable verification',
    () async {
      final unavailable = StartupUnlock(store: _UnavailableStorage());
      expect(await unavailable.verificationRequired, isTrue);
      await expectLater(unavailable.remember('123456'), throwsStateError);
      await expectLater(unavailable.forget(), throwsStateError);
    },
  );
}
