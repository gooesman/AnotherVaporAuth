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
    return ScreenQrRegion(width, height, pixels);
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
