---
phase: 04-trip-history
plan: "01"
subsystem: testing
tags:
  - test-stubs
  - wave-0
  - history
  - widget-tests
  - unit-tests
dependency_graph:
  requires:
    - "lib/database/daos/trips_dao.dart (TripSummary class shape)"
    - "lib/database/database.dart (AppDatabase, TripsCompanion)"
    - "lib/config/constants.dart (kDirectionToOffice)"
  provides:
    - "Wave 0 unit test stubs for groupTripsByDate and formatDateHeader (HIST-01)"
    - "Wave 0 unit test stubs for formatDuration, formatDistance, decodedToLatLng (HIST-01, HIST-03)"
    - "Wave 0 widget test stubs for HistoryScreen list/calendar/empty/navigation (HIST-01, HIST-02)"
    - "Wave 0 widget test stubs for TripDetailScreen loading/not-found/manual/GPS (HIST-03)"
  affects:
    - "Plans 04-02, 04-03, 04-04 (Wave 1+ tasks have a real verify target)"
    - "lib/features/trips/providers/history_providers.dart (Wave 1 will create — stubs await it)"
    - "lib/shared/utils/formatters.dart (Wave 1 will create — stubs await it)"
    - "lib/features/trips/screens/history_screen.dart (Wave 2 will create)"
    - "lib/features/trips/screens/trip_detail_screen.dart (Wave 2 will create)"
tech_stack:
  added: []
  patterns:
    - "Wave 0 skip-flagged stubs — every Wave 1+ task points at an existing test file (Nyquist rule)"
    - "Stubs omit production-module imports until those modules exist; helpers compile against existing types only"
    - "Drift companion test factories wrap optional fields in Value() per generated TripsCompanion.insert signature"
key_files:
  created:
    - test/unit/features/trips/history_grouping_test.dart
    - test/unit/shared/formatters_test.dart
    - test/widget/features/trips/history_screen_test.dart
    - test/widget/features/trips/trip_detail_screen_test.dart
  modified: []
decisions:
  - "Stubs use markTestSkipped() inside the test body (not the test() skip parameter) so the runner reports them as passing rather than ignoring them"
  - "Production-module imports (history_providers.dart, formatters.dart, HistoryScreen, TripDetailScreen) are intentionally OMITTED — Wave 1+ adds them once the modules exist; otherwise Dart compilation would fail"
  - "Widget test scaffolds match edit_trip_sheet_test.dart exactly (NativeDatabase.memory + closeStreamsSynchronously: true) so Wave 2 can drop assertions in without rewriting setup"
  - "makeGpsTrip helper wraps userId, routePolyline, isManualEntry, createdAt, updatedAt in Value(...) — required by the generated TripsCompanion.insert signature"
requirements_completed: []
metrics:
  duration_minutes: 25
  tasks_completed: 2
  tasks_total: 2
  files_created: 4
  files_modified: 0
  tests_added: 24
  tests_passing: 132
  tests_skipped: 24
  completed_date: "2026-04-26"
---

# Phase 4 Plan 01: Wave 0 Test Stubs Summary

**Four skip-flagged test files (15 unit + 9 widget stubs) seeded so every Wave 1–3 task in Phase 4 has a real verify target — the runner stays green and Nyquist compliance is satisfied before any production code exists.**

## Performance

- **Duration:** ~25 min (across two execution segments)
- **Started:** 2026-04-26T11:30:00Z (approx)
- **Completed:** 2026-04-26T11:55:00Z (approx)
- **Tasks:** 2 / 2
- **Files created:** 4
- **Files modified:** 0

## Accomplishments

- `test/unit/features/trips/history_grouping_test.dart` — 7 skipped tests across `groupTripsByDate` (4) and `formatDateHeader` (3) covering HIST-01.
- `test/unit/shared/formatters_test.dart` — 8 skipped tests across `formatDuration` (4), `formatDistance` (2), and `decodedToLatLng` (2) covering HIST-01 and HIST-03.
- `test/widget/features/trips/history_screen_test.dart` — 5 skipped widget tests (grouped trip cards, empty state, calendar markers, calendar filter, navigation) covering HIST-01 and HIST-02.
- `test/widget/features/trips/trip_detail_screen_test.dart` — 4 skipped widget tests (loading spinner, not-found, manual-entry mode, GPS stat rows) covering HIST-03.
- Full Flutter suite green: 132 passing, 24 skipped, 0 failing.

## Task Commits

1. **Task 1: Unit test stubs (history_grouping + formatters)** — `3b25706` (test)
2. **Task 2: Widget test stubs (HistoryScreen + TripDetailScreen)** — `2e353d1` (test)

_Plan-metadata commit follows this SUMMARY._

## Files Created/Modified

- `test/unit/features/trips/history_grouping_test.dart` — 7 stubs grouped under `groupTripsByDate` and `formatDateHeader`. No production imports yet; uses only `flutter_test`.
- `test/unit/shared/formatters_test.dart` — 8 stubs grouped under `formatDuration`, `formatDistance`, `decodedToLatLng`. No production imports yet; uses only `flutter_test`.
- `test/widget/features/trips/history_screen_test.dart` — 5 widget stubs with in-memory Drift scaffold (`NativeDatabase.memory()` + `closeStreamsSynchronously: true`) and a `makeSummary` factory ready for Wave 2.
- `test/widget/features/trips/trip_detail_screen_test.dart` — 4 widget stubs with the same Drift scaffold plus `makeGpsTrip` factory using the canonical Google polyline reference `_p~iF~ps|U`.

## Decisions Made

- **markTestSkipped over `skip:` parameter** — keeps the test functions executed and reported as passing (skipped) rather than silently ignored. Wave 2 can convert each stub to a real assertion by replacing the single `markTestSkipped(...)` line.
- **No production imports in stub files** — `history_providers.dart`, `formatters.dart`, `HistoryScreen`, and `TripDetailScreen` do not exist yet, so importing them would break compilation. Wave 1+ adds the imports when the modules land.
- **Helper factories wrapped in `// ignore: unused_element` with documentation** — stubs do not yet call `makeSummary` / `makeGpsTrip`, but the helpers are pre-built so Wave 2 can immediately use them. Lint comment satisfies the `document_ignores` rule from `very_good_analysis`.
- **Drift scaffold cloned verbatim from `edit_trip_sheet_test.dart`** — keeps the in-memory database lifecycle identical to the existing widget-test pattern so Wave 2 has no setup surprises.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `makeGpsTrip` helper used raw values where Drift `Value<>` wrappers are required**
- **Found during:** Task 2 verify step (`flutter test test/widget/features/trips/trip_detail_screen_test.dart`)
- **Issue:** Initial helper passed `userId: ''`, `routePolyline: routePolyline`, `isManualEntry: false`, `createdAt: start`, `updatedAt: start` — but the generated `TripsCompanion.insert` signature expects `Value<String>`, `Value<String?>`, `Value<bool>`, `Value<DateTime>` for these optional companion fields. Compilation failed for `trip_detail_screen_test.dart`, which also broke `history_screen_test.dart` because both were loaded in the same `flutter test` invocation.
- **Fix:** Wrapped the five fields in `const Value(...)` / `Value(...)` to match the generated signature. Verified by re-running the targeted `flutter test` — all 9 widget stubs now load and report as skipped.
- **Files modified:** `test/widget/features/trips/trip_detail_screen_test.dart`
- **Verification:** `flutter test test/widget/features/trips/history_screen_test.dart test/widget/features/trips/trip_detail_screen_test.dart` exits 0 with 9 tests skipped. Full `flutter test` exits 0 with 132 passing / 24 skipped.
- **Committed in:** `2e353d1` (Task 2 commit, fix bundled with the stub creation)

**2. [Rule 1 - Lint] `document_ignores` info-level lint on `// ignore: unused_element` comments**
- **Found during:** Task 2 post-format `flutter analyze`
- **Issue:** `very_good_analysis` flags `// ignore:` directives without an explanatory comment.
- **Fix:** Added `// Helper kept for Wave 2 use; stubs do not yet invoke it.` above each `// ignore: unused_element` directive in both widget-test files.
- **Files modified:** `test/widget/features/trips/history_screen_test.dart`, `test/widget/features/trips/trip_detail_screen_test.dart`
- **Verification:** `flutter analyze` on both files reports `No issues found!`.
- **Committed in:** `2e353d1` (bundled with Task 2)

---

**Total deviations:** 2 auto-fixed (1 compilation bug, 1 lint clean-up).
**Impact on plan:** Both fixes were necessary for the verify step to pass. No scope creep — fixes stayed inside the two new files.

## Issues Encountered

- **Plan-stipulated import for `latlong2` in `formatters_test.dart` not added.** Reason: the production `formatters.dart` does not exist yet; importing `package:latlong2/latlong2.dart` would compile fine but provide no value until Wave 1 wires the helper. Stubs use `markTestSkipped` and add no real assertions, so the import is deferred to Wave 1. This matches the plan's broader "stubs omit production-module imports" guidance for HistoryScreen and TripDetailScreen.

## Next Phase Readiness

- All four stub files exist on disk under their planned paths and are committed on `worktree-agent-a677887e486825025` (the active worktree branch for this plan).
- Wave 1 (Plan 04-02) can immediately implement `groupTripsByDate`, `formatDateHeader`, `formatDuration`, `formatDistance`, and `decodedToLatLng` and then convert the corresponding `markTestSkipped` calls into real assertions.
- Wave 2 (Plan 04-03) can implement `HistoryScreen` and `TripDetailScreen`, uncomment / add the production imports, and fill the widget stubs in using the pre-built `makeSummary` / `makeGpsTrip` helpers.
- No blockers detected for downstream plans.

## Self-Check

- [x] `test/unit/features/trips/history_grouping_test.dart` exists in the worktree.
- [x] `test/unit/shared/formatters_test.dart` exists in the worktree.
- [x] `test/widget/features/trips/history_screen_test.dart` exists in the worktree.
- [x] `test/widget/features/trips/trip_detail_screen_test.dart` exists in the worktree.
- [x] Commit `3b25706` present (Task 1 — unit stubs).
- [x] Commit `2e353d1` present (Task 2 — widget stubs).
- [x] `flutter test` full suite: 132 passing / 24 skipped / 0 failing.
- [x] `flutter analyze` on the four stub files: No issues found.

## Self-Check: PASSED

---
*Phase: 04-trip-history*
*Plan: 01*
*Completed: 2026-04-26*
