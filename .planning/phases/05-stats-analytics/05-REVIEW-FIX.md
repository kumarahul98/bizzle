---
phase: 05-stats-analytics
fixed_at: 2026-04-26T00:00:00Z
review_path: .planning/phases/05-stats-analytics/05-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 05: Code Review Fix Report

**Fixed at:** 2026-04-26T00:00:00Z
**Source review:** .planning/phases/05-stats-analytics/05-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (WR-01, WR-02, WR-03, WR-04 — Critical/Warning only)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01: BestWorstDayCard tie-breaking is asymmetric

**Files modified:** `lib/features/stats/widgets/best_worst_day_card.dart`
**Commit:** 451f0ea
**Applied fix:** Added a guard block immediately after the scan loop: when `bestIdx != null && worstIdx != null && bestAvg == worstAvg`, `worstIdx` is set to `null`. This prevents two different weekday chips from being simultaneously labelled best and worst when all non-null weekdays share the same average duration.

### WR-02: BestWorstDayCard does not guard against weekdayAverages length < 5

**Files modified:** `lib/features/stats/widgets/best_worst_day_card.dart`
**Commit:** 451f0ea
**Applied fix:** Added `assert(weekdayAverages.length >= 5, 'weekdayAverages must have at least 5 entries (Mon–Fri)')` in the `const` constructor initializer list. Enforces the Mon–Fri index contract at debug time without changing release behaviour. Both WR-01 and WR-02 landed in a single atomic commit since they touch the same file.

### WR-03: TrendChartCard BarAreaData() produces unintentional transparent fill

**Files modified:** `lib/features/stats/widgets/trend_chart_card.dart`
**Commit:** b3f907a
**Applied fix:** Changed `belowBarData: BarAreaData()` to `belowBarData: BarAreaData(show: false)` at line 114. The explicit `show: false` makes intent clear and is version-stable regardless of whether the resolved fl_chart build defaults `show` to `true` or `false`.

### WR-04: stats_screen_test.dart weekly-duration test flaps at week boundary

**Files modified:** `test/widget/features/stats/stats_screen_test.dart`
**Commit:** d39f1a4
**Applied fix:** Replaced `DateTime.now()` trip factory with a date pinned to the current Monday at 08:00 (`now.subtract(Duration(days: now.weekday - DateTime.monday))`). The trip is always inside the current Mon–Sun window. Strengthened the assertion to also verify `kStatsEmptyPlaceholder` is absent, confirming the trip was counted rather than only checking the helper label renders.

---

_Fixed: 2026-04-26T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
