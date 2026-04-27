---
phase: 05-stats-analytics
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 15
files_reviewed_list:
  - lib/features/stats/services/stats_service.dart
  - lib/features/stats/providers/stats_providers.dart
  - lib/features/stats/screens/stats_screen.dart
  - lib/features/stats/widgets/stats_card.dart
  - lib/features/stats/widgets/week_month_totals_card.dart
  - lib/features/stats/widgets/direction_averages_card.dart
  - lib/features/stats/widgets/traffic_waste_card.dart
  - lib/features/stats/widgets/best_worst_day_card.dart
  - lib/features/stats/widgets/trend_chart_card.dart
  - lib/config/constants.dart
  - lib/config/routes.dart
  - lib/features/tracking/screens/home_screen.dart
  - test/unit/features/stats/stats_service_test.dart
  - test/widget/features/stats/stats_screen_test.dart
  - test/widget/features/tracking/home_screen_test.dart
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-04-26T00:00:00Z
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

This review covers the Phase 5 stats & analytics feature: the `computeStatsSummary` pure-function service, a single derived Riverpod provider, five stat card widgets, the updated `constants.dart` and `routes.dart`, the updated `HomeScreen`, and the accompanying unit and widget test suites.

The core computation logic in `stats_service.dart` is well-structured, correctly handles DST via the UTC-anchor helper, and correctly guards against division by zero. The Riverpod provider is minimal and correct. The widget layer is clean and stays under the 100-line limit for every file.

Four warnings were found: two logic correctness issues in `best_worst_day_card.dart` (a tie case and an index bounds assumption), one missing `BarAreaData` color that produces an unintended transparent fill, and one time-sensitive widget test that will produce false failures on a Monday. Five informational items cover a magic number, a redundant null assertion, a dead method on `HomeScreen`, a comment inaccuracy in the test file, and a missing `monthHelper` label.

No security issues were found.

## Warnings

### WR-01: BestWorstDayCard tie-breaking is asymmetric — same-average days are silently wrong

**File:** `lib/features/stats/widgets/best_worst_day_card.dart:38-55`

**Issue:** The best/worst scan uses separate `bestAvg` / `worstAvg` accumulators with initial values `1 << 30` and `-1`. When two weekdays share the exact same average, the *first* one wins best and the *last* one wins worst — they end up as different chips. The single-weekday guard on line 53 (`bestIdx == worstIdx`) only fires when `bestIdx` and `worstIdx` happen to point to the same index, which is impossible when two different indices have equal averages. The result: on a perfectly even commute week, both `isBest` and `isWorst` are set on different chips at the same time, which is semantically wrong (they should both be highlighted as "best" or neither highlighted).

The logic also reads `weekdayAverages[i]` for `i` in `0..<5`, which is correct, but because the list always has length 7 (per `StatsSummary`), the bounds are safe. The real issue is purely the equal-average case.

**Fix:**
```dart
// After the scan loop, if best and worst averages are equal,
// drop worstIdx so no chip shows a "worst" highlight when
// all non-null weekdays share the same duration.
if (bestIdx != null && worstIdx != null && bestAvg == worstAvg) {
  worstIdx = null;
}
// The existing single-index guard below remains:
if (bestIdx != null && bestIdx == worstIdx) {
  worstIdx = null;
}
```

### WR-02: BestWorstDayCard does not guard against `weekdayAverages` list length < 5

**File:** `lib/features/stats/widgets/best_worst_day_card.dart:63-70`

**Issue:** The widget reads `weekdayAverages[i]` for `i` in `0..<5` without checking that the list has at least 5 elements. `StatsSummary.weekdayAverages` is always length 7 (built via `List<int?>.generate(7, ...)` in the service), but the `BestWorstDayCard` constructor accepts an arbitrary `List<int?>` — nothing prevents a caller from passing a shorter list, which would throw a `RangeError` at runtime.

**Fix:**
Add an assertion in the constructor to document and enforce the contract:
```dart
const BestWorstDayCard({
  required this.weekdayAverages,
  super.key,
}) : assert(
       weekdayAverages.length >= 5,
       'weekdayAverages must have at least 5 entries (Mon–Fri)',
     );
```

Alternatively, clamp the loop upper bound: `for (var i = 0; i < weekdayAverages.length.clamp(0, 5); i++)`.

### WR-03: TrendChartCard's `BarAreaData()` produces an unintentional transparent fill under the line

**File:** `lib/features/stats/widgets/trend_chart_card.dart:114`

**Issue:** `belowBarData: BarAreaData()` creates a `BarAreaData` with `show: false` by default in fl_chart, so at first glance this is harmless — but on fl_chart `^0.66+` the default constructor sets `show: true`, which fills the area below the line with the default colour (semi-transparent `Colors.blueAccent`). Whether `show` defaults to `true` or `false` depends on the exact fl_chart version resolved. The intent here is clearly "no fill" (the comment says "Interaction: disabled"), but the fill area is a visual concern, not an interaction one. If `show` defaults to `true` in the resolved version, every chart renders with an unwanted semi-transparent blue area that clashes with `colorScheme.primary`.

**Fix:**
Be explicit:
```dart
belowBarData: BarAreaData(show: false),
```

### WR-04: `stats_screen_test.dart` "renders weekly duration" test is time-sensitive and will flap on Mondays before the trip is recorded

**File:** `test/widget/features/stats/stats_screen_test.dart:106-123`

**Issue:** The test constructs a trip with `startTime: DateTime.now()` and then relies on `statsSummaryProvider` computing against `DateTime.now()` inside `whenData`. On the vast majority of runs this is fine. However if the test runs within the same second that a week boundary crosses (Sunday 23:59:59 → Monday 00:00:00), `DateTime.now()` in the trip factory and `DateTime.now()` inside the provider could fall on opposite sides of the `weekStart` boundary, causing `weekTotalSeconds == 0` and the card to render `kStatsEmptyPlaceholder` instead of a duration. The test would then fail spuriously. The comment in the test acknowledges the time-sensitivity but still relies on `DateTime.now()`.

Beyond the boundary edge, `kStatsCardWeekHelper` (`'Mon–Sun'`) is always rendered once the card is present regardless of whether the value is empty or not, so the assertion is not actually validating that the trip was counted. The test should verify the computed duration.

**Fix:**
Pin `startTime` to a fixed weekday in the current week so the trip is always in-week relative to any test-runner date, or — better — pass a fake `DateTime` directly to `computeStatsSummary` in a unit test rather than relying on widget-level time coupling:
```dart
testWidgets('renders weekly duration when trips exist', (tester) async {
  // Pin trip to the current Monday so it is guaranteed in-week.
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - DateTime.monday));
  final pinnedTrip = _trip(
    DateTime(monday.year, monday.month, monday.day, 8),
    durationSeconds: 1800,
  );
  await tester.pumpWidget(buildScreen(trips: [pinnedTrip]));
  await tester.pump();
  // Now assert the actual computed value is non-empty.
  expect(find.text(kStatsEmptyPlaceholder), findsNothing);
  expect(find.text(kStatsCardWeekHelper), findsOneWidget);
});
```

## Info

### IN-01: Magic number `1 << 30` in BestWorstDayCard

**File:** `lib/features/stats/widgets/best_worst_day_card.dart:38`

**Issue:** `var bestAvg = 1 << 30` is an ad-hoc sentinel for "infinity". While the intent is clear from context, CLAUDE.md requires no magic numbers. A named constant or `double.maxFinite.toInt()` would be clearer.

**Fix:**
```dart
const int _kMaxDurationSentinel = 1 << 30; // ~1.07 billion seconds; no real trip is this long
var bestAvg = _kMaxDurationSentinel;
```
Or simply use `var bestAvg = double.maxFinite.toInt();`.

### IN-02: Redundant non-null assertion in `DirectionAveragesCard`

**File:** `lib/features/stats/widgets/direction_averages_card.dart:66`

**Issue:** On line 66, `formatDuration(valueSeconds!)` uses `!` after the `null` guard `valueSeconds == null ? ... : formatDuration(valueSeconds!)`. The `else` branch is only reached when `valueSeconds != null`, so the `!` is redundant. Dart's flow analysis should handle this without the assertion.

**Fix:**
```dart
final value = valueSeconds == null
    ? kStatsEmptyPlaceholder
    : formatDuration(valueSeconds);
```

### IN-03: `handleDeleteTrip` is a dead public method on `HomeScreen`

**File:** `lib/features/tracking/screens/home_screen.dart:167-171`

**Issue:** `HomeScreen.handleDeleteTrip` is a public instance method (no leading underscore) that is never called from within `HomeScreen` itself and is not part of any declared interface. It exists purely to delegate to `trip_actions.handleDeleteTrip`. There is no route or widget in the reviewed files that accesses this method via a `HomeScreen` reference. If it is only called through `trip_actions.handleDeleteTrip` everywhere else, the delegation method on `HomeScreen` is dead code.

**Fix:** Remove the method from `HomeScreen`, or if it is genuinely called by something outside the reviewed scope, add a comment explaining the callsite.

### IN-04: Unit test file header comment refers to `UnimplementedError stub`

**File:** `test/unit/features/stats/stats_service_test.dart:6`

**Issue:** The comment on line 6 reads `"Plan 05-02 (Wave 1) replaces the UnimplementedError stub with the real single-pass implementation; until then every test here is RED."` The implementation has shipped, so every test in this file is GREEN. This comment is now stale and misleading — a reader will not know whether to expect red or green.

**Fix:** Remove or update the comment to reflect the current state:
```dart
// Pure-data tests for the single-pass computeStatsSummary implementation.
// No Drift, no widget, no Riverpod.
```

### IN-05: `WeekMonthTotalsCard` has no helper text for the monthly total (asymmetric with weekly helper)

**File:** `lib/features/stats/widgets/week_month_totals_card.dart:58-70`

**Issue:** The weekly total renders `kStatsCardWeekHelper` ("Mon–Sun") below it to clarify the date boundary. The monthly total has no equivalent helper text. This is an asymmetry: a user can see what "This week" means from the helper, but has no visual cue about which calendar month "This month" refers to. This is a minor UX gap that may become confusing in the first few days of a new month.

**Fix:** Add a helper text below the monthly total using `intl`'s `DateFormat.MMMM()`:
```dart
Text(
  DateFormat.MMMM().format(DateTime.now()),
  style: textTheme.bodyMedium?.copyWith(
    color: colorScheme.onSurfaceVariant,
  ),
),
```
Or add a constant `kStatsCardMonthHelper` if the display format should be locked rather than computed at render time.

---

_Reviewed: 2026-04-26T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
