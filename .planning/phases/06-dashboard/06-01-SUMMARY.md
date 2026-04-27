---
phase: 06-dashboard
plan: "01"
subsystem: testing
tags: [flutter, riverpod, widget-test, unit-test, tdd, dashboard]

# Dependency graph
requires:
  - phase: 05-stats-analytics
    provides: statsSummaryProvider, StatsSummary shape, stats_providers.dart pattern
  - phase: 04-trip-history
    provides: TripCard widget, allTripSummariesProvider, TripSummary type
  - phase: 02-core-tracking
    provides: trackingStateProvider, TrackingNotifier, TrackingPermissionService, permission harness pattern

provides:
  - Failing widget test scaffold for DashboardScreen (12 test cases, RED state)
  - Failing unit test for todaysTripSummariesProvider filter logic (4 test cases, RED state)
  - Contract spec for Plans 02–04: constants (kDashboardFabIdleLabel, kDashboardFabActiveLabel, kDashboardEmptyStateLabel), InProgressCard widget, DashboardScreen widget

affects:
  - 06-02 (constants + provider plan — must make dashboard_providers_test GREEN)
  - 06-03 (widgets plan — must make InProgressCard/TodayTripsSection tests GREEN)
  - 06-04 (screen plan — must make all DashboardScreen tests GREEN)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - ProviderContainer + listen + Future.delayed(Duration.zero) + .value assertion for Provider<AsyncValue<T>> unit tests
    - _IdleTrackingNotifier / _ActiveTrackingNotifier TrackingNotifier subclass pattern for widget test isolation
    - _PermissionHarness typedef + _buildFakePermissionService spy factory (migrated from home_screen_test.dart)
    - _pumpDashboardScreen helper overriding all 3 providers (trackingPermissionServiceProvider, trackingStateProvider, allTripSummariesProvider, statsSummaryProvider)

key-files:
  created:
    - test/unit/features/dashboard/dashboard_providers_test.dart
    - test/widget/features/dashboard/dashboard_screen_test.dart
  modified: []

key-decisions:
  - "Icon assertions use Icons.history and Icons.bar_chart (not _rounded variants) per UI-SPEC §Icon library"
  - "statsSummaryProvider overrideWith uses (ref) => AsyncValue.data(...) pattern matching Provider<AsyncValue<T>> contract"
  - "_ActiveTrackingNotifier added (not in original home_screen_test.dart) to enable active-state test cases"
  - "trackingNotifierFactory parameter added to _pumpDashboardScreen for test flexibility"

patterns-established:
  - "Wave 0 test scaffold: import non-existent production files to establish RED compile failure before any implementation"
  - "ProviderContainer.listen before Future.delayed(Duration.zero) forces StreamProvider emission without widget pump"

requirements-completed:
  - UX-01

# Metrics
duration: 57min
completed: "2026-04-28"
---

# Phase 6 Plan 01: Dashboard Test Scaffold Summary

**Two failing test files (RED state) defining the full behavioral contract for DashboardScreen and todaysTripSummariesProvider before any production code exists**

## Performance

- **Duration:** 57 min
- **Started:** 2026-04-27T04:08:27Z
- **Completed:** 2026-04-28T04:09:27Z
- **Tasks:** 2
- **Files created:** 2

## Accomplishments

- Created `test/unit/features/dashboard/dashboard_providers_test.dart` with 4 unit test cases for `todaysTripSummariesProvider` filter logic (today included, yesterday excluded, tomorrow excluded, empty input) — RED due to missing `dashboard_providers.dart`
- Created `test/widget/features/dashboard/dashboard_screen_test.dart` with 12 widget test cases covering all UX-01 behaviors: FAB idle/active labels, InProgressCard visibility, today's trip list, empty state, AppBar icons (history, bar_chart), and 3 permission-path flows — RED due to missing `dashboard_screen.dart` and `in_progress_card.dart`
- Migrated permission-path tests verbatim from `home_screen_test.dart` with `HomeScreen` → `DashboardScreen` substitution; added `_ActiveTrackingNotifier` subclass to enable active-tracking test coverage not present in the source file

## Task Commits

Each task was committed atomically:

1. **Task 1: Create dashboard_providers_test.dart** - `6745c66` (test)
2. **Task 2: Create dashboard_screen_test.dart** - `ba6d7b2` (test)

**Plan metadata:** (committed with SUMMARY)

## Files Created/Modified

- `test/unit/features/dashboard/dashboard_providers_test.dart` — Unit test for `todaysTripSummariesProvider` using `ProviderContainer` override pattern; 4 tests; RED compile failure on missing `dashboard_providers.dart`
- `test/widget/features/dashboard/dashboard_screen_test.dart` — Widget test scaffold for `DashboardScreen`; 12 tests; RED compile failure on missing `dashboard_screen.dart` and `in_progress_card.dart`

## Decisions Made

- **Icon assertions**: Test assertions use `Icons.history` and `Icons.bar_chart` (not the `_rounded` variants) per 06-UI-SPEC.md §Icon library table which specifies `Icons.history` and `Icons.bar_chart` for AppBar actions. Implementation in Plan 04 must match these exactly.
- **`statsSummaryProvider` override**: Uses `(ref) => AsyncValue<StatsSummary>.data(...)` pattern — correct for `Provider<AsyncValue<StatsSummary>>` which is a synchronous `Provider`, not a `StreamProvider`.
- **`_ActiveTrackingNotifier`**: Added this subclass (not present in the source `home_screen_test.dart`) to cover the active-tracking test cases required by the plan spec (FAB active label, InProgressCard visibility).
- **`trackingNotifierFactory` parameter**: Added to `_pumpDashboardScreen` helper to allow injecting different tracking states per test, keeping the helper reusable across idle and active test cases.

## Deviations from Plan

None — plan executed exactly as written. The `_ActiveTrackingNotifier` and `trackingNotifierFactory` parameter are additive to satisfy the plan's test cases (c) and (d) which explicitly require an active-state notifier; they are not deviations.

## Issues Encountered

None.

## Next Phase Readiness

- Plan 02 must create `lib/features/dashboard/providers/dashboard_providers.dart` with `todaysTripSummariesProvider` to turn `dashboard_providers_test.dart` GREEN
- Plan 02 must also add Phase 6 constants to `lib/config/constants.dart` (`kDashboardFabIdleLabel`, `kDashboardFabActiveLabel`, `kDashboardEmptyStateLabel`) to unblock `dashboard_screen_test.dart` partial compilation
- Plan 03 must create `lib/features/dashboard/widgets/in_progress_card.dart` (and other widgets)
- Plan 04 must create `lib/features/dashboard/screens/dashboard_screen.dart` to turn all `dashboard_screen_test.dart` tests GREEN; icon choices in AppBar must use `Icons.history` and `Icons.bar_chart` to match test assertions

---
*Phase: 06-dashboard*
*Completed: 2026-04-28*

## Self-Check: PASSED

- `test/unit/features/dashboard/dashboard_providers_test.dart` — FOUND
- `test/widget/features/dashboard/dashboard_screen_test.dart` — FOUND
- Commit `6745c66` — FOUND
- Commit `ba6d7b2` — FOUND
- Both files produce compile errors (RED state) — CONFIRMED
- dashboard_screen_test.dart has 12 test cases — CONFIRMED
- dashboard_providers_test.dart has 4 test cases — CONFIRMED
- No production code modified — CONFIRMED
