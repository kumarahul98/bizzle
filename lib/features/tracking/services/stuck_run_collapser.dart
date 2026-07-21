import 'package:flutter/foundation.dart';
import 'package:traevy/config/constants.dart';

/// How one GPS interval — the span from polyline point `i-1` to point `i` —
/// was classified by `TripAccumulator.addSample` (Phase 31, D-02).
///
/// There are exactly three outcomes and every accepted sample produces one,
/// so the list of classes is index-parallel to the sample list and therefore
/// to the decoded polyline.
enum StuckIntervalClass {
  /// The interval's leading speed was below the stuck threshold. Its seconds
  /// were added to `timeStuckSeconds`.
  stuck,

  /// The interval's leading speed was at or above the stuck threshold. Its
  /// seconds were added to `timeMovingSeconds`.
  moving,

  /// No time was attributed to this interval: it is the first sample, the
  /// timestamp delta was zero or negative, the trip was paused, or the gap
  /// exceeded [kTrackingMaxAttributableGapSeconds].
  ///
  /// D-03: an `unattributed` interval **breaks** a stuck run rather than
  /// extending it. A GPS blackout is not evidence of being stuck — bridging
  /// one would paint a red line through a tunnel the user drove at speed.
  unattributed,
}

/// One classified interval: how it was classified and how many whole seconds
/// it contributed to the matching counter (zero for [StuckIntervalClass
/// .unattributed]).
///
/// The seconds are the SAME rounded integers the accumulator added to
/// `timeStuckSeconds`, never a re-derivation — that is what makes
/// `sum(retained runs) <= timeStuckSeconds` hold by construction (T-31-03).
typedef StuckInterval = ({StuckIntervalClass cls, int seconds});

/// A contiguous run of [StuckIntervalClass.stuck] intervals that survived the
/// [kStuckSegmentMinSeconds] floor, expressed as an inclusive index range into
/// the decoded polyline plus the wall-clock span it covers.
@immutable
class StuckRun {
  /// Construct a run. [startTime] and [endTime] must be UTC.
  const StuckRun({
    required this.startPointIndex,
    required this.endPointIndex,
    required this.startTime,
    required this.endTime,
    required this.attributedSeconds,
  });

  /// Index of the first polyline point in the run (the point the first stuck
  /// interval started FROM).
  final int startPointIndex;

  /// Index of the last polyline point in the run, inclusive.
  final int endPointIndex;

  /// Timestamp (UTC) of the sample at [startPointIndex].
  final DateTime startTime;

  /// Timestamp (UTC) of the sample at [endPointIndex].
  final DateTime endTime;

  /// Sum of the run's intervals' attributed seconds — the exact slice of
  /// `timeStuckSeconds` this run represents.
  final int attributedSeconds;

  @override
  bool operator ==(Object other) =>
      other is StuckRun &&
      other.startPointIndex == startPointIndex &&
      other.endPointIndex == endPointIndex &&
      other.startTime == startTime &&
      other.endTime == endTime &&
      other.attributedSeconds == attributedSeconds;

  @override
  int get hashCode => Object.hash(
    startPointIndex,
    endPointIndex,
    startTime,
    endTime,
    attributedSeconds,
  );

  @override
  String toString() =>
      'StuckRun($startPointIndex..$endPointIndex, ${attributedSeconds}s)';
}

/// Collapse index-parallel [intervals] into the contiguous stuck runs worth
/// painting (Phase 31, D-03).
///
/// [intervals] and [sampleTimes] are index-parallel: entry `i` of [intervals]
/// classifies the span from point `i-1` to point `i`, and entry `i` of
/// [sampleTimes] is the timestamp of point `i`. Entry `0` is always
/// [StuckIntervalClass.unattributed] (there is no interval before the first
/// sample). Extra entries in either list beyond the shorter one are ignored,
/// so a legacy recovered accumulator whose class list is shorter than its
/// sample list degrades to fewer runs rather than throwing.
///
/// Rules:
///   * `moving` and `unattributed` both terminate the current run.
///   * A run whose summed attributed seconds is below
///     [kStuckSegmentMinSeconds] is discarded entirely.
///
/// Returns runs in chronological order. Pure — no I/O, no clock reads — so it
/// is safe to call from the tracking service isolate and directly testable.
List<StuckRun> collapseStuckRuns({
  required List<StuckInterval> intervals,
  required List<DateTime> sampleTimes,
}) {
  final count = intervals.length < sampleTimes.length
      ? intervals.length
      : sampleTimes.length;
  final runs = <StuckRun>[];

  // Interval index the open run started at, or -1 when no run is open.
  var runStartInterval = -1;
  var runSeconds = 0;

  void closeRun(int lastStuckInterval) {
    if (runStartInterval != -1 && runSeconds >= kStuckSegmentMinSeconds) {
      // Interval `i` spans point i-1 → i, so the run's first point is the one
      // BEFORE its first interval. Interval 0 is always `unattributed`, so
      // runStartInterval is never 0 in practice; the clamp is a defensive
      // floor rather than an expected branch.
      final startPoint = runStartInterval > 0 ? runStartInterval - 1 : 0;
      runs.add(
        StuckRun(
          startPointIndex: startPoint,
          endPointIndex: lastStuckInterval,
          startTime: sampleTimes[startPoint].toUtc(),
          endTime: sampleTimes[lastStuckInterval].toUtc(),
          attributedSeconds: runSeconds,
        ),
      );
    }
    runStartInterval = -1;
    runSeconds = 0;
  }

  for (var i = 0; i < count; i++) {
    if (intervals[i].cls == StuckIntervalClass.stuck) {
      if (runStartInterval == -1) runStartInterval = i;
      runSeconds += intervals[i].seconds;
    } else {
      closeRun(i - 1);
    }
  }
  closeRun(count - 1);

  return runs;
}
