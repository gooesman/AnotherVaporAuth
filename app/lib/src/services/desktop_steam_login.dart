import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/models/steam_guard_account.dart';
import '../core/protocol/qr_approval_client.dart';
import 'screen_qr_capture.dart';
import 'steam_client_service.dart';
import 'steam_request_scope.dart';

enum DesktopLoginStage { preparing, waitingQr, approving, waitingAccount }

enum DesktopLoginOutcome {
  loggedIn,
  manualRequired,
  approvedUnconfirmed,
  cancelled,
  differentAccount,
}

class DesktopLoginResult {
  const DesktopLoginResult(this.outcome, {this.backupPath});
  final DesktopLoginOutcome outcome;
  final String? backupPath;
}

class DesktopLoginQr {
  const DesktopLoginQr(this.window, this.challenge);
  final String window;
  final QrChallenge challenge;

  bool sameRequest(DesktopLoginQr other) =>
      window == other.window &&
      challenge.version == other.challenge.version &&
      challenge.clientId == other.challenge.clientId;
}

/// Windows limits a lease to newly created, installation-owned Steam login
/// windows. It returns only their visible client area, never a full screenshot.
/// Decoding stays local and off the UI thread; pixels are never persisted.
class DesktopLoginCapture {
  const DesktopLoginCapture([
    this.channel = MethodChannelSteamClientPlatform.channel,
  ]);
  final MethodChannel channel;

  Future<int> begin(String path) async {
    final attempt = await channel.invokeMethod<int>('beginLoginCapture', {
      'path': path,
    });
    if (attempt == null || attempt <= 0) {
      throw const SteamClientException('capture_failed', 'No capture lease.');
    }
    return attempt;
  }

  Future<void> end(String path, int attempt) => channel.invokeMethod<void>(
    'endLoginCapture',
    {'path': path, 'attempt': attempt},
  );

  Future<DesktopLoginQr?> read(String path, int attempt) async {
    final raw = await channel.invokeMapMethod<String, dynamic>(
      'captureLoginWindow',
      {'path': path, 'attempt': attempt},
    );
    if (raw == null) return null;
    final region = ScreenQrRegion.fromMap(raw);
    try {
      final window = raw['window'];
      if (window is! String || window.isEmpty || window.length > 160) {
        throw const FormatException('Invalid Steam window identity');
      }
      final text = await compute(decodeScreenQr, region);
      final challenge = text == null ? null : QrChallenge.tryParse(text);
      return challenge == null ? null : DesktopLoginQr(window, challenge);
    } finally {
      region.bgra.fillRange(0, region.bgra.length, 0);
    }
  }
}

/// A single explicit click owns a bounded local launch-and-approval attempt.
/// Pending account requests are deliberately never queried: only a challenge
/// read twice from the same verified local window can be authorized.
class DesktopSteamLogin {
  DesktopSteamLogin({
    required this.steam,
    required this.approval,
    required this.ensureSession,
    this.capture = const DesktopLoginCapture(),
    this.timeout = const Duration(seconds: 75),
    this.pollInterval = const Duration(seconds: 1),
  });

  final SteamClientService steam;
  final QrApprovalClient approval;
  final Future<bool> Function(SteamGuardAccount) ensureSession;
  final DesktopLoginCapture capture;
  final Duration timeout;
  final Duration pollInterval;
  static bool _busy = false;

  Future<DesktopLoginResult> login({
    required String path,
    required SteamGuardAccount account,
    required bool Function() isCurrent,
    SteamRequestScope? requestScope,
    void Function(DesktopLoginStage)? onProgress,
  }) async {
    if (_busy) {
      throw const SteamClientException(
        'busy',
        'A desktop login is in progress.',
      );
    }
    _busy = true;
    final steamId = account.steamId;
    final secret = account.sharedSecret;
    final accountName = account.accountName;
    int? attempt;
    String? backupPath;
    var submitted = false;
    final scope =
        requestScope ?? SteamRequestScope(timeout: const Duration(seconds: 20));
    bool current() =>
        isCurrent() &&
        account.steamId == steamId &&
        account.sharedSecret == secret &&
        account.accountName == accountName;
    DesktopLoginResult done(DesktopLoginOutcome outcome) =>
        DesktopLoginResult(outcome, backupPath: backupPath);
    DesktopLoginResult cancelled() => done(
      submitted
          ? DesktopLoginOutcome.approvedUnconfirmed
          : DesktopLoginOutcome.cancelled,
    );
    void progress(DesktopLoginStage stage) {
      onProgress?.call(stage);
    }

    try {
      if (!current() || steamId <= 0) {
        return done(DesktopLoginOutcome.cancelled);
      }
      progress(DesktopLoginStage.preparing);
      final initial = await steam.status(path);
      if (!current()) return cancelled();
      if (initial.running && initial.activeSteamId == '$steamId') {
        await steam.open(path);
        final checked = await steam.status(path);
        if (!current()) return cancelled();
        return done(
          checked.running && checked.activeSteamId == '$steamId'
              ? DesktopLoginOutcome.loggedIn
              : DesktopLoginOutcome.manualRequired,
        );
      }
      // Renew/persist before disrupting Steam. No working session means that
      // one-click approval cannot be promised, so leave the client untouched.
      if (!await scope.run(() => ensureSession(account))) {
        throw const SteamClientException(
          'session_expired',
          'Refresh this account session.',
        );
      }
      if (!current()) return cancelled();
      if (!qrApprovalIdentityMatches(account) ||
          secret == null ||
          secret.isEmpty) {
        throw const SteamClientException(
          'identity_mismatch',
          'Account identity changed.',
        );
      }
      attempt = await capture.begin(path);
      if (!current()) return cancelled();
      backupPath = (await steam.prepareLogin(
        path: path,
        steamId: '$steamId',
      )).backupPath;
      final clock = Stopwatch()..start();
      progress(DesktopLoginStage.waitingQr);
      while (clock.elapsed < timeout) {
        if (!current()) return cancelled();
        final status = await steam.status(path);
        if (!current()) return cancelled();
        if (status.running && status.activeSteamId != null) {
          return done(
            status.activeSteamId == '$steamId'
                ? DesktopLoginOutcome.loggedIn
                : DesktopLoginOutcome.differentAccount,
          );
        }
        if (!submitted && status.running) {
          final qr = await capture.read(path, attempt);
          if (!current()) return cancelled();
          if (qr != null) {
            final info = await scope.run(
              () => approval.sessionInfo(account, qr.challenge.clientId),
            );
            if (!current()) return cancelled();
            if (info == null ||
                info.platformType != 1 ||
                info.clientId != qr.challenge.clientId ||
                info.version != qr.challenge.version) {
              return done(DesktopLoginOutcome.manualRequired);
            }
            // Network lookup can outlive a QR refresh or window replacement.
            // Re-capture and require the exact process/window and QR tuple.
            final latest = await capture.read(path, attempt);
            if (!current()) return cancelled();
            if (latest == null || !qr.sameRequest(latest)) {
              await Future<void>.delayed(pollInterval);
              continue;
            }
            if (!qrApprovalIdentityMatches(account)) {
              throw const SteamClientException(
                'identity_mismatch',
                'Account identity changed.',
              );
            }
            progress(DesktopLoginStage.approving);
            if (!current()) return cancelled();
            if (clock.elapsed >= timeout) {
              return done(DesktopLoginOutcome.manualRequired);
            }
            // Do not retry an ambiguous submission: Steam may have accepted it.
            // The subsequent runtime check, never the HTTP response, proves login.
            try {
              submitted = true;
              final accepted = await scope.run(
                () => approval.respond(account, qr.challenge, approve: true),
              );
              if (!accepted) return done(DesktopLoginOutcome.manualRequired);
            } catch (_) {
              // Submission may have reached Steam. Never label this confirmed
              // or authorize another challenge automatically after ambiguity.
            }
            progress(DesktopLoginStage.waitingAccount);
          }
        }
        await Future<void>.delayed(pollInterval);
      }
      return done(
        submitted
            ? DesktopLoginOutcome.approvedUnconfirmed
            : DesktopLoginOutcome.manualRequired,
      );
    } on SteamClientException catch (error) {
      if (!current()) return cancelled();
      if (backupPath == null) rethrow;
      throw SteamClientException(
        error.code,
        error.message,
        backupPath: error.backupPath ?? backupPath,
        rollbackIncomplete: error.rollbackIncomplete,
      );
    } catch (_) {
      if (!current()) return cancelled();
      if (submitted) return done(DesktopLoginOutcome.approvedUnconfirmed);
      if (backupPath != null) return done(DesktopLoginOutcome.manualRequired);
      rethrow;
    } finally {
      scope.cancel();
      if (attempt != null) {
        try {
          await capture.end(path, attempt);
        } catch (_) {}
      }
      _busy = false;
    }
  }
}
