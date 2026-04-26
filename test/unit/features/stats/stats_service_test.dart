// Unit tests for computeStatsSummary (STAT-01..05).
//
// Pure-data tests: no Drift, no widget, no Riverpod. The function
// under test is `lib/features/stats/services/stats_service.dart`.
// Plan 05-02 (Wave 1) replaces the UnimplementedError stub with the
// real single-pass implementation; until then every test here is RED.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:uuid/uuid.dart';

TripSummary _trip({
  required DateTime startTime,
  int durationSeconds = 1800,
  String direction = kDirectionToOffice,
  int timeStuckSeconds = 0,
  bool isManualEntry = false,
}) {
  return TripSummary(
    id: const Uuid().v4(),
    startTime: startTime,
    endTime: startTime.add(Duration(seconds: durationSeconds)),
    durationSeconds: durationSeconds,
    distanceMeters: 0,
    direction: direction,
    timeMovingSeconds: durationSeconds - timeStuckSeconds,
    timeStuckSeconds: timeStuckSeconds,
    isManualEntry: isManualEntry,
  );
}

void main() {
  setUpAll(() {
    // Pitfall 7: pin locale so DateFormat.E() outputs are deterministic
    // even though stats_service does not call DateFormat directly. Pinning
    // here keeps the suite runnable on non-en CI runners and matches the
    // widget test setup in Plan 05.
    Intl.defaultLocale = 'en_US';
  });

  group('computeStatsSummary - empty input (D-10)', () {
    test('empty trips list returns hasAnyTrips=false and zero/null fields', () {
      final result = computeStatsSummary(
        const <TripSummary>[],
        DateTime(2026, 4, 26, 12), // Sunday noon local
      );
      expect(result.hasAnyTrips, isFalse);
      expect(result.weekTotalSeconds, 0);
      expect(result.monthTotalSeconds, 0);
      expect(result.toOfficeAvgSeconds, isNull);
      expect(result.toHomeAvgSeconds, isNull);
      expect(result.weekStuckSeconds, 0);
      expect(result.dailyTotalsLast28Days.length, 28);
      expect(result.dailyTotalsLast28Days.every((v) => v == 0), isTrue);
      expect(result.weekdayAverages.length, 7);
      expect(result.weekdayAverages.every((v) => v == null), isTrue);
    });
  });

  group('STAT-01 weekly + monthly totals (D-03, D-04)', () {
    test('sums durations only for trips inside Mon–Sun current week', () {
      // Wednesday 2026-04-22 12:00 local = inside the 2026-04-20..04-26 week.
      final inWeek = _trip(
        startTime: DateTime(2026, 4, 22, 8).toUtc(),
        durationSeconds: 1500,
      );
      // Sunday 2026-04-19 22:00 local = previous week, must be excluded
      // from week total.
      final outOfWeek = _trip(
        startTime: DateTime(2026, 4, 19, 22).toUtc(),
        durationSeconds: 9999,
      );
      final result = computeStatsSummary(
        <TripSummary>[inWeek, outOfWeek],
        DateTime(2026, 4, 22, 18), // Wednesday evening local
      );
      expect(result.weekTotalSeconds, 1500);
    });

    test('sums durations for every trip inside the calendar month', () {
      // April 1 + April 30 + May 1: only the first two count for April.
      final apr1 = _trip(
        startTime: DateTime(2026, 4, 1, 8).toUtc(),
        durationSeconds: 600,
      );
      final apr30 = _trip(
        startTime: DateTime(2026, 4, 30, 8).toUtc(),
        durationSeconds: 1200,
      );
      final may1 = _trip(
        startTime: DateTime(2026, 5, 1, 8).toUtc(),
        durationSeconds: 9000,
      );
      final result = computeStatsSummary(
        <TripSummary>[apr1, apr30, may1],
        DateTime(2026, 4, 30, 23), // April 30 local
      );
      expect(result.monthTotalSeconds, 1800);
    });

    test('manual entries are included in week + month totals (D-05)', () {
      final manual = _trip(
        startTime: DateTime(2026, 4, 22, 8).toUtc(),
        durationSeconds: 1200,
        isManualEntry: true,
      );
      final gps = _trip(
        startTime: DateTime(2026, 4, 22, 18).toUtc(),
        durationSeconds: 600,
      );
      final result = computeStatsSummary(
        <TripSummary>[manual, gps],
        DateTime(2026, 4, 22, 20),
      );
      expect(result.weekTotalSeconds, 1800);
      expect(result.monthTotalSeconds, 1800);
    });
  });

  group('STAT-02 direction averages (D-10)', () {
    test('averages each direction independently', () {
      final office1 = _trip(
        startTime: DateTime(2026, 4, 1, 8).toUtc(),
        durationSeconds: 1200,
      );
      final office2 = _trip(
        startTime: DateTime(2026, 4, 2, 8).toUtc(),
      );
      final home = _trip(
        startTime: DateTime(2026, 4, 1, 18).toUtc(),
        durationSeconds: 600,
        direction: kDirectionToHome,
      );
      final result = computeStatsSummary(
        <TripSummary>[office1, office2, home],
        DateTime(2026, 4, 26, 12),
      );
      expect(result.toOfficeAvgSeconds, 1500); // (1200 + 1800) / 2
      expect(result.toHomeAvgSeconds, 600);
    });

    test('returns null for direction with zero trips', () {
      final office = _trip(
        startTime: DateTime(2026, 4, 22, 8).toUtc(),
      );
      final result = computeStatsSummary(
        <TripSummary>[office],
        DateTime(2026, 4, 26, 12),
      );
      expect(result.toOfficeAvgSeconds, isNotNull);
      expect(result.toHomeAvgSeconds, isNull);
    });
  });

  group('STAT-03 weekday averages (D-09)', () {
    test('Mon–Fri populated, Sat/Sun always null', () {
      // Two trips on a Monday (2026-04-20) with durations 600 and 1200.
      final mon1 = _trip(
        startTime: DateTime(2026, 4, 20, 8).toUtc(),
        durationSeconds: 600,
      );
      final mon2 = _trip(
        startTime: DateTime(2026, 4, 20, 18).toUtc(),
        durationSeconds: 1200,
      );
      // One Saturday trip (2026-04-25) — must be ignored.
      final sat = _trip(
        startTime: DateTime(2026, 4, 25, 12).toUtc(),
        durationSeconds: 9999,
      );
      final result = computeStatsSummary(
        <TripSummary>[mon1, mon2, sat],
        DateTime(2026, 4, 26, 12),
      );
      // Index 0 = Monday (DateTime.monday - 1 == 0).
      expect(result.weekdayAverages[0], 900);
      // Saturday (index 5) and Sunday (index 6) MUST be null.
      expect(result.weekdayAverages[5], isNull);
      expect(result.weekdayAverages[6], isNull);
    });
  });

  group('STAT-04 28-day trend (D-07)', () {
    test('dailyTotalsLast28Days has length 28 with index 0 == today total', () {
      final todayTrip = _trip(
        startTime: DateTime(2026, 4, 26, 8).toUtc(),
        durationSeconds: 1500,
      );
      final result = computeStatsSummary(
        <TripSummary>[todayTrip],
        DateTime(2026, 4, 26, 20),
      );
      expect(result.dailyTotalsLast28Days.length, 28);
      expect(result.dailyTotalsLast28Days[0], 1500);
    });

    test('trips outside the 28-day window are excluded', () {
      // 30 days before "now" — must be dropped.
      final tooOld = _trip(
        startTime: DateTime(2026, 3, 27, 8).toUtc(),
        durationSeconds: 9000,
      );
      final result = computeStatsSummary(
        <TripSummary>[tooOld],
        DateTime(2026, 4, 26, 12),
      );
      expect(result.dailyTotalsLast28Days.every((v) => v == 0), isTrue);
    });
  });

  group('STAT-05 weekly traffic waste (D-05)', () {
    test('excludes manual entries from weekStuckSeconds', () {
      final monday = DateTime(2026, 4, 20, 8); // Monday 8am local
      final manual = _trip(
        startTime: monday.toUtc(),
        timeStuckSeconds: 600,
        isManualEntry: true,
      );
      final gps = _trip(
        startTime: monday.toUtc(),
        timeStuckSeconds: 600,
      );
      final result = computeStatsSummary(
        <TripSummary>[manual, gps],
        DateTime(2026, 4, 22, 12), // Wednesday — same week
      );
      // STAT-01 sees both trips, STAT-05 sees only the GPS one.
      expect(
        result.weekTotalSeconds,
        manual.durationSeconds + gps.durationSeconds,
      );
      expect(result.weekStuckSeconds, 600);
    });

    test('only counts stuck seconds inside the current week', () {
      // Last Monday (previous week) — must NOT contribute to weekStuck.
      final lastWeek = _trip(
        startTime: DateTime(2026, 4, 13, 8).toUtc(),
        timeStuckSeconds: 5000,
      );
      final thisWeek = _trip(
        startTime: DateTime(2026, 4, 20, 8).toUtc(),
        timeStuckSeconds: 700,
      );
      final result = computeStatsSummary(
        <TripSummary>[lastWeek, thisWeek],
        DateTime(2026, 4, 22, 12),
      );
      expect(result.weekStuckSeconds, 700);
    });
  });

  group('Pitfall 1 (timezone): UTC startTime bucketed by local date', () {
    test('local-date bucketing across UTC midnight boundary', () {
      // Pin "now" to a date well inside April 2026.
      final now = DateTime(2026, 4, 22, 12);
      // A trip whose UTC startTime is 2026-04-22 02:00Z corresponds to
      // a different local calendar date in many timezones (e.g. UTC-8
      // -> 2026-04-21 18:00 local). The bucketing logic must use
      // local-date math so the trip lands in the local-day index, not
      // the UTC-day index. We assert hasAnyTrips and a non-zero
      // dailyTotalsLast28Days entry to keep the test TZ-agnostic.
      final trip = _trip(
        startTime: DateTime.utc(2026, 4, 22, 2),
        durationSeconds: 1200,
      );
      final result = computeStatsSummary(<TripSummary>[trip], now);
      expect(result.hasAnyTrips, isTrue);
      // Some index 0..27 must equal 1200; we don't assume which because
      // the test runner timezone is not pinned. The implementation
      // contract is "bucket by local day".
      expect(
        result.dailyTotalsLast28Days.where((v) => v == 1200).length,
        1,
        reason: 'Trip must land in exactly one local-day bucket',
      );
    });
  });

  group('Pitfall 4 (DST): 28-day diff uses local-midnight UTC anchor', () {
    test('a trip 27 calendar days before now lands at index 27', () {
      // March 30 -> April 26 = 27 calendar days. Even across a DST
      // boundary in late March (EU DST ends 2026-03-29) the
      // implementation must place this trip at index 27.
      final old = _trip(
        startTime: DateTime(2026, 3, 30, 12).toUtc(),
        durationSeconds: 600,
      );
      final result = computeStatsSummary(
        <TripSummary>[old],
        DateTime(2026, 4, 26, 12),
      );
      expect(result.dailyTotalsLast28Days[27], 600);
    });
  });
}
