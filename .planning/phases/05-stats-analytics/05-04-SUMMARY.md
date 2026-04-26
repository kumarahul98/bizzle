---
phase: 05-stats-analytics
plan: "04"
subsystem: stats-ui-widgets
tags: [flutter, stats, ui, fl_chart, material3, accessibility]
dependency_graph:
  requires:
    - 05-02  # StatsSummary + statsSummaryProvider
  provides:
    - BestWorstDayCard  # STAT-03 weekday chips card
    - TrendChartCard    # STAT-04 fl_chart LineChart card
  affects:
    - 05-05  # Stats screen assembles these widgets
tech_stack:
  added: []
  patterns:
    - fl_chart 1.x LineChart with SideTitleWidget(meta: meta, child: ...) API
    - DateFormat.E('en_US') anchored to 2024-01-01 (known Monday) for locale-stable weekday labels
    - Semantics(container: true, label: ...) for chip a11y — colour never sole signal
key_files:
  created:
    - lib/features/stats/widgets/stats_card.dart
    - lib/features/stats/widgets/best_worst_day_card.dart
    - lib/features/stats/widgets/trend_chart_card.dart
  modified: []
decisions:
  - "Created stats_card.dart in Plan 04 worktree (Rule 3 deviation) — Plan 03 runs in parallel in a separate worktree; Plan 04 imports StatsCard so a compatible version was needed to compile"
  - "Removed _kLineWidth constant — fl_chart LineChartBarData default barWidth is 2.0, making the constant both redundant and flagged by very_good_analysis; defaulting is semantically identical"
  - "Dropped explicit isCurved: false, showTitles: false for top/right/left axes, and BarAreaData(show: false) — all are fl_chart defaults; very_good_analysis avoid_redundant_argument_values requires removal"
metrics:
  duration: "5 minutes"
  completed: "2026-04-26"
  tasks_completed: 2
  files_created: 3
---

# Phase 05 Plan 04: Best/Worst Day Card + Trend Chart Card Summary

BestWorstDayCard (STAT-03) with locale-anchored weekday chips and a11y semantics, and TrendChartCard (STAT-04) with fl_chart 1.x LineChart and 4 week midpoint labels.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create BestWorstDayCard with locale chips + a11y | 505d211 | stats_card.dart, best_worst_day_card.dart |
| 2 | Create TrendChartCard with fl_chart 1.x LineChart | 294dc33 | trend_chart_card.dart |

## Artifact Details

### lib/features/stats/widgets/best_worst_day_card.dart (136 lines)

- 5 chips Mon–Fri using `DateFormat.E('en_US').format(DateTime(2024, 1, 1 + i))` — locale pinned, anchor is a known Monday
- Best chip (lowest non-null average): `colorScheme.primaryContainer` / `colorScheme.onPrimaryContainer` + `Icons.trending_down_rounded`
- Worst chip (highest non-null average): `colorScheme.errorContainer` / `colorScheme.onErrorContainer` + `Icons.trending_up_rounded`
- All-null guard: all 5 chips render unstyled when `weekdayAverages` has no non-null entries
- Single-weekday tie-break: `bestIdx == worstIdx` → `worstIdx` dropped, chip renders as best only
- Saturday/Sunday indices (5, 6) never iterated — loop is `for (var i = 0; i < 5; i++)`
- Each chip wrapped in `Semantics(container: true, label: ...)` — "Best commute day: Tuesday, average 24 min"
- `VisualDensity.standard` for 44dp minimum touch target per UI-SPEC

### lib/features/stats/widgets/trend_chart_card.dart (125 lines)

- fl_chart 1.x `LineChart` with 28 `FlSpot` entries
- Reverse mapping: `dailyTotalsLast28Days[kStatsTrendWindowDays - 1 - i]` puts today at right edge (x=27)
- Y values in minutes (seconds / 60.0) for legible scale
- `minX: 0`, `maxX: 27`, `minY: 0` — flat baseline when all data is zero
- `LineTouchData(enabled: false)` — read-only, no tooltips
- 4 x-axis labels at positions 3, 10, 17, 24 via `SideTitleWidget(meta: meta, child: Text(...))` — fl_chart 1.x API confirmed
- Top/right/left axes hidden via `const AxisTitles()` (default)
- `FlDotCirclePainter(radius: _kDotRadius, color: colorScheme.primary)` — 2dp dots
- Fixed height: `SizedBox(height: kStatsTrendChartHeight)` = 192px

## fl_chart API Confirmation

fl_chart 1.x API correctly used:
- `SideTitleWidget(meta: meta, child: Text(...))` — NOT the 0.69.x `axisSide:` argument
- No `axisSide:` references anywhere in `lib/features/stats/widgets/`

## Deviations from Plan

### Auto-created StatsCard (Rule 3 - Blocking Issue)

- **Found during:** Task 1
- **Issue:** `lib/features/stats/widgets/stats_card.dart` did not exist — Plan 03 (which creates it) runs in parallel in a separate worktree. Plan 04 imports `StatsCard` so the file was needed to compile.
- **Fix:** Created a complete, compatible `StatsCard` implementation matching Plan 03's specification: `Card(color: surfaceContainerLow)` + 16dp padding + `titleSmall` heading + child body.
- **Files modified:** `lib/features/stats/widgets/stats_card.dart` (created)
- **Commit:** 505d211

### Removed redundant fl_chart arguments (Rule 1 - Bug fix / lint)

- **Found during:** Task 2
- **Issue:** `very_good_analysis` flagged `avoid_redundant_argument_values` for `isCurved: false`, `showTitles: false` on top/right/left axes, `show: false` on `BarAreaData`, and `strokeWidth: 0` — all are fl_chart 1.x defaults. Also flagged `const BarAreaData(show: false)` as `const_with_non_const` error.
- **Fix:** Removed all redundant arguments. Used `const AxisTitles()` (default hides axis). Removed `const` from `BarAreaData()`.
- **Files modified:** `lib/features/stats/widgets/trend_chart_card.dart`
- **Commit:** 294dc33

### Acceptance test grep limitation (plan spec note)

- `grep -c "primaryContainer"` criteria requires >= 2, but `onPrimaryContainer` contains uppercase "P" so the lowercase grep only matches 1 line. The implementation correctly uses both `colorScheme.primaryContainer` (bg) and `colorScheme.onPrimaryContainer` (fg) — semantically correct, plan grep is a case-sensitivity oversight.

## Verification Results

```
flutter analyze lib/features/stats/widgets/best_worst_day_card.dart
  → No issues found

flutter analyze lib/features/stats/widgets/trend_chart_card.dart
  → No issues found

flutter analyze (both files together)
  → No issues found

grep -rE "Color\(0x" best_worst_day_card.dart trend_chart_card.dart
  → None (good)

grep -rE "axisSide:" lib/features/stats/widgets/
  → None (good)

flutter test (170 tests)
  → All tests passed
```

## Self-Check: PASSED

- `lib/features/stats/widgets/best_worst_day_card.dart` — FOUND (136 lines)
- `lib/features/stats/widgets/trend_chart_card.dart` — FOUND (125 lines)
- `lib/features/stats/widgets/stats_card.dart` — FOUND (51 lines)
- Commit 505d211 — FOUND (Task 1: BestWorstDayCard + StatsCard)
- Commit 294dc33 — FOUND (Task 2: TrendChartCard)
