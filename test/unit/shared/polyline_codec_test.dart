// Unit tests for the hand-rolled Google Polyline codec.
//
// The reference string `_p~iF~ps|U_ulLnnqC_mqNvxq`@` comes directly from
// the Google Polyline Algorithm Format documentation:
// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
//
// If the encoder output diverges from this string, the encoder has a bug.
// Do not adjust the reference — fix the encoder.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/shared/utils/polyline_codec.dart';

void main() {
  group('encodePolyline', () {
    test('returns empty string for empty input', () {
      expect(encodePolyline(const []), isEmpty);
    });

    test('produces Google reference output for canonical coordinate set', () {
      // From https://developers.google.com/maps/documentation/utilities/polylinealgorithm
      const referenceString = r'_p~iF~ps|U_ulLnnqC_mqNvxq`@';

      final encoded = encodePolyline(const [
        (lat: 38.5, lng: -120.2),
        (lat: 40.7, lng: -120.95),
        (lat: 43.252, lng: -126.453),
      ]);

      expect(encoded, equals(referenceString));
    });
  });

  group('decodePolyline', () {
    test('returns empty list for empty input', () {
      expect(decodePolyline(''), isEmpty);
    });

    test('round-trips the canonical Google reference string', () {
      const referenceString = r'_p~iF~ps|U_ulLnnqC_mqNvxq`@';

      final decoded = decodePolyline(referenceString);

      expect(decoded.length, equals(3));
      expect(decoded[0].lat, closeTo(38.5, 1e-5));
      expect(decoded[0].lng, closeTo(-120.2, 1e-5));
      expect(decoded[1].lat, closeTo(40.7, 1e-5));
      expect(decoded[1].lng, closeTo(-120.95, 1e-5));
      expect(decoded[2].lat, closeTo(43.252, 1e-5));
      expect(decoded[2].lng, closeTo(-126.453, 1e-5));
    });

    test('round-trips a 1000-point randomized coordinate stream', () {
      final rng = Random(42);
      final points = List.generate(1000, (_) {
        return (
          lat: (rng.nextDouble() * 180) - 90,
          lng: (rng.nextDouble() * 360) - 180,
        );
      });

      final encoded = encodePolyline(points);
      final decoded = decodePolyline(encoded);

      expect(decoded.length, equals(points.length));
      for (var i = 0; i < points.length; i++) {
        expect(
          decoded[i].lat,
          closeTo(points[i].lat, 1e-5),
          reason: 'lat mismatch at index $i',
        );
        expect(
          decoded[i].lng,
          closeTo(points[i].lng, 1e-5),
          reason: 'lng mismatch at index $i',
        );
      }
    });
  });
}
