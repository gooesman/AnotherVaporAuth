import 'package:ava/src/services/biometric_unlock.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _SecureStorage implements FlutterSecureStorage {
  final values = <String, String>{
    'ava.unlock.passkey': '123456',
    'ava.startup.passkey': 'startup-record',
  };
  bool ignoreDeletion = false;
  Object? deleteError;
  Object? containsError;
  final calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String;
    if (invocation.memberName == #delete) {
      calls.add('delete:$key');
      return Future<void>(() {
        if (deleteError case final error?) throw error;
        if (!ignoreDeletion) values.remove(key);
      });
    }
    if (invocation.memberName == #containsKey) {
      calls.add('contains:$key');
      return Future<bool>(() {
        if (containsError case final error?) throw error;
        return values.containsKey(key);
      });
    }
    throw UnsupportedError('${invocation.memberName}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'verified disable deletes only the biometric credential and verifies it',
    () async {
      final storage = _SecureStorage();
      final biometric = BiometricUnlock(store: storage);

      await biometric.disableVerified();

      expect(storage.values, {'ava.startup.passkey': 'startup-record'});
      expect(storage.calls, [
        'delete:ava.unlock.passkey',
        'contains:ava.unlock.passkey',
      ]);
      expect(await biometric.isEnabled, isFalse);
      // Repeating an already completed settings operation is harmless.
      await biometric.disableVerified();
    },
  );

  test(
    'verified disable rejects a platform deletion that silently did nothing',
    () async {
      final storage = _SecureStorage()..ignoreDeletion = true;
      final biometric = BiometricUnlock(store: storage);

      await expectLater(biometric.disableVerified(), throwsStateError);

      expect(await biometric.isEnabled, isTrue);
      expect(storage.values['ava.startup.passkey'], 'startup-record');
    },
  );

  test(
    'verified disable propagates deletion errors without claiming success',
    () async {
      final error = StateError('Keystore unavailable');
      final storage = _SecureStorage()..deleteError = error;
      final biometric = BiometricUnlock(store: storage);

      await expectLater(biometric.disableVerified(), throwsA(same(error)));

      expect(storage.calls, ['delete:ava.unlock.passkey']);
      expect(storage.values['ava.unlock.passkey'], '123456');
      // The existing vault-reset cleanup API deliberately remains best-effort.
      await biometric.disable();
    },
  );

  test(
    'verified disable propagates an unavailable post-deletion check',
    () async {
      final error = StateError('Keystore read unavailable');
      final storage = _SecureStorage()..containsError = error;

      await expectLater(
        BiometricUnlock(store: storage).disableVerified(),
        throwsA(same(error)),
      );

      expect(storage.calls, [
        'delete:ava.unlock.passkey',
        'contains:ava.unlock.passkey',
      ]);
    },
  );
}
