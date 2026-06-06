// IOS-08 reduced-accuracy gate tests.
//
// Validates all three outcomes of LocationAccuracyGate.ensurePrecise():
//
//   Outcome A — BLOCKED:
//     getLocationAccuracy() → LocationAccuracyStatus.reduced
//     requestTemporaryFullAccuracy(purposeKey: kPreciseCommutePurposeKey)
//       → LocationAccuracyStatus.reduced
//     ➜ ensurePrecise() returns false (recording blocked)
//
//   Outcome B — PROCEED:
//     getLocationAccuracy() → LocationAccuracyStatus.reduced
//     requestTemporaryFullAccuracy(purposeKey: kPreciseCommutePurposeKey)
//       → LocationAccuracyStatus.precise
//     ➜ ensurePrecise() returns true
//
//   Outcome C — PROCEED (already precise):
//     getLocationAccuracy() → LocationAccuracyStatus.precise
//     requestTemporaryFullAccuracy NOT called
//     ➜ ensurePrecise() returns true
//
// Uses injected mock functions — no real device or CoreLocation needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/location_accuracy_gate.dart';

void main() {
  group(
    'IOS-08 reduced-accuracy gate — LocationAccuracyGate.ensurePrecise()',
    () {
      group('Outcome A: reduced → request → still reduced → BLOCKED', () {
        test('ensurePrecise() returns false', () async {
          var requestCalled = false;
          String? capturedPurposeKey;

          final gate = LocationAccuracyGate(
            getLocationAccuracy: () async => LocationAccuracyStatus.reduced,
            requestTemporaryFullAccuracy: ({required String purposeKey}) async {
              requestCalled = true;
              capturedPurposeKey = purposeKey;
              return LocationAccuracyStatus.reduced;
            },
          );

          final result = await gate.ensurePrecise();

          expect(result, isFalse, reason: 'reduced after request must block');
          expect(
            requestCalled,
            isTrue,
            reason: 'request must have been called',
          );
          expect(
            capturedPurposeKey,
            equals(kPreciseCommutePurposeKey),
            reason: 'purposeKey must match kPreciseCommutePurposeKey',
          );
        });
      });

      group('Outcome B: reduced → request → precise → PROCEED', () {
        test('ensurePrecise() returns true', () async {
          var requestCalled = false;
          String? capturedPurposeKey;

          final gate = LocationAccuracyGate(
            getLocationAccuracy: () async => LocationAccuracyStatus.reduced,
            requestTemporaryFullAccuracy: ({required String purposeKey}) async {
              requestCalled = true;
              capturedPurposeKey = purposeKey;
              return LocationAccuracyStatus.precise;
            },
          );

          final result = await gate.ensurePrecise();

          expect(result, isTrue, reason: 'precise after request must proceed');
          expect(
            requestCalled,
            isTrue,
            reason: 'request must have been called',
          );
          expect(
            capturedPurposeKey,
            equals(kPreciseCommutePurposeKey),
            reason: 'purposeKey must match kPreciseCommutePurposeKey',
          );
        });
      });

      group('Outcome C: already precise → PROCEED (no request call)', () {
        test(
          'ensurePrecise() returns true without calling requestTemporaryFullAccuracy',
          () async {
            var requestCalled = false;

            final gate = LocationAccuracyGate(
              getLocationAccuracy: () async => LocationAccuracyStatus.precise,
              requestTemporaryFullAccuracy:
                  ({required String purposeKey}) async {
                    requestCalled = true;
                    return LocationAccuracyStatus.precise;
                  },
            );

            final result = await gate.ensurePrecise();

            expect(result, isTrue, reason: 'already precise must proceed');
            expect(
              requestCalled,
              isFalse,
              reason:
                  'requestTemporaryFullAccuracy must NOT be called when '
                  'already precise',
            );
          },
        );
      });
    },
  );
}
