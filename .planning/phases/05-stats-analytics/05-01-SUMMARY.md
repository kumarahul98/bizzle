---
phase: 05-stats-analytics
plan: "01"
subsystem: stats
tags: [flutter, stats, fl_chart, riverpod, foundation, tdd]
dependency_graph:
  requires: []
  provides:
    - fl_chart 1.2.0 dependency in pubspec.yaml
    - Phase 5 string and layout constants in lib/config/constants.dart
    - kRouteStats route constant in lib/config/routes.dart
    - StatsSummary value object in lib/features/stats/services/stats_service.dart
    - computeStatsSummary(List<TripSummary>, DateTime) stub (TDD RED)
    - RED unit test suite (13 tests, all failing with UnimplementedError)
  affects:
    - lib/config/constants.dart (appended Phase 5 section)
    - lib/config/routes.dart (kRouteStats added)
    - pubspec.yaml (fl_chart dependency added)
tech_stack:
  added:
    - fl_chart: ^1.2.0 (resolved to 1.2.0)
  patterns:
    - TDD RED phase: stub throws UnimplementedError, tests fail as expected
    - @immutable value object with const constructor and nullable aggregate fields
key_files:
  created:
    - lib/features/stats/services/stats_service.dart
    - test/unit/features/stats/stats_service_test.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - lib/config/constants.dart
    - lib/config/routes.dart
decisions:
  - "fl_chart pinned to ^1.2.0 (RESEARCH.md overrides stale UI-SPEC ^0.69)"
  - "constants.dart import dropped from stats_service.dart stub — Plan 02 re-adds when needed to avoid unused_import warning"
  - "kRouteStats declared in routes.dart but NOT added to kAppRoutes map — StatsScreen does not exist yet (Plan 05 adds the map entry)"
metrics:
  duration_minutes: 4
  completed_date: "2026-04-26"
  tasks_completed: 2
  files_changed: 6
---

# Phase 5 Plan 01: Stats Foundation — fl_chart, Constants, StatsSummary, RED Tests Summary

**One-liner:** fl_chart 1.2.0 pinned, 21 Phase 5 constants declared, StatsSummary value object and computeStatsSummary stub established with 13 RED unit tests locking the math contract.

## What Was Built

### Task 1: fl_chart dependency + Phase 5 constants + kRouteStats

- **pubspec.yaml**: Added `fl_chart: ^1.2.0` in alphabetical order within the dependencies block. Resolved to fl_chart 1.2.0 (confirmed via `flutter pub get`).
- **lib/config/constants.dart**: Appended a "Phase 5: Stats & Analytics" section with 3 numeric/dimension constants (`kStatsTrendWindowDays`, `kStatsTrendWeekCount`, `kStatsTrendChartHeight`) and 18 string constants covering all UI card labels, headings, helpers, and the `kStatsEmptyPlaceholder` em-dash.
- **lib/config/routes.dart**: Added `kRouteStats = '/stats'` constant. The `kAppRoutes` map is intentionally unchanged — Plan 05 adds the map entry when `StatsScreen` exists.

### Task 2: StatsSummary class + stub + RED tests

- **lib/features/stats/services/stats_service.dart**: Pure Dart file (no Flutter/widget imports). Contains `@immutable class StatsSummary` with 8 `final` fields and a `const` constructor, plus `StatsSummary computeStatsSummary(List<TripSummary> trips, DateTime now)` whose body is `throw UnimplementedError('computeStatsSummary is implemented by Plan 05-02 (Wave 1).')`.
- **test/unit/features/stats/stats_service_test.dart**: 13 unit tests across 8 `group()` blocks. Covers STAT-01 (week/month totals), STAT-02 (direction averages), STAT-03 (weekday averages), STAT-04 (28-day trend), STAT-05 (traffic waste), D-10 (empty input), Pitfall 1 (UTC-to-local bucketing), and Pitfall 4 (DST-safe day diff).

## Test Results

- **fl_chart version resolved**: 1.2.0
- **Total test count**: 13 `test(...)` blocks across 8 `group(...)` blocks
- **Failing tests after `flutter test`**: 13 (all fail with `UnimplementedError: computeStatsSummary is implemented by Plan 05-02 (Wave 1).`)
- **RED state**: Confirmed — exit code non-zero, all failures carry the expected UnimplementedError message

## Verification Results

1. `flutter pub get` exits 0 — fl_chart 1.2.0 resolved
2. `flutter analyze` exits 0 — zero new warnings/errors (full project clean)
3. `flutter test test/unit/features/stats/stats_service_test.dart` exits non-zero — RED state confirmed
4. Failure trace mentions "UnimplementedError" and "Plan 05-02" — confirmed
5. `grep -c "// Phase 5" lib/config/constants.dart` returns 1 — section header present
6. `grep -c "kRouteStats" lib/config/routes.dart` returns 1 — declared, not yet in kAppRoutes

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed sort_pub_dependencies lint error in pubspec.yaml**
- **Found during:** Task 1 verification (`flutter analyze`)
- **Issue:** `fl_chart` was initially inserted after the `flutter: sdk: flutter` entry, violating `sort_pub_dependencies` lint rule
- **Fix:** Moved `fl_chart: ^1.2.0` to alphabetical position before `flutter:` (fl_ < flu alphabetically)
- **Files modified:** pubspec.yaml
- **Commit:** 1bb9586

**2. [Rule 1 - Bug] Fixed lines_longer_than_80_chars in constants.dart**
- **Found during:** Task 1 verification (`flutter analyze`)
- **Issue:** The `kStatsCardTrendXAxisPrefix` doc comment exceeded 80 characters on one line
- **Fix:** Wrapped the doc comment across two lines
- **Files modified:** lib/config/constants.dart
- **Commit:** 1bb9586

**3. [Rule 1 - Bug] Fixed comment_references warnings in stats_service.dart**
- **Found during:** Task 2 verification (`flutter analyze`)
- **Issue:** Three doc comments referenced symbols not in scope: `[kStatsEmptyPlaceholder]`, `[trips]` (parameter name, not a type), `[_daysBetweenLocalMidnights]` (private helper not yet created)
- **Fix:** Changed bracket references to backtick code-style references that don't trigger comment_references
- **Files modified:** lib/features/stats/services/stats_service.dart
- **Commit:** 3d40dfa

**4. [Rule 1 - Bug] Fixed avoid_redundant_argument_values in stats_service_test.dart**
- **Found during:** Task 2 verification (`flutter analyze`)
- **Issue:** Four `_trip(...)` calls explicitly passed default argument values (`direction: kDirectionToOffice`, `durationSeconds: 1800`, `isManualEntry: false`)
- **Fix:** Removed the redundant explicit arguments; test semantics unchanged
- **Files modified:** test/unit/features/stats/stats_service_test.dart
- **Commit:** 3d40dfa

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| fl_chart pinned to ^1.2.0 | RESEARCH.md key finding overrides stale UI-SPEC ^0.69 version |
| constants.dart import omitted from stub | Importing `package:traevy/config/constants.dart` would trigger `unused_import` in the stub state; Plan 02 adds it in the GREEN phase |
| kRouteStats not in kAppRoutes | StatsScreen widget does not exist yet; Plan 05 adds the map entry to avoid dead route entries |

## Known Stubs

| File | Symbol | Reason |
|------|--------|--------|
| lib/features/stats/services/stats_service.dart | `computeStatsSummary` | Intentional TDD RED stub; Plan 02 (Wave 1) implements the body |

This is intentional per the plan design — Plan 02 turns the RED tests GREEN.

## Threat Flags

None — this plan introduces no new network endpoints, auth paths, file access patterns, or schema changes. The StatsSummary value object is an in-process pure Dart computation with no external surface.

## Self-Check: PASSED

- lib/features/stats/services/stats_service.dart — FOUND
- test/unit/features/stats/stats_service_test.dart — FOUND
- lib/config/constants.dart (Phase 5 section) — FOUND
- lib/config/routes.dart (kRouteStats) — FOUND
- Commit 1bb9586 — FOUND (feat: fl_chart dep, Phase 5 constants, kRouteStats)
- Commit 3d40dfa — FOUND (test: StatsSummary class + computeStatsSummary stub + RED unit tests)
