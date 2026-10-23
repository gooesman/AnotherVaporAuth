import 'dart:convert';

import 'package:ava/src/core/sync/sync_payload.dart';
import 'package:ava/src/core/sync/sync_transport.dart';
import 'package:ava/src/services/sync/sync_config_store.dart';
import 'package:ava/src/services/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_engine_test.dart' as fixture;
import 'sync_transfer_test.dart' as transfer;

void main() {
  test(
    'comparison account pull preserves merged favorites and restart baselines',
    () async {
      final server = fixture.InMemoryServer();
      final a = transfer.device(server, 'a');
      a.port.accounts.add(fixture.account(transfer.accountOne));
      a.settingsPort.values['market_favorites'] = transfer.favorites([
        'remote',
      ]);
      await a.engine.uploadNow();

      final b = transfer.device(server, 'b');
      b.settingsPort.values['market_favorites'] = transfer.favorites(['local']);
      await b.engine.pullNow();
      final favoriteBaseline =
          b.configStore.state.localContentHashes['favorites'];
      a.port.accounts.single.accountName = 'remote edit';
      await a.engine.setUploadSelection(transfer.accountsOnly);
      await a.engine.uploadNow();

      await b.engine.start();
      b.port.onApply = (_) => b.engine.notifyAccountsChanged();
      final preview = await b.engine.compareWithRemote();
      b.engine.notifyAccountsChanged();
      transfer.resetTraffic(server);
      await b.engine.applyComparison(
        preview,
        preview.items.singleWhere(
          (item) => item.steamId == transfer.accountOne,
        ),
        upload: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(b.port.accounts.single.accountName, 'remote edit');
      expect(
        b.configStore.state.localContentHashes['favorites'],
        favoriteBaseline,
      );
      expect(server.puts, isEmpty);
      expect(server.deletes, isEmpty);

      // Recreate both the engine and serialized on-disk state, as after restart.
      final restarted = transfer.device(server, 'b-restarted');
      restarted.configStore.config = SyncConfig.fromJson(
        jsonDecode(jsonEncode(b.configStore.config!.toJson()))
            as Map<String, dynamic>,
      );
      restarted.configStore.state = SyncLocalState.fromJson(
        jsonDecode(jsonEncode(b.configStore.state.toJson()))
            as Map<String, dynamic>,
      );
      restarted.port.accounts.addAll(b.port.accounts);
      restarted.settingsPort.values =
          jsonDecode(jsonEncode(b.settingsPort.values)) as Map<String, dynamic>;
      await transfer.automatic(restarted.engine);
      expect(server.puts, isEmpty);
      expect(server.deletes, isEmpty);
      expect(
        transfer.read(
          server,
          transfer.sidecar(server).settings!,
        )['market_favorites'],
        transfer.favorites(['remote']),
      );
      expect(
        (restarted.settingsPort.values['market_favorites'] as Map)['items'],
        hasLength(2),
      );
    },
  );

  test(
    'comparison settings pull merges favorites without uploading later',
    () async {
      final server = fixture.InMemoryServer();
      final a = transfer.device(server, 'a');
      final remoteFavorites = transfer.favorites([
        'shared',
        'remote',
      ], currency: 1);
      (remoteFavorites['items'] as List).first['name'] = 'remote shared';
      a.settingsPort.values['market_favorites'] = remoteFavorites;
      await a.engine.uploadNow();
      final b = transfer.device(server, 'b');
      final localFavorites = transfer.favorites(['shared', 'local']);
      (localFavorites['items'] as List).first['name'] = 'local shared';
      b.settingsPort.values['market_favorites'] = localFavorites;
      await b.engine.start();
      b.settingsPort.onApply = (_) => b.engine.notifyAccountsChanged();
      final preview = await b.engine.compareWithRemote();
      transfer.resetTraffic(server);
      await b.engine.applyComparison(
        preview,
        preview.items.singleWhere((item) => item.steamId == null),
        upload: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await transfer.automatic(b.engine);
      expect(server.puts, isEmpty);
      expect(server.deletes, isEmpty);
      final merged = b.settingsPort.values['market_favorites'] as Map;
      final items = merged['items'] as List;
      expect(items.map((item) => item['market_hash_name']), [
        'shared',
        'local',
        'remote',
      ]);
      expect(items.first['name'], 'remote shared');
      expect(merged['currency'], 1);
      expect(
        transfer.read(
          server,
          transfer.sidecar(server).settings!,
        )['market_favorites'],
        remoteFavorites,
      );
      expect(b.engine.status.hasError, isFalse);
    },
  );

  test(
    'comparison includes favorites selected after the legacy settings switch was off',
    () async {
      final server = fixture.InMemoryServer();
      final a = transfer.device(server, 'a');
      a.settingsPort.values['market_favorites'] = transfer.favorites([
        'remote',
      ]);
      await a.engine.setUploadSelection(transfer.favoritesOnly);
      await a.engine.uploadNow();
      final b = transfer.device(server, 'b');
      b.configStore.config = b.configStore.config!.copyWith(
        syncSettings: false,
        uploadSelection: transfer.favoritesOnly,
        pullSelection: transfer.favoritesOnly,
      );
      b.settingsPort.values['market_favorites'] = transfer.favorites(['local']);
      transfer.resetTraffic(server);
      final preview = await b.engine.compareWithRemote();
      final item = preview.items.singleWhere((item) => item.steamId == null);
      expect(item.local!['market_favorites'], transfer.favorites(['local']));
      expect(item.remote!['market_favorites'], transfer.favorites(['remote']));
      expect(item.canUpload, isTrue);
      expect(item.canPull, isTrue);
      expect(server.puts, isEmpty);
      expect(server.deletes, isEmpty);
    },
  );

  for (final accountChange in [true, false]) {
    test(
      'comparison upload retains a ${accountChange ? 'account' : 'settings'} edit made during commit',
      () async {
        final server = fixture.InMemoryServer();
        final a = transfer.device(server, 'a');
        a.port.accounts.add(fixture.account(transfer.accountOne));
        await a.engine.uploadNow();
        if (accountChange) {
          a.port.accounts.single.accountName = 'reviewed';
        } else {
          a.settingsPort.values['skin'] = 'reviewed';
        }
        final preview = await a.engine.compareWithRemote();
        final item = preview.items.singleWhere(
          (item) => accountChange
              ? item.steamId == transfer.accountOne
              : item.steamId == null,
        );
        server.onPut = (name) {
          if (name != kSyncSidecarFilename) return;
          if (accountChange) {
            a.port.accounts.single.accountName = 'new edit';
          } else {
            a.settingsPort.values['skin'] = 'new edit';
          }
        };
        await a.engine.applyComparison(preview, item, upload: true);
        server.onPut = null;
        Map<String, dynamic> currentRemote() {
          final latest = transfer.sidecar(server);
          return transfer.read(
            server,
            accountChange
                ? latest.accounts[transfer.accountOne]!
                : latest.settings!,
          );
        }

        final field = accountChange ? 'account_name' : 'skin';
        expect(currentRemote()[field], 'reviewed');
        await transfer.automatic(a.engine);
        expect(a.engine.status.hasError, isFalse);
        expect(currentRemote()[field], 'new edit');
      },
    );
  }

  for (final upload in [true, false]) {
    test(
      '${upload ? 'upload' : 'pull'} transport construction failure clears busy state and allows retry',
      () async {
        final server = fixture.InMemoryServer();
        final a = transfer.device(server, 'a');
        a.port.accounts.add(fixture.account(transfer.accountOne));
        await a.engine.setUploadSelection(transfer.accountsOnly);
        var fail = true;
        final engine = SyncEngine(
          configStore: a.configStore,
          accounts: a.port,
          settings: a.settingsPort,
          trash: a.trash,
          deviceId: () async => 'factory-test',
          transportFactory: (_, _) {
            if (fail) throw const SyncHttpPolicyError('fixture-private-detail');
            return fixture.InMemoryTransport(server);
          },
        );
        addTearDown(engine.dispose);
        await (upload ? engine.uploadNow() : engine.pullNow());
        expect(engine.status.syncing, isFalse);
        expect(engine.status.hasError, isTrue);
        expect(
          engine.status.errorDetail,
          isNot(contains('fixture-private-detail')),
        );
        expect(server.puts, isEmpty);
        fail = false;
        await engine.uploadNow();
        expect(engine.status.syncing, isFalse);
        expect(engine.status.hasError, isFalse);
        expect(
          transfer.sidecar(server).accounts,
          contains(transfer.accountOne),
        );
      },
    );
  }
}
