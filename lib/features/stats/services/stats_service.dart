import 'package:flutter/foundation.dart';
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
  // Plan 01 (Wave 0): stub raises so the unit-test scaffold lands in a
  // RED state. Plan 02 replaces this body with the single-pass
  // implementation described in 05-RESEARCH.md §Pattern 4.
  throw UnimplementedError(
    'computeStatsSummary is implemented by Plan 05-02 (Wave 1).',
  );
}
