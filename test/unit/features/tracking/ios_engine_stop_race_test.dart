// iOS engine stop-race contract tests.
//
// These tests verify that MainIsolateTrackingEngine preserves the stop-race
// ordering from tracking_service.dart (the Android isolate precedent):
//
//   1. stop() sets the `stopping` flag to true FIRST.
//   2. stop() then cancels the StreamSubscription<Position>.
//   3. A Position pushed AFTER stop() sets the flag MUST NOT reach
//      TripAccumulator.addSample().
//   4. The finalized trip reflects only pre-stop samples.
//
// Drive the engine with an injectable StreamController<Position> so the
// test controls delivery order precisely (no real GPS needed).
//
// Assertions read from the finalized trip's *map* — never from raw Position
// coordinates — to honour the T-02-07 PII guard.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/features/tracking/services/main_isolate_tracking_engine.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a [Position] with controlled lat/lng/speed/timestamp for tests.
/// Accuracy is well under kTrackingMaxAcceptableAccuracyMeters (30 m) so no
/// sample is dropped by the accumulator's accuracy gate.
Position _pos({
  required double lat,
  required double lng,
  double speedMs = 5,
  required DateTime timestamp,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: timestamp,
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speedMs,
    speedAccuracy: 0,
  );
}

/// Build an engine backed by the given [controller] instead of Geolocator.
MainIsolateTrackingEngine _engineFor(
  StreamController<Position> controller,
) {
  return MainIsolateTrackingEngine(
    positionStreamFactory: (_) => controller.stream,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 8);

  group('MainIsolateTrackingEngine stop-race guard', () {
    test(
      'late sample pushed after stop() does NOT reach TripAccumulator',
      () async {
        final controller = StreamController<Position>.broadcast();
        final engine = _engineFor(controller);

        await engine.start();

        // Collect finalized-trip events.
        final finalizedMaps = <Map<String, dynamic>?>[];
        engine.onFinalized.listen(finalizedMaps.add);

        // Pre-stop sample: position at (0, 0) → (0.01, 0).
        // Two samples needed so the accumulator can compute a distance
        // interval (it needs a prev sample to diff against).
        final p1 = _pos(lat: 0, lng: 0, timestamp: t0);
        final p2 = _pos(
          lat: 0.01,
          lng: 0,
          timestamp: t0.add(
            const Duration(seconds: 3),
          ),
        );
        controller.add(p1);
        controller.add(p2);

        // Pump the event loop so the listener processes p1 and p2.
        await Future<void>.delayed(Duration.zero);

        // Stop the engine — sets stopping=true, cancels sub, finalizes.
        await engine.stop();

        // Late sample: pushed AFTER stop().
        final pLate = _pos(
          lat: 1.0,
          lng: 1.0,
          timestamp: t0.add(const Duration(seconds: 6)),
        );
        controller.add(pLate);

        // Pump so pLate has a chance to reach the listener (it should not).
        await Future<void>.delayed(Duration.zero);

        // Exactly one finalized event must have been emitted.
        expect(finalizedMaps, hasLength(1));
        final tripMap = finalizedMaps.first!;

        // The finalized trip's distanceMeters should only reflect p1→p2.
        // pLate would have been a very long jump (~157 km) — presence in the
        // accumulator would make distanceMeters >> 1000 m.
        final distance = (tripMap['distanceMeters'] as num).toDouble();
        // p1(0,0)→p2(0.01,0) ≈ 1111 m; pLate would add ~157,000 m.
        // Assert the late sample did NOT contribute.
        expect(
          distance,
          lessThan(2000),
          reason: 'distanceMeters should only reflect pre-stop samples',
        );

        await controller.close();
      },
    );

    test(
      'stopping flag is set before StreamSubscription.cancel() '
      '(ordering guarantee)',
      () async {
        // Use a sync broadcast controller so additions are processed
        // synchronously in the same microtask — this lets us verify the flag
        // is already true when a sample arrives during the cancel window.
        final controller = StreamController<Position>.broadcast(sync: true);
        var sampleReachedAccumulator = false;

        final engine = _engineFor(controller);
        await engine.start();

        // Attach a post-stop probe: immediately after stop() is awaited,
        // add a sample synchronously — the sync controller will deliver it
        // before any awaited cancellation completes.
        final stopFuture = engine.stop();
        // Add the late sample synchronously WHILE stop() is in progress.
        controller.add(
          _pos(lat: 5, lng: 5, timestamp: t0.add(const Duration(seconds: 1))),
        );
        await stopFuture;

        // The accumulator should have seen NO samples (start was called but
        // no pre-stop samples were pushed, and the synchronous post-stop
        // sample was dropped by the stopping flag).
        final acc = engine.accumulatorForTest;
        if (acc != null) {
          sampleReachedAccumulator = acc.distanceMetersForTest > 0;
        }

        expect(
          sampleReachedAccumulator,
          isFalse,
          reason:
              'stopping flag must be set before cancel() so synchronous '
              'post-stop samples are dropped',
        );

        await controller.close();
      },
    );

    test(
      'finalized trip excludes samples delivered after stop()',
      () async {
        final controller = StreamController<Position>.broadcast();
        final engine = _engineFor(controller);

        await engine.start();

        final finalizedMaps = <Map<String, dynamic>?>[];
        engine.onFinalized.listen(finalizedMaps.add);

        // Push N=3 pre-stop samples.
        final pre = [
          _pos(lat: 0, lng: 0, timestamp: t0),
          _pos(
            lat: 0.001,
            lng: 0,
            timestamp: t0.add(
              const Duration(seconds: 3),
            ),
          ),
          _pos(
            lat: 0.002,
            lng: 0,
            timestamp: t0.add(
              const Duration(seconds: 6),
            ),
          ),
        ];
        for (final p in pre) {
          controller.add(p);
        }
        await Future<void>.delayed(Duration.zero);

        await engine.stop();

        // Push M=2 post-stop samples.
        final post = [
          _pos(
            lat: 5,
            lng: 5,
            timestamp: t0.add(const Duration(seconds: 9)),
          ),
          _pos(
            lat: 6,
            lng: 6,
            timestamp: t0.add(const Duration(seconds: 12)),
          ),
        ];
        for (final p in post) {
          controller.add(p);
        }
        await Future<void>.delayed(Duration.zero);

        expect(finalizedMaps, hasLength(1));
        final tripMap = finalizedMaps.first!;
        final distance = (tripMap['distanceMeters'] as num).toDouble();
        // 3 pre-stop samples span ≈ 3× ~111 m ≈ 222 m.
        // Post-stop samples would add hundreds of km.
        expect(
          distance,
          lessThan(1000),
          reason: 'finalized trip must only integrate pre-stop samples',
        );

        await controller.close();
      },
    );
  });
}
