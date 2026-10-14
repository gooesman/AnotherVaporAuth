import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/src/core/sync/sync_field_diff.dart';
import 'package:ava/src/core/sync/sync_payload.dart';
import 'package:ava/src/core/sync/sync_transport.dart';
import 'package:ava/src/services/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_engine_test.dart'
    show InMemoryServer, InMemoryTransport, Device, account, kSubscription;

class _CommitTransport extends InMemoryTransport {
  _CommitTransport(super.server, {this.beforePut, this.afterPut});
  final Future<void> Function(String)? beforePut;
  final Future<void> Function(String)? afterPut;

  @override
  Future<String?> putFile(
    String name,
    Uint8List bytes, {
    String? ifMatch,
    bool ifAbsent = false,
  }) async {
    await beforePut?.call(name);
    final etag = await super.putFile(
      name,
      bytes,
      ifMatch: ifMatch,
      ifAbsent: ifAbsent,
    );
    await afterPut?.call(name);
    return etag;
  }
}

const id1 = 76561198000000001;
const id2 = 76561198000000002;
const favorites = {
  'currency': 23,
  'items': [
    {'appid': 440, 'market_hash_name': 'Key', 'name': 'Key'},
  ],
};

void main() {
  test(
    'manual manifest cannot overwrite an ordinary writer staged before its sidecar commit',
    () async {
      final server = InMemoryServer();
      final a = Device(server, 'A');
      final b = Device(server, 'B');
      a.port.accounts.add(account(id1));
      await a.engine.syncNow();
      await b.engine.syncNow();
      a.port.accounts[0] = account(id1, name: 'manual-change');
      final manifestStaged = Completer<void>();
      final allowOrdinaryCommit = Completer<void>();
      Future<void>? ordinaryRound;
      final ordinary = SyncEngine(
        configStore: b.configStore,
        accounts: b.port,
        settings: b.settingsPort,
        trash: b.trash,
        deviceId: () async => 'B',
        transportFactory: (_, _) => _CommitTransport(
          server,
          beforePut: (name) async {
            if (name == kSyncSidecarFilename) await allowOrdinaryCommit.future;
          },
          afterPut: (name) async {
            if (name == kSyncManifestFilename) manifestStaged.complete();
          },
        ),
      );
      final manual = SyncEngine(
        configStore: a.configStore,
        accounts: a.port,
        settings: a.settingsPort,
        trash: a.trash,
        deviceId: () async => 'A',
        transportFactory: (_, _) => _CommitTransport(
          server,
          afterPut: (name) async {
            if (name != kSyncSidecarFilename) return;
            // B first adopts A's committed revision, then edits it normally.
            await b.engine.syncNow();
            b.port.accounts[0] = account(id1, name: 'ordinary-newer-change');
            ordinaryRound = ordinary.syncNow();
            await manifestStaged.future;
          },
          beforePut: (name) async {
            if (name != kSyncManifestFilename || ordinaryRound == null) return;
            // The old implementation has now read B's new manifest ETag but
            // A's older sidecar. Let B commit and remove A's superseded blob.
            allowOrdinaryCommit.complete();
            await ordinaryRound;
          },
        ),
      );
      addTearDown(manual.dispose);
      addTearDown(ordinary.dispose);
      final preview = await manual.compareWithRemote();
      await manual.applyComparison(
        preview,
        preview.items.firstWhere((item) => item.steamId == id1),
        upload: true,
      );
      final latest = SyncSidecar.parse(
        utf8.decode(server.files[kSyncSidecarFilename]!.$1),
      );
      expect(
        utf8.decode(server.files[kSyncManifestFilename]!.$1),
        buildRemoteManifest(latest.accounts, latest.passkeyCheck!),
      );
      expect(server.files.containsKey(latest.accounts[id1]!.filename), isTrue);
      expect(ordinary.status.hasError, isFalse);
    },
  );

  test(
    'comparison reads remote and field changes without any writes',
    () async {
      final server = InMemoryServer();
      final a = Device(server, 'A');
      final b = Device(server, 'B');
      a.port.accounts.add(account(id1));
      await a.engine.syncNow();
      await b.engine.syncNow();
      a.port.accounts[0] = account(id1, name: 'local-name');
      final count = server.etagSeq;
      final preview = await a.engine.compareWithRemote();
      final item = preview.items.firstWhere((i) => i.steamId == id1);
      expect(item.kind, SyncComparisonKind.localChanged);
      expect(
        syncFieldDiff(item.local, item.remote).single.path,
        'account_name',
      );
      expect(server.etagSeq, count);
      expect(b.port.accounts.single.accountName, 'gaben');
      await a.engine.applyComparison(preview, item, upload: true);
      await b.engine.syncNow();
      expect(b.port.accounts.single.accountName, 'local-name');
    },
  );

  test(
    'favorites and subscriptions pull together without changing another account',
    () async {
      final server = InMemoryServer();
      final a = Device(server, 'A');
      final b = Device(server, 'B');
      a.port.accounts.add(account(id1));
      await a.engine.syncNow();
      await b.engine.syncNow();
      a.settingsPort.values.addAll({
        'market_favorites': favorites,
        'steam_acceleration': kSubscription,
      });
      await a.engine.syncNow();
      b.port.accounts.add(account(id2, name: 'local-only'));
      final preview = await b.engine.compareWithRemote();
      final item = preview.items.firstWhere((i) => i.steamId == null);
      expect(item.kind, SyncComparisonKind.remoteChanged);
      final count = server.etagSeq;
      await b.engine.applyComparison(preview, item, upload: false);
      expect(server.etagSeq, count);
      expect(b.settingsPort.values['market_favorites'], favorites);
      expect(b.settingsPort.values['steam_acceleration'], kSubscription);
      final sidecar = SyncSidecar.parse(
        utf8.decode(server.files[kSyncSidecarFilename]!.$1),
      );
      expect(sidecar.accounts.containsKey(id2), isFalse);
      expect(b.port.accounts, hasLength(2));
    },
  );

  test(
    'concurrent settings wait for choice and explicit upload resolves',
    () async {
      final server = InMemoryServer();
      final a = Device(server, 'A');
      final b = Device(server, 'B');
      await a.engine.syncNow();
      await b.engine.syncNow();
      a.settingsPort.values['market_favorites'] = favorites;
      b.settingsPort.values['steam_acceleration'] = kSubscription;
      await a.engine.syncNow();
      final count = server.etagSeq;
      await b.engine.syncNow();
      expect(b.engine.status.settingsConflict, isTrue);
      expect(server.etagSeq, count);
      final preview = await b.engine.compareWithRemote();
      final item = preview.items.single;
      expect(item.kind, SyncComparisonKind.bothChanged);
      await b.engine.applyComparison(preview, item, upload: true);
      expect(b.engine.status.settingsConflict, isFalse);
      await a.engine.syncNow();
      expect(a.settingsPort.values['steam_acceleration'], kSubscription);
    },
  );

  test('stale local comparison cannot overwrite reviewed remote', () async {
    final server = InMemoryServer();
    final a = Device(server, 'A');
    a.port.accounts.add(account(id1));
    final preview = await a.engine.compareWithRemote();
    a.port.accounts[0] = account(id1, name: 'changed-after-preview');
    await expectLater(
      a.engine.applyComparison(preview, preview.items.first, upload: true),
      throwsA(isA<SyncComparisonChanged>()),
    );
    expect(server.files, isEmpty);
  });

  test('stale remote comparison cannot pull or upload', () async {
    final server = InMemoryServer();
    final a = Device(server, 'A');
    final b = Device(server, 'B');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    final preview = await b.engine.compareWithRemote();
    a.port.accounts[0] = account(id1, name: 'new-remote');
    await a.engine.syncNow();
    await expectLater(
      b.engine.applyComparison(preview, preview.items.first, upload: false),
      throwsA(isA<SyncComparisonChanged>()),
    );
    expect(b.port.accounts, isEmpty);
  });

  test(
    'conditional commit failure leaves local merge base untouched',
    () async {
      final server = InMemoryServer();
      final a = Device(server, 'A');
      a.port.accounts.add(account(id1));
      await a.engine.syncNow();
      a.port.accounts[0] = account(id1, name: 'changed');
      final preview = await a.engine.compareWithRemote();
      final before = a.configStore.state.toJson();
      final sidecarBefore = server.files[kSyncSidecarFilename]!;
      final manifestBefore = server.files[kSyncManifestFilename]!;
      server.rejectIfMatch = true;
      await expectLater(
        a.engine.applyComparison(preview, preview.items.first, upload: true),
        throwsA(isA<SyncPreconditionFailed>()),
      );
      expect(a.configStore.state.toJson(), before);
      expect(server.files[kSyncSidecarFilename], sidecarBefore);
      expect(server.files[kSyncManifestFilename], manifestBefore);
      expect(a.engine.status.syncing, isFalse);
    },
  );

  test('failed recovery backup refuses local overwrite', () async {
    final server = InMemoryServer();
    final a = Device(server, 'A');
    final b = Device(server, 'B');
    a.port.accounts.add(account(id1));
    await a.engine.syncNow();
    b.port.accounts.add(account(id1, name: 'local'));
    final preview = await b.engine.compareWithRemote();
    b.trash.failPuts = true;
    await expectLater(
      b.engine.applyComparison(preview, preview.items.first, upload: false),
      throwsStateError,
    );
    expect(b.port.accounts.single.accountName, 'local');
  });

  test(
    'locked account store and corrupted remote cannot be compared',
    () async {
      final server = InMemoryServer();
      final a = Device(server, 'A');
      a.port.locked = true;
      await expectLater(a.engine.compareWithRemote(), throwsStateError);
      a.port.locked = false;
      a.port.accounts.add(account(id1));
      await a.engine.syncNow();
      final sidecar = SyncSidecar.parse(
        utf8.decode(server.files[kSyncSidecarFilename]!.$1),
      );
      server.files[sidecar.accounts[id1]!.filename] = (
        Uint8List.fromList(utf8.encode('corrupt')),
        'changed',
      );
      await expectLater(a.engine.compareWithRemote(), throwsA(anything));
    },
  );

  test(
    'field comparison never exposes secrets; favorite differences use product IDs',
    () {
      final changes = syncFieldDiff(
        {
          'password': 'private-password',
          'shared_secret': 'private-secret',
          'steam_acceleration': kSubscription,
          'market_favorites': favorites,
        },
        {
          'market_favorites': {'currency': 1, 'items': []},
        },
      );
      final text = changes
          .map((d) => '${d.path} ${d.local} ${d.remote}')
          .join('\n');
      expect(text, isNot(contains('private-password')));
      expect(text, isNot(contains('private-secret')));
      expect(text, isNot(contains('fixture-token')));
      expect(text, isNot(contains('fixture-node-secret')));
      expect(text, contains('market_favorites.items.440/Key'));
      expect(text, contains('market_favorites.currency'));
    },
  );

  test('account comparison hides OTP URIs and unknown private fields', () {
    final changes = syncFieldDiff({
      'Session': {'SteamID': id1},
      'account_name': 'visible-name',
      'uri': 'otpauth://totp/Steam?secret=PRIVATESEED',
      'future_private_field': 'PRIVATEVALUE',
    }, null);
    final text = changes.map((d) => '${d.path} ${d.local}').join('\n');
    expect(text, contains('visible-name'));
    expect(text, contains('$id1'));
    expect(text, isNot(contains('PRIVATESEED')));
    expect(text, isNot(contains('PRIVATEVALUE')));
  });
}
