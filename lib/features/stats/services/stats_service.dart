import 'package:flutter/foundation.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';

/// Immutable summary of every Phase 5 stat, computed from the full
/// list of [TripSummary] records by [computeStatsSummary] in a single
/// pass.
///
/// All duration fields are in seconds. Average fields are nullable
/// (`int?`) — `null` signals "no qualifying trips for this slot" and
/// must be rendered as `kStatsEmptyPlaceholder` (D-10).
@immutable
class StatsSummary {
  /// Construct an immutable [StatsSummary]. Every aggregate field is
  /// required so the value object cannot be partially populated.
  const StatsSummary({
    required this.weekTotalSeconds,
    required this.monthTotalSeconds,
    required this.toOfficeAvgSeconds,
    required this.toHomeAvgSeconds,
    required this.weekdayAverages,
    required this.dailyTotalsLast28Days,
    required this.weekStuckSeconds,
    required this.hasAnyTrips,
  });

  /// Total commute seconds for the current Mon–Sun calendar week (D-03,
  /// STAT-01). Manual entries included (D-05).
  final int weekTotalSeconds;

  /// Total commute seconds for the current calendar month (D-04, STAT-01).
  /// Manual entries included (D-05).
  final int monthTotalSeconds;

  /// Average duration in seconds for trips with `direction ==
  /// kDirectionToOffice` across all time. `null` when no such trips
  /// exist (STAT-02, D-10).
  final int? toOfficeAvgSeconds;

  /// Average duration in seconds for trips with `direction ==
  /// kDirectionToHome` across all time. `null` when no such trips
  /// exist (STAT-02, D-10).
  final int? toHomeAvgSeconds;

  /// Average commute duration per weekday, indexed by
  /// `DateTime.weekday - 1` (0 = Mon … 4 = Fri). Indices 5 (Sat) and
  /// 6 (Sun) are always `null` per D-09. Other indices are `null`
  /// when no qualifying trips exist for that weekday.
  final List<int?> weekdayAverages;

  /// 28 entries of total seconds per calendar day. Index 0 is today;
  /// index 27 is 27 days ago. Days outside the window are not in the
  /// list (STAT-04, D-07).
  final List<int> dailyTotalsLast28Days;

  /// Sum of `timeStuckSeconds` for the current week, restricted to
  /// non-manual trips (D-05, STAT-05).
  final int weekStuckSeconds;

  /// `true` when the `trips` list passed to [computeStatsSummary] was
  /// non-empty. Drives the screen-level empty branch behaviour (D-10
  /// still keeps cards rendered so this flag is informational only).
  final bool hasAnyTrips;
}

/// Number of whole calendar days from [earlier] to [later], where both
/// arguments are local-time midnights (constructed via `DateTime(y, m, d)`).
///
/// Constructs UTC anchors so the diff is independent of DST: a local
/// "day" can be 23 or 25 hours of wall-clock time during a DST
/// transition, which would corrupt `Duration.inDays`. Anchoring both
/// endpoints to `DateTime.utc(y, m, d)` makes every day exactly 24h.
int _daysBetweenLocalMidnights(DateTime later, DateTime earlier) {
  final laterUtc = DateTime.utc(later.year, later.month, later.day);
  final earlierUtc = DateTime.utc(earlier.year, earlier.month, earlier.day);
  return laterUtc.difference(earlierUtc).inDays;
}

/// Compute every Phase 5 stat in a single O(n) pass over [trips].
///
/// [now] is injected so tests can pin a fixed instant. Production
/// callers pass `DateTime.now()` from inside the provider's `whenData`
/// (Plan 02 / Pattern 1 in 05-RESEARCH.md).
///
/// All UTC `TripSummary.startTime` values are converted via `toLocal()`
/// before any date math (Pitfall 1 mitigation). Calendar-day diffs use
/// a local-midnight UTC anchor helper (Pitfall 4 mitigation).
StatsSummary computeStatsSummary(List<TripSummary> trips, DateTime now) {
  // ---- Period anchors (D-03 Mon–Sun, D-04 calendar month) ----
  final localNow = now.toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final daysSinceMonday = today.weekday - DateTime.monday; // 0..6
  final weekStart = today.subtract(Duration(days: daysSinceMonday));
  final weekEnd = weekStart.add(const Duration(days: 7));
  final monthStart = DateTime(localNow.year, localNow.month);
  final monthEnd = DateTime(localNow.year, localNow.month + 1);

  // ---- Accumulators (single pass populates all of these) ----
  var weekTotalSeconds = 0;
  var monthTotalSeconds = 0;
  var weekStuckSeconds = 0;
  final dirTotals = <String, int>{
    kDirectionToOffice: 0,
    kDirectionToHome: 0,
  };
  final dirCounts = <String, int>{
    kDirectionToOffice: 0,
    kDirectionToHome: 0,
  };
  final weekdayTotals = List<int>.filled(7, 0); // index = weekday - 1
  final weekdayCounts = List<int>.filled(7, 0);
  final dailyTotalsLast28 = List<int>.filled(
    kStatsTrendWindowDays,
    0,
  ); // index 0 = today

  // ---- Single pass ----
  for (final trip in trips) {
    final local = trip.startTime.toLocal();
    final dateOnly = DateTime(local.year, local.month, local.day);

    // Week (D-03) — STAT-01 weekly + STAT-05 traffic waste accumulators.
    if (!local.isBefore(weekStart) && local.isBefore(weekEnd)) {
      weekTotalSeconds += trip.durationSeconds;
      // D-05 (refined): exclude manual trips from traffic waste ONLY when
      // the user left both traffic and distance fields blank (both zero).
      // Manual trips where the user entered traffic or distance data are
      // included so their real-world commute time registers in the stats.
      final isBlankManualEntry =
          trip.isManualEntry &&
          trip.timeStuckSeconds == 0 &&
          trip.distanceMeters == 0;
      if (!isBlankManualEntry) {
        weekStuckSeconds += trip.timeStuckSeconds;
      }
    }

    // Month (D-04) — STAT-01 monthly accumulator.
    if (!local.isBefore(monthStart) && local.isBefore(monthEnd)) {
      monthTotalSeconds += trip.durationSeconds;
    }

    // Direction (STAT-02) — all trips, all time.
    if (dirTotals.containsKey(trip.direction)) {
      dirTotals[trip.direction] =
          dirTotals[trip.direction]! + trip.durationSeconds;
      dirCounts[trip.direction] = dirCounts[trip.direction]! + 1;
    }

    // Weekday (STAT-03, D-09) — Mon–Fri only; Sat/Sun never tallied.
    final weekday = local.weekday; // 1..7
    if (weekday >= DateTime.monday && weekday <= DateTime.friday) {
      weekdayTotals[weekday - 1] += trip.durationSeconds;
      weekdayCounts[weekday - 1] += 1;
    }

    // 28-day window (STAT-04, D-07) — Pitfall 4 mitigation via helper.
    final daysAgo = _daysBetweenLocalMidnights(today, dateOnly);
    if (daysAgo >= 0 && daysAgo < kStatsTrendWindowDays) {
      dailyTotalsLast28[daysAgo] += trip.durationSeconds;
    }
  }

  // ---- Build immutable result with zero-division guards (Pitfall 2). ----
  return StatsSummary(
    weekTotalSeconds: weekTotalSeconds,
    monthTotalSeconds: monthTotalSeconds,
    toOfficeAvgSeconds: dirCounts[kDirectionToOffice]! == 0
        ? null
        : dirTotals[kDirectionToOffice]! ~/ dirCounts[kDirectionToOffice]!,
    toHomeAvgSeconds: dirCounts[kDirectionToHome]! == 0
        ? null
        : dirTotals[kDirectionToHome]! ~/ dirCounts[kDirectionToHome]!,
    weekdayAverages: List<int?>.generate(
      7,
      (i) {
        if (i >= 5) return null; // Sat (5), Sun (6) per D-09
        if (weekdayCounts[i] == 0) return null;
        return weekdayTotals[i] ~/ weekdayCounts[i];
      },
    ),
    dailyTotalsLast28Days: dailyTotalsLast28,
    weekStuckSeconds: weekStuckSeconds,
    hasAnyTrips: trips.isNotEmpty,
  );
}
