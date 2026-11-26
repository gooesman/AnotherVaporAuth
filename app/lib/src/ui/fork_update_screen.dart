import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/app_localizations.dart';
import '../app/responsive.dart';
import '../app/steam_acceleration_providers.dart';
import '../app/theme.dart';
import '../core/fork_update.dart';
import '../services/fork_update_installer.dart';
import '../services/fork_update_service.dart';
import 'widgets/ava_panel.dart';
import 'widgets/scanline_overlay.dart';

final forkUpdateServiceProvider = Provider<ForkUpdateService>(
  (ref) => ForkUpdateService(),
);
final forkUpdateInstallerProvider = Provider<ForkUpdateInstaller>(
  (ref) => ForkUpdateInstaller(),
);
final forkUpdatePrepareNetworkProvider = Provider<Future<void> Function()>((
  ref,
) {
  final service = ref.watch(steamAccelerationServiceProvider);
  return () async {
    if (service.supported) {
      await service.checkEnvironment(allowAutomaticStart: false);
    }
  };
});
final forkUpdateTargetProvider = Provider<ForkUpdateTarget?>((ref) {
  if (kIsWeb) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows => ForkUpdateTarget.windowsX64,
    TargetPlatform.android => ForkUpdateTarget.androidArm64,
    _ => null,
  };
});
final forkUpdatePackageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

enum _Failure { download, hash, install, permission, signature, package }

/// Only downloads after an explicit action, and only passes verified files to
/// the platform installer after a second, separate confirmation.
class ForkUpdateScreen extends ConsumerStatefulWidget {
  const ForkUpdateScreen({super.key});

  @override
  ConsumerState<ForkUpdateScreen> createState() => _ForkUpdateScreenState();
}

class _ForkUpdateScreenState extends ConsumerState<ForkUpdateScreen> {
  ForkUpdateCheck? _checkResult;
  VerifiedForkUpdate? _verified;
  PackageInfo? _installed;
  CancelToken? _downloadCancel;
  _Failure? _failure;
  bool _checking = true;
  bool _downloading = false;
  bool _installing = false;
  bool _cancelled = false;
  bool _installStarted = false;
  int _received = 0;
  int _total = 0;
  int _latestReceived = 0;
  int _latestTotal = 0;
  double _bytesPerSecond = 0;
  bool _verifying = false;
  ForkUpdateDownloadMode _downloadMode = ForkUpdateDownloadMode.automatic;
  ForkUpdateDownloadSource? _downloadSource;
  Timer? _progressTimer;
  final _progressSamples = <(int, int)>[];
  int _operation = 0;

  static const _progressInterval = Duration(milliseconds: 250);
  static const _speedWindowMilliseconds = 2000;

  bool get _busy => _checking || _downloading || _installing;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  @override
  void dispose() {
    _operation++;
    _downloadCancel?.cancel();
    _stopProgress();
    super.dispose();
  }

  Future<void> _check() async {
    if (_downloading || _installing) return;
    final operation = ++_operation;
    setState(() {
      _checking = true;
      _checkResult = null;
      _verified = null;
      _failure = null;
      _cancelled = false;
      _installStarted = false;
      _downloadSource = null;
    });
    try {
      final target = ref.read(forkUpdateTargetProvider);
      if (target == null) {
        if (mounted && operation == _operation) {
          setState(() {
            _checkResult = const ForkUpdateCheck(
              status: ForkUpdateCheckStatus.unsupported,
            );
          });
        }
        return;
      }
      final installed = await ref.read(forkUpdatePackageInfoProvider.future);
      if (!mounted || operation != _operation) return;
      setState(() => _installed = installed);
      await ref.read(forkUpdatePrepareNetworkProvider)();
      if (!mounted || operation != _operation) return;
      final result = await ref
          .read(forkUpdateServiceProvider)
          .check(
            target: target,
            currentVersion: installed.version,
            currentBuild: installed.buildNumber,
          );
      if (!mounted || operation != _operation) return;
      setState(() => _checkResult = result);
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(() {
          _checkResult = const ForkUpdateCheck(
            status: ForkUpdateCheckStatus.networkError,
          );
        });
      }
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _download() async {
    final release = _checkResult?.release;
    if (_busy ||
        release == null ||
        _checkResult?.status != ForkUpdateCheckStatus.available) {
      return;
    }
    final operation = ++_operation;
    final cancel = CancelToken();
    _downloadCancel = cancel;
    setState(() {
      _downloading = true;
      _verified = null;
      _failure = null;
      _cancelled = false;
      _installStarted = false;
      _received = 0;
      _total = release.asset.size;
      _latestReceived = 0;
      _latestTotal = release.asset.size;
      _bytesPerSecond = 0;
      _verifying = false;
      _downloadSource = null;
    });
    _startProgress(operation);
    try {
      await ref.read(forkUpdatePrepareNetworkProvider)();
      if (!mounted || operation != _operation || cancel.isCancelled) return;
      final verified = await ref
          .read(forkUpdateServiceProvider)
          .download(
            release,
            mode: _downloadMode,
            cancelToken: cancel,
            onSourceChanged: (source) {
              if (!mounted ||
                  operation != _operation ||
                  !_downloading ||
                  cancel.isCancelled) {
                return;
              }
              setState(() {
                _downloadSource = source;
                _received = _latestReceived = 0;
                _total = _latestTotal = release.asset.size;
                _bytesPerSecond = 0;
                _verifying = false;
              });
              // A fallback starts a separate, fully verified transfer. Do not
              // carry the previous source's bytes or speed into its estimate.
              _startProgress(operation);
            },
            onProgress: (received, total) {
              if (!mounted ||
                  operation != _operation ||
                  !_downloading ||
                  cancel.isCancelled) {
                return;
              }
              // Transport chunks can arrive far more often than the screen
              // needs to repaint. A fixed sampler coalesces them to 4 Hz.
              _latestTotal = total > 0 ? total : release.asset.size;
              _latestReceived = received.clamp(0, _latestTotal);
            },
          );
      if (!mounted || operation != _operation || cancel.isCancelled) return;
      setState(() => _verified = verified);
    } catch (error) {
      if (!mounted || operation != _operation) return;
      setState(() {
        if (cancel.isCancelled) {
          _cancelled = true;
        } else {
          _failure = _isHashFailure(error) ? _Failure.hash : _Failure.download;
        }
      });
    } finally {
      if (mounted && operation == _operation) {
        _stopProgress();
        setState(() => _downloading = false);
        _downloadCancel = null;
      }
    }
  }

  void _stopProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _progressSamples.clear();
  }

  void _startProgress(int operation) {
    _stopProgress();
    _progressSamples.add((0, 0));
    _progressTimer = Timer.periodic(_progressInterval, (timer) {
      if (!mounted || operation != _operation || !_downloading) {
        timer.cancel();
        return;
      }
      // Timer.tick includes elapsed periods when the event loop is busy, so
      // skipped frames do not inflate the transfer rate. The two-second
      // window also drops stale speed/ETA when a connection stops delivering.
      final elapsed = timer.tick * _progressInterval.inMilliseconds;
      _progressSamples.add((elapsed, _latestReceived));
      while (_progressSamples.length > 2 &&
          elapsed - _progressSamples.first.$1 > _speedWindowMilliseconds) {
        _progressSamples.removeAt(0);
      }
      final (started, previousBytes) = _progressSamples.first;
      final duration = elapsed - started;
      final rate = duration > 0
          ? ((_latestReceived - previousBytes).clamp(0, _latestTotal) *
                1000 /
                duration)
          : 0.0;
      final verifying = _latestTotal > 0 && _latestReceived >= _latestTotal;
      if (_received != _latestReceived ||
          _total != _latestTotal ||
          _bytesPerSecond != rate ||
          _verifying != verifying) {
        setState(() {
          _received = _latestReceived;
          _total = _latestTotal;
          _bytesPerSecond = rate;
          _verifying = verifying;
        });
      }
      // Hash verification can take time, but it needs no transfer timer.
      if (verifying) _stopProgress();
    });
  }

  String _speedText(AppLocalizations l) {
    const mib = 1024 * 1024;
    final useMib = _bytesPerSecond >= mib;
    final speed = _bytesPerSecond / (useMib ? mib : 1024);
    return l.forkUpdateTransferSpeed(
      NumberFormat('0.0', l.localeName).format(speed),
      useMib ? 'MiB' : 'KiB',
    );
  }

  String _remainingText(AppLocalizations l) {
    final seconds = ((_total - _received) / _bytesPerSecond).ceil();
    return seconds < 60
        ? l.forkUpdateRemainingSeconds(seconds)
        : l.forkUpdateRemainingMinutes((seconds / 60).ceil());
  }

  bool _isHashFailure(Object error) =>
      error is ForkUpdateException &&
      error.code == ForkUpdateErrorCode.hashMismatch;

  void _cancelDownload() {
    // Invalidate callbacks immediately, even if the transport completes at
    // the same moment the user cancels. A cancelled result cannot be installed.
    _operation++;
    _downloadCancel?.cancel();
    _stopProgress();
    _downloadCancel = null;
    setState(() {
      _downloading = false;
      _verified = null;
      _cancelled = true;
      _failure = null;
    });
  }

  Future<void> _openPermissionSettings() async {
    if (_busy) return;
    setState(() => _installing = true);
    try {
      await ref
          .read(forkUpdateInstallerProvider)
          .openInstallPermissionSettings();
    } catch (_) {
      if (mounted) setState(() => _failure = _Failure.install);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _install() async {
    final update = _verified;
    if (_busy || update == null) return;
    final installer = ref.read(forkUpdateInstallerProvider);
    setState(() {
      _installing = true;
      _failure = null;
      _installStarted = false;
    });
    try {
      final allowed = await installer.canInstall(update.release.target);
      if (!mounted) return;
      if (!allowed) {
        setState(() => _failure = _Failure.permission);
        return;
      }
      final l = AppLocalizations.of(context);
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.forkUpdateInstallTitle),
          scrollable: true,
          content: Text(
            update.release.target == ForkUpdateTarget.androidArm64
                ? l.forkUpdateInstallAndroid
                : l.forkUpdateInstallWindows,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              key: const ValueKey('fork-update-install-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.forkUpdateInstallConfirm),
            ),
          ],
        ),
      );
      if (approved != true || !mounted || !identical(update, _verified)) return;
      await installer.install(update);
      if (mounted) setState(() => _installStarted = true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = switch (error) {
          ForkUpdateInstallException(code: 'install_permission_required') =>
            _Failure.permission,
          ForkUpdateInstallException(code: 'signature_mismatch') =>
            _Failure.signature,
          ForkUpdateInstallException(code: 'wrong_package') => _Failure.package,
          _ => _isHashFailure(error) ? _Failure.hash : _Failure.install,
        };
        if (_failure == _Failure.hash ||
            _failure == _Failure.signature ||
            _failure == _Failure.package) {
          _verified = null;
        }
      });
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  String _status(AppLocalizations l) {
    if (_checking) return l.forkUpdateChecking;
    return switch (_checkResult?.status) {
      ForkUpdateCheckStatus.available => l.forkUpdateAvailable(
        _checkResult!.release!.tag,
      ),
      ForkUpdateCheckStatus.upToDate => l.forkUpdateUpToDate,
      ForkUpdateCheckStatus.noRelease => l.forkUpdateNoRelease,
      ForkUpdateCheckStatus.noCompatibleAsset => l.forkUpdateNoCompatibleAsset,
      ForkUpdateCheckStatus.unverifiable => l.forkUpdateUnverifiable,
      ForkUpdateCheckStatus.invalidMetadata => l.forkUpdateInvalidMetadata,
      ForkUpdateCheckStatus.networkError => l.forkUpdateCheckFailed,
      ForkUpdateCheckStatus.unsupported => l.forkUpdateUnsupported,
      null => l.forkUpdateCheckFailed,
    };
  }

  String _failureText(AppLocalizations l, _Failure failure) =>
      switch (failure) {
        _Failure.download => l.forkUpdateDownloadFailed,
        _Failure.hash => l.forkUpdateHashFailed,
        _Failure.install => l.forkUpdateInstallFailed,
        _Failure.permission => l.forkUpdatePermissionRequired,
        _Failure.signature => l.forkUpdateSignatureMismatch,
        _Failure.package => l.forkUpdateWrongPackage,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final release = _checkResult?.release;
    final installed = _installed;
    final progress = _total > 0 ? (_received / _total).clamp(0.0, 1.0) : null;
    final amountFormat = NumberFormat('0.0', l.localeName);
    return Scaffold(
      appBar: AppBar(title: Text(l.forkUpdateTitle)),
      body: ScanlineOverlay(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: context.rSafeInsets(all: 20),
              children: [
                AvaPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.system_update_alt, color: t.accent, size: 32),
                      const SizedBox(height: 12),
                      if (installed != null) ...[
                        Text(
                          l.forkUpdateCurrentVersion(
                            '${installed.version}+${installed.buildNumber}',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _status(l),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (_checking) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        key: const ValueKey('fork-update-check'),
                        onPressed: _busy ? null : _check,
                        icon: const Icon(Icons.refresh),
                        label: Text(l.forkUpdateCheck),
                      ),
                      // Keep the download route visible even when this device
                      // is already up to date or the version check fails.
                      if (ref.watch(forkUpdateTargetProvider) != null) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ForkUpdateDownloadMode>(
                          key: const ValueKey('fork-update-source-mode'),
                          initialValue: _downloadMode,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l.forkUpdateSourceLabel,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: ForkUpdateDownloadMode.automatic,
                              child: Text(
                                l.forkUpdateSourceAutomatic,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: ForkUpdateDownloadMode.github,
                              child: Text(
                                l.forkUpdateSourceOfficial,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: _busy || _verified != null
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _downloadMode = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l.forkUpdateConnectionHint,
                          style: TextStyle(color: t.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (release != null) ...[
                  const SizedBox(height: 16),
                  AvaPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.forkUpdateReleaseNotes,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          release.notes.trim().isEmpty
                              ? l.forkUpdateNoNotes
                              : release.notes.trim(),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_checkResult?.status ==
                    ForkUpdateCheckStatus.available) ...[
                  const SizedBox(height: 16),
                  AvaPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_failure == _Failure.download ||
                            _failure == _Failure.hash) ...[
                          Text(
                            _failureText(l, _failure!),
                            key: const ValueKey('fork-update-error'),
                            style: TextStyle(color: t.bad),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_downloadSource case final source?) ...[
                          Text(
                            switch (source) {
                              ForkUpdateDownloadSource.axisNow =>
                                l.forkUpdateSourceAccelerated('AxisNow'),
                              ForkUpdateDownloadSource.v4 =>
                                l.forkUpdateSourceAccelerated('IPv4'),
                              ForkUpdateDownloadSource.github =>
                                l.forkUpdateSourceOfficial,
                            },
                            key: const ValueKey('fork-update-active-source'),
                            style: TextStyle(color: t.muted),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_downloading) ...[
                          Text(
                            _verifying
                                ? l.forkUpdateVerifying
                                : l.forkUpdateDownloading(
                                    progress == null
                                        ? '…'
                                        : '${(progress * 100).round()}%',
                                  ),
                            key: const ValueKey('fork-update-progress-label'),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: _verifying ? null : progress,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l.forkUpdateTransferSize(
                              amountFormat.format(_received / (1024 * 1024)),
                              amountFormat.format(_total / (1024 * 1024)),
                            ),
                            key: const ValueKey('fork-update-transfer-size'),
                            style: TextStyle(color: t.muted),
                          ),
                          if (!_verifying) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  _bytesPerSecond > 0
                                      ? _speedText(l)
                                      : l.forkUpdateWaitingForData,
                                  key: const ValueKey('fork-update-speed'),
                                  style: TextStyle(color: t.muted),
                                ),
                                if (_bytesPerSecond > 0 && _total > _received)
                                  Text(
                                    _remainingText(l),
                                    key: const ValueKey(
                                      'fork-update-remaining',
                                    ),
                                    style: TextStyle(color: t.muted),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextButton(
                            key: const ValueKey('fork-update-cancel-download'),
                            onPressed: _cancelDownload,
                            child: Text(l.forkUpdateCancelDownload),
                          ),
                        ] else if (_verified != null) ...[
                          Text(l.forkUpdateReady),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const ValueKey('fork-update-install'),
                            onPressed: _busy ? null : _install,
                            icon: const Icon(Icons.install_desktop_outlined),
                            label: Text(l.forkUpdateInstall),
                          ),
                        ] else
                          FilledButton.icon(
                            key: const ValueKey('fork-update-download'),
                            onPressed: _busy ? null : _download,
                            icon: const Icon(Icons.download_outlined),
                            label: Text(l.forkUpdateDownload),
                          ),
                        if (_cancelled) Text(l.forkUpdateCancelled),
                      ],
                    ),
                  ),
                ],
                if (_failure case final failure?
                    when failure != _Failure.download &&
                        failure != _Failure.hash) ...[
                  const SizedBox(height: 16),
                  Text(
                    _failureText(l, failure),
                    key: const ValueKey('fork-update-error'),
                    style: TextStyle(color: t.bad),
                  ),
                  if (failure == _Failure.permission)
                    OutlinedButton(
                      key: const ValueKey('fork-update-permission'),
                      onPressed: _busy ? null : _openPermissionSettings,
                      child: Text(l.forkUpdateOpenPermissionSettings),
                    ),
                ],
                if (_installStarted) ...[
                  const SizedBox(height: 16),
                  Text(l.forkUpdateInstallStarted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
