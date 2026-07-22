import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/stats/services/stats_period.dart';

/// A single bar of the period-aware trend chart (Phase 34, Q6 overrule).
///
/// The bucketing differs per [StatsPeriod]: one bar per weekday of the week,
/// per calendar week of the month, or per month of the year. Each bar carries
/// its own axis [label] and whether it is the bucket containing today
/// ([isCurrent]) so the card can highlight it without re-deriving `now`.
@immutable
class StatsTrendBar {
  /// Construct a trend bar.
  const StatsTrendBar({
    required this.seconds,
    required this.label,
    required this.isCurrent,
  });

  /// Total commute seconds falling in this bucket.
  final int seconds;

  /// Axis label for this bucket (e.g. 'Mon', 'W1', 'Jan').
  final String label;

  /// `true` when this bucket contains today.
  final bool isCurrent;
}

/// Immutable summary of every stat rendered by the Stats screen, computed
/// from the full list of [TripSummary] records by [computeStatsSummary] in a
/// single pass.
///
/// All duration fields are in seconds. Average fields are nullable (`int?`) —
/// `null` signals "no qualifying trips for this slot" and must be rendered as
/// `kStatsEmptyPlaceholder`.
///
/// Phase 34 adds the selected-period aggregates (fields prefixed `period…`).
/// The `week…` accumulators are kept SEPARATE and always describe the current
/// Mon–Sun week regardless of the selected period, because the dashboard
/// week-loss card reads them and must not move when the stats screen's period
/// changes (D-03).
@immutable
class StatsSummary {
  /// Construct an immutable [StatsSummary]. Every aggregate field is required
  /// so the value object cannot be partially populated.
  const StatsSummary({
    required this.weekTotalSeconds,
    required this.weekStuckSeconds,
    required this.period,
    required this.periodLabel,
    required this.isPeriodPartial,
    required this.periodTotalSeconds,
    required this.periodStuckSeconds,
    required this.periodMovingSeconds,
    required this.periodStuckSharePercent,
    required this.periodCommutingDays,
    required this.periodAvgSecondsPerCommutingDay,
    required this.periodTrendBars,
    required this.toOfficeAvgSeconds,
    required this.toHomeAvgSeconds,
    required this.weekdayAverages,
    required this.dailyTotalsLast28Days,
    required this.hasAnyTrips,
  });

  /// Total commute seconds for the current Mon–Sun calendar week (D-03).
  /// Manual entries included (D-05). Period-independent — the dashboard reads
  /// this regardless of the stats screen's selected period.
  final int weekTotalSeconds;

  /// Sum of `timeStuckSeconds` for the current week, restricted to
  /// non-blank-manual trips (D-05). Period-independent (dashboard, D-03).
  final int weekStuckSeconds;

  /// The period this summary was computed for.
  final StatsPeriod period;

  /// Human label for the period: 'This week', 'July', '2026'.
  final String periodLabel;

  /// `true` while the current period has not yet reached its end anchor.
  /// The shown period is always the current one, so this is effectively
  /// always `true` — it drives the '· so far' marker (D-01 Q4).
  final bool isPeriodPartial;

  /// Total commute seconds inside the selected period (all trips, D-05).
  /// This is the DonutCard centre / headline total (D-02 rename of the old
  /// `monthTotalSeconds`).
  final int periodTotalSeconds;

  /// Stuck seconds inside the period over the non-blank-manual population.
  final int periodStuckSeconds;

  /// Moving seconds inside the period over the non-blank-manual population
  /// (`nonBlankTotal - stuck`). Kept matched to [periodStuckSeconds] so the
  /// donut wedges and the stuck share are drawn from one population.
  final int periodMovingSeconds;

  /// Stuck share as a rounded percentage over the non-blank-manual population
  /// (`stuck ÷ (moving + stuck)`). `null` when that population is empty. The
  /// numerator and denominator are the SAME population so a blank hand entry
  /// cannot distort it (D-01 additional finding).
  final int? periodStuckSharePercent;

  /// Number of distinct local calendar dates in the period that hold at least
  /// one trip — the "commuting days" denominator (D-01 Q2).
  final int periodCommutingDays;

  /// Per-commuting-day average: `periodTotalSeconds ÷ periodCommutingDays`.
  /// `null` when there are no commuting days (empty period).
  final int? periodAvgSecondsPerCommutingDay;

  /// Trend bars for the selected period, bucketed by day/week/month.
  final List<StatsTrendBar> periodTrendBars;

  /// Average duration in seconds for `direction == kDirectionToOffice` across
  /// all time. `null` when no such trips exist (STAT-02).
  final int? toOfficeAvgSeconds;

  /// Average duration in seconds for `direction == kDirectionToHome` across
  /// all time. `null` when no such trips exist (STAT-02).
  final int? toHomeAvgSeconds;

  /// Average commute duration per weekday, indexed by `weekday - 1`
  /// (0 = Mon … 4 = Fri). Indices 5 (Sat) and 6 (Sun) are always `null`
  /// (D-09). All-time — NOT period-aware.
  final List<int?> weekdayAverages;

  /// 28 entries of total seconds per calendar day. Index 0 is today; index 27
  /// is 27 days ago (STAT-04, D-07). Fixed 28-day window — NOT period-aware.
  final List<int> dailyTotalsLast28Days;

  /// `true` when the `trips` list passed to [computeStatsSummary] was
  /// non-empty.
  final bool hasAnyTrips;
}

/// Number of whole calendar days from [earlier] to [later], where both
/// arguments are local-time midnights (constructed via `DateTime(y, m, d)`).
///
/// Constructs UTC anchors so the diff is independent of DST: a local "day"
/// can be 23 or 25 hours during a DST transition, which would corrupt
/// `Duration.inDays`. Anchoring both endpoints to `DateTime.utc(y, m, d)`
/// makes every day exactly 24h.
int _daysBetweenLocalMidnights(DateTime later, DateTime earlier) {
  final laterUtc = DateTime.utc(later.year, later.month, later.day);
  final earlierUtc = DateTime.utc(earlier.year, earlier.month, earlier.day);
  return laterUtc.difference(earlierUtc).inDays;
}

/// The exact `'Xh Ym'` / `'Xm'` / `'0m'` duration label used across the stats
/// cards. Integer-minute formatter — drops a zero-minute tail (`'6h'`, not
/// `'6h 00m'`).
String formatDurationHm(int minutes) {
  if (minutes == 0) return '0m';
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// The exact per-commuting-day average label, e.g. `'1h 30m per commuting
/// day'`, or `'— per commuting day'` when [avgSeconds] is `null` (D-01 Q2).
String formatPerCommutingDay(int? avgSeconds) {
  final value = avgSeconds == null
      ? kStatsEmptyPlaceholder
      : formatDurationHm(avgSeconds ~/ 60);
  return '$value $kStatsPerCommutingDaySuffix';
}

/// The exact commuting-day count label: `'No commuting days'`,
/// `'1 commuting day'`, or `'N commuting days'` (D-01 Q2).
String formatCommutingDays(int count) {
  if (count == 0) return kStatsNoCommutingDays;
  if (count == 1) return '1 $kStatsCommutingDayWord';
  return '$count $kStatsCommutingDaysWord';
}

/// Compute every Stats-screen stat in a single O(n) pass over [trips].
///
/// [now] is injected so tests can pin a fixed instant. Production callers pass
/// `DateTime.now()` from inside the provider. [period] selects which calendar
/// period the `period…` aggregates describe; it defaults to [WeekPeriod] so
/// pre-Phase-34 callers keep the week behaviour.
///
/// All UTC `TripSummary.startTime` values are converted via `toLocal()` before
/// any date math. Calendar-day diffs use a local-midnight UTC anchor helper.
StatsSummary computeStatsSummary(
  List<TripSummary> trips,
  DateTime now, {
  StatsPeriod period = const WeekPeriod(),
}) {
  final localNow = now.toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);

  // ---- Calendar anchors (half-open [start, end)). ----
  final daysSinceMonday = today.weekday - DateTime.monday; // 0..6
  final weekStart = today.subtract(Duration(days: daysSinceMonday));
  final weekEnd = weekStart.add(const Duration(days: 7));
  final monthStart = DateTime(localNow.year, localNow.month);
  final monthEnd = DateTime(localNow.year, localNow.month + 1);
  final yearStart = DateTime(localNow.year);
  final yearEnd = DateTime(localNow.year + 1);

  // Monday of the first/last week touching the month, for weekly bucketing.
  final monthFirstWeekStart = monthStart.subtract(
    Duration(days: monthStart.weekday - DateTime.monday),
  );
  final monthLastDay = monthEnd.subtract(const Duration(days: 1));
  final monthLastWeekStart = monthLastDay.subtract(
    Duration(days: monthLastDay.weekday - DateTime.monday),
  );
  final monthWeekBucketCount =
      _daysBetweenLocalMidnights(monthLastWeekStart, monthFirstWeekStart) ~/ 7 +
      1;

  // ---- Resolve the selected period. ----
  final DateTime periodStart;
  final DateTime periodEnd;
  final String periodLabel;
  final int bucketCount;
  switch (period) {
    case WeekPeriod():
      periodStart = weekStart;
      periodEnd = weekEnd;
      periodLabel = kStatsCardWeekLabel; // 'This week'
      bucketCount = 7;
    case MonthPeriod():
      periodStart = monthStart;
      periodEnd = monthEnd;
      periodLabel = DateFormat(kStatsPeriodMonthPattern).format(localNow);
      bucketCount = monthWeekBucketCount;
    case YearPeriod():
      periodStart = yearStart;
      periodEnd = yearEnd;
      periodLabel = localNow.year.toString();
      bucketCount = 12;
  }
  final isPeriodPartial = localNow.isBefore(periodEnd);

  // Assign a local date to its trend bucket for the selected period.
  int bucketIndexFor(DateTime d) => switch (period) {
    WeekPeriod() => d.weekday - DateTime.monday,
    MonthPeriod() =>
      _daysBetweenLocalMidnights(
            d.subtract(Duration(days: d.weekday - DateTime.monday)),
            monthFirstWeekStart,
          ) ~/
          7,
    YearPeriod() => d.month - 1,
  };

  final trendBucketLabels = List<String>.generate(bucketCount, (i) {
    return switch (period) {
      WeekPeriod() => DateFormat(
        'EEE',
      ).format(weekStart.add(Duration(days: i))),
      MonthPeriod() => '$kStatsTrendWeekBucketPrefix${i + 1}',
      YearPeriod() => DateFormat('MMM').format(DateTime(localNow.year, i + 1)),
    };
  });
  final currentBucketIndex =
      (!today.isBefore(periodStart) && today.isBefore(periodEnd))
      ? bucketIndexFor(today)
      : -1;

  // ---- Accumulators (single pass populates all of these). ----
  var weekTotalSeconds = 0;
  var weekStuckSeconds = 0;
  var periodTotalSeconds = 0;
  var periodStuckSeconds = 0;
  var periodNonBlankTotalSeconds = 0;
  final commutingDays = <DateTime>{};
  final trendBucketSeconds = List<int>.filled(bucketCount, 0);
  final dirTotals = <String, int>{kDirectionToOffice: 0, kDirectionToHome: 0};
  final dirCounts = <String, int>{kDirectionToOffice: 0, kDirectionToHome: 0};
  final weekdayTotals = List<int>.filled(7, 0); // index = weekday - 1
  final weekdayCounts = List<int>.filled(7, 0);
  final dailyTotalsLast28 = List<int>.filled(kStatsTrendWindowDays, 0);

  // ---- Single pass ----
  for (final trip in trips) {
    final local = trip.startTime.toLocal();
    final dateOnly = DateTime(local.year, local.month, local.day);
    // D-05 (refined): a manual trip counts as "blank" only when the user left
    // both traffic and distance empty. Blank manuals are excluded from the
    // stuck population on BOTH the numerator and the denominator.
    final isBlankManualEntry =
        trip.isManualEntry &&
        trip.timeStuckSeconds == 0 &&
        trip.distanceMeters == 0;

    // Dashboard week accumulators — ALWAYS the current week (D-03).
    if (!local.isBefore(weekStart) && local.isBefore(weekEnd)) {
      weekTotalSeconds += trip.durationSeconds;
      if (!isBlankManualEntry) weekStuckSeconds += trip.timeStuckSeconds;
    }

    // Selected-period accumulators.
    if (!local.isBefore(periodStart) && local.isBefore(periodEnd)) {
      periodTotalSeconds += trip.durationSeconds;
      if (!isBlankManualEntry) {
        periodStuckSeconds += trip.timeStuckSeconds;
        periodNonBlankTotalSeconds += trip.durationSeconds;
      }
      commutingDays.add(dateOnly);
      trendBucketSeconds[bucketIndexFor(dateOnly)] += trip.durationSeconds;
    }

    // Direction (STAT-02) — all trips, all time.
    if (dirTotals.containsKey(trip.direction)) {
      dirTotals[trip.direction] =
          dirTotals[trip.direction]! + trip.durationSeconds;
      dirCounts[trip.direction] = dirCounts[trip.direction]! + 1;
    }

    // Weekday (STAT-03, D-09) — Mon–Fri only, all time.
    final weekday = local.weekday; // 1..7
    if (weekday >= DateTime.monday && weekday <= DateTime.friday) {
      weekdayTotals[weekday - 1] += trip.durationSeconds;
      weekdayCounts[weekday - 1] += 1;
    }

    // 28-day fixed window (STAT-04, D-07).
    final daysAgo = _daysBetweenLocalMidnights(today, dateOnly);
    if (daysAgo >= 0 && daysAgo < kStatsTrendWindowDays) {
      dailyTotalsLast28[daysAgo] += trip.durationSeconds;
    }
  }

  final commutingDayCount = commutingDays.length;
  final periodTrendBars = List<StatsTrendBar>.generate(
    bucketCount,
    (i) => StatsTrendBar(
      seconds: trendBucketSeconds[i],
      label: trendBucketLabels[i],
      isCurrent: i == currentBucketIndex,
    ),
  );

  return StatsSummary(
    weekTotalSeconds: weekTotalSeconds,
    weekStuckSeconds: weekStuckSeconds,
    period: period,
    periodLabel: periodLabel,
    isPeriodPartial: isPeriodPartial,
    periodTotalSeconds: periodTotalSeconds,
    periodStuckSeconds: periodStuckSeconds,
    periodMovingSeconds: periodNonBlankTotalSeconds - periodStuckSeconds,
    periodStuckSharePercent: periodNonBlankTotalSeconds == 0
        ? null
        : (periodStuckSeconds * 100 / periodNonBlankTotalSeconds).round(),
    periodCommutingDays: commutingDayCount,
    periodAvgSecondsPerCommutingDay: commutingDayCount == 0
        ? null
        : periodTotalSeconds ~/ commutingDayCount,
    periodTrendBars: periodTrendBars,
    toOfficeAvgSeconds: dirCounts[kDirectionToOffice]! == 0
        ? null
        : dirTotals[kDirectionToOffice]! ~/ dirCounts[kDirectionToOffice]!,
    toHomeAvgSeconds: dirCounts[kDirectionToHome]! == 0
        ? null
        : dirTotals[kDirectionToHome]! ~/ dirCounts[kDirectionToHome]!,
    weekdayAverages: List<int?>.generate(7, (i) {
      if (i >= 5) return null; // Sat (5), Sun (6) per D-09
      if (weekdayCounts[i] == 0) return null;
      return weekdayTotals[i] ~/ weekdayCounts[i];
    }),
    dailyTotalsLast28Days: dailyTotalsLast28,
    hasAnyTrips: trips.isNotEmpty,
  );
}
