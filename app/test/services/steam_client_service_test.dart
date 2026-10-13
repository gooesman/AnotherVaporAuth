import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ava/src/core/steam_vdf.dart';
import 'package:ava/src/services/steam_client_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _path = 'test-steam';
const _firstId = '76561198000000001';
const _secondId = '76561198000000002';
const _login = '''// unknown fields and whitespace are intentionally retained
"users"
{
  "76561198000000001" {
    "AccountName" "alice"
    "PersonaName" "A \\"quote\\""
    "RememberPassword" "1"
    "MostRecent" "1"
    "UnknownFutureFlag" "keep"
  }
  "76561198000000002" {
    "AccountName" "bob"
    "PersonaName" "Bob"
    "RememberPassword" "1"
    "MostRecent" "0"
    "AutoLogin" "0"
    "AllowAutoLogin" "0"
  }
}
''';
const _config = '''"InstallConfigStore" { "Software" { "Valve" { "Steam" {
"WebStorage" { "Auth" { "AlwaysShowUserChooser" "1" "untouched" "value" } }
} } } }''';

String get _loginPath => p.join(_path, 'config', 'loginusers.vdf');
String get _configPath => p.join(_path, 'config', 'config.vdf');

TypeMatcher<SteamClientException> _code(String code) =>
    isA<SteamClientException>().having((e) => e.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Files files;
  late _Platform platform;
  late SteamClientService service;

  setUp(() {
    files = _Files();
    platform = _Platform();
    service = SteamClientService(
      files: files,
      platform: platform,
      shutdownTimeout: Duration.zero,
      pollInterval: Duration.zero,
    );
  });

  test(
    'status reads runtime identity without reading or writing login files',
    () async {
      // Remembered MostRecent and AutoLoginUser are Alice, while live Steam is Bob.
      platform.running = true;
      platform.activeSteamId = _secondId;
      final status = await service.status(_path);
      expect(status.running, isTrue);
      expect(status.activeSteamId, _secondId);
      expect(files.reads, 0);
      expect(files.writes, 0);
      expect(files.backups, isNull);
      expect(platform.calls, ['status']);
    },
  );

  test('status does not assume a saved account is logged in', () async {
    platform.running = true;
    final unknown = await service.status(_path);
    expect(unknown.running, isTrue);
    expect(unknown.activeSteamId, isNull);
    platform.running = false;
    final stopped = await service.status(_path);
    expect(stopped.running, isFalse);
    expect(stopped.activeSteamId, isNull);
    expect(files.reads, 0);
    expect(files.writes, 0);
  });

  test(
    'status errors stay unavailable rather than claiming Steam is stopped',
    () async {
      platform.failStatus = true;
      await expectLater(
        service.status(_path),
        throwsA(_code('status_unavailable')),
      );
      expect(files.reads, 0);
      expect(files.writes, 0);
      files.data.remove(p.join(_path, 'steam.exe'));
      await expectLater(service.status(_path), throwsA(_code('invalid_path')));
    },
  );

  group('native runtime status bridge', () {
    const channel = MethodChannelSteamClientPlatform.channel;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final bridge = MethodChannelSteamClientPlatform();
    Map<String, Object?>? snapshot;
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      snapshot = {
        'running': true,
        'activeProcessVerified': true,
        'activeAccountId': 39734274,
      };
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return snapshot;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test(
      'uses only fixed readStatus method and preserves unsigned account IDs',
      () async {
        final status = await bridge.status(_path);
        expect(status.running, isTrue);
        expect(status.activeSteamId, _secondId);
        expect(calls.single.method, 'readStatus');
        expect(calls.single.arguments, {'path': _path});
        snapshot!['activeAccountId'] = 0xffffffff;
        expect((await bridge.status(_path)).activeSteamId, '76561202255233023');
      },
    );

    test(
      'stopped process or unverified PID cannot expose a stale ActiveUser',
      () async {
        snapshot!['running'] = false;
        expect((await bridge.status(_path)).activeSteamId, isNull);
        snapshot!['running'] = true;
        snapshot!['activeProcessVerified'] = false;
        expect((await bridge.status(_path)).activeSteamId, isNull);
        snapshot!.remove('activeProcessVerified');
        expect((await bridge.status(_path)).activeSteamId, isNull);
      },
    );

    test(
      'zero, absent, and malformed ActiveUser values stay unknown',
      () async {
        for (final id in [null, 0, -1, 0x100000000, '39734274', 123.0, true]) {
          snapshot!['activeAccountId'] = id;
          final status = await bridge.status(_path);
          expect(status.running, isTrue);
          expect(status.activeSteamId, isNull);
        }
      },
    );

    test(
      'missing or invalid process state is not converted into stopped',
      () async {
        for (final invalid in [
          null,
          <String, Object?>{},
          {'running': 0},
        ]) {
          snapshot = invalid;
          await expectLater(
            bridge.status(_path),
            throwsA(_code('status_unavailable')),
          );
        }
      },
    );
  });

  test('lists stable string Steam IDs and saved-login eligibility', () async {
    files.data[_loginPath] = utf8.encode(
      _login.replaceFirst('"RememberPassword" "1"', '"RememberPassword" "0"'),
    );
    final accounts = await service.listAccounts(_path);
    expect(accounts.map((a) => a.steamId), [_firstId, _secondId]);
    expect(accounts.first.personaName, 'A "quote"');
    expect(accounts.first.rememberPassword, false);
    expect(accounts.last.rememberPassword, true);
    expect(platform.calls, isEmpty);
    expect(files.writes, 0);
  });

  test('a fresh Steam installation has an empty saved-account list', () async {
    files.data.remove(_loginPath);
    expect(await service.listAccounts(_path), isEmpty);
    expect(files.reads, 0);
    expect(files.writes, 0);
    expect(platform.calls, isEmpty);

    // Absence of loginusers.vdf must not make an unrelated folder valid.
    files.data.remove(p.join(_path, 'steam.exe'));
    await expectLater(
      service.listAccounts(_path),
      throwsA(_code('invalid_path')),
    );
  });

  test(
    'backs up final shutdown snapshot, changes flags and requests start',
    () async {
      platform.running = true;
      platform.onShutdown = () {
        files.data[_loginPath] = utf8.encode(
          _login.replaceFirst('keep', 'saved'),
        );
      };
      final stages = <SteamSwitchStage>[];
      final result = await service.switchAccount(
        path: _path,
        steamId: _secondId,
        onProgress: stages.add,
      );
      expect(result.backupPath, 'private-backup');
      expect(platform.calls, ['shutdown', 'registry', 'start']);
      expect(platform.registry.autoLoginUser, 'bob');
      expect(platform.registry.rememberPassword, 1);
      expect(
        files.backups!['loginusers.vdf'],
        utf8.encode(_login.replaceFirst('keep', 'saved')),
      );
      expect(files.backups!['config.vdf'], utf8.encode(_config));
      final updated = utf8.decode(files.data[_loginPath]!);
      expect(updated, contains('"UnknownFutureFlag" "saved"'));
      final document = SteamVdfDocument.parse(updated);
      final users = document.object(document.root, 'users')!;
      final first = document.object(users, _firstId)!;
      final second = document.object(users, _secondId)!;
      expect(document.string(first, 'MostRecent'), '0');
      expect(document.string(second, 'MostRecent'), '1');
      expect(document.string(second, 'AutoLogin'), '1');
      expect(document.string(second, 'AllowAutoLogin'), '1');
      expect(
        utf8.decode(files.data[_configPath]!),
        _config.replaceFirst('"1"', '"0"'),
      );
      expect(stages.last, SteamSwitchStage.starting);
    },
  );

  test('does not invent absent config nodes and preserves UTF-8 BOM', () async {
    files.data[_loginPath] = [0xef, 0xbb, 0xbf, ...utf8.encode(_login)];
    files.data[_configPath] = utf8.encode('"other" "unchanged"');
    await service.switchAccount(path: _path, steamId: _secondId);
    expect(files.data[_loginPath]!.take(3), [0xef, 0xbb, 0xbf]);
    expect(utf8.decode(files.data[_configPath]!), '"other" "unchanged"');
  });

  test(
    'updates current Steam root WebStorage layout only at the exact path',
    () async {
      const current =
          '"InstallConfigStore" { '
          '"WebStorage" { "Auth" { "AlwaysShowUserChooser" "1" } } '
          '"unrelated" { "Auth" { "AlwaysShowUserChooser" "1" } } }';
      files.data[_configPath] = utf8.encode(current);
      await service.switchAccount(path: _path, steamId: _secondId);
      expect(
        utf8.decode(files.data[_configPath]!),
        current.replaceFirst(
          '"AlwaysShowUserChooser" "1"',
          '"AlwaysShowUserChooser" "0"',
        ),
      );
    },
  );

  test('refuses a missing or unremembered account before shutdown', () async {
    await expectLater(
      service.switchAccount(path: _path, steamId: '999'),
      throwsA(_code('account_missing')),
    );
    files.data[_loginPath] = utf8.encode(
      _login.replaceAll('"RememberPassword" "1"', '"RememberPassword" "0"'),
    );
    await expectLater(
      service.switchAccount(path: _path, steamId: _secondId),
      throwsA(_code('credentials_not_saved')),
    );
    expect(platform.calls, isEmpty);
    expect(files.writes, 0);
  });

  test(
    'a Steam process that will not exit causes no configuration writes',
    () async {
      platform.running = true;
      platform.exits = false;
      await expectLater(
        service.switchAccount(path: _path, steamId: _secondId),
        throwsA(_code('shutdown_timeout')),
      );
      expect(platform.calls, ['shutdown']);
      expect(files.backups, isNull);
      expect(files.writes, 0);
    },
  );

  test('revalidates a target removed during graceful shutdown', () async {
    platform.running = true;
    platform.onShutdown = () =>
        files.data[_loginPath] = utf8.encode('"users" {}');
    await expectLater(
      service.switchAccount(path: _path, steamId: _secondId),
      throwsA(_code('account_missing')),
    );
    expect(files.writes, 0);
  });

  test('rejects a changed target login name after shutdown', () async {
    platform.running = true;
    platform.onShutdown = () => files.data[_loginPath] = utf8.encode(
      _login.replaceFirst('"bob"', '"someone_else"'),
    );
    await expectLater(
      service.switchAccount(path: _path, steamId: _secondId),
      throwsA(_code('account_changed')),
    );
    expect(files.writes, 0);
  });

  for (final ambiguous in [
    _login.replaceFirst(
      '"MostRecent" "0"',
      '"MostRecent" "0" "mostrecent" "1"',
    ),
    _login.replaceFirst(_secondId, _firstId),
    _login.replaceFirst('"bob"', '"ALICE"'),
  ]) {
    test('refuses ambiguous account configuration', () async {
      files.data[_loginPath] = utf8.encode(ambiguous);
      await expectLater(
        service.listAccounts(_path),
        throwsA(_code('invalid_config')),
      );
      expect(files.writes, 0);
    });
  }

  test('backup failure happens before any mutable state is changed', () async {
    files.failBackup = true;
    await expectLater(
      service.switchAccount(path: _path, steamId: _secondId),
      throwsA(_code('backup_failed')),
    );
    expect(files.writes, 0);
    expect(platform.calls, isEmpty);
  });

  test('second file write failure restores the first file', () async {
    files.failWrite = 2;
    await expectLater(
      service.switchAccount(path: _path, steamId: _secondId),
      throwsA(
        _code(
          'write_failed',
        ).having((e) => e.rollbackIncomplete, 'rollback', false),
      ),
    );
    expect(files.data[_loginPath], utf8.encode(_login));
    expect(files.data[_configPath], utf8.encode(_config));
    expect(platform.calls, isEmpty);
  });

  test('a file write which succeeds then throws is also restored', () async {
    files.failWrite = 1;
    files.failAfterWrite = true;
    await expectLater(
      service.switchAccount(path: _path, steamId: _secondId),
      throwsA(_code('write_failed')),
    );
    expect(files.data[_loginPath], utf8.encode(_login));
  });

  test(
    'partial registry failure restores files and missing original values',
    () async {
      platform.registry = const SteamAutoLogin();
      platform.failRegistry = true;
      await expectLater(
        service.switchAccount(path: _path, steamId: _secondId),
        throwsA(
          _code(
            'write_failed',
          ).having((e) => e.rollbackIncomplete, 'rollback', false),
        ),
      );
      expect(platform.registry, const SteamAutoLogin());
      expect(files.data[_loginPath], utf8.encode(_login));
      expect(files.data[_configPath], utf8.encode(_config));
      expect(platform.calls, isNot(contains('start')));
    },
  );

  test('launch failure restores registry and both files', () async {
    platform.failStart = true;
    await expectLater(
      service.switchAccount(path: _path, steamId: _secondId),
      throwsA(
        _code(
          'launch_failed',
        ).having((e) => e.backupPath, 'backup', 'private-backup'),
      ),
    );
    expect(
      platform.registry,
      const SteamAutoLogin(autoLoginUser: 'alice', rememberPassword: 0),
    );
    expect(files.data[_loginPath], utf8.encode(_login));
    expect(files.data[_configPath], utf8.encode(_config));
  });

  test('external file change before replacement is not overwritten', () async {
    files.onBackup = () =>
        files.data[_loginPath] = utf8.encode('external edit');
    await expectLater(
      service.switchAccount(path: _path, steamId: _secondId),
      throwsA(
        _code(
          'concurrent_change',
        ).having((e) => e.rollbackIncomplete, 'rollback', true),
      ),
    );
    expect(utf8.decode(files.data[_loginPath]!), 'external edit');
    expect(platform.calls, isEmpty);
  });

  test(
    'rollback will not overwrite external file or registry changes',
    () async {
      platform.failStart = true;
      platform.onStart = () {
        files.data[_loginPath] = utf8.encode('external edit');
        platform.registry = const SteamAutoLogin(
          autoLoginUser: 'third_party',
          rememberPassword: 1,
        );
      };
      await expectLater(
        service.switchAccount(path: _path, steamId: _secondId),
        throwsA(
          _code(
            'launch_failed',
          ).having((e) => e.rollbackIncomplete, 'rollback', true),
        ),
      );
      expect(utf8.decode(files.data[_loginPath]!), 'external edit');
      expect(platform.registry.autoLoginUser, 'third_party');
      expect(files.data[_configPath], utf8.encode(_config));
    },
  );

  test('reports failed rollback and keeps recovery location', () async {
    platform.failStart = true;
    files.failWrite = 3;
    await expectLater(
      service.switchAccount(path: _path, steamId: _secondId),
      throwsA(
        _code('launch_failed')
            .having((e) => e.rollbackIncomplete, 'rollback', true)
            .having((e) => e.backupPath, 'backup', 'private-backup'),
      ),
    );
  });

  test(
    'global guard rejects simultaneous switches across service instances',
    () async {
      final gate = Completer<void>();
      files.backupGate = gate.future;
      final first = service.switchAccount(path: _path, steamId: _secondId);
      await files.backupStarted.future;
      final other = SteamClientService(platform: platform, files: files);
      await expectLater(
        other.switchAccount(path: _path, steamId: _firstId),
        throwsA(_code('busy')),
      );
      gate.complete();
      await first;
    },
  );

  test('non-Windows production gate refuses before file access', () async {
    platform.supported = false;
    await expectLater(
      service.listAccounts(_path),
      throwsA(_code('unsupported')),
    );
    await expectLater(
      service.switchAccount(path: _path, steamId: _secondId),
      throwsA(_code('unsupported')),
    );
    expect(files.reads, 0);
  });

  test('throwing progress UI cannot interrupt a switch transaction', () async {
    await service.switchAccount(
      path: _path,
      steamId: _secondId,
      onProgress: (_) => throw StateError('disposed UI'),
    );
    expect(platform.calls.last, 'start');
  });

  test(
    'one-click first login disables automatic other accounts without deleting credentials',
    () async {
      await service.prepareLogin(path: _path, steamId: '76561198000000003');
      expect(platform.registry.autoLoginUser, '');
      final document = SteamVdfDocument.parse(
        utf8.decode(files.data[_loginPath]!),
      );
      final users = document.object(document.root, 'users')!;
      for (final id in [_firstId, _secondId]) {
        final record = document.object(users, id)!;
        expect(document.string(record, 'MostRecent'), '0');
        expect(document.string(record, 'AutoLogin'), '0');
        expect(document.string(record, 'AllowAutoLogin'), '0');
        expect(document.string(record, 'RememberPassword'), '1');
      }
      expect(files.backups!['loginusers.vdf'], utf8.encode(_login));
      expect(platform.calls.last, 'start');
    },
  );

  test('one-click unremembered target opens login prompt', () async {
    files.data[_loginPath] = utf8.encode(
      _login.replaceAll('"RememberPassword" "1"', '"RememberPassword" "0"'),
    );
    await service.prepareLogin(path: _path, steamId: _secondId);
    expect(platform.registry.autoLoginUser, '');
    expect(platform.calls.last, 'start');
  });

  test(
    'fresh installation backs up registry without creating loginusers',
    () async {
      files.data.remove(_loginPath);
      files.data.remove(_configPath);
      await service.prepareLogin(path: _path, steamId: _secondId);
      expect(files.data.containsKey(_loginPath), isFalse);
      expect(files.writes, 0);
      expect(files.backups!.keys, ['auto-login.json']);
      expect(platform.registry.autoLoginUser, '');
      expect(platform.calls.last, 'start');
    },
  );

  test(
    'one-click remembered target keeps existing safe switch behavior',
    () async {
      await service.prepareLogin(path: _path, steamId: _secondId);
      expect(platform.registry.autoLoginUser, 'bob');
      expect(files.backups!['loginusers.vdf'], utf8.encode(_login));
      expect(platform.calls.last, 'start');
    },
  );

  test('failed first-login launch restores files and registry', () async {
    final oldRegistry = platform.registry;
    platform.failStart = true;
    await expectLater(
      service.prepareLogin(path: _path, steamId: '76561198000000003'),
      throwsA(_code('launch_failed')),
    );
    expect(platform.registry, oldRegistry);
    expect(files.data[_loginPath], utf8.encode(_login));
    expect(files.data[_configPath], utf8.encode(_config));
  });

  test(
    'open Steam is local and never reads or edits account configuration',
    () async {
      await service.open(_path);
      expect(platform.calls, ['start']);
      expect(files.reads, 0);
      expect(files.writes, 0);
      expect(files.backups, isNull);
    },
  );

  test(
    'launch failure preserves native code number stage and rollback',
    () async {
      platform.onStart = () => throw PlatformException(
        code: 'steam_start_failed',
        message: 'private-account-token',
        details: {'win32Error': 193, 'private': 'secret'},
      );
      for (final action in [
        () => service.open(_path),
        () => service.prepareLogin(path: _path, steamId: '76561198000000003'),
      ]) {
        await expectLater(
          action(),
          throwsA(
            _code('launch_failed')
                .having((e) => e.nativeCode, 'nativeCode', 'steam_start_failed')
                .having((e) => e.win32Error, 'win32Error', 193)
                .having((e) => e.stage, 'stage', 'starting')
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('private-account')),
                ),
          ),
        );
      }
      expect(files.data[_loginPath], utf8.encode(_login));
      expect(files.data[_configPath], utf8.encode(_config));
    },
  );

  test('diagnostics accept only known codes and bounded system integers', () {
    for (final value in [0, -1, 0x100000000, '5', null]) {
      final result = SteamClientException.fromFailure(
        PlatformException(
          code: 'secret_token',
          message: 'private',
          details: {'win32Error': value},
        ),
        code: 'launch_failed',
        stage: 'starting',
      );
      expect(result.nativeCode, isNull);
      expect(result.win32Error, isNull);
      expect(result.message, isNot(contains('private')));
    }
  });

  test(
    'fresh local installation creates config and secures backup before bytes',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'steamkit-files-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      const channel = MethodChannelSteamClientPlatform.channel;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var secured = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'secureDirectory');
        final directory = Directory((call.arguments as Map)['path'] as String);
        expect(directory.existsSync(), isTrue);
        expect(directory.listSync(), isEmpty);
        secured = true;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final backup = await LocalSteamClientFiles().backup(root.path, {
        'auto-login.json': utf8.encode('{"synthetic":true}'),
      });
      expect(secured, isTrue);
      expect(
        await File(p.join(backup, 'auto-login.json')).readAsString(),
        '{"synthetic":true}',
      );
    },
  );
}

class _Platform implements SteamClientPlatform {
  bool supported = true;
  bool running = false;
  bool exits = true;
  bool failRegistry = false;
  bool failStart = false;
  bool failStatus = false;
  String? activeSteamId;
  void Function()? onShutdown;
  void Function()? onStart;
  SteamAutoLogin registry = const SteamAutoLogin(
    autoLoginUser: 'alice',
    rememberPassword: 0,
  );
  final calls = <String>[];

  @override
  bool get isSupported => supported;
  @override
  Future<String?> discoverPath() async => _path;
  @override
  Future<bool> isRunning(String path) async => running;
  @override
  Future<SteamClientStatus> status(String path) async {
    calls.add('status');
    if (failStatus) throw StateError('process query failed');
    return SteamClientStatus(
      running: running,
      activeSteamId: running ? activeSteamId : null,
    );
  }

  @override
  Future<void> shutdown(String path) async {
    calls.add('shutdown');
    onShutdown?.call();
    if (exits) running = false;
  }

  @override
  Future<void> start(String path) async {
    calls.add('start');
    onStart?.call();
    if (failStart) throw StateError('launch failed');
  }

  @override
  Future<SteamAutoLogin> readAutoLogin() async => registry;
  @override
  Future<void> writeAutoLogin(SteamAutoLogin value) async {
    calls.add('registry');
    registry = value;
    if (failRegistry) {
      failRegistry = false;
      throw StateError('registry write failed');
    }
  }
}

class _Files implements SteamClientFiles {
  final data = <String, List<int>>{
    p.join(_path, 'steam.exe'): [0],
    _loginPath: utf8.encode(_login),
    _configPath: utf8.encode(_config),
  };
  Map<String, List<int>>? backups;
  int reads = 0;
  int writes = 0;
  int? failWrite;
  bool failAfterWrite = false;
  bool failBackup = false;
  void Function()? onBackup;
  Future<void>? backupGate;
  final backupStarted = Completer<void>();

  @override
  Future<bool> exists(String path) async => data.containsKey(path);
  @override
  Future<List<int>> read(String path) async {
    reads++;
    return List<int>.of(data[path]!);
  }

  @override
  Future<String> backup(
    String steamPath,
    Map<String, List<int>> originals,
  ) async {
    backupStarted.complete();
    await backupGate;
    if (failBackup) throw StateError('backup failed');
    backups = {
      for (final entry in originals.entries)
        entry.key: List<int>.of(entry.value),
    };
    onBackup?.call();
    return 'private-backup';
  }

  @override
  Future<void> replace(
    String path,
    List<int> expected,
    List<int> replacement,
  ) async {
    writes++;
    if (writes == failWrite && !failAfterWrite) {
      throw StateError('write failed');
    }
    if (base64.encode(data[path]!) != base64.encode(expected)) {
      throw const SteamClientException('concurrent_change', 'external edit');
    }
    data[path] = List<int>.of(replacement);
    if (writes == failWrite && failAfterWrite) {
      throw StateError('write failed after write');
    }
  }
}
