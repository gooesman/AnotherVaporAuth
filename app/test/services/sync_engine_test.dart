import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/sync/sync_payload.dart';
import 'package:ava/src/core/sync/sync_transport.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/services/sync/sync_config_store.dart';
import 'package:ava/src/services/sync/sync_engine.dart';
import 'package:ava/src/services/sync/sync_trash.dart';
import 'package:flutter_test/flutter_test.dart';

// End-to-end engine tests over an in-memory transport: two simulated
// devices share one "server" map and sync against it. This is the spec's
// acceptance list run as code — propagation both ways, tombstones, both
// conflict outcomes with trash copies, the 412 retry, the weak-ETag server,
// the passwords toggle, and the trash-write-failure refusal.

/// One shared in-memory WebDAV-ish server.
class InMemoryServer {
  final Map<String, (Uint8List, String)> files = {};
  int etagSeq = 0;
  bool enforceConditionals = true;

  /// Fails every If-Match PUT, like an origin behind a proxy that rewrites
  /// the ETags it hands out.
  bool rejectIfMatch = false;

  /// Called before every PUT — lets a test inject a concurrent commit.
  void Function(String name)? onPut;
}

class InMemoryTransport implements SyncTransport {
  final InMemoryServer server;
  InMemoryTransport(this.server);

  @override
  Future<void> ensureRoot() async {}

  @override
  Future<RemoteFile?> getFile(String name) async {
    final f = server.files[name];
    return f == null ? null : RemoteFile(f.$1, f.$2);
  }

  @override
  Future<String?> putFile(String name, Uint8List bytes,
      {String? ifMatch, bool ifAbsent = false}) async {
    server.onPut?.call(name);
    if (server.rejectIfMatch && ifMatch != null) {
      throw const SyncPreconditionFailed('etag rewritten');
    }
    if (server.enforceConditionals) {
      final existing = server.files[name];
      if (ifAbsent && existing != null) {
        throw const SyncPreconditionFailed('exists');
      }
      if (ifMatch != null &&
          (existing == null || existing.$2 != ifMatch)) {
        throw const SyncPreconditionFailed('etag mismatch');
      }
    }
    final etag = 'e${++server.etagSeq}';
    server.files[name] = (bytes, etag);
    return etag;
  }

  @override
  Future<void> deleteFile(String name) async => server.files.remove(name);

  @override
  Future<void> probe() async {}

  @override
  Future<bool> checkConditionalSupport() async =>
      server.enforceConditionals;

  @override
  void close() {}
}

class MemoryConfigStore extends SyncConfigStore {
  MemoryConfigStore() : super(MemoryStorageProvider());

  SyncConfig? config;
  SyncLocalState state = const SyncLocalState();
  String? webdavPassword = 'server-pw';
  String? passphrase;
  String? previousPassphrase;
  bool failNextStateSave = false;
  bool failNextConfigSave = false;
  bool failSavePrevious = false;

  @override
  Future<SyncConfig?> loadConfig() async => config;
  @override
  Future<void> saveConfig(SyncConfig c) async {
    if (failNextConfigSave) {
      failNextConfigSave = false;
      throw StateError('config storage unavailable');
    }
    config = c;
  }
  @override
  Future<SyncLocalState> loadState() async => state;
  @override
  Future<void> saveState(SyncLocalState s) async {
    if (failNextStateSave) {
      failNextStateSave = false;
      throw StateError('state storage unavailable');
    }
    state = s;
  }
  @override
  Future<String?> loadWebdavPassword() async => webdavPassword;
  @override
  Future<void> saveWebdavPassword(String p) async => webdavPassword = p;
  @override
  Future<String?> loadPassphrase() async => passphrase;
  @override
  Future<void> savePassphrase(String p) async => passphrase = p;
  @override
  Future<String?> loadPreviousPassphrase() async => previousPassphrase;
  @override
  Future<void> savePreviousPassphrase(String p) async {
    if (failSavePrevious) throw StateError('secure storage unavailable');
    previousPassphrase = p;
  }
  @override
  Future<void> clearPreviousPassphrase() async => previousPassphrase = null;
  @override
  Future<void> clearAll() async {
    config = null;
    state = const SyncLocalState();
    webdavPassword = null;
    previousPassphrase = null;
  }
}

class MemoryTrash extends SyncTrash {
  MemoryTrash() : super(MemoryStorageProvider());

  final List<({int steamId, SyncTrashReason reason})> entries = [];
  bool failPuts = false;

  @override
  Future<bool> put({
    required int steamId,
    required String? accountName,
    required Map<String, dynamic> payload,
    required SyncTrashReason reason,
    required String passphrase,
  }) async {
    if (failPuts) return false;
    entries.add((steamId: steamId, reason: reason));
    return true;
  }

  @override
  Future<void> purgeExpired() async {}
}

class FakePort implements SyncAccountsPort {
  final List<SteamGuardAccount> accounts = [];
  bool locked = false;

  @override
  List<SteamGuardAccount>? snapshot() => locked ? null : accounts;

  @override
  Future<void> applyRemote(Map<String, dynamic> payload) async {
    final incoming = SteamGuardAccount.fromJson(
        jsonDecode(jsonEncode(payload)) as Map<String, dynamic>);
    accounts.removeWhere((a) => a.steamId == incoming.steamId);
    accounts.add(incoming);
  }

  @override
  Future<void> removeAccount(int steamId) async {
    accounts.removeWhere((a) => a.steamId == steamId);
  }
}

class FakeSettingsPort implements SyncSettingsPort {
  Map<String, dynamic> values = {
    'skin': 'none',
    'brightness_mode': 'system',
    'hold_confirm': true,
  };
  int applies = 0;
  bool failApply = false;

  @override
  Future<Map<String, dynamic>?> snapshot() async => Map.of(values);

  @override
  Future<void> apply(Map<String, dynamic> doc) async {
    if (failApply) throw StateError('secure storage unavailable');
    applies++;
    values = {...values, ...doc};
  }
}

/// One simulated device.
class Device {
  final MemoryConfigStore configStore = MemoryConfigStore();
  final MemoryTrash trash = MemoryTrash();
  final FakePort port = FakePort();
  final FakeSettingsPort settingsPort = FakeSettingsPort();
  late final SyncEngine engine;

  Device(InMemoryServer server, String id, {String passphrase = kPass}) {
    configStore.config = const SyncConfig(
      url: 'https://example.com/dav/ava/',
      username: 'user',
      deviceName: 'test-device',
    );
    configStore.passphrase = passphrase;
    engine = SyncEngine(
      configStore: configStore,
      accounts: port,
      settings: settingsPort,
      trash: trash,
      transportFactory: (_, _) => InMemoryTransport(server),
      deviceId: () async => id,
    );
  }
}

const kPass = 'correct horse battery staple';
const kSubscription = {
  'v': 1,
  'configured': true,
  'url': 'https://subscription.example.invalid/list?token=fixture-token',
  'selected': 'fixture-node',
  'nodes': '{"proxies":[{"name":"Fixture","type":"ss",'
      '"server":"node.example.invalid","port":443,'
      '"cipher":"aes-128-gcm","password":"fixture-node-secret"}]}',
};

SteamGuardAccount account(int steamId,
        {String name = 'gaben', String password = 'pw123'}) =>
    SteamGuardAccount.fromJson({
      'shared_secret': 'c2VjcmV0',
      'identity_secret': 'aWRlbnRpdHk=',
      'account_name': name,
      'password': password,
      'Session': {
        'SteamID': steamId,
        'AccessToken': 'localToken',
        'RefreshToken': 'localRefresh',
      },
    });

void main() {
  const id1 = 76561198000000001;
  const id2 = 76561198000000002;

  test('first device pushes an SDA-readable encrypted folder', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.addAll([account(id1), account(id2, name: 'alt')]);

    await a.engine.syncNow();

    expect(a.engine.status.hasError, isFalse);
    expect(a.engine.status.lastPushed, 2);

    // The sidecar and the SDA manifest both exist and agree.
    final sidecar = SyncSidecar.parse(
        utf8.decode(server.files[kSyncSidecarFilename]!.$1));
    expect(sidecar.accounts, hasLength(2));
    final manifest = jsonDecode(
            utf8.decode(server.files[kSyncManifestFilename]!.$1))
        as Map<String, dynamic>;
    expect(manifest['encrypted'], isTrue);
    expect(manifest['entries'], hasLength(2));

    // Each referenced file decrypts with the passphrase, carries the
    // password, and carries no session tokens.
    for (final entry in sidecar.accounts.values) {
      final payload = decryptSyncPayload(kPass, entry.salt, entry.iv,
          utf8.decode(server.files[entry.filename]!.$1));
      expect(payload, isNotNull);
      expect(payload!['password'], 'pw123');
      final session = payload['Session'] as Map<String, dynamic>;
      expect(session.containsKey('RefreshToken'), isFalse);
    }
  });

  test('second device pulls everything and keeps identities', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();

    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    expect(b.engine.status.lastPulled, 1);
    final got = b.port.accounts.single;
    expect(got.steamId, id1);
    expect(got.password, 'pw123');
    expect(got.session.hasTokens, isFalse);
  });

  test('an edit propagates A → B; a session refresh does not', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    // Session-only change: nothing to sync.
    a.port.accounts.single.session.accessToken = 'rotated';
    await a.engine.syncNow();
    expect(a.engine.status.lastPushed, 0);

    // Real change: propagates.
    a.port.accounts.single.password = 'newpass';
    await a.engine.syncNow();
    expect(a.engine.status.lastPushed, 1);
    await b.engine.syncNow();
    expect(b.port.accounts.single.password, 'newpass');
  });

  test('a delete propagates as a tombstone and lands in the trash',
      () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.addAll([account(id1), account(id2, name: 'alt')]);
    await a.engine.syncNow();
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    // B deletes one account.
    b.port.accounts.removeWhere((x) => x.steamId == id2);
    await b.engine.syncNow();

    // A applies the tombstone: account gone, trash copy kept.
    await a.engine.syncNow();
    expect(a.port.accounts.map((x) => x.steamId), [id1]);
    expect(a.trash.entries.single.steamId, id2);
    expect(a.trash.entries.single.reason, SyncTrashReason.remoteDelete);

    // And it does NOT bounce back on B's next round.
    await b.engine.syncNow();
    expect(b.port.accounts.map((x) => x.steamId), [id1]);
  });

  test('a failed trash write refuses the local delete', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    b.port.accounts.clear();
    await b.engine.syncNow();

    a.trash.failPuts = true;
    await a.engine.syncNow();
    // The delete was refused; the account is still here.
    expect(a.port.accounts, hasLength(1));

    // Once the trash works again the delete goes through.
    a.trash.failPuts = false;
    await a.engine.syncNow();
    expect(a.port.accounts, isEmpty);
  });

  test('divergent edits conflict; keep-local wins outward and the loser '
      'is trashed', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    a.port.accounts.single.password = 'versionA';
    await a.engine.syncNow();
    b.port.accounts.single.password = 'versionB';
    await b.engine.syncNow();

    final conflict = b.engine.status.conflicts.single;
    expect(conflict.steamId, id1);
    // Both sides are in hand for the compare UI.
    expect(conflict.localPayload?['password'], 'versionB');
    expect(conflict.remotePayload?['password'], 'versionA');

    await b.engine.resolveConflict(id1, keepLocal: true);
    expect(b.engine.status.conflicts, isEmpty);
    expect(b.trash.entries.single.reason, SyncTrashReason.conflictRemote);

    await a.engine.syncNow();
    expect(a.port.accounts.single.password, 'versionB');
  });

  test('keep-remote applies the other side and trashes the local copy',
      () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    a.port.accounts.single.password = 'versionA';
    await a.engine.syncNow();
    b.port.accounts.single.password = 'versionB';
    await b.engine.syncNow();

    await b.engine.resolveConflict(id1, keepLocal: false);
    expect(b.port.accounts.single.password, 'versionA');
    expect(b.trash.entries.single.reason, SyncTrashReason.conflictLocal);
  });

  test('a lost commit race re-merges instead of overwriting', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();

    final b = Device(server, 'devB0002');
    await b.engine.syncNow();

    // A stages a change. Mid-push — right before A commits its sidecar —
    // another device commits a new account, so A's If-Match fails.
    a.port.accounts.single.password = 'racer';
    // The competing device's payload really exists on the server, exactly
    // as a real committer would have left it (file first, sidecar last).
    final otherPayload =
        syncPayloadJson(account(id2, name: 'alt'), includePassword: true);
    final otherEnc = encryptSyncPayload(kPass, otherPayload);
    server.files['$id2.r1.devC.maFile'] = (
      Uint8List.fromList(utf8.encode(otherEnc.ciphertext)),
      'eX',
    );
    var injected = false;
    server.onPut = (name) {
      if (name == kSyncSidecarFilename && !injected) {
        injected = true;
        server.onPut = null;
        final current = SyncSidecar.parse(
            utf8.decode(server.files[kSyncSidecarFilename]!.$1));
        final updated = current.copyWith(accounts: {
          ...current.accounts,
          id2: SyncRemoteAccount(
            rev: 1,
            hash: payloadHash(otherPayload),
            filename: '$id2.r1.devC.maFile',
            salt: otherEnc.salt,
            iv: otherEnc.iv,
          ),
        });
        server.files[kSyncSidecarFilename] = (
          Uint8List.fromList(utf8.encode(updated.serialize())),
          'e${++server.etagSeq}',
        );
      }
    };

    await a.engine.syncNow();
    expect(a.engine.status.hasError, isFalse);

    // A's change landed AND B's competing entry survived.
    final sidecar = SyncSidecar.parse(
        utf8.decode(server.files[kSyncSidecarFilename]!.$1));
    expect(sidecar.accounts.keys, containsAll([id1, id2]));
  });

  test('a 412 against an untouched sidecar is reported, not retried',
      () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    final before = server.files[kSyncSidecarFilename];

    server.rejectIfMatch = true;
    var commits = 0;
    server.onPut = (name) {
      if (name == kSyncSidecarFilename) commits++;
    };
    a.port.accounts.single.password = 'changed';
    await a.engine.syncNow();

    // One retry shows nobody else committed; no blind retries after that.
    expect(commits, 2);
    expect(a.engine.status.errorKind, SyncErrorKind.server);
    expect(a.engine.status.errorDetail, contains('although nobody changed'));
    expect(server.files[kSyncSidecarFilename], same(before));
  });

  test('wrong passphrase is reported as a passphrase problem, not '
      'corruption', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();

    final b = Device(server, 'devB0002', passphrase: 'totally wrong one');
    await b.engine.syncNow();
    expect(b.engine.status.needsPassphrase, isTrue);
    expect(b.engine.status.errorKind, SyncErrorKind.passphrase);
    expect(b.port.accounts, isEmpty);

    // providePassphrase with the right one heals it.
    expect(await b.engine.providePassphrase(kPass), isTrue);
    await b.engine.syncNow();
    expect(b.port.accounts, hasLength(1));
  });

  test('turning password sync off strips passwords from the remote',
      () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();

    await a.engine.setSyncPasswords(false);

    final sidecar = SyncSidecar.parse(
        utf8.decode(server.files[kSyncSidecarFilename]!.$1));
    expect(sidecar.includePasswords, isFalse);
    final entry = sidecar.accounts[id1]!;
    final payload = decryptSyncPayload(kPass, entry.salt, entry.iv,
        utf8.decode(server.files[entry.filename]!.$1));
    expect(payload!.containsKey('password'), isFalse);

    // The other device adopts the flag instead of fighting it.
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();
    expect(b.configStore.config!.syncPasswords, isFalse);
  });

  test('changing the passphrase re-encrypts and locks out the old one',
      () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();

    const newPass = 'an entirely new passphrase';
    expect(await a.engine.changePassphrase(newPass), isNull);

    final sidecar = SyncSidecar.parse(
        utf8.decode(server.files[kSyncSidecarFilename]!.$1));
    expect(sidecar.passphraseEpoch, 2);
    expect(verifyPasskeyCheck(newPass, sidecar.passkeyCheck), isTrue);
    expect(verifyPasskeyCheck(kPass, sidecar.passkeyCheck), isFalse);

    // A device still holding the old passphrase is asked for the new one.
    final b = Device(server, 'devB0002');
    await b.engine.syncNow();
    expect(b.engine.status.needsPassphrase, isTrue);
  });

  test('a locked device does nothing', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.locked = true;
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    expect(server.files, isEmpty);
  });

  test('disconnect with deleteRemote clears the server', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    expect(server.files, isNotEmpty);

    await a.engine.disconnect(deleteRemote: true);
    expect(server.files, isEmpty);
    expect(a.configStore.config, isNull);
    // The local account itself is untouched — disconnect is about sync,
    // never about the library.
    expect(a.port.accounts, hasLength(1));
  });

  group('app-settings sync', () {
    Map<String, dynamic> remoteSettings(InMemoryServer server,
        {String passphrase = kPass}) {
      final sidecar = SyncSidecar.parse(
          utf8.decode(server.files[kSyncSidecarFilename]!.$1));
      final entry = sidecar.settings!;
      return decryptSyncPayload(passphrase, entry.salt, entry.iv,
          utf8.decode(server.files[entry.filename]!.$1))!;
    }

    test('rotation preserves remote settings while their sync is disabled',
        () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      a.settingsPort.values['steam_acceleration'] = kSubscription;
      await a.engine.syncNow();
      final b = Device(server, 'devB0002');
      await b.engine.syncNow();
      await a.engine.setSyncSettings(false);
      a.settingsPort.values['skin'] = 'pixel';
      a.settingsPort.values['steam_acceleration'] = {
        'v': 1, 'configured': false,
      };
      b.settingsPort.values['skin'] = 'neon';
      await b.engine.syncNow();
      final remoteBefore = remoteSettings(server);
      final localBefore = Map.of(a.settingsPort.values);
      final baseBefore = a.configStore.state.toJson();
      final applies = a.settingsPort.applies;

      const newPass = 'disabled settings replacement passphrase';
      expect(await a.engine.changePassphrase(newPass), isNull);
      expect(remoteSettings(server, passphrase: newPass), remoteBefore);
      expect(a.settingsPort.values, localBefore);
      expect(a.settingsPort.applies, applies);
      expect(a.configStore.state.toJson(), baseBefore);
      expect(a.configStore.config!.syncSettings, isFalse);
      expect(a.configStore.previousPassphrase, isNull);
      final sidecar = SyncSidecar.parse(
          utf8.decode(server.files[kSyncSidecarFilename]!.$1));
      final entry = sidecar.settings!;
      expect(sidecar.passphraseEpoch, 2);
      expect(decryptSyncPayload(kPass, entry.salt, entry.iv,
          utf8.decode(server.files[entry.filename]!.$1)), isNull);
    });

    test('rotation failure retains the recovery key and resumes after restart',
        () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      a.settingsPort.values['steam_acceleration'] = kSubscription;
      await a.engine.syncNow();
      await a.engine.setSyncSettings(false);
      final remoteBefore = server.files[kSyncSidecarFilename];
      final sidecar = SyncSidecar.parse(utf8.decode(remoteBefore!.$1));
      final filename = sidecar.settings!.filename;
      final intact = server.files[filename]!;
      server.files[filename] = (
        Uint8List.fromList(utf8.encode('corrupt ciphertext')), intact.$2,
      );
      const newPass = 'resume this pending passphrase';
      expect(await a.engine.changePassphrase(newPass), isNotNull);
      expect(server.files[kSyncSidecarFilename], same(remoteBefore));
      expect(a.configStore.previousPassphrase, kPass);
      expect(a.configStore.config!.forcePushPending, isTrue);
      expect(await a.engine.changePassphrase('must not replace the old key'),
          'passphrase change pending');
      expect(a.configStore.previousPassphrase, kPass);
      expect(a.configStore.passphrase, newPass);

      server.files[filename] = intact;
      a.engine.dispose();
      final restarted = SyncEngine(configStore: a.configStore,
          accounts: a.port, settings: a.settingsPort, trash: a.trash,
          transportFactory: (_, _) => InMemoryTransport(server),
          deviceId: () async => 'devA0001');
      addTearDown(restarted.dispose);
      await restarted.syncNow();
      expect(restarted.status.hasError, isFalse);
      expect(remoteSettings(server, passphrase: newPass)['steam_acceleration'],
          kSubscription);
      expect(a.configStore.previousPassphrase, isNull);
      expect(a.configStore.config!.forcePushPending, isFalse);
    });

    test('rotation 412 retry rekeys concurrently edited and new remote accounts',
        () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      a.port.accounts.add(account(id1));
      a.settingsPort.values['steam_acceleration'] = kSubscription;
      await a.engine.syncNow();
      await a.engine.setSyncSettings(false);
      var injected = false;
      server.onPut = (name) {
        if (name != kSyncSidecarFilename || injected ||
            !a.configStore.config!.forcePushPending) {
          return;
        }
        injected = true;
        final remote = SyncSidecar.parse(
            utf8.decode(server.files[kSyncSidecarFilename]!.$1));
        SyncRemoteAccount seed(int id, int revision, String password) {
          final payload = syncPayloadJson(account(id, password: password),
              includePassword: true);
          final enc = encryptSyncPayload(kPass, payload);
          final filename = '$id.r$revision.racer.maFile';
          server.files[filename] = (
            Uint8List.fromList(utf8.encode(enc.ciphertext)),
            'e${++server.etagSeq}',
          );
          return SyncRemoteAccount(rev: revision, hash: payloadHash(payload),
              filename: filename, salt: enc.salt, iv: enc.iv);
        }
        final changed = remote.copyWith(accounts: {
          ...remote.accounts,
          id1: seed(id1, remote.accounts[id1]!.rev + 1, 'concurrent-edit'),
          id2: seed(id2, 1, 'concurrent-new'),
        });
        server.files[kSyncSidecarFilename] = (
          Uint8List.fromList(utf8.encode(changed.serialize())),
          'e${++server.etagSeq}',
        );
      };
      const newPass = 'raced rotation replacement passphrase';
      expect(await a.engine.changePassphrase(newPass), isNull);
      expect(injected, isTrue);
      final finalRemote = SyncSidecar.parse(
          utf8.decode(server.files[kSyncSidecarFilename]!.$1));
      expect(finalRemote.passphraseEpoch, 2);
      for (final entry in finalRemote.accounts.entries) {
        final metadata = entry.value;
        final ciphertext = utf8.decode(server.files[metadata.filename]!.$1);
        final payload = decryptSyncPayload(newPass, metadata.salt,
            metadata.iv, ciphertext)!;
        expect(payload['password'],
            entry.key == id1 ? 'concurrent-edit' : 'concurrent-new');
        expect(decryptSyncPayload(kPass, metadata.salt,
            metadata.iv, ciphertext), isNull);
      }
      expect(remoteSettings(server, passphrase: newPass)['steam_acceleration'],
          kSubscription);
      expect(a.configStore.previousPassphrase, isNull);
      // Normal merging follows the rotation; concurrently changed plaintext
      // was not falsely marked as already imported on this device.
      await a.engine.syncNow();
      expect(a.port.accounts, hasLength(2));
      expect(a.port.accounts.firstWhere((acc) => acc.steamId == id1).password,
          'concurrent-edit');
    });

    test('rotation keeps the recovery key until local commit state is saved',
        () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      a.settingsPort.values['steam_acceleration'] = kSubscription;
      await a.engine.syncNow();
      await a.engine.setSyncSettings(false);
      server.onPut = (name) {
        if (name == kSyncSidecarFilename &&
            a.configStore.config!.forcePushPending) {
          a.configStore.failNextStateSave = true;
          server.onPut = null;
        }
      };
      const newPass = 'local commit replacement passphrase';
      expect(await a.engine.changePassphrase(newPass), isNotNull);
      expect(a.configStore.previousPassphrase, kPass);
      expect(a.configStore.config!.forcePushPending, isTrue);
      expect(remoteSettings(server, passphrase: newPass)['steam_acceleration'],
          kSubscription);
      await a.engine.syncNow();
      expect(a.engine.status.hasError, isFalse);
      expect(a.configStore.previousPassphrase, isNull);
      expect(a.configStore.config!.forcePushPending, isFalse);
    });

    test('rotation setup failures preserve the current and recovery keys',
        () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      await a.engine.syncNow();
      final remoteBefore = server.files[kSyncSidecarFilename];
      a.configStore.failSavePrevious = true;
      await expectLater(a.engine.changePassphrase('not stored'),
          throwsStateError);
      expect(a.configStore.passphrase, kPass);
      expect(a.configStore.previousPassphrase, isNull);
      expect(a.configStore.config!.passphraseEpoch, 1);

      a.configStore.failSavePrevious = false;
      a.configStore.failNextConfigSave = true;
      await expectLater(a.engine.changePassphrase('rolled back'),
          throwsStateError);
      expect(a.configStore.passphrase, kPass);
      expect(a.configStore.previousPassphrase, kPass);
      expect(a.configStore.config!.forcePushPending, isFalse);
      expect(server.files[kSyncSidecarFilename], same(remoteBefore));
      await a.engine.syncNow();
      expect(a.engine.status.hasError, isFalse);
      expect(a.configStore.previousPassphrase, isNull);
    });

    test('rotation recovery key is never used for an ordinary wrong-key pull',
        () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      await a.engine.syncNow();
      final b = Device(server, 'devB0002', passphrase: 'wrong current key');
      b.configStore.previousPassphrase = kPass;
      await b.engine.syncNow();
      expect(b.engine.status.needsPassphrase, isTrue);
      expect(b.configStore.previousPassphrase, kPass);
      expect(b.settingsPort.applies, 0);
    });

    test('local settings hash is persisted separately and older state migrates',
        () {
      final legacy = SyncLocalState.fromJson({
        'settings_base': {'rev': 7, 'hash': 'remote-hash'},
      });
      expect(legacy.settingsBase!.hash, 'remote-hash');
      expect(legacy.settingsLocalHash, isNull);
      final current = SyncLocalState(
        settingsBase: legacy.settingsBase,
        settingsLocalHash: 'local-projection-hash',
      );
      final restored = SyncLocalState.fromJson(current.toJson());
      expect(restored.settingsBase!.hash, 'remote-hash');
      expect(restored.settingsLocalHash, 'local-projection-hash');
      expect(current.toJson().keys,
          unorderedEquals(['base', 'tombstones_seen', 'settings_base',
            'settings_local_hash']));
    });

    test('first pull retains newer local fields without repeated upload',
        () async {
      final server = InMemoryServer();
      final old = Device(server, 'old00001');
      await old.engine.syncNow();
      final newer = Device(server, 'new00001');
      newer.settingsPort.values['steam_acceleration'] = kSubscription;
      await newer.engine.syncNow();

      expect(newer.settingsPort.values['steam_acceleration'], kSubscription);
      final base = newer.configStore.state;
      expect(base.settingsLocalHash,
          payloadHash(newer.settingsPort.values));
      expect(base.settingsLocalHash, isNot(base.settingsBase!.hash));
      final writes = server.etagSeq;
      await newer.engine.syncNow();
      await old.engine.syncNow();
      await newer.engine.syncNow();
      expect(server.etagSeq, writes);

      // A real subsequent user edit still propagates the full current document.
      newer.settingsPort.values['skin'] = 'neon';
      await newer.engine.syncNow();
      expect(remoteSettings(server)['skin'], 'neon');
      expect(remoteSettings(server)['steam_acceleration'], kSubscription);
      expect(newer.configStore.state.settingsLocalHash,
          newer.configStore.state.settingsBase!.hash);
    });

    test('older writer stripping newer fields does not cause an upload loop',
        () async {
      final server = InMemoryServer();
      final newer = Device(server, 'new00001');
      newer.settingsPort.values['steam_acceleration'] = kSubscription;
      await newer.engine.syncNow();
      final old = Device(server, 'old00001');
      await old.engine.syncNow();
      // An older app publishes only the settings keys it understands.
      old.settingsPort.values.remove('steam_acceleration');
      old.settingsPort.values['hold_confirm'] = false;
      await old.engine.syncNow();
      await newer.engine.syncNow();
      expect(newer.settingsPort.values['steam_acceleration'], kSubscription);
      expect(newer.settingsPort.values['hold_confirm'], isFalse);
      expect(newer.configStore.state.settingsLocalHash,
          isNot(newer.configStore.state.settingsBase!.hash));
      final writes = server.etagSeq;
      for (var i = 0; i < 3; i++) {
        await newer.engine.syncNow();
        await old.engine.syncNow();
      }
      expect(server.etagSeq, writes);
      newer.settingsPort.values['steam_acceleration'] = {
        ...kSubscription,
        'selected': 'another-node',
      };
      await newer.engine.syncNow();
      expect(remoteSettings(server)['steam_acceleration']['selected'],
          'another-node');
    });

    test('a failed secure settings import does not advance either baseline',
        () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      await a.engine.syncNow();
      final b = Device(server, 'devB0002');
      await b.engine.syncNow();
      final before = b.configStore.state.toJson();
      a.settingsPort.values['steam_acceleration'] = kSubscription;
      await a.engine.syncNow();
      b.settingsPort.failApply = true;
      await b.engine.syncNow();
      expect(b.engine.status.hasError, isTrue);
      expect(b.configStore.state.toJson(), before);
      expect(b.settingsPort.values.containsKey('steam_acceleration'), isFalse);

      b.settingsPort.failApply = false;
      await b.engine.syncNow();
      expect(b.engine.status.hasError, isFalse);
      expect(b.settingsPort.values['steam_acceleration'], kSubscription);
      expect(b.configStore.state.settingsLocalHash,
          b.configStore.state.settingsBase!.hash);
    });

    test('subscription settings are encrypted, optional and rekeyed', () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      a.settingsPort.values['steam_acceleration'] = kSubscription;
      await a.engine.syncNow();
      final b = Device(server, 'devB0002');
      await b.engine.syncNow();
      expect(b.settingsPort.values['steam_acceleration'], kSubscription);
      for (final file in server.files.values) {
        final text = utf8.decode(file.$1);
        expect(text, isNot(contains('fixture-token')));
        expect(text, isNot(contains('fixture-node-secret')));
        expect(text, isNot(contains('subscription.example.invalid')));
      }
      await a.engine.setSyncSettings(false);
      a.settingsPort.values['steam_acceleration'] = {
        'v': 1, 'configured': false,
      };
      await a.engine.syncNow();
      await b.engine.syncNow();
      expect(b.settingsPort.values['steam_acceleration'], kSubscription);
      await a.engine.setSyncSettings(true);
      await b.engine.syncNow();
      expect(b.settingsPort.values['steam_acceleration'],
          {'v': 1, 'configured': false});

      a.settingsPort.values['steam_acceleration'] = kSubscription;
      await a.engine.syncNow();
      const newPass = 'replacement synchronization passphrase';
      expect(await a.engine.changePassphrase(newPass), isNull);
      final sidecar = SyncSidecar.parse(
          utf8.decode(server.files[kSyncSidecarFilename]!.$1));
      final entry = sidecar.settings!;
      final ciphertext = utf8.decode(server.files[entry.filename]!.$1);
      expect(decryptSyncPayload(kPass, entry.salt, entry.iv, ciphertext), isNull);
      expect(remoteSettings(server, passphrase: newPass)['steam_acceleration'],
          kSubscription);
      expect(a.configStore.state.settingsLocalHash,
          a.configStore.state.settingsBase!.hash);
    });

    test('account conflict resolution retains both settings baselines',
        () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      a.port.accounts.add(account(id1));
      await a.engine.syncNow();
      final b = Device(server, 'devB0002');
      b.settingsPort.values['steam_acceleration'] = kSubscription;
      await b.engine.syncNow();
      await b.engine.setSyncSettings(false);
      final base = b.configStore.state.settingsBase;
      final localHash = b.configStore.state.settingsLocalHash;
      a.port.accounts.single.password = 'remote-edit';
      await a.engine.syncNow();
      b.port.accounts.single.password = 'local-edit';
      await b.engine.syncNow();
      expect(b.engine.status.conflicts, hasLength(1));
      await b.engine.resolveConflict(id1, keepLocal: true);
      expect(b.configStore.state.settingsBase!.toJson(), base!.toJson());
      expect(b.configStore.state.settingsLocalHash, localHash);
      expect(localHash, isNot(base.hash));
    });

    test('a settings change propagates A → B with an older local state',
        () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      a.port.accounts.add(account(id1));
      await a.engine.syncNow();
      final b = Device(server, 'devB0002');
      await b.engine.syncNow();
      // State saved by the previous app version has only the remote hash.
      b.configStore.state = SyncLocalState.fromJson(
          b.configStore.state.toJson()..remove('settings_local_hash'));

      a.settingsPort.values['skin'] = 'neon';
      await a.engine.syncNow();
      await b.engine.syncNow();
      expect(b.settingsPort.values['skin'], 'neon');
    });

    test('a brand-new device ADOPTS the remote document instead of '
        'clobbering it with defaults', () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      a.port.accounts.add(account(id1));
      a.settingsPort.values['skin'] = 'pixel';
      await a.engine.syncNow();

      final c = Device(server, 'devC0003'); // fresh defaults
      await c.engine.syncNow();
      expect(c.settingsPort.values['skin'], 'pixel');

      // And A's next round sees nothing to change.
      await a.engine.syncNow();
      final sidecar = SyncSidecar.parse(
          utf8.decode(server.files[kSyncSidecarFilename]!.$1));
      final entry = sidecar.settings!;
      final doc = decryptSyncPayload(kPass, entry.salt, entry.iv,
          utf8.decode(server.files[entry.filename]!.$1));
      expect(doc!['skin'], 'pixel');
    });

    test('both-changed resolves by last writer, whole document', () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      a.port.accounts.add(account(id1));
      await a.engine.syncNow();
      final b = Device(server, 'devB0002');
      await b.engine.syncNow();

      a.settingsPort.values['skin'] = 'neon';
      await a.engine.syncNow();
      b.settingsPort.values['hold_confirm'] = false;
      await b.engine.syncNow(); // B is the later writer: its document wins

      await a.engine.syncNow();
      expect(a.settingsPort.values['hold_confirm'], false);
      // Whole-document LWW: B's document still carried the old skin.
      expect(a.settingsPort.values['skin'], 'none');
    });

    test('the toggle stops settings from syncing, accounts unaffected',
        () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      a.port.accounts.add(account(id1));
      await a.engine.syncNow();
      final b = Device(server, 'devB0002');
      await b.engine.syncNow();

      await a.engine.setSyncSettings(false);
      a.settingsPort.values['skin'] = 'neon';
      a.port.accounts.single.password = 'stillsyncs';
      await a.engine.syncNow();
      await b.engine.syncNow();

      expect(b.settingsPort.values['skin'], 'none');
      expect(b.port.accounts.single.password, 'stillsyncs');
    });

    test('superseded settings files are garbage-collected', () async {
      final server = InMemoryServer();
      final a = Device(server, 'devA0001');
      a.port.accounts.add(account(id1));
      await a.engine.syncNow();
      a.settingsPort.values['skin'] = 'neon';
      await a.engine.syncNow();
      final settingsFiles = server.files.keys
          .where((k) => k.startsWith('ava.settings.'))
          .toList();
      expect(settingsFiles, hasLength(1));
    });
  });

  test('garbage collection removes superseded payload files', () async {
    final server = InMemoryServer();
    final a = Device(server, 'devA0001');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    final firstFiles =
        server.files.keys.where((k) => k.endsWith('.maFile')).toList();

    a.port.accounts.single.password = 'changed';
    await a.engine.syncNow();
    final secondFiles =
        server.files.keys.where((k) => k.endsWith('.maFile')).toList();

    expect(secondFiles, hasLength(1));
    expect(secondFiles.single, isNot(firstFiles.single));
  });
}
