import 'dart:io';

enum ForkUpdateTarget { windowsX64, androidArm64 }

enum ForkUpdateDownloadMode { automatic, github }

enum ForkUpdateDownloadSource { axisNow, v4, github }

enum ForkUpdateCheckStatus {
  available,
  upToDate,
  noRelease,
  noCompatibleAsset,
  unverifiable,
  invalidMetadata,
  networkError,
  unsupported,
}

class ForkUpdateCheck {
  const ForkUpdateCheck({required this.status, this.release});

  final ForkUpdateCheckStatus status;
  final ForkUpdateRelease? release;
}

class ForkUpdateRelease {
  const ForkUpdateRelease({
    required this.target,
    required this.tag,
    required this.version,
    required this.buildNumber,
    required this.notes,
    required this.releaseUrl,
    required this.asset,
  });

  final ForkUpdateTarget target;
  final String tag;
  final String version;
  final int buildNumber;
  final String notes;
  final Uri releaseUrl;
  final ForkUpdateAsset asset;
}

class ForkUpdateAsset {
  const ForkUpdateAsset({
    required this.name,
    required this.url,
    required this.size,
    required this.sha256,
  });

  final String name;
  final Uri url;
  final int size;

  /// GitHub's SHA-256 digest, without the `sha256:` prefix. Null means that
  /// release information can be displayed but the file cannot be installed.
  final String? sha256;
}

/// A completed download. This is a value object, not an authorization token:
/// the installer must call ForkUpdateService.verifyAgain immediately before
/// handing this file to the operating system.
class VerifiedForkUpdate {
  const VerifiedForkUpdate({required this.file, required this.release});

  final File file;
  final ForkUpdateRelease release;
}

enum ForkUpdateErrorCode {
  cancelled,
  networkError,
  invalidMetadata,
  unverifiable,
  tooLarge,
  hashMismatch,
  ioError,
}

class ForkUpdateException implements Exception {
  const ForkUpdateException(this.code);

  final ForkUpdateErrorCode code;

  // Never include a signed redirect URL or a local filesystem path in UI/logs.
  @override
  String toString() => 'ForkUpdateException(${code.name})';
}
