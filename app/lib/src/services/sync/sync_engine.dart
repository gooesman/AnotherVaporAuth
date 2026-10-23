/// The sync orchestrator: runs rounds (fetch → plan → execute → commit),
/// owns the conflict list, the trash, and the status the UI renders.
///
/// Design rules it enforces (from the spec):
///  - Sync is the library's shadow, never its gate: nothing here blocks an
///    account operation, errors surface as status, not dialogs.
///  - Every destructive step (remote tombstone applied locally, either side
///    of a conflict resolution) writes the losing payload to the trash first.
///  - The sidecar PUT is the commit point, guarded by If-Match; a 412 means
///    another device won — re-pull, re-merge, retry (bounded), never
///    overwrite blind. A 412 against a sidecar nobody changed is not a race
///    (typically a proxy rewriting ETags) and is reported, not retried.
///
/// The engine knows nothing about Flutter or Riverpod. Its window into the
/// account store is [SyncAccountsPort]; providers adapt it to AppController
/// and tests fake it in memory.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart'
    show IterableExtension, ListEquality;

import '../../core/models/steam_guard_account.dart';
import '../../core/sync/sync_payload.dart';
import '../../core/sync/sync_planner.dart';
import '../../core/sync/sync_transport.dart';
import '../debug_log.dart';
import 'sync_config_store.dart';
import 'sync_trash.dart';

part 'sync_comparison.dart';
part 'sync_transfer.dart';

/// The engine's window into the local account store.
abstract class SyncAccountsPort {
  /// The decrypted account list, or null while locked / not bootstrapped.
  List<SteamGuardAccount>? snapshot();

  /// Imports/overwrites one account from a pulled payload (standard maFile
  /// JSON). Keep the local session and omitted fields, but apply explicit
  /// null/empty values from the synchronized document.
  Future<void> applyRemote(Map<String, dynamic> payload);

  /// Removes one account locally (the engine has already trashed it).
  Future<void> removeAccount(int steamId);
}

/// The engine's window into the curated app-settings document.
///
/// Concurrent settings edits wait for an explicit comparison decision.
/// Optional subscription credentials share this encrypted document, while
/// account secrets retain their explicit conflict handling. A device that
/// has never synced settings ADOPTS the remote document rather than pushing
/// its fresh defaults over everyone else's
/// choices.
abstract class SyncSettingsPort {
  /// The current curated settings document, or null while unavailable
  /// (store locked / not bootstrapped).
  Future<Map<String, dynamic>?> snapshot({
    SyncSelection selection = const SyncSelection(),
  });

  /// Applies a pulled settings document (unknown keys ignored).
  Future<void> apply(Map<String, dynamic> settings);
}

typedef SyncTransportFactory = SyncTransport Function(
    SyncConfig config, String webdavPassword);

enum SyncErrorKind {
  none,
  network,
  auth,
  tls,
  server,

  /// The stored passphrase no longer opens the remote (changed elsewhere,
  /// or secure storage lost it) — the UI asks for it again.
  passphrase,
  io,
}

/// One unresolved conflict, with both payloads already in hand so the
/// compare UI never needs the network.
class SyncConflictItem {
  final int steamId;
  final SyncConflictKind kind;
  final Map<String, dynamic>? localPayload;
  final Map<String, dynamic>? remotePayload;
  final SyncRemoteAccount? remote;
  final SyncTombstone? tombstone;

  const SyncConflictItem({
    required this.steamId,
    required this.kind,
    this.localPayload,
    this.remotePayload,
    this.remote,
    this.tombstone,
  });

  String? get accountName =>
      (localPayload?['account_name'] ?? remotePayload?['account_name'])
          as String?;
}

class SyncEngineStatus {
  final bool configured;
  final bool syncing;
  final DateTime? lastSyncAt;
  final SyncErrorKind errorKind;
  final String? errorDetail;
  final bool needsPassphrase;
  final bool conditionalUnsupported;
  final List<SyncConflictItem> conflicts;
  final bool settingsConflict;
  final int lastPushed;
  final int lastPulled;

  const SyncEngineStatus({
    this.configured = false,
    this.syncing = false,
    this.lastSyncAt,
    this.errorKind = SyncErrorKind.none,
    this.errorDetail,
    this.needsPassphrase = false,
    this.conditionalUnsupported = false,
    this.conflicts = const [],
    this.settingsConflict = false,
    this.lastPushed = 0,
    this.lastPulled = 0,
  });

  bool get hasError => errorKind != SyncErrorKind.none;

  SyncEngineStatus copyWith({
    bool? configured,
    bool? syncing,
    DateTime? lastSyncAt,
    SyncErrorKind? errorKind,
    String? errorDetail,
    bool? needsPassphrase,
    bool? conditionalUnsupported,
    List<SyncConflictItem>? conflicts,
    bool? settingsConflict,
    int? lastPushed,
    int? lastPulled,
  }) =>
      SyncEngineStatus(
        configured: configured ?? this.configured,
        syncing: syncing ?? this.syncing,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        errorKind: errorKind ?? this.errorKind,
        errorDetail: errorDetail == null && errorKind == SyncErrorKind.none
            ? null
            : (errorDetail ?? this.errorDetail),
        needsPassphrase: needsPassphrase ?? this.needsPassphrase,
        conditionalUnsupported:
            conditionalUnsupported ?? this.conditionalUnsupported,
        conflicts: conflicts ?? this.conflicts,
        settingsConflict: settingsConflict ?? this.settingsConflict,
        lastPushed: lastPushed ?? this.lastPushed,
        lastPulled: lastPulled ?? this.lastPulled,
      );
}

class SyncEngine {
  final SyncConfigStore configStore;
  final SyncAccountsPort accounts;

  /// Null disables settings sync entirely (tests, future backends).
  final SyncSettingsPort? settings;
  final SyncTrash trash;
  final SyncTransportFactory transportFactory;
  final Future<String> Function() deviceId;
  final DateTime Function() now;

  /// Debounce for change-triggered rounds; long enough to batch a burst of
  /// store writes (import of twenty accounts), short enough to feel live.
  final Duration debounce;

  SyncEngine({
    required this.configStore,
    required this.accounts,
    required this.trash,
    required this.transportFactory,
    required this.deviceId,
    this.settings,
    DateTime Function()? now,
    this.debounce = const Duration(seconds: 5),
  }) : now = now ?? DateTime.now;

  final _statusController = StreamController<SyncEngineStatus>.broadcast();
  SyncEngineStatus _status = const SyncEngineStatus();
  SyncEngineStatus get status => _status;
  Stream<SyncEngineStatus> get statusStream => _statusController.stream;

  void _publish(SyncEngineStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  Timer? _debounceTimer;
  bool _started = false;
  int _autoGeneration = 0;
  bool _applyingRemote = false;

  /// Serializes rounds. Each caller's future completes after its own round,
  /// so `await syncNow()` always means "a round that saw my state ran" —
  /// even when another round was in flight when it was called.
  Future<void> _rounds = Future<void>.value();

  Future<SyncComparison> compareWithRemote() => _compareWithRemote();

  Future<void> applyComparison(SyncComparison preview, SyncComparisonItem item,
      {required bool upload}) {
    if (!upload) _cancelAutomaticUpload();
    return _applyComparison(preview, item, upload: upload);
  }

  /// Max commit-race retries before giving up the round (the next trigger
  /// tries again anyway).
  static const int _maxCommitRetries = 3;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    unawaited(trash.purgeExpired());
    final config = await configStore.loadConfig();
    _publish(_status.copyWith(
      configured: config != null,
      conditionalUnsupported: config?.conditionalUnsupported ?? false,
    ));
  }

  void dispose() {
    _debounceTimer?.cancel();
    _statusController.close();
  }

  /// Called whenever the account list may have changed (any store write).
  /// Debounced; no-op rounds are cheap (hash comparison only).
  void notifyAccountsChanged() {
    if (!_status.configured || _applyingRemote) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      unawaited(_autoSync());
    });
  }

  Future<void> _autoSync() async {
    final generation = _autoGeneration;
    final config = await configStore.loadConfig();
    if (config == null || !config.autoSync) return;
    await _queueTransfer(upload: true, automaticGeneration: generation);
  }

  /// Compatibility name for the explicit, one-way upload action.
  Future<void> syncNow() => uploadNow();

  Future<void> uploadNow() => _queueTransfer(upload: true);

  Future<void> pullNow() {
    _cancelAutomaticUpload();
    return _queueTransfer(upload: false);
  }

  void _cancelAutomaticUpload() {
    _autoGeneration++;
    _debounceTimer?.cancel();
  }

  Future<T> _applyRemoteChange<T>(Future<T> Function() action) async {
    _applyingRemote = true;
    try {
      return await action();
    } finally {
      _applyingRemote = false;
    }
  }

  /// Legacy three-way reconciliation, retained for recovery and its tests.
  /// User actions and automatic uploads use the directional methods above.
  Future<void> reconcileInternal() {
    final run = _rounds.then((_) => _runRound());
    _rounds = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _runRound({bool rotationOnly = false}) async {
    final config = await configStore.loadConfig();
    if (config == null) {
      _publish(_status.copyWith(configured: false));
      return;
    }
    final local = accounts.snapshot();
    if (local == null) return; // locked — nothing to compare against

    final webdavPassword = await configStore.loadWebdavPassword();
    final passphrase = await configStore.loadPassphrase();
    final previousPassphrase = await configStore.loadPreviousPassphrase();
    if (webdavPassword == null || passphrase == null || passphrase.isEmpty) {
      _publish(_status.copyWith(
        configured: true,
        needsPassphrase: true,
        errorKind: SyncErrorKind.passphrase,
        errorDetail: 'missing stored sync secrets',
      ));
      return;
    }

    _publish(_status.copyWith(
      configured: true,
      syncing: true,
      errorKind: SyncErrorKind.none,
      conditionalUnsupported: config.conditionalUnsupported,
    ));

    SyncTransport? transport;
    try {
      transport = transportFactory(config, webdavPassword);
      var lost = await _attemptRound(transport, config, passphrase,
          previousPassphrase: previousPassphrase, rotationOnly: rotationOnly);
      var retries = 0;
      while (lost != null && retries < _maxCommitRetries) {
        retries++;
        dlog('sync: commit raced, retry $retries/$_maxCommitRetries');
        final again = await _attemptRound(transport, config, passphrase,
            previousPassphrase: previousPassphrase, rotationOnly: rotationOnly);
        if (again != null && again.sameBaseAs(lost)) {
          // Nobody committed in between, yet the guard failed again: the
          // server is refusing the precondition built from what it served
          // (typically a proxy rewriting ETags). Retrying cannot help.
          dlog('sync: 412 against an unchanged sidecar (etag ${again.etag})');
          _publish(_status.copyWith(
            syncing: false,
            errorKind: SyncErrorKind.server,
            errorDetail: '412 on $kSyncSidecarFilename although nobody '
                'changed it — a proxy or CDN may be rewriting ETags',
          ));
          return;
        }
        lost = again;
      }
      if (lost != null) {
        _publish(_status.copyWith(
          syncing: false,
          errorKind: SyncErrorKind.server,
          errorDetail: 'commit kept racing after $_maxCommitRetries retries',
        ));
      }
    } on SyncTransportException catch (e) {
      _publish(_status.copyWith(
        syncing: false,
        errorKind: switch (e) {
          SyncAuthError() => SyncErrorKind.auth,
          SyncTlsUntrusted() => SyncErrorKind.tls,
          SyncNetworkError() => SyncErrorKind.network,
          _ => SyncErrorKind.server,
        },
        errorDetail: e.message,
      ));
      dlog('sync: failed: $e');
    } catch (e) {
      _publish(_status.copyWith(
          syncing: false,
          errorKind: SyncErrorKind.io,
          errorDetail: '$e'));
      dlog('sync: failed: $e');
    } finally {
      transport?.close();
    }
  }

  /// One fetch → plan → execute → commit pass. Null when the round is over
  /// (synced, or an error was published); a [_LostCommit] when the sidecar
  /// guard failed and the caller should retry.
  Future<_LostCommit?> _attemptRound(
      SyncTransport transport, SyncConfig config, String passphrase,
      {String? previousPassphrase, bool rotationOnly = false}) async {
    final local = accounts.snapshot();
    if (local == null) return null;

    // 1. Fetch the sidecar — the remote's source of truth.
    final sidecarFile = await transport.getFile(kSyncSidecarFilename);
    var remote = const SyncSidecar();
    var remoteExists = false;
    if (sidecarFile != null) {
      remoteExists = true;
      try {
        remote = SyncSidecar.parse(utf8.decode(sidecarFile.bytes));
      } catch (e) {
        _publish(_status.copyWith(
          syncing: false,
          errorKind: SyncErrorKind.server,
          errorDetail: 'remote sidecar is unreadable: $e',
        ));
        return null;
      }
    }

    // 2. Passphrase sanity against the remote before touching anything.
    // Skipped when this device is the one changing the passphrase (its local
    // epoch is ahead) — the old remote token is expected to fail then.
    if (remoteExists && config.passphraseEpoch <= remote.passphraseEpoch) {
      final check = verifyPasskeyCheck(passphrase, remote.passkeyCheck);
      if (check == false) {
        _publish(_status.copyWith(
          syncing: false,
          needsPassphrase: true,
          errorKind: SyncErrorKind.passphrase,
          errorDetail: 'stored passphrase no longer opens the remote',
        ));
        return null;
      }
      // The passphrase still opens the remote but the epoch moved (a
      // passphrase "change" elsewhere to the same phrase, or a re-setup):
      // adopt the remote epoch quietly.
      if (check == true && remote.passphraseEpoch > config.passphraseEpoch) {
        await configStore.saveConfig(
            config.copyWith(passphraseEpoch: remote.passphraseEpoch));
      }
    }

    // Explicit rotation changes encryption only. Re-read and re-encrypt every
    // referenced payload after a lost commit, including settings disabled on
    // this device. Ordinary merge logic must not retain old-key ciphertext
    // behind the newly committed epoch when another device edited an account.
    if (config.passphraseEpoch > remote.passphraseEpoch) {
      if (!config.forcePushPending || previousPassphrase == null ||
          previousPassphrase.isEmpty) {
        throw StateError('Previous sync passphrase is unavailable');
      }
      return _rotateRemote(transport, config, remote, sidecarFile,
          previousPassphrase, passphrase);
    }
    if (rotationOnly) {
      // Resume cleanup after a committed rotation whose local save failed.
      if (previousPassphrase != null &&
          verifyPasskeyCheck(passphrase, remote.passkeyCheck) == true) {
        await configStore.saveConfig(config.copyWith(forcePushPending: false));
        await configStore.clearPreviousPassphrase();
        _publish(status.copyWith(syncing: false, errorKind: SyncErrorKind.none));
        return null;
      }
      throw StateError('Remote encryption changed; retry the passphrase change');
    }

    // 3. The include-passwords flag must agree across devices. A local
    // pending toggle wins (it re-pushes everything); otherwise the remote's
    // value is adopted — the device that flipped it last committed it.
    var effectiveConfig = config;
    if (remoteExists &&
        remote.includePasswords != config.syncPasswords &&
        !config.forcePushPending) {
      effectiveConfig = config.copyWith(syncPasswords: remote.includePasswords);
      await configStore.saveConfig(effectiveConfig);
    }
    final includePasswords = effectiveConfig.syncPasswords;

    // 4. Plan.
    final state = await configStore.loadState();
    final byId = {for (final a in local) a.steamId: a};
    final payloads = {
      for (final a in local)
        a.steamId: syncPayloadJson(a, includePassword: includePasswords)
    };
    final localHashes = {
      for (final e in payloads.entries) e.key: payloadHash(e.value)
    };
    final plan = planSync(
      localHashes: localHashes,
      base: state.base,
      tombstonesSeen: state.tombstonesSeen,
      remote: remote,
      forcePushAll: effectiveConfig.forcePushPending,
    );

    final newBase = Map<int, SyncBaseEntry>.of(state.base);
    final newSeen = Map<int, int>.of(state.tombstonesSeen);
    var pushed = 0, pulled = 0;

    // 5. Pulls first (reads before writes; a failed pull aborts the round
    // before anything was mutated remotely).
    final conflicts = <SyncConflictItem>[];
    var pullDecryptFailures = 0;
    var pullDecryptAttempts = 0;
    for (final pull in plan.pulls) {
      final file = await transport.getFile(pull.remote.filename);
      if (file == null) {
        // Missing file ≠ wrong passphrase: an interrupted committer can
        // leave a sidecar entry whose payload never landed. Skip; the next
        // committing device repairs the reference.
        dlog('sync: pull ${pull.steamId}: file missing, skipped');
        continue;
      }
      pullDecryptAttempts++;
      final payload = decryptSyncPayload(passphrase, pull.remote.salt,
          pull.remote.iv, utf8.decode(file.bytes));
      if (payload == null) {
        pullDecryptFailures++;
        dlog('sync: pull ${pull.steamId} unreadable, skipped');
        continue;
      }
      await accounts.applyRemote(payload);
      newBase[pull.steamId] =
          SyncBaseEntry(rev: pull.remote.rev, hash: pull.remote.hash);
      pulled++;
    }
    // Every attempted decrypt failing = wrong passphrase (same judgement as
    // the SDA import); scattered failures = corrupt entries, reported soft.
    if (pullDecryptAttempts > 0 &&
        pullDecryptFailures == pullDecryptAttempts) {
      _publish(_status.copyWith(
        syncing: false,
        needsPassphrase: true,
        errorKind: SyncErrorKind.passphrase,
        errorDetail: 'no remote account could be decrypted',
      ));
      return null;
    }

    // 6. Apply remote deletions locally — trash first, then remove.
    for (final del in plan.localDeletes) {
      final acc = byId[del.steamId];
      if (acc != null) {
        final ok = await trash.put(
          steamId: del.steamId,
          accountName: acc.accountName,
          payload: syncPayloadJson(acc, includePassword: true),
          reason: SyncTrashReason.remoteDelete,
          passphrase: passphrase,
        );
        if (!ok) {
          // No trash copy → no delete. The account will re-conflict next
          // round; losing secrets to a full disk is the one unacceptable
          // outcome.
          dlog('sync: trash write failed, refusing to delete ${del.steamId}');
          continue;
        }
        await accounts.removeAccount(del.steamId);
      }
      newBase.remove(del.steamId);
      newSeen[del.steamId] = del.tombstone.rev;
    }

    // 7. Conflicts: fetch the remote side now so the UI can compare offline.
    for (final c in plan.conflicts) {
      Map<String, dynamic>? remotePayload;
      if (c.remote != null) {
        remotePayload = await _fetchPayload(transport, c.remote!, passphrase);
      }
      final acc = byId[c.steamId];
      conflicts.add(SyncConflictItem(
        steamId: c.steamId,
        kind: c.kind,
        localPayload: acc == null
            ? null
            : syncPayloadJson(acc, includePassword: includePasswords),
        remotePayload: remotePayload,
        remote: c.remote,
        tombstone: c.tombstone,
      ));
    }

    // 8. App settings: compare against the last shared revision.
    //  - first contact (no base) ADOPTS the remote document — a new device
    //    must never clobber everyone's choices with its fresh defaults;
    //  - both-changed waits for an explicit upload/pull decision;
    //  - forcePushPending re-pushes regardless (ciphertext must change on a
    //    passphrase rotation).
    // Keep a separate local hash after pulls: older documents can omit newer
    // fields that the settings port retains, without this being a local edit.
    var newSettingsBase = state.settingsBase;
    var newSettingsLocalHash = state.settingsLocalHash;
    Map<String, dynamic>? settingsPushPayload;
    var settingsPushRev = 0;
    var settingsConflict = false;
    if (effectiveConfig.syncSettings && settings != null) {
      final localSettings = await settings!.snapshot();
      if (localSettings != null) {
        final hash = payloadHash(localSettings);
        final base = state.settingsBase;
        final r = remote.settings;
        final localChanged = base == null ||
            hash != (state.settingsLocalHash ?? base.hash);
        final remoteChanged =
            r != null && (base == null || r.rev != base.rev);
        if (r != null &&
            hash == r.hash &&
            !effectiveConfig.forcePushPending) {
          // Identical content — converge bookkeeping, move nothing.
          newSettingsBase = SyncBaseEntry(rev: r.rev, hash: r.hash);
          newSettingsLocalHash = hash;
        } else if (r == null) {
          if (localChanged || effectiveConfig.forcePushPending) {
            settingsPushPayload = localSettings;
            settingsPushRev = (base?.rev ?? 0) + 1;
          }
        } else if (base == null) {
          final payload = await _fetchPayload(transport, r, passphrase);
          if (payload != null) {
            await settings!.apply(payload);
            final applied = await settings!.snapshot();
            if (applied != null) {
              newSettingsBase = SyncBaseEntry(rev: r.rev, hash: r.hash);
              newSettingsLocalHash = payloadHash(applied);
            }
          }
          if (effectiveConfig.forcePushPending) {
            settingsPushPayload =
                (await settings!.snapshot()) ?? localSettings;
            settingsPushRev = r.rev + 1;
          }
        } else if (remoteChanged && !localChanged) {
          final payload = await _fetchPayload(transport, r, passphrase);
          if (payload != null) {
            await settings!.apply(payload);
            final applied = await settings!.snapshot();
            if (applied != null) {
              newSettingsBase = SyncBaseEntry(rev: r.rev, hash: r.hash);
              newSettingsLocalHash = payloadHash(applied);
            }
          }
        } else if (remoteChanged &&
            localChanged &&
            !effectiveConfig.forcePushPending) {
          settingsConflict = true;
        } else if (localChanged || effectiveConfig.forcePushPending) {
          settingsPushPayload = localSettings;
          settingsPushRev = r.rev + 1;
        }
      }
    }

    // 9. Pushes. Files first (revision-suffixed names never collide with
    // live data), manifest next, sidecar last as the commit.
    var nextSidecar = remote;
    if (plan.pushesAnything ||
        settingsPushPayload != null ||
        !remoteExists ||
        effectiveConfig.forcePushPending) {
      final devId = await deviceId();
      final devTag = devId.length >= 4 ? devId.substring(0, 4) : devId;
      final newAccounts =
          Map<int, SyncRemoteAccount>.of(remote.accounts);
      final newTombstones = Map<int, SyncTombstone>.of(remote.tombstones);

      for (final push in plan.pushes) {
        final acc = byId[push.steamId];
        if (acc == null) continue;
        final payload = payloads[push.steamId]!;
        final enc = encryptSyncPayload(passphrase, payload);
        // Device-tagged name: two devices pushing the same account at the
        // same rev must not overwrite each other's file mid-race.
        final filename = '${push.steamId}.r${push.newRev}.$devTag.maFile';
        await transport.putFile(
            filename, Uint8List.fromList(utf8.encode(enc.ciphertext)));
        newAccounts[push.steamId] = SyncRemoteAccount(
          rev: push.newRev,
          hash: localHashes[push.steamId]!,
          filename: filename,
          salt: enc.salt,
          iv: enc.iv,
        );
        newTombstones.remove(push.steamId);
        newBase[push.steamId] = SyncBaseEntry(
            rev: push.newRev, hash: localHashes[push.steamId]!);
        newSeen.remove(push.steamId);
        pushed++;
      }

      for (final t in plan.tombstonePushes) {
        newAccounts.remove(t.steamId);
        newTombstones[t.steamId] = SyncTombstone(
          rev: t.newRev,
          deletedAt: now().toUtc().toIso8601String(),
          device: devId,
        );
        newBase.remove(t.steamId);
        newSeen[t.steamId] = t.newRev;
      }

      // Mint a fresh check token when this device is committing a new
      // passphrase epoch — carrying the old token forward would lock every
      // other device out with "wrong passphrase" against the NEW phrase.
      SyncRemoteAccount? nextSettingsEntry;
      if (settingsPushPayload != null) {
        final enc = encryptSyncPayload(passphrase, settingsPushPayload);
        final filename = 'ava.settings.r$settingsPushRev.$devTag.json';
        await transport.putFile(
            filename, Uint8List.fromList(utf8.encode(enc.ciphertext)));
        final settingsHash = payloadHash(settingsPushPayload);
        nextSettingsEntry = SyncRemoteAccount(
          rev: settingsPushRev,
          hash: settingsHash,
          filename: filename,
          salt: enc.salt,
          iv: enc.iv,
        );
        newSettingsBase =
            SyncBaseEntry(rev: settingsPushRev, hash: settingsHash);
        newSettingsLocalHash = settingsHash;
      }

      final passkeyCheck = (remote.passkeyCheck == null ||
              effectiveConfig.passphraseEpoch > remote.passphraseEpoch)
          ? buildPasskeyCheck(passphrase)
          : remote.passkeyCheck!;
      nextSidecar = remote.copyWith(
        includePasswords: includePasswords,
        passphraseEpoch: effectiveConfig.passphraseEpoch,
        passkeyCheck: passkeyCheck,
        accounts: newAccounts,
        tombstones: newTombstones,
        settings: nextSettingsEntry,
        devices: {
          ...remote.devices,
          devId: SyncDeviceInfo(
            name: effectiveConfig.deviceName,
            lastSyncAt: now().toUtc().toIso8601String(),
          ),
        },
      );

      if (!remoteExists) await transport.ensureRoot();

      // Manifest before sidecar: a crash in between leaves an SDA folder
      // whose manifest already matches the new files (still fully readable),
      // while the old sidecar just makes the next round re-push.
      await transport.putFile(
        kSyncManifestFilename,
        Uint8List.fromList(
            utf8.encode(buildRemoteManifest(newAccounts, passkeyCheck))),
      );

      try {
        await transport.putFile(
          kSyncSidecarFilename,
          Uint8List.fromList(utf8.encode(nextSidecar.serialize())),
          ifMatch: remoteExists ? sidecarFile?.etag : null,
          ifAbsent: !remoteExists,
        );
      } on SyncPreconditionFailed {
        return _LostCommit(sidecarFile?.etag, sidecarFile?.bytes);
      }

      // Post-commit GC: files the new sidecar no longer references.
      final live = {for (final a in newAccounts.values) a.filename};
      for (final old in remote.accounts.values) {
        if (!live.contains(old.filename)) {
          try {
            await transport.deleteFile(old.filename);
          } catch (_) {/* orphan; the next committer retries */}
        }
      }
      final oldSettings = remote.settings;
      if (oldSettings != null &&
          nextSidecar.settings?.filename != oldSettings.filename) {
        try {
          await transport.deleteFile(oldSettings.filename);
        } catch (_) {/* orphan; the next committer retries */}
      }
    }

    // 10. Bookkeeping the plan asked for without data movement.
    for (final adopt in plan.baseAdopts) {
      if (adopt.drop) {
        newBase.remove(adopt.steamId);
        newSeen.remove(adopt.steamId);
      } else if (adopt.tombstone) {
        newBase.remove(adopt.steamId);
        newSeen[adopt.steamId] = adopt.rev;
      } else {
        newBase[adopt.steamId] =
            SyncBaseEntry(rev: adopt.rev, hash: adopt.hash);
      }
    }

    await configStore.saveState(SyncLocalState(
      base: newBase,
      tombstonesSeen: newSeen,
      settingsBase: newSettingsBase,
      settingsLocalHash: newSettingsLocalHash,
      localContentHashes: state.localContentHashes,
      remoteContentHashes: state.remoteContentHashes,
    ));
    if (effectiveConfig.forcePushPending) {
      await configStore
          .saveConfig(effectiveConfig.copyWith(forcePushPending: false));
    }
    // Also retry cleanup after a prior successful commit whose secure-storage
    // deletion failed. Never clear the recovery phrase before local saves.
    if (previousPassphrase != null) await configStore.clearPreviousPassphrase();

    _publish(_status.copyWith(
      configured: true,
      syncing: false,
      lastSyncAt: now(),
      errorKind: SyncErrorKind.none,
      needsPassphrase: false,
      conflicts: conflicts,
      settingsConflict: settingsConflict,
      lastPushed: pushed,
      lastPulled: pulled,
    ));
    return null;
  }

  /// Changes only ciphertext and crypto metadata, never remote plaintext.
  /// A 412 re-enters from a fresh sidecar and re-reads every referenced file.
  Future<_LostCommit?> _rotateRemote(
      SyncTransport transport, SyncConfig config, SyncSidecar remote,
      RemoteFile? sidecarFile, String previousPassphrase,
      String passphrase) async {
    if (verifyPasskeyCheck(previousPassphrase, remote.passkeyCheck) == false) {
      throw StateError('Previous sync passphrase no longer opens the remote');
    }
    Future<Map<String, dynamic>> read(SyncRemoteAccount entry) async {
      final payload = await _fetchPayload(transport, entry, previousPassphrase);
      if (payload == null || payloadHash(payload) != entry.hash) {
        throw StateError('Remote payload could not be re-encrypted');
      }
      return payload;
    }

    // Validate the full set before writing anything: never publish an epoch
    // while one missing, corrupt or unreadable file still uses the old key.
    final payloads = <int, Map<String, dynamic>>{};
    for (final entry in remote.accounts.entries) {
      payloads[entry.key] = await read(entry.value);
    }
    final settingsPayload = remote.settings == null
        ? null : await read(remote.settings!);
    final devId = await deviceId();
    final devTag = devId.length >= 4 ? devId.substring(0, 4) : devId;
    Future<SyncRemoteAccount> rewrite(SyncRemoteAccount entry,
        Map<String, dynamic> payload, String stem, String extension) async {
      final enc = encryptSyncPayload(passphrase, payload);
      final revision = entry.rev + 1;
      final filename = '$stem.r$revision.$devTag.$extension';
      await transport.putFile(
          filename, Uint8List.fromList(utf8.encode(enc.ciphertext)));
      return SyncRemoteAccount(rev: revision, hash: entry.hash,
          filename: filename, salt: enc.salt, iv: enc.iv);
    }

    final newAccounts = <int, SyncRemoteAccount>{};
    for (final entry in remote.accounts.entries) {
      newAccounts[entry.key] = await rewrite(entry.value, payloads[entry.key]!,
          '${entry.key}', 'maFile');
    }
    final newSettings = settingsPayload == null ? null : await rewrite(
        remote.settings!, settingsPayload, 'ava.settings', 'json');
    final passkeyCheck = buildPasskeyCheck(passphrase);
    final next = remote.copyWith(
      passphraseEpoch: config.passphraseEpoch,
      passkeyCheck: passkeyCheck,
      accounts: newAccounts,
      settings: newSettings,
      devices: {
        ...remote.devices,
        devId: SyncDeviceInfo(name: config.deviceName,
            lastSyncAt: now().toUtc().toIso8601String()),
      },
    );
    if (sidecarFile == null) await transport.ensureRoot();
    await transport.putFile(kSyncManifestFilename, Uint8List.fromList(
        utf8.encode(buildRemoteManifest(newAccounts, passkeyCheck))));
    try {
      await transport.putFile(kSyncSidecarFilename,
          Uint8List.fromList(utf8.encode(next.serialize())),
          ifMatch: sidecarFile?.etag, ifAbsent: sidecarFile == null);
    } on SyncPreconditionFailed {
      return _LostCommit(sidecarFile?.etag, sidecarFile?.bytes);
    }

    // Preserve the merge history of content changed by another device during
    // the rotation. Only unchanged plaintext can adopt its new crypto revision.
    final state = await configStore.loadState();
    final base = Map<int, SyncBaseEntry>.of(state.base);
    for (final entry in newAccounts.entries) {
      if (base[entry.key]?.hash == entry.value.hash) {
        base[entry.key] = SyncBaseEntry(
            rev: entry.value.rev, hash: entry.value.hash);
      }
    }
    var settingsBase = state.settingsBase;
    if (newSettings != null && settingsBase?.hash == newSettings.hash) {
      settingsBase = SyncBaseEntry(
          rev: newSettings.rev, hash: newSettings.hash);
    }
    await configStore.saveState(SyncLocalState(base: base,
        tombstonesSeen: state.tombstonesSeen, settingsBase: settingsBase,
        settingsLocalHash: state.settingsLocalHash,
        localContentHashes: state.localContentHashes,
        remoteContentHashes: state.remoteContentHashes));
    await configStore.saveConfig(config.copyWith(forcePushPending: false));
    await configStore.clearPreviousPassphrase();

    // As in a normal commit, remove superseded files only after the guarded
    // sidecar succeeds. Cleanup failure never invalidates a committed payload.
    final live = {for (final entry in newAccounts.values) entry.filename,
      if (newSettings != null) newSettings.filename};
    for (final entry in [
      ...remote.accounts.values, if (remote.settings != null) remote.settings!,
    ]) {
      if (!live.contains(entry.filename)) {
        try {
          await transport.deleteFile(entry.filename);
        } catch (_) {/* orphan; safe to retain */}
      }
    }
    _publish(_status.copyWith(configured: true, syncing: false,
        lastSyncAt: now(), errorKind: SyncErrorKind.none,
        needsPassphrase: false, conflicts: const [],
        lastPushed: newAccounts.length, lastPulled: 0));
    return null;
  }

  Future<Map<String, dynamic>?> _fetchPayload(SyncTransport transport,
      SyncRemoteAccount remote, String passphrase) async {
    final file = await transport.getFile(remote.filename);
    if (file == null) return null;
    return decryptSyncPayload(
        passphrase, remote.salt, remote.iv, utf8.decode(file.bytes));
  }

  // ─── Conflict resolution ───────────────────────────────────────────────

  /// Resolves one conflict. The losing side's payload goes to the trash;
  /// then local bookkeeping is adjusted so the next round carries the
  /// winner outward (keep local) or nothing (keep remote), and a round is
  /// triggered immediately.
  Future<void> resolveConflict(int steamId, {required bool keepLocal}) async {
    final conflict = status.conflicts.where((c) => c.steamId == steamId).firstOrNull;
    if (conflict == null) return;
    final preview = await compareWithRemote();
    final item = preview.items.where((item) => item.steamId == steamId).firstOrNull;
    if (item == null) throw SyncComparisonChanged();
    if (keepLocal ? item.canUpload : item.canPull) {
      await applyComparison(preview, item, upload: keepLocal);
      return;
    }
    if (!keepLocal && item.remoteDeleted && item.local != null) {
      _cancelAutomaticUpload();
      await _serializedComparison(() async {
        final access = await _comparisonAccess();
        final transport = transportFactory(access.config, access.password);
        try {
          final file = await transport.getFile(kSyncSidecarFilename);
          if (file?.etag != preview._sidecar?.etag ||
              !const ListEquality<int>().equals(file?.bytes, preview._sidecar?.bytes) ||
              payloadHash((await _comparisonLocal(steamId, access.config))!) !=
                  item._localHash) {
            throw SyncComparisonChanged();
          }
          final account = accounts.snapshot()?.where((a) => a.steamId == steamId).firstOrNull;
          if (account == null) throw SyncComparisonChanged();
          final fullPayload = syncPayloadJson(account, includePassword: true);
          final hash = payloadHash(fullPayload);
          if (!await trash.put(steamId: steamId, accountName: item.name,
              payload: fullPayload, reason: SyncTrashReason.remoteDelete,
              passphrase: access.phrase)) {
            throw StateError('Could not save recovery copy');
          }
          final current = accounts.snapshot()?.where((a) => a.steamId == steamId).firstOrNull;
          if (current == null || payloadHash(syncPayloadJson(current,
              includePassword: true)) != hash) {
            throw SyncComparisonChanged();
          }
          await _applyRemoteChange(() => accounts.removeAccount(steamId));
          final state = await configStore.loadState();
          await configStore.saveState(SyncLocalState(
            base: {...state.base}..remove(steamId),
            tombstonesSeen: {...state.tombstonesSeen, steamId: item.remoteRevision},
            settingsBase: state.settingsBase, settingsLocalHash: state.settingsLocalHash,
            localContentHashes: {...state.localContentHashes}..remove('account:$steamId'),
            remoteContentHashes: state.remoteContentHashes,
          ));
        } finally {
          transport.close();
        }
      });
    } else if (item.kind != SyncComparisonKind.same) {
      throw StateError('Choose an available copy in the comparison screen');
    }
    _publish(status.copyWith(conflicts:
        status.conflicts.where((c) => c.steamId != steamId).toList()));
  }
  // ─── Settings mutations ────────────────────────────────────────────────

  Future<void> setAutoSync(bool enabled) async {
    final config = await configStore.loadConfig();
    if (config == null) return;
    await configStore.saveConfig(config.copyWith(autoSync: enabled));
  }

  /// Saves the legacy settings option without starting a transfer.
  Future<void> setSyncSettings(bool enabled) async {
    final config = await configStore.loadConfig();
    if (config == null) return;
    await configStore.saveConfig(config.copyWith(syncSettings: enabled));
  }

  Future<void> setUploadSelection(SyncSelection selection) async {
    final config = await configStore.loadConfig();
    if (config != null) {
      await configStore.saveConfig(config.copyWith(uploadSelection: selection));
    }
  }

  Future<void> setPullSelection(SyncSelection selection) async {
    final config = await configStore.loadConfig();
    if (config != null) {
      await configStore.saveConfig(config.copyWith(pullSelection: selection));
    }
  }

  /// Flips whether payloads carry the account password. Marks a full
  /// re-push: the remote ciphertext must change for every account, not just
  /// the ones whose payload hash moved.
  Future<void> setSyncPasswords(bool enabled) async {
    final config = await configStore.loadConfig();
    if (config == null) return;
    await configStore.saveConfig(
        config.copyWith(syncPasswords: enabled, forcePushPending: true));
  }

  /// Accepts a re-entered passphrase after [SyncErrorKind.passphrase],
  /// verifying it against the remote before storing.
  Future<bool> providePassphrase(String passphrase) async {
    final config = await configStore.loadConfig();
    final webdavPassword = await configStore.loadWebdavPassword();
    if (config == null || webdavPassword == null) return false;
    final transport = transportFactory(config, webdavPassword);
    try {
      final sidecarFile = await transport.getFile(kSyncSidecarFilename);
      if (sidecarFile != null) {
        final remote = SyncSidecar.parse(utf8.decode(sidecarFile.bytes));
        final check = verifyPasskeyCheck(passphrase, remote.passkeyCheck);
        if (check == false) return false;
        if (check == null && remote.accounts.isNotEmpty) {
          // Older remote without a check token: test-decrypt one entry.
          final probe = remote.accounts.values.first;
          if (await _fetchPayload(transport, probe, passphrase) == null) {
            return false;
          }
        }
        await configStore.saveConfig(
            config.copyWith(passphraseEpoch: remote.passphraseEpoch));
      }
      await configStore.savePassphrase(passphrase);
      _publish(_status.copyWith(
          needsPassphrase: false, errorKind: SyncErrorKind.none));
      return true;
    } finally {
      transport.close();
    }
  }

  /// Changes the sync passphrase: bumps the epoch, re-encrypts everything.
  /// Rotation preserves the current remote plaintext, including settings not synced
  /// by this device and concurrent edits encountered during commit retries.
  Future<String?> changePassphrase(String newPassphrase) {
    final run = _rounds.then((_) => _changePassphrase(newPassphrase));
    _rounds = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<String?> _changePassphrase(String newPassphrase) async {
    var config = await configStore.loadConfig();
    if (config == null) return 'not configured';
    if (config.forcePushPending &&
        await configStore.loadPreviousPassphrase() != null) {
      return 'passphrase change pending';
    }
    if (accounts.snapshot() == null) return 'account store is locked';
    if (config.forcePushPending) return 'password policy change pending';
    final previousPassphrase = await configStore.loadPassphrase();
    if (previousPassphrase == null || previousPassphrase.isEmpty) {
      return 'missing stored sync passphrase';
    }
    final password = await configStore.loadWebdavPassword();
    if (password == null) return 'missing sync credentials';
    final transport = transportFactory(config, password);
    try {
      final file = await transport.getFile(kSyncSidecarFilename);
      if (file != null) {
        final remote = SyncSidecar.parse(utf8.decode(file.bytes));
        if (verifyPasskeyCheck(previousPassphrase, remote.passkeyCheck) == false) {
          return 'stored passphrase no longer opens the remote';
        }
        config = config.copyWith(passphraseEpoch: remote.passphraseEpoch);
      }
    } finally {
      transport.close();
    }
    // Save the old key before replacing anything. It is secure-storage-only
    // and survives failed PUTs/restarts until the new sidecar is committed.
    await configStore.savePreviousPassphrase(previousPassphrase);
    try {
      await configStore.savePassphrase(newPassphrase);
      await configStore.saveConfig(config.copyWith(
        passphraseEpoch: config.passphraseEpoch + 1,
        forcePushPending: true,
      ));
    } catch (_) {
      // A failed config write must not leave the current key ahead of the
      // unchanged remote. Keep the recovery slot until a successful round.
      await configStore.savePassphrase(previousPassphrase);
      rethrow;
    }
    // The forced round re-encrypts every payload and commits the new epoch
    // plus a fresh passkey_check (see the epoch check in _attemptRound).
    await _runRound(rotationOnly: true);
    if (_status.hasError) return _status.errorDetail ?? 'sync failed';
    if ((await configStore.loadConfig())?.forcePushPending == true) {
      return 'passphrase change pending';
    }
    return null;
  }

  /// Fetches the current remote sidecar for the read-only "view remote"
  /// screen. Null when unconfigured or the remote has no sidecar yet.
  Future<SyncSidecar?> fetchRemoteSidecar() async {
    final config = await configStore.loadConfig();
    final webdavPassword = await configStore.loadWebdavPassword();
    if (config == null || webdavPassword == null) return null;
    final transport = transportFactory(config, webdavPassword);
    try {
      final file = await transport.getFile(kSyncSidecarFilename);
      if (file == null) return null;
      return SyncSidecar.parse(utf8.decode(file.bytes));
    } finally {
      transport.close();
    }
  }

  /// Disconnects sync. [deleteRemote] additionally removes every file the
  /// sidecar references plus manifest + sidecar (the caller has already put
  /// the long-press confirmation in front of this).
  Future<void> disconnect({required bool deleteRemote}) async {
    final config = await configStore.loadConfig();
    if (config != null && deleteRemote) {
      final webdavPassword = await configStore.loadWebdavPassword();
      if (webdavPassword != null) {
        final transport = transportFactory(config, webdavPassword);
        try {
          final sidecarFile = await transport.getFile(kSyncSidecarFilename);
          if (sidecarFile != null) {
            final remote = SyncSidecar.parse(utf8.decode(sidecarFile.bytes));
            for (final a in remote.accounts.values) {
              await transport.deleteFile(a.filename);
            }
            final s = remote.settings;
            if (s != null) await transport.deleteFile(s.filename);
          }
          await transport.deleteFile(kSyncManifestFilename);
          await transport.deleteFile(kSyncSidecarFilename);
        } finally {
          transport.close();
        }
      }
    }
    _debounceTimer?.cancel();
    await configStore.clearAll();
    _publish(const SyncEngineStatus(configured: false));
  }
}

/// A sidecar commit whose guard failed, and the sidecar version it was based
/// on (both null when the sidecar did not exist yet). A real race always
/// moves the sidecar before the retry re-reads it; an identical base means
/// the guard failed against a sidecar nobody touched.
class _LostCommit {
  final String? etag;
  final Uint8List? sidecar;
  const _LostCommit(this.etag, this.sidecar);

  bool sameBaseAs(_LostCommit other) =>
      etag == other.etag &&
      const ListEquality<int>().equals(sidecar, other.sidecar);
}
