import 'dart:async';
import 'dart:typed_data';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/core/crypto/vault_crypto.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/biometric_unlock.dart';
import 'package:ava/src/services/startup_unlock.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/services/vault_key_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _LocalSettings extends SettingsStore {
  _LocalSettings(super.storage);
  @override
  Future<int> loadPrivacyAcceptedVersion() async => 0;
}

class _BiometricDeleteFailure extends BiometricUnlock {
  @override
  Future<void> disableVerified() async => throw StateError('secure storage');
}

class _DelayedVaultKeys extends VaultKeyStore {
  final entered = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<bool> rewrapPin(String oldPin, String newPin) async {
    entered.complete();
    await resume.future;
    return super.rewrapPin(oldPin, newPin);
  }
}

class _SeededApp extends AppController {
  _SeededApp(this.initial);
  final AppData initial;
  @override
  Future<AppData> build() async => initial;
}

class _DelayedAccountStore extends AccountStore {
  _DelayedAccountStore(super.storage);
  final entered = Completer<void>();
  final resume = Completer<void>();
  bool pauseLegacyChange = false;
  bool pauseVaultSetup = false;

  @override
  Future<bool> changeEncryptionKey(String? oldKey, String? newKey) async {
    if (pauseLegacyChange) {
      entered.complete();
      await resume.future;
    }
    return super.changeEncryptionKey(oldKey, newKey);
  }

  @override
  Future<void> migrateToVault(
    Uint8List dek,
    List<SteamGuardAccount> accounts,
  ) async {
    await super.migrateToVault(dek, accounts);
    if (pauseVaultSetup) {
      entered.complete();
      await resume.future;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryStorageProvider storage;
  late VaultKeyStore keys;
  late StartupUnlock startup;
  const secret = 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=';

  ProviderContainer container({AppData? initial, BiometricUnlock? biometric}) {
    final value = ProviderContainer(
      overrides: [
        storageProvider.overrideWithValue(storage),
        settingsStoreProvider.overrideWithValue(_LocalSettings(storage)),
        vaultKeyStoreProvider.overrideWithValue(keys),
        startupUnlockProvider.overrideWithValue(startup),
        if (biometric != null)
          biometricUnlockProvider.overrideWithValue(biometric),
        timeAlignerProvider.overrideWithValue(() async {}),
        if (initial != null)
          appControllerProvider.overrideWith(() => _SeededApp(initial)),
      ],
    );
    addTearDown(value.dispose);
    return value;
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storage = MemoryStorageProvider();
    keys = VaultKeyStore();
    startup = StartupUnlock(vaultKeys: keys);
    final dek = VaultCrypto.generateDek();
    await keys.storePinWrap('123456', dek);
    final store = AccountStore(storage);
    await store.migrateToVault(dek, [
      SteamGuardAccount(
        sharedSecret: secret,
        accountName: 'fixture',
        session: SessionData(steamId: 111),
      ),
    ]);
  });

  test(
    'default startup is locked; opt-in skips the gate without decrypting stored files',
    () async {
      final first = container();
      expect((await first.read(appControllerProvider.future)).locked, isTrue);
      final controller = first.read(appControllerProvider.notifier);
      await expectLater(
        controller.setStartupVerificationEnabled(false),
        throwsStateError,
      );
      expect(await controller.unlock('123456'), isTrue);
      await controller.setStartupVerificationEnabled(false);
      final next = container();
      final data = await next.read(appControllerProvider.future);
      expect(data.locked, isFalse);
      expect(data.accounts.single.accountName, 'fixture');
      expect(data.store.isVault, isTrue);
      expect(storage.files.values.any((v) => v.contains(secret)), isFalse);
    },
  );

  test('re-enabling startup verification affects the next startup', () async {
    await startup.remember('123456');
    // An older installation may have both convenience and biometric keys.
    await const FlutterSecureStorage().write(
      key: 'ava.unlock.passkey',
      value: '123456',
    );
    final first = container();
    await first.read(appControllerProvider.future);
    await first
        .read(appControllerProvider.notifier)
        .setStartupVerificationEnabled(true);
    expect(await BiometricUnlock().isEnabled, isFalse);
    expect(
      (await container().read(appControllerProvider.future)).locked,
      isTrue,
    );
  });

  test(
    'disabling startup verification also removes biometric credentials',
    () async {
      await const FlutterSecureStorage().write(
        key: 'ava.unlock.passkey',
        value: '123456',
      );
      final first = container();
      await first.read(appControllerProvider.future);
      final controller = first.read(appControllerProvider.notifier);
      expect(await controller.unlock('123456'), isTrue);
      await controller.setStartupVerificationEnabled(false);
      expect(await startup.verificationRequired, isFalse);
      expect(await BiometricUnlock().isEnabled, isFalse);
      await controller.setStartupVerificationEnabled(true);
      expect(await BiometricUnlock().isEnabled, isFalse);
    },
  );

  for (final required in [true, false]) {
    test(
      'credential deletion failure does not change startup policy to $required',
      () async {
        if (required) await startup.remember('123456');
        final first = container(biometric: _BiometricDeleteFailure());
        await first.read(appControllerProvider.future);
        final controller = first.read(appControllerProvider.notifier);
        if (!required) expect(await controller.unlock('123456'), isTrue);
        await expectLater(
          controller.setStartupVerificationEnabled(required),
          throwsStateError,
        );
        expect(await startup.verificationRequired, !required);
      },
    );
  }

  test('a saved wrong PIN falls back to a usable manual unlock', () async {
    await startup.remember('000000');
    final first = container();
    expect((await first.read(appControllerProvider.future)).locked, isTrue);
    expect(
      await first.read(appControllerProvider.notifier).unlock('123456'),
      isTrue,
    );
  });

  test(
    'manual lock clears accounts and PIN and does not immediately auto-unlock',
    () async {
      await startup.remember('123456');
      final first = container();
      await first.read(appControllerProvider.future);
      final controller = first.read(appControllerProvider.notifier);
      controller.lock();
      await controller.reload();
      var data = first.read(appControllerProvider).value!;
      expect(data.locked, isTrue);
      expect(data.accounts, isEmpty);
      expect(data.passKey, isNull);
      expect(controller.manuallyLocked, isTrue);
      expect(await controller.unlock('654321'), isFalse);
      expect(await controller.unlock('123456'), isTrue);
      data = first.read(appControllerProvider).value!;
      expect(data.accounts.single.accountName, 'fixture');
      expect(controller.manuallyLocked, isFalse);
    },
  );

  test(
    'changing the PIN turns verification back on and preserves the vault',
    () async {
      await startup.remember('123456');
      await const FlutterSecureStorage().write(
        key: 'ava.unlock.passkey',
        value: '123456',
      );
      final first = container();
      await first.read(appControllerProvider.future);
      expect(await first.read(biometricUnlockEnabledProvider.future), isTrue);
      final controller = first.read(appControllerProvider.notifier);
      expect(await controller.changePasskey('123456', '654321'), isTrue);
      expect(await first.read(biometricUnlockEnabledProvider.future), isFalse);
      final next = container();
      expect((await next.read(appControllerProvider.future)).locked, isTrue);
      expect(
        await next.read(appControllerProvider.notifier).unlock('654321'),
        isTrue,
      );
      expect(
        next.read(appControllerProvider).value!.accounts.single.accountName,
        'fixture',
      );
    },
  );

  test(
    'a PIN change finishing after manual lock cannot resurrect the session',
    () async {
      final delayed = _DelayedVaultKeys();
      keys = delayed;
      final first = container();
      await first.read(appControllerProvider.future);
      final controller = first.read(appControllerProvider.notifier);
      expect(await controller.unlock('123456'), isTrue);
      final changing = controller.changePasskey('123456', '654321');
      await delayed.entered.future;
      controller.lock();
      delayed.resume.complete();
      expect(await changing, isTrue);
      final data = first.read(appControllerProvider).value!;
      expect(data.locked, isTrue);
      expect(data.passKey, isNull);
      expect(data.accounts, isEmpty);
      expect(data.visibleAccounts, isEmpty);
      expect(controller.manuallyLocked, isTrue);
      expect(await data.store.getAllAccounts(), isEmpty);
      expect(await controller.unlock('123456'), isFalse);
      expect(await controller.unlock('654321'), isTrue);
    },
  );

  test(
    'reset waits for an in-flight PIN write and cannot be overtaken by another change',
    () async {
      final delayed = _DelayedVaultKeys();
      keys = delayed;
      final first = container();
      await first.read(appControllerProvider.future);
      final controller = first.read(appControllerProvider.notifier);
      expect(await controller.unlock('123456'), isTrue);
      final changing = controller.changePasskey('123456', '654321');
      await delayed.entered.future;
      // A second rotation must never race the existing secure-store write.
      expect(await controller.changePasskey('123456', '111111'), isFalse);
      controller.lock();
      var resetDone = false;
      final reset = controller.resetVault().then((_) => resetDone = true);
      await Future<void>.delayed(Duration.zero);
      expect(resetDone, isFalse);
      expect(await keys.exists, isTrue);
      expect((await AccountStore.load(storage)).isVault, isTrue);
      expect(await controller.changePasskey('123456', '222222'), isFalse);
      delayed.resume.complete();
      expect(await changing, isTrue);
      await reset;
      final afterReset = await first.read(appControllerProvider.future);
      expect(afterReset.encrypted, isFalse);
      expect(afterReset.locked, isFalse);
      expect(afterReset.accounts, isEmpty);
      expect(await keys.exists, isFalse);
      // Only now can a fresh PIN establish a new vault. No old write remains
      // to replace its key after creation.
      expect(await controller.changePasskey(null, '999999'), isTrue);
      expect(await keys.unwrapWithPin('999999'), isNotNull);
      expect(await keys.unwrapWithPin('654321'), isNull);
    },
  );

  for (final fresh in [true, false]) {
    test(
      '${fresh ? 'first PIN setup' : 'legacy PIN rotation'} preserves a concurrent lock',
      () async {
        storage = MemoryStorageProvider();
        final store = _DelayedAccountStore(storage);
        final account = SteamGuardAccount(
          sharedSecret: secret,
          accountName: 'fixture',
          session: SessionData(steamId: 111),
        );
        expect(await store.saveAccount(account, false), isTrue);
        if (!fresh) {
          expect(await store.changeEncryptionKey(null, '123456'), isTrue);
          store.pauseLegacyChange = true;
        } else {
          store.pauseVaultSetup = true;
        }
        final first = container(
          initial: AppData(
            store: store,
            accounts: [account],
            locked: false,
            passKey: fresh ? null : '123456',
            privacyVersion: 0,
          ),
        );
        await first.read(appControllerProvider.future);
        final controller = first.read(appControllerProvider.notifier);
        final changing = controller.changePasskey(
          fresh ? null : '123456',
          '654321',
        );
        await store.entered.future;
        controller.lock();
        store.resume.complete();
        expect(await changing, isTrue);
        final data = first.read(appControllerProvider).value!;
        expect(data.locked, isTrue);
        expect(data.passKey, isNull);
        expect(data.accounts, isEmpty);
        expect(controller.manuallyLocked, isTrue);
        if (fresh) {
          expect(await store.getAllAccounts(), isEmpty);
          expect(await keys.unwrapWithPin('654321'), isNotNull);
        } else {
          expect(await store.verifyPasskey('654321'), isTrue);
          expect(await store.verifyPasskey('123456'), isFalse);
        }
      },
    );
  }
}
