// Unit tests for the Phase 31 (D-02) stuck-segment pipeline inside
// [TripAccumulator]: the index-parallel interval classification, its survival
// across the accuracy gate and pause, and the segment maps finalize() emits.
//
// The single most important property proved here is INDEX CORRELATION:
// segment point indices must address the same points the encoded polyline
// decodes to, even when samples were rejected by the accuracy gate. If any
// _samples append site ever forgets its matching classification append, these
// tests fail.

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/stuck_run_collapser.dart';
import 'package:traevy/features/tracking/services/trip_accumulator.dart';
import 'package:traevy/shared/utils/polyline_codec.dart';

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

/// Below the 10 km/h threshold (10 km/h ≈ 2.78 m/s).
const double _stuckSpeed = 1;

/// Comfortably above it.
const double _movingSpeed = 15;

void main() {
  final start = DateTime.utc(2026, 3, 1, 8);

  /// Feed [speeds] as one sample per [stepSeconds], walking north so each
  /// sample is a distinct coordinate. Returns the accumulator.
  TripAccumulator feed(
    List<double> speeds, {
    int stepSeconds = 10,
    List<double>? accuracies,
  }) {
    final acc = TripAccumulator(startedAt: start);
    for (var i = 0; i < speeds.length; i++) {
      acc.addSample(
        _pos(
          lat: 37.7749 + i * 0.001,
          lng: -122.4194,
          speedMs: speeds[i],
          timestamp: start.add(Duration(seconds: i * stepSeconds)),
          accuracy: accuracies == null ? 5 : accuracies[i],
        ),
      );
    }
    return acc;
  }

  group('interval classification is index-parallel to the polyline', () {
    test('one class entry per retained sample', () {
      final acc = feed(List<double>.filled(12, _stuckSpeed));
      expect(acc.intervalClassesForTest, hasLength(acc.sampleCountForTest));
      expect(acc.sampleCountForTest, 12);
    });

    test('the first entry is always unattributed', () {
      final acc = feed([_stuckSpeed, _stuckSpeed]);
      expect(
        acc.intervalClassesForTest.first.cls,
        StuckIntervalClass.unattributed,
      );
      expect(acc.intervalClassesForTest.first.seconds, 0);
    });

    test(
      'accuracy-rejected samples never enter EITHER list, so segment indices '
      'still address the correct decoded polyline points',
      () {
        // 10 stuck samples, but samples 3 and 6 are beyond the accuracy gate
        // and are dropped before they reach _samples. The remaining 8 form one
        // uninterrupted stuck run.
        final accuracies = List<double>.filled(10, 5);
        accuracies[3] = kTrackingMaxAcceptableAccuracyMeters + 50;
        accuracies[6] = kTrackingMaxAcceptableAccuracyMeters + 50;
        final acc = feed(
          List<double>.filled(10, _stuckSpeed),
          accuracies: accuracies,
        );

        expect(acc.sampleCountForTest, 8, reason: '2 samples were rejected');
        expect(acc.intervalClassesForTest, hasLength(8));

        final trip = acc.finalize(start.add(const Duration(seconds: 90)));
        final decoded = decodePolyline(trip.encodedPolyline);
        expect(decoded, hasLength(8));

        expect(trip.stuckSegments, hasLength(1));
        final segment = trip.stuckSegments.single;
        expect(segment['startIndex'], 0);
        expect(segment['endIndex'], 7);
        // Every index is addressable in the decoded polyline (T-31-02).
        expect(segment['endIndex']! as int, lessThan(decoded.length));
        // And the endpoint really is the LAST accepted sample's coordinate,
        // not the last emitted sample's — proving the two lists stayed aligned
        // through the rejections.
        expect(decoded.last.lat, closeTo(37.7749 + 9 * 0.001, 1e-5));
      },
    );

    test('a paused sample is unattributed and breaks the run (D-07)', () {
      final acc = TripAccumulator(startedAt: start);
      // 8 stuck samples (70s) → pause → 2 bridged samples → resume →
      // 8 stuck samples (70s). The bridge must not join the two runs.
      var i = 0;
      void sample(double speed) {
        acc.addSample(
          _pos(
            lat: 37.7749 + i * 0.001,
            lng: -122.4194,
            speedMs: speed,
            timestamp: start.add(Duration(seconds: i * 10)),
          ),
        );
        i++;
      }

      for (var n = 0; n < 8; n++) {
        sample(_stuckSpeed);
      }
      acc.pause(start.add(Duration(seconds: i * 10)));
      for (var n = 0; n < 2; n++) {
        sample(_stuckSpeed);
      }
      acc.resume(start.add(Duration(seconds: i * 10)));
      for (var n = 0; n < 8; n++) {
        sample(_stuckSpeed);
      }

      final trip = acc.finalize(start.add(Duration(seconds: i * 10)));
      expect(
        trip.stuckSegments,
        hasLength(2),
        reason: 'the bridge across a break must never join two stuck runs',
      );
    });

    test(
      'a gap longer than the attribution window is unattributed and is never '
      'painted (SC#4)',
      () {
        final acc = TripAccumulator(startedAt: start);
        // 8 stuck samples 10s apart, then a blackout far beyond the window,
        // then 8 more. Two runs, never one bridged run.
        var elapsed = 0;
        for (var n = 0; n < 8; n++) {
          acc.addSample(
            _pos(
              lat: 37.7749 + n * 0.001,
              lng: -122.4194,
              speedMs: _stuckSpeed,
              timestamp: start.add(Duration(seconds: elapsed)),
            ),
          );
          elapsed += 10;
        }
        elapsed += kTrackingMaxAttributableGapSeconds + 60;
        for (var n = 8; n < 16; n++) {
          acc.addSample(
            _pos(
              lat: 37.7749 + n * 0.001,
              lng: -122.4194,
              speedMs: _stuckSpeed,
              timestamp: start.add(Duration(seconds: elapsed)),
            ),
          );
          elapsed += 10;
        }

        final trip = acc.finalize(start.add(Duration(seconds: elapsed)));
        expect(trip.stuckSegments, hasLength(2));
        // Neither segment may span the blackout.
        for (final segment in trip.stuckSegments) {
          final startUs = segment['startUs']! as int;
          final endUs = segment['endUs']! as int;
          final span = Duration(microseconds: endUs - startUs);
          expect(span.inSeconds, lessThan(120));
        }
      },
    );
  });

  group('finalize() stuck segments', () {
    test('a wholly free-flowing trip emits no segments', () {
      final acc = feed(List<double>.filled(20, _movingSpeed));
      final trip = acc.finalize(start.add(const Duration(seconds: 200)));
      expect(trip.stuckSegments, isEmpty);
      expect(trip.timeStuckSeconds, 0);
    });

    test('a stuck stretch under the 20s floor emits no segment', () {
      // 1 interval × 10s = 10s of stuck time — real, counted, but not
      // painted. The printed figure and the map deliberately disagree here,
      // which is what the explainer copy states outright.
      final acc = feed([
        _movingSpeed,
        _stuckSpeed,
        _movingSpeed,
        _movingSpeed,
      ]);
      final trip = acc.finalize(start.add(const Duration(seconds: 40)));
      expect(trip.timeStuckSeconds, greaterThan(0));
      expect(trip.stuckSegments, isEmpty);
    });

    test('segment maps carry only primitives (isolate boundary)', () {
      final acc = feed(List<double>.filled(12, _stuckSpeed));
      final trip = acc.finalize(start.add(const Duration(seconds: 120)));
      expect(trip.stuckSegments, hasLength(1));
      for (final value in trip.stuckSegments.single.values) {
        expect(value, isA<int>());
      }
      // Survives a round trip across the channel unchanged.
      final roundTripped = trip.toMap();
      expect(roundTripped['stuckSegments'], trip.stuckSegments);
    });

    test(
      'painted segment time never exceeds the trip timeStuckSeconds (SC#3)',
      () {
        // Alternating shapes, including sub-floor stuck bursts that inflate
        // the counter without contributing a segment.
        for (final pattern in <List<double>>[
          List<double>.filled(20, _stuckSpeed),
          [
            for (var i = 0; i < 30; i++)
              i % 3 == 0 ? _movingSpeed : _stuckSpeed,
          ],
          [
            for (var i = 0; i < 40; i++) i % 7 < 5 ? _stuckSpeed : _movingSpeed,
          ],
          [
            for (var i = 0; i < 25; i++) i.isEven ? _stuckSpeed : _movingSpeed,
          ],
        ]) {
          final acc = feed(pattern);
          final trip = acc.finalize(
            start.add(Duration(seconds: pattern.length * 10)),
          );
          final painted = trip.stuckSegments.fold<int>(0, (sum, s) {
            final span = Duration(
              microseconds: (s['endUs']! as int) - (s['startUs']! as int),
            );
            return sum + span.inSeconds;
          });
          expect(
            painted,
            lessThanOrEqualTo(trip.timeStuckSeconds),
            reason: 'painted $painted s > measured ${trip.timeStuckSeconds} s',
          );
        }
      },
    );
  });

  group('restore keeps the two lists aligned', () {
    test('a dumped/restored accumulator preserves classification', () {
      final acc = feed(List<double>.filled(12, _stuckSpeed));
      final restored = TripAccumulator.restore(acc.dumpState());
      expect(
        restored.intervalClassesForTest,
        acc.intervalClassesForTest,
      );
      final trip = restored.finalize(start.add(const Duration(seconds: 120)));
      expect(trip.stuckSegments, hasLength(1));
    });

    test(
      'a legacy snapshot with no classes pads to the sample count rather than '
      'desynchronising indices',
      () {
        final acc = feed(List<double>.filled(12, _stuckSpeed));
        final state = acc.dumpState()..remove('_intervalClasses');
        final restored = TripAccumulator.restore(state);
        expect(restored.intervalClassesForTest, hasLength(12));
        expect(
          restored.intervalClassesForTest.every(
            (c) => c.cls == StuckIntervalClass.unattributed,
          ),
          isTrue,
        );
        // No fabricated segments for samples whose speed is no longer known.
        final trip = restored.finalize(start.add(const Duration(seconds: 120)));
        expect(trip.stuckSegments, isEmpty);
      },
    );
  });
}
