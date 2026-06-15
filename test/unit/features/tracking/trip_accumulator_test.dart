// Unit tests for [TripAccumulator], [TripSnapshot], and [FinalizedTrip].
//
// These tests exercise every D-02..D-06 decision from 02-CONTEXT.md plus
// the Pitfall 2 regression tripwire (5 km/h → 40 km/h interval must
// classify as stuck when the prev-sample is at 5 km/h). If the
// implementation ever compared raw `Position.speed` (m/s) against the
// km/h threshold constant, this test would fail loudly.

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/trip_accumulator.dart';
import 'package:traevy/features/tracking/state/finalized_trip.dart';

/// Build a real `geolocator` [Position] for tests. Using the real class
/// (not a mock) catches API drift between plan 02-02 and plan 02-03.
Position _pos({
  required double lat,
  required double lng,
  required double speedMs,
  required DateTime timestamp,
  double accuracy = 5,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: timestamp,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speedMs,
    speedAccuracy: 0,
  );
}

void main() {
  final start = DateTime.utc(2026, 1, 1, 8);

  group('TripAccumulator.finalize()', () {
    test('with zero samples returns empty trip', () {
      final acc = TripAccumulator(startedAt: start);
      final trip = acc.finalize(start.add(const Duration(seconds: 10)));

      expect(trip.distanceMeters, 0);
      expect(trip.timeMovingSeconds, 0);
      expect(trip.timeStuckSeconds, 0);
      expect(trip.encodedPolyline, isEmpty);
      expect(trip.id, isNotEmpty);
      expect(trip.startTime.isUtc, isTrue);
      expect(trip.endTime.isUtc, isTrue);
    });

    test('with one sample has zero distance but one polyline point', () {
      final acc = TripAccumulator(startedAt: start)
        ..addSample(
          _pos(
            lat: 37.7749,
            lng: -122.4194,
            speedMs: 5,
            timestamp: start,
          ),
        );
      final trip = acc.finalize(start.add(const Duration(seconds: 10)));

      expect(trip.distanceMeters, 0);
      expect(trip.timeMovingSeconds, 0);
      expect(trip.timeStuckSeconds, 0);
      expect(trip.encodedPolyline, isNotEmpty);
    });
  });

  group('TripAccumulator.addSample() — time attribution (D-03)', () {
    test('prev.speed ABOVE threshold → interval is moving', () {
      final acc = TripAccumulator(startedAt: start)
        ..addSample(
          _pos(
            lat: 37.7749,
            lng: -122.4194,
            speedMs: 20, // 72 km/h — moving
            timestamp: start,
          ),
        )
        ..addSample(
          _pos(
            lat: 37.7800,
            lng: -122.4194,
            speedMs: 20,
            timestamp: start.add(const Duration(seconds: 5)),
          ),
        );

      expect(acc.timeMovingSecondsForTest, 5);
      expect(acc.timeStuckSecondsForTest, 0);
    });

    test('prev.speed BELOW threshold → interval is stuck', () {
      final acc = TripAccumulator(startedAt: start)
        ..addSample(
          _pos(
            lat: 37.7749,
            lng: -122.4194,
            speedMs: 1, // 3.6 km/h — stuck
            timestamp: start,
          ),
        )
        ..addSample(
          _pos(
            lat: 37.77495,
            lng: -122.4194,
            speedMs: 1,
            timestamp: start.add(const Duration(seconds: 5)),
          ),
        );

      expect(acc.timeMovingSecondsForTest, 0);
      expect(acc.timeStuckSecondsForTest, 5);
    });

    test(
      'prev.speed EXACTLY at threshold → moving (>= boundary, D-03)',
      () {
        final acc = TripAccumulator(startedAt: start)
          ..addSample(
            _pos(
              lat: 37.7749,
              lng: -122.4194,
              speedMs: kStuckSpeedThresholdMs,
              timestamp: start,
            ),
          )
          ..addSample(
            _pos(
              lat: 37.7800,
              lng: -122.4194,
              speedMs: kStuckSpeedThresholdMs,
              timestamp: start.add(const Duration(seconds: 5)),
            ),
          );

        expect(acc.timeMovingSecondsForTest, 5);
        expect(acc.timeStuckSecondsForTest, 0);
      },
    );

    test(
      'PITFALL 2 TRIPWIRE: 5 km/h -> 40 km/h interval classifies as stuck '
      '(prev.speed 1.389 m/s < kStuckSpeedThresholdMs 2.777...)',
      () {
        // 5 km/h = 1.38889 m/s, 40 km/h = 11.11111 m/s.
        // If the implementation accidentally compared raw m/s against
        // kStuckSpeedThresholdKmh = 10, 1.38889 < 10 (coincidentally
        // still stuck) BUT we would expect the SAME value compared
        // against 10 would also wrongly classify values like 3 m/s
        // (10.8 km/h, should be MOVING) as stuck. This 5→40 case locks
        // the classification site to use the m/s threshold, not the
        // km/h one.
        final acc = TripAccumulator(startedAt: start)
          ..addSample(
            _pos(
              lat: 37.7749,
              lng: -122.4194,
              speedMs: 1.38889, // 5 km/h — stuck
              timestamp: start,
            ),
          )
          ..addSample(
            _pos(
              lat: 37.7800,
              lng: -122.4194,
              speedMs: 11.11111, // 40 km/h
              timestamp: start.add(const Duration(seconds: 10)),
            ),
          );

        // prev (5 km/h) classifies the 10s interval → stuck
        expect(acc.timeStuckSecondsForTest, 10);
        expect(acc.timeMovingSecondsForTest, 0);

        // Inverse tripwire: a sample at 3 m/s (~10.8 km/h) prev.speed
        // MUST classify as moving (it is above the m/s threshold of
        // ~2.777). A buggy comparison against the km/h threshold would
        // make it stuck.
        final acc2 = TripAccumulator(startedAt: start)
          ..addSample(
            _pos(
              lat: 37.7749,
              lng: -122.4194,
              speedMs: 3, // ~10.8 km/h — moving
              timestamp: start,
            ),
          )
          ..addSample(
            _pos(
              lat: 37.7800,
              lng: -122.4194,
              speedMs: 3,
              timestamp: start.add(const Duration(seconds: 5)),
            ),
          );
        expect(acc2.timeMovingSecondsForTest, 5);
        expect(acc2.timeStuckSecondsForTest, 0);
      },
    );
  });

  group('TripAccumulator.snapshot() — speed freshness (gap 08-02)', () {
    // SPEED tile must drop to 0 when the device stops emitting fresh GPS
    // samples. See `.planning/debug/active-speed-tile-stale.md`.

    test('returns last accepted speed when within freshness window', () {
      final acc = TripAccumulator(startedAt: start);
      final t0 = start.add(const Duration(seconds: 5));
      acc.addSample(_pos(lat: 0, lng: 0, speedMs: 12, timestamp: t0));

      // Half the freshness window has passed — sample is still fresh.
      final now = t0.add(kTrackingSpeedFreshnessWindow ~/ 2);
      final snap = acc.snapshot(now);

      expect(snap.currentSpeedMs, 12);
    });

    test('decays to 0 when last sample is older than the freshness window', () {
      final acc = TripAccumulator(startedAt: start);
      final t0 = start.add(const Duration(seconds: 5));
      acc.addSample(_pos(lat: 0, lng: 0, speedMs: 12, timestamp: t0));

      // Window + 1s has passed without any new sample.
      final now = t0
          .add(kTrackingSpeedFreshnessWindow)
          .add(const Duration(seconds: 1));
      final snap = acc.snapshot(now);

      expect(snap.currentSpeedMs, 0);
    });

    test('reflects fresh zero-speed sample immediately', () {
      final acc = TripAccumulator(startedAt: start);
      final t0 = start.add(const Duration(seconds: 5));
      acc.addSample(_pos(lat: 0, lng: 0, speedMs: 12, timestamp: t0));

      // 4 seconds later (within window) a 0-speed sample arrives.
      final t1 = t0.add(const Duration(seconds: 4));
      acc.addSample(_pos(lat: 0, lng: 0, speedMs: 0, timestamp: t1));
      final snap = acc.snapshot(t1);

      expect(snap.currentSpeedMs, 0);
    });

    test('reports 0 when no sample has been accepted yet', () {
      final acc = TripAccumulator(startedAt: start);
      final snap = acc.snapshot(start.add(const Duration(seconds: 1)));

      expect(snap.currentSpeedMs, 0);
    });
  });

  group('TripAccumulator.addSample() — gates', () {
    test('drops sample with accuracy > threshold', () {
      final acc = TripAccumulator(startedAt: start)
        ..addSample(
          _pos(
            lat: 37.7749,
            lng: -122.4194,
            speedMs: 20,
            timestamp: start,
          ),
        )
        ..addSample(
          _pos(
            lat: 37.7800,
            lng: -122.4194,
            speedMs: 20,
            timestamp: start.add(const Duration(seconds: 5)),
            accuracy: kTrackingMaxAcceptableAccuracyMeters + 0.1,
          ),
        );

      expect(acc.distanceMetersForTest, 0);
      expect(acc.timeMovingSecondsForTest, 0);
      expect(acc.timeStuckSecondsForTest, 0);
    });

    test(
      'gap > kTrackingMaxAttributableGapSeconds: distance yes, time no',
      () {
        final acc = TripAccumulator(startedAt: start)
          ..addSample(
            _pos(
              lat: 37.7749,
              lng: -122.4194,
              speedMs: 20,
              timestamp: start,
            ),
          )
          ..addSample(
            _pos(
              lat: 37.7800,
              lng: -122.4194,
              speedMs: 20,
              timestamp: start.add(
                const Duration(
                  seconds: kTrackingMaxAttributableGapSeconds + 5,
                ),
              ),
            ),
          );

        expect(acc.distanceMetersForTest, greaterThan(0));
        expect(acc.timeMovingSecondsForTest, 0);
        expect(acc.timeStuckSecondsForTest, 0);
      },
    );

    test(
      'deltaSec <= 0 (clock skew/duplicate): polyline yes, distance no, '
      'time no',
      () {
        final acc = TripAccumulator(startedAt: start)
          ..addSample(
            _pos(
              lat: 37.7749,
              lng: -122.4194,
              speedMs: 20,
              timestamp: start,
            ),
          )
          ..addSample(
            _pos(
              lat: 37.7800,
              lng: -122.4194,
              speedMs: 20,
              timestamp: start, // same timestamp → deltaSec = 0
            ),
          );

        expect(acc.distanceMetersForTest, 0);
        expect(acc.timeMovingSecondsForTest, 0);
        expect(acc.timeStuckSecondsForTest, 0);

        // But the polyline should contain both points.
        final trip = acc.finalize(start.add(const Duration(seconds: 1)));
        expect(trip.encodedPolyline, isNotEmpty);
      },
    );
  });

  group('TripAccumulator.finalize()', () {
    test('ignores addSample calls after finalize', () {
      final acc = TripAccumulator(startedAt: start)
        ..addSample(
          _pos(
            lat: 37.7749,
            lng: -122.4194,
            speedMs: 20,
            timestamp: start,
          ),
        )
        ..finalize(start.add(const Duration(seconds: 10)))
        ..addSample(
          _pos(
            lat: 37.7800,
            lng: -122.4194,
            speedMs: 20,
            timestamp: start.add(const Duration(seconds: 5)),
          ),
        );

      expect(acc.distanceMetersForTest, 0);
      expect(acc.timeMovingSecondsForTest, 0);
      expect(acc.timeStuckSecondsForTest, 0);
    });

    test('distance matches Geolocator.distanceBetween for two points', () {
      final acc = TripAccumulator(startedAt: start)
        ..addSample(
          _pos(
            lat: 37.7749,
            lng: -122.4194,
            speedMs: 20,
            timestamp: start,
          ),
        )
        ..addSample(
          _pos(
            lat: 37.7800,
            lng: -122.4100,
            speedMs: 20,
            timestamp: start.add(const Duration(seconds: 5)),
          ),
        );

      final expectedMeters = Geolocator.distanceBetween(
        37.7749,
        -122.4194,
        37.7800,
        -122.4100,
      );

      expect(
        acc.distanceMetersForTest,
        closeTo(expectedMeters, 1e-6),
      );
    });
  });

  group('TripAccumulator.pause()/resume() — paused attribution (D-05)', () {
    test('paused addSample adds no distance/moving/stuck (polyline only)', () {
      final acc = TripAccumulator(startedAt: start)
        ..addSample(
          _pos(lat: 37.7749, lng: -122.4194, speedMs: 20, timestamp: start),
        )
        ..addSample(
          _pos(
            lat: 37.7800,
            lng: -122.4194,
            speedMs: 20,
            timestamp: start.add(const Duration(seconds: 5)),
          ),
        );

      // Capture pre-pause attribution.
      final distanceBefore = acc.distanceMetersForTest;
      final movingBefore = acc.timeMovingSecondsForTest;
      final stuckBefore = acc.timeStuckSecondsForTest;
      expect(movingBefore, 5);

      // Pause, then feed two more samples spanning real distance/time.
      acc
        ..pause(start.add(const Duration(seconds: 5)))
        ..addSample(
          _pos(
            lat: 37.7900,
            lng: -122.4000,
            speedMs: 20,
            timestamp: start.add(const Duration(seconds: 10)),
          ),
        )
        ..addSample(
          _pos(
            lat: 37.8000,
            lng: -122.3900,
            speedMs: 20,
            timestamp: start.add(const Duration(seconds: 15)),
          ),
        );

      // No attribution moved while paused.
      expect(acc.distanceMetersForTest, distanceBefore);
      expect(acc.timeMovingSecondsForTest, movingBefore);
      expect(acc.timeStuckSecondsForTest, stuckBefore);
      expect(acc.isPausedForTest, isTrue);

      // But the polyline still grew (bridge line).
      final trip = acc.finalize(start.add(const Duration(seconds: 20)));
      expect(trip.encodedPolyline, isNotEmpty);
    });

    test('elapsed freezes while paused (D-06)', () {
      final acc = TripAccumulator(startedAt: start);
      final beforePause = acc.snapshot(start.add(const Duration(seconds: 10)));
      expect(beforePause.elapsedSeconds, 10);

      acc.pause(start.add(const Duration(seconds: 10)));

      // Advance wall clock 30s while paused — elapsed must stay frozen at 10.
      final whilePaused = acc.snapshot(start.add(const Duration(seconds: 40)));
      expect(whilePaused.elapsedSeconds, 10);
      expect(whilePaused.isPaused, isTrue);
      expect(whilePaused.breakCount, 1);
      // pausedSeconds includes the open span (40 - 10 = 30).
      expect(whilePaused.pausedSeconds, 30);
    });

    test('resume reopens attribution (D-05)', () {
      final acc = TripAccumulator(startedAt: start)
        ..addSample(
          _pos(lat: 37.7749, lng: -122.4194, speedMs: 20, timestamp: start),
        )
        ..pause(start.add(const Duration(seconds: 5)))
        ..addSample(
          _pos(
            lat: 37.7800,
            lng: -122.4194,
            speedMs: 20,
            timestamp: start.add(const Duration(seconds: 10)),
          ),
        )
        ..resume(start.add(const Duration(seconds: 15)));

      expect(acc.isPausedForTest, isFalse);
      expect(acc.accumulatedPausedSecondsForTest, 10);
      final movingAfterResume = acc.timeMovingSecondsForTest;

      // Feed two post-resume moving samples — attribution must resume.
      acc
        ..addSample(
          _pos(
            lat: 37.7850,
            lng: -122.4194,
            speedMs: 20,
            timestamp: start.add(const Duration(seconds: 20)),
          ),
        )
        ..addSample(
          _pos(
            lat: 37.7900,
            lng: -122.4194,
            speedMs: 20,
            timestamp: start.add(const Duration(seconds: 25)),
          ),
        );

      expect(acc.timeMovingSecondsForTest, greaterThan(movingAfterResume));
    });

    test('elapsed resumes ticking after resume (D-06)', () {
      final acc = TripAccumulator(startedAt: start)
        ..pause(start.add(const Duration(seconds: 10)))
        ..resume(start.add(const Duration(seconds: 40)));

      // 40s wall, 30s paused → elapsed = 10 at resume instant, ticks after.
      final snap = acc.snapshot(start.add(const Duration(seconds: 50)));
      expect(snap.isPaused, isFalse);
      expect(snap.pausedSeconds, 30);
      expect(snap.breakCount, 1);
      // elapsed = 50 - 0 - 30 = 20.
      expect(snap.elapsedSeconds, 20);
    });

    test('pause while paused is a no-op; resume while running is a no-op', () {
      final acc = TripAccumulator(startedAt: start)
        ..pause(start.add(const Duration(seconds: 10)))
        ..pause(start.add(const Duration(seconds: 20))); // ignored

      // The open span is still anchored at the FIRST pause (10).
      final snap = acc.snapshot(start.add(const Duration(seconds: 30)));
      expect(snap.pausedSeconds, 20); // 30 - 10

      // resume while running: resume twice — second is a no-op.
      acc
        ..resume(start.add(const Duration(seconds: 30)))
        ..resume(start.add(const Duration(seconds: 40))); // ignored
      expect(acc.accumulatedPausedSecondsForTest, 20);
    });

    test('finalize emits segments + active duration (D-07)', () {
      final acc = TripAccumulator(startedAt: start)
        ..pause(start.add(const Duration(seconds: 10)))
        ..resume(start.add(const Duration(seconds: 40)));

      final trip = acc.finalize(start.add(const Duration(seconds: 60)));

      // 60s wall − 30s paused = 30s active.
      expect(trip.durationSeconds, 30);
      expect(trip.totalPausedSeconds, 30);
      expect(trip.breaks, hasLength(1));
      expect(
        trip.breaks.single['startUs'],
        start.add(const Duration(seconds: 10)).microsecondsSinceEpoch,
      );
      expect(
        trip.breaks.single['endUs'],
        start.add(const Duration(seconds: 40)).microsecondsSinceEpoch,
      );
    });

    test('finalize while paused closes the open break at endedAt (D-07)', () {
      final acc = TripAccumulator(startedAt: start)
        ..pause(start.add(const Duration(seconds: 20)));

      final trip = acc.finalize(start.add(const Duration(seconds: 50)));

      expect(trip.breaks, hasLength(1));
      expect(
        trip.breaks.single['startUs'],
        start.add(const Duration(seconds: 20)).microsecondsSinceEpoch,
      );
      expect(
        trip.breaks.single['endUs'],
        start.add(const Duration(seconds: 50)).microsecondsSinceEpoch,
      );
      // 50s wall − 30s paused = 20s active.
      expect(trip.durationSeconds, 20);
      expect(trip.totalPausedSeconds, 30);
    });

    test('no-pause regression: identical attribution + zero breaks', () {
      final acc = TripAccumulator(startedAt: start)
        ..addSample(
          _pos(lat: 37.7749, lng: -122.4194, speedMs: 20, timestamp: start),
        )
        ..addSample(
          _pos(
            lat: 37.7800,
            lng: -122.4100,
            speedMs: 20,
            timestamp: start.add(const Duration(seconds: 5)),
          ),
        );

      final trip = acc.finalize(start.add(const Duration(seconds: 10)));

      expect(trip.totalPausedSeconds, 0);
      expect(trip.breaks, isEmpty);
      // Wall-clock duration unchanged when no pauses.
      expect(trip.durationSeconds, 10);
      expect(trip.timeMovingSeconds, 5);
      expect(trip.timeStuckSeconds, 0);
      expect(trip.distanceMeters, greaterThan(0));
    });

    test('finalize is a no-op for pause/resume/addSample after finalize', () {
      final acc = TripAccumulator(startedAt: start)
        ..finalize(start.add(const Duration(seconds: 10)))
        ..pause(start.add(const Duration(seconds: 5)))
        ..resume(start.add(const Duration(seconds: 6)));

      expect(acc.isPausedForTest, isFalse);
      expect(acc.accumulatedPausedSecondsForTest, 0);
    });
  });

  group('FinalizedTrip', () {
    test('toMap/fromMap round-trips', () {
      final trip = FinalizedTrip(
        id: 'test-id-123',
        startTime: DateTime.utc(2026, 1, 1, 8),
        endTime: DateTime.utc(2026, 1, 1, 8, 30),
        durationSeconds: 1800,
        distanceMeters: 12345.6,
        timeMovingSeconds: 1500,
        timeStuckSeconds: 300,
        encodedPolyline: '_p~iF~ps|U',
      );

      final map = trip.toMap();
      final restored = FinalizedTrip.fromMap(map);

      expect(restored.id, trip.id);
      expect(restored.startTime, trip.startTime);
      expect(restored.endTime, trip.endTime);
      expect(restored.durationSeconds, trip.durationSeconds);
      expect(restored.distanceMeters, trip.distanceMeters);
      expect(restored.timeMovingSeconds, trip.timeMovingSeconds);
      expect(restored.timeStuckSeconds, trip.timeStuckSeconds);
      expect(restored.encodedPolyline, trip.encodedPolyline);
      // New primitive fields default safely on the legacy-shaped builder.
      expect(restored.totalPausedSeconds, 0);
      expect(restored.breaks, isEmpty);
    });

    test(
      'toMap/fromMap round-trips breaks + totalPausedSeconds as primitives',
      () {
        final trip = FinalizedTrip(
          id: 'paused-trip',
          startTime: DateTime.utc(2026, 1, 1, 8),
          endTime: DateTime.utc(2026, 1, 1, 8, 30),
          durationSeconds: 1500,
          distanceMeters: 12345.6,
          timeMovingSeconds: 1200,
          timeStuckSeconds: 300,
          encodedPolyline: '_p~iF~ps|U',
          totalPausedSeconds: 300,
          breaks: const <Map<String, Object?>>[
            <String, Object?>{'startUs': 1000, 'endUs': 2000},
            <String, Object?>{'startUs': 3000, 'endUs': 4000},
          ],
        );

        final map = trip.toMap();
        // The serialized breaks must be a List of primitive maps
        // (isolate-safe).
        final encodedBreaks = map['breaks'];
        expect(encodedBreaks, isA<List<Object?>>());
        expect(map['totalPausedSeconds'], 300);

        final restored = FinalizedTrip.fromMap(map);
        expect(restored.totalPausedSeconds, 300);
        expect(restored.breaks, hasLength(2));
        expect(restored.breaks.first['startUs'], 1000);
        expect(restored.breaks.first['endUs'], 2000);
        expect(restored.breaks.last['startUs'], 3000);
        expect(restored.breaks.last['endUs'], 4000);
        // Value equality holds across the round-trip (deep list equality).
        expect(restored, trip);
      },
    );
  });

  group('TripSnapshot', () {
    test('toMap/fromMap round-trips', () {
      final snap = TripSnapshot(
        startedAt: DateTime.utc(2026, 1, 1, 8),
        elapsedSeconds: 120,
        distanceMeters: 500,
        timeMovingSeconds: 100,
        timeStuckSeconds: 20,
        currentSpeedMs: 15,
      );

      final map = snap.toMap();
      final restored = TripSnapshot.fromMap(map);

      expect(restored.startedAt, snap.startedAt);
      expect(restored.elapsedSeconds, snap.elapsedSeconds);
      expect(restored.distanceMeters, snap.distanceMeters);
      expect(restored.timeMovingSeconds, snap.timeMovingSeconds);
      expect(restored.timeStuckSeconds, snap.timeStuckSeconds);
      expect(restored.currentSpeedMs, snap.currentSpeedMs);
      // New pause fields default safely on the legacy-shaped builder.
      expect(restored.isPaused, isFalse);
      expect(restored.pausedSeconds, 0);
      expect(restored.breakCount, 0);
    });

    test('toMap/fromMap round-trips isPaused/pausedSeconds/breakCount', () {
      final snap = TripSnapshot(
        startedAt: DateTime.utc(2026, 1, 1, 8),
        elapsedSeconds: 120,
        distanceMeters: 500,
        timeMovingSeconds: 100,
        timeStuckSeconds: 20,
        currentSpeedMs: 0,
        isPaused: true,
        pausedSeconds: 45,
        breakCount: 2,
      );

      final map = snap.toMap();
      expect(map['isPaused'], isTrue);
      expect(map['pausedSeconds'], 45);
      expect(map['breakCount'], 2);

      final restored = TripSnapshot.fromMap(map);
      expect(restored.isPaused, isTrue);
      expect(restored.pausedSeconds, 45);
      expect(restored.breakCount, 2);
    });

    test('fromMap tolerates a legacy map missing the new pause keys', () {
      final legacy = <String, Object?>{
        'startedAtUs': DateTime.utc(2026, 1, 1, 8).microsecondsSinceEpoch,
        'elapsedSeconds': 60,
        'distanceMeters': 100.0,
        'timeMovingSeconds': 50,
        'timeStuckSeconds': 10,
        'currentSpeedMs': 5.0,
      };

      final restored = TripSnapshot.fromMap(legacy);
      expect(restored.isPaused, isFalse);
      expect(restored.pausedSeconds, 0);
      expect(restored.breakCount, 0);
    });
  });

  group('TripAccumulator Serialization', () {
    test('dumpState and restore round-trips state losslessly', () {
      final start = DateTime.utc(2026, 1, 1, 8);
      final acc = TripAccumulator(startedAt: start)
        ..addSample(_pos(lat: 37.7749, lng: -122.4194, speedMs: 20, timestamp: start))
        ..pause(start.add(const Duration(seconds: 10)))
        ..resume(start.add(const Duration(seconds: 20)))
        ..addSample(_pos(lat: 37.7800, lng: -122.4194, speedMs: 20, timestamp: start.add(const Duration(seconds: 30))));

      final dumped = acc.dumpState();
      final restored = TripAccumulator.restore(dumped);

      // Verify the restored accumulator produces the identical snapshot.
      final snapOrig = acc.snapshot(start.add(const Duration(seconds: 40)));
      final snapRestored = restored.snapshot(start.add(const Duration(seconds: 40)));

      expect(snapRestored.startedAt, snapOrig.startedAt);
      expect(snapRestored.elapsedSeconds, snapOrig.elapsedSeconds);
      expect(snapRestored.distanceMeters, snapOrig.distanceMeters);
      expect(snapRestored.timeMovingSeconds, snapOrig.timeMovingSeconds);
      expect(snapRestored.timeStuckSeconds, snapOrig.timeStuckSeconds);
      expect(snapRestored.currentSpeedMs, snapOrig.currentSpeedMs);
      expect(snapRestored.isPaused, snapOrig.isPaused);
      expect(snapRestored.pausedSeconds, snapOrig.pausedSeconds);
      expect(snapRestored.breakCount, snapOrig.breakCount);

      // Also verify we can still finalize successfully and get the same result.
      final end = start.add(const Duration(seconds: 60));
      final finalOrig = acc.finalize(end);
      final finalRestored = restored.finalize(end);

      expect(finalRestored.durationSeconds, finalOrig.durationSeconds);
      expect(finalRestored.distanceMeters, finalOrig.distanceMeters);
      expect(finalRestored.encodedPolyline, finalOrig.encodedPolyline);
      expect(finalRestored.breaks.length, finalOrig.breaks.length);
      expect(finalRestored.id, finalOrig.id);
    });
  });
}
