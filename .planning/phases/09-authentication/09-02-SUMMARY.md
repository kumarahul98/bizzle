---
phase: 09-authentication
plan: "02"
subsystem: auth
tags: [sealed-state, drift-dao, backfill, wave-2, tdd, auth-state]
dependency_graph:
  requires:
    - 09-01 (Phase 9 constants, kDefaultUserId, RED test contracts)
  provides:
    - sealed AuthState (loading/guest/signedIn) with const subtypes
    - TripsDao.backfillUserId(String) -> Future<int>
    - UserPreferencesDao.backfillUserId(String) -> Future<int>
    - minimal auth_providers.dart shell (firebaseReadyProvider, AuthStateNotifier, authStateProvider)
  affects:
    - lib/features/auth/models/auth_state.dart (new)
    - lib/features/auth/providers/auth_providers.dart (new)
    - lib/database/daos/trips_dao.dart (backfillUserId added)
    - lib/database/daos/user_preferences_dao.dart (backfillUserId added)
tech_stack:
  added: []
  patterns:
    - Sealed class with @immutable base + final-class subtypes + const singletons (tracking_state.dart analog)
    - Explicit-WHERE Drift UPDATE — (update(table)..where(...)).write(Companion(...)) — never .replace()
    - Future<int> return from .write() used as first-sign-in signal (changed-row count)
key_files:
  created:
    - lib/features/auth/models/auth_state.dart
    - lib/features/auth/providers/auth_providers.dart
  modified:
    - lib/database/daos/trips_dao.dart
    - lib/database/daos/user_preferences_dao.dart
decisions:
  - auth_providers.dart created as Rule 3 deviation — auth_state_notifier_test.dart imports auth_providers at compile time even for skip-tagged tests; without the file the test suite cannot load
  - AuthStateNotifier shell in auth_providers.dart returns AuthGuest (firebaseReady=false) or AuthLoading (firebaseReady=true); full stream subscription deferred to Plan 09-03
  - auth_providers.dart declares firebaseReadyProvider with default value false so test overrides work without a real Firebase config
metrics:
  duration: "12 minutes"
  completed_date: "2026-05-29"
  tasks_completed: 2
  files_changed: 4
---

# Phase 09 Plan 02: AuthState Model + DAO Backfill Summary

Sealed `AuthState` (loading / guest / signedIn) created matching the `tracking_state.dart` shape; `backfillUserId` added to both DAOs using the explicit-WHERE pattern, returning changed-row count; Plan 09-01 `backfill_test.dart` RED contract turned GREEN (9/9 tests pass).

## What Was Built

### Task 1: Sealed AuthState model

Created `lib/features/auth/models/auth_state.dart`:

- `@immutable sealed class AuthState` base with `const AuthState()` constructor
- `final class AuthLoading extends AuthState` — const singleton (identical() at every call site), initial/transient state while Firebase initialises
- `final class AuthGuest extends AuthState` — const singleton, valid permanent state for unsigned-in users (D-06 contract)
- `final class AuthSignedIn extends AuthState` — payload subtype with `final String uid`, `final String name`, `final String email`, all required-named in a const constructor

Matches the `tracking_state.dart` shape exactly: `@immutable` base, `final class` subtypes, const singletons for zero-payload variants, payload subtype for the data-carrying variant. Dartdoc on the sealed base explains the exhaustive switch contract and prohibits `default` branches.

Also created a minimal `lib/features/auth/providers/auth_providers.dart` (Rule 3 deviation — see Deviations section) so the Wave 0 `auth_state_notifier_test.dart` compiles.

**Verification:** `flutter analyze lib/features/auth/models/auth_state.dart` — zero issues. `auth_state_notifier_test.dart` Groups 1 and 2 (sealed-subtype identity + exhaustive switch) pass GREEN; Group 3 tests remain appropriately skipped with `RED — requires fake FirebaseAuth stream injection (Plan 09-02)` labels for Plan 09-03.

### Task 2: backfillUserId on TripsDao and UserPreferencesDao

Modified `lib/database/daos/trips_dao.dart`:
- Added `import 'package:traevy/config/constants.dart'` (kDefaultUserId)
- Added `Future<int> backfillUserId(String newUserId)` using explicit-WHERE: `(update(trips)..where((t) => t.userId.equals(kDefaultUserId))).write(TripsCompanion(userId: Value(newUserId)))`
- Returns the `.write()` result directly (changed-row count for first-sign-in D-12 signal)

Modified `lib/database/daos/user_preferences_dao.dart`:
- Added `Future<int> backfillUserId(String newUserId)` using the same pattern on `userPreferences` table
- Documented that callers key off the trips count for the D-12 first-sign-in signal; prefs count returned for symmetry

Both methods use dartdoc matching `updateTrip`'s style: D-11 reference, explicit-WHERE pitfall mitigation note, "Never use .replace() for partial updates" mandate.

**Verification:** `flutter test test/unit/features/auth/backfill_test.dart` — 9/9 tests GREEN. `flutter analyze lib/database/daos/trips_dao.dart lib/database/daos/user_preferences_dao.dart` — zero issues. `grep "\.replace(" ...` finds only doc-comment occurrences, no actual calls.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created auth_providers.dart to unblock test compilation**
- **Found during:** Task 1 (test verification — `auth_state_notifier_test.dart` imports `auth_providers.dart` at the top level even though Group 3 tests are `skip:`-tagged; Dart compiles all imports regardless of skip)
- **Issue:** Without `auth_providers.dart`, `flutter test test/unit/features/auth/auth_state_notifier_test.dart` fails with `Error when reading 'lib/features/auth/providers/auth_providers.dart': No such file or directory` before any tests run
- **Fix:** Created a minimal `auth_providers.dart` with `firebaseReadyProvider` (Provider<bool>, default false), a skeletal `AuthStateNotifier extends Notifier<AuthState>` (returns AuthGuest or AuthLoading in build() based on firebaseReady flag), and `authStateProvider` (NotifierProvider). Full stream subscription is Plan 09-03 scope.
- **Files modified:** `lib/features/auth/providers/auth_providers.dart` (new)
- **Commit:** f872371

## Wave 0 Status After Plan 09-02

| File | Before | After | Tests |
|------|--------|-------|-------|
| google_sign_in_api_probe_test.dart | GREEN | GREEN | 8/8 pass |
| auth_state_notifier_test.dart | RED (compile fail) | GREEN/SKIP | 5 pass, 4 skipped |
| auth_service_test.dart | RED (compile fail) | RED (AuthService missing) | Plan 09-03 target |
| backfill_test.dart | RED (compile fail) | GREEN | 9/9 pass |

`auth_service_test.dart` remains RED because `AuthService` is Plan 09-03's scope — this is expected and not a regression.

## Known Stubs

- `AuthStateNotifier.build()` in `auth_providers.dart` does not subscribe to `FirebaseAuth.instance.authStateChanges()` — it returns `const AuthLoading()` (firebaseReady=true path) as a compile-correct placeholder. Full subscription with stream cancel in `ref.onDispose` is Plan 09-03 scope. The shell is sufficient to make the sealed-subtype tests compile and run.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes introduced. T-09-02-01 (backfill UPDATE tamper) mitigated: explicit `WHERE userId = kDefaultUserId` scopes the rewrite; never `.replace()`. T-09-02-02 (partial backfill repudiation) noted: atomicity to be enforced by AuthService transaction wrapper in Plan 09-03.

## Self-Check: PASSED
