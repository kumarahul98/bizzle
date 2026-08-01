import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/stuck_run_collapser.dart';

/// Unit coverage for the Phase 31 D-03 run-collapsing rules.
///
/// The fixture builds a synthetic interval list from a compact string where
/// each character is one interval: `s` = stuck, `m` = moving, `u` =
/// unattributed. Every interval is [_intervalSeconds] long, so a run of N
/// stuck characters lasts `N * _intervalSeconds` seconds and the 20s floor is
/// crossed at exactly 2 characters.
const int _intervalSeconds = 10;
final DateTime _origin = DateTime.utc(2026, 3, 1, 8);

/// Build index-parallel `(intervals, sampleTimes)` from a class string. The
/// leading interval is always `unattributed` (no interval precedes the first
/// sample), matching what `TripAccumulator` records.
({List<StuckInterval> intervals, List<DateTime> times}) fixture(String spec) {
  final intervals = <StuckInterval>[
    (cls: StuckIntervalClass.unattributed, seconds: 0),
  ];
  final times = <DateTime>[_origin];
  for (var i = 0; i < spec.length; i++) {
    final c = spec[i];
    intervals.add(switch (c) {
      's' => (cls: StuckIntervalClass.stuck, seconds: _intervalSeconds),
      'm' => (cls: StuckIntervalClass.moving, seconds: _intervalSeconds),
      _ => (cls: StuckIntervalClass.unattributed, seconds: 0),
    });
    times.add(_origin.add(Duration(seconds: (i + 1) * _intervalSeconds)));
  }
  return (intervals: intervals, times: times);
}

List<StuckRun> collapse(String spec) {
  final f = fixture(spec);
  return collapseStuckRuns(intervals: f.intervals, sampleTimes: f.times);
}

void main() {
  group('collapseStuckRuns — D-03 run collapsing', () {
    test('the 20s floor sits at 2 ten-second intervals (fixture sanity)', () {
      expect(kStuckSegmentMinSeconds, 20);
      expect(
        2 * _intervalSeconds,
        greaterThanOrEqualTo(kStuckSegmentMinSeconds),
      );
      expect(1 * _intervalSeconds, lessThan(kStuckSegmentMinSeconds));
    });

    test('contiguous stuck intervals merge into ONE run', () {
      final runs = collapse('ssssssss');
      expect(runs, hasLength(1));
      expect(runs.single.attributedSeconds, 80);
      // Interval 1 is the first stuck one, so the run starts at point 0 and
      // ends at point 8 (the last stuck interval's index).
      expect(runs.single.startPointIndex, 0);
      expect(runs.single.endPointIndex, 8);
    });

    test('a moving interval splits one stretch into two runs', () {
      final runs = collapse('ssssssmssssss');
      expect(runs, hasLength(2));
      expect(runs[0].endPointIndex, 6);
      expect(runs[1].startPointIndex, 7);
      expect(runs[0].attributedSeconds, 60);
      expect(runs[1].attributedSeconds, 60);
    });

    test(
      'an unattributed interval SPLITS a run — it never bridges one (SC#4)',
      () {
        // Six stuck, a GPS blackout, six stuck. Bridging would yield one
        // 13-point run painted straight through the blackout.
        final runs = collapse('ssssssussssss');
        expect(runs, hasLength(2));
        expect(runs[0].startPointIndex, 0);
        expect(runs[0].endPointIndex, 6);
        // The blackout interval (index 7) belongs to NEITHER run: the second
        // run starts from point 7 (its own leading sample) and the blackout
        // span 6 → 7 is left unpainted.
        expect(runs[1].startPointIndex, 7);
        expect(runs[1].endPointIndex, 13);
      },
    );

    test('a run below the 20s floor is discarded entirely', () {
      // One ten-second stuck interval = 10s < 20s.
      expect(collapse('mmsmm'), isEmpty);
    });

    test('a run exactly at the floor is retained', () {
      final runs = collapse('mmssmm');
      expect(runs, hasLength(1));
      expect(runs.single.attributedSeconds, kStuckSegmentMinSeconds);
    });

    test('short runs are dropped while long ones in the same trip survive', () {
      // 1 stuck (10s, dropped) · moving · 7 stuck (70s, kept) · moving ·
      // 1 stuck (10s, dropped).
      final runs = collapse('sm${'s' * 7}ms');
      expect(runs, hasLength(1));
      expect(runs.single.attributedSeconds, 70);
    });

    test('a run at the very FIRST interval is emitted', () {
      final runs = collapse('ssssssmmm');
      expect(runs, hasLength(1));
      expect(runs.single.startPointIndex, 0);
      expect(runs.single.startTime, _origin);
    });

    test('a run at the very LAST interval is emitted (loop-exit flush)', () {
      final runs = collapse('mmmssssss');
      expect(runs, hasLength(1));
      expect(runs.single.endPointIndex, 9);
      expect(
        runs.single.endTime,
        _origin.add(const Duration(seconds: 90)),
      );
    });

    test('an all-stuck trip is one run spanning every point', () {
      final runs = collapse('s' * 20);
      expect(runs, hasLength(1));
      expect(runs.single.startPointIndex, 0);
      expect(runs.single.endPointIndex, 20);
      expect(runs.single.attributedSeconds, 200);
    });

    test('an all-moving trip yields no runs', () {
      expect(collapse('m' * 20), isEmpty);
    });

    test('an empty sample list yields no runs', () {
      expect(
        collapseStuckRuns(intervals: const [], sampleTimes: const []),
        isEmpty,
      );
    });

    test('timestamps come from the boundary samples, in UTC', () {
      final runs = collapse('mmssssssmm');
      expect(runs.single.startTime, _origin.add(const Duration(seconds: 20)));
      expect(runs.single.endTime, _origin.add(const Duration(seconds: 80)));
      expect(runs.single.startTime.isUtc, isTrue);
      expect(runs.single.endTime.isUtc, isTrue);
    });

    test('mismatched list lengths degrade rather than throw', () {
      final f = fixture('ssssssss');
      final runs = collapseStuckRuns(
        intervals: f.intervals,
        // Truncated sample list — a legacy recovered accumulator. The 20s
        // floor is crossed well before the truncation point, so this now
        // emits one run bounded by the shorter list rather than nothing.
        sampleTimes: f.times.sublist(0, 4),
      );
      expect(runs, hasLength(1));
      expect(runs.single.endPointIndex, 3);
      expect(runs.single.attributedSeconds, 30);
    });
  });

  group('collapseStuckRuns — T-31-03 invariant', () {
    test(
      'sum(retained run seconds) <= total stuck seconds, over many shapes',
      () {
        // Deterministic pseudo-random specs: every retained run is a disjoint
        // subset of the stuck intervals feeding timeStuckSeconds, so the sum
        // can only be smaller (never larger) once short runs are dropped.
        const alphabet = 'smu';
        var seed = 12345;
        int next(int bound) {
          seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
          return seed % bound;
        }

        for (var trial = 0; trial < 200; trial++) {
          final spec = StringBuffer();
          final length = 1 + next(60);
          for (var i = 0; i < length; i++) {
            spec.write(alphabet[next(alphabet.length)]);
          }
          final specString = spec.toString();

          // The accumulator's counter: EVERY stuck interval, floor or not.
          final timeStuckSeconds =
              's'.allMatches(specString).length * _intervalSeconds;
          final runs = collapse(specString);
          final painted = runs.fold<int>(
            0,
            (sum, r) => sum + r.attributedSeconds,
          );

          expect(
            painted,
            lessThanOrEqualTo(timeStuckSeconds),
            reason: 'spec "$specString" painted more than it measured',
          );
          // And every emitted run must itself clear the floor.
          for (final run in runs) {
            expect(
              run.attributedSeconds,
              greaterThanOrEqualTo(kStuckSegmentMinSeconds),
            );
            expect(run.endPointIndex, greaterThan(run.startPointIndex));
          }
        }
      },
    );
  });
}
