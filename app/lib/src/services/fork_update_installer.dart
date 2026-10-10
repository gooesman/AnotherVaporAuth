import 'dart:io';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../core/fork_update.dart';
import 'fork_update_service.dart';

class ForkUpdateInstallException implements Exception {
  const ForkUpdateInstallException(this.code);

  final String code;

  @override
  String toString() => 'ForkUpdateInstallException($code)';
}

/// Hands a freshly verified download to the operating system. Downloading or
/// constructing a VerifiedForkUpdate alone never authorizes installation.
class ForkUpdateInstaller {
  ForkUpdateInstaller({
    String? operatingSystem,
    this._channel = const MethodChannel('ava/app_update'),
    Future<void> Function(VerifiedForkUpdate)? verify,
    Future<void> Function(String)? launchWindows,
    Future<void> Function()? closeWindows,
  }) : _operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _verify = verify ?? ForkUpdateService().verifyAgain,
       _launchWindows = launchWindows ?? _startWindowsInstaller,
       _closeWindows = closeWindows ?? windowManager.close;

  final String _operatingSystem;
  final MethodChannel _channel;
  final Future<void> Function(VerifiedForkUpdate) _verify;
  final Future<void> Function(String) _launchWindows;
  final Future<void> Function() _closeWindows;
  bool _installing = false;

  void _requireTarget(ForkUpdateTarget target) {
    final supported = switch (target) {
      ForkUpdateTarget.windowsX64 => _operatingSystem == 'windows',
      ForkUpdateTarget.androidArm64 => _operatingSystem == 'android',
    };
    if (!supported) {
      throw const ForkUpdateInstallException('unsupported_platform');
    }
  }

  Future<bool> canInstall(ForkUpdateTarget target) async {
    _requireTarget(target);
    if (target == ForkUpdateTarget.windowsX64) return true;
    return await _invoke<bool>('canInstall') ?? false;
  }

  Future<void> openInstallPermissionSettings() async {
    _requireTarget(ForkUpdateTarget.androidArm64);
    await _invoke<void>('openInstallPermissionSettings');
  }

  Future<void> install(VerifiedForkUpdate update) async {
    _requireTarget(update.release.target);
    if (_installing) {
      throw const ForkUpdateInstallException('install_in_progress');
    }
    _installing = true;
    try {
      // Re-read bytes immediately before launch; a completed download can have
      // been changed or replaced while the confirmation dialog was open.
      await _verify(update);
      if (update.release.target == ForkUpdateTarget.androidArm64) {
        await _invoke<void>('install', {
          'path': update.file.absolute.path,
          'version': update.release.version,
          'buildNumber': update.release.buildNumber,
        });
        // Android reads this URI asynchronously. Keep the APK after handoff.
      } else {
        try {
          await _launchWindows(update.file.absolute.path);
        } catch (_) {
          throw const ForkUpdateInstallException('installer_unavailable');
        }
        // Launch the interactive installer first, then release the running
        // app's files. A launch failure must leave AVA open.
        try {
          await _closeWindows();
        } catch (_) {
          throw const ForkUpdateInstallException('close_failed');
        }
      }
    } finally {
      _installing = false;
    }
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw ForkUpdateInstallException(error.code);
    } on MissingPluginException {
      throw const ForkUpdateInstallException('installer_unavailable');
    }
  }

  static Future<void> _startWindowsInstaller(String path) async {
    await Process.start(
      path,
      const [],
      runInShell: false,
      mode: ProcessStartMode.detached,
    );
  }
}
