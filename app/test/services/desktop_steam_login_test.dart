import 'dart:async';
import 'dart:convert';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/protocol/qr_approval_client.dart';
import 'package:ava/src/services/desktop_steam_login.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/steam_client_service.dart';
import 'package:ava/src/services/steam_network.dart';
import 'package:ava/src/services/steam_request_scope.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zxing2/qrcode.dart';

const _id = 76561198000000001;
const _qr = DesktopLoginQr('owned-window:pid:start', QrChallenge(1, 123));

class _Steam extends SteamClientService {
  final calls = <String>[];
  SteamClientStatus value = const SteamClientStatus(running: false);
  Future<SteamClientStatus> Function()? reader;
  Object? launchError;
  SteamClientStatus? preparedStatus;
  @override
  Future<SteamClientStatus> status(String path) async {
    calls.add('status');
    return reader == null ? value : await reader!();
  }

  @override
  Future<void> open(String path) async {
    calls.add('open');
  }

  @override
  Future<SteamSwitchResult> prepareLogin({
    required String path,
    required String steamId,
    void Function(SteamSwitchStage)? onProgress,
  }) async {
    calls.add('prepare:$steamId');
    if (launchError != null) throw launchError!;
    value = preparedStatus ?? const SteamClientStatus(running: true);
    return const SteamSwitchResult(backupPath: 'private-backup');
  }
}

class _Capture extends DesktopLoginCapture {
  final calls = <String>[];
  Object? beginError;
  Future<DesktopLoginQr?> Function()? reader;
  @override
  Future<int> begin(String path) async {
    calls.add('begin');
    if (beginError != null) throw beginError!;
    return 7;
  }

  @override
  Future<void> end(String path, int attempt) async {
    calls.add('end:$attempt');
  }

  @override
  Future<DesktopLoginQr?> read(String path, int attempt) async {
    calls.add('read:$attempt');
    return reader == null ? _qr : await reader!();
  }
}

class _Approval extends QrApprovalClient {
  _Approval() : super(SteamApiClient());
  int reads = 0, responses = 0;
  int? platformType = 1;
  int version = 1;
  Future<void> Function()? onInfo;
  Future<bool> Function()? onRespond;
  @override
  Future<List<int>> pendingLoginClientIds(SteamGuardAccount account) =>
      throw StateError('Never inspect unrelated pending requests');
  @override
  Future<AuthSessionInfo?> sessionInfo(
    SteamGuardAccount account,
    int clientId,
  ) async {
    reads++;
    expect(clientId, 123);
    await onInfo?.call();
    return AuthSessionInfo(
      clientId: clientId,
      version: version,
      ip: '',
      city: '',
      country: '',
      deviceName: 'PC',
      platformType: platformType,
    );
  }

  @override
  Future<bool> respond(
    SteamGuardAccount account,
    QrChallenge challenge, {
    required bool approve,
  }) async {
    responses++;
    expect(account.steamId, _id);
    expect(challenge.clientId, 123);
    expect(approve, isTrue);
    return onRespond == null ? true : await onRespond!();
  }
}

class _QueuedApproval extends QrApprovalClient {
  _QueuedApproval(super.api);
  final entered = Completer<void>();
  @override
  Future<AuthSessionInfo?> sessionInfo(
    SteamGuardAccount account,
    int clientId,
  ) async => AuthSessionInfo(
    clientId: clientId,
    version: 1,
    ip: '',
    city: '',
    country: '',
    deviceName: 'PC',
    platformType: 1,
  );
  @override
  Future<bool> respond(
    SteamGuardAccount account,
    QrChallenge challenge, {
    required bool approve,
  }) {
    entered.complete();
    return super.respond(account, challenge, approve: approve);
  }
}

class _Adapter implements HttpClientAdapter {
  int requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return ResponseBody.fromBytes(
      [],
      200,
      headers: {
        'x-eresult': ['1'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Steam steam;
  late _Capture capture;
  late _Approval approval;
  late SteamGuardAccount account;
  late DesktopSteamLogin service;
  var available = true;
  var session = true;
  setUp(() {
    steam = _Steam();
    capture = _Capture();
    approval = _Approval();
    available = true;
    session = true;
    account = SteamGuardAccount(
      accountName: 'test',
      sharedSecret: 'aGVsbG8=',
      session: SessionData(
        steamId: _id,
        accessToken: 'e30.${base64Url.encode(utf8.encode('{"sub":"$_id"}'))}.x',
      ),
    );
    service = DesktopSteamLogin(
      steam: steam,
      capture: capture,
      approval: approval,
      ensureSession: (_) async => session,
      timeout: const Duration(seconds: 2),
      pollInterval: Duration.zero,
    );
  });
  Future<DesktopLoginResult> run() => service.login(
    path: 'mock-steam',
    account: account,
    isCurrent: () => available,
  );
  void shortTimeout() {
    service = DesktopSteamLogin(
      steam: steam,
      capture: capture,
      approval: approval,
      ensureSession: (_) async => session,
      timeout: const Duration(milliseconds: 100),
      pollInterval: Duration.zero,
    );
  }

  test(
    'only one local QR is approved and live selected identity proves completion',
    () async {
      approval.onRespond = () async {
        steam.value = const SteamClientStatus(
          running: true,
          activeSteamId: '$_id',
        );
        return true;
      };
      final result = await run();
      expect(result.outcome, DesktopLoginOutcome.loggedIn);
      expect(result.backupPath, 'private-backup');
      expect(approval.responses, 1);
      expect(capture.calls, ['begin', 'read:7', 'read:7', 'end:7']);
      expect(steam.calls, contains('prepare:$_id'));
    },
  );
  test(
    'already selected account is opened without restart, capture or approval',
    () async {
      steam.value = const SteamClientStatus(
        running: true,
        activeSteamId: '$_id',
      );
      expect((await run()).outcome, DesktopLoginOutcome.loggedIn);
      expect(steam.calls, ['status', 'open', 'status']);
      expect(capture.calls, isEmpty);
      expect(approval.responses, 0);
    },
  );
  test(
    'running other account is prepared before session check and selected local login is approved',
    () async {
      steam.value = const SteamClientStatus(
        running: true,
        activeSteamId: '76561198000000002',
      );
      service = DesktopSteamLogin(
        steam: steam,
        capture: capture,
        approval: approval,
        ensureSession: (selected) async {
          expect(selected, same(account));
          expect(steam.calls, ['status', 'prepare:$_id', 'status']);
          return true;
        },
        pollInterval: Duration.zero,
      );
      approval.onRespond = () async {
        steam.value = const SteamClientStatus(
          running: true,
          activeSteamId: '$_id',
        );
        return true;
      };
      expect((await run()).outcome, DesktopLoginOutcome.loggedIn);
      expect(approval.responses, 1);
      expect(capture.calls, ['begin', 'read:7', 'read:7', 'end:7']);
      expect(steam.calls.where((call) => call == 'open'), isEmpty);
    },
  );
  test(
    'failed session renewal still launches Steam before offering login',
    () async {
      session = false;
      final result = await run();
      expect(result.outcome, DesktopLoginOutcome.sessionRequired);
      expect(result.backupPath, 'private-backup');
      expect(steam.calls.where((call) => call != 'status'), ['prepare:$_id']);
      expect(capture.calls, ['begin', 'end:7']);
      expect(approval.responses, 0);
    },
  );
  test('mismatched token never approves even after local launch', () async {
    account.session.accessToken =
        'e30.${base64Url.encode(utf8.encode('{"sub":"12"}'))}.x';
    await expectLater(
      run(),
      throwsA(
        isA<SteamClientException>().having(
          (e) => e.code,
          'code',
          'identity_mismatch',
        ),
      ),
    );
    expect(steam.calls.where((call) => call != 'status'), ['prepare:$_id']);
    expect(capture.calls, ['begin', 'end:7']);
    expect(approval.responses, 0);
  });
  test('imported account without a session can still open Steam', () async {
    account.session.accessToken = null;
    expect((await run()).outcome, DesktopLoginOutcome.sessionRequired);
    expect(steam.calls.where((call) => call != 'status'), ['prepare:$_id']);
    expect(approval.responses, 0);
  });
  test(
    'remembered login verifies actual client even without an AVA session',
    () async {
      account.session.accessToken = null;
      steam.preparedStatus = const SteamClientStatus(
        running: true,
        activeSteamId: '$_id',
      );
      expect((await run()).outcome, DesktopLoginOutcome.loggedIn);
      expect(approval.responses, 0);
      expect(capture.calls, ['begin', 'end:7']);
    },
  );
  for (final throwsNetwork in [false, true]) {
    test(
      'client completed remembered login during failed session renewal ($throwsNetwork)',
      () async {
        service = DesktopSteamLogin(
          steam: steam,
          capture: capture,
          approval: approval,
          ensureSession: (_) async {
            steam.value = const SteamClientStatus(
              running: true,
              activeSteamId: '$_id',
            );
            if (throwsNetwork) throw StateError('offline');
            return false;
          },
        );
        final result = await run();
        expect(result.outcome, DesktopLoginOutcome.loggedIn);
        expect(result.diagnostic, isNull);
        expect(approval.responses, 0);
        expect(approval.reads, 0);
      },
    );
  }
  test(
    'different client after remembered login is not approved despite no session',
    () async {
      account.session.accessToken = null;
      steam.preparedStatus = const SteamClientStatus(
        running: true,
        activeSteamId: '76561198000000002',
      );
      expect((await run()).outcome, DesktopLoginOutcome.differentAccount);
      expect(approval.responses, 0);
    },
  );
  test(
    'network exception after launch has sanitized stage diagnostics',
    () async {
      service = DesktopSteamLogin(
        steam: steam,
        capture: capture,
        approval: approval,
        ensureSession: (_) async {
          expect(steam.calls, contains('prepare:$_id'));
          throw StateError('secret-token-and-account-url');
        },
      );
      final result = await run();
      expect(result.outcome, DesktopLoginOutcome.manualRequired);
      expect(result.diagnostic?.code, 'session_failed');
      expect(result.diagnostic?.stage, 'connecting');
      expect(result.diagnostic.toString(), isNot(contains('secret-token')));
      expect(result.backupPath, 'private-backup');
      expect(approval.responses, 0);
    },
  );
  test('capture bridge failure does not block local Steam launch', () async {
    capture.beginError = PlatformException(
      code: 'login_capture_failed',
      message: 'private-path',
      details: {'win32Error': 5},
    );
    final result = await run();
    expect(result.outcome, DesktopLoginOutcome.manualRequired);
    expect(steam.calls.where((call) => call != 'status'), ['prepare:$_id']);
    expect(result.diagnostic?.nativeCode, 'login_capture_failed');
    expect(result.diagnostic?.win32Error, 5);
    expect(approval.responses, 0);
  });
  test('advisory status failure does not block local preparation', () async {
    steam.reader = () async =>
        throw const SteamClientException('status_unavailable', 'unavailable');
    account.session.accessToken = null;
    expect((await run()).outcome, DesktopLoginOutcome.sessionRequired);
    expect(steam.calls.where((call) => call != 'status'), ['prepare:$_id']);
  });
  for (final type in <int?>[null, 0, 2, 3]) {
    test(
      'non-desktop or absent platform type $type cannot be auto-approved',
      () async {
        approval.platformType = type;
        expect((await run()).outcome, DesktopLoginOutcome.manualRequired);
        expect(approval.responses, 0);
        expect(capture.calls.last, 'end:7');
      },
    );
  }
  test('session version mismatch cannot be approved', () async {
    approval.version = 2;
    expect((await run()).outcome, DesktopLoginOutcome.manualRequired);
    expect(approval.responses, 0);
  });
  test(
    'removed/locked account while session details load cancels approval',
    () async {
      approval.onInfo = () async {
        available = false;
      };
      expect((await run()).outcome, DesktopLoginOutcome.cancelled);
      expect(approval.responses, 0);
      expect(capture.calls.last, 'end:7');
    },
  );
  test(
    'account identity mutation while session details load cancels approval',
    () async {
      approval.onInfo = () async {
        account.session.steamId = 123;
      };
      expect((await run()).outcome, DesktopLoginOutcome.cancelled);
      expect(approval.responses, 0);
    },
  );
  for (final changed in [
    const DesktopLoginQr('different-window', QrChallenge(1, 123)),
    const DesktopLoginQr('owned-window:pid:start', QrChallenge(1, 124)),
    const DesktopLoginQr('owned-window:pid:start', QrChallenge(2, 123)),
  ]) {
    test(
      'revalidation rejects changed window/client/version ${changed.window}/${changed.challenge.clientId}/${changed.challenge.version}',
      () async {
        var reads = 0;
        capture.reader = () async {
          reads++;
          if (reads == 1) return _qr;
          if (reads == 2) return changed;
          available = false;
          return null;
        };
        expect((await run()).outcome, DesktopLoginOutcome.cancelled);
        expect(approval.responses, 0);
      },
    );
  }
  test('explicit rejection is not reported as approved', () async {
    approval.onRespond = () async => false;
    expect((await run()).outcome, DesktopLoginOutcome.manualRequired);
    expect(approval.responses, 1);
  });
  test('ambiguous submission is never retried or declared logged in', () async {
    shortTimeout();
    approval.onRespond = () async {
      throw TimeoutException('ambiguous');
    };
    expect((await run()).outcome, DesktopLoginOutcome.approvedUnconfirmed);
    expect(approval.responses, 1);
    expect(capture.calls.where((c) => c.startsWith('read')), hasLength(2));
  });
  test(
    'accepted QR without verified client identity remains unconfirmed',
    () async {
      shortTimeout();
      expect((await run()).outcome, DesktopLoginOutcome.approvedUnconfirmed);
      expect(approval.responses, 1);
    },
  );
  test('different live account stops without any QR authorization', () async {
    var statusReads = 0;
    steam.reader = () async => ++statusReads == 1
        ? const SteamClientStatus(running: false)
        : const SteamClientStatus(
            running: true,
            activeSteamId: '76561198000000002',
          );
    expect((await run()).outcome, DesktopLoginOutcome.differentAccount);
    expect(approval.responses, 0);
    expect(capture.calls, ['begin', 'end:7']);
  });
  test('no window/QR times out to a truthful manual fallback', () async {
    shortTimeout();
    capture.reader = () async => null;
    expect((await run()).outcome, DesktopLoginOutcome.manualRequired);
    expect(approval.responses, 0);
    expect(approval.reads, 0);
  });
  test('launch error closes capture lease without authorization', () async {
    steam.launchError = const SteamClientException('launch_failed', 'failed');
    await expectLater(run(), throwsA(isA<SteamClientException>()));
    expect(capture.calls, ['begin', 'end:7']);
    expect(approval.responses, 0);
  });
  test(
    'concurrent one-click attempts are serialized across service instances',
    () async {
      final gate = Completer<void>();
      approval.onInfo = () => gate.future;
      final first = run();
      while (approval.reads == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
        run(),
        throwsA(
          isA<SteamClientException>().having((e) => e.code, 'code', 'busy'),
        ),
      );
      available = false;
      gate.complete();
      expect((await first).outcome, DesktopLoginOutcome.cancelled);
    },
  );

  test(
    'cancellation while proxy readiness queues approval prevents HTTP dispatch',
    () async {
      final ready = Completer<void>();
      SteamNetwork.configureProxy(() => null, readiness: ready.future);
      addTearDown(() => SteamNetwork.configureProxy(() => null));
      final dio = SteamNetwork.createDio(BaseOptions());
      final adapter = _Adapter();
      dio.httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final client = _QueuedApproval(SteamApiClient(dio: dio));
      final scope = SteamRequestScope();
      final queued = DesktopSteamLogin(
        steam: steam,
        capture: capture,
        approval: client,
        ensureSession: (_) async => true,
        pollInterval: Duration.zero,
      );
      final future = queued.login(
        path: 'mock-steam',
        account: account,
        isCurrent: () => available,
        requestScope: scope,
      );
      await client.entered.future;
      await Future<void>.delayed(Duration.zero);
      available = false;
      scope.cancel();
      final result = await future;
      ready.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(adapter.requests, 0);
      expect(result.outcome, DesktopLoginOutcome.approvedUnconfirmed);
      expect(capture.calls.last, 'end:7');
    },
  );

  test(
    'cancelling session renewal after local launch never begins approval',
    () async {
      final entered = Completer<void>();
      final gate = Completer<bool>();
      final scope = SteamRequestScope();
      final flow = DesktopSteamLogin(
        steam: steam,
        capture: capture,
        approval: approval,
        ensureSession: (_) {
          expect(steam.calls, contains('prepare:$_id'));
          entered.complete();
          return gate.future;
        },
      );
      final pending = flow.login(
        path: 'mock-steam',
        account: account,
        isCurrent: () => available,
        requestScope: scope,
      );
      await entered.future;
      available = false;
      scope.cancel();
      expect((await pending).outcome, DesktopLoginOutcome.cancelled);
      gate.complete(true);
      expect(approval.responses, 0);
      expect(approval.reads, 0);
      expect(capture.calls, ['begin', 'end:7']);
    },
  );

  test(
    'desktop capture decodes real read-only engine envelope without cleanup failure',
    () async {
      const channel = MethodChannel('desktop-readonly-codec-test');
      const text = 'https://s.team/q/1/123';
      final matrix = Encoder.encode(text, ErrorCorrectionLevel.m).matrix!;
      const scale = 6, border = 4;
      final size = (matrix.width + border * 2) * scale;
      final pixels = Uint8List(size * size * 4);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final mx = x ~/ scale - border, my = y ~/ scale - border;
          final dark =
              mx >= 0 &&
              my >= 0 &&
              mx < matrix.width &&
              my < matrix.height &&
              matrix.get(mx, my) == 1;
          final at = (y * size + x) * 4;
          pixels[at] = pixels[at + 1] = pixels[at + 2] = dark ? 0 : 255;
          pixels[at + 3] = 255;
        }
      }
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler(channel.name, (message) async {
        final call = const StandardMethodCodec().decodeMethodCall(message);
        expect(call.method, 'captureLoginWindow');
        expect(call.arguments, {'path': 'synthetic', 'attempt': 7});
        return const StandardMethodCodec().encodeSuccessEnvelope({
          'window': 'owned:pid:creation',
          'width': size,
          'height': size,
          'bgra': pixels,
        }).asUnmodifiableView();
      });
      addTearDown(() => messenger.setMockMessageHandler(channel.name, null));
      final result = await const DesktopLoginCapture(
        channel,
      ).read('synthetic', 7);
      expect(result?.window, 'owned:pid:creation');
      expect(result?.challenge.clientId, 123);
      expect(result?.challenge.version, 1);
    },
  );

  test(
    'native capture uses bounded lease commands and invalid pixels fail closed',
    () async {
      const channel = MethodChannel('desktop-login-test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'beginLoginCapture') return 12;
        if (call.method == 'captureLoginWindow') {
          return {
            'window': 'owned',
            'width': 1000000,
            'height': 1000000,
            'bgra': Uint8List(4),
          };
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const native = DesktopLoginCapture(channel);
      expect(await native.begin('installation'), 12);
      await expectLater(native.read('installation', 12), throwsFormatException);
      await native.end('installation', 12);
      expect(calls.map((c) => c.method), [
        'beginLoginCapture',
        'captureLoginWindow',
        'endLoginCapture',
      ]);
      expect(calls[1].arguments, {'path': 'installation', 'attempt': 12});
    },
  );
}
