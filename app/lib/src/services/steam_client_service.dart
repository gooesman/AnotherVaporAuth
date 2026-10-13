import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/steam_vdf.dart';

enum SteamSwitchStage { stopping, backingUp, configuring, starting, restoring }

class SteamClientAccount {
  const SteamClientAccount({
    required this.steamId,
    required this.accountName,
    required this.personaName,
    required this.rememberPassword,
    required this.isMostRecent,
  });

  final String steamId;
  final String accountName;
  final String personaName;
  final bool rememberPassword;
  final bool isMostRecent;
}

/// A read-only snapshot of the selected desktop installation. A running client
/// can still be at its login screen, so [activeSteamId] may be unknown/null.
class SteamClientStatus {
  const SteamClientStatus({required this.running, this.activeSteamId});

  final bool running;

  /// Present only when the native bridge verified ActiveProcess.pid belongs
  /// to this installation's live steam.exe and read a nonzero ActiveUser.
  /// MostRecent and AutoLoginUser are intentionally never used here.
  final String? activeSteamId;
}

class SteamSwitchResult {
  const SteamSwitchResult({required this.backupPath});

  /// Only confirms that a Steam launch was requested, never authentication.
  final String backupPath;
}

class SteamClientException implements Exception {
  const SteamClientException(
    this.code,
    this.message, {
    this.backupPath,
    this.rollbackIncomplete = false,
  });
  final String code;
  final String message;
  final String? backupPath;
  final bool rollbackIncomplete;

  @override
  String toString() => 'SteamClientException($code): $message';
}

class SteamAutoLogin {
  const SteamAutoLogin({this.autoLoginUser, this.rememberPassword});
  final String? autoLoginUser;
  final int? rememberPassword;

  Map<String, Object?> toMap() => {
    'autoLoginUser': autoLoginUser,
    'rememberPassword': rememberPassword,
  };

  @override
  bool operator ==(Object other) =>
      other is SteamAutoLogin &&
      autoLoginUser == other.autoLoginUser &&
      rememberPassword == other.rememberPassword;

  @override
  int get hashCode => Object.hash(autoLoginUser, rememberPassword);
}

/// Kept injectable so tests never touch a real Steam process or registry.
abstract interface class SteamClientPlatform {
  bool get isSupported;
  Future<String?> discoverPath();
  Future<bool> isRunning(String path);
  Future<SteamClientStatus> status(String path);
  Future<void> shutdown(String path);
  Future<void> start(String path);
  Future<SteamAutoLogin> readAutoLogin();
  Future<void> writeAutoLogin(SteamAutoLogin value);
}

class MethodChannelSteamClientPlatform implements SteamClientPlatform {
  static const channel = MethodChannel('ava/steam_client');

  @override
  bool get isSupported => Platform.isWindows;

  @override
  Future<String?> discoverPath() =>
      channel.invokeMethod<String>('discoverPath');

  @override
  Future<bool> isRunning(String path) async =>
      await channel.invokeMethod<bool>('isRunning', {'path': path}) ?? true;

  @override
  Future<SteamClientStatus> status(String path) async {
    final value = await channel.invokeMapMethod<String, Object?>('readStatus', {
      'path': path,
    });
    final running = value?['running'];
    if (running is! bool) {
      throw const SteamClientException(
        'status_unavailable',
        'Steam runtime status could not be read.',
      );
    }
    final accountId = value?['activeAccountId'];
    final verified = running && value?['activeProcessVerified'] == true;
    // CSteamID public universe + individual account type + desktop instance 1.
    // Keep the full unsigned 32-bit account ID, including its high bit.
    const individualSteamIdBase = 76561197960265728;
    return SteamClientStatus(
      running: running,
      activeSteamId:
          verified &&
              accountId is int &&
              accountId > 0 &&
              accountId <= 0xffffffff
          ? '${individualSteamIdBase + accountId}'
          : null,
    );
  }

  @override
  Future<void> shutdown(String path) =>
      channel.invokeMethod<void>('shutdown', {'path': path});

  @override
  Future<void> start(String path) =>
      channel.invokeMethod<void>('start', {'path': path});

  @override
  Future<SteamAutoLogin> readAutoLogin() async {
    final value = await channel.invokeMapMethod<String, Object?>(
      'readAutoLogin',
    );
    if (value == null) throw StateError('Missing Steam registry response');
    return SteamAutoLogin(
      autoLoginUser: value['autoLoginUser'] as String?,
      rememberPassword: value['rememberPassword'] as int?,
    );
  }

  @override
  Future<void> writeAutoLogin(SteamAutoLogin value) =>
      channel.invokeMethod<void>('writeAutoLogin', value.toMap());
}

abstract interface class SteamClientFiles {
  Future<bool> exists(String path);
  Future<List<int>> read(String path);

  /// Creates a unique private directory before writing any sensitive bytes.
  Future<String> backup(String steamPath, Map<String, List<int>> originals);

  /// Must refuse replacement when the current bytes differ from [expected].
  Future<void> replace(String path, List<int> expected, List<int> replacement);
}

class LocalSteamClientFiles implements SteamClientFiles {
  static const _channel = MethodChannelSteamClientPlatform.channel;
  static const _maxFileSize = 8 * 1024 * 1024;

  @override
  Future<bool> exists(String path) async =>
      await FileSystemEntity.type(path, followLinks: false) ==
      FileSystemEntityType.file;

  @override
  Future<List<int>> read(String path) async {
    if (!await exists(path)) {
      throw const SteamClientException(
        'invalid_path',
        'Steam file is missing.',
      );
    }
    final file = File(path);
    if (await file.length() > _maxFileSize) {
      throw const SteamClientException(
        'invalid_config',
        'Steam configuration is unexpectedly large.',
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxFileSize) {
      throw const SteamClientException(
        'invalid_config',
        'Steam configuration is unexpectedly large.',
      );
    }
    return bytes;
  }

  @override
  Future<String> backup(
    String steamPath,
    Map<String, List<int>> originals,
  ) async {
    final root = Directory(p.join(steamPath, 'config', 'ava-switch-backups'));
    await root.create();
    final directory = await root.createTemp('switch-');
    // Native ACL protection happens before any account data is written.
    await _channel.invokeMethod<void>('secureDirectory', {
      'path': directory.path,
    });
    for (final entry in originals.entries) {
      await File(
        p.join(directory.path, entry.key),
      ).writeAsBytes(entry.value, flush: true);
    }
    return directory.path;
  }

  @override
  Future<void> replace(
    String path,
    List<int> expected,
    List<int> replacement,
  ) async {
    // The temporary file inherits a private directory ACL. ReplaceFileW
    // preserves the destination file's existing ACL on successful replacement.
    final directory = await Directory(p.dirname(path)).createTemp('.ava-');
    final temporary = File(p.join(directory.path, p.basename(path)));
    try {
      await _channel.invokeMethod<void>('secureDirectory', {
        'path': directory.path,
      });
      await temporary.writeAsBytes(replacement, flush: true);
      if (!_same(await read(path), expected)) {
        throw const SteamClientException(
          'concurrent_change',
          'Steam configuration changed during the switch.',
        );
      }
      await _channel.invokeMethod<void>('replaceFile', {
        'path': path,
        'replacementPath': temporary.path,
      });
    } finally {
      if (await temporary.exists()) await temporary.delete();
      try {
        // A leftover empty private directory is harmless. Failure to remove
        // sensitive temporary bytes above still propagates to the transaction.
        if (await directory.exists()) await directory.delete();
      } on FileSystemException {
        // Antivirus/indexers can briefly retain the now-empty directory.
      }
    }
  }
}

class SteamClientService {
  SteamClientService({
    SteamClientPlatform? platform,
    SteamClientFiles? files,
    this.shutdownTimeout = const Duration(seconds: 30),
    this.pollInterval = const Duration(milliseconds: 250),
  }) : _platform = platform ?? MethodChannelSteamClientPlatform(),
       _files = files ?? LocalSteamClientFiles();

  final SteamClientPlatform _platform;
  final SteamClientFiles _files;
  final Duration shutdownTimeout;
  final Duration pollInterval;
  static bool _switching = false;

  static bool get isSupported => Platform.isWindows;

  Future<String?> discoverPath() async {
    _requireSupported();
    return _platform.discoverPath();
  }

  /// Reads process/ActiveProcess state only. Does not inspect saved credentials
  /// or assume that a previous switch request completed authentication.
  Future<SteamClientStatus> status(String path) async {
    _requireSupported();
    await _validatePath(path);
    try {
      return await _platform.status(path);
    } catch (_) {
      throw const SteamClientException(
        'status_unavailable',
        'Steam runtime status could not be read.',
      );
    }
  }

  Future<List<SteamClientAccount>> listAccounts(String path) async {
    _requireSupported();
    try {
      await _validatePath(path);
      final loginPath = _loginFile(path);
      // A fresh Steam installation has no saved account file until its first
      // login. The installation is valid; the UI can explain how to add one.
      if (!await _files.exists(loginPath)) return const [];
      return _LoginUsers.parse(await _files.read(loginPath)).accounts;
    } on SteamClientException {
      rethrow;
    } on FormatException {
      throw const SteamClientException(
        'invalid_config',
        'Steam account configuration could not be read safely.',
      );
    } catch (_) {
      throw const SteamClientException(
        'invalid_path',
        'Steam account configuration could not be opened.',
      );
    }
  }

  Future<SteamSwitchResult> switchAccount({
    required String path,
    required String steamId,
    void Function(SteamSwitchStage)? onProgress,
  }) => _switchAccount(path: path, steamId: steamId, onProgress: onProgress);

  /// User-initiated desktop login. A new/unremembered account opens a clean
  /// login prompt instead of requiring credentials to have been saved in Steam.
  /// This does not authorize any login: the separate QR flow owns that step.
  Future<SteamSwitchResult> prepareLogin({
    required String path,
    required String steamId,
    void Function(SteamSwitchStage)? onProgress,
  }) => _switchAccount(
    path: path,
    steamId: steamId,
    onProgress: onProgress,
    allowQrLogin: true,
  );

  Future<void> open(String path) async {
    _requireSupported();
    await _validatePath(path);
    if (_switching) {
      throw const SteamClientException(
        'busy',
        'A Steam switch is in progress.',
      );
    }
    await _platform.start(path);
  }

  Future<SteamSwitchResult> _switchAccount({
    required String path,
    required String steamId,
    void Function(SteamSwitchStage)? onProgress,
    bool allowQrLogin = false,
  }) async {
    _requireSupported();
    if (_switching) {
      throw const SteamClientException(
        'busy',
        'A Steam switch is in progress.',
      );
    }
    _switching = true;
    String? backupPath;
    final edits = <_FileEdit>[];
    SteamAutoLogin? oldRegistry;
    SteamAutoLogin? newRegistry;
    var registryAttempted = false;
    var failureCode = 'operation_failed';
    // A UI progress callback must never interrupt a configuration transaction.
    void progress(SteamSwitchStage stage) {
      try {
        onProgress?.call(stage);
      } catch (_) {
        // Progress is advisory; the transaction owns its cleanup.
      }
    }

    try {
      await _validatePath(path);
      if (!RegExp(r'^[0-9]{1,20}$').hasMatch(steamId)) {
        throw const SteamClientException(
          'account_missing',
          'Invalid Steam ID.',
        );
      }
      final initial = allowQrLogin && !await _files.exists(_loginFile(path))
          ? null
          : _LoginUsers.parse(await _files.read(_loginFile(path)));
      final initialTarget = allowQrLogin
          ? initial?.accounts.where((a) => a.steamId == steamId).firstOrNull
          : initial!.target(steamId);
      progress(SteamSwitchStage.stopping);
      failureCode = 'shutdown_failed';
      if (await _platform.isRunning(path)) {
        await _platform.shutdown(path);
        final clock = Stopwatch()..start();
        while (await _platform.isRunning(path)) {
          if (clock.elapsed >= shutdownTimeout) {
            throw const SteamClientException(
              'shutdown_timeout',
              'Steam did not exit. Close Steam and any running games, then retry.',
            );
          }
          await Future<void>.delayed(pollInterval);
        }
      }

      // Steam can rewrite these files while shutting down. Never patch the
      // pre-shutdown snapshot, and revalidate the target after it has exited.
      failureCode = 'invalid_config';
      final loginPath = _loginFile(path);
      final loginBytes = allowQrLogin && !await _files.exists(loginPath)
          ? null
          : await _files.read(loginPath);
      final login = loginBytes == null ? null : _LoginUsers.parse(loginBytes);
      final target = allowQrLogin
          ? login?.accounts.where((a) => a.steamId == steamId).firstOrNull
          : login!.target(steamId);
      if (initialTarget?.accountName != target?.accountName) {
        throw const SteamClientException(
          'account_changed',
          'The selected Steam account changed during shutdown.',
        );
      }
      final remembered = target?.rememberPassword == true;
      final planned = <_FileEdit>[
        if (loginBytes != null)
          _FileEdit(
            loginPath,
            loginBytes,
            remembered ? login!.select(steamId) : login!.prompt(),
          ),
      ];
      final backups = <String, List<int>>{
        'loginusers.vdf': ?loginBytes,
      };
      final configPath = p.join(path, 'config', 'config.vdf');
      if (await _files.exists(configPath)) {
        final original = await _files.read(configPath);
        backups['config.vdf'] = original;
        planned.add(_FileEdit(configPath, original, _patchConfig(original)));
      }
      oldRegistry = await _platform.readAutoLogin();
      newRegistry = SteamAutoLogin(
        autoLoginUser: remembered ? target!.accountName : '',
        rememberPassword: 1,
      );
      backups['auto-login.json'] = utf8.encode(jsonEncode(oldRegistry.toMap()));
      progress(SteamSwitchStage.backingUp);
      failureCode = 'backup_failed';
      backupPath = await _files.backup(path, backups);

      progress(SteamSwitchStage.configuring);
      failureCode = 'write_failed';
      await _requireStopped(path);
      if (await _platform.readAutoLogin() != oldRegistry) {
        throw const SteamClientException(
          'concurrent_change',
          'Steam auto-login settings changed during the switch.',
        );
      }
      for (final edit in planned) {
        if (_same(edit.original, edit.updated)) continue;
        await _requireStopped(path);
        // Include attempted writes: a filesystem can write, then throw.
        edits.add(edit);
        await _files.replace(edit.path, edit.original, edit.updated);
      }
      await _requireStopped(path);
      if (await _platform.readAutoLogin() != oldRegistry) {
        throw const SteamClientException(
          'concurrent_change',
          'Steam auto-login settings changed during the switch.',
        );
      }
      if (oldRegistry != newRegistry) {
        registryAttempted = true;
        await _platform.writeAutoLogin(newRegistry);
      }
      // Detect interference before launching, even if no file needed editing.
      for (final edit in planned) {
        if (!_same(await _files.read(edit.path), edit.updated)) {
          throw const SteamClientException(
            'concurrent_change',
            'Steam configuration changed during the switch.',
          );
        }
      }
      if (await _platform.readAutoLogin() != newRegistry) {
        throw const SteamClientException(
          'concurrent_change',
          'Steam auto-login settings changed during the switch.',
        );
      }
      await _requireStopped(path);
      progress(SteamSwitchStage.starting);
      failureCode = 'launch_failed';
      await _platform.start(path);
      return SteamSwitchResult(backupPath: backupPath);
    } catch (error) {
      var incomplete = false;
      if (edits.isNotEmpty || registryAttempted) {
        progress(SteamSwitchStage.restoring);
        incomplete = !await _restore(
          path,
          edits,
          registryAttempted ? oldRegistry : null,
          registryAttempted ? newRegistry : null,
        );
      }
      throw SteamClientException(
        error is SteamClientException
            ? error.code
            : error is FormatException
            ? 'invalid_config'
            : failureCode,
        error is SteamClientException
            ? error.message
            : 'Steam could not complete the switch.',
        backupPath: backupPath,
        rollbackIncomplete: incomplete,
      );
    } finally {
      _switching = false;
    }
  }

  Future<bool> _restore(
    String path,
    List<_FileEdit> edits,
    SteamAutoLogin? oldRegistry,
    SteamAutoLogin? newRegistry,
  ) async {
    var complete = true;
    try {
      // If someone started Steam in parallel, leave its live files alone.
      if (await _platform.isRunning(path)) return false;
    } catch (_) {
      return false;
    }
    if (oldRegistry != null && newRegistry != null) {
      try {
        final current = await _platform.readAutoLogin();
        final userSafe =
            current.autoLoginUser == oldRegistry.autoLoginUser ||
            current.autoLoginUser == newRegistry.autoLoginUser;
        final rememberSafe =
            current.rememberPassword == oldRegistry.rememberPassword ||
            current.rememberPassword == newRegistry.rememberPassword;
        if (userSafe && rememberSafe) {
          if (current != oldRegistry) {
            await _platform.writeAutoLogin(oldRegistry);
          }
        } else {
          complete = false;
        }
      } catch (_) {
        complete = false;
      }
    }
    for (final edit in edits.reversed) {
      try {
        await _requireStopped(path);
        final current = await _files.read(edit.path);
        if (_same(current, edit.original)) continue;
        if (!_same(current, edit.updated)) {
          complete = false;
          continue;
        }
        await _files.replace(edit.path, edit.updated, edit.original);
      } catch (_) {
        complete = false;
      }
    }
    return complete;
  }

  void _requireSupported() {
    if (!_platform.isSupported) {
      throw const SteamClientException(
        'unsupported',
        'Steam account switching is available on Windows only.',
      );
    }
  }

  Future<void> _validatePath(String path) async {
    if (path.isEmpty || !await _files.exists(p.join(path, 'steam.exe'))) {
      throw const SteamClientException(
        'invalid_path',
        'Choose the folder containing steam.exe.',
      );
    }
  }

  Future<void> _requireStopped(String path) async {
    if (await _platform.isRunning(path)) {
      throw const SteamClientException(
        'concurrent_change',
        'Steam restarted during the switch. Close it and retry.',
      );
    }
  }

  static String _loginFile(String path) =>
      p.join(path, 'config', 'loginusers.vdf');
}

class _FileEdit {
  const _FileEdit(this.path, this.original, this.updated);
  final String path;
  final List<int> original;
  final List<int> updated;
}

class _LoginUsers {
  _LoginUsers(this.document, this.accounts, this.records);

  factory _LoginUsers.parse(List<int> bytes) {
    final document = SteamVdfDocument.parse(_decode(bytes));
    final users = document.object(document.root, 'users');
    if (users == null) {
      throw const FormatException('Missing Steam users object');
    }
    final accounts = <SteamClientAccount>[];
    final records = <String, SteamVdfObject>{};
    final names = <String>{};
    for (final entry in users.entries) {
      if (!RegExp(r'^[0-9]{1,20}$').hasMatch(entry.key) ||
          entry.object == null ||
          records.containsKey(entry.key)) {
        throw const FormatException('Ambiguous Steam account record');
      }
      final record = entry.object!;
      final accountName = document.string(record, 'AccountName');
      if (accountName == null ||
          accountName.isEmpty ||
          accountName.length > 256 ||
          accountName.contains('\u0000') ||
          !names.add(accountName.toLowerCase())) {
        throw const FormatException('Ambiguous Steam account name');
      }
      // Validate all keys involved in switching before making any changes.
      document.string(record, 'AutoLogin');
      document.string(record, 'AllowAutoLogin');
      accounts.add(
        SteamClientAccount(
          steamId: entry.key,
          accountName: accountName,
          personaName: document.string(record, 'PersonaName') ?? accountName,
          rememberPassword: document.string(record, 'RememberPassword') == '1',
          isMostRecent: document.string(record, 'MostRecent') == '1',
        ),
      );
      records[entry.key] = record;
    }
    return _LoginUsers(document, accounts, records);
  }

  final SteamVdfDocument document;
  final List<SteamClientAccount> accounts;
  final Map<String, SteamVdfObject> records;

  SteamClientAccount target(String steamId) {
    final target = accounts.where((a) => a.steamId == steamId).firstOrNull;
    if (target == null) {
      throw const SteamClientException(
        'account_missing',
        'Log into this account in Steam on this PC first.',
      );
    }
    if (!target.rememberPassword) {
      throw const SteamClientException(
        'credentials_not_saved',
        'Log into Steam with Remember me enabled for this account first.',
      );
    }
    return target;
  }

  List<int> select(String steamId) {
    for (final entry in records.entries) {
      document.setString(
        entry.value,
        'MostRecent',
        entry.key == steamId ? '1' : '0',
      );
    }
    final selected = records[steamId]!;
    document.setString(selected, 'AutoLogin', '1');
    document.setString(selected, 'AllowAutoLogin', '1');
    return utf8.encode(document.render());
  }

  List<int> prompt() {
    for (final record in records.values) {
      document.setString(record, 'MostRecent', '0');
      document.setString(record, 'AutoLogin', '0');
      document.setString(record, 'AllowAutoLogin', '0');
    }
    return utf8.encode(document.render());
  }
}

List<int> _patchConfig(List<int> bytes) {
  final document = SteamVdfDocument.parse(_decode(bytes));
  // Current Steam stores WebStorage directly under InstallConfigStore.
  // Also handle the older nested layout, but never search unrelated Auth keys.
  for (final keys in const [
    ['InstallConfigStore', 'WebStorage', 'Auth'],
    ['InstallConfigStore', 'Software', 'Valve', 'Steam', 'WebStorage', 'Auth'],
  ]) {
    SteamVdfObject? node = document.root;
    for (final key in keys) {
      node = document.object(node!, key);
      if (node == null) break;
    }
    if (node != null &&
        document.string(node, 'AlwaysShowUserChooser') != null) {
      document.setString(node, 'AlwaysShowUserChooser', '0');
    }
  }
  return utf8.encode(document.render());
}

String _decode(List<int> bytes) {
  // Dart's UTF-8 decoder strips a BOM; preserve it in the edited file.
  final hasBom =
      bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf;
  return hasBom ? '\ufeff${utf8.decode(bytes.sublist(3))}' : utf8.decode(bytes);
}

bool _same(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
