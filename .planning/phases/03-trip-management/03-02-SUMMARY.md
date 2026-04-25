---
phase: 03-trip-management
plan: "02"
subsystem: trips/providers + tracking/services
tags:
  - notifier
  - sealed-state
  - transaction
  - direction-labeling
  - wave-1
dependency_graph:
  requires:
    - "lib/database/daos/trips_dao.dart (updateTrip, deleteTrip — Plan 03-01)"
    - "lib/database/daos/sync_queue_dao.dart (enqueueUpdate, enqueueDelete)"
    - "lib/features/trips/services/direction_label_service.dart (Plan 03-01)"
    - "lib/database/daos/user_preferences_dao.dart (getOrDefault)"
    - "lib/config/constants.dart (kDefaultUserId, kSyncActionUpdate, kSyncActionDelete)"
  provides:
    - "TripManagementNotifier — edit/delete with Idle→Saving→Saved/Error sealed state"
    - "tripManagementProvider — NotifierProvider<TripManagementNotifier, TripManagementState>"
    - "persistFinalizedTrip — labels direction at save time via DirectionLabelService (D-06)"
  affects:
    - "lib/features/trips/ (Plan 03-04 edit sheet wires tripManagementProvider)"
    - "lib/features/tracking/ (all new trips now have real direction, not kDirectionUnknown)"
tech_stack:
  added: []
  patterns:
    - "Sealed TripManagementState with Idle/Saving/Saved/Error variants — matches TrackingState pattern"
    - "appDatabase.transaction() wrapping both DAO calls for atomicity (D-08)"
    - "Pitfall 3 mitigation: deleteTrip payload built before row deletion inside transaction"
    - "DirectionLabelService.label() called before transaction; getOrDefault() is async-safe outside Drift tx"
    - "Constructor injection of UserPreferencesDao as 6th required parameter"
key_files:
  created:
    - lib/features/trips/providers/trip_management_providers.dart
  modified:
    - lib/features/tracking/services/tracking_service_controller.dart
    - lib/features/tracking/providers/tracking_providers.dart
    - test/unit/features/trips/trip_management_notifier_test.dart
    - test/unit/features/tracking/persist_finalized_trip_test.dart
    - test/unit/features/tracking/tracking_notifier_test.dart
decisions:
  - "Direction labeling (getOrDefault + DirectionLabelService.label) placed BEFORE the Drift transaction — Drift transactions should not span async DAO calls outside their scope; prefs read is outside the tx boundary for correctness"
  - "Pitfall 3 mitigation: deleteTrip JSON payload built from known tripId + kDefaultUserId without a DB read — no risk of payload-after-delete race"
  - "existing test kDirectionUnknown direction assertion updated to isNot(kDirectionUnknown) — Phase 3 D-06 change breaks the old Phase 2 expectation, updating is correct"
metrics:
  duration_minutes: 4
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 5
  tests_added: 5
  tests_passing: 89
  tests_skipped: 12
  completed_date: "2026-04-25"
---

# Phase 3 Plan 02: TripManagementNotifier and Direction Labeling Summary

**One-liner:** `TripManagementNotifier` sealed-state notifier with atomic edit/delete transactions, plus `DirectionLabelService` wired into `persistFinalizedTrip` so all new trips are labeled `to_office`/`to_home` at save time instead of `unknown`.

## What Was Built

### Task 1: TripManagementNotifier (TDD)

Created `lib/features/trips/providers/trip_management_providers.dart`:

- `TripManagementState` — sealed class with `TripManagementIdle`, `TripManagementSaving`, `TripManagementSaved`, `TripManagementError(message)` variants. `@immutable`, `final class` variants — matches `TrackingState` pattern exactly.
- `TripManagementNotifier.editTrip()` — Idle→Saving, wraps `updateTrip` + `enqueueUpdate` in `appDatabase.transaction()`, then Saving→Saved or Error. Passes `durationSeconds` computed from the UTC time difference.
- `TripManagementNotifier.deleteTrip()` — Idle→Saving, builds JSON payload (`{id, userId}`) BEFORE `deleteTrip` call (Pitfall 3), then both DAO calls in transaction, Saving→Saved or Error.
- `TripManagementNotifier.reset()` — returns state to Idle for UI to call after consuming Saved or Error.
- `tripManagementProvider` — bare `NotifierProvider`, keepAlive=true by Riverpod 3.x default.

TDD gates followed: RED commit (`12ba49b`) with 4 tests failing to compile, GREEN commit (`adea1a8`) with all 4 passing.

### Task 2: Wire DirectionLabelService into TrackingServiceController

Modified `lib/features/tracking/services/tracking_service_controller.dart`:

- Added imports for `UserPreferencesDao` and `DirectionLabelService`.
- Added `required UserPreferencesDao userPreferencesDao` as 6th constructor parameter with matching `_userPreferencesDao` private field.
- In `persistFinalizedTrip`, replaced `direction: kDirectionUnknown` with a pre-transaction call to `_userPreferencesDao.getOrDefault()` then `const DirectionLabelService().label(trip.startTime.toLocal(), prefs.morningCutoffHour)`. The `getOrDefault()` call lives BEFORE the Drift transaction (D-06, Pitfall 2: UTC→local conversion at call site).

Modified `lib/features/tracking/providers/tracking_providers.dart`:

- Added `userPreferencesDao: ref.watch(userPreferencesDaoProvider)` to `trackingServiceControllerProvider` constructor call.

Updated three test files to pass `userPreferencesDao: db.userPreferencesDao` to all `TrackingServiceController` constructions:

- `persist_finalized_trip_test.dart` — updated old `expect(direction, kDirectionUnknown)` to `isNot(kDirectionUnknown)` (Phase 3 D-06 change), added new D-06 direction-labeling test. 5 tests pass.
- `tracking_notifier_test.dart` — added `userPreferencesDao` to `_RecordingController` super-constructor call and setUp.

## Verification Results

```
flutter test test/unit/features/trips/trip_management_notifier_test.dart → 4/4 pass
flutter test test/unit/features/tracking/persist_finalized_trip_test.dart → 5/5 pass
flutter test test/unit/ → 89 pass, 12 skipped, 0 fail
flutter analyze (3 files) → No issues found
```

Prior baseline was 84 passing, 16 skipped. This plan:
- Converted 4 skipped Wave 0 stubs (trip_management_notifier_test) to real passing tests
- Added 1 new test (D-06 direction assertion in persist_finalized_trip_test)
- Net: +5 passing, -4 skipped

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `TripsCompanion` not found via `drift` + `providers.dart` imports alone**
- **Found during:** Task 1 analyze after creating `trip_management_providers.dart`
- **Issue:** `TripsCompanion` is generated into `database.g.dart` which is exported from `database.dart`; the plan's import list omitted `package:traevy/database/database.dart`
- **Fix:** Added `import 'package:traevy/database/database.dart';` to `trip_management_providers.dart`
- **Files modified:** `lib/features/trips/providers/trip_management_providers.dart`
- **Commit:** `adea1a8`

**2. [Rule 1 - Bug] `tracking_notifier_test.dart` broke after constructor parameter addition**
- **Found during:** Task 2, full suite run
- **Issue:** `_RecordingController` extends `TrackingServiceController` and used only 5 named super-params; adding the 6th required param caused a compile error in the existing test file
- **Fix:** Added `required super.userPreferencesDao` to `_RecordingController` constructor and `userPreferencesDao: db.userPreferencesDao` to the setUp construction call
- **Files modified:** `test/unit/features/tracking/tracking_notifier_test.dart`
- **Commit:** `38608cf`

**3. [Rule 1 - Bug] `persist_finalized_trip_test.dart` direction assertion was stale after D-06**
- **Found during:** Task 2 (expected — the plan noted direction changes from unknown to labeled)
- **Issue:** Existing test asserted `expect(summaries.single.direction, kDirectionUnknown)` which is now false post-D-06
- **Fix:** Updated to `expect(summaries.single.direction, isNot(kDirectionUnknown))` and added a dedicated D-06 test
- **Files modified:** `test/unit/features/tracking/persist_finalized_trip_test.dart`
- **Commit:** `38608cf`

## Known Stubs

None in this plan. The 12 remaining skipped tests are Wave 0 stubs for Plan 03-03:
- `manual_entry_notifier_test.dart` — 8 stubs for Plan 03-03
- `backfill_provider_test.dart` — 4 stubs for Plan 03-03

## Threat Surface Scan

No new network endpoints, auth paths, or file access patterns introduced. All changes operate within the existing DAO/Riverpod/Drift layer.

T-03-04 (Pitfall 3 mitigation): deleteTrip payload `{id, userId: kDefaultUserId}` is built from known constants before the DB delete — no user-controlled input reaches the payload construction.

T-03-06 (D-06 direction labeling): `DirectionLabelService.label()` returns only `kDirectionToOffice` or `kDirectionToHome`; no user-controlled input reaches this call in `persistFinalizedTrip`.

## Self-Check: PASSED

- `lib/features/trips/providers/trip_management_providers.dart` — FOUND, contains `sealed class TripManagementState`, `Future<void> editTrip(`, `Future<void> deleteTrip(`
- `lib/features/tracking/services/tracking_service_controller.dart` — FOUND, does NOT contain `direction: kDirectionUnknown`, DOES contain `DirectionLabelService`
- `lib/features/tracking/providers/tracking_providers.dart` — FOUND, contains `userPreferencesDao: ref.watch(userPreferencesDaoProvider)`
- `test/unit/features/trips/trip_management_notifier_test.dart` — FOUND, 4 passing tests (no skips)
- `test/unit/features/tracking/persist_finalized_trip_test.dart` — FOUND, 5 passing tests including D-06 direction assertion
- Commits verified: `12ba49b` (RED), `adea1a8` (GREEN), `38608cf` (Task 2)
- `flutter test test/unit/` exits 0 — 89 pass, 12 skipped, 0 fail
