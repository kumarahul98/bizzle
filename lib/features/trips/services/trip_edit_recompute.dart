import 'package:traevy/config/constants.dart';

/// A single closed break segment in wall-clock UTC, as the recompute and
/// validation logic operates on it (Phase 19, D-01/D-10).
///
/// The edit sheet (Plan 02) maps each persisted `TripBreakRow` into one of
/// these and back. Segments are always closed: finalize never leaves an open
/// (null-end) break (D-07), so this type has no nullable end.
///
/// Immutable value type — `const` constructor, all fields `final`.
class EditBreakSegment {
  /// Construct a closed break segment. [start] and [end] are UTC instants.
  const EditBreakSegment({required this.start, required this.end});

  /// Break start (pause) in UTC.
  final DateTime start;

  /// Break end (resume) in UTC.
  final DateTime end;

  /// Duration of this segment in whole seconds.
  int get seconds => end.difference(start).inSeconds;
}

/// Result of [TripEditRecompute.validate]: a finite, exhaustive state per
/// the CLAUDE.md "sealed classes for finite state" rule.
sealed class EditValidationResult {
  const EditValidationResult();
}

/// The edit passed every validation rule (D-05/D-06/D-07).
final class EditValid extends EditValidationResult {
  const EditValid();
}

/// The edit failed the FIRST rule whose message is [message] — one of the
/// `kEditValidation*` constants, never raw English.
final class EditInvalid extends EditValidationResult {
  const EditInvalid(this.message);

  /// User-facing failure message (a `kEditValidation*` constant).
  final String message;
}

/// Pure recompute + validation logic for full trip editing (Phase 19).
///
/// No Drift, no Flutter, no `DateTime.now()` — every method is deterministic
/// and unit-tested in isolation. The edit sheet computes these values live
/// and hands the results to the notifier, which only persists (keeping the
/// math here and the I/O there).
abstract final class TripEditRecompute {
  /// Active duration of an edited trip in seconds (D-01):
  /// `(end − start) − Σ break durations`. [breaks] must already be the
  /// validated, clamped, closed segments inside `[start, end]`.
  static int activeSeconds(
    DateTime start,
    DateTime end,
    List<EditBreakSegment> breaks,
  ) {
    final wallClock = end.difference(start).inSeconds;
    final paused = breaks.fold<int>(0, (sum, b) => sum + b.seconds);
    return wallClock - paused;
  }

  /// Re-derive moving/stuck seconds for a new active duration while
  /// preserving the original `moving:stuck` ratio (D-01), and NEVER
  /// inventing a ratio for a 0/0 manual entry (D-02).
  ///
  /// `newStuck` is the exact complement (`newActive − newMoving`) so the
  /// `moving + stuck == active` invariant always holds. `newMoving` is
  /// clamped into `[0, newActive]` to guard rounding at zero-length.
  static ({int moving, int stuck}) rescaleTraffic({
    required int origMoving,
    required int origStuck,
    required int newActiveSeconds,
  }) {
    final total = origMoving + origStuck;
    if (total == 0) {
      // D-02: a manual entry with no GPS keeps 0/0 — derive nothing.
      return (moving: 0, stuck: 0);
    }
    final rawMoving = (newActiveSeconds * origMoving / total).round();
    final moving = rawMoving.clamp(0, newActiveSeconds);
    final stuck = newActiveSeconds - moving;
    return (moving: moving, stuck: stuck);
  }

  /// Validate an edited window + its breaks, returning the FIRST failing
  /// rule (D-05/D-06/D-07). Order:
  ///   1. end must be strictly after start (D-06 at the trip level).
  ///   2. each break: start strictly before end (D-06).
  ///   3. each break: fully within `[tripStart, tripEnd]`; boundary-touch
  ///      of the trip edges is allowed (D-05).
  ///   4. sorted by start, every adjacent pair must satisfy
  ///      `prev.end < next.start` STRICTLY — rejecting overlap AND touch
  ///      (D-07).
  /// A COPY is sorted; the input list is never mutated.
  static EditValidationResult validate({
    required DateTime tripStart,
    required DateTime tripEnd,
    required List<EditBreakSegment> breaks,
  }) {
    if (!tripEnd.isAfter(tripStart)) {
      return const EditInvalid(kEditValidationEndBeforeStart);
    }

    for (final b in breaks) {
      if (!b.end.isAfter(b.start)) {
        return const EditInvalid(kEditValidationBreakZeroLength);
      }
      if (b.start.isBefore(tripStart) || b.end.isAfter(tripEnd)) {
        return const EditInvalid(kEditValidationBreakOutsideWindow);
      }
    }

    final sorted = [...breaks]..sort((a, b) => a.start.compareTo(b.start));
    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final next = sorted[i];
      // prev.end < next.start strictly → anything else (touch or overlap)
      // is rejected (D-07).
      if (!prev.end.isBefore(next.start)) {
        return const EditInvalid(kEditValidationBreakOverlap);
      }
    }

    return const EditValid();
  }

  /// Clamp/drop breaks to a (typically shrunk) `[newStart, newEnd]` window
  /// (D-10), reporting whether any break was adjusted:
  ///   * fully outside (`end <= newStart` or `start >= newEnd`) → DROP.
  ///   * partially outside → CLAMP `start = max(start, newStart)`,
  ///     `end = min(end, newEnd)`.
  ///   * a clamp that collapses to `start >= end` → DROP.
  /// `adjusted` is true if any break was dropped or clamped. The input list
  /// is never mutated.
  static ({List<EditBreakSegment> breaks, bool adjusted}) clampToWindow({
    required DateTime newStart,
    required DateTime newEnd,
    required List<EditBreakSegment> breaks,
  }) {
    final out = <EditBreakSegment>[];
    var adjusted = false;

    for (final b in breaks) {
      // Fully outside the new window → drop.
      if (!b.end.isAfter(newStart) || !b.start.isBefore(newEnd)) {
        adjusted = true;
        continue;
      }

      final clampedStart = b.start.isBefore(newStart) ? newStart : b.start;
      final clampedEnd = b.end.isAfter(newEnd) ? newEnd : b.end;
      final wasClamped = clampedStart != b.start || clampedEnd != b.end;

      // A clamp that collapses the segment → drop.
      if (!clampedEnd.isAfter(clampedStart)) {
        adjusted = true;
        continue;
      }

      if (wasClamped) {
        adjusted = true;
        out.add(EditBreakSegment(start: clampedStart, end: clampedEnd));
      } else {
        out.add(b);
      }
    }

    return (breaks: out, adjusted: adjusted);
  }
}
