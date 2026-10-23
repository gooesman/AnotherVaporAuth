part of 'sync_engine.dart';

enum SyncComparisonKind {
  same,
  localOnly,
  remoteOnly,
  localChanged,
  remoteChanged,
  bothChanged,
}

/// A reviewed snapshot, not a plan to replace the whole account library.
class SyncComparison {
  final List<SyncComparisonItem> items;
  final DateTime? localSyncAt;
  final DateTime? remoteSyncAt;
  final bool uploadBlockedByPasswordChange;
  final String _configKey;
  final RemoteFile? _sidecar;
  const SyncComparison._(
    this.items,
    this.localSyncAt,
    this.remoteSyncAt,
    this._configKey,
    this._sidecar,
    this.uploadBlockedByPasswordChange,
  );
}

class SyncComparisonItem {
  /// Null identifies the curated settings document (including favorites).
  final int? steamId;
  final Map<String, dynamic>? local;
  final Map<String, dynamic>? remote;
  final SyncComparisonKind kind;
  final int remoteRevision;
  final bool remoteDeleted;
  final String? _localHash;
  final String? _remoteHash;
  SyncComparisonItem._(
    this.steamId,
    this.local,
    this.remote,
    this.kind,
    this.remoteRevision,
    this.remoteDeleted,
  ) : _localHash = local == null ? null : payloadHash(local),
      _remoteHash = remote == null ? null : payloadHash(remote);

  String get name =>
      (local?['account_name'] ?? remote?['account_name'] ?? steamId ?? '')
          .toString();
  bool get canUpload => local != null && kind != SyncComparisonKind.same;
  bool get canPull => remote != null && kind != SyncComparisonKind.same;
}

/// The user must refresh a stale preview, never confirm unseen changes.
class SyncComparisonChanged implements Exception {}

extension SyncComparisonOperations on SyncEngine {
  Future<T> _serializedComparison<T>(Future<T> Function() action) {
    final run = _rounds.then((_) => action());
    _rounds = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Future<({SyncConfig config, String password, String phrase})>
  _comparisonAccess({bool upload = false}) async {
    final config = await configStore.loadConfig();
    final password = await configStore.loadWebdavPassword();
    final phrase = await configStore.loadPassphrase();
    if (config == null ||
        password == null ||
        phrase == null ||
        accounts.snapshot() == null) {
      throw StateError('Sync unavailable or locked');
    }
    // A pending password-upload policy does not restrict read-only comparisons
    // or pulls. Uploads must first finish the whole-account policy cleanup.
    if (config.forcePushPending &&
        (upload || await configStore.loadPreviousPassphrase() != null)) {
      throw StateError('Sync configuration change pending');
    }
    return (config: config, password: password, phrase: phrase);
  }

  String _comparisonKey(SyncConfig config, String phrase) =>
      payloadHash({'config': config.toJson(), 'phrase': phrase});

  SyncSidecar _comparisonSidecar(
    RemoteFile? file,
    String phrase,
    SyncConfig config,
  ) {
    final remote = file == null
        ? const SyncSidecar()
        : SyncSidecar.parse(utf8.decode(file.bytes));
    if (file != null &&
        (remote.passphraseEpoch != config.passphraseEpoch ||
            verifyPasskeyCheck(phrase, remote.passkeyCheck) == false)) {
      throw StateError('Sync configuration changed; synchronize first');
    }
    return remote;
  }

  Future<Map<String, dynamic>> _checkedComparisonPayload(
    SyncTransport transport,
    SyncRemoteAccount entry,
    String phrase,
    int? steamId,
  ) async {
    final payload = await _fetchPayload(transport, entry, phrase);
    if (payload == null ||
        payloadHash(payload) != entry.hash ||
        (steamId != null &&
            '${(payload['Session'] as Map?)?['SteamID']}' != '$steamId')) {
      throw StateError('Remote sync data could not be verified');
    }
    return payload;
  }

  Future<Map<String, dynamic>?> _comparisonLocal(
    int? steamId,
    SyncConfig config,
  ) async {
    final all = accounts.snapshot();
    if (all == null) throw StateError('Account store locked');
    if (steamId == null) return settings?.snapshot();
    final account = all.where((a) => a.steamId == steamId).firstOrNull;
    return account == null
        ? null
        : syncPayloadJson(account, includePassword: config.syncPasswords);
  }

  Future<SyncComparison> _compareWithRemote() =>
      _serializedComparison(() async {
        final access = await _comparisonAccess();
        final transport = transportFactory(access.config, access.password);
        try {
          final file = await transport.getFile(kSyncSidecarFilename);
          final remote = _comparisonSidecar(file, access.phrase, access.config);
          final state = await configStore.loadState();
          final all = accounts.snapshot();
          if (all == null) throw StateError('Account store locked');
          final ids = {
            ...all.map((a) => a.steamId),
            ...remote.accounts.keys,
          }.toList()..sort();
          final items = <SyncComparisonItem>[];
          Future<void> add(
            int? id,
            SyncRemoteAccount? entry,
            SyncBaseEntry? base,
            String? localBaseHash,
          ) async {
            final local = await _comparisonLocal(id, access.config);
            final payload = entry == null
                ? null
                : await _checkedComparisonPayload(
                    transport,
                    entry,
                    access.phrase,
                    id,
                  );
            if (local == null && payload == null) return;
            final localHash = local == null ? null : payloadHash(local);
            var kind = localHash == entry?.hash && local != null
                ? SyncComparisonKind.same
                : local == null
                ? SyncComparisonKind.remoteOnly
                : payload == null
                ? SyncComparisonKind.localOnly
                : base == null
                ? SyncComparisonKind.bothChanged
                : localHash == (localBaseHash ?? base.hash) &&
                      entry?.hash != base.hash
                ? SyncComparisonKind.remoteChanged
                : entry?.hash == base.hash &&
                      localHash != (localBaseHash ?? base.hash)
                ? SyncComparisonKind.localChanged
                : SyncComparisonKind.bothChanged;
            if (id == null &&
                local != null &&
                payload != null &&
                localHash != entry?.hash &&
                state.remoteContentHashes.isNotEmpty) {
              var localChanged = false;
              var remoteChanged = false;
              for (final group in _settingsSelections.entries) {
                localChanged |=
                    payloadHash(group.value.selectSettings(local)) !=
                    state.localContentHashes[group.key];
                remoteChanged |=
                    payloadHash(group.value.selectSettings(payload)) !=
                    state.remoteContentHashes[group.key];
              }
              kind = localChanged && !remoteChanged
                  ? SyncComparisonKind.localChanged
                  : remoteChanged && !localChanged
                  ? SyncComparisonKind.remoteChanged
                  : SyncComparisonKind.bothChanged;
            }
            items.add(
              SyncComparisonItem._(
                id,
                local,
                payload,
                kind,
                entry?.rev ?? remote.tombstones[id]?.rev ?? 0,
                id != null && remote.tombstones.containsKey(id),
              ),
            );
          }

          for (final id in ids) {
            await add(id, remote.accounts[id], state.base[id], null);
          }
          if (settings != null) {
            await add(
              null,
              remote.settings,
              state.settingsBase,
              state.settingsLocalHash,
            );
          }
          if (accounts.snapshot() == null) {
            throw StateError('Account store locked');
          }
          final dates =
              remote.devices.values
                  .map((d) => DateTime.tryParse(d.lastSyncAt ?? ''))
                  .whereType<DateTime>()
                  .toList()
                ..sort();
          return SyncComparison._(
            List.unmodifiable(items),
            status.lastSyncAt,
            dates.isEmpty ? null : dates.last,
            _comparisonKey(access.config, access.phrase),
            file,
            access.config.forcePushPending,
          );
        } finally {
          transport.close();
        }
      });

  /// Applies only the selected row. Other accounts/settings remain untouched.
  Future<void> _applyComparison(
    SyncComparison preview,
    SyncComparisonItem item, {
    required bool upload,
  }) => _serializedComparison(() async {
    if (!preview.items.contains(item) ||
        !(upload ? item.canUpload : item.canPull)) {
      throw StateError('Invalid comparison selection');
    }
    final access = await _comparisonAccess(upload: upload);
    if (_comparisonKey(access.config, access.phrase) != preview._configKey) {
      throw SyncComparisonChanged();
    }
    final transport = transportFactory(access.config, access.password);
    _publish(status.copyWith(syncing: true));
    try {
      final file = await transport.getFile(kSyncSidecarFilename);
      if (file?.etag != preview._sidecar?.etag ||
          !const ListEquality<int>().equals(
            file?.bytes,
            preview._sidecar?.bytes,
          )) {
        throw SyncComparisonChanged();
      }
      final remote = _comparisonSidecar(file, access.phrase, access.config);
      Future<void> checkLocal() async {
        final config = await configStore.loadConfig();
        if (config == null ||
            _comparisonKey(config, access.phrase) != preview._configKey) {
          throw SyncComparisonChanged();
        }
        final current = await _comparisonLocal(item.steamId, access.config);
        if ((current == null ? null : payloadHash(current)) !=
                item._localHash ||
            (item.local == null ? null : payloadHash(item.local!)) !=
                item._localHash ||
            (item.remote == null ? null : payloadHash(item.remote!)) !=
                item._remoteHash) {
          throw SyncComparisonChanged();
        }
      }

      await checkLocal();
      final reviewedAccount = item.steamId == null
          ? null
          : accounts
                .snapshot()
                ?.where((account) => account.steamId == item.steamId)
                .firstOrNull;
      final reviewedAccountPayload = reviewedAccount == null
          ? null
          : jsonDecode(
                  jsonEncode(
                    syncPayloadJson(reviewedAccount, includePassword: true),
                  ),
                )
                as Map<String, dynamic>;
      final reviewedLocalHash = reviewedAccountPayload == null
          ? null
          : payloadHash(reviewedAccountPayload);
      final state = await configStore.loadState();
      final id = item.steamId;
      final oldEntry = id == null ? remote.settings : remote.accounts[id];
      final losing = upload
          ? item.remote
          : reviewedAccountPayload ?? item.local;
      if (id != null &&
          losing != null &&
          !await trash.put(
            steamId: id,
            accountName: losing['account_name'] as String?,
            payload: losing,
            reason: upload
                ? SyncTrashReason.conflictRemote
                : SyncTrashReason.conflictLocal,
            passphrase: access.phrase,
          )) {
        throw StateError('Could not save recovery copy');
      }
      SyncRemoteAccount entry;
      if (upload) {
        // Explicit overwrite still requires an atomic server commit.
        if (access.config.conditionalUnsupported ||
            (file != null && file.etag == null)) {
          throw StateError('Server does not support conditional updates');
        }
        final devId = await deviceId();
        final baseRev =
            (id == null ? state.settingsBase : state.base[id])?.rev ?? 0;
        final rev =
            (baseRev > item.remoteRevision ? baseRev : item.remoteRevision) + 1;
        final payload = {...item.local!};
        if (id != null && !remote.includePasswords) payload.remove('password');
        final enc = encryptSyncPayload(access.phrase, payload);
        // Random IV suffix keeps a losing 412 attempt from replacing a live blob.
        final nonce = base64Url
            .encode(base64.decode(enc.iv))
            .replaceAll('=', '');
        final filename =
            '${id ?? 'ava.settings'}.r$rev.$nonce.${id == null ? 'json' : 'maFile'}';
        entry = SyncRemoteAccount(
          rev: rev,
          hash: payloadHash(payload),
          filename: filename,
          salt: enc.salt,
          iv: enc.iv,
        );
        if (file == null) await transport.ensureRoot();
        await checkLocal();
        await transport.putFile(
          filename,
          Uint8List.fromList(utf8.encode(enc.ciphertext)),
        );
        final nextAccounts = {...remote.accounts, ?id: entry};
        final tombstones = {...remote.tombstones}..remove(id);
        final check = remote.passkeyCheck ?? buildPasskeyCheck(access.phrase);
        final next = remote.copyWith(
          accounts: nextAccounts,
          tombstones: tombstones,
          settings: id == null ? entry : null,
          passkeyCheck: check,
          includePasswords: remote.includePasswords,
          devices: {
            ...remote.devices,
            devId: SyncDeviceInfo(
              name: access.config.deviceName,
              lastSyncAt: now().toUtc().toIso8601String(),
            ),
          },
        );
        // Bind the compatibility mirror to this commit's payload and to the
        // manifest version observed BEFORE its authoritative sidecar CAS.
        // Reading a fresh manifest ETag after committing could pair another
        // writer's staged manifest with our older sidecar and overwrite it.
        final updateManifest = id != null || file == null;
        final manifest = updateManifest
            ? await transport.getFile(kSyncManifestFilename)
            : null;
        final manifestBytes = updateManifest
            ? Uint8List.fromList(
                utf8.encode(buildRemoteManifest(nextAccounts, check)),
              )
            : null;
        await checkLocal();
        await transport.putFile(
          kSyncSidecarFilename,
          Uint8List.fromList(utf8.encode(next.serialize())),
          ifMatch: file?.etag,
          ifAbsent: file == null,
        );
        // A rejected sidecar commit must never alter SDA's manifest.
        if (manifestBytes != null) {
          await _writeComparisonManifest(transport, manifest, manifestBytes);
        }
      } else {
        entry = oldEntry!;
        await checkLocal();
        if (id == null) {
          final incoming = {...item.remote!};
          if (incoming.containsKey('market_favorites')) {
            incoming['market_favorites'] = _mergeFavorites(
              item.local?['market_favorites'],
              incoming['market_favorites'],
            );
          }
          await _applyRemoteChange(() => settings!.apply(incoming));
        } else {
          await _applyRemoteChange(() => accounts.applyRemote(item.remote!));
        }
      }
      final settingsAfter = id == null ? await settings!.snapshot() : null;
      final localContentHashes = {...state.localContentHashes};
      final remoteContentHashes = {...state.remoteContentHashes};
      if (id == null && settingsAfter != null) {
        final localDocument = upload ? item.local! : settingsAfter;
        final remoteDocument = upload ? item.local! : item.remote!;
        for (final group in _settingsSelections.entries) {
          localContentHashes[group.key] = payloadHash(
            group.value.selectSettings(localDocument),
          );
          remoteContentHashes[group.key] = payloadHash(
            group.value.selectSettings(remoteDocument),
          );
        }
      } else if (id != null) {
        final after = accounts
            .snapshot()
            ?.where((a) => a.steamId == id)
            .firstOrNull;
        if (after != null) {
          localContentHashes['account:$id'] = upload
              ? reviewedLocalHash!
              : payloadHash(syncPayloadJson(after, includePassword: true));
        }
      }
      await configStore.saveState(
        SyncLocalState(
          base: {
            ...state.base,
            ?id: SyncBaseEntry(rev: entry.rev, hash: entry.hash),
          },
          tombstonesSeen: {...state.tombstonesSeen}..remove(id),
          settingsBase: id == null
              ? SyncBaseEntry(rev: entry.rev, hash: entry.hash)
              : state.settingsBase,
          settingsLocalHash: id == null
              ? (upload
                    ? entry.hash
                    : settingsAfter == null
                    ? null
                    : payloadHash(settingsAfter))
              : state.settingsLocalHash,
          localContentHashes: localContentHashes,
          remoteContentHashes: remoteContentHashes,
        ),
      );
      _publish(
        status.copyWith(
          lastSyncAt: now(),
          errorKind: SyncErrorKind.none,
          settingsConflict: id == null ? false : status.settingsConflict,
          conflicts: status.conflicts.where((c) => c.steamId != id).toList(),
          lastPushed: upload ? 1 : 0,
          lastPulled: upload ? 0 : 1,
        ),
      );
    } finally {
      transport.close();
      _publish(status.copyWith(syncing: false));
    }
  });

  Future<void> _writeComparisonManifest(
    SyncTransport transport,
    RemoteFile? previous,
    Uint8List bytes,
  ) async {
    try {
      if (previous != null && previous.etag == null) {
        throw StateError('Manifest cannot be conditionally updated');
      }
      await transport.putFile(
        kSyncManifestFilename,
        bytes,
        ifMatch: previous?.etag,
        ifAbsent: previous == null,
      );
    } catch (_) {
      // The sidecar is authoritative and already committed. A concurrent
      // writer may leave this SDA-only mirror temporarily behind. Never retry
      // this older payload against a newly read ETag or replay the account write.
      dlog('sync: committed comparison; SDA manifest refresh deferred');
    }
  }
}
