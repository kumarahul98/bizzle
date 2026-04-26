// Wave 0 stub tests for shared formatting utilities (HIST-01, HIST-03).
//
// These stubs compile and pass immediately (via markTestSkipped) so the test
// runner stays green before the production code exists. Wave 1 implements
// `formatDuration`, `formatDistance`, and `decodedToLatLng` in
// lib/shared/utils/formatters.dart, then Wave 2 fills these stubs with real
// assertions and the production import.
//
// Do NOT import the production module from this stub — it does not exist
// yet and importing it would fail compilation. The latlong2 import for the
// decodedToLatLng tests is also deferred to Wave 1, when latlong2 is added
// as a dependency.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDuration', () {
    test('formatDuration(0) returns "0 min"', () {
      markTestSkipped('Wave 1: implement formatDuration first');
    });

    test('formatDuration(2700) returns "45 min" (under 60 min)', () {
      markTestSkipped('Wave 1: implement formatDuration first');
    });

    test('formatDuration(3600) returns "1h 00min" (exactly 60 min)', () {
      markTestSkipped('Wave 1: implement formatDuration first');
    });

    test('formatDuration(4320) returns "1h 12min" (over 60 min)', () {
      markTestSkipped('Wave 1: implement formatDuration first');
    });
  });

  group('formatDistance', () {
    test('formatDistance(0) returns "0.0 km"', () {
      markTestSkipped('Wave 1: implement formatDistance first');
    });

    test('formatDistance(12400) returns "12.4 km"', () {
      markTestSkipped('Wave 1: implement formatDistance first');
    });
  });

  group('decodedToLatLng', () {
    test("decodedToLatLng('') returns empty list", () {
      markTestSkipped('Wave 1: implement decodedToLatLng first');
    });

    test('decodedToLatLng with valid polyline returns correct LatLng list', () {
      markTestSkipped('Wave 1: implement decodedToLatLng first');
    });
  });
}
