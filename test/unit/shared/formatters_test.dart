// Unit tests for shared formatting utilities (HIST-01, HIST-03).
//
// These tests assert the behaviour of `formatDuration`, `formatDistance`,
// and `decodedToLatLng`. The decodedToLatLng reference polyline string is
// the canonical Google Polyline Algorithm Format example, lifted from
// test/unit/shared/polyline_codec_test.dart so any divergence between the
// codec and the LatLng adapter shows up here.

import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/shared/utils/formatters.dart';

void main() {
  group('formatDuration', () {
    test('formatDuration(0) returns "0 min"', () {
      expect(formatDuration(0), equals('0 min'));
    });

    test('formatDuration(2700) returns "45 min" (under 60 min)', () {
      expect(formatDuration(2700), equals('45 min'));
    });

    test('formatDuration(3600) returns "1h 00min" (exactly 60 min)', () {
      expect(formatDuration(3600), equals('1h 00min'));
    });

    test('formatDuration(4320) returns "1h 12min" (over 60 min)', () {
      expect(formatDuration(4320), equals('1h 12min'));
    });
  });

  group('formatDistance', () {
    test('formatDistance(0) returns "0.0 km"', () {
      expect(formatDistance(0), equals('0.0 km'));
    });

    test('formatDistance(12400) returns "12.4 km"', () {
      expect(formatDistance(12400), equals('12.4 km'));
    });
  });

  group('decodedToLatLng', () {
    test("decodedToLatLng('') returns empty list", () {
      expect(decodedToLatLng(''), isEmpty);
    });

    test('decodedToLatLng with valid polyline returns correct LatLng list', () {
      // Canonical Google polyline reference — same string used in
      // polyline_codec_test.dart. Decodes to three known coordinates.
      const referenceString = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

      final result = decodedToLatLng(referenceString);

      expect(result.length, equals(3));
      expect(result[0].latitude, closeTo(38.5, 1e-5));
      expect(result[0].longitude, closeTo(-120.2, 1e-5));
      expect(result[1].latitude, closeTo(40.7, 1e-5));
      expect(result[1].longitude, closeTo(-120.95, 1e-5));
      expect(result[2].latitude, closeTo(43.252, 1e-5));
      expect(result[2].longitude, closeTo(-126.453, 1e-5));
    });
  });
}
