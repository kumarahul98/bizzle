// Wave 0 RED scaffold — reduced-accuracy gate contract (IOS-08 / D-05).
//
// @Skip annotation keeps this file from failing the suite until Wave 1
// implements the gate. Wave 1 will:
//   1. Remove (or replace) the @Skip annotation.
//   2. Create the injectable accuracy wrapper (thin abstraction over
//      Geolocator.getLocationAccuracy / requestTemporaryFullAccuracy).
//   3. Implement the gate in MainIsolateTrackingEngine.start() preflight.
//   4. Fill in the test body below with real assertions.
//
// CONTRACT (Wave 1 must satisfy all three outcomes):
//
//   Outcome A — BLOCKED:
//     getLocationAccuracy() → LocationAccuracyStatus.reduced
//     requestTemporaryFullAccuracy(purposeKey: kPreciseCommutePurposeKey) → reduced
//     ➜ start() returns a "blocked" result (or throws/returns a sentinel that the
//       UI maps to a banner: "Precise location required to record a commute")
//
//   Outcome B — PROCEED:
//     getLocationAccuracy() → LocationAccuracyStatus.reduced
//     requestTemporaryFullAccuracy(purposeKey: kPreciseCommutePurposeKey) → precise
//     ➜ start() proceeds; the GPS stream is created with AppleSettings
//
//   Outcome C — PROCEED (already precise):
//     getLocationAccuracy() → LocationAccuracyStatus.precise
//     requestTemporaryFullAccuracy is NOT called
//     ➜ start() proceeds immediately; the GPS stream is created with AppleSettings
//
// IMPLEMENTATION NOTE for Wave 1:
//   The gate lives in MainIsolateTrackingEngine.start() (iOS-only path).
//   Use a thin injectable wrapper — e.g. an `AccuracyService` interface:
//     abstract interface class AccuracyService {
//       Future<LocationAccuracyStatus> getAccuracy();
//       Future<LocationAccuracyStatus> requestPrecise({required String purposeKey});
//     }
//   Inject a mock in tests; inject the real Geolocator-backed impl in production.
//   purposeKey literal: use kPreciseCommutePurposeKey from constants.dart.
//
// See:
//   - IOS-08 in .planning/REQUIREMENTS.md
//   - D-05 in .planning/phases/14-background-gps-platform-branch/14-CONTEXT.md
//   - RESEARCH §4 in .planning/phases/14-background-gps-platform-branch/14-RESEARCH.md
//   - 14-VALIDATION.md Wave 0 Requirements

@Skip('Wave 1 implements: IOS-08 reduced-accuracy gate in MainIsolateTrackingEngine')
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IOS-08 reduced-accuracy gate — MainIsolateTrackingEngine.start()', () {
    // Wave 1: inject a mock AccuracyService; the real impl wraps Geolocator.

    group('Outcome A: reduced → request → still reduced → BLOCKED', () {
      // setUp: mock.getAccuracy() returns reduced; mock.requestPrecise() returns reduced
      // Wave 1 fills this test body.
      test('start() returns a blocked/error result (TODO Wave 1)', () {
        // TODO(Wave 1): assert start() returns blocked sentinel / throws
        // LocationAccuracyBlockedException or equivalent.
        // The UI maps this to a banner: "Precise location required".
      });
    });

    group('Outcome B: reduced → request → precise → PROCEED', () {
      // setUp: mock.getAccuracy() returns reduced; mock.requestPrecise() returns precise
      test('start() proceeds and opens the GPS stream (TODO Wave 1)', () {
        // TODO(Wave 1): assert start() proceeds; verify getPositionStream is
        // called with AppleSettings.
      });
    });

    group('Outcome C: already precise → PROCEED (no request call)', () {
      // setUp: mock.getAccuracy() returns precise
      test(
        'start() proceeds without calling requestPrecise (TODO Wave 1)',
        () {
          // TODO(Wave 1): assert start() proceeds; verify requestPrecise is
          // NOT called (mock verifyNever).
        },
      );
    });
  });
}
