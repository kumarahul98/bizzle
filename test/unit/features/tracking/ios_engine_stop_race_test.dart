// Wave 0 RED scaffold — iOS engine stop-race contract.
//
// @Skip annotation keeps this file from failing the suite until Wave 1
// implements MainIsolateTrackingEngine. Wave 1 will:
//   1. Remove (or replace) the @Skip annotation.
//   2. Implement MainIsolateTrackingEngine in
//      lib/features/tracking/services/main_isolate_tracking_engine.dart.
//   3. Fill in the test body below with real assertions using a controllable
//      StreamController<Position> injected into the engine.
//
// CONTRACT (Wave 1 must satisfy):
//
//   Stop-race ordering (mirrors the Android isolate's stop-race guard in
//   tracking_service.dart):
//
//     1. engine.stop() sets the internal `stopping` flag to true FIRST.
//     2. engine.stop() then cancels the StreamSubscription<Position>.
//     3. A Position sample pushed onto the controllable StreamController
//        AFTER stop() has set the flag MUST NOT reach TripAccumulator.addSample().
//     4. The trip finalized after stop() reflects only samples delivered
//        BEFORE the stopping flag was set.
//
// IMPLEMENTATION NOTE for Wave 1:
//   Drive the engine with an injectable position stream:
//     - Construct MainIsolateTrackingEngine with a StreamController<Position>
//       (or equivalent injectable stream factory) instead of calling
//       Geolocator.getPositionStream() directly.
//     - In the test:
//         final controller = StreamController<Position>();
//         final engine = MainIsolateTrackingEngine(positionStream: controller.stream);
//         engine.start();
//         controller.add(validSample);   // accepted
//         engine.stop();                  // sets stopping = true, cancels sub
//         controller.add(lateSample);    // MUST be dropped
//         // assert TripAccumulator only saw validSample
//
//   The TripAccumulator used by the engine should be inspectable (injected or
//   exposed via a test-only getter) so assertions can check its state.
//
// See:
//   - RESEARCH §3 (MainIsolateTrackingEngine seam) in
//     .planning/phases/14-background-gps-platform-branch/14-RESEARCH.md
//   - 02-RESEARCH.md §8 (stop-race guard) — the Android precedent
//   - 14-VALIDATION.md Wave 0 Requirements

@Skip('Wave 1 implements: MainIsolateTrackingEngine iOS stop-race guard')
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MainIsolateTrackingEngine stop-race guard', () {
    // Wave 1: build the engine with an injectable StreamController<Position>.

    test(
      'late sample pushed after stop() does NOT reach TripAccumulator '
      '(TODO Wave 1)',
      () {
        // TODO(Wave 1):
        //   final controller = StreamController<Position>.broadcast();
        //   final engine = MainIsolateTrackingEngine(
        //     positionStream: controller.stream,
        //   );
        //   await engine.start();
        //   controller.add(earlyPosition);  // must be accepted
        //   await engine.stop();            // sets stopping flag, cancels sub
        //   controller.add(latePosition);   // must be dropped
        //   final trip = /* finalizedTrip from engine.onFinalized */;
        //   // Only earlyPosition's data appears in the finalized trip.
        //   expect(trip.distanceMeters, closeTo(expectedFromEarlyOnly, 1e-6));
      },
    );

    test(
      'stopping flag is set before StreamSubscription.cancel() '
      '(ordering guarantee — TODO Wave 1)',
      () {
        // TODO(Wave 1): use a spy/mock subscription or a synchronous
        // StreamController to verify that by the time cancel() is called,
        // the stopping flag is already true so any in-flight callback
        // short-circuits.
      },
    );

    test(
      'finalized trip excludes samples delivered after stop() '
      '(TODO Wave 1)',
      () {
        // TODO(Wave 1): send N samples pre-stop and M samples post-stop;
        // assert the finalized trip only integrates the N pre-stop samples.
      },
    );
  });
}
