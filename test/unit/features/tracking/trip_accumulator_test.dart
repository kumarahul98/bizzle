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
                Duration(
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
        );
      acc.finalize(start.add(const Duration(seconds: 10)));

      acc.addSample(
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
    });
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
    });
  });
}
