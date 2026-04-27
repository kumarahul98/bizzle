---
phase: 05-stats-analytics
verified: 2026-04-26T12:00:00Z
status: human_needed
score: 5/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Navigate to Stats from the home screen on a real or emulated Android device with no trips recorded. Verify all 5 cards are visible with em-dash (—) placeholders in every value slot."
    expected: "AppBar shows 'Stats'. WeekMonthTotalsCard shows '—' for both week and month. DirectionAveragesCard shows '—' for both directions. BestWorstDayCard shows 5 unstyled chips (Mon–Fri). TrendChartCard shows a flat line at y=0. TrafficWasteCard shows '—'."
    why_human: "Visual appearance, card layout order, and fl_chart render output cannot be asserted programmatically without a real device or screenshot comparison framework."
  - test: "Record at least one GPS trip, return to the home screen, and tap 'View stats'. Verify WeekMonthTotalsCard shows a non-zero duration."
    expected: "WeekMonthTotalsCard's 'This week' slot shows the formatted duration (e.g., '30 min'). The app does not block or show an error state."
    why_human: "Requires live GPS capture and Drift write to flow through to the stats screen — end-to-end data flow through real hardware."
  - test: "Verify the BestWorstDayCard best/worst chip color contrast meets WCAG 1.4.1. Best chip (primaryContainer/onPrimaryContainer) and worst chip (errorContainer/onErrorContainer) must be distinguishable without color as the sole signal."
    expected: "Best chip shows trending_down icon; worst chip shows trending_up icon. Both icons visible alongside the chip color."
    why_human: "Accessibility color contrast requires human visual or automated accessibility audit tooling (not available via flutter test)."
---

# Phase 5: Stats & Analytics Verification Report

**Phase Goal:** Users can see the reality of their commute through weekly/monthly totals, direction-split averages, best/worst days, trends, and traffic waste
**Verified:** 2026-04-26T12:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can view total commute time for the current week and current month | VERIFIED | `WeekMonthTotalsCard` renders `weekTotalSeconds` and `monthTotalSeconds` from `StatsSummary`. `computeStatsSummary` accumulates week (D-03 Mon–Sun) and month (D-04 calendar month) totals in a single pass. Both fields pass 3 unit tests (week boundary exclusion, month boundary, manual entry inclusion). |
| 2 | User can see average commute duration split by to-office vs to-home | VERIFIED | `DirectionAveragesCard` renders `toOfficeAvgSeconds` and `toHomeAvgSeconds`. `computeStatsSummary` computes integer-division averages per direction with null guards for zero-trip directions (D-10). 2 unit tests cover independent averaging and null return. |
| 3 | User can identify their best and worst commute day of the week | VERIFIED | `BestWorstDayCard` renders 5 chips Mon–Fri using `DateFormat.E('en_US')` anchored to 2024-01-01 (known Monday). Best chip = `primaryContainer` + `Icons.trending_down_rounded`; worst = `errorContainer` + `Icons.trending_up_rounded`. Single-weekday tie-break drops `worstIdx`. `computeStatsSummary` forces indices 5–6 (Sat/Sun) to null per D-09. 1 unit test covers Mon–Fri population and Sat/Sun null enforcement. |
| 4 | User can view a 4-week trend line chart showing commute duration over time | VERIFIED | `TrendChartCard` renders fl_chart 1.x `LineChart` with 28 `FlSpot` entries. Index reversal places today at right edge (x=27). 4 x-axis labels at positions 3, 10, 17, 24 via `SideTitleWidget(meta: meta, ...)`. `minY: 0` enforces flat baseline. `LineTouchData(enabled: false)` disables touch. 2 unit tests cover 28-day length and window exclusion. |
| 5 | User can see a weekly total of time wasted stuck in traffic | VERIFIED | `TrafficWasteCard` renders `weekStuckSeconds`. `computeStatsSummary` accumulates `timeStuckSeconds` for non-manual trips in the current week only (D-05 guard). 2 unit tests verify manual-entry exclusion and out-of-week exclusion. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|---------|--------|---------|
| `lib/features/stats/services/stats_service.dart` | StatsSummary + computeStatsSummary | VERIFIED | 178 lines. `@immutable` class with 8 final fields. Single-pass implementation with `_daysBetweenLocalMidnights` DST helper. No `UnimplementedError`. |
| `lib/features/stats/providers/stats_providers.dart` | statsSummaryProvider | VERIFIED | 37 lines. `Provider<AsyncValue<StatsSummary>>` watching `allTripSummariesProvider` via `whenData`. Name: `'statsSummaryProvider'`. |
| `lib/features/stats/widgets/stats_card.dart` | StatsCard wrapper | VERIFIED | 56 lines. `Card(color: surfaceContainerLow)` + 16px padding + `titleMedium w600` title + child slot. No `InkWell`. |
| `lib/features/stats/widgets/week_month_totals_card.dart` | STAT-01 card | VERIFIED | 75 lines. Renders both totals via `formatDuration` with `kStatsEmptyPlaceholder` for zero. |
| `lib/features/stats/widgets/direction_averages_card.dart` | STAT-02 card | VERIFIED | 87 lines. Two `_DirectionRow` widgets. Nullable `int?` renders as `kStatsEmptyPlaceholder`. |
| `lib/features/stats/widgets/traffic_waste_card.dart` | STAT-05 card | VERIFIED | 51 lines. `weekStuckSeconds` via `formatDuration` with `kStatsEmptyPlaceholder` for zero. |
| `lib/features/stats/widgets/best_worst_day_card.dart` | STAT-03 card | VERIFIED | 136 lines. `DateFormat.E('en_US')` anchored labels. `Semantics` wrapping. `VisualDensity.standard`. |
| `lib/features/stats/widgets/trend_chart_card.dart` | STAT-04 chart card | VERIFIED | 125 lines. fl_chart 1.x `SideTitleWidget(meta: meta, ...)`. `minY: 0`. `LineTouchData(enabled: false)`. Fixed height `kStatsTrendChartHeight`. |
| `lib/features/stats/screens/stats_screen.dart` | StatsScreen | VERIFIED | 80 lines. `ConsumerWidget`. `AsyncValue.when` with loading/error/data branches. All 5 cards in D-01 order. `SingleChildScrollView + Column` (not ListView). |
| `lib/config/routes.dart` | kRouteStats in kAppRoutes | VERIFIED | `kRouteStats: (BuildContext context) => const StatsScreen()` present. Import of `stats_screen.dart` present. |
| `lib/features/tracking/screens/home_screen.dart` | View stats button | VERIFIED | `FractionallySizedBox(widthFactor: 0.7)` + `OutlinedButton` with `kStatsHomeButtonLabel` + `Navigator.pushNamed(context, kRouteStats)`. |
| `lib/config/constants.dart` | Phase 5 constants | VERIFIED | 21 Phase 5 constants declared: 3 numeric/dimension (`kStatsTrendWindowDays`, `kStatsTrendWeekCount`, `kStatsTrendChartHeight`) and 18 strings. All with doc comments. |
| `test/unit/features/stats/stats_service_test.dart` | Unit tests GREEN | VERIFIED | 13 tests across 8 groups. All pass. |
| `test/widget/features/stats/stats_screen_test.dart` | Widget tests | VERIFIED | 5 `testWidgets` covering: AppBar title, 5 card titles, D-10 empty placeholders, weekly helper on non-empty, error branch. |
| `test/widget/features/tracking/home_screen_test.dart` | View stats nav tests | VERIFIED | 2 new tests: button presence + navigation to StatsScreen. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `stats_providers.dart` | `history_providers.dart` | `ref.watch(allTripSummariesProvider)` | WIRED | Line 31: `ref.watch(allTripSummariesProvider)` present. |
| `stats_providers.dart` | `stats_service.dart` | `computeStatsSummary` inside `whenData` | WIRED | Line 33: `computeStatsSummary(trips, DateTime.now())` inside `whenData`. |
| `stats_screen.dart` | `stats_providers.dart` | `ref.watch(statsSummaryProvider)` | WIRED | Line 36: `ref.watch(statsSummaryProvider)`. |
| `routes.dart` | `stats_screen.dart` | `kAppRoutes` mapping | WIRED | `kRouteStats: (BuildContext context) => const StatsScreen()` at line 32. StatsScreen import at line 2. |
| `home_screen.dart` | `routes.dart` | `Navigator.pushNamed(context, kRouteStats)` | WIRED | Line 76: `Navigator.pushNamed(context, kRouteStats)`. `kStatsHomeButtonLabel` at line 77. |
| Each stat card | `stats_service.dart` fields | Constructor parameters | WIRED | Each card receives the correct `StatsSummary` field: `weekTotalSeconds`, `monthTotalSeconds`, `toOfficeAvgSeconds`, `toHomeAvgSeconds`, `weekdayAverages`, `dailyTotalsLast28Days`, `weekStuckSeconds`. |
| `trend_chart_card.dart` | `fl_chart` | `LineChart`, `SideTitleWidget(meta: meta, ...)` | WIRED | fl_chart 1.x API confirmed. No `axisSide:` usage. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `StatsScreen` | `asyncStats` (AsyncValue<StatsSummary>) | `statsSummaryProvider` → `allTripSummariesProvider` → Drift `watchAllSummaries()` | Yes — Drift reactive stream, real DB queries | FLOWING |
| `WeekMonthTotalsCard` | `weekTotalSeconds`, `monthTotalSeconds` | `StatsSummary` fields passed as constructor params by `StatsScreen` | Yes — computed from real trip list in `computeStatsSummary` | FLOWING |
| `DirectionAveragesCard` | `toOfficeAvgSeconds`, `toHomeAvgSeconds` | Same as above | Yes | FLOWING |
| `BestWorstDayCard` | `weekdayAverages` | Same as above | Yes | FLOWING |
| `TrendChartCard` | `dailyTotalsLast28Days` | Same as above | Yes | FLOWING |
| `TrafficWasteCard` | `weekStuckSeconds` | Same as above | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| 177 tests pass including all Phase 5 additions | `flutter test --no-pub` | 177/177 passed | PASS |
| No analyzer warnings | `flutter analyze` (per SUMMARY.md) | 0 issues | PASS |
| No `UnimplementedError` stub remains | `grep "throw UnimplementedError" lib/features/stats/services/stats_service.dart` | 0 matches | PASS |
| fl_chart 1.x API used (not 0.69 axisSide) | `grep "axisSide:" lib/features/stats/widgets/trend_chart_card.dart` | 0 matches | PASS |
| No hardcoded Color(0x...) literals | `grep -r "Color(0x" lib/features/stats/` | 0 matches | PASS |
| kRouteStats mapped in kAppRoutes | `grep "kRouteStats:" lib/config/routes.dart` | 1 match | PASS |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| STAT-01 | 05-01, 05-02, 05-03, 05-05 | Weekly (Mon–Sun) and monthly commute totals | SATISFIED | `computeStatsSummary` accumulates week/month totals. `WeekMonthTotalsCard` renders both. 3 unit tests + 1 widget test. |
| STAT-02 | 05-01, 05-02, 05-03, 05-05 | Direction averages (to-office / to-home) | SATISFIED | `computeStatsSummary` averages per direction with null for zero. `DirectionAveragesCard` renders nullable values. 2 unit tests + 1 widget test. |
| STAT-03 | 05-01, 05-02, 05-04, 05-05 | Best and worst commute day of the week | SATISFIED | `computeStatsSummary` computes weekday averages Mon–Fri only (D-09). `BestWorstDayCard` renders chips with color + icon. 1 unit test + 1 widget test. |
| STAT-04 | 05-01, 05-02, 05-04, 05-05 | 4-week trend line chart | SATISFIED | `computeStatsSummary` fills 28-day window. `TrendChartCard` renders fl_chart 1.x `LineChart` with 4 week labels. 2 unit tests + 1 widget test. |
| STAT-05 | 05-01, 05-02, 05-03, 05-05 | Weekly traffic waste (stuck seconds, GPS trips only) | SATISFIED | `computeStatsSummary` sums `timeStuckSeconds` for non-manual in-week trips (D-05). `TrafficWasteCard` renders the value. 2 unit tests + 1 widget test. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `stats_service.dart` | 168–169 | `return null` in `List.generate` | Info | Intentional — D-09/D-10 guard forcing Sat/Sun and zero-count weekday slots to null. Not a stub. |
| `stats_screen.dart` | 28 | `—` in doc comment | Info | In-code documentation string referencing the placeholder character. Not a rendered stub. |

No blocker or warning anti-patterns found. The `return null` occurrences are inside the `weekdayAverages` generator and are contractually required by D-09 and D-10.

One deviation noted: `stats_screen.dart` uses `SingleChildScrollView + Column` instead of `ListView` as specified in the plan. This was an intentional fix (documented in 05-05-SUMMARY.md) because `ListView` caused widget test failures for the 5th card. The behavior is identical for a fixed-length 5-item list and the widget tests verify it correctly.

### Human Verification Required

#### 1. Empty-state visual smoke test

**Test:** On a real or emulated Android device with no trips recorded, tap "View stats" from the home screen.
**Expected:** AppBar shows 'Stats'. All 5 cards are visible. Every value slot shows '—' (em-dash). BestWorstDayCard shows 5 unstyled chips. TrendChartCard shows a flat line at y=0.
**Why human:** Visual layout, card render order, and fl_chart chart output cannot be fully asserted via `flutter test` without screenshot comparison. The widget tests verify titles and placeholder text presence but not visual correctness.

#### 2. Live data smoke test

**Test:** Record at least one GPS commute trip, navigate back to the home screen, tap "View stats".
**Expected:** `WeekMonthTotalsCard` shows a non-zero formatted duration (e.g., "30 min") in the 'This week' slot. No error state or blank screen.
**Why human:** Requires live GPS capture and a complete Drift write → `allTripSummariesProvider` emission → `statsSummaryProvider` derivation chain on real hardware.

#### 3. Accessibility smoke test

**Test:** Inspect BestWorstDayCard best and worst chips using TalkBack (Android accessibility service).
**Expected:** TalkBack reads "Best commute day: Monday, average 24 min" (or equivalent) for the best chip, and "Worst commute day: Wednesday, average 45 min" for the worst chip. The icon (trending_down / trending_up) is visible alongside the color coding.
**Why human:** Requires TalkBack activation on device. Semantics labels are present in code (verified) but audible output requires manual testing.

### Gaps Summary

No gaps found. All 5 STAT-0x success criteria are verified end-to-end: the math contract is locked by 13 unit tests, the Riverpod wiring flows from Drift through `statsSummaryProvider` to each card constructor, all route registrations are in place, and the full test suite of 177 tests passes.

---

_Verified: 2026-04-26T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
