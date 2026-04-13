import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';

/// Unit tests for the sealed [TrackingState] hierarchy and the
/// `trackingActiveFromSnapshotMap` adapter that converts a
/// `TripSnapshot.toMap()` payload (m/s source-of-truth) into a
/// [TrackingActive] UI value (km/h display).
///
/// These tests lock in the isolate-boundary contract for plan 02-03:
///
///   * All singleton variants (idle/starting/stopping) are `const`.
///   * `TrackingError` rejects an empty message at construction.
///   * m/s → km/h conversion happens EXACTLY ONCE — inside the adapter.
///   * Exhaustive switches compile without a default branch.
void main() {
  group('TrackingState singletons', () {
    test('TrackingIdle is const-constructible', () {
      const a = TrackingIdle();
      const b = TrackingIdle();
      expect(identical(a, b), isTrue);
    });

    test('TrackingStarting is const-constructible', () {
      const a = TrackingStarting();
      const b = TrackingStarting();
      expect(identical(a, b), isTrue);
    });

    test('TrackingStopping is const-constructible', () {
      const a = TrackingStopping();
      const b = TrackingStopping();
      expect(identical(a, b), isTrue);
    });
  });

  group('TrackingError', () {
    test('carries the supplied message', () {
      const err = TrackingError('oops');
      expect(err.message, 'oops');
    });

    test('rejects an empty message', () {
      expect(
        () => TrackingError(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('trackingActiveFromSnapshotMap', () {
    test(
      'converts currentSpeedMs (27.777) to currentSpeedKmh (~100.0)',
      () {
        final startedAt = DateTime.utc(2026, 4, 13, 10);
        final map = <String, Object?>{
          'startedAtUs': startedAt.microsecondsSinceEpoch,
          'elapsedSeconds': 42,
          'distanceMeters': 1234.5,
          'timeMovingSeconds': 30,
          'timeStuckSeconds': 12,
          'currentSpeedMs': 27.777,
        };

        final active = trackingActiveFromSnapshotMap(map);

        expect(active.startedAt.toUtc(), startedAt);
        expect(active.elapsedSeconds, 42);
        expect(active.distanceMeters, closeTo(1234.5, 1e-9));
        expect(active.timeMovingSeconds, 30);
        expect(active.timeStuckSeconds, 12);
        expect(active.currentSpeedKmh, closeTo(100.0, 0.01));
      },
    );

    test('accepts an int currentSpeedMs via num.toDouble', () {
      final startedAt = DateTime.utc(2026, 4, 13, 11);
      final map = <String, Object?>{
        'startedAtUs': startedAt.microsecondsSinceEpoch,
        'elapsedSeconds': 10,
        'distanceMeters': 0,
        'timeMovingSeconds': 0,
        'timeStuckSeconds': 10,
        'currentSpeedMs': 0,
      };

      final active = trackingActiveFromSnapshotMap(map);

      expect(active.currentSpeedKmh, 0.0);
    });

    test('throws ArgumentError when a required key is missing', () {
      expect(
        () => trackingActiveFromSnapshotMap(<String, Object?>{
          'elapsedSeconds': 1,
          'distanceMeters': 0,
          'timeMovingSeconds': 0,
          'timeStuckSeconds': 1,
          'currentSpeedMs': 0,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('exhaustive switch', () {
    test('compiles without a default branch for every variant', () {
      String describe(TrackingState s) {
        return switch (s) {
          TrackingIdle() => 'idle',
          TrackingStarting() => 'starting',
          TrackingActive() => 'active',
          TrackingStopping() => 'stopping',
          TrackingError() => 'error',
        };
      }

      final active = TrackingActive(
        startedAt: DateTime.utc(2026, 4, 13),
        elapsedSeconds: 0,
        distanceMeters: 0,
        currentSpeedKmh: 0,
        timeMovingSeconds: 0,
        timeStuckSeconds: 0,
      );

      expect(describe(const TrackingIdle()), 'idle');
      expect(describe(const TrackingStarting()), 'starting');
      expect(describe(active), 'active');
      expect(describe(const TrackingStopping()), 'stopping');
      expect(describe(const TrackingError('x')), 'error');
    });
  });
}
