/// Persistence for the sync feature's configuration and per-device state.
///
/// Three storage tiers, split by sensitivity:
///  - `sync_config.json` (next to app_settings.json): server URL, username,
///    options, cert pins, HTTP overrides — restorable, not secret.
///  - `sync_state.json` (same place): this device's merge base (last-synced
///    rev + payload hash per account, tombstones seen). Hashes only — no
///    secrets — and losing the file is safe: the next round re-merges from
///    scratch, degenerating to first-connect semantics.
///  - flutter_secure_storage: the WebDAV password, sync passphrase, and the
///    previous passphrase during a pending explicit rotation. These never
///    touch a JSON file.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../../core/sync/sync_planner.dart';
import '../../core/sync/sync_selection.dart';
import '../storage_provider.dart';

export '../../core/sync/sync_selection.dart';

class SyncConfig {
  /// Only 'webdav' today; 'gdrive' is reserved for the Pro backend.
  final String backend;
  final String url;
  final String username;

  /// Human-readable name of this device, shown in the remote device table.
  final String deviceName;
  final bool autoSync;
  final bool syncPasswords;

  /// Whether the curated app-settings document syncs too (2026-08-12 user
  /// decision: default on). Device-specific preferences (language, text
  /// size) are never part of the document regardless of this flag.
  final bool syncSettings;

  final SyncSelection? _uploadSelection;
  final SyncSelection? _pullSelection;
  SyncSelection get uploadSelection =>
      _uploadSelection ??
      SyncSelection(
        settings: syncSettings,
        favorites: syncSettings,
        acceleration: syncSettings,
      );
  SyncSelection get pullSelection =>
      _pullSelection ??
      SyncSelection(
        settings: syncSettings,
        favorites: syncSettings,
        acceleration: syncSettings,
      );

  /// Passphrase epoch this device's stored passphrase belongs to; compared
  /// against the remote sidecar to detect a passphrase change made elsewhere.
  final int passphraseEpoch;

  /// Hosts explicitly allowed to use plain HTTP despite being public.
  final Set<String> httpOverrides;

  /// host → lowercase hex SHA-256 of the pinned certificate DER.
  final Map<String, String> pinnedCerts;

  /// Set when the setup probe found the server ignoring conditional PUTs
  /// (the optimistic lock is then advisory) — the UI shows a warning.
  final bool conditionalUnsupported;

  /// Set when the include-passwords toggle (or a passphrase change) demands
  /// a full re-push on the next round even for unchanged payloads.
  final bool forcePushPending;

  const SyncConfig({
    this.backend = 'webdav',
    required this.url,
    required this.username,
    required this.deviceName,
    this.autoSync = true,
    this.syncPasswords = true,
    this.syncSettings = true,
    this.passphraseEpoch = 1,
    this.httpOverrides = const {},
    this.pinnedCerts = const {},
    this.conditionalUnsupported = false,
    this.forcePushPending = false,
    SyncSelection? uploadSelection,
    SyncSelection? pullSelection,
  // Public arguments retain the old syncSettings fallback for const callers.
  // ignore: prefer_initializing_formals
  }) : _uploadSelection = uploadSelection,
       // ignore: prefer_initializing_formals
       _pullSelection = pullSelection;

  factory SyncConfig.fromJson(Map<String, dynamic> json) => SyncConfig(
        backend: (json['backend'] as String?) ?? 'webdav',
        url: (json['url'] as String?) ?? '',
        username: (json['username'] as String?) ?? '',
        deviceName: (json['device_name'] as String?) ?? '',
        autoSync: json['auto_sync'] != false,
        syncPasswords: json['sync_passwords'] != false,
        syncSettings: json['sync_settings'] != false,
    uploadSelection: SyncSelection.fromJson(
      json['upload_selection'],
      legacySettings: json['sync_settings'] != false,
    ),
    pullSelection: SyncSelection.fromJson(
      json['pull_selection'],
      legacySettings: json['sync_settings'] != false,
    ),
        passphraseEpoch: (json['passphrase_epoch'] as num?)?.toInt() ?? 1,
        httpOverrides: {
          for (final h in (json['http_overrides'] as List? ?? const []))
        h.toString(),
    },
        pinnedCerts: {
      for (final e in ((json['pinned_certs'] as Map?) ?? const {}).entries)
        e.key.toString(): e.value.toString(),
    },
        conditionalUnsupported: json['conditional_unsupported'] == true,
        forcePushPending: json['force_push_pending'] == true,
  );

  Map<String, dynamic> toJson() => {
        'backend': backend,
        'url': url,
        'username': username,
        'device_name': deviceName,
        'auto_sync': autoSync,
        'sync_passwords': syncPasswords,
        'sync_settings': syncSettings,
    'upload_selection': uploadSelection.toJson(),
    'pull_selection': pullSelection.toJson(),
        'passphrase_epoch': passphraseEpoch,
        'http_overrides': [...httpOverrides],
        'pinned_certs': pinnedCerts,
        'conditional_unsupported': conditionalUnsupported,
        'force_push_pending': forcePushPending,
  };

  SyncConfig copyWith({
    bool? autoSync,
    bool? syncPasswords,
    bool? syncSettings,
    int? passphraseEpoch,
    Set<String>? httpOverrides,
    Map<String, String>? pinnedCerts,
    bool? conditionalUnsupported,
    bool? forcePushPending,
    SyncSelection? uploadSelection,
    SyncSelection? pullSelection,
  }) => SyncConfig(
        backend: backend,
        url: url,
        username: username,
        deviceName: deviceName,
        autoSync: autoSync ?? this.autoSync,
        syncPasswords: syncPasswords ?? this.syncPasswords,
        syncSettings: syncSettings ?? this.syncSettings,
        passphraseEpoch: passphraseEpoch ?? this.passphraseEpoch,
        httpOverrides: httpOverrides ?? this.httpOverrides,
        pinnedCerts: pinnedCerts ?? this.pinnedCerts,
        conditionalUnsupported:
            conditionalUnsupported ?? this.conditionalUnsupported,
        forcePushPending: forcePushPending ?? this.forcePushPending,
    uploadSelection: uploadSelection ?? _uploadSelection,
    pullSelection: pullSelection ?? _pullSelection,
  );
}

/// This device's merge base.
class SyncLocalState {
  final Map<int, SyncBaseEntry> base;

  /// steamid → tombstone rev this device has already applied or noted.
  final Map<int, int> tombstonesSeen;

  /// Last-synced remote revision + hash of the app-settings document.
  final SyncBaseEntry? settingsBase;

  /// Hash of the local settings snapshot after the last successful push or
  /// pull. It can differ from the remote hash when an older document omits
  /// newer fields that this device deliberately retains. No settings or
  /// credentials are stored here. Older state files fall back to settingsBase.
  final String? settingsLocalHash;

  /// Local snapshots after successful directional transfers. Per-category
  /// hashes keep an unrelated edit from uploading stale settings or favorites.
  final Map<String, String> localContentHashes;
  final Map<String, String> remoteContentHashes;

  const SyncLocalState({
    this.base = const {},
    this.tombstonesSeen = const {},
    this.settingsBase,
    this.settingsLocalHash,
    this.localContentHashes = const {},
    this.remoteContentHashes = const {},
  });

  factory SyncLocalState.fromJson(Map<String, dynamic> json) {
    final base = <int, SyncBaseEntry>{};
    final raw = json['base'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final id = int.tryParse(e.key.toString());
        final v = e.value;
        if (id != null && v is Map) {
          base[id] = SyncBaseEntry.fromJson(v.cast<String, dynamic>());
        }
      }
    }
    final seen = <int, int>{};
    final rawSeen = json['tombstones_seen'];
    if (rawSeen is Map) {
      for (final e in rawSeen.entries) {
        final id = int.tryParse(e.key.toString());
        if (id != null) seen[id] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    return SyncLocalState(
      base: base,
      tombstonesSeen: seen,
      settingsBase: json['settings_base'] is Map
          ? SyncBaseEntry.fromJson(
              (json['settings_base'] as Map).cast<String, dynamic>(),
            )
          : null,
      settingsLocalHash: json['settings_local_hash'] as String?,
      localContentHashes: {
        for (final entry
            in (json['local_content_hashes'] as Map? ?? const {}).entries)
          if (entry.value is String) '${entry.key}': entry.value as String,
      },
      remoteContentHashes: {
        for (final entry
            in (json['remote_content_hashes'] as Map? ?? const {}).entries)
          if (entry.value is String) '${entry.key}': entry.value as String,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'base': {for (final e in base.entries) '${e.key}': e.value.toJson()},
        'tombstones_seen': {
      for (final e in tombstonesSeen.entries) '${e.key}': e.value,
    },
        if (settingsBase != null) 'settings_base': settingsBase!.toJson(),
        if (settingsLocalHash != null) 'settings_local_hash': settingsLocalHash,
    if (localContentHashes.isNotEmpty)
      'local_content_hashes': localContentHashes,
    if (remoteContentHashes.isNotEmpty)
      'remote_content_hashes': remoteContentHashes,
  };
}

class SyncConfigStore {
  final StorageProvider storage;
  final FlutterSecureStorage _secure;

  SyncConfigStore(this.storage, {FlutterSecureStorage? secure})
    : _secure =
          secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _kWebdavPassword = 'ava.sync.webdav_password';
  static const _kPassphrase = 'ava.sync.passphrase';
  // Retained only while an explicit passphrase rotation is pending, so a
  // restart or failed conditional commit can re-encrypt remote-only settings.
  static const _kPreviousPassphrase = 'ava.sync.previous_passphrase';

  Future<String> _path(String name) async =>
      p.join(p.dirname(await storage.maFilesDir()), name);

  Future<Map<String, dynamic>?> _readJson(String name) async {
    try {
      final f = File(await _path(name));
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeJson(String name, Map<String, dynamic> data) async {
    final path = await _path(name);
    await File(path).parent.create(recursive: true);
    await StorageProvider.replaceFileAtomic(path, jsonEncode(data));
  }

  Future<void> _deleteFile(String name) async {
    try {
      final f = File(await _path(name));
      if (await f.exists()) await f.delete();
    } catch (_) {
      /* best-effort */
    }
  }

  Future<SyncConfig?> loadConfig() async {
    final json = await _readJson('sync_config.json');
    if (json == null) return null;
    final config = SyncConfig.fromJson(json);
    return config.url.isEmpty ? null : config;
  }

  Future<void> saveConfig(SyncConfig config) =>
      _writeJson('sync_config.json', config.toJson());

  Future<SyncLocalState> loadState() async {
    final json = await _readJson('sync_state.json');
    return json == null
        ? const SyncLocalState()
        : SyncLocalState.fromJson(json);
  }

  Future<void> saveState(SyncLocalState state) =>
      _writeJson('sync_state.json', state.toJson());

  Future<String?> loadWebdavPassword() async {
    try {
      return await _secure.read(key: _kWebdavPassword);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWebdavPassword(String password) =>
      _secure.write(key: _kWebdavPassword, value: password);

  Future<String?> loadPassphrase() async {
    try {
      return await _secure.read(key: _kPassphrase);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePassphrase(String passphrase) =>
      _secure.write(key: _kPassphrase, value: passphrase);

  Future<String?> loadPreviousPassphrase() async {
    try {
      return await _secure.read(key: _kPreviousPassphrase);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePreviousPassphrase(String passphrase) =>
      _secure.write(key: _kPreviousPassphrase, value: passphrase);

  Future<void> clearPreviousPassphrase() =>
      _secure.delete(key: _kPreviousPassphrase);

  /// Removes config + local state. Secrets: the WebDAV password goes; the
  /// sync passphrase is KEPT — it is the only thing that can still open the
  /// entries in the local sync trash (and, if the remote was kept, the
  /// remote files). It is overwritten by the next setup.
  Future<void> clearAll() async {
    await _deleteFile('sync_config.json');
    await _deleteFile('sync_state.json');
    try {
      await _secure.delete(key: _kWebdavPassword);
      await clearPreviousPassphrase();
    } catch (_) {}
  }
}
