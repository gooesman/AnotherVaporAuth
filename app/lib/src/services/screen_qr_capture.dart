import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zxing2/qrcode.dart';

/// Screen pixels only live in memory. Only the decoded text leaves this service;
/// the approval screen still validates Steam's URL and asks before authorizing.
class ScreenQrCapture {
  const ScreenQrCapture([
    this._channel = const MethodChannel('ava/screen_capture'),
  ]);

  final MethodChannel _channel;
  bool get available => Platform.isWindows;

  Future<String?> capture({
    required String instruction,
    required int accent,
  }) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'captureRegion',
      {'instruction': instruction, 'accent': accent},
    );
    if (raw == null) return null; // Esc, right-click or lost selection focus.
    final region = ScreenQrRegion.fromMap(raw);
    try {
      final text = await compute(decodeScreenQr, region);
      if (text == null || text.isEmpty) throw const ScreenQrNotFound();
      return text;
    } finally {
      region.bgra.fillRange(0, region.bgra.length, 0);
    }
  }
}

class ScreenQrNotFound implements Exception {
  const ScreenQrNotFound();
}

/// Only stable diagnostic identifiers cross into the UI. Platform messages can
/// contain filesystem paths or other private context and must not be displayed.
class ScreenQrFailure {
  const ScreenQrFailure(this.code, {this.stage, this.win32Error});

  final String code;
  final String? stage;
  final int? win32Error;

  factory ScreenQrFailure.fromError(Object error) {
    if (error is MissingPluginException) {
      return const ScreenQrFailure('capture_unavailable');
    }
    if (error is FormatException) {
      return const ScreenQrFailure('invalid_pixels', stage: 'decode');
    }
    if (error is! PlatformException) {
      return const ScreenQrFailure('capture_failed');
    }
    const codes = {
      'capture_busy',
      'invalid_arguments',
      'capture_unavailable',
      'capture_failed',
      'capture_prepare_failed',
      'capture_display_failed',
      'desktop_too_large',
      'region_too_large',
      'display_changed',
    };
    const stages = {
      'begin',
      'hide',
      'prepare',
      'snapshot',
      'buffers',
      'display',
      'selection',
      'reply',
      'decode',
    };
    final details = error.details;
    final stage = details is Map ? details['stage'] : null;
    final systemError = details is Map ? details['win32Error'] : null;
    return ScreenQrFailure(
      codes.contains(error.code) ? error.code : 'capture_failed',
      stage: stage is String && stages.contains(stage) ? stage : null,
      win32Error:
          systemError is int && systemError > 0 && systemError <= 0xffffffff
          ? systemError
          : null,
    );
  }

  String get diagnostic => [
    ?stage,
    code,
    if (win32Error != null) 'Win32 $win32Error',
  ].join(' · ');
}

class ScreenQrRegion {
  const ScreenQrRegion(this.width, this.height, this.bgra);

  final int width;
  final int height;
  final Uint8List bgra;

  factory ScreenQrRegion.fromMap(Map<String, dynamic> raw) {
    final width = raw['width'];
    final height = raw['height'];
    final pixels = raw['bgra'];
    if (width is! int ||
        height is! int ||
        pixels is! Uint8List ||
        width < 1 ||
        height < 1 ||
        width * height > 16000000 ||
        pixels.length != width * height * 4) {
      throw const FormatException('Invalid screen region');
    }
    // Engine platform replies are read-only views (unlike ordinary mock
    // method-channel replies). Own the working buffer before decoding and
    // clearing it, otherwise cleanup masks a successful scan with UnsupportedError.
    return ScreenQrRegion(width, height, Uint8List.fromList(pixels));
  }
}

/// Decodes in an isolate so even a large selected region cannot freeze the UI.
/// BGRA comes from a top-down Windows DIB, independent of Dart's host endianness.
String? decodeScreenQr(ScreenQrRegion region) {
  final pixels = Int32List(region.width * region.height);
  for (var i = 0; i < pixels.length; i++) {
    final offset = i * 4;
    pixels[i] =
        (region.bgra[offset + 2] << 16) |
        (region.bgra[offset + 1] << 8) |
        region.bgra[offset];
  }
  final source = RGBLuminanceSource(region.width, region.height, pixels);
  for (final luminance in [source, source.invert()]) {
    for (final bitmap in [
      BinaryBitmap(HybridBinarizer(luminance)),
      BinaryBitmap(GlobalHistogramBinarizer(luminance)),
    ]) {
      try {
        return QRCodeReader().decode(bitmap).text;
      } on ReaderException {
        // Try the other threshold/polarity for dark themes and scaled displays.
      }
    }
  }
  return null;
}
