/// The calendar period the Stats screen is currently showing (Phase 34).
///
/// Sealed so the finite set (week / month / year) is exhaustive at every
/// `switch` — CLAUDE.md forbids raw strings for finite state. All three are
/// the *current* period anchored to `now`; there is no navigation to past
/// periods, so a shown period is always in progress.
sealed class StatsPeriod {
  /// Const base constructor so the concrete periods can be `const`.
  const StatsPeriod();
}

/// The current Mon–Sun calendar week (D-03 boundary, unchanged from Phase 5).
class WeekPeriod extends StatsPeriod {
  /// Construct the week period.
  const WeekPeriod();
}

/// The current 1st-to-last-day calendar month.
class MonthPeriod extends StatsPeriod {
  /// Construct the month period.
  const MonthPeriod();
}

/// The current Jan–Dec calendar year.
class YearPeriod extends StatsPeriod {
  /// Construct the year period.
  const YearPeriod();
}
