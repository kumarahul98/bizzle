---
phase: 05-stats-analytics
plan: "05"
subsystem: stats-screen
tags: [flutter, stats, ui, navigation, widget-tests]
dependency_graph:
  requires: ["05-03", "05-04"]
  provides: ["StatsScreen", "kRouteStats", "stats-nav-entry"]
  affects: ["lib/config/routes.dart", "lib/features/tracking/screens/home_screen.dart"]
tech_stack:
  added: []
  patterns:
    - "ConsumerWidget + AsyncValue.when dispatch (identical to HistoryScreen pattern)"
    - "SingleChildScrollView+Column for fixed-list screen (vs ListView) — avoids lazy virtualisation"
    - "pump(Duration(seconds:2)) for fl_chart animation in widget tests"
key_files:
  created:
    - lib/features/stats/screens/stats_screen.dart
    - test/widget/features/stats/stats_screen_test.dart
  modified:
    - lib/config/routes.dart
    - lib/features/tracking/screens/home_screen.dart
    - test/widget/features/tracking/home_screen_test.dart
decisions:
  - "Used SingleChildScrollView+Column instead of ListView for the 5-card body — with exactly 5 cards, lazy virtualisation gives no benefit and causes widget tests to miss off-screen cards"
  - "Used pump(Duration(seconds:2)) instead of pumpAndSettle for fl_chart animation in navigation test — LineChart draw animation never settles under pumpAndSettle"
  - "kStatsCardWeekLabel ('This week') intentionally appears twice in the data branch — once as WeekMonthTotalsCard title, once as TrendChartCard x-axis kStatsCardTrendXAxisCurrent — test uses findsAtLeastNWidgets(1)"
metrics:
  duration: "~25 minutes"
  completed: "2026-04-27T03:12:55Z"
  tasks_completed: 2
  files_changed: 5
---

# Phase 05 Plan 05: StatsScreen Wire-Up and Widget Tests Summary

StatsScreen ConsumerWidget wired with 5 stat cards in D-01 order, route registered, home nav button added, and 7 new widget tests covering all AsyncValue branches plus navigation.

## Tasks Completed

### Task 1: Create StatsScreen + register kRouteStats + add View stats home button

**Commit:** `8857ddb`

Created `lib/features/stats/screens/stats_screen.dart` — 80 lines, `ConsumerWidget`, watches `statsSummaryProvider`, dispatches via `AsyncValue.when` with three branches:
- `loading` → `Center(CircularProgressIndicator())`
- `error` → `Center(Text(kStatsErrorMessage))`
- `data` → `SingleChildScrollView` + `Column` with 5 cards in D-01 order: `WeekMonthTotalsCard`, `DirectionAveragesCard`, `BestWorstDayCard`, `TrendChartCard`, `TrafficWasteCard`

Updated `lib/config/routes.dart`:
- Added import `package:traevy/features/stats/screens/stats_screen.dart`
- Added entry `kRouteStats: (BuildContext context) => const StatsScreen()` between kRouteHistory and kRouteTripDetail

Updated `lib/features/tracking/screens/home_screen.dart`:
- Added `import 'package:traevy/config/constants.dart'`
- Added `View stats` `OutlinedButton` with `FractionallySizedBox(widthFactor: 0.7)` + `SizedBox(height: 12)` gap below `View history` (D-02)

### Task 2: Widget tests for StatsScreen + updated home_screen test

**Commit:** `436ddbf`

Created `test/widget/features/stats/stats_screen_test.dart` — 5 `testWidgets`:
1. Renders Stats AppBar title
2. Renders all 5 stat-card titles (with `skipOffstage: false` for off-viewport cards)
3. Renders em-dash placeholders when no trips (D-10) — `findsAtLeastNWidgets(4)`
4. Renders weekly helper text when trips exist (kStatsCardWeekHelper)
5. Error branch renders kStatsErrorMessage

Updated `test/widget/features/tracking/home_screen_test.dart` — 2 new `testWidgets`:
1. Renders View stats OutlinedButton with locked label
2. Tapping View stats navigates to StatsScreen

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Switched ListView to SingleChildScrollView+Column**
- **Found during:** Task 2 (widget test failure — TrafficWasteCard not found)
- **Issue:** `ListView` lazily builds children; 5th card (`TrafficWasteCard`) was never constructed in the default 600px test viewport even with `skipOffstage: false`. This is a correctness bug for the test assertion contract.
- **Fix:** Replaced `ListView` with `SingleChildScrollView` + `Column` so all 5 cards are always built. For a fixed-length list of 5 items, lazy virtualisation has no benefit and causes test unreliability.
- **Files modified:** `lib/features/stats/screens/stats_screen.dart`
- **Commit:** `436ddbf`

**2. [Rule 1 - Bug] Replaced pumpAndSettle with pump(Duration(seconds:2)) in navigation test**
- **Found during:** Task 2 (navigation test timeout after 10s)
- **Issue:** `fl_chart`'s `LineChart` runs a draw animation that never fully settles, causing `pumpAndSettle` to time out after the default 100-frame limit.
- **Fix:** Used `pump(const Duration(seconds: 2))` to advance past the 150ms fl_chart animation without blocking forever. This pattern is standard for fl_chart widget tests.
- **Files modified:** `test/widget/features/tracking/home_screen_test.dart`
- **Commit:** `436ddbf`

**3. [Rule 2 - Missing functionality] Removed redundant durationSeconds argument**
- **Found during:** `flutter analyze` post-Task 2
- **Issue:** `avoid_redundant_argument_values` lint — `_trip(today, durationSeconds: 1800)` passed the default value explicitly.
- **Fix:** Removed named argument; default of 1800 applies.
- **Files modified:** `test/widget/features/stats/stats_screen_test.dart`
- **Commit:** `436ddbf`

## Test Results

| Suite | Tests |
|-------|-------|
| Prior phases (01–04) | 170 |
| New: stats_screen_test.dart | 5 |
| New: home_screen_test.dart additions | 2 |
| **Total** | **177** |

`flutter analyze`: No issues found.
`flutter test`: 177/177 passed.

## Known Stubs

None. All 5 stat cards receive real data from `statsSummaryProvider` which derives from `allTripSummariesProvider` (Drift-backed). No placeholder values, no hardcoded data.

## Threat Flags

None. Read-only screen, no input, no auth, no network, no PII written (T-05-05-01..03 all accepted per plan's threat model).

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| lib/features/stats/screens/stats_screen.dart exists | FOUND |
| lib/config/routes.dart exists | FOUND |
| lib/features/tracking/screens/home_screen.dart exists | FOUND |
| test/widget/features/stats/stats_screen_test.dart exists | FOUND |
| test/widget/features/tracking/home_screen_test.dart exists | FOUND |
| commit 8857ddb (feat Task 1) | FOUND |
| commit 436ddbf (test Task 2) | FOUND |
| flutter analyze | No issues found |
| flutter test | 177/177 passed |
