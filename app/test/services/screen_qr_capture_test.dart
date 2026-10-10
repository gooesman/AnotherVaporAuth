import 'package:ava/src/services/screen_qr_capture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zxing2/qrcode.dart';

ScreenQrRegion _qr(
  String text, {
  int scale = 6,
  bool inverted = false,
  bool rotated = false,
}) {
  final matrix = Encoder.encode(text, ErrorCorrectionLevel.m).matrix!;
  const border = 4;
  final size = (matrix.width + border * 2) * scale;
  final bgra = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final mx = x ~/ scale - border;
      final my = y ~/ scale - border;
      final dark =
          mx >= 0 &&
          my >= 0 &&
          mx < matrix.width &&
          my < matrix.height &&
          matrix.get(mx, my) == 1;
      final shade = (dark != inverted) ? 20 : 245;
      final at = rotated ? ((size - x - 1) * size + y) * 4 : (y * size + x) * 4;
      bgra[at] = shade;
      bgra[at + 1] = shade;
      bgra[at + 2] = shade;
      bgra[at + 3] = 255;
    }
  }
  return ScreenQrRegion(size, size, bgra);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ava/screen_capture_test');
  const service = ScreenQrCapture(channel);
  const code = 'https://s.team/q/1/18446744073709551615';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('decodes actual QR pixels at several display scales and rotations', () {
    for (final scale in [2, 5, 9]) {
      expect(decodeScreenQr(_qr(code, scale: scale)), code);
      expect(decodeScreenQr(_qr(code, scale: scale, rotated: true)), code);
    }
  });

  test('decodes light QR modules on a dark background', () {
    expect(decodeScreenQr(_qr(code, inverted: true)), code);
  });

  test('blank pixels are not treated as a QR', () {
    final pixels = Uint8List(128 * 128 * 4)..fillRange(0, 128 * 128 * 4, 255);
    expect(decodeScreenQr(ScreenQrRegion(128, 128, pixels)), isNull);
  });

  test('validates dimensions and payload length before decoding', () {
    for (final raw in <Map<String, dynamic>>[
      {'width': -1, 'height': 8, 'bgra': Uint8List(0)},
      {'width': 4001, 'height': 4000, 'bgra': Uint8List(0)},
      {'width': 10, 'height': 10, 'bgra': Uint8List(399)},
      {'width': '10', 'height': 10, 'bgra': Uint8List(400)},
    ]) {
      expect(() => ScreenQrRegion.fromMap(raw), throwsFormatException);
    }
  });

  test(
    'native cancellation returns no QR and passes localized UI options',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'captureRegion');
        expect(call.arguments, {
          'instruction': 'Test instruction',
          'accent': 0xff3366ff,
        });
        return null;
      });
      expect(
        await service.capture(
          instruction: 'Test instruction',
          accent: 0xff3366ff,
        ),
        isNull,
      );
    },
  );

  test('captured pixels are decoded through the background isolate', () async {
    final region = _qr(code);
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'width': region.width,
        'height': region.height,
        'bgra': region.bgra,
      },
    );
    expect(
      await service.capture(instruction: 'Select', accent: 0xff3366ff),
      code,
    );
  });

  test('empty capture produces a retryable QR error', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'width': 64, 'height': 64, 'bgra': Uint8List(64 * 64 * 4)},
    );
    await expectLater(
      service.capture(instruction: 'Select', accent: 0xff3366ff),
      throwsA(isA<ScreenQrNotFound>()),
    );
  });

  test(
    'native failure propagates without treating it as a successful scan',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'capture_failed'),
      );
      await expectLater(
        service.capture(instruction: 'Select', accent: 0xff3366ff),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
