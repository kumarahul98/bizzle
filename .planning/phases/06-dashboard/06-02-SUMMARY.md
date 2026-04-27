---
phase: 06-dashboard
plan: "02"
subsystem: ui
tags: [flutter, riverpod, dart, constants, provider, dashboard]

# Dependency graph
requires:
  - phase: 05-stats-analytics
    provides: statsSummaryProvider pattern (manual Provider<AsyncValue<T>> with whenData)
  - phase: 04-trip-history
    provides: allTripSummariesProvider, TripSummary type, history_providers.dart date comparison pattern
  - phase: 06-dashboard (plan 01)
    provides: dashboard_providers_test.dart RED scaffold (4 test cases awaiting GREEN)

provides:
  - 10 kDashboard* string constants in lib/config/constants.dart under Phase 6 block
  - todaysTripSummariesProvider (manual Provider<AsyncValue<List<TripSummary>>>) in dashboard_providers.dart

affects:
  - 06-03 (widgets plan — WeeklySummaryCard, InProgressCard, TodayTripsSection use kDashboard* constants)
  - 06-04 (screen plan — DashboardScreen uses all constants and todaysTripSummariesProvider)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Derived Provider<AsyncValue<T>> via whenData — mirrors statsSummaryProvider pattern exactly"
    - "Date comparison using .toLocal() + DateTime(y, m, d) equality — same as groupTripsByDate in history_providers.dart"

key-files:
  created:
    - lib/features/dashboard/providers/dashboard_providers.dart
  modified:
    - lib/config/constants.dart

key-decisions:
  - "kStatsHomeButtonLabel retained in constants.dart — home_screen.dart still exists until Plan 04 deletes it"
  - "todaysTripSummariesProvider is a manual Provider (no @riverpod annotation) — consistent with project-wide codegen ban from Phase 2"
  - "kDashboardTripCountPlural = 'trips' (suffix only) — call site builds full string via interpolation ('$count trips')"

patterns-established:
  - "Phase 6 Dashboard constants block appended at bottom of constants.dart following existing phase-block convention"
  - "dashboard_providers.dart: single-export provider file with full doc comment on the provider, no @riverpod"

requirements-completed:
  - UX-01

# Metrics
duration: 80min
completed: "2026-04-27"
---

# Phase 6 Plan 02: Constants + Dashboard Provider Summary

**10 kDashboard* string constants added to constants.dart and todaysTripSummariesProvider implemented as a derived manual Provider that filters today's trips from allTripSummariesProvider using .toLocal() date comparison — dashboard_providers_test.dart turns GREEN (4/4 tests pass)**

## Performance

- **Duration:** 80 min
- **Started:** 2026-04-27T18:33:35Z
- **Completed:** 2026-04-27T20:33:55Z
- **Tasks:** 2
- **Files created:** 1
- **Files modified:** 1

## Accomplishments

- Appended Phase 6 Dashboard block (10 constants) to `lib/config/constants.dart` with exact names and values from UI-SPEC — all locked constant names verified with grep
- Created `lib/features/dashboard/providers/` directory and `dashboard_providers.dart` implementing `todaysTripSummariesProvider` as a manual `Provider<AsyncValue<List<TripSummary>>>` with `whenData` filter and `.toLocal()` date comparison
- Turned `test/unit/features/dashboard/dashboard_providers_test.dart` GREEN: all 4 test cases pass (today included, yesterday excluded, tomorrow excluded, empty input)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Phase 6 constants block to constants.dart** - `c6ec78d` (feat)
2. **Task 2: Create dashboard_providers.dart with todaysTripSummariesProvider** - `4fd7b13` (feat)

**Plan metadata:** (committed with SUMMARY)

## Files Created/Modified

- `lib/config/constants.dart` — Phase 6 Dashboard block appended at bottom; 10 new `kDashboard*` constants with exact names/values from UI-SPEC; `kStatsHomeButtonLabel` retained (home_screen.dart still exists)
- `lib/features/dashboard/providers/dashboard_providers.dart` — New file; exports `todaysTripSummariesProvider`; manual `Provider<AsyncValue<List<TripSummary>>>` deriving from `allTripSummariesProvider` via `whenData`; date filter uses `.toLocal()` + `DateTime(y, m, d)` equality; full `///` doc comment on the provider

## Decisions Made

- **`kStatsHomeButtonLabel` retained:** The plan explicitly prohibits removing it in Plan 02 because `home_screen.dart` still imports it; Plan 04 will remove both together.
- **`kDashboardTripCountPlural = 'trips'`:** Suffix-only constant (not `'%d trips'` or `'$count trips'`) — call site builds the full string via `'$count trips'` interpolation. Matches the UI-SPEC "Build the full string at call site" instruction.
- **Manual `Provider` (no codegen):** Consistent with the Phase 2 decision to ban `@riverpod` codegen project-wide due to the `drift_dev` / `riverpod_generator` analyzer version conflict.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

- Plan 03 can now import `kDashboardInProgressLabel`, `kDashboardTodaySectionLabel`, `kDashboardEmptyStateLabel`, `kDashboardErrorMessage`, `kDashboardWeeklySummaryTitle`, `kDashboardInTrafficLabel`, `kDashboardTripCountSingular`, `kDashboardTripCountPlural` from `constants.dart` without constants.dart churn
- `todaysTripSummariesProvider` is ready for `DashboardScreen` and `TodayTripsSection` to watch
- `dashboard_screen_test.dart` (12 tests) still RED — missing `dashboard_screen.dart` and `in_progress_card.dart` (Plans 03 and 04)

---
*Phase: 06-dashboard*
*Completed: 2026-04-27*

## Self-Check: PASSED

- `lib/config/constants.dart` — FOUND, 10 kDashboard* constants confirmed via grep
- `lib/features/dashboard/providers/dashboard_providers.dart` — FOUND
- Commit `c6ec78d` — FOUND
- Commit `4fd7b13` — FOUND
- `dashboard_providers_test.dart` 4/4 GREEN — CONFIRMED
- `flutter analyze` on both files — 0 issues CONFIRMED
