import 'package:flutter_test/flutter_test.dart';
import 'package:ava/src/core/protocol/qr_approval_client.dart';

void main() {
  group('QrChallenge.tryParse', () {
    test('parses s.team/q/<version>/<client_id>', () {
      final c = QrChallenge.tryParse('https://s.team/q/1/123456789');
      expect(c, isNotNull);
      expect(c!.version, 1);
      expect(c.clientId, 123456789);
    });

    test('parses steamcommunity host variant', () {
      final c = QrChallenge.tryParse(
        'https://steamcommunity.com/q/2/987654321?foo=bar',
      );
      expect(c!.version, 2);
      expect(c.clientId, 987654321);
    });

    test('parses www.steamcommunity.com variant', () {
      final c = QrChallenge.tryParse('https://www.steamcommunity.com/q/3/42');
      expect(c!.version, 3);
      expect(c.clientId, 42);
    });

    test('parses a client_id above 2^63-1 (random uint64 — half of them)', () {
      // Regression: int.tryParse rejects decimals beyond the signed-64 max,
      // which made ~half of all real login QR codes read as "not a Steam QR".
      final c = QrChallenge.tryParse(
        'https://s.team/q/1/18446744073709551615',
      ); // 2^64-1
      expect(c, isNotNull);
      expect(
        c!.clientId,
        BigInt.parse('18446744073709551615').toSigned(64).toInt(),
      );

      final mid = QrChallenge.tryParse(
        'https://s.team/q/1/9223372036854775808',
      ); // 2^63
      expect(mid, isNotNull);
    });

    test('rejects a client_id wider than 64 bits', () {
      expect(
        QrChallenge.tryParse('https://s.team/q/1/18446744073709551616'),
        isNull,
      ); // 2^64
      expect(QrChallenge.tryParse('https://s.team/q/1/-5'), isNull);
    });

    test('returns null for unrelated text', () {
      expect(QrChallenge.tryParse('not a url'), isNull);
      expect(QrChallenge.tryParse('https://example.com/foo/bar'), isNull);
    });

    test('rejects a valid path shape on a non-Steam host', () {
      expect(QrChallenge.tryParse('https://evil.example/q/1/123'), isNull);
    });

    test('rejects a non-HTTPS scheme on a Steam host', () {
      expect(QrChallenge.tryParse('http://s.team/q/1/123'), isNull);
    });

    test('accepts query metadata and the default HTTPS port', () {
      final challenge = QrChallenge.tryParse(
        'https://s.team:443/q/65535/123?source=steam&flow=login',
      );
      expect(challenge?.version, 65535);
      expect(challenge?.clientId, 123);
    });

    test(
      'rejects ambiguous authorities, fragments, and extra path segments',
      () {
        for (final url in [
          'https://user@s.team/q/1/123',
          'https://@s.team/q/1/123',
          'https://s.team:8443/q/1/123',
          'https://s.team/q/1/123#login',
          'https://s.team/q/1/123#',
          'https://s.team/extra/q/1/123',
          'https://s.team/q/1/123/extra',
          'https://s.team/q/1/123/',
          'https://s.team//q/1/123',
          'https://s.team/q/1/123/q/2/456',
          'https://s.team/extra/../q/1/123',
          'https://s.team/%71/1/123',
          'https://s.team/q/%31/123',
        ]) {
          expect(QrChallenge.tryParse(url), isNull, reason: url);
        }
      },
    );

    test(
      'requires decimal nonzero values within the signed challenge bounds',
      () {
        for (final url in [
          'https://s.team/q/0/123',
          'https://s.team/q/-1/123',
          'https://s.team/q/+1/123',
          'https://s.team/q/65536/123',
          'https://s.team/q/999999999999999999999/123',
          'https://s.team/q/1/0',
          'https://s.team/q/1/+123',
          'https://s.team/q/1/0x123',
        ]) {
          expect(QrChallenge.tryParse(url), isNull, reason: url);
        }
      },
    );

    test('rejects malformed/short paths on a trusted host', () {
      expect(QrChallenge.tryParse('https://s.team/q/1'), isNull);
      expect(QrChallenge.tryParse('https://s.team/q'), isNull);
      expect(QrChallenge.tryParse('https://s.team/'), isNull);
      expect(QrChallenge.tryParse('https://s.team/q/abc/123'), isNull);
    });
  });
}
