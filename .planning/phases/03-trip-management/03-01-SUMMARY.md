---
phase: 03-trip-management
plan: "01"
subsystem: database/trips
tags:
  - dao
  - direction-labeling
  - test-stubs
  - wave-0
dependency_graph:
  requires:
    - "lib/database/daos/trips_dao.dart (existing insertTrip, watchAllSummaries)"
    - "lib/config/constants.dart (kDirectionToOffice, kDirectionToHome, kDirectionUnknown)"
  provides:
    - "TripsDao.updateTrip — partial update with explicit WHERE (Pitfall 4 safe)"
    - "TripsDao.deleteTrip — hard delete, caller wraps in appDatabase.transaction()"
    - "DirectionLabelService — pure stateless morning-cutoff labeler"
    - "Wave 0 test stubs — 16 skip-flagged stubs for Plans 03-02 and 03-03"
  affects:
    - "lib/features/trips/ (all Wave 1 plans depend on DirectionLabelService)"
    - "lib/features/tracking/providers/backfill_provider.dart (Plan 03-03)"
tech_stack:
  added: []
  patterns:
    - "Explicit WHERE on Drift update companion (Pitfall 4 mitigation)"
    - "Stateless const class for pure transform utilities"
    - "Wave 0 skip-flagged stubs — Nyquist rule enforcement"
key_files:
  created:
    - lib/features/trips/services/direction_label_service.dart
    - test/unit/features/trips/direction_label_service_test.dart
    - test/unit/features/trips/trip_management_notifier_test.dart
    - test/unit/features/trips/manual_entry_notifier_test.dart
    - test/unit/features/trips/backfill_provider_test.dart
  modified:
    - lib/database/daos/trips_dao.dart
    - test/unit/database/trips_dao_test.dart
decisions:
  - "Pitfall 4 mitigation: updateTrip uses explicit WHERE (t) => t.id.equals(companion.id.value) — never update().replace()"
  - "deleteTrip doc comment mandates transaction wrapper per D-08; method itself is standalone for testability"
  - "DirectionLabelService uses const constructor — callers pay zero allocation cost"
  - "comment_references info hints resolved by using backtick code style over bracket style in class-level doc comments"
metrics:
  duration_minutes: 12
  tasks_completed: 2
  tasks_total: 2
  files_created: 5
  files_modified: 2
  tests_added: 19
  tests_passing: 84
  tests_skipped: 16
  completed_date: "2026-04-25"
---

# Phase 3 Plan 01: DAO Extensions and Wave 0 Test Stubs Summary

**One-liner:** `updateTrip`/`deleteTrip` added to TripsDao with Pitfall 4 WHERE-clause safety, plus `DirectionLabelService` pure labeler and 16 Wave 0 skip-flagged test stubs for Plans 03-02 and 03-03.

## What Was Built

### Task 1: Extend TripsDao with updateTrip and deleteTrip (TDD)

Added two methods to `lib/database/daos/trips_dao.dart`:

- `updateTrip(TripsCompanion companion)` — partial update using an explicit `..where((t) => t.id.equals(companion.id.value))` clause. Doc comment explains Pitfall 4 (WHERE-clause omission on Drift update) and instructs callers to always pass `updatedAt: Value(DateTime.now().toUtc())`.
- `deleteTrip(String id)` — hard delete by primary key. Doc comment mandates it be called inside `appDatabase.transaction()` per D-08 so the local delete and the sync-queue tombstone are atomic.

Three new test cases added to `test/unit/database/trips_dao_test.dart`:
1. `updateTrip only mutates the targeted row` — inserts two rows, updates one, asserts the other is unchanged (Pitfall 4 guard)
2. `deleteTrip removes only the targeted row` — inserts two rows, deletes one, asserts remaining count is 1
3. `manual entry insert has isManualEntry=true, distanceMeters=0.0` — validates the D-10 manual entry contract

TDD gates followed: RED commit (`ef30c01`) with failing compilation, GREEN commit (`5d0b4fc`) with all 6 tests passing.

### Task 2: DirectionLabelService and Wave 0 Test Stubs

**Production file created:** `lib/features/trips/services/direction_label_service.dart`
- Stateless `const` class following the `polyline_codec.dart` analog pattern
- Single method `label(DateTime startTimeLocal, int morningCutoffHour)` implementing D-04: `hour < cutoff → kDirectionToOffice`, `hour >= cutoff → kDirectionToHome`
- Zero imports except `constants.dart` — no Riverpod, no async

**Test file created (fully implemented):** `test/unit/features/trips/direction_label_service_test.dart`
- 7 passing tests covering: before/at/after cutoff, midnight edge case, UTC-offset pitfall (IST 05:30 = UTC 00:00), custom cutoff values

**Stub test files created (16 skipped stubs):**
- `trip_management_notifier_test.dart` — 4 stubs for Plan 03-02 (editTrip, deleteTrip atomicity, state transitions)
- `manual_entry_notifier_test.dart` — 8 stubs for Plan 03-03 (parseHhMm validation, insertManualTrip contract)
- `backfill_provider_test.dart` — 4 stubs for Plan 03-03 (backfill behavior, one-shot guarantee)

## Verification Results

```
flutter test test/unit/database/trips_dao_test.dart   → 6/6 pass
flutter test test/unit/features/trips/direction_label_service_test.dart → 7/7 pass
flutter test test/unit/                               → 84 pass, 16 skipped, 0 fail
flutter analyze lib/database/daos/trips_dao.dart lib/features/trips/services/direction_label_service.dart → No issues found
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Quality] Fixed comment_references info warnings in doc comments**
- **Found during:** Task 1 (trips_dao.dart) and Task 2 (direction_label_service.dart)
- **Issue:** Bracket-style `[companion.id]` and `[startTimeLocal]` references in class-level and method-level doc comments triggered `comment_references` info from `very_good_analysis` because the referenced identifiers were not in scope at the doc-comment location
- **Fix:** Changed bracket references `[companion.id]`, `[Value(...)]`, `[startTimeLocal]`, `[morningCutoffHour]` to backtick code style in the specific locations where the referenced names were not resolvable
- **Files modified:** `lib/database/daos/trips_dao.dart`, `lib/features/trips/services/direction_label_service.dart`
- **Result:** `flutter analyze` reports 0 issues on both files

None - all other plan elements executed exactly as written.

## Known Stubs

All stubs are intentional Wave 0 placeholders — the plan explicitly specifies them as `skip: 'Wave 0 stub — implement in Plan 03-0X'`. They do not prevent this plan's goals from being achieved. Wave 1 plans (03-02, 03-03) will unskip and implement them.

| File | Stubs | Resolved in |
|------|-------|-------------|
| `trip_management_notifier_test.dart` | 4 | Plan 03-02 |
| `manual_entry_notifier_test.dart` | 8 | Plan 03-03 |
| `backfill_provider_test.dart` | 4 | Plan 03-03 |

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. Both files operate entirely within the DAO/utility layer with no external trust boundaries.

## Self-Check: PASSED

- `lib/database/daos/trips_dao.dart` — FOUND, contains `Future<void> updateTrip(TripsCompanion` and `Future<void> deleteTrip(String id)`
- `lib/features/trips/services/direction_label_service.dart` — FOUND, exports `DirectionLabelService`
- `test/unit/features/trips/direction_label_service_test.dart` — FOUND, 7 passing tests
- `test/unit/features/trips/trip_management_notifier_test.dart` — FOUND, 4 skipped stubs
- `test/unit/features/trips/manual_entry_notifier_test.dart` — FOUND, 8 skipped stubs
- `test/unit/features/trips/backfill_provider_test.dart` — FOUND, 4 skipped stubs
- Commits verified: `ef30c01` (RED), `5d0b4fc` (GREEN/DAO), `570ed22` (service + stubs)
- `flutter test test/unit/` exits 0 — confirmed above
