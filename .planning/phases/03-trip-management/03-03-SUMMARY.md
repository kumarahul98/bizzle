---
phase: 03-trip-management
plan: "03"
subsystem: trips/providers + tracking/providers + app
tags:
  - manual-entry
  - backfill
  - direction-labeling
  - wave-1
  - tdd
dependency_graph:
  requires:
    - "lib/features/trips/providers/trip_management_providers.dart (Plan 03-02 — sealed state, editTrip, deleteTrip)"
    - "lib/features/trips/services/direction_label_service.dart (Plan 03-01)"
    - "lib/database/daos/trips_dao.dart (insertTrip, updateTrip — Plans 03-01/03-02)"
    - "lib/database/daos/sync_queue_dao.dart (enqueueCreate, enqueueUpdate)"
    - "lib/database/daos/user_preferences_dao.dart (getOrDefault)"
    - "lib/config/constants.dart (kDirectionUnknown, kDirectionToOffice, kDirectionToHome)"
  provides:
    - "TripManagementNotifier.insertManualTrip — D-10 manual trip persistence"
    - "parseHhMm free function — HH:MM validation (0:00–23:59)"
    - "directionBackfillProvider — one-shot FutureProvider labels all kDirectionUnknown rows"
    - "app.dart ConsumerWidget wiring — backfill fires exactly once at startup"
  affects:
    - "lib/features/trips/widgets/manual_entry_sheet.dart (Plan 03-05 — imports parseHhMm)"
    - "lib/features/tracking/screens/home_screen.dart (Plan 03-05 — FAB invokes ManualEntrySheet)"
tech_stack:
  added:
    - "uuid ^4.x — Uuid().v4() for client-side trip ID generation in insertManualTrip"
  patterns:
    - "FutureProvider<void> without autoDispose (keepAlive=true) for one-shot startup work"
    - "toLocal() before DirectionLabelService.label() at every backfill call site (Pitfall 2)"
    - "db.transaction() wrapping all updateTrip+enqueueUpdate for T-03-11 atomicity"
    - "ConsumerWidget in app.dart for ref.watch — lightest approach, no wrapper widget needed"
    - "Local-time DateTime constructors in tests for timezone-deterministic labeling assertions"
key_files:
  created:
    - lib/features/tracking/providers/backfill_provider.dart
  modified:
    - lib/features/trips/providers/trip_management_providers.dart
    - lib/app.dart
    - test/unit/features/trips/manual_entry_notifier_test.dart
    - test/unit/features/trips/backfill_provider_test.dart
    - test/unit/app_bootstrap_test.dart
decisions:
  - "parseHhMm exported from trip_management_providers.dart — co-located with the notifier it feeds (manual_entry_sheet.dart imports both from one place)"
  - "routePolyline passed as const Value('') (empty string) not null — D-10 intent preserved even though column is nullable; empty string signals 'no route' distinctly from absent"
  - "Test start times use local DateTime constructors not UTC — toLocal() is timezone-deterministic on any host; UTC constructors break on non-UTC CI/dev machines (IST UTC+5:30)"
  - "app_bootstrap_test overrides directionBackfillProvider with no-op — prevents pending timer in fake_async widget test from driftDatabase file-open path"
metrics:
  duration_minutes: 7
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 5
  tests_added: 12
  tests_passing: 101
  tests_skipped: 0
  completed_date: "2026-04-25"
---

# Phase 3 Plan 03: insertManualTrip, parseHhMm, and DirectionBackfillProvider Summary

**One-liner:** `insertManualTrip` + `parseHhMm` added to `TripManagementNotifier`, one-shot `directionBackfillProvider` labels all `kDirectionUnknown` rows at startup, and all 12 Wave 0 stubs from Plans 03-01/03-02/03-03 are now passing tests.

## What Was Built

### Task 1: insertManualTrip and parseHhMm (TDD)

Added two exports to `lib/features/trips/providers/trip_management_providers.dart`:

**`TripManagementNotifier.insertManualTrip`**
- Idle→Saving, wraps `insertTrip` + `enqueueCreate` in `appDatabase.transaction()`, then Saving→Saved or Error
- D-10 fields: `isManualEntry=true`, `routePolyline=const Value('')`, `distanceMeters=0`, `timeMovingSeconds=0`, `timeStuckSeconds=0`
- UUID generated client-side via `const Uuid().v4()`
- `startTimeUtc` is expected to be UTC midnight of the chosen local date (Pitfall 6 mitigation delegated to caller — ManualEntrySheet)

**`parseHhMm(String input)` free function**
- Validates HH:MM format: hours 0–23, minutes 0–59; returns null for any malformed input
- Exported from the same file as the notifier so `manual_entry_sheet.dart` (Plan 03-05) can import both from one location

**8 tests passing:**
- 6 `parseHhMm` boundary cases (0:00, 23:59, 24:00, empty, no-colon, non-numeric)
- 2 `insertManualTrip` contract tests (isManualEntry=true/distanceMeters=0.0, epoch-ms round-trip for UTC midnight)

TDD gates: RED commit `8d49d15`, GREEN commit `45300d0`.

### Task 2: DirectionBackfillProvider + app.dart wiring (TDD)

**Created `lib/features/tracking/providers/backfill_provider.dart`**
- `final FutureProvider<void> directionBackfillProvider` — bare (keepAlive=true), no autoDispose (Pitfall 5)
- Queries `db.trips WHERE direction = kDirectionUnknown` then early-returns if empty
- Single `db.transaction()` wrapping all `updateTrip` + `enqueueUpdate` calls (T-03-11 atomicity)
- `trip.startTime.toLocal()` before every `DirectionLabelService.label()` call (Pitfall 2)
- `updatedAt: Value(DateTime.now().toUtc())` in every `TripsCompanion`

**Modified `lib/app.dart`**
- `TraevyApp` changed from `StatelessWidget` to `ConsumerWidget`
- `ref.watch(directionBackfillProvider)` called in `build` — fires once at startup, UI does not block on result

**4 backfill tests passing:**
- Labels kDirectionUnknown trips with correct direction (morning=to_office, evening=to_home)
- Leaves already-labeled trips unchanged
- Enqueues `kSyncActionUpdate` for each backfilled trip
- No-op when no unknown trips exist (sync_queue stays empty)

TDD gates: RED commit `926189d`, GREEN commit `132643a`.

## Verification Results

```
flutter test test/unit/features/trips/manual_entry_notifier_test.dart → 8/8 pass
flutter test test/unit/features/trips/backfill_provider_test.dart     → 4/4 pass
flutter test test/unit/                                                → 101 pass, 0 skipped, 0 fail
flutter analyze (3 production files)                                   → No issues found
```

Prior baseline was 89 passing, 12 skipped. This plan:
- Converted 8 skipped Wave 0 stubs (manual_entry_notifier_test) to passing tests
- Converted 4 skipped Wave 0 stubs (backfill_provider_test) to passing tests
- Net: +12 passing, -12 skipped

All Wave 0 stubs from Phase 3 are now resolved (0 remaining).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] backfill_provider.dart missing database.dart import**
- **Found during:** Task 2 GREEN (compile error)
- **Issue:** `TripsCompanion` is generated into `database.g.dart` which is exported from `database.dart`; the plan's import list omitted it — same issue as Plan 03-02
- **Fix:** Added `import 'package:traevy/database/database.dart';` to `backfill_provider.dart`
- **Files modified:** `lib/features/tracking/providers/backfill_provider.dart`
- **Commit:** `132643a`

**2. [Rule 1 - Bug] backfill tests used UTC start times, causing timezone-dependent labeling failure**
- **Found during:** Task 2 GREEN (test failure on IST host UTC+5:30)
- **Issue:** `DateTime.utc(2026, 4, 25, 8).toLocal()` returns hour 13 in IST (>= 12 → kDirectionToHome, not kDirectionToOffice); context_note in the prompt warned about this but specified "UTC test env" as the assumption, which did not hold
- **Fix:** Changed test start times from `DateTime.utc(...)` to `DateTime(...)` (local constructor) so `toLocal()` returns the same hour regardless of host timezone
- **Files modified:** `test/unit/features/trips/backfill_provider_test.dart`
- **Commit:** `132643a`

**3. [Rule 1 - Bug] app_bootstrap_test failed after TraevyApp → ConsumerWidget change**
- **Found during:** Task 2, full suite run
- **Issue:** `ref.watch(directionBackfillProvider)` in `TraevyApp.build` caused the `FutureProvider` to start an async operation that opened a file-based `driftDatabase`, leaving a pending timer in the flutter_test fake_async harness → assertion `!timersPending` failed
- **Fix:** Updated `app_bootstrap_test.dart` to use `ProviderScope(overrides: [...])` with in-memory DB and a no-op `directionBackfillProvider` override; the test still exercises MaterialApp structure and HomeScreen rendering
- **Files modified:** `test/unit/app_bootstrap_test.dart`
- **Commit:** `132643a`

## Known Stubs

None — all Wave 0 stubs from Phase 3 Plans 01/02/03 are now resolved. Test suite has 0 skipped tests.

## Threat Surface Scan

T-03-07 (parseHhMm input overflow): mitigated — `parseHhMm` validates hours 0–23 and minutes 0–59, returns null for any out-of-range or malformed input.

T-03-10 (DirectionBackfillProvider multiple runs): accepted — keepAlive=true + no autoDispose prevents re-runs in session; already-labeled rows are excluded by the `WHERE direction = kDirectionUnknown` filter (idempotent).

T-03-11 (orphaned sync_queue on backfill failure): mitigated — all `updateTrip` + `enqueueUpdate` calls are inside a single `db.transaction()` — SQLite rolls back on failure.

No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `lib/features/trips/providers/trip_management_providers.dart` — FOUND, contains `Future<void> insertManualTrip(` and `Duration? parseHhMm(String input)`
- `lib/features/tracking/providers/backfill_provider.dart` — FOUND, contains `final FutureProvider<void> directionBackfillProvider`
- `lib/app.dart` — FOUND, contains `ref.watch(directionBackfillProvider)` and `class TraevyApp extends ConsumerWidget`
- `test/unit/features/trips/manual_entry_notifier_test.dart` — FOUND, 8 passing tests (0 skips)
- `test/unit/features/trips/backfill_provider_test.dart` — FOUND, 4 passing tests (0 skips)
- Commits verified: `8d49d15` (RED T1), `45300d0` (GREEN T1), `926189d` (RED T2), `132643a` (GREEN T2)
- `flutter test test/unit/` exits 0 — 101 pass, 0 skipped, 0 fail
