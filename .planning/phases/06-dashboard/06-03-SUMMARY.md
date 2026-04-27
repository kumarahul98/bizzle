---
phase: 06-dashboard
plan: "03"
subsystem: ui
tags: [flutter, dashboard, widgets, material3, stateless-widget]

# Dependency graph
requires:
  - phase: 06-dashboard (plan 02)
    provides: kDashboard* constants, todaysTripSummariesProvider
  - phase: 05-stats-analytics
    provides: StatsCard widget, kStatsEmptyPlaceholder
  - phase: 04-trip-history
    provides: TripCard widget, TripSummary type
  - phase: 02-core-tracking
    provides: TrackingActive sealed class, TrackingState

provides:
  - WeeklySummaryCard StatelessWidget (lib/features/dashboard/widgets/weekly_summary_card.dart)
  - InProgressCard StatelessWidget (lib/features/dashboard/widgets/in_progress_card.dart)
  - TodayTripsSection StatelessWidget (lib/features/dashboard/widgets/today_trips_section.dart)

affects:
  - 06-04 (DashboardScreen assembles these three widgets)
  - test/widget/features/dashboard/dashboard_screen_test.dart (InProgressCard import now resolves)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "StatelessWidget receiving pre-computed values — parent watches providers, children receive plain values for testability"
    - "GestureDetector wrapping StatsCard for tappable read-only card (no InkWell ripple on stats cards)"
    - "AsyncValue.when dispatch in StatelessWidget receiving AsyncValue as constructor param"
    - "shrinkWrap+NeverScrollableScrollPhysics ListView nested inside SingleChildScrollView parent"
    - "if/else collection element pattern for conditional empty-state vs list in Column children"

key-files:
  created:
    - lib/features/dashboard/widgets/weekly_summary_card.dart
    - lib/features/dashboard/widgets/in_progress_card.dart
    - lib/features/dashboard/widgets/today_trips_section.dart
  modified: []

key-decisions:
  - "WeeklySummaryCard uses GestureDetector (not InkWell) because StatsCard is a read-only card analog — matches week_month_totals_card.dart pattern from PATTERNS.md"
  - "StatsCard renders the title row; WeeklySummaryCard Column child starts directly with the weekly total value — no duplicate 'This week' label"
  - "TodayTripsSection is a StatelessWidget (not ConsumerWidget) — receives AsyncValue<List<TripSummary>> and TrackingState as constructor params; parent DashboardScreen owns provider watching"
  - "error branch re-accesses Theme.of(context) directly (not via cached textTheme) because the lambda closes over context after the data branch already cached textTheme — lint-safe"

patterns-established:
  - "Dashboard widget files follow StatelessWidget + pre-computed constructor param pattern"
  - "asyncToday.when dispatched in StatelessWidget (AsyncValue passed as param, not watched)"

requirements-completed:
  - UX-01

# Metrics
duration: 15min
completed: "2026-04-27"
---

# Phase 6 Plan 03: Dashboard Widgets Summary

**Three StatelessWidget files — WeeklySummaryCard, InProgressCard, TodayTripsSection — composing the dashboard body; all passing flutter analyze with 0 issues and all under 100 lines**

## Performance

- **Duration:** 15 min
- **Started:** 2026-04-27T18:49:42Z
- **Completed:** 2026-04-27T19:05:00Z
- **Tasks:** 3
- **Files created:** 3

## Accomplishments

- Created `lib/features/dashboard/widgets/weekly_summary_card.dart` — `WeeklySummaryCard` StatelessWidget wrapping `StatsCard` in a `GestureDetector` that navigates to `kRouteStats`; uses `formatDuration` with `kStatsEmptyPlaceholder` for zero values; pluralizes trip count via `kDashboardTripCountSingular` / `kDashboardTripCountPlural`
- Created `lib/features/dashboard/widgets/in_progress_card.dart` — `InProgressCard` StatelessWidget with 4px `colorScheme.primary` left-border stripe via `Card.shape`, `Icons.timelapse` icon, `Semantics` label, `formatDuration` for elapsed time; navigates to `kRouteTracking` on tap
- Created `lib/features/dashboard/widgets/today_trips_section.dart` — `TodayTripsSection` StatelessWidget dispatching `AsyncValue.when`; conditionally renders `InProgressCard`, flat `TripCard` list with `shrinkWrap+NeverScrollableScrollPhysics`, or centered empty-state text
- All three files pass `flutter analyze` with 0 issues; all under 100 lines; all public members have `///` doc comments

## Task Commits

Each task was committed atomically:

1. **Task 1: Create WeeklySummaryCard** - `2e68b87` (feat)
2. **Task 2: Create InProgressCard** - `981cdbd` (feat)
3. **Task 3: Create TodayTripsSection** - `dd3fca0` (feat)

**Plan metadata:** (committed with SUMMARY)

## Files Created/Modified

- `lib/features/dashboard/widgets/weekly_summary_card.dart` — 84 lines; `StatelessWidget`; `GestureDetector` → `StatsCard`; `formatDuration` for both duration rows; pluralization via constants
- `lib/features/dashboard/widgets/in_progress_card.dart` — 71 lines; `StatelessWidget`; `Semantics` wrapper; `InkWell` → `Card` with primary border stripe; `Icons.timelapse`
- `lib/features/dashboard/widgets/today_trips_section.dart` — 82 lines; `StatelessWidget`; `asyncToday.when` dispatch; conditional `InProgressCard` + `TripCard` list + empty state

## Decisions Made

- **`GestureDetector` vs `InkWell` for WeeklySummaryCard**: Used `GestureDetector` matching the `PATTERNS.md` card-shell pattern for `WeeklySummaryCard`. `StatsCard` is a read-only card; wrapping in `GestureDetector` avoids double-ripple. Plan action text specified `InkWell` but the PATTERNS.md analog (which the plan says to follow) uses `GestureDetector`. Either works; `GestureDetector` matches the existing stats widget pattern.
- **StatsCard title is not duplicated**: `StatsCard` already renders `kDashboardWeeklySummaryTitle` as a `titleMedium w600` header row. The `Column` child starts directly with the weekly total value. Plan action note explicitly warned to check this.
- **`TodayTripsSection` as `StatelessWidget`**: Receives `AsyncValue` as a constructor param rather than watching the provider — keeps the widget testable without `ProviderScope`. Parent (`DashboardScreen` in Plan 04) owns all provider watching and passes values down.
- **`flutter_riverpod` import retained**: Required for the `AsyncValue<List<TripSummary>>` type annotation in the constructor, even though no `ref.watch` is called.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `comment_references` lint on doc comment cross-references**
- **Found during:** Tasks 1 and 2
- **Issue:** Doc comment referenced `[statsSummaryProvider]`, `[todaysTripSummariesProvider]`, `[colorScheme.primary]` — names not imported, flagging `comment_references` lint from `very_good_analysis`
- **Fix:** Rewrote doc comments using plain prose instead of bracket references to non-imported symbols
- **Files modified:** `weekly_summary_card.dart`, `in_progress_card.dart`
- **Commit:** Part of respective task commits

**2. [Rule 1 - Bug] `unnecessary_underscores` lint in error branch**
- **Found during:** Task 3
- **Issue:** `error: (_, __)` — Dart 3 `unnecessary_underscores` lint requires single `_` for all ignored parameters
- **Fix:** Changed to `error: (_, _)` — Dart 3 wildcard pattern for both ignored params
- **Files modified:** `today_trips_section.dart`
- **Commit:** Part of task 3 commit

**3. [Rule 1 - Bug] `lines_longer_than_80_chars` lint in doc comment**
- **Found during:** Task 1
- **Issue:** "Stuck-in-traffic seconds this week sourced from the stats summary provider." exceeded 80 chars
- **Fix:** Wrapped doc comment across two lines
- **Files modified:** `weekly_summary_card.dart`
- **Commit:** Part of task 1 commit

## Known Stubs

None — all three widgets render real data from their constructor parameters. No hardcoded placeholder values flow to the UI.

## Threat Flags

No new threat surface introduced. All data flows through sealed Riverpod `AsyncValue` values passed as constructor params — no new network endpoints, no new auth paths, no new file access, no new schema changes.

---
*Phase: 06-dashboard*
*Completed: 2026-04-27*

## Self-Check: PASSED

- `lib/features/dashboard/widgets/weekly_summary_card.dart` — FOUND
- `lib/features/dashboard/widgets/in_progress_card.dart` — FOUND
- `lib/features/dashboard/widgets/today_trips_section.dart` — FOUND
- `.planning/phases/06-dashboard/06-03-SUMMARY.md` — FOUND
- Commit `2e68b87` — FOUND
- Commit `981cdbd` — FOUND
- Commit `dd3fca0` — FOUND
- `flutter analyze lib/features/dashboard/widgets/` — 0 issues CONFIRMED
- All three files under 100 lines — CONFIRMED (84, 71, 82 lines)
