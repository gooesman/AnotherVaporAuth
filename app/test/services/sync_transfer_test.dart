import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/src/core/sync/sync_payload.dart';
import 'package:ava/src/services/sync/sync_config_store.dart';
import 'package:ava/src/services/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_engine_test.dart' as fixture;

const accountOne = 76561198000000001;
const accountTwo = 76561198000000002;
const accountsOnly = SyncSelection(
  settings: false,
  favorites: false,
  acceleration: false,
);
const favoritesOnly = SyncSelection(
  accounts: false,
  settings: false,
  acceleration: false,
);
const settingsOnly = SyncSelection(
  accounts: false,
  favorites: false,
  acceleration: false,
);
const nothing = SyncSelection(
  accounts: false,
  settings: false,
  favorites: false,
  acceleration: false,
);

Map<String, dynamic> favorites(List<String> names, {int currency = 23}) => {
  'currency': currency,
  'items': [
    for (final name in names)
      {
        'appid': 730,
        'market_hash_name': name,
        'name': name,
        'icon_url': '',
        'type': '',
        'rarity_color': '',
      },
  ],
};

SyncSidecar sidecar(fixture.InMemoryServer server) =>
    SyncSidecar.parse(utf8.decode(server.files[kSyncSidecarFilename]!.$1));

Map<String, dynamic> read(
  fixture.InMemoryServer server,
  SyncRemoteAccount entry, {
  String phrase = fixture.kPass,
}) => decryptSyncPayload(
  phrase,
  entry.salt,
  entry.iv,
  utf8.decode(server.files[entry.filename]!.$1),
)!;

void resetTraffic(fixture.InMemoryServer server) {
  server.gets.clear();
  server.puts.clear();
  server.deletes.clear();
}

fixture.Device device(fixture.InMemoryServer server, String id) {
  final value = fixture.Device(
    server,
    id,
    debounce: const Duration(milliseconds: 1),
  );
  addTearDown(value.engine.dispose);
  return value;
}

Future<void> automatic(SyncEngine engine) async {
  await engine.start();
  final before = engine.status.lastSyncAt;
  final done = engine.statusStream.firstWhere(
    (status) =>
        !status.syncing && (status.lastSyncAt != before || status.hasError),
  );
  engine.notifyAccountsChanged();
  await done.timeout(const Duration(seconds: 15));
}

void main() {
  test(
    'old configuration migrates selections independently and keeps disabled settings',
    () {
      final config = SyncConfig.fromJson({
        'url': 'https://example.invalid',
        'username': 'fixture',
        'device_name': 'fixture',
        'sync_settings': false,
      });
      expect(config.uploadSelection.accounts, isTrue);
      expect(config.uploadSelection.anySettings, isFalse);
      expect(config.pullSelection.anySettings, isFalse);
      final edited = config.copyWith(uploadSelection: favoritesOnly);
      final saved = SyncConfig.fromJson(edited.toJson());
      expect(saved.uploadSelection.toJson(), favoritesOnly.toJson());
      expect(saved.pullSelection.toJson(), config.pullSelection.toJson());
    },
  );

  test(
    'selection and password setters save without any network request',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      await a.engine.setUploadSelection(favoritesOnly);
      await a.engine.setPullSelection(accountsOnly);
      await a.engine.setSyncPasswords(false);
      await a.engine.setSyncSettings(true);
      expect(server.gets, isEmpty);
      expect(server.puts, isEmpty);
      expect(a.configStore.config!.forcePushPending, isTrue);
    },
  );

  test(
    'syncNow uploads once and does not pull or erase remote-only accounts',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      final b = device(server, 'b');
      a.port.accounts.add(fixture.account(accountOne));
      b.port.accounts.add(fixture.account(accountTwo));
      await a.engine.setUploadSelection(accountsOnly);
      await b.engine.setUploadSelection(accountsOnly);
      await a.engine.uploadNow();
      resetTraffic(server);
      await b.engine.syncNow();
      expect(b.port.accounts.map((a) => a.steamId), [accountTwo]);
      expect(
        sidecar(server).accounts.keys,
        containsAll([accountOne, accountTwo]),
      );
      expect(
        server.puts.where((name) => name == kSyncSidecarFilename).length,
        1,
      );
      expect(b.engine.status.lastPulled, 0);
    },
  );

  test(
    'favorites-only upload preserves other encrypted settings and unknown fields',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.settingsPort.values.addAll({
        'skin': 'remote',
        'market_favorites': favorites(['remote']),
        'steam_acceleration': fixture.kSubscription,
      });
      await a.engine.uploadNow();
      final b = device(server, 'b');
      b.settingsPort.values['market_favorites'] = favorites(['local']);
      b.settingsPort.values['steam_acceleration'] = {'configured': false};
      await b.engine.setUploadSelection(favoritesOnly);
      await b.engine.uploadNow();
      final result = read(server, sidecar(server).settings!);
      expect(result['skin'], 'remote');
      expect(result['steam_acceleration'], fixture.kSubscription);
      expect(result['market_favorites'], favorites(['local']));
      expect(b.settingsPort.values['skin'], 'none');
      expect(b.engine.status.lastPushed, 1);
    },
  );

  test(
    'pull is remote-read-only and merges local-only accounts and favorites',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.port.accounts.add(fixture.account(accountOne));
      a.settingsPort.values['market_favorites'] = favorites([
        'shared',
        'remote',
      ], currency: 1);
      await a.engine.uploadNow();
      final b = device(server, 'b');
      b.port.accounts.add(fixture.account(accountTwo));
      b.settingsPort.values['market_favorites'] = favorites([
        'shared',
        'local',
      ]);
      await b.engine.setPullSelection(
        const SyncSelection(settings: false, acceleration: false),
      );
      resetTraffic(server);
      await b.engine.pullNow();
      expect(
        b.port.accounts.map((a) => a.steamId),
        containsAll([accountOne, accountTwo]),
      );
      final saved = b.settingsPort.values['market_favorites'] as Map;
      expect((saved['items'] as List).map((row) => row['market_hash_name']), [
        'shared',
        'local',
        'remote',
      ]);
      expect(saved['currency'], 1);
      expect(server.puts, isEmpty);
      expect(server.deletes, isEmpty);
      expect(
        server.gets
            .where((name) => name == sidecar(server).settings!.filename)
            .length,
        1,
      );
      expect(b.engine.status.lastPulled, 2);
    },
  );

  test(
    'remote imports and merged favorites do not queue an automatic upload',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.settingsPort.values['market_favorites'] = favorites(['remote']);
      await a.engine.uploadNow();
      final b = device(server, 'b');
      b.settingsPort.values['market_favorites'] = favorites(['local']);
      await b.engine.setPullSelection(favoritesOnly);
      await b.engine.start();
      b.settingsPort.onApply = (_) => b.engine.notifyAccountsChanged();
      b.engine
          .notifyAccountsChanged(); // Cancel a pending pre-pull debounce, too.
      resetTraffic(server);
      await b.engine.pullNow();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(server.puts, isEmpty);
      await b.engine.setUploadSelection(favoritesOnly);
      await automatic(b.engine);
      expect(server.puts, isEmpty);
      expect(
        read(server, sidecar(server).settings!)['market_favorites'],
        favorites(['remote']),
      );
    },
  );

  test(
    'automatic upload protects remote changes and only uploads edited categories',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.port.accounts.add(fixture.account(accountOne));
      a.settingsPort.values['market_favorites'] = favorites(['initial']);
      await a.engine.uploadNow();
      final b = device(server, 'b');
      await b.engine.pullNow();
      a.port.accounts[0].accountName = 'remote edit';
      a.settingsPort.values['skin'] = 'remote skin';
      await a.engine.uploadNow();
      b.port.accounts[0].accountName = 'local edit';
      b.settingsPort.values['market_favorites'] = favorites(['new favorite']);
      resetTraffic(server);
      await automatic(b.engine);
      expect(
        read(server, sidecar(server).accounts[accountOne]!)['account_name'],
        'remote edit',
      );
      expect(b.engine.status.conflicts.single.steamId, accountOne);
      final settings = read(server, sidecar(server).settings!);
      expect(settings['skin'], 'remote skin');
      expect(settings['market_favorites'], favorites(['new favorite']));
      await b.engine.setUploadSelection(accountsOnly);
      await b.engine.uploadNow();
      expect(
        read(server, sidecar(server).accounts[accountOne]!)['account_name'],
        'local edit',
      );
    },
  );

  test(
    'automatic first contact does not overwrite an existing remote account or settings',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.port.accounts.add(fixture.account(accountOne, name: 'remote'));
      a.settingsPort.values['skin'] = 'remote';
      await a.engine.uploadNow();
      final b = device(server, 'b');
      b.port.accounts.add(fixture.account(accountOne, name: 'local'));
      resetTraffic(server);
      await automatic(b.engine);
      expect(server.puts, isEmpty);
      expect(b.port.accounts.single.accountName, 'local');
    },
  );

  test(
    'pending password cleanup waits for accounts and strips remote-only passwords',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.port.accounts.addAll([
        fixture.account(accountOne),
        fixture.account(accountTwo),
      ]);
      await a.engine.uploadNow();
      final b = device(server, 'b');
      b.settingsPort.values['market_favorites'] = favorites(['local']);
      await b.engine.setSyncPasswords(false);
      await b.engine.setUploadSelection(favoritesOnly);
      await b.engine.uploadNow();
      expect(sidecar(server).includePasswords, isTrue);
      expect(b.configStore.config!.forcePushPending, isTrue);
      await b.engine.setUploadSelection(accountsOnly);
      await b.engine.uploadNow();
      expect(b.port.accounts, isEmpty);
      expect(sidecar(server).includePasswords, isFalse);
      expect(b.configStore.config!.forcePushPending, isFalse);
      for (final entry in sidecar(server).accounts.values) {
        expect(read(server, entry).containsKey('password'), isFalse);
      }
    },
  );

  test('stale device adopts remote password policy before uploading', () async {
    final server = fixture.InMemoryServer();
    final a = device(server, 'a');
    a.port.accounts.add(fixture.account(accountOne));
    await a.engine.uploadNow();
    await a.engine.setSyncPasswords(false);
    await a.engine.uploadNow();
    final b = device(server, 'b');
    b.port.accounts.add(fixture.account(accountTwo));
    await b.engine.setUploadSelection(accountsOnly);
    await b.engine.uploadNow();
    expect(b.configStore.config!.syncPasswords, isFalse);
    expect(sidecar(server).includePasswords, isFalse);
    expect(
      read(
        server,
        sidecar(server).accounts[accountTwo]!,
      ).containsKey('password'),
      isFalse,
    );
    await a.engine.setSyncPasswords(true);
    await a.engine.uploadNow();
    b.port.accounts[0].accountName = 'edited';
    await b.engine.uploadNow();
    expect(b.configStore.config!.syncPasswords, isTrue);
    expect(
      read(server, sidecar(server).accounts[accountTwo]!)['password'],
      'pw123',
    );
  });

  test('password upload option does not prevent a remote-only pull', () async {
    final server = fixture.InMemoryServer();
    final a = device(server, 'a');
    a.port.accounts.add(fixture.account(accountOne));
    await a.engine.uploadNow();
    final b = device(server, 'b');
    await b.engine.setSyncPasswords(false);
    await b.engine.setPullSelection(accountsOnly);
    resetTraffic(server);
    await b.engine.pullNow();
    expect(b.port.accounts.single.steamId, accountOne);
    expect(b.configStore.config!.syncPasswords, isFalse);
    expect(b.configStore.config!.forcePushPending, isTrue);
    expect(server.puts, isEmpty);
  });

  test(
    'pull refuses an account edited in-place while remote payload downloads',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.port.accounts.add(fixture.account(accountOne, name: 'remote'));
      await a.engine.uploadNow();
      final b = device(server, 'b');
      b.port.accounts.add(fixture.account(accountOne, name: 'old local'));
      await b.engine.setPullSelection(accountsOnly);
      server.onGet = (name) {
        if (name == sidecar(server).accounts[accountOne]!.filename) {
          b.port.accounts.single.accountName = 'new local edit';
        }
      };
      await b.engine.pullNow();
      expect(b.engine.status.hasError, isTrue);
      expect(b.port.accounts.single.accountName, 'new local edit');
      expect(b.engine.status.lastPulled, 0);
    },
  );

  test(
    'partial pull preserves first account and stops before a later concurrent edit',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.port.accounts.addAll([
        fixture.account(accountOne),
        fixture.account(accountTwo),
      ]);
      await a.engine.uploadNow();
      final b = device(server, 'b');
      b.port.accounts.add(fixture.account(accountTwo, name: 'old local'));
      await b.engine.setPullSelection(accountsOnly);
      b.port.onApply = (id) {
        if (id == accountOne) {
          b.port.accounts
                  .firstWhere((a) => a.steamId == accountTwo)
                  .accountName =
              'new local';
        }
      };
      await b.engine.pullNow();
      expect(b.engine.status.hasError, isTrue);
      expect(b.engine.status.lastPulled, 1);
      expect(b.configStore.state.base.keys, contains(accountOne));
      expect(b.configStore.state.base.keys, isNot(contains(accountTwo)));
      expect(
        b.port.accounts.firstWhere((a) => a.steamId == accountTwo).accountName,
        'new local',
      );
    },
  );

  test(
    'edit during upload commit remains dirty for the next automatic upload',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.port.accounts.add(fixture.account(accountOne, name: 'reviewed'));
      await a.engine.setUploadSelection(accountsOnly);
      server.onPut = (name) {
        if (name == kSyncSidecarFilename) {
          a.port.accounts.single.accountName = 'new edit';
        }
      };
      await a.engine.uploadNow();
      expect(
        read(server, sidecar(server).accounts[accountOne]!)['account_name'],
        'reviewed',
      );
      server.onPut = null;
      await automatic(a.engine);
      expect(
        read(server, sidecar(server).accounts[accountOne]!)['account_name'],
        'new edit',
      );
    },
  );

  test('empty selections do not contact the server', () async {
    final server = fixture.InMemoryServer();
    final a = device(server, 'a');
    await a.engine.setUploadSelection(nothing);
    await a.engine.setPullSelection(nothing);
    await a.engine.uploadNow();
    await a.engine.pullNow();
    expect(server.gets, isEmpty);
    expect(server.puts, isEmpty);
  });

  test(
    'malformed favorites report partial completion and keep prior successful settings',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.settingsPort.values['skin'] = 'remote skin';
      a.settingsPort.values['market_favorites'] = null;
      await a.engine.uploadNow();
      final b = device(server, 'b');
      b.settingsPort.values['market_favorites'] = favorites(['local']);
      await b.engine.setPullSelection(
        const SyncSelection(accounts: false, acceleration: false),
      );
      resetTraffic(server);
      await b.engine.pullNow();
      expect(b.engine.status.hasError, isTrue);
      expect(b.engine.status.lastPulled, 1);
      expect(b.settingsPort.values['skin'], 'remote skin');
      expect(b.settingsPort.values['market_favorites'], favorites(['local']));
      expect(b.configStore.state.localContentHashes.keys, contains('settings'));
      expect(
        b.configStore.state.localContentHashes.keys,
        isNot(contains('favorites')),
      );
      expect(server.puts, isEmpty);
    },
  );

  test(
    'unselected account conflicts survive a favorites-only upload',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.port.accounts.add(fixture.account(accountOne));
      await a.engine.uploadNow();
      final b = device(server, 'b');
      await b.engine.pullNow();
      a.port.accounts.single.accountName = 'remote';
      b.port.accounts.single.accountName = 'local';
      await a.engine.uploadNow();
      await automatic(b.engine);
      expect(b.engine.status.conflicts, hasLength(1));
      b.settingsPort.values['market_favorites'] = favorites(['favorite']);
      await b.engine.setUploadSelection(favoritesOnly);
      await b.engine.uploadNow();
      expect(b.engine.status.conflicts, hasLength(1));
    },
  );

  test(
    'a conditional retry preserves concurrent edits to an unselected category',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.settingsPort.values['market_favorites'] = favorites(['initial']);
      await a.engine.uploadNow();
      final b = device(server, 'b');
      b.settingsPort.values['market_favorites'] = favorites(['new']);
      await b.engine.setUploadSelection(favoritesOnly);
      var raced = false;
      server.onPut = (name) {
        if (raced || name != kSyncSidecarFilename) return;
        raced = true;
        final previous = sidecar(server);
        final settings = read(server, previous.settings!)
          ..['skin'] = 'concurrent skin';
        final encrypted = encryptSyncPayload(fixture.kPass, settings);
        const filename = 'fixture.concurrent.json';
        server.files[filename] = (
          Uint8List.fromList(utf8.encode(encrypted.ciphertext)),
          'e${++server.etagSeq}',
        );
        final entry = SyncRemoteAccount(
          rev: previous.settings!.rev + 1,
          hash: payloadHash(settings),
          filename: filename,
          salt: encrypted.salt,
          iv: encrypted.iv,
        );
        server.files[kSyncSidecarFilename] = (
          Uint8List.fromList(
            utf8.encode(previous.copyWith(settings: entry).serialize()),
          ),
          'e${++server.etagSeq}',
        );
      };
      await b.engine.uploadNow();
      expect(b.engine.status.hasError, isFalse);
      expect(raced, isTrue);
      final result = read(server, sidecar(server).settings!);
      expect(result['skin'], 'concurrent skin');
      expect(result['market_favorites'], favorites(['new']));
    },
  );

  test(
    'failed local recovery backup refuses overwrite and sends no remote writes',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.port.accounts.add(fixture.account(accountOne, name: 'remote'));
      await a.engine.uploadNow();
      final b = device(server, 'b');
      b.port.accounts.add(fixture.account(accountOne, name: 'local'));
      await b.engine.setPullSelection(accountsOnly);
      b.trash.failPuts = true;
      resetTraffic(server);
      await b.engine.pullNow();
      expect(b.engine.status.hasError, isTrue);
      expect(b.port.accounts.single.accountName, 'local');
      expect(b.configStore.state.base, isEmpty);
      expect(server.puts, isEmpty);
    },
  );

  test('pending password policy permits comparison and pull but blocks comparison upload', () async {
    final server = fixture.InMemoryServer();
    final a = device(server, 'a');
    a.port.accounts.add(fixture.account(accountOne));
    await a.engine.uploadNow();
    final b = device(server, 'b');
    await b.engine.setUploadSelection(favoritesOnly);
    await b.engine.setSyncPasswords(false);
    resetTraffic(server);
    final preview = await b.engine.compareWithRemote();
    expect(preview.uploadBlockedByPasswordChange, isTrue);
    final account = preview.items.firstWhere((item) => item.steamId == accountOne);
    await b.engine.applyComparison(preview, account, upload: false);
    expect(b.port.accounts.single.steamId, accountOne);
    expect(b.configStore.config!.forcePushPending, isTrue);
    final next = await b.engine.compareWithRemote();
    final changed = next.items.firstWhere((item) => item.steamId == accountOne);
    expect(changed.canUpload, isTrue);
    await expectLater(b.engine.applyComparison(next, changed, upload: true), throwsStateError);
    expect(server.puts, isEmpty);
    expect(server.deletes, isEmpty);
    b.configStore.previousPassphrase = 'previous rotation phrase';
    await expectLater(b.engine.compareWithRemote(), throwsStateError);
  });

  test(
    'rotation preserves remote plaintext without merging remote content locally',
    () async {
      final server = fixture.InMemoryServer();
      final a = device(server, 'a');
      a.port.accounts.add(fixture.account(accountOne));
      a.settingsPort.values['market_favorites'] = favorites(['remote']);
      await a.engine.uploadNow();
      final b = device(server, 'b');
      await b.engine.setUploadSelection(nothing);
      await b.engine.setPullSelection(nothing);
      final error = await b.engine.changePassphrase('new strong sync phrase');
      expect(error, isNull);
      expect(b.port.accounts, isEmpty);
      expect(b.settingsPort.applies, 0);
      expect(
        read(
          server,
          sidecar(server).accounts[accountOne]!,
          phrase: 'new strong sync phrase',
        )['account_name'],
        'gaben',
      );
    },
  );
}
