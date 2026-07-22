// Phase 34 Wave 2 — multi-period aggregation unit tests.
//
// Encodes the four Q2 worked examples from 34-RESEARCH.md §2 VERBATIM,
// including the rendered strings, plus partial-period, empty-period, DST,
// the T-34-02 dashboard/stats week-agreement, the stuck-share population fix,
// and the Q6-overrule trend bucketing.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/stats/services/stats_period.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:uuid/uuid.dart';

/// Build a trip. Times are local `DateTime`s; the service converts via
/// `toLocal()`, which is a no-op for local instants, so the local calendar
/// date is preserved regardless of the test runner's timezone.
TripSummary _trip(
  DateTime start, {
  int seconds = 2700,
  int stuck = 0,
  double distance = 5000,
  bool manual = false,
  String direction = kDirectionToOffice,
}) {
  return TripSummary(
    id: const Uuid().v4(),
    startTime: start,
    endTime: start.add(Duration(seconds: seconds)),
    durationSeconds: seconds,
    distanceMeters: distance,
    direction: direction,
    timeMovingSeconds: seconds - stuck,
    timeStuckSeconds: stuck,
    isManualEntry: manual,
  );
}

/// Two trips (morning + evening), each `seconds` long, on a local date.
List<TripSummary> _commuteDay(DateTime date, {int seconds = 2700}) =>
    <TripSummary>[
      _trip(DateTime(date.year, date.month, date.day, 8), seconds: seconds),
      _trip(DateTime(date.year, date.month, date.day, 18), seconds: seconds),
    ];

void main() {
  setUpAll(() {
    Intl.defaultLocale = 'en_US';
  });

  group('Q2 worked examples (34-RESEARCH.md §2) — verbatim', () {
    // Fixed commute throughout: 2 trips/commuting day, 45 min each = 2700 s,
    // 5400 s (1h 30m) per commuting day.

    test('A — normal 5-day week: 1h 30m per commuting day, 5 days', () {
      final trips = <TripSummary>[];
      for (final d in <int>[20, 21, 22, 23, 24]) {
        trips.addAll(_commuteDay(DateTime(2026, 4, d)));
      }
      final r = computeStatsSummary(
        trips,
        DateTime(2026, 4, 26, 12), // Sunday, inside the Mon–Sun week
      );
      expect(r.periodCommutingDays, 5);
      expect(r.periodTotalSeconds, 27000);
      expect(r.periodAvgSecondsPerCommutingDay, 5400);
      expect(
        formatPerCommutingDay(r.periodAvgSecondsPerCommutingDay),
        '1h 30m per commuting day',
      );
      expect(formatCommutingDays(r.periodCommutingDays), '5 commuting days');
      // RnD total column shows '7h 30m'; the integer-minute formatter agrees.
      expect(formatDurationHm(r.periodTotalSeconds ~/ 60), '7h 30m');
    });

    test('B — same week, Wed off: average UNCHANGED, 4 days', () {
      final trips = <TripSummary>[];
      for (final d in <int>[20, 21, 23, 24]) {
        trips.addAll(_commuteDay(DateTime(2026, 4, d)));
      }
      final r = computeStatsSummary(
        trips,
        DateTime(2026, 4, 26, 12),
      );
      expect(r.periodCommutingDays, 4);
      expect(r.periodTotalSeconds, 21600);
      // The whole point of T-34-01: taking a day off does NOT move the average.
      expect(r.periodAvgSecondsPerCommutingDay, 5400);
      expect(
        formatPerCommutingDay(r.periodAvgSecondsPerCommutingDay),
        '1h 30m per commuting day',
      );
      expect(formatCommutingDays(r.periodCommutingDays), '4 commuting days');
      // Total DOES drop (6h) — the pair (average, total) tells both truths.
      expect(formatDurationHm(r.periodTotalSeconds ~/ 60), '6h');
    });

    test('C — two-week holiday inside June: average matches full June', () {
      // Holiday June: commute the first 12 weekdays only.
      final holiday = <TripSummary>[];
      var used = 0;
      for (var day = 1; day <= 30 && used < 12; day++) {
        final dt = DateTime(2026, 6, day);
        if (dt.weekday < DateTime.monday || dt.weekday > DateTime.friday) {
          continue;
        }
        holiday.addAll(_commuteDay(dt));
        used++;
      }
      final rHoliday = computeStatsSummary(
        holiday,
        DateTime(2026, 6, 30, 12),
        period: const MonthPeriod(),
      );
      expect(rHoliday.periodCommutingDays, 12);
      expect(rHoliday.periodTotalSeconds, 64800);
      expect(rHoliday.periodAvgSecondsPerCommutingDay, 5400);
      expect(
        formatPerCommutingDay(rHoliday.periodAvgSecondsPerCommutingDay),
        '1h 30m per commuting day',
      );
      expect(
        formatCommutingDays(rHoliday.periodCommutingDays),
        '12 commuting days',
      );

      // Full June: every weekday.
      final full = <TripSummary>[];
      for (var day = 1; day <= 30; day++) {
        final dt = DateTime(2026, 6, day);
        if (dt.weekday < DateTime.monday || dt.weekday > DateTime.friday) {
          continue;
        }
        full.addAll(_commuteDay(dt));
      }
      final rFull = computeStatsSummary(
        full,
        DateTime(2026, 6, 30, 12),
        period: const MonthPeriod(),
      );
      expect(rFull.periodCommutingDays, 22);
      expect(rFull.periodAvgSecondsPerCommutingDay, 5400);
      // The holiday awards ZERO improvement to the per-commuting-day figure.
      expect(
        rHoliday.periodAvgSecondsPerCommutingDay,
        rFull.periodAvgSecondsPerCommutingDay,
      );
    });

    test('D — July (public holiday) vs June: 22 days, identical average', () {
      // July 2026 has 23 weekdays; drop one for a public holiday → 22.
      final july = <TripSummary>[];
      var skipped = false;
      for (var day = 1; day <= 31; day++) {
        final dt = DateTime(2026, 7, day);
        if (dt.weekday < DateTime.monday || dt.weekday > DateTime.friday) {
          continue;
        }
        if (!skipped) {
          skipped = true; // one public holiday
          continue;
        }
        july.addAll(_commuteDay(dt));
      }
      final r = computeStatsSummary(
        july,
        DateTime(2026, 7, 31, 12),
        period: const MonthPeriod(),
      );
      expect(r.periodCommutingDays, 22);
      expect(r.periodTotalSeconds, 118800);
      expect(r.periodAvgSecondsPerCommutingDay, 5400);
      expect(
        formatPerCommutingDay(r.periodAvgSecondsPerCommutingDay),
        '1h 30m per commuting day',
      );
      expect(formatCommutingDays(r.periodCommutingDays), '22 commuting days');
    });
  });

  group('period labels', () {
    test('week → This week', () {
      final r = computeStatsSummary(
        const <TripSummary>[],
        DateTime(2026, 7, 22, 12),
      );
      expect(r.periodLabel, 'This week');
    });

    test('month → month name (July)', () {
      final r = computeStatsSummary(
        const <TripSummary>[],
        DateTime(2026, 7, 22, 12),
        period: const MonthPeriod(),
      );
      expect(r.periodLabel, 'July');
    });

    test('year → year number (2026)', () {
      final r = computeStatsSummary(
        const <TripSummary>[],
        DateTime(2026, 7, 22, 12),
        period: const YearPeriod(),
      );
      expect(r.periodLabel, '2026');
    });
  });

  group('partial period (D-01 Q4)', () {
    test('the current period is always in progress (· so far)', () {
      for (final p in <StatsPeriod>[
        const WeekPeriod(),
        const MonthPeriod(),
        const YearPeriod(),
      ]) {
        final r = computeStatsSummary(
          const <TripSummary>[],
          DateTime(2026, 4, 22, 12),
          period: p,
        );
        expect(r.isPeriodPartial, isTrue);
      }
    });
  });

  group('empty period', () {
    test('zero commuting days → null average, em-dash label', () {
      final r = computeStatsSummary(
        const <TripSummary>[],
        DateTime(2026, 4, 22, 12),
      );
      expect(r.periodCommutingDays, 0);
      expect(r.periodAvgSecondsPerCommutingDay, isNull);
      expect(r.periodStuckSharePercent, isNull);
      expect(formatPerCommutingDay(null), '— per commuting day');
      expect(formatCommutingDays(0), 'No commuting days');
    });

    test('singular day label', () {
      expect(formatCommutingDays(1), '1 commuting day');
    });
  });

  group('DST / date-only bucketing', () {
    test(
      'two trips on one local date (DST day) count as one commuting day',
      () {
        // 2026-03-29 is the EU spring-forward Sunday. The commuting-day set is
        // built from date-only locals, so it is DST-immune by construction.
        final r = computeStatsSummary(
          <TripSummary>[
            _trip(DateTime(2026, 3, 29, 1)),
            _trip(DateTime(2026, 3, 29, 23)),
          ],
          DateTime(2026, 3, 29, 23, 30),
        );
        expect(r.periodCommutingDays, 1);
      },
    );

    test(
      'a trip at 23:50 and one at 00:10 next day are two commuting days',
      () {
        final r = computeStatsSummary(
          <TripSummary>[
            _trip(DateTime(2026, 4, 20, 23, 50), seconds: 600),
            _trip(DateTime(2026, 4, 21, 0, 10), seconds: 600),
          ],
          DateTime(2026, 4, 22, 12),
        );
        expect(r.periodCommutingDays, 2);
      },
    );
  });

  group('T-34-02 dashboard / stats week agreement (D-03)', () {
    test('week accumulators do not move when the period is Month', () {
      final trips = <TripSummary>[
        _trip(DateTime(2026, 4, 20, 8), seconds: 1800, stuck: 300),
        _trip(DateTime(2026, 4, 21, 8), seconds: 1200, stuck: 200),
        // Earlier in the month but outside the current week — must not be in
        // the week accumulators.
        _trip(DateTime(2026, 4, 6, 8), seconds: 9000, stuck: 5000),
      ];
      final now = DateTime(2026, 4, 22, 12);
      final weekView = computeStatsSummary(trips, now);
      final monthView = computeStatsSummary(
        trips,
        now,
        period: const MonthPeriod(),
      );
      // The dashboard reads weekTotalSeconds/weekStuckSeconds; identical across
      // period selections.
      expect(weekView.weekTotalSeconds, monthView.weekTotalSeconds);
      expect(weekView.weekStuckSeconds, monthView.weekStuckSeconds);
      expect(weekView.weekTotalSeconds, 3000);
      expect(weekView.weekStuckSeconds, 500);
      // In Week period the period totals equal the dashboard week accumulators.
      expect(weekView.periodTotalSeconds, weekView.weekTotalSeconds);
      expect(weekView.periodStuckSeconds, weekView.weekStuckSeconds);
      // Month total includes the earlier trip; dashboard week does not.
      expect(monthView.periodTotalSeconds, 12000);
    });
  });

  group('stuck-share population fix (D-01 additional finding)', () {
    test('a blank hand-entry trip does not distort the stuck share', () {
      final gps = _trip(
        DateTime(2026, 4, 20, 8),
        seconds: 1000,
        stuck: 400,
      );
      final blankManual = _trip(
        DateTime(2026, 4, 20, 10),
        seconds: 2000,
        distance: 0,
        manual: true,
      );
      final now = DateTime(2026, 4, 22, 12);
      final without = computeStatsSummary(
        <TripSummary>[gps],
        now,
      );
      final with_ = computeStatsSummary(
        <TripSummary>[gps, blankManual],
        now,
      );
      // Numerator and denominator both exclude the blank manual, so the share
      // is unchanged.
      expect(with_.periodStuckSharePercent, without.periodStuckSharePercent);
      expect(with_.periodStuckSeconds, without.periodStuckSeconds);
      expect(with_.periodMovingSeconds, without.periodMovingSeconds);
      // 400 stuck / 1000 non-blank total = 40 %.
      expect(without.periodStuckSharePercent, 40);
      // The headline total DOES include the blank manual (all trips).
      expect(with_.periodTotalSeconds, without.periodTotalSeconds + 2000);
    });

    test('empty non-blank population → null share', () {
      final blankManual = _trip(
        DateTime(2026, 4, 20, 10),
        seconds: 2000,
        distance: 0,
        manual: true,
      );
      final r = computeStatsSummary(
        <TripSummary>[blankManual],
        DateTime(2026, 4, 22, 12),
      );
      expect(r.periodStuckSharePercent, isNull);
      // But the trip still counts toward the headline total and commuting days.
      expect(r.periodTotalSeconds, 2000);
      expect(r.periodCommutingDays, 1);
    });
  });

  group('period trend bucketing (Q6 overrule)', () {
    test('week → 7 daily bars, labelled Mon…Sun', () {
      final r = computeStatsSummary(
        <TripSummary>[_trip(DateTime(2026, 4, 22, 8), seconds: 1200)],
        DateTime(2026, 4, 22, 12),
      );
      expect(r.periodTrendBars.length, 7);
      expect(r.periodTrendBars.first.label, 'Mon');
      expect(r.periodTrendBars.last.label, 'Sun');
      // Wednesday 2026-04-22 → index 2; today, so highlighted.
      expect(r.periodTrendBars[2].seconds, 1200);
      expect(r.periodTrendBars[2].isCurrent, isTrue);
    });

    test('month → one bar per calendar week touching the month', () {
      // April 2026: Apr 1 is Wednesday → weeks Mar30, Apr6, Apr13, Apr20,
      // Apr27 = 5 buckets.
      final r = computeStatsSummary(
        const <TripSummary>[],
        DateTime(2026, 4, 15, 12),
        period: const MonthPeriod(),
      );
      expect(r.periodTrendBars.length, 5);
      expect(r.periodTrendBars.first.label, 'W1');
      expect(r.periodTrendBars.last.label, 'W5');
    });

    test('year → 12 monthly bars, trip lands in its month', () {
      final r = computeStatsSummary(
        <TripSummary>[_trip(DateTime(2026, 4, 22, 8), seconds: 1200)],
        DateTime(2026, 12, 15, 12),
        period: const YearPeriod(),
      );
      expect(r.periodTrendBars.length, 12);
      expect(r.periodTrendBars.first.label, 'Jan');
      // April = index 3.
      expect(r.periodTrendBars[3].seconds, 1200);
      // December is the current month.
      expect(r.periodTrendBars[11].isCurrent, isTrue);
      expect(r.periodTrendBars[3].isCurrent, isFalse);
    });
  });
}
