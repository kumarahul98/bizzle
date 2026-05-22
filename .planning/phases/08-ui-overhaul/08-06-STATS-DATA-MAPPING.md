# Phase 08 Plan 06 — Stats Data-Shape Mapping Audit

> **Review HIGH #2 compliance document.** This audit proves that every new stats widget
> introduced in Task 2 consumes only existing `StatsSummary` fields. No new Drift DAO
> queries and no new provider fields are introduced.

---

## ✅ All mappings resolved — Tasks 1/2 may proceed

No BLOCKER rows found. Every required field is either **MAPPED** directly from an
existing `StatsSummary` field, is a **TRIVIAL-LOCAL-COMPUTE** over existing fields, or
uses a **GRACEFUL-DEGRADE** fallback documented below.

---

## Section 1: Existing `StatsSummary` Output Shape

Source: `lib/features/stats/services/stats_service.dart` — `class StatsSummary` (lines 13–63)
and `lib/features/stats/providers/stats_providers.dart` — `statsSummaryProvider` (line 28).

The provider chain is:

```
statsSummaryProvider  →  allTripSummariesProvider (StreamProvider<List<TripSummary>>)
                      →  computeStatsSummary(trips, DateTime.now())
                      →  returns StatsSummary
```

No sub-providers are composed. There is exactly one provider (`statsSummaryProvider`) which
returns `AsyncValue<StatsSummary>`.

| Field | Type | Source | Example |
|-------|------|--------|---------|
| `weekTotalSeconds` | `int` | Sum of `durationSeconds` for trips where `startTime` falls in current Mon–Sun week | 9600 (= 2h 40m) |
| `monthTotalSeconds` | `int` | Sum of `durationSeconds` for trips in current calendar month | 38400 (= 10h 40m) |
| `toOfficeAvgSeconds` | `int?` | Average `durationSeconds` across all `kDirectionToOffice` trips (null if no such trips) | 2100 (= 35m) |
| `toHomeAvgSeconds` | `int?` | Average `durationSeconds` across all `kDirectionToHome` trips (null if no such trips) | 2820 (= 47m) |
| `weekdayAverages` | `List<int?>` | 7-element list; index = `DateTime.weekday - 1` (0=Mon…6=Sun). Indices 5–6 always null; Mon–Fri null when no trips on that day | [1800, 2100, null, 1980, null, null, null] |
| `dailyTotalsLast28Days` | `List<int>` | 28-element list; index 0 = today, index 27 = 27 days ago; value = total `durationSeconds` that day | [0, 0, 3600, 2700, …] |
| `weekStuckSeconds` | `int` | Sum of `timeStuckSeconds` for non-blank-manual trips in current week | 1080 (= 18m) |
| `hasAnyTrips` | `bool` | `true` when input `trips` list was non-empty | true |

**Total fields: 8**. Note: `StatsSummary` does NOT have:
- `movingMinutes` / `stuckMinutes` — these do NOT exist as named fields
- `tripCount` — does NOT exist as a named field
- `previousWeekStuckMinutes` — does NOT exist
- Any per-week-of-28-days aggregation beyond `dailyTotalsLast28Days`
- `bestDay` / `worstDay` as precomputed integers

These absences are handled via TRIVIAL-LOCAL-COMPUTE or GRACEFUL-DEGRADE paths (see Section 3).

---

## Section 2: New Widget Input Requirements

### `TrafficLossHero`

Per UI-SPEC §7 and Plan 06 `<behavior>`:
- **`stuckMinutes` (int):** Total minutes stuck in traffic this week — derived from `weekStuckSeconds`.
- **`previousWeekStuckMinutes` (int, optional):** Minutes stuck last week for "vs last week" comparison — NOT available on `StatsSummary`.
- **Fallback:** If `previousWeekStuckMinutes` is unavailable, the "vs last week" comparison row is simply omitted (GRACEFUL-DEGRADE path). The plan explicitly states: "If the provider does NOT expose `previousWeekStuckMinutes`, skip the comparison row (do not invent data)."

### `DonutCard`

Per UI-SPEC §7 and Plan 06 `<behavior>`:
- **`movingMinutes` (int):** Moving minutes this week — derived from `weekTotalSeconds - weekStuckSeconds`.
- **`stuckMinutes` (int):** Stuck minutes this week — derived from `weekStuckSeconds`.
- **`totalMinutes` (int):** Total minutes this week — derived from `weekTotalSeconds`.
- **`tripCount` (int):** Number of trips in the last 28 days for the subtitle — NOT available as a named field. GRACEFUL-DEGRADE: show `dailyTotalsLast28Days.where((s) => s > 0).length` as an approximation, or omit the count.

### `TrendBarsCard`

Per UI-SPEC §7 and Plan 06 `<behavior>`:
- **Per-day duration for 28 days (List<int>, minutes):** The `dailyTotalsLast28Days` field provides exactly this in seconds (index 0 = today). Divide by 60 for minutes.
- **Today marker:** Bar at index 0 (the most recent day).
- **Worst day marker:** Computed locally by finding `max(dailyTotalsLast28Days)` index.

### `WeekdayChartCard`

Per UI-SPEC §7 and Plan 06 `<behavior>`:
- **`perWeekdayAverageMinutes` (Map<int, int> or equivalent):** The `weekdayAverages` field (`List<int?>`) provides average `durationSeconds` per weekday (index 0=Mon…4=Fri). Divide by 60 for minutes.
- **`bestDay` (int):** The weekday index with the lowest non-null average — computed locally by iterating `weekdayAverages[0..4]`.
- **`worstDay` (int):** The weekday index with the highest non-null average — computed locally by iterating `weekdayAverages[0..4]`.

---

## Section 3: 1:1 Mapping Table

| New widget | Required field | StatsSummary field name | Type match? | Direct or computed? | Decision |
|------------|----------------|-------------------------|-------------|---------------------|----------|
| `TrafficLossHero` | stuckMinutes (int) | `weekStuckSeconds` | No (seconds→minutes) | `weekStuckSeconds ~/ 60` | TRIVIAL-LOCAL-COMPUTE |
| `TrafficLossHero` | previousWeekStuckMinutes (int?) | (none) | N/A | Field does not exist; skip comparison row | GRACEFUL-DEGRADE |
| `DonutCard` | stuckMinutes (int) | `weekStuckSeconds` | No (seconds→minutes) | `weekStuckSeconds ~/ 60` | TRIVIAL-LOCAL-COMPUTE |
| `DonutCard` | movingMinutes (int) | `weekTotalSeconds`, `weekStuckSeconds` | No (derived) | `(weekTotalSeconds - weekStuckSeconds) ~/ 60` | TRIVIAL-LOCAL-COMPUTE |
| `DonutCard` | totalMinutes (int) | `weekTotalSeconds` | No (seconds→minutes) | `weekTotalSeconds ~/ 60` | TRIVIAL-LOCAL-COMPUTE |
| `DonutCard` | tripCount (int, for subtitle) | (none) | N/A | Count non-zero entries in `dailyTotalsLast28Days` as approximation, or omit | GRACEFUL-DEGRADE |
| `TrendBarsCard` | dailyDurations (List<int>, 28 entries, minutes) | `dailyTotalsLast28Days` | No (seconds→minutes) | `dailyTotalsLast28Days.map((s) => s ~/ 60)` | TRIVIAL-LOCAL-COMPUTE |
| `TrendBarsCard` | worstDayIndex (int) | `dailyTotalsLast28Days` | No (computed) | `argmax(dailyTotalsLast28Days)` inside build | TRIVIAL-LOCAL-COMPUTE |
| `WeekdayChartCard` | weekdayAverageMinutes (List<int?>, Mon–Fri) | `weekdayAverages` | No (seconds→minutes) | `weekdayAverages[i] != null ? weekdayAverages[i]! ~/ 60 : null` | TRIVIAL-LOCAL-COMPUTE |
| `WeekdayChartCard` | bestDay (int weekday index) | `weekdayAverages` | No (computed) | `argmin(weekdayAverages[0..4])` inside build | TRIVIAL-LOCAL-COMPUTE |
| `WeekdayChartCard` | worstDay (int weekday index) | `weekdayAverages` | No (computed) | `argmax(weekdayAverages[0..4])` inside build | TRIVIAL-LOCAL-COMPUTE |

**All rows: TRIVIAL-LOCAL-COMPUTE or GRACEFUL-DEGRADE. Zero rows require a new DAO query or provider field.**

---

## Legacy Widget Deletion Confirmation

The five legacy widgets being deleted and which `StatsSummary` fields they currently consume:

| Widget | StatsSummary fields consumed | Fields still available after deletion? |
|--------|------------------------------|----------------------------------------|
| `WeekMonthTotalsCard` | `weekTotalSeconds`, `monthTotalSeconds` | Yes — both still in `StatsSummary` |
| `DirectionAveragesCard` | `toOfficeAvgSeconds`, `toHomeAvgSeconds` | Yes — both still in `StatsSummary` |
| `BestWorstDayCard` | `weekdayAverages` | Yes — still in `StatsSummary` |
| `TrendChartCard` | `dailyTotalsLast28Days` | Yes — still in `StatsSummary` |
| `TrafficWasteCard` | `weekStuckSeconds` | Yes — still in `StatsSummary` |

All five legacy widgets' data needs are subsumed by the new widgets (via TRIVIAL-LOCAL-COMPUTE).
Deletion of the widget files does not remove any `StatsSummary` field — the provider is untouched.

---

## Interface Block Corrections

The `<interfaces>` block in `08-06-PLAN.md` describes `StatsSummary` with these names:
- `movingMinutes`, `stuckMinutes`, `totalMinutes`, `tripCount` — **These do NOT exist.**
- `weeklyTotalsMinutes` — **Does NOT exist.**
- `perWeekdayAverageMinutes` — **Does NOT exist.**
- `bestDay`, `worstDay` — **Do NOT exist as precomputed fields.**
- `previousWeekStuckMinutes` — **Does NOT exist.**

**Actual field names in `StatsSummary`:**
- Use `weekStuckSeconds` (int, seconds) — divide by 60 for `stuckMinutes`
- Use `weekTotalSeconds` (int, seconds) — divide by 60 for `totalMinutes`; derive `movingMinutes = (weekTotalSeconds - weekStuckSeconds) ~/ 60`
- Use `dailyTotalsLast28Days` (List<int>, seconds, 28 entries) — not `weeklyTotalsMinutes`
- Use `weekdayAverages` (List<int?>, seconds) — not `perWeekdayAverageMinutes`
- `bestDay`/`worstDay` and `tripCount` — compute locally in widget build methods

**Task 2 MUST use the actual field names above, not the interface block names.**

---

## Verification

```
grep -c "^|" this file  ≥ 11 rows in mapping table  ✓
All four new widgets named: TrafficLossHero ✓ DonutCard ✓ TrendBarsCard ✓ WeekdayChartCard ✓
No blocking rows found ✓
No new Drift DAO query required ✓
No new StatsSummary field required ✓
```
