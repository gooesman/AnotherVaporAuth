part of 'sync_engine.dart';

const _settingsSelections = <String, SyncSelection>{
  'settings': SyncSelection(
    accounts: false,
    favorites: false,
    acceleration: false,
  ),
  'favorites': SyncSelection(
    accounts: false,
    settings: false,
    acceleration: false,
  ),
  'acceleration': SyncSelection(
    accounts: false,
    settings: false,
    favorites: false,
  ),
};

extension SyncTransfers on SyncEngine {
  Future<void> _queueTransfer({
    required bool upload,
    int? automaticGeneration,
  }) {
    final run = _rounds.then((_) async {
      if (automaticGeneration != null &&
          automaticGeneration != _autoGeneration) {
        return;
      }
      await _runTransfer(
        upload: upload,
        automatic: automaticGeneration != null,
      );
    });
    _rounds = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Future<void> _runTransfer({
    required bool upload,
    bool automatic = false,
  }) async {
    final config = await configStore.loadConfig();
    if (config == null) {
      _publish(status.copyWith(configured: false));
      return;
    }
    final selection = upload ? config.uploadSelection : config.pullSelection;
    if (!selection.any || accounts.snapshot() == null) return;
    final password = await configStore.loadWebdavPassword();
    final phrase = await configStore.loadPassphrase();
    if (password == null || phrase == null || phrase.isEmpty) {
      _publish(
        status.copyWith(
          configured: true,
          needsPassphrase: true,
          errorKind: SyncErrorKind.passphrase,
          errorDetail: 'missing stored sync secrets',
        ),
      );
      return;
    }
    _publish(
      status.copyWith(
        configured: true,
        syncing: true,
        errorKind: SyncErrorKind.none,
        lastPushed: 0,
        lastPulled: 0,
      ),
    );
    SyncTransport? transport;
    try {
      transport = transportFactory(config, password);
      _LostCommit? previous;
      for (
        var attempt = 0;
        attempt <= SyncEngine._maxCommitRetries;
        attempt++
      ) {
        final lost = await _transferAttempt(
          transport,
          config,
          phrase,
          selection: selection,
          upload: upload,
          automatic: automatic,
        );
        if (lost == null) return;
        if (previous != null && lost.sameBaseAs(previous)) {
          throw const SyncPreconditionFailed('Conditional commit was refused');
        }
        previous = lost;
      }
      throw const SyncPreconditionFailed('Remote data kept changing; retry');
    } on SyncTransportException catch (error) {
      _publish(
        status.copyWith(
          errorKind: switch (error) {
            SyncAuthError() => SyncErrorKind.auth,
            SyncTlsUntrusted() => SyncErrorKind.tls,
            SyncNetworkError() => SyncErrorKind.network,
            _ => SyncErrorKind.server,
          },
          errorDetail: 'The sync service could not complete the request',
        ),
      );
    } catch (error) {
      _publish(
        status.copyWith(
          errorKind: SyncErrorKind.io,
          errorDetail: error is SyncComparisonChanged
              ? 'Sync data changed during the operation; retry'
              : 'The selected items could not be transferred; completed items were kept',
        ),
      );
    } finally {
      transport?.close();
      _publish(status.copyWith(syncing: false));
    }
  }

  Future<_LostCommit?> _transferAttempt(
    SyncTransport transport,
    SyncConfig config,
    String phrase, {
    required SyncSelection selection,
    required bool upload,
    required bool automatic,
  }) async {
    final file = await transport.getFile(kSyncSidecarFilename);
    final remote = file == null
        ? const SyncSidecar()
        : SyncSidecar.parse(utf8.decode(file.bytes));
    if (file != null &&
        config.passphraseEpoch <= remote.passphraseEpoch &&
        verifyPasskeyCheck(phrase, remote.passkeyCheck) == false) {
      _publish(
        status.copyWith(
          needsPassphrase: true,
          errorKind: SyncErrorKind.passphrase,
          errorDetail: 'stored passphrase no longer opens the remote',
        ),
      );
      return null;
    }
    if (config.passphraseEpoch > remote.passphraseEpoch) {
      final previous = await configStore.loadPreviousPassphrase();
      if (!upload || !config.forcePushPending || previous == null) {
        throw StateError('Finish the pending passphrase change before pulling');
      }
      return _rotateRemote(transport, config, remote, file, previous, phrase);
    }
    if (remote.passphraseEpoch > config.passphraseEpoch) {
      config = config.copyWith(passphraseEpoch: remote.passphraseEpoch);
      await configStore.saveConfig(config);
    }
    if (upload &&
        file != null &&
        !config.forcePushPending &&
        remote.includePasswords != config.syncPasswords) {
      config = config.copyWith(syncPasswords: remote.includePasswords);
      await configStore.saveConfig(config);
    }
    if (!upload && file == null) {
      _publish(status.copyWith(lastSyncAt: now(), needsPassphrase: false));
      return null;
    }
    final local = accounts.snapshot();
    if (local == null) throw StateError('Account store locked');
    final byId = {for (final account in local) account.steamId: account};
    final accountSnapshots = {
      for (final account in local)
        account.steamId:
            jsonDecode(
                  jsonEncode(syncPayloadJson(account, includePassword: true)),
                )
                as Map<String, dynamic>,
    };
    void checkAccount(int id) {
      final current = accounts
          .snapshot()
          ?.where((account) => account.steamId == id)
          .firstOrNull;
      if ((accountSnapshots[id] == null
              ? null
              : payloadHash(accountSnapshots[id]!)) !=
          (current == null
              ? null
              : payloadHash(syncPayloadJson(current, includePassword: true)))) {
        throw SyncComparisonChanged();
      }
    }

    final settingsSnapshot = selection.anySettings && settings != null
        ? await settings!.snapshot(selection: selection)
        : null;
    final localSettings = settingsSnapshot == null
        ? null
        : jsonDecode(jsonEncode(settingsSnapshot)) as Map<String, dynamic>;
    if (selection.anySettings && settings != null && localSettings == null) {
      throw StateError('Sync settings unavailable');
    }
    final remoteSettings = selection.anySettings && remote.settings != null
        ? await _checkedComparisonPayload(
            transport,
            remote.settings!,
            phrase,
            null,
          )
        : <String, dynamic>{};
    final state = await configStore.loadState();
    final base = {...state.base};
    final seen = {...state.tombstonesSeen};
    final localHashes = {...state.localContentHashes};
    final remoteHashes = {...state.remoteContentHashes};
    var settingsBase = state.settingsBase;
    var settingsLocalHash = state.settingsLocalHash;
    Future<void> saveState() => configStore.saveState(
      SyncLocalState(
        base: base,
        tombstonesSeen: seen,
        settingsBase: settingsBase,
        settingsLocalHash: settingsLocalHash,
        localContentHashes: localHashes,
        remoteContentHashes: remoteHashes,
      ),
    );
    final configKey = _comparisonKey(config, phrase);
    Future<void> requireAvailable() async {
      final current = await configStore.loadConfig();
      if (accounts.snapshot() == null ||
          current == null ||
          _comparisonKey(current, phrase) != configKey) {
        throw SyncComparisonChanged();
      }
    }

    if (!upload) {
      // Verify every selected payload before changing any local account.
      final payloads = <int, Map<String, dynamic>>{};
      if (selection.accounts) {
        for (final entry in remote.accounts.entries) {
          payloads[entry.key] = await _checkedComparisonPayload(
            transport,
            entry.value,
            phrase,
            entry.key,
          );
        }
      }
      final currentFile = await transport.getFile(kSyncSidecarFilename);
      if (currentFile?.etag != file?.etag ||
          !const ListEquality<int>().equals(currentFile?.bytes, file?.bytes)) {
        throw SyncComparisonChanged();
      }
      await requireAvailable();
      for (final entry in payloads.entries) {
        final before = byId[entry.key];
        checkAccount(entry.key);
        if (before != null &&
            payloadHash(accountSnapshots[entry.key]!) !=
                payloadHash(entry.value)) {
          if (!await trash.put(
            steamId: entry.key,
            accountName: before.accountName,
            payload: accountSnapshots[entry.key]!,
            reason: SyncTrashReason.conflictLocal,
            passphrase: phrase,
          )) {
            throw StateError('Could not save recovery copy');
          }
        }
      }
      for (final entry in payloads.entries) {
        await requireAvailable();
        checkAccount(entry.key);
        await _applyRemoteChange(() => accounts.applyRemote(entry.value));
        _publish(status.copyWith(lastPulled: status.lastPulled + 1));
        final after = accounts
            .snapshot()
            ?.where((account) => account.steamId == entry.key)
            .firstOrNull;
        if (after == null) throw StateError('Account store locked');
        final source = remote.accounts[entry.key]!;
        base[entry.key] = SyncBaseEntry(rev: source.rev, hash: source.hash);
        seen.remove(entry.key);
        localHashes['account:${entry.key}'] = payloadHash(
          syncPayloadJson(after, includePassword: true),
        );
        await saveState();
      }
      if (localSettings != null && remote.settings != null) {
        for (final group in _selectedSettings(selection)) {
          final part = group.value.selectSettings(remoteSettings);
          if (part.isEmpty) continue; // An older document omitted this section.
          await requireAvailable();
          final current = await settings!.snapshot(selection: group.value);
          if (current == null ||
              payloadHash(current) !=
                  payloadHash(group.value.selectSettings(localSettings))) {
            throw SyncComparisonChanged();
          }
          final applied = {...part};
          if (group.key == 'favorites') {
            applied['market_favorites'] = _mergeFavorites(
              current['market_favorites'],
              part['market_favorites'],
            );
          }
          await _applyRemoteChange(() => settings!.apply(applied));
          _publish(status.copyWith(lastPulled: status.lastPulled + 1));
          final after = await settings!.snapshot(selection: group.value);
          if (after == null) throw StateError('Sync settings unavailable');
          localHashes[group.key] = payloadHash(after);
          remoteHashes[group.key] = payloadHash(part);
          settingsBase = null;
          settingsLocalHash = null;
          await saveState();
        }
      }
      _publish(
        status.copyWith(
          lastSyncAt: now(),
          needsPassphrase: false,
          conflicts: selection.accounts ? const [] : status.conflicts,
          settingsConflict: selection.anySettings
              ? status.settingsConflict && !_allSettingsSelected(selection)
              : status.settingsConflict,
        ),
      );
      return null;
    }

    if (config.conditionalUnsupported || (file != null && file.etag == null)) {
      throw StateError('Server does not support conditional updates');
    }
    final updates = <int, Map<String, dynamic>>{};
    final localUpdates = <int>{};
    final conflicts = <SyncConflictItem>[];
    final pendingPolicy = config.forcePushPending && selection.accounts;
    if (selection.accounts) {
      for (final account in local) {
        final id = account.steamId;
        final payload = {...accountSnapshots[id]!};
        if (!config.syncPasswords) payload.remove('password');
        final hash = payloadHash(payload);
        final localHash = payloadHash(accountSnapshots[id]!);
        final entry = remote.accounts[id];
        final key = 'account:$id';
        final previousHash = localHashes[key] ?? base[id]?.hash;
        if (entry?.hash == hash) {
          localHashes[key] = localHash;
          base[id] = SyncBaseEntry(rev: entry!.rev, hash: entry.hash);
          continue;
        }
        if (automatic) {
          if (previousHash == null && entry != null) {
            localHashes[key] = localHash;
            continue;
          }
          if (previousHash == localHash) continue;
          final changedRemote = entry != null && base[id]?.hash != entry.hash;
          if (changedRemote || remote.tombstones.containsKey(id)) {
            conflicts.add(
              SyncConflictItem(
                steamId: id,
                kind: entry == null
                    ? SyncConflictKind.editDelete
                    : SyncConflictKind.editEdit,
                localPayload: payload,
                remotePayload: entry == null
                    ? null
                    : await _checkedComparisonPayload(
                        transport,
                        entry,
                        phrase,
                        id,
                      ),
                remote: entry,
                tombstone: remote.tombstones[id],
              ),
            );
            continue;
          }
        }
        updates[id] = payload;
        localUpdates.add(id);
      }
    }
    // A password-policy change also strips passwords from remote-only accounts.
    // It never imports those accounts or replaces their other fields.
    if (pendingPolicy && !config.syncPasswords) {
      for (final entry in remote.accounts.entries) {
        final payload =
            updates[entry.key] ??
            await _checkedComparisonPayload(
              transport,
              entry.value,
              phrase,
              entry.key,
            );
        final stripped = {...payload}..remove('password');
        if (payloadHash(stripped) != entry.value.hash) {
          updates[entry.key] = stripped;
        }
      }
    }
    final nextSettings = {...remoteSettings};
    final changedGroups = <String>[];
    var settingsConflict = false;
    if (localSettings != null) {
      for (final group in _selectedSettings(selection)) {
        final part = group.value.selectSettings(localSettings);
        if (part.isEmpty) continue;
        final hash = payloadHash(part);
        final remoteHash = payloadHash(
          group.value.selectSettings(remoteSettings),
        );
        if (hash == remoteHash) {
          localHashes[group.key] = hash;
          remoteHashes[group.key] = remoteHash;
          continue;
        }
        if (automatic) {
          final previous = localHashes[group.key];
          if (previous == null && remote.settings != null) {
            localHashes[group.key] = hash;
            remoteHashes[group.key] = remoteHash;
            continue;
          }
          if (previous == hash) continue;
          if (remote.settings != null &&
              remoteHashes[group.key] != remoteHash) {
            settingsConflict = true;
            continue;
          }
        }
        nextSettings.addAll(part);
        changedGroups.add(group.key);
      }
    }
    final policyChanged =
        pendingPolicy && remote.includePasswords != config.syncPasswords;
    if (updates.isEmpty && changedGroups.isEmpty && !policyChanged) {
      await saveState();
      if (pendingPolicy) {
        await configStore.saveConfig(config.copyWith(forcePushPending: false));
      }
      _publish(
        status.copyWith(
          lastSyncAt: now(),
          needsPassphrase: false,
          conflicts: selection.accounts ? conflicts : status.conflicts,
          settingsConflict:
              settingsConflict ||
              (status.settingsConflict && !_allSettingsSelected(selection)),
        ),
      );
      return null;
    }
    await requireAvailable();
    for (final entry in updates.entries) {
      final old = remote.accounts[entry.key];
      if (old == null) continue;
      final payload = await _checkedComparisonPayload(
        transport,
        old,
        phrase,
        entry.key,
      );
      if (!await trash.put(
        steamId: entry.key,
        accountName: payload['account_name'] as String?,
        payload: payload,
        reason: SyncTrashReason.conflictRemote,
        passphrase: phrase,
      )) {
        throw StateError('Could not save recovery copy');
      }
    }
    final nextAccounts = {...remote.accounts};
    final tombstones = {...remote.tombstones};
    Future<SyncRemoteAccount> write(
      Map<String, dynamic> payload,
      String stem,
      int revision,
      String extension,
    ) async {
      final encrypted = encryptSyncPayload(phrase, payload);
      final nonce = base64Url
          .encode(base64.decode(encrypted.iv))
          .replaceAll('=', '');
      final filename = '$stem.r$revision.$nonce.$extension';
      await transport.putFile(
        filename,
        Uint8List.fromList(utf8.encode(encrypted.ciphertext)),
      );
      return SyncRemoteAccount(
        rev: revision,
        hash: payloadHash(payload),
        filename: filename,
        salt: encrypted.salt,
        iv: encrypted.iv,
      );
    }

    if (file == null) await transport.ensureRoot();
    for (final entry in updates.entries) {
      final remoteRev =
          remote.accounts[entry.key]?.rev ??
          remote.tombstones[entry.key]?.rev ??
          0;
      final baseRev = base[entry.key]?.rev ?? 0;
      nextAccounts[entry.key] = await write(
        entry.value,
        '${entry.key}',
        (remoteRev > baseRev ? remoteRev : baseRev) + 1,
        'maFile',
      );
      tombstones.remove(entry.key);
    }
    final settingsEntry = changedGroups.isEmpty
        ? remote.settings
        : await write(
            nextSettings,
            'ava.settings',
            (remote.settings?.rev ?? 0) + 1,
            'json',
          );
    final devId = await deviceId();
    final check = remote.passkeyCheck ?? buildPasskeyCheck(phrase);
    final next = remote.copyWith(
      accounts: nextAccounts,
      tombstones: tombstones,
      settings: settingsEntry,
      passkeyCheck: check,
      includePasswords: pendingPolicy || file == null
          ? config.syncPasswords
          : remote.includePasswords,
      devices: {
        ...remote.devices,
        devId: SyncDeviceInfo(
          name: config.deviceName,
          lastSyncAt: now().toUtc().toIso8601String(),
        ),
      },
    );
    final updateManifest = updates.isNotEmpty || file == null;
    final manifest = updateManifest
        ? await transport.getFile(kSyncManifestFilename)
        : null;
    await requireAvailable();
    // User edits while network requests were in flight must get a fresh round.
    for (final entry in updates.entries) {
      if (localUpdates.contains(entry.key)) checkAccount(entry.key);
    }
    if (localSettings != null) {
      final current = await settings!.snapshot(selection: selection);
      if (current == null ||
          payloadHash(current) != payloadHash(localSettings)) {
        throw SyncComparisonChanged();
      }
    }
    try {
      await transport.putFile(
        kSyncSidecarFilename,
        Uint8List.fromList(utf8.encode(next.serialize())),
        ifMatch: file?.etag,
        ifAbsent: file == null,
      );
    } on SyncPreconditionFailed {
      return _LostCommit(file?.etag, file?.bytes);
    }
    _publish(
      status.copyWith(lastPushed: updates.length + changedGroups.length),
    );
    if (updateManifest) {
      await _writeComparisonManifest(
        transport,
        manifest,
        Uint8List.fromList(
          utf8.encode(buildRemoteManifest(nextAccounts, check)),
        ),
      );
    }
    for (final id in updates.keys) {
      final entry = nextAccounts[id]!;
      if (localUpdates.contains(id)) {
        base[id] = SyncBaseEntry(rev: entry.rev, hash: entry.hash);
        seen.remove(id);
        localHashes['account:$id'] = payloadHash(accountSnapshots[id]!);
      }
    }
    if (changedGroups.isNotEmpty) {
      settingsBase = null;
      settingsLocalHash = null;
      for (final group in changedGroups) {
        final hash = payloadHash(
          _settingsSelections[group]!.selectSettings(nextSettings),
        );
        localHashes[group] = hash;
        remoteHashes[group] = hash;
      }
    }
    await saveState();
    if (pendingPolicy) {
      await configStore.saveConfig(config.copyWith(forcePushPending: false));
    }
    final superseded = [
      for (final id in updates.keys)
        if (remote.accounts[id] != null) remote.accounts[id]!,
      if (changedGroups.isNotEmpty && remote.settings != null) remote.settings!,
    ];
    for (final entry in superseded) {
      try {
        await transport.deleteFile(entry.filename);
      } catch (_) {
        /* A committed update remains valid if cleanup fails. */
      }
    }
    _publish(
      status.copyWith(
        lastSyncAt: now(),
        needsPassphrase: false,
        conflicts: selection.accounts ? conflicts : status.conflicts,
        settingsConflict:
            settingsConflict ||
            (status.settingsConflict && !_allSettingsSelected(selection)),
      ),
    );
    return null;
  }
}

Iterable<MapEntry<String, SyncSelection>> _selectedSettings(
  SyncSelection selected,
) => _settingsSelections.entries.where(
  (entry) => switch (entry.key) {
    'settings' => selected.settings,
    'favorites' => selected.favorites,
    _ => selected.acceleration,
  },
);

bool _allSettingsSelected(SyncSelection selection) =>
    selection.settings && selection.favorites && selection.acceleration;

/// Keep local-only favorites; the remote wins for the same product and currency.
Map<String, dynamic> _mergeFavorites(Object? local, Object? remote) {
  Map<String, dynamic> checked(Object? raw) {
    if (raw == null) return {'items': <dynamic>[], 'currency': null};
    if (raw is! Map) throw const FormatException('Invalid market favorites');
    final value = raw.cast<String, dynamic>();
    final currency = value['currency'];
    if (value['items'] is! List ||
        (currency != null &&
            (currency is! int || currency < 1 || currency > 32))) {
      throw const FormatException('Invalid market favorites');
    }
    for (final item in value['items'] as List) {
      if (item is! Map ||
          item['appid'] is! int ||
          (item['appid'] as int) <= 0 ||
          item['market_hash_name'] is! String ||
          (item['market_hash_name'] as String).isEmpty ||
          (item['market_hash_name'] as String).length > 4096 ||
          const ['name', 'icon_url', 'type', 'rarity_color'].any(
            (key) =>
                item[key] is! String || (item[key] as String).length > 8192,
          )) {
        throw const FormatException('Invalid market favorite');
      }
    }
    return value;
  }

  final first = checked(local);
  if (remote == null) throw const FormatException('Invalid market favorites');
  final second = checked(remote);
  final items = <(int, String), dynamic>{};
  for (final item in [...first['items'] as List, ...second['items'] as List]) {
    items[(item['appid'] as int, item['market_hash_name'] as String)] = item;
  }
  return {...first, ...second, 'items': items.values.toList()};
}
