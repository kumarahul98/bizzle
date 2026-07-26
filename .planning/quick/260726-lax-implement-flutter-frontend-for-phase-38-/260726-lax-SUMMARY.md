---
phase: 38-account-data-deletion
plan: 01
subsystem: auth
tags: [riverpod, drift, http, sealed-classes, firebase-auth, google-sign-in, play-compliance]

# Dependency graph
requires:
  - phase: 11-sync-engine
    provides: ApiClient's _send/_headers/SyncException classification, the double-wrap envelope-unwrap pattern
  - phase: 32-identity-dashboard-personalization
    provides: the account sheet (_AccountSheetContent, _confirmSignOut) this plan's Delete-account row is added to
provides:
  - "TripsDao.deleteAllTrips() / SyncQueueDao.clearAll() — hard-wipe DAOs with FK-cascade to trip_breaks/trip_stuck_segments"
  - "ApiClient.deleteAllTrips() (DELETE /trips) / ApiClient.deleteAccount() (DELETE /account)"
  - "DeleteTripsController + Settings 'Delete all data' row (guest AND signed-in)"
  - "AuthService.deleteAccount() (server-first ordered wipe) + DeleteAccountController + account-sheet 'Delete account' row (signed-in only)"
affects: [39-release-play-internal-testing, backend-phase-38-endpoints]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sealed DeleteTripsState / DeleteAccountState (Idle/InProgress/Success/Error) mirroring RestoreState — PII guard: Error variants carry no error detail"
    - "Manual Notifier<T> + keepAlive NotifierProvider (no @riverpod codegen) for both new controllers, matching the project-wide drift_dev/analyzer pin"
    - "Server-first-then-local-wipe ordering in AuthService.deleteAccount() — propagates on API failure so local data is never wiped while the server account still exists"

key-files:
  created:
    - lib/sync/delete_trips_controller.dart
    - lib/features/settings/widgets/delete_all_data_row.dart
    - lib/features/auth/providers/delete_account_controller.dart
    - test/unit/database/trips_dao_delete_all_test.dart
    - test/unit/sync/delete_trips_controller_test.dart
    - test/unit/features/auth/delete_account_controller_test.dart
  modified:
    - lib/config/constants.dart
    - lib/database/daos/trips_dao.dart
    - lib/database/daos/sync_queue_dao.dart
    - lib/sync/api_client.dart
    - lib/features/auth/services/auth_service.dart
    - lib/features/auth/providers/auth_providers.dart
    - lib/features/dashboard/widgets/account_sheet.dart
    - lib/features/settings/screens/settings_screen.dart
    - test/unit/database/sync_queue_dao_test.dart
    - test/unit/sync/api_client_test.dart
    - test/unit/features/auth/auth_service_test.dart
    - test/widget/features/dashboard/account_sheet_test.dart
    - test/unit/sync/sync_engine_test.dart
    - test/sync/restore_controller_test.dart
    - lib/firebase_options.dart

key-decisions:
  - "AuthService.deleteAccount() propagates on API failure (unlike its own controller) — mirrors signIn()'s discipline so a caller that skips the controller layer still gets a hard failure rather than a silently wiped local device"
  - "DeleteTripsController checks authStateProvider (not a passed-in flag) to decide guest-vs-signed-in, keeping the guest/signed-in branch logic in one place instead of duplicating it at each call site"
  - "Delete-all-data success snackbar uses one fixed 'All data deleted' message rather than a singular/plural trip-count template — simpler, and the plan explicitly allowed either"
  - "Two pre-existing hand-rolled ApiClient fakes (test/unit/sync/sync_engine_test.dart, test/sync/restore_controller_test.dart) had no noSuchMethod fallback and broke when ApiClient gained two new methods; fixed with the same throw-loudly pattern already used there for the Phase 29 preferences guards"

patterns-established:
  - "Any new ApiClient method must be added to test/unit/sync/sync_engine_test.dart's FakeApiClient and test/sync/restore_controller_test.dart's FakeApiClient (both lack noSuchMethod) or those suites fail to compile"

requirements-completed: [DEL-ALL-DATA, DEL-ACCOUNT]

# Metrics
duration: ~55min
completed: 2026-07-26
---

# Phase 38 Plan 01: Account & Data Deletion (Flutter frontend) Summary

Two new destructive, Play-compliance-driven user actions — "Delete all data" (Settings, guest+signed-in) and "Delete account" (account sheet, signed-in only) — each backed by a sealed-state manual `Notifier` controller, a fixed-copy confirm dialog, and a PII-free error path, wired against a fixed backend contract (`DELETE /trips`, `DELETE /account`) built in parallel.

## Performance

- **Duration:** ~55 min
- **Tasks:** 6/6 completed
- **Files modified:** 21 (6 new, 15 modified)

## Accomplishments

- `TripsDao.deleteAllTrips()` / `SyncQueueDao.clearAll()` hard-wipe DAOs, with the trip wipe confirmed to cascade to `trip_breaks` + `trip_stuck_segments` under `PRAGMA foreign_keys = ON`.
- `ApiClient.deleteAllTrips()` / `ApiClient.deleteAccount()` added, reusing the existing `_send`/`_headers`/401-refresh-retry/`SyncException` classification path — no new auth surface introduced client-side.
- `DeleteTripsController` (guest: local-only; signed-in: server-first) + `DeleteAllDataRow` wired into Settings → Data, below the existing Trash row, for both guest and signed-in users.
- `AuthService.deleteAccount()` — ordered server-first wipe (`deleteAccount()` → `deleteAllTrips()` → `clearAll()` → `signOut()`), propagating on API failure so local data and the session survive intact if the server call fails.
- `DeleteAccountController` + a new "Delete account" row in the account sheet's signed-in branch (below Sign out), with an error-styled confirm dialog, an in-flight spinner, a fixed error snackbar, and a pop-on-success flow that lets the existing `authStateProvider`-driven guest/signed-in switch handle the re-render.

## Task Commits

1. **Task 1: Constants + DAO wipes** - `4ab69b5` (feat)
2. **Task 2: ApiClient.deleteAllTrips() + deleteAccount()** - `8e6bd93` (feat)
3. **Task 3: DeleteTripsController + Settings row** - `469c15b` (feat)
4. **Task 4: AuthService.deleteAccount() + provider wiring + DeleteAccountController** - `abe1155` (feat)
5. **Task 5: Account sheet "Delete account" row** - `22591e4` (feat)
6. **Task 6: Full verification sweep** - `2dc4504` (fix)

## Files Created/Modified

- `lib/config/constants.dart` - new `kDeleteAllTripsPath`/`kDeleteAccountPath` + all Delete-all-data/Delete-account copy constants
- `lib/database/daos/trips_dao.dart` - `deleteAllTrips()` (hard wipe, cascades)
- `lib/database/daos/sync_queue_dao.dart` - `clearAll()` (hard wipe)
- `lib/sync/api_client.dart` - `deleteAllTrips()` (envelope-unwrap `deletedCount`), `deleteAccount()` (bare 2xx/non-2xx)
- `lib/sync/delete_trips_controller.dart` **(new)** - `DeleteTripsController` + sealed `DeleteTripsState`
- `lib/features/settings/widgets/delete_all_data_row.dart` **(new)** - Settings row, confirm dialog, snackbar feedback
- `lib/features/settings/screens/settings_screen.dart` - wires `DeleteAllDataRow` into `_DataSection`
- `lib/features/auth/services/auth_service.dart` - `deleteAccount()` (server-first ordered wipe), optional injectable `ApiClient`
- `lib/features/auth/providers/auth_providers.dart` - `authServiceProvider` now injects the real `ApiClient`
- `lib/features/auth/providers/delete_account_controller.dart` **(new)** - `DeleteAccountController` + sealed `DeleteAccountState`
- `lib/features/dashboard/widgets/account_sheet.dart` - "Delete account" row + `_confirmDeleteAccount` helper
- Test files: `trips_dao_delete_all_test.dart` (new), `sync_queue_dao_test.dart`, `api_client_test.dart`, `delete_trips_controller_test.dart` (new), `auth_service_test.dart`, `delete_account_controller_test.dart` (new), `account_sheet_test.dart`, `sync_engine_test.dart`, `test/sync/restore_controller_test.dart`
- `lib/firebase_options.dart` - trailing-newline-only whitespace fix (see Deviations)

## Decisions Made

See `key-decisions` in the frontmatter. The most consequential: `AuthService.deleteAccount()` propagates on API failure rather than catching it, matching `signIn()`'s existing discipline — the controller layer (`DeleteAccountController`) is the one place errors are swallowed into a UI-safe sealed state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Two pre-existing `ApiClient` fakes broke when `ApiClient` gained two new methods**
- **Found during:** Task 6 (full verification sweep, `flutter analyze`)
- **Issue:** `test/unit/sync/sync_engine_test.dart`'s `FakeApiClient` and `test/sync/restore_controller_test.dart`'s `FakeApiClient` both `implements ApiClient` directly with no `noSuchMethod` fallback. Adding `deleteAllTrips()`/`deleteAccount()` to `ApiClient` in Task 2 made both classes fail `non_abstract_class_inherits_abstract_member` — a hard compile error, not a lint.
- **Fix:** Added `deleteAllTrips()`/`deleteAccount()` overrides to both fakes that `throw UnimplementedError(...)`, mirroring the existing Phase 29 "must not touch preferences" throw-loudly guards already present in the same classes (`SyncEngine` never touches these Phase 38 endpoints; the restore-conflict flow never touches them either).
- **Files modified:** `test/unit/sync/sync_engine_test.dart`, `test/sync/restore_controller_test.dart`
- **Verification:** `flutter analyze` — 0 errors (was 2); full suites still green.
- **Committed in:** `2dc4504`

**2. [Rule 3 - Blocking issue] `dart format --set-exit-if-changed .` failed on a pre-existing file**
- **Found during:** Task 6 (`dart format --set-exit-if-changed .` gate)
- **Issue:** `lib/firebase_options.dart` was missing a trailing newline — pre-existing since Phase 37 (`3701dd3`), untouched by this plan otherwise. The mandated gate command rewrites and fails on any file needing reformatting, regardless of who last touched it.
- **Fix:** Ran `dart format` on the one file to add the trailing newline; no other content changed (confirmed via `git diff`).
- **Files modified:** `lib/firebase_options.dart`
- **Verification:** `dart format --set-exit-if-changed .` now exits 0.
- **Committed in:** `2dc4504`

---

**Total deviations:** 2 auto-fixed (1× Rule 1, 1× Rule 3).
**Impact on plan:** Both fixes were required to satisfy Task 6's mandated verification gates and touched only test infrastructure / a one-line whitespace issue in an unrelated file. No scope creep into the Phase 38 feature itself.

### Out-of-scope items NOT fixed (documented, not touched)

`flutter analyze` reports 295 pre-existing `info`-level lints scattered across ~60 test files this plan never touched (`test/unit/features/tracking/`, `test/unit/notifications/`, `test/widget/features/settings/conflict_resolution_sheet_test.dart`, `test/widget/shared/widgets/*`, etc. — line-length, `avoid_redundant_argument_values`, `avoid_types_on_closure_parameters`, and similar). These predate this quick task (confirmed via `git diff` against the pre-Phase-38 commit) and are out of this plan's Scope Boundary. Zero **errors** exist; the plan's own new/modified files have zero analyzer issues beyond the two pre-existing ones noted above (`lib/features/settings/screens/settings_screen.dart:186` line-length, `test/unit/features/auth/auth_service_test.dart:20,24` line-length — both pre-existing, confirmed unrelated to Phase 38 edits).

## Issues Encountered

None beyond the deviations above.

## User Setup Required

None - no external service configuration required. The backend endpoints (`DELETE /trips`, `DELETE /account`) are being built in parallel against the fixed contract described in the plan; `backend/functions/` was never touched by this plan.

## Next Phase Readiness

Frontend half of Phase 38 is code-complete: two new REST methods, two DAO wipes, two sealed-state manual-Notifier controllers, two UI rows wired into Settings → Data and the account sheet, full unit-test coverage (guest/signed-in/error paths on both flows), and `user_preferences` / `backend/functions/` both confirmed untouched. Blocked on: the parallel backend agent's `DELETE /trips` and `DELETE /account` handlers landing and deploying before this can be exercised end-to-end on a real device; that verification is out of this plan's scope.

---
*Phase: 38-account-data-deletion*
*Completed: 2026-07-26*

## Self-Check: PASSED

All 6 created files verified present on disk; all 6 task commits (`4ab69b5`, `8e6bd93`, `469c15b`, `abe1155`, `22591e4`, `2dc4504`) verified present in `git log`.
