# Phase 5: Stats & Analytics - Research

**Researched:** 2026-04-26
**Domain:** Flutter/Dart pure-data computation, fl_chart LineChart, Riverpod 3.x derived providers, locale-aware date math
**Confidence:** HIGH

## Summary

Phase 5 adds a single `/stats` screen that computes five stats (weekly/monthly totals, direction averages, best/worst weekday, 4-week trend, weekly traffic waste) entirely in pure Dart by subscribing to the existing `allTripSummariesProvider` `StreamProvider<List<TripSummary>>`. No new DAO methods, no new database queries, no network calls. The screen is read-only and renders inside the existing `MaterialApp` with no theme overrides.

The two non-trivial concerns are: (1) date-bucketing math that has to convert UTC `TripSummary.startTime` into the device's local timezone before computing calendar-week / calendar-month / day-of-week / 28-day-window membership, and (2) `fl_chart 1.2.0`'s `LineChart` API for rendering 28 daily totals with 4 week-level x-axis labels. Both are well-understood — the codebase already has the timezone conversion pattern (`history_providers.dart:31`) and `fl_chart` is the canonical Flutter charting library with stable APIs.

**Primary recommendation:** Add `fl_chart: ^1.2.0` to `pubspec.yaml`, implement a single `Provider<AsyncValue<StatsSummary>>` that watches `allTripSummariesProvider` and calls a pure top-level function `computeStatsSummary(List<TripSummary>, DateTime nowLocal)` to produce an immutable `StatsSummary`. Cards consume sub-fields off the same `AsyncValue`. Test the pure function exhaustively against `List<TripSummary>` literals — no fake DB needed.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Reactive stat recomputation | Riverpod provider layer | Drift (data source) | `StreamProvider` re-emits on every Drift change; pure function recomputes |
| Pure stat math (no I/O) | Pure Dart layer (`lib/features/stats/services/`) | — | Deterministic, no Drift/widget context, fully unit-testable |
| Period/timezone bucketing | Pure Dart layer | — | All UTC→local conversion happens once, inline with stat computation |
| Chart rendering | Flutter UI tier (widget) | fl_chart package | `TrendChartCard` consumes `StatsSummary.dailyTotals` and renders `LineChart` |
| Empty/error/loading branches | Flutter UI tier | — | `AsyncValue.when` at screen root, single dispatch (no per-card flicker) |
| Home-screen entry point | Flutter UI tier (existing widget) | — | One additional `OutlinedButton` in `home_screen.dart` |

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Single scrollable page with M3 cards stacked vertically. Card order: (1) Week/Month totals, (2) Direction averages, (3) Best/worst day, (4) 4-week trend, (5) Time in traffic this week.
- **D-02:** "View stats" `OutlinedButton` on home screen below "View history" — same `FractionallySizedBox(widthFactor: 0.7)` wrapper, 12px gap.
- **D-03:** "Current week" = Mon–Sun calendar week. Stats reset on Monday.
- **D-04:** "Current month" = calendar month (1st through last of month).
- **D-05:** Manual entries are **included** in STAT-01..04 time stats. **Excluded** from STAT-05 traffic waste because their `timeMovingSeconds`/`timeStuckSeconds` are 0.
- **D-06:** All stats computed in pure Dart inside a single Riverpod `StreamProvider`. Subscribe to `watchAllSummaries()`. Single-pass computation produces all 5 stats at once. No new DAO methods.
- **D-07:** Trend chart data point = total commute time per calendar day (sum of all `durationSeconds` on that day). Single combined line — not split by direction. 28-day window ending today inclusive.
- **D-08:** X-axis = 4 week labels only: "Week 1", "Week 2", "Week 3", "This week". No per-day ticks.
- **D-09:** Best/worst day = average commute duration per weekday Mon–Fri across all trips ever recorded. No minimum threshold. Sat/Sun excluded.
- **D-10:** Empty state = `—` (em-dash) in each card's value slot. No full-screen empty state. Cards remain structurally intact.
- **UI-SPEC §Discretion:**
  - Trend chart days with no trips render as `0` value (flat baseline), not gaps.
  - Provider granularity: ONE `StreamProvider<StatsSummary>` (or `Provider<AsyncValue<StatsSummary>>` derived from `allTripSummariesProvider` — see Pattern 1 below).
  - File names locked: `screens/stats_screen.dart`, `widgets/{stats_card,week_month_totals_card,direction_averages_card,best_worst_day_card,trend_chart_card,traffic_waste_card}.dart`, `providers/stats_providers.dart`.

### Claude's Discretion
- Exact Material 3 card styling, padding, typography (within UI-SPEC token tables).
- Whether the stats provider is a fresh `StreamProvider<StatsSummary>` or a `Provider<AsyncValue<StatsSummary>>` derived from the existing `allTripSummariesProvider`. **Recommendation: derive (see Pattern 1).** Avoids two parallel subscriptions on `watchAllSummaries()`.
- Whether to extract `computeStatsSummary` into `lib/features/stats/services/` (recommended) or keep it inside the provider file. **Recommendation: extract** — it's pure Dart and the test file has no Riverpod dependency.
- Visual treatment of best/worst chips — UI-SPEC already locks colors and icons.
- Whether to add `RefreshIndicator` for the error state (UI-SPEC defers to planner — **default: don't add**, matches HistoryScreen).

### Deferred Ideas (OUT OF SCOPE)
- Average trip distance — `distanceMeters` available but not in STAT-01..05.
- Month-over-month comparison — ANLYT-01, v2 only.
- Interactive trend chart (tap to reveal date+value) — `LineTouchData(enabled: false)` per UI-SPEC §Interaction.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STAT-01 | Weekly and monthly total commute time | Pure Dart sum of `durationSeconds` filtered by Mon–Sun calendar week / calendar month — see Pattern 2. |
| STAT-02 | Average commute duration split by direction | Pure Dart group-by `direction` (`kDirectionToOffice`/`kDirectionToHome`), sum/count per group, divide. Empty group → return `null`/sentinel for D-10 placeholder. |
| STAT-03 | Best/worst commute day of the week | Pure Dart group-by local weekday (Mon–Fri only), avg per weekday. Best = lowest avg, worst = highest. With zero qualifying trips, all chips render unstyled. |
| STAT-04 | 4-week trend line | Build `Map<int, int>` keyed by `daysAgo` (0..27) → total seconds; produce 28 `FlSpot(x, totalMinutes)` for `LineChart`. X-axis labels at positions 3.5, 10.5, 17.5, 24.5 (week midpoints) using `SideTitles.getTitlesWidget`. |
| STAT-05 | Weekly time wasted in traffic | Pure Dart sum of `timeStuckSeconds` over current Mon–Sun, filtered to `!isManualEntry` (D-05). |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `fl_chart` | `^1.2.0` | LineChart for STAT-04 trend | [VERIFIED: pub.dev API 2026-04-26] Latest stable, published 2026-03-13. Requires Flutter ≥3.27.4 (we have 3.41.6 — compatible). Already named in CLAUDE.md as the canonical chart lib. |
| `flutter_riverpod` | `^3.3.1` (in `pubspec.yaml`) | Provider for derived stats | [VERIFIED: pubspec.yaml] Already installed. `Provider`, `StreamProvider`, `AsyncValue.whenData` are all stable Riverpod 3.x APIs. |
| `intl` | `^0.20.2` (in `pubspec.yaml`) | Locale-aware weekday names | [VERIFIED: pubspec.yaml] Already installed; used by `trip_card.dart` and `history_providers.dart`. `DateFormat.E()` returns short weekday name in current locale. |
| `drift` | `^2.32.1` (in `pubspec.yaml`) | `TripsDao.watchAllSummaries()` consumer | [VERIFIED: pubspec.yaml] No new DAO work — Phase 5 reuses the existing stream. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `flutter_test` | (sdk) | Unit + widget tests for stats math and screen | Test the pure `computeStatsSummary` against `List<TripSummary>` literals (no DB). |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `fl_chart 1.2.0` | `fl_chart 0.69.x` (UI-SPEC default) | UI-SPEC says `^0.69` based on Phase 0 research data. The `0.69 → 1.2` series introduced `SideTitleWidget(meta: meta, ...)` instead of `axisSide`/`axisType`, and `LineTouchTooltipData.getTooltipColor` instead of `tooltipBgColor`. **Recommend `^1.2.0`** — breaking changes are mostly at the title/tooltip API surface that we partially use. Either works for our minimal trend chart, but pinning to the latest avoids re-pinning later. **DECISION FOR PLANNER:** confirm `^1.2.0` vs `^0.69` with the user before pubspec edit. |
| Derived `Provider<AsyncValue<StatsSummary>>` | Fresh `StreamProvider<StatsSummary>` watching `tripsDaoProvider` directly | Fresh provider duplicates the Drift subscription; derived provider reuses `allTripSummariesProvider`'s emissions. **Recommend derived** — single source of truth, simpler test overrides. |
| `fl_chart` `LineChart` | `BarChart` for daily totals | Locked: UI-SPEC requires line. STAT-04 explicitly says "trend line". |

**Installation:**
```bash
flutter pub add fl_chart
```

Verify in `pubspec.yaml` after add — `fl_chart` is the only new dependency.

**Version verification:**
- `fl_chart 1.2.0` — published `2026-03-13T20:46:03Z`, latest stable [VERIFIED: pub.dev API at https://pub.dev/api/packages/fl_chart, 2026-04-26]
- Compatible with `sdk ^3.11.4` (pubspec.yaml constraint) — fl_chart needs `sdk >=3.6.2 <4.0.0` ✓

## Architecture Patterns

### System Architecture Diagram

```
                ┌────────────────────────────────┐
                │  Drift trips table             │
                │  (single source of truth)      │
                └──────────────┬─────────────────┘
                               │ watchAllSummaries() Stream
                               ▼
            ┌──────────────────────────────────────┐
            │  allTripSummariesProvider             │
            │  StreamProvider<List<TripSummary>>    │
            │  (existing, from Phase 4)             │
            └──────────────┬───────────────────────┘
                           │ ref.watch (AsyncValue<List<TripSummary>>)
                           ▼
            ┌──────────────────────────────────────┐
            │  statsSummaryProvider                  │
            │  Provider<AsyncValue<StatsSummary>>   │
            │                                        │
            │   .whenData((trips) =>                │
            │       computeStatsSummary(             │
            │         trips,                         │
            │         DateTime.now()))               │
            └──────────────┬───────────────────────┘
                           │ ref.watch
                           ▼
            ┌──────────────────────────────────────┐
            │  StatsScreen (ConsumerWidget)         │
            │   asyncStats.when(                    │
            │     data: (s) => ListView of cards,   │
            │     loading: CircularProgressInd...,  │
            │     error: error text)                │
            └──┬───────────┬───────────┬───────────┘
               │           │           │
               ▼           ▼           ▼
        WeekMonth   Direction   TrendChartCard ──► fl_chart LineChart
        TotalsCard  AveragesCard  (28 FlSpots, 4 x-axis labels)
                                  BestWorstDayCard, TrafficWasteCard
```

Data flows one-way: Drift → existing StreamProvider → derived stats Provider → screen → cards. No card subscribes directly to Drift.

### Recommended Project Structure
```
lib/features/stats/
├── providers/
│   └── stats_providers.dart      # statsSummaryProvider + StatsSummary class
├── services/
│   └── stats_service.dart        # computeStatsSummary() pure function
├── screens/
│   └── stats_screen.dart         # ConsumerWidget, Scaffold + ListView of cards
└── widgets/
    ├── stats_card.dart           # base card wrapper (title + body + sub-label)
    ├── week_month_totals_card.dart
    ├── direction_averages_card.dart
    ├── best_worst_day_card.dart
    ├── trend_chart_card.dart     # fl_chart LineChart
    └── traffic_waste_card.dart

test/unit/features/stats/
└── stats_service_test.dart       # pure function tests, no DB

test/widget/features/stats/
└── stats_screen_test.dart        # ProviderScope override pattern
```

This mirrors the existing `lib/features/trips/` and `lib/features/tracking/` layout (CONTEXT code_context §2). UI-SPEC §Component Inventory locks the file names; the only addition here is the `services/stats_service.dart` extraction (Claude's discretion — recommended for testability).

### Pattern 1: Derived Provider with `whenData`

**What:** Define `statsSummaryProvider` as a `Provider<AsyncValue<StatsSummary>>` that watches `allTripSummariesProvider` and transforms `AsyncValue<List<TripSummary>>` into `AsyncValue<StatsSummary>` via `whenData`.

**When to use:** Always, for derived/computed reactive values. Avoids duplicate Drift subscriptions.

**Example:**
```dart
// Source: AsyncValue API at https://pub.dev/documentation/riverpod/latest/riverpod/AsyncValue/whenData.html
// File: lib/features/stats/providers/stats_providers.dart

final Provider<AsyncValue<StatsSummary>> statsSummaryProvider =
    Provider<AsyncValue<StatsSummary>>(
      (ref) {
        final asyncTrips = ref.watch(allTripSummariesProvider);
        return asyncTrips.whenData(
          (trips) => computeStatsSummary(trips, DateTime.now()),
        );
      },
      name: 'statsSummaryProvider',
    );
```

`whenData` preserves loading/error states unchanged and applies the function only when data is present. The screen consumes this with `asyncStats.when(data:..., loading:..., error:...)` exactly like `HistoryScreen` (`history_screen.dart:81`).

**Important:** `DateTime.now()` is evaluated every time `allTripSummariesProvider` re-emits. This is correct — the Mon/midnight rollover is computed using "now" at the moment of recomputation. For tests, inject `DateTime` via an optional second positional parameter on `computeStatsSummary` (Pattern 4).

### Pattern 2: Calendar-Week Bucketing (Mon–Sun, Local TZ)

**What:** Compute the start of the current Mon–Sun calendar week, then sum trips whose local-date `startTime` falls in `[weekStart, weekEnd)`.

**When to use:** STAT-01 weekly total, STAT-05 weekly traffic waste.

**Example:**
```dart
/// Returns local-time midnight of the Monday that begins the calendar
/// week containing [now]. Dart's [DateTime.weekday] uses Mon=1, Sun=7.
DateTime startOfWeek(DateTime now) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day); // strip time
  final daysSinceMonday = today.weekday - DateTime.monday;    // 0..6
  return today.subtract(Duration(days: daysSinceMonday));
}

DateTime startOfMonth(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month);
}

bool isInCurrentWeek(DateTime tripStartUtc, DateTime now) {
  final tripLocal = tripStartUtc.toLocal();
  final weekStart = startOfWeek(now);
  final weekEnd = weekStart.add(const Duration(days: 7));
  return !tripLocal.isBefore(weekStart) && tripLocal.isBefore(weekEnd);
}
```

**Why this works:**
- `DateTime.weekday` is **always Mon=1..Sun=7** regardless of locale [VERIFIED: dart:core docs at https://api.dart.dev/stable/dart-core/DateTime/weekday.html]. Locale only affects `DateFormat.E()` display strings.
- Stripping time via `DateTime(year, month, day)` produces a local-time midnight that is timezone-stable for date math.
- `tripStartUtc.toLocal()` honors the device's current TZ — this matches the existing pattern in `history_providers.dart:31`.

### Pattern 3: 28-Day Window for Trend (STAT-04)

**What:** Build a `List<int>` of length 28 where index 0 = today, index 27 = 27 days ago, value = total seconds for that calendar day.

**Example:**
```dart
List<int> dailyTotalsLast28Days(List<TripSummary> trips, DateTime now) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final totals = List<int>.filled(28, 0);
  for (final trip in trips) {
    final tripLocal = trip.startTime.toLocal();
    final tripDate = DateTime(tripLocal.year, tripLocal.month, tripLocal.day);
    final daysAgo = today.difference(tripDate).inDays;
    if (daysAgo >= 0 && daysAgo < 28) {
      totals[daysAgo] += trip.durationSeconds;
    }
  }
  return totals;
}
```

**Why `inDays` is safe here:** Both `today` and `tripDate` are timezone-local midnights (no time component). `Duration.inDays` floors to whole days. Even across DST boundaries, the difference between two local midnights is always a whole number of 24h-multiples (`Duration` is in microseconds; DST creates 23h or 25h days but `inDays` truncates) — but **see Pitfall 4** for the DST edge case.

**Mapping to FlSpots for fl_chart:**
```dart
// Spot at x=0 is 27 days ago (left edge), x=27 is today (right edge).
// We reverse so the chart reads left-to-right chronologically.
final spots = List<FlSpot>.generate(
  28,
  (i) => FlSpot(i.toDouble(), totals[27 - i] / 60.0), // y = minutes
);
```

X-axis labels at week midpoints: positions 3.5, 10.5, 17.5, 24.5. See Pattern 5 for SideTitles config.

### Pattern 4: Pure Stats Function with Injectable `now`

**What:** Top-level `computeStatsSummary(List<TripSummary> trips, DateTime now)` — fully deterministic, no `DateTime.now()` inside, no DB, no widget.

**Example:**
```dart
// File: lib/features/stats/services/stats_service.dart

/// Compute all five Phase 5 stats in a single pass.
///
/// [now] is injected so tests can pin a fixed instant. Production
/// callers pass `DateTime.now()` from the provider (Pattern 1).
StatsSummary computeStatsSummary(
  List<TripSummary> trips,
  DateTime now,
) {
  final weekStart = startOfWeek(now);
  final weekEnd = weekStart.add(const Duration(days: 7));
  final monthStart = startOfMonth(now);
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1);

  // Single pass: tally every aggregate at once.
  var weekTotalSeconds = 0;
  var monthTotalSeconds = 0;
  var weekStuckSeconds = 0;
  final dirTotals = <String, int>{kDirectionToOffice: 0, kDirectionToHome: 0};
  final dirCounts = <String, int>{kDirectionToOffice: 0, kDirectionToHome: 0};
  final weekdayTotals = List<int>.filled(7, 0);   // index = weekday-1
  final weekdayCounts = List<int>.filled(7, 0);
  final dailyTotalsLast28 = List<int>.filled(28, 0);

  final today = DateTime(now.toLocal().year, now.toLocal().month, now.toLocal().day);

  for (final trip in trips) {
    final local = trip.startTime.toLocal();
    final dateOnly = DateTime(local.year, local.month, local.day);

    // Week
    if (!local.isBefore(weekStart) && local.isBefore(weekEnd)) {
      weekTotalSeconds += trip.durationSeconds;
      if (!trip.isManualEntry) {
        weekStuckSeconds += trip.timeStuckSeconds;
      }
    }
    // Month
    if (!local.isBefore(monthStart) && local.isBefore(monthEnd)) {
      monthTotalSeconds += trip.durationSeconds;
    }
    // Direction (all trips ever recorded)
    if (dirTotals.containsKey(trip.direction)) {
      dirTotals[trip.direction] = dirTotals[trip.direction]! + trip.durationSeconds;
      dirCounts[trip.direction] = dirCounts[trip.direction]! + 1;
    }
    // Weekday (Mon–Fri only — D-09)
    final weekday = local.weekday; // 1..7
    if (weekday >= DateTime.monday && weekday <= DateTime.friday) {
      weekdayTotals[weekday - 1] += trip.durationSeconds;
      weekdayCounts[weekday - 1] += 1;
    }
    // 28-day window
    final daysAgo = today.difference(dateOnly).inDays;
    if (daysAgo >= 0 && daysAgo < 28) {
      dailyTotalsLast28[daysAgo] += trip.durationSeconds;
    }
  }

  return StatsSummary(
    weekTotalSeconds: weekTotalSeconds,
    monthTotalSeconds: monthTotalSeconds,
    toOfficeAvgSeconds: dirCounts[kDirectionToOffice]! == 0
        ? null
        : dirTotals[kDirectionToOffice]! ~/ dirCounts[kDirectionToOffice]!,
    toHomeAvgSeconds: dirCounts[kDirectionToHome]! == 0
        ? null
        : dirTotals[kDirectionToHome]! ~/ dirCounts[kDirectionToHome]!,
    weekdayAverages: List<int?>.generate(
      7,
      (i) => weekdayCounts[i] == 0 ? null : weekdayTotals[i] ~/ weekdayCounts[i],
    ),
    dailyTotalsLast28Days: dailyTotalsLast28,
    weekStuckSeconds: weekStuckSeconds,
    hasAnyTrips: trips.isNotEmpty,
  );
}
```

**Why injectable `now`:**
- Tests can pin `now` to a specific instant and assert exact stat values.
- Production code calls `computeStatsSummary(trips, DateTime.now())` from inside `whenData`.
- Avoids `clock` package — Dart's stdlib `DateTime` is sufficient.

### Pattern 5: fl_chart LineChart with 4 X-Axis Week Labels

**What:** Render `LineChart` with 28 `FlSpot`s and exactly 4 x-axis week-level labels at positions 3.5, 10.5, 17.5, 24.5.

**Example:**
```dart
// Source: https://github.com/imaNNeo/fl_chart/blob/main/example/lib/presentation/samples/line/line_chart_sample1.dart
// Adapted for Phase 5 (28-day window, 4 week labels, no touch interactions).

LineChart(
  LineChartData(
    minX: 0,
    maxX: 27,
    minY: 0,
    // maxY auto-calculated from spots.
    lineTouchData: const LineTouchData(enabled: false), // UI-SPEC: read-only
    gridData: const FlGridData(show: false),
    borderData: FlBorderData(show: false),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false), // y-axis hidden per UI-SPEC simplicity
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: 1, // fl_chart calls getTitlesWidget per integer x value
          getTitlesWidget: (value, meta) {
            // Return SizedBox.shrink() for non-label x positions.
            const labels = <int, String>{
              3: 'Week 1',  // ~mid of leftmost week (days 0..6)
              10: 'Week 2', // ~mid of days 7..13
              17: 'Week 3', // ~mid of days 14..20
              24: 'This week', // ~mid of days 21..27
            };
            final label = labels[value.toInt()];
            if (label == null) return const SizedBox.shrink();
            return SideTitleWidget(
              meta: meta,
              child: Text(label, style: Theme.of(context).textTheme.labelMedium),
            );
          },
        ),
      ),
    ),
    lineBarsData: [
      LineChartBarData(
        spots: spots, // List<FlSpot> length 28
        isCurved: false,
        color: Theme.of(context).colorScheme.primary,
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) =>
              FlDotCirclePainter(
                radius: 2,
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 0,
              ),
        ),
        belowBarData: BarAreaData(show: false),
      ),
    ],
  ),
);
```

**Notes:**
- `interval: 1` + `getTitlesWidget` returning `SizedBox.shrink()` for unwanted positions is the documented way to render only specific x labels [CITED: fl_chart sample1.dart].
- `LineTouchData(enabled: false)` disables tooltip + ripple (UI-SPEC §Interaction).
- Use `Theme.of(context).colorScheme.primary` — never raw hex (UI-SPEC §Color).
- `fl_chart 1.2.0` requires `SideTitleWidget(meta: meta, child: ...)` — older versions used `axisSide`/`axisType`. **Pin version carefully.**
- The 28-spot chart with `FlDotData(show: true)` shows a circle at each day. Set `radius: 2` to keep them subtle (vs default 4) — discretion.

### Pattern 6: Locale-Aware Day Chip Labels

**What:** Use `intl`'s `DateFormat.E()` to derive "Mon", "Tue", etc., for the BestWorstDayCard chips.

**Example:**
```dart
// Build five "anchor" dates that fall on Mon..Fri (the actual date does not
// matter — only weekday matters). 2024-01-01 is a Monday in the Gregorian
// calendar [VERIFIED: 2024-01-01 == Monday].
final anchors = List<DateTime>.generate(
  5,
  (i) => DateTime(2024, 1, 1 + i), // Mon, Tue, Wed, Thu, Fri
);
final labels = anchors.map(DateFormat.E().format).toList();
// In en_US: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']
```

This matches UI-SPEC §Copywriting Contract (do NOT hardcode weekday strings; tests pin locale to `en_US`).

### Anti-Patterns to Avoid
- **Don't** create a new DAO method for stats. `watchAllSummaries()` already provides everything; CONTEXT D-06 explicitly forbids a new aggregate query.
- **Don't** subscribe to `tripsDaoProvider.watchAllSummaries()` from a fresh `StreamProvider`. Reuse the existing `allTripSummariesProvider`.
- **Don't** call `DateTime.now()` inside `computeStatsSummary` — inject it for testability.
- **Don't** compute stats inside the widget `build` method. The provider does it once per stream emission; widgets just read fields.
- **Don't** strip the time component from a UTC `DateTime` and assume it represents a local date — convert to local first (`history_providers.dart:31` is the canonical pattern).
- **Don't** put `LineTouchData()` with default arguments — touch is enabled by default. Phase 5 requires `LineTouchData(enabled: false)`.
- **Don't** wrap stat cards in `InkWell` (UI-SPEC §Interaction: cards are read-only).
- **Don't** use `dart:ui` `Color(0xFF...)` literals — every color from `Theme.of(context).colorScheme`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Charting | Custom `CustomPainter` line chart | `fl_chart LineChart` | fl_chart handles axis ticks, animations, touch detection, dots, layout. Reinventing produces months of polishing edge cases (text positioning, scaling, accessibility). |
| Date math (week start, month start) | Hand-rolled day-of-week tables | Dart `DateTime.weekday` + arithmetic | Dart stdlib `weekday` is locale-independent (always Mon=1..Sun=7). Don't pull a date library — overkill for our needs. |
| Locale-aware weekday names | Hardcoded `'Mon'`, `'Tue'`, etc. | `intl` `DateFormat.E()` | UI-SPEC §Copywriting forbids hardcoding; `intl` is already in the project. |
| Computed reactive provider | Manual `Stream.transform()` or a new `StreamController` | Riverpod `Provider<AsyncValue<T>>` + `whenData` | The `whenData` pattern preserves loading/error states automatically; manual stream code re-implements that. |
| Empty-state placeholder | `if (count == 0) return Text('No data')` everywhere | `StatsSummary` exposes `int?` fields; widget renders `kStatsEmptyPlaceholder` for null | UI-SPEC §Copywriting locks `'—'` as the only empty marker; centralizing it in the model keeps cards consistent. |

**Key insight:** Phase 5 is genuinely tiny — **one new dependency** (`fl_chart`), **one new provider**, **one pure function**, **six widget files**, **two test files**. The temptation to over-engineer (custom date utilities, multiple providers, a stats DAO) must be resisted. CONTEXT D-06 already locked the simplest possible architecture.

## Common Pitfalls

### Pitfall 1: UTC `startTime` Buckets in Wrong Calendar Day
**What goes wrong:** A trip starting at 23:30 local time may have a UTC `startTime` of 04:30 the next day (or vice versa). If you compute `trip.startTime.weekday` directly (without `toLocal()`), you'll bucket trips into the wrong day, week, or month.
**Why it happens:** `TripSummary.startTime` is documented as UTC (`trips_dao.dart:39`); `DateTime.weekday` reflects whatever timezone the DateTime is in.
**How to avoid:** **Always** call `.toLocal()` before extracting day/week/month. The codebase pattern is `final local = trip.startTime.toLocal(); final dateOnly = DateTime(local.year, local.month, local.day);` (`history_providers.dart:31`). Apply this in every loop iteration in `computeStatsSummary`.
**Warning signs:** Trip recorded at 11pm shows up in tomorrow's "today" total. Test with a trip whose UTC date differs from local date.

### Pitfall 2: Division by Zero on Empty Direction / Weekday
**What goes wrong:** A user with zero "to_home" trips would crash on `total / count` when computing STAT-02. Same for STAT-03 if they've only ever commuted on Tuesdays.
**Why it happens:** Dart's integer `~/` throws `IntegerDivisionByZeroException`; double `/` returns `Infinity`/`NaN` and corrupts the chart.
**How to avoid:** Guard every average: `count == 0 ? null : total ~/ count`. Use `int?` in `StatsSummary` for fields that can be empty (avg fields, weekday averages). Card widget renders `kStatsEmptyPlaceholder` (`'—'`) when null.
**Warning signs:** "Stats screen crashes for new users" or "card shows ∞ minutes". Test case: empty `List<TripSummary>` and `List<TripSummary>` with one trip whose direction is `kDirectionToOffice` only.

### Pitfall 3: Manual Entries Skewing Traffic Waste (D-05)
**What goes wrong:** Manual trips have `timeStuckSeconds == 0` (no GPS to measure speed). Including them in STAT-05 averages a real traffic figure with synthetic zeroes, making the user think their commute is less stuck than it actually is.
**Why it happens:** Easy to forget the `!isManualEntry` filter when summing `timeStuckSeconds` because the same trip IS included in the duration totals (D-05 says manual entries count for time but not for traffic).
**How to avoid:** Apply the `!trip.isManualEntry` guard ONLY for the `weekStuckSeconds` accumulator. All other accumulators in the loop count manual entries normally. **Test case:** mix of manual and GPS trips in the same week; assert weekTotal includes both, weekStuck excludes manual.
**Warning signs:** A user who logs many manual trips reports "traffic time looks low".

### Pitfall 4: DST Boundary in 28-Day Window
**What goes wrong:** `today.difference(tripDate).inDays` over a DST transition can off-by-one because `Duration` is in microseconds and DST shifts a "day" to 23 or 25 hours of wall clock time. If `today` and `tripDate` straddle a DST boundary, `inDays` may truncate to 26 instead of 27.
**Why it happens:** `DateTime(year, month, day)` constructs a local-time midnight. Across a DST forward jump, two consecutive midnights are 23h apart, so `Duration.inDays` returns 0 instead of 1 for that pair, but the cumulative effect over 28 days flips one boundary.
**How to avoid:** Use the `weekday-difference / 7` approach by counting **calendar days**, not microsecond differences. Safer formulation:
```dart
int daysBetweenLocalDates(DateTime laterMidnight, DateTime earlierMidnight) {
  // Both args MUST be local midnights produced by DateTime(y, m, d).
  // toUtc() turns wall-clock midnight into a TZ-anchored UTC instant;
  // the difference is then a whole-day count regardless of DST.
  final aUtc = DateTime.utc(laterMidnight.year, laterMidnight.month, laterMidnight.day);
  final bUtc = DateTime.utc(earlierMidnight.year, earlierMidnight.month, earlierMidnight.day);
  return aUtc.difference(bUtc).inDays;
}
```
**Warning signs:** In US/Europe TZ users, on the day after DST starts/ends, a trip from "yesterday" appears in the wrong column of the trend chart. **Confidence: MEDIUM** — Dart's `Duration.inDays` documentation [CITED: https://api.dart.dev/stable/dart-core/Duration/inDays.html] says "the number of entire days spanned by this Duration"; the two-`DateTime.utc(y, m, d)` construction sidesteps the issue. Recommend using this helper inside `computeStatsSummary`.

### Pitfall 5: `LineChart` minY Default Hides Zero Baseline
**What goes wrong:** When all 28 days have small values (e.g., 5–10 minutes), `fl_chart` auto-scales `minY` to ~5, so a zero-trip day looks like a steep dip rather than a flat baseline.
**Why it happens:** `LineChartData` auto-fits the y-axis to the data extent if `minY` is unset.
**How to avoid:** Set `minY: 0` explicitly. UI-SPEC §Discretion §1 says zero days render as flat baseline — `minY: 0` ensures that.
**Warning signs:** Trend chart shows wild swings even when all days are similar.

### Pitfall 6: Chart Re-Renders on Every Stream Emission
**What goes wrong:** `allTripSummariesProvider` re-emits whenever any row in `trips` changes (Drift `watch()` fires on table writes). If the user navigates away from `/stats` mid-tracking, the chart re-renders dozens of times per minute as GPS samples accumulate (Phase 2 logic). Each rebuild repaints `fl_chart`.
**Why it happens:** Drift streams are extremely chatty. The base chart cost is ~few ms per build, which is fine for occasional updates but visible if many emissions queue up in the background.
**How to avoid:** This is mostly OK for Phase 5 because the stats screen isn't visible during tracking. Confirm: when the user is on `/tracking` (foreground), they cannot also be on `/stats`. **However**, the provider DOES still recompute (`computeStatsSummary` is O(n) over all trips) every time. Mitigation if it shows up later: switch the provider to `select` only on count/last-id of trips, or debounce. **Don't pre-optimize for Phase 5.**
**Warning signs:** Frame jank visible on the stats screen if user navigates there during heavy GPS load. Performance budget: 1000 trips × 28 fields = O(28000) operations per emission. On a mid-range Android, that's <2ms — safe.

### Pitfall 7: Test Locale Default Mismatch
**What goes wrong:** `flutter_test` defaults the locale to `en_US`. If a developer runs tests on a CI runner with a different default locale, `DateFormat.E()` would produce different strings ("Mo." in German), failing string-matching tests.
**Why it happens:** `intl` honors the ambient locale unless explicitly set.
**How to avoid:** Pin the locale in tests via `Intl.defaultLocale = 'en_US';` in `setUpAll`, or pass an explicit locale to `DateFormat.E('en_US')`. UI-SPEC §Copywriting Contract already mandates this for tests.
**Warning signs:** Widget test passes locally, fails on CI with "Expected: 'Mon' Actual: 'Lun'".

## Runtime State Inventory

Not applicable — Phase 5 is a greenfield phase (new screen, new provider, new tests). No rename, no migration, no string replacement. There is no runtime state from a prior implementation to inventory.

**Stored data:** None — no schema changes, no new tables, no new columns. `pubspec.yaml` adds `fl_chart` (build artifact only).
**Live service config:** None.
**OS-registered state:** None.
**Secrets/env vars:** None.
**Build artifacts:** None to invalidate; `fl_chart` is a fresh add.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All | ✓ | 3.41.6 (verified via `flutter --version`) | — |
| Dart SDK | All | ✓ | 3.11.4 (bundled with Flutter) | — |
| `fl_chart` package | TrendChartCard | ✗ (not in pubspec.yaml) | — | `flutter pub add fl_chart` (one-line install) |
| `flutter_riverpod` | Stats provider | ✓ | 3.3.1 (pubspec.yaml) | — |
| `intl` | Day chip labels | ✓ | 0.20.2 (pubspec.yaml) | — |
| `drift` | Trip summary stream consumer | ✓ | 2.32.1 (pubspec.yaml) | — |
| `very_good_analysis` | Lint compliance | ✓ | 10.2.0 (pubspec.yaml) | — |

**Missing dependencies with fallback:**
- `fl_chart` — install via `flutter pub add fl_chart` in plan task. No alternative needed; this is the canonical project chart library per CLAUDE.md.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (Flutter SDK), `package:test` matchers |
| Config file | `analysis_options.yaml` (lint), no separate test config |
| Quick run command | `flutter test test/unit/features/stats/stats_service_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STAT-01 | Weekly + monthly totals match expected sum | unit | `flutter test test/unit/features/stats/stats_service_test.dart -p` | ❌ Wave 0 |
| STAT-02 | Direction averages computed; null when no trips for that direction | unit | `flutter test test/unit/features/stats/stats_service_test.dart` | ❌ Wave 0 |
| STAT-03 | Best/worst weekday match expected day; weekend trips excluded | unit | `flutter test test/unit/features/stats/stats_service_test.dart` | ❌ Wave 0 |
| STAT-04 | 28-element daily totals correct; out-of-window trips excluded | unit | `flutter test test/unit/features/stats/stats_service_test.dart` | ❌ Wave 0 |
| STAT-05 | Weekly traffic waste excludes `isManualEntry == true` trips | unit | `flutter test test/unit/features/stats/stats_service_test.dart` | ❌ Wave 0 |
| D-10 (empty state) | StatsSummary fields are null/zero on empty input; widget renders `'—'` | unit + widget | `flutter test test/unit/features/stats/ test/widget/features/stats/` | ❌ Wave 0 |
| D-02 (home screen entry) | "View stats" button navigates to `/stats` | widget | `flutter test test/widget/features/tracking/home_screen_test.dart` | partial — existing home_screen_test.dart needs new assertion |
| Pitfall 1 (TZ) | Trip at UTC 23:00 buckets to local-day correctly | unit | `flutter test test/unit/features/stats/stats_service_test.dart` | ❌ Wave 0 |
| Pitfall 4 (DST) | 28-day window count correct across DST boundary | unit | `flutter test test/unit/features/stats/stats_service_test.dart` | ❌ Wave 0 |
| LineChart renders | TrendChartCard builds without throwing on empty data | widget | `flutter test test/widget/features/stats/stats_screen_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/features/stats/stats_service_test.dart` (sub-second)
- **Per wave merge:** `flutter test test/unit/features/stats/ test/widget/features/stats/`
- **Phase gate:** `flutter test && flutter analyze` — full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/unit/features/stats/stats_service_test.dart` — covers STAT-01..05, D-10 empty state, pitfall 1/4 cases
- [ ] `test/widget/features/stats/stats_screen_test.dart` — verifies AsyncValue.when branches, card titles, empty placeholder rendering, smoke-test LineChart builds
- [ ] No new conftest/fixtures needed — pure-data tests use `List<TripSummary>` literals with the existing `_makeTrip` helper pattern from `history_grouping_test.dart:14`
- [ ] Update `test/widget/features/tracking/home_screen_test.dart` with a single test asserting the "View stats" button exists and navigates to `kRouteStats`

## Code Examples

### Example A: Pure Stats Function Test (no DB)

```dart
// File: test/unit/features/stats/stats_service_test.dart
// Pattern derived from: test/unit/features/trips/history_grouping_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:uuid/uuid.dart';

TripSummary _trip({
  required DateTime startTime,
  int durationSeconds = 1800,
  String direction = 'to_office',
  int timeStuckSeconds = 0,
  bool isManualEntry = false,
}) {
  return TripSummary(
    id: const Uuid().v4(),
    startTime: startTime,
    endTime: startTime.add(Duration(seconds: durationSeconds)),
    durationSeconds: durationSeconds,
    distanceMeters: 0,
    direction: direction,
    timeMovingSeconds: durationSeconds - timeStuckSeconds,
    timeStuckSeconds: timeStuckSeconds,
    isManualEntry: isManualEntry,
  );
}

void main() {
  group('computeStatsSummary', () {
    test('empty list produces zero/null summary (D-10)', () {
      final result = computeStatsSummary(
        const <TripSummary>[],
        DateTime(2026, 4, 26, 12), // Sunday noon local
      );
      expect(result.weekTotalSeconds, 0);
      expect(result.monthTotalSeconds, 0);
      expect(result.toOfficeAvgSeconds, isNull);
      expect(result.toHomeAvgSeconds, isNull);
      expect(result.dailyTotalsLast28Days.length, 28);
      expect(result.dailyTotalsLast28Days.every((v) => v == 0), isTrue);
      expect(result.weekStuckSeconds, 0);
      expect(result.hasAnyTrips, isFalse);
    });

    test('STAT-05 excludes manual entries from traffic waste', () {
      final monday = DateTime(2026, 4, 20, 8); // Monday 8am local
      final manualTrip = _trip(
        startTime: monday.toUtc(),
        timeStuckSeconds: 600,
        isManualEntry: true,
      );
      final gpsTrip = _trip(
        startTime: monday.toUtc(),
        timeStuckSeconds: 600,
        isManualEntry: false,
      );
      final result = computeStatsSummary(
        [manualTrip, gpsTrip],
        DateTime(2026, 4, 22, 12), // Wednesday — same week as the trips
      );
      expect(result.weekTotalSeconds, manualTrip.durationSeconds + gpsTrip.durationSeconds,
        reason: 'STAT-01 includes manual entries');
      expect(result.weekStuckSeconds, 600,
        reason: 'STAT-05 (D-05) excludes manual entries — only the GPS trip counts');
    });

    // ... STAT-01, STAT-02, STAT-03, STAT-04 cases
  });
}
```

### Example B: StatsSummary Model

```dart
// File: lib/features/stats/services/stats_service.dart (top of file)

/// Immutable summary of all five Phase 5 stats, computed once per
/// emission of [allTripSummariesProvider].
class StatsSummary {
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

  /// Total commute seconds for the current Mon–Sun week (D-03).
  final int weekTotalSeconds;

  /// Total commute seconds for the current calendar month (D-04).
  final int monthTotalSeconds;

  /// Average duration for to-office trips in seconds, or null if none.
  final int? toOfficeAvgSeconds;

  /// Average duration for to-home trips in seconds, or null if none.
  final int? toHomeAvgSeconds;

  /// Avg seconds per weekday, indexed by [DateTime.weekday] - 1
  /// (0 = Mon, 4 = Fri). Indexes 5/6 (Sat/Sun) are always null per D-09.
  /// Each element is null when no trips for that weekday.
  final List<int?> weekdayAverages;

  /// 28 entries, index 0 = today, index 27 = 27 days ago. Total
  /// seconds for that calendar day (D-07).
  final List<int> dailyTotalsLast28Days;

  /// Sum of `timeStuckSeconds` for current-week non-manual trips (D-05).
  final int weekStuckSeconds;

  /// Quick flag for the screen-level empty branch (D-10).
  final bool hasAnyTrips;
}
```

### Example C: Widget Override for Tests

```dart
// File: test/widget/features/stats/stats_screen_test.dart
// Pattern from: test/widget/features/trips/history_screen_test.dart:60

ProviderScope(
  overrides: [
    // Override the existing stream provider with a deterministic stream.
    allTripSummariesProvider.overrideWith(
      (ref) => Stream<List<TripSummary>>.value(<TripSummary>[/* test trips */]),
    ),
    // statsSummaryProvider does not need an override — it derives from
    // allTripSummariesProvider, so the override above flows through.
  ],
  child: const MaterialApp(home: StatsScreen()),
);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `StreamProvider.overrideWithValue` removed in Riverpod 2.x | Re-added in Riverpod 3.0 (Sept 2025) | Riverpod 3.0 | Test override pattern works as expected. We use `overrideWith((ref) => Stream.value(...))` to be explicit. |
| `fl_chart` 0.69 `tooltipBgColor`, `axisSide` | `fl_chart` 1.x `getTooltipColor`, `SideTitleWidget(meta: meta)` | fl_chart 1.0.0 (2025) | If the user accepts `^1.2.0`, follow the new API. UI-SPEC §Tools currently lists `^0.69` — flag for confirmation. |
| `riverpod_generator` `@riverpod` codegen | Manual `Provider<...>` declarations | Phase 1 D-12 (this project) | All Phase 5 providers are manual — no `@riverpod` annotation. See `database/providers.dart` for the rationale. |

**Deprecated/outdated:**
- `tooltipBgColor` parameter in `LineTouchTooltipData` — replaced by `getTooltipColor` callback in fl_chart 1.x. We don't use tooltips (touch disabled), so this doesn't affect us.

## Project Constraints (from CLAUDE.md)

These directives MUST be honored by every task in the plan:

- **Drift is the only data source for UI.** StatsScreen reads exclusively from `allTripSummariesProvider` — never the network.
- **Riverpod for all state.** No `setState`, no `ChangeNotifier`. Use `ConsumerWidget` and `ref.watch`.
- **Manual Riverpod 3.x providers.** No `@riverpod` annotation; declare as `final Provider<...> name = Provider<...>(...);` per the project pattern (`database/providers.dart`).
- **Keep widgets under 100 lines.** Each card is a separate file in `lib/features/stats/widgets/`. UI-SPEC §Component Inventory already mandates this.
- **No hardcoded values.** All strings + numeric layout values go in `lib/config/constants.dart`. UI-SPEC §Constants Required gives exact names.
- **`very_good_analysis` lint** — note that `public_member_api_docs: ignore` is set in `analysis_options.yaml`, so doc comments are encouraged (per existing code style) but not strictly required by the linter. **Recommendation:** match the existing style — every public class and provider has a doc comment in `history_providers.dart` and `trips_dao.dart`.
- **`package:traevy/...` absolute imports** — no relative imports.
- **`strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`** — never `dynamic`; explicitly type every collection (`List<int>`, `Map<String, int>`, etc.).
- **No dead code, no `// TODO`, no placeholders** — every committed task must be production-ready.
- **One concern per commit, prefix `[stats]`** for this phase.
- **Test what matters** — pure stats math gets exhaustive unit tests; widget tests verify card structure and empty/error/loading branches.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | UI-SPEC's `fl_chart ^0.69` pin is stale; latest stable `^1.2.0` is the better choice | Standard Stack / Alternatives | Planner ships with `^0.69` and accepts the older API surface. Both APIs work for the simple LineChart we need; planner should confirm with user before pubspec edit. |
| A2 | The provider should be a derived `Provider<AsyncValue<StatsSummary>>` (not a fresh StreamProvider) | Pattern 1 | Planner picks fresh StreamProvider — duplicates the Drift subscription but works. Tests are slightly more annoying (must override two providers). Functional outcome identical. |
| A3 | DST off-by-one in `Duration.inDays` is real | Pitfall 4 | We add an unnecessary `DateTime.utc` helper. Worst case: simpler code that works correctly 363/365 days/year and shows a 1-day shift on DST boundaries. Mitigation is cheap and correct — keep the helper. |
| A4 | `flutter_test` defaults locale to `en_US` on developer machines and CI runners | Pitfall 7 | Tests pass locally and fail on a non-en CI environment. Mitigation: explicitly set `Intl.defaultLocale = 'en_US'` in `setUpAll` — UI-SPEC already requires this. |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

## Open Questions

1. **fl_chart version: `^1.2.0` (latest) or `^0.69` (UI-SPEC default)?**
   - What we know: `1.2.0` is current stable, requires Flutter ≥3.27.4 (we're on 3.41.6 ✓).
   - What's unclear: whether the user explicitly wanted `^0.69` for some compat reason (e.g., known issue), or whether `^0.69` was just the version in the Phase 0 research data.
   - Recommendation: planner's first task includes `flutter pub add fl_chart` (no version) which picks the current latest, then pins it. Surface in plan-checker if user prefers `^0.69`.

2. **Should `kStatsErrorMessage` keep "Pull down to retry" hint or drop it?**
   - What we know: UI-SPEC §Copywriting flagged this as an open question — Option A (drop it) recommended; Option B (add `RefreshIndicator`) deferred.
   - What's unclear: nothing functional — both work. UI-SPEC default is Option A.
   - Recommendation: ship Option A. Constant is `kStatsErrorMessage = 'Could not load stats.'` per UI-SPEC §Constants Required (already set to Option A).

3. **Should `computeStatsSummary` live in `services/` or inline in `providers/stats_providers.dart`?**
   - What we know: extracting to `services/stats_service.dart` allows pure-data unit tests with no Riverpod import.
   - What's unclear: nothing. Codebase has `lib/features/trips/services/trip_actions.dart` precedent for this pattern.
   - Recommendation: extract. Plan task list: `lib/features/stats/services/stats_service.dart` for the pure function, `providers/stats_providers.dart` for the thin `Provider` wrapper.

## Sources

### Primary (HIGH confidence)
- pub.dev API for fl_chart: `https://pub.dev/api/packages/fl_chart` — fetched 2026-04-26, latest version 1.2.0
- fl_chart line chart sample: `https://github.com/imaNNeo/fl_chart/blob/main/example/lib/presentation/samples/line/line_chart_sample1.dart` — official LineChart usage
- fl_chart API docs: `https://github.com/imaNNeo/fl_chart/blob/main/repo_files/documentations/line_chart.md`
- Riverpod AsyncValue API: `https://pub.dev/documentation/riverpod/latest/riverpod/AsyncValue-class.html`
- Riverpod StreamProvider docs: `https://docs-v2.riverpod.dev/docs/providers/stream_provider`
- Riverpod 3.0 release notes: `https://riverpod.dev/docs/whats_new`
- Dart `DateTime.weekday` API: `https://api.dart.dev/stable/dart-core/DateTime/weekday.html`
- Dart `Duration.inDays` API: `https://api.dart.dev/stable/dart-core/Duration/inDays.html`
- Existing codebase patterns: `lib/features/trips/providers/history_providers.dart`, `test/unit/features/trips/history_grouping_test.dart`, `test/widget/features/trips/history_screen_test.dart`, `lib/database/daos/trips_dao.dart`, `lib/database/providers.dart`
- Project config: `pubspec.yaml`, `analysis_options.yaml`, `.planning/config.json`
- Phase decisions: `.planning/phases/05-stats-analytics/05-CONTEXT.md`, `.planning/phases/05-stats-analytics/05-UI-SPEC.md`

### Secondary (MEDIUM confidence)
- WebSearch on Riverpod 3.x derived provider patterns — corroborated by official docs above.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — `fl_chart 1.2.0` verified live on pub.dev; `flutter_riverpod 3.3.1`, `intl 0.20.2`, `drift 2.32.1` verified in `pubspec.yaml`.
- Architecture: HIGH — pattern derived from existing `allTripSummariesProvider` + `HistoryScreen` exact match, plus official Riverpod `whenData` API.
- Pitfalls: HIGH for 1, 2, 3, 5, 7 (codebase precedent or library docs); MEDIUM for 4 (DST) — empirically possible but rare; mitigation is cheap, recommend applying it.
- Code examples: HIGH — adapted from real fl_chart sample code and existing project test patterns.

**Research date:** 2026-04-26
**Valid until:** 2026-05-26 (30 days — fl_chart and Riverpod are stable, Flutter SDK won't change for at least 6 weeks). Re-verify `fl_chart` version if not started by then.
