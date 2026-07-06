import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/trips/services/trip_edit_recompute.dart';

/// Pure, table-driven coverage for the Phase 19 recompute/validation service
/// (D-01/D-02/D-05/D-06/D-07/D-10). No Flutter binding or Drift needed.
void main() {
  // A fixed reference window so cases read clearly.
  final tripStart = DateTime.utc(2026, 1, 1, 8); // 08:00
  final tripEnd = DateTime.utc(2026, 1, 1, 9); // 09:00 (3600s)

  EditBreakSegment seg(int startMin, int endMin) => EditBreakSegment(
    start: tripStart.add(Duration(minutes: startMin)),
    end: tripStart.add(Duration(minutes: endMin)),
  );

  group('activeSeconds (D-01)', () {
    test('no breaks → wall-clock seconds', () {
      expect(
        TripEditRecompute.activeSeconds(tripStart, tripEnd, const []),
        3600,
      );
    });

    test('subtracts a single 300s break', () {
      // break 08:10–08:15 = 300s
      final breaks = [seg(10, 15)];
      expect(
        TripEditRecompute.activeSeconds(tripStart, tripEnd, breaks),
        3300,
      );
    });

    test('subtracts multiple breaks', () {
      final breaks = [seg(10, 15), seg(40, 50)]; // 300 + 600
      expect(
        TripEditRecompute.activeSeconds(tripStart, tripEnd, breaks),
        2700,
      );
    });
  });

  group('rescaleTraffic (D-01/D-02 — sum == active invariant)', () {
    final cases =
        <
          ({
            String name,
            int origMoving,
            int origStuck,
            int newActive,
            int expectedMoving,
            int expectedStuck,
          })
        >[
          (
            name: 'preserve ratio, same active',
            origMoving: 3000,
            origStuck: 600,
            newActive: 3600,
            expectedMoving: 3000,
            expectedStuck: 600,
          ),
          (
            name: 'grow window keeps ratio',
            origMoving: 3000,
            origStuck: 600,
            newActive: 4200,
            expectedMoving: 3500,
            expectedStuck: 700,
          ),
          (
            name: 'shrink window keeps ratio',
            origMoving: 3000,
            origStuck: 600,
            newActive: 3000,
            expectedMoving: 2500,
            expectedStuck: 500,
          ),
          (
            name: 'break-shrunk active rescales',
            origMoving: 3000,
            origStuck: 600,
            newActive: 3300,
            // round(3300 * 3000 / 3600) = round(2750.0) = 2750
            expectedMoving: 2750,
            expectedStuck: 550,
          ),
          (
            name: '0/0 manual entry never invents a ratio (D-02)',
            origMoving: 0,
            origStuck: 0,
            newActive: 3600,
            expectedMoving: 0,
            expectedStuck: 0,
          ),
          (
            name: 'rounding edge: active 1, 1:1 ratio',
            origMoving: 1,
            origStuck: 1,
            newActive: 1,
            // round(1 * 1 / 2) = round(0.5) = 1 (Dart rounds half away from zero)
            expectedMoving: 1,
            expectedStuck: 0,
          ),
        ];

    for (final c in cases) {
      test(c.name, () {
        final result = TripEditRecompute.rescaleTraffic(
          origMoving: c.origMoving,
          origStuck: c.origStuck,
          newActiveSeconds: c.newActive,
        );
        expect(result.moving, c.expectedMoving, reason: c.name);
        expect(result.stuck, c.expectedStuck, reason: c.name);
        // Invariant: when there IS a measured ratio, moving + stuck == active.
        // The 0/0 manual-entry case is the deliberate exception (D-02): the
        // service never invents a ratio, so moving/stuck stay 0 and the new
        // active duration is carried by duration_seconds (set by the
        // notifier), not by moving+stuck.
        final hadRatio = c.origMoving + c.origStuck > 0;
        if (hadRatio) {
          expect(result.moving + result.stuck, c.newActive, reason: c.name);
        } else {
          expect(result.moving, 0, reason: c.name);
          expect(result.stuck, 0, reason: c.name);
        }
        expect(result.moving >= 0, isTrue, reason: c.name);
        expect(result.stuck >= 0, isTrue, reason: c.name);
      });
    }
  });

  group('validate (D-05/D-06/D-07 — first failure)', () {
    test('end <= start → end-before-start', () {
      final result = TripEditRecompute.validate(
        tripStart: tripEnd,
        tripEnd: tripStart,
        breaks: const [],
      );
      expect(result, isA<EditInvalid>());
      expect((result as EditInvalid).message, kEditValidationEndBeforeStart);
    });

    test('end == start → end-before-start', () {
      final result = TripEditRecompute.validate(
        tripStart: tripStart,
        tripEnd: tripStart,
        breaks: const [],
      );
      expect((result as EditInvalid).message, kEditValidationEndBeforeStart);
    });

    test('break start >= break end → zero-length', () {
      final result = TripEditRecompute.validate(
        tripStart: tripStart,
        tripEnd: tripEnd,
        breaks: [seg(20, 20)],
      );
      expect((result as EditInvalid).message, kEditValidationBreakZeroLength);
    });

    test('break before trip.start → outside window', () {
      final result = TripEditRecompute.validate(
        tripStart: tripStart,
        tripEnd: tripEnd,
        breaks: [seg(-10, 5)],
      );
      expect(
        (result as EditInvalid).message,
        kEditValidationBreakOutsideWindow,
      );
    });

    test('break after trip.end → outside window', () {
      final result = TripEditRecompute.validate(
        tripStart: tripStart,
        tripEnd: tripEnd,
        breaks: [seg(55, 70)],
      );
      expect(
        (result as EditInvalid).message,
        kEditValidationBreakOutsideWindow,
      );
    });

    test('break touching trip.start is VALID (boundary-touch, D-05)', () {
      final result = TripEditRecompute.validate(
        tripStart: tripStart,
        tripEnd: tripEnd,
        breaks: [seg(0, 10)],
      );
      expect(result, isA<EditValid>());
    });

    test('break touching trip.end is VALID (boundary-touch, D-05)', () {
      final result = TripEditRecompute.validate(
        tripStart: tripStart,
        tripEnd: tripEnd,
        breaks: [seg(50, 60)],
      );
      expect(result, isA<EditValid>());
    });

    test('two touching breaks (prev.end == next.start) → overlap', () {
      final result = TripEditRecompute.validate(
        tripStart: tripStart,
        tripEnd: tripEnd,
        breaks: [seg(10, 20), seg(20, 30)],
      );
      expect((result as EditInvalid).message, kEditValidationBreakOverlap);
    });

    test('two overlapping breaks (prev.end > next.start) → overlap', () {
      final result = TripEditRecompute.validate(
        tripStart: tripStart,
        tripEnd: tripEnd,
        breaks: [seg(10, 25), seg(20, 30)],
      );
      expect((result as EditInvalid).message, kEditValidationBreakOverlap);
    });

    test('overlap detected even when breaks supplied out of order', () {
      // Same as above but reversed input — validate must sort a COPY.
      final input = [seg(20, 30), seg(10, 25)];
      final result = TripEditRecompute.validate(
        tripStart: tripStart,
        tripEnd: tripEnd,
        breaks: input,
      );
      expect((result as EditInvalid).message, kEditValidationBreakOverlap);
      // Input is not mutated.
      expect(input.first.start, seg(20, 30).start);
    });

    test('non-adjacent valid breaks (prev.end < next.start) → valid', () {
      final result = TripEditRecompute.validate(
        tripStart: tripStart,
        tripEnd: tripEnd,
        breaks: [seg(10, 20), seg(25, 35)],
      );
      expect(result, isA<EditValid>());
    });

    test('empty breaks with a valid window → valid', () {
      final result = TripEditRecompute.validate(
        tripStart: tripStart,
        tripEnd: tripEnd,
        breaks: const [],
      );
      expect(result, isA<EditValid>());
    });
  });

  group('clampToWindow (D-10 — drop/clamp + adjusted flag)', () {
    // New, shorter window: 08:10–08:50.
    final newStart = tripStart.add(const Duration(minutes: 10));
    final newEnd = tripStart.add(const Duration(minutes: 50));

    test('break fully before newStart → dropped, adjusted', () {
      final result = TripEditRecompute.clampToWindow(
        newStart: newStart,
        newEnd: newEnd,
        breaks: [seg(0, 5)],
      );
      expect(result.breaks, isEmpty);
      expect(result.adjusted, isTrue);
    });

    test('break fully after newEnd → dropped, adjusted', () {
      final result = TripEditRecompute.clampToWindow(
        newStart: newStart,
        newEnd: newEnd,
        breaks: [seg(52, 58)],
      );
      expect(result.breaks, isEmpty);
      expect(result.adjusted, isTrue);
    });

    test('break straddling newStart → clamped start, adjusted', () {
      final result = TripEditRecompute.clampToWindow(
        newStart: newStart,
        newEnd: newEnd,
        breaks: [seg(5, 20)],
      );
      expect(result.breaks, hasLength(1));
      expect(result.breaks.single.start.isAtSameMomentAs(newStart), isTrue);
      expect(result.breaks.single.end.isAtSameMomentAs(seg(5, 20).end), isTrue);
      expect(result.adjusted, isTrue);
    });

    test('break straddling newEnd → clamped end, adjusted', () {
      final result = TripEditRecompute.clampToWindow(
        newStart: newStart,
        newEnd: newEnd,
        breaks: [seg(40, 58)],
      );
      expect(result.breaks, hasLength(1));
      expect(
        result.breaks.single.start.isAtSameMomentAs(seg(40, 58).start),
        isTrue,
      );
      expect(result.breaks.single.end.isAtSameMomentAs(newEnd), isTrue);
      expect(result.adjusted, isTrue);
    });

    test('break fully inside → unchanged, not adjusted', () {
      final result = TripEditRecompute.clampToWindow(
        newStart: newStart,
        newEnd: newEnd,
        breaks: [seg(20, 30)],
      );
      expect(result.breaks, hasLength(1));
      expect(
        result.breaks.single.start.isAtSameMomentAs(seg(20, 30).start),
        isTrue,
      );
      expect(
        result.breaks.single.end.isAtSameMomentAs(seg(20, 30).end),
        isTrue,
      );
      expect(result.adjusted, isFalse);
    });

    test('clamp collapsing to start >= end → dropped', () {
      // Break 08:08–08:10 clamped to newStart 08:10 → start==end → drop.
      final result = TripEditRecompute.clampToWindow(
        newStart: newStart,
        newEnd: newEnd,
        breaks: [seg(8, 10)],
      );
      expect(result.breaks, isEmpty);
      expect(result.adjusted, isTrue);
    });

    test('empty breaks → empty, not adjusted', () {
      final result = TripEditRecompute.clampToWindow(
        newStart: newStart,
        newEnd: newEnd,
        breaks: const [],
      );
      expect(result.breaks, isEmpty);
      expect(result.adjusted, isFalse);
    });

    test('does not mutate the input list', () {
      final input = [seg(5, 20)];
      TripEditRecompute.clampToWindow(
        newStart: newStart,
        newEnd: newEnd,
        breaks: input,
      );
      expect(input.single.start.isAtSameMomentAs(seg(5, 20).start), isTrue);
    });
  });
}
