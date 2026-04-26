---
phase: 05-stats-analytics
plan: "02"
subsystem: stats
tags: [flutter, stats, riverpod, pure-dart, tdd-green]
dependency_graph:
  requires:
    - "05-01 (StatsSummary class + RED test scaffold + kStatsTrendWindowDays constant)"
    - "04-xx (allTripSummariesProvider + TripSummary DAO type)"
  provides:
    - "computeStatsSummary fully implemented (GREEN)"
    - "statsSummaryProvider derived Provider<AsyncValue<StatsSummary>>"
  affects:
    - "05-03+ (stats screen widgets consume statsSummaryProvider)"
tech_stack:
  added: []
  patterns:
    - "Single O(n) pass with eight accumulators for all Phase 5 stats"
    - "_daysBetweenLocalMidnights UTC-anchor helper (Pitfall 4 / DST mitigation)"
    - "Derived Provider<AsyncValue<T>> via whenData wrapping existing StreamProvider"
key_files:
  created:
    - "lib/features/stats/providers/stats_providers.dart"
  modified:
    - "lib/features/stats/services/stats_service.dart"
decisions:
  - "Single-pass design confirmed: one loop, eight accumulators, O(n) — no multi-pass or helper queries"
  - "weekdayAverages index guard i>=5 forces Sat/Sun null independently of accumulator loop (D-09 double guard)"
  - "dirCounts/dirTotals initialised for both directions so containsKey guards are always true; no map[key] lookup failure possible"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-27"
  tasks: 2
  files_changed: 2
---

# Phase 5 Plan 02: Stats Service Implementation (GREEN) Summary

**One-liner:** Single-pass `computeStatsSummary` body + `statsSummaryProvider` derived provider turn 13 RED unit tests GREEN with full DST/timezone safety.

## What Was Built

### Task 1: computeStatsSummary single-pass body

Replaced the `UnimplementedError` stub in `lib/features/stats/services/stats_service.dart` with a production-ready single-pass implementation. The function accepts `List<TripSummary>` and an injected `DateTime now` and returns a fully populated `StatsSummary` in O(n).

Key implementation details:

- **Period anchors**: `localNow = now.toLocal()` → `today`, `weekStart` (Mon), `weekEnd` (+7 days), `monthStart`, `monthEnd` computed once before the loop.
- **`_daysBetweenLocalMidnights` helper**: Constructs `DateTime.utc(y, m, d)` anchors for both endpoints so DST transitions (23h/25h days) don't corrupt `Duration.inDays` (Pitfall 4 mitigation).
- **Per-trip `toLocal()` call**: Every iteration converts `trip.startTime.toLocal()` before any date math (Pitfall 1 mitigation).
- **D-05 guard**: `weekStuckSeconds` accumulates only when `!trip.isManualEntry`; `weekTotalSeconds` and `monthTotalSeconds` include manual trips unconditionally.
- **D-09 double guard**: Weekday accumulator loop skips `weekday > DateTime.friday`; `weekdayAverages` generator also forces `i >= 5` to `null` regardless.
- **Zero-division**: Integer division `~/` always guarded by `dirCounts[dir]! == 0` check (Pitfall 2).
- **`kStatsTrendWindowDays`**: Used for both `List.filled` length and `daysAgo < kStatsTrendWindowDays` bound check — constant is the single source of truth.

**Body lines (stats_service.dart computeStatsSummary + helper):** ~70 lines of implementation logic.

### Task 2: statsSummaryProvider

Created `lib/features/stats/providers/stats_providers.dart` (new directory `lib/features/stats/providers/`).

- `Provider<AsyncValue<StatsSummary>>` using manual Riverpod 3.x declaration (no codegen — analyzer version conflict with drift_dev documented in Phase 2 decisions).
- `ref.watch(allTripSummariesProvider)` reuses the single Drift subscription from Phase 4 — no duplicate `watchAllSummaries()` call.
- `asyncTrips.whenData((trips) => computeStatsSummary(trips, DateTime.now()))` preserves `AsyncLoading`/`AsyncError` states transparently.
- `name: 'statsSummaryProvider'` consistent with all manual providers in the project.
- Doc comment explains the architectural decision (derived Provider vs. new StreamProvider).

## Test Results

| Suite | Tests | Status |
|-------|-------|--------|
| `stats_service_test.dart` (Plan 01 RED → Plan 02 GREEN) | 13 | All passed |
| Full suite (Phases 1–4 regression) | 170 | All passed |

The 13 tests cover:
- Empty input → zero/null fields, `hasAnyTrips=false`, 28-length `dailyTotalsLast28Days`
- STAT-01: week/month boundary exclusion, manual entry inclusion
- STAT-02: direction averages + null for zero-trip direction
- STAT-03: Mon–Fri populated, Sat/Sun indices always null
- STAT-04: 28-day window length + exclusion of day 29+
- STAT-05: manual entry excluded from `weekStuckSeconds`, out-of-week trips excluded
- Pitfall 1 (TZ): UTC midnight trip bucketed by local date
- Pitfall 4 (DST): trip 27 days ago lands at index 27 across EU DST boundary

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. Both files deliver complete production logic.

## Threat Flags

None. This plan introduces no new input boundaries, network endpoints, or auth paths. `statsSummaryProvider` is a pure in-memory derivation over already-trusted Drift data (T-05-02-01 and T-05-02-02 accepted; T-05-02-03 mitigated by single-pass design).

## Self-Check: PASSED

- `lib/features/stats/services/stats_service.dart` — exists, stub removed
- `lib/features/stats/providers/stats_providers.dart` — exists, new file
- Task 1 commit `1c4d192` — verified in git log
- Task 2 commit `f2b501d` — verified in git log
- `flutter analyze` — 0 issues
- `flutter test test/unit/features/stats/stats_service_test.dart` — 13/13 passed
- `flutter test` (full) — 170/170 passed
