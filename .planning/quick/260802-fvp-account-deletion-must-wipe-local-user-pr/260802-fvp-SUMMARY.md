---
phase: quick-260802-fvp
plan: 01
subsystem: auth
tags: [drift, flutter, account-deletion, pii, user-preferences]

requires: []
provides:
  - "UserPreferencesDao.deleteAllPreferences() row wipe"
  - "AuthService.deleteAccount() clears local Home/Office coordinates on account deletion"
affects: [settings, auth]

tech-stack:
  added: []
  patterns:
    - "Full-row HARD delete (delete(table).go(), no where) for single-row settings tables, mirroring TripsDao.deleteAllTrips()"

key-files:
  created: []
  modified:
    - lib/database/daos/user_preferences_dao.dart
    - test/unit/database/user_preferences_dao_test.dart
    - lib/features/auth/services/auth_service.dart
    - lib/features/auth/providers/delete_account_controller.dart
    - test/unit/features/auth/auth_service_test.dart

key-decisions:
  - "Delete the entire user_preferences row rather than resetting individual columns to null (D-1) — a future PII column is covered automatically, and getOrDefault()/watch() already treat an absent row as UserPreferencesValue.defaults() (D-04)."
  - "Wipe placed after syncQueueDao.clearAll() and before signOut(), with no try/catch — a throw here leaves the user visibly still signed in rather than silently signed out with coordinates still on disk."
  - "Rewrote (not duplicated) the stale happy-path test whose name asserted 'never touches prefsDao' — the old assertion encoded the bug."

patterns-established:
  - "Regression tests for cross-DAO data-integrity bugs should use a real in-memory AppDatabase, not fake DAOs, and must be verified adversarially (temporarily remove the fix, confirm the test fails, restore, confirm it passes)."

requirements-completed: [DEL-ACCOUNT]

duration: ~35min
completed: 2026-08-02
---

# Quick Task 260802-fvp: Account Deletion Must Wipe Local User Preferences Summary

**Closed a cross-account PII leak: `AuthService.deleteAccount()` now wipes the local `user_preferences` row (Home/Office coordinates included), where it previously wiped only trips and the sync queue.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-08-02T06:07:15Z
- **Tasks:** 2 completed
- **Files modified:** 5

## Accomplishments
- Added `UserPreferencesDao.deleteAllPreferences()` — a bare `delete(userPreferences).go()` mirroring `TripsDao.deleteAllTrips()`, with a dartdoc explaining the account-deletion caller, the full-row-vs-column rationale (D-1), and the D-04 "absent row → defaults" safety net.
- Wired the wipe into `AuthService.deleteAccount()` between `syncQueueDao.clearAll()` and `signOut()`, preserving the server-first, no-try/catch discipline.
- Rewrote the stale happy-path ordering test (previously named "...never touches prefsDao", asserting the bug) to assert the prefs wipe runs in the correct position.
- Added a real-database regression test that seeds Home/Office coordinates into an in-memory `AppDatabase`, runs `deleteAccount()`, and asserts the coordinates are unreadable afterward — adversarially verified to fail without the fix (see below).
- Updated the `deleteAccount()` and `DeleteAccountSuccess` dartdocs to name local preferences (including Home/Office) as part of what gets wiped, replacing the now-false "does NOT touch user_preferences" line.

## Task Commits

Each task was committed atomically, using CLAUDE.md's bracket commit convention (not conventional-commit prefixes):

1. **Task 1: Add UserPreferencesDao.deleteAllPreferences() with its unit test** - `fc81104` (`[settings]`)
2. **Task 2: Wire the wipe into deleteAccount(), update dartdocs, and add the leak regression test** - `4882d14` (`[auth]`)

No separate plan-metadata commit was made for this quick task — this SUMMARY.md itself is the completion record (no STATE.md/ROADMAP.md exist for quick tasks).

## Files Created/Modified
- `lib/database/daos/user_preferences_dao.dart` - Added `deleteAllPreferences()` (full-row hard delete) with dartdoc naming its caller and rationale.
- `test/unit/database/user_preferences_dao_test.dart` - Three new tests: wipe returns 1 for a seeded row, `getOrDefault()` returns clean defaults post-wipe without throwing, wipe on an empty table returns 0 idempotently.
- `lib/features/auth/services/auth_service.dart` - `deleteAccount()` now calls `_prefsDao.deleteAllPreferences()` after `syncQueueDao.clearAll()` and before `signOut()`; dartdoc rewritten to describe the leak this closes and why the wipe sits before `signOut()`.
- `lib/features/auth/providers/delete_account_controller.dart` - `DeleteAccountSuccess` dartdoc extended to name local preferences (Home/Office coordinates) as wiped.
- `test/unit/features/auth/auth_service_test.dart` - Added `_OrderedFakeUserPreferencesDao`; rewrote the happy-path test name/assertion to include the prefs wipe step; added a comment to the server-throws test noting it now also proves the prefs wipe doesn't run on failure; added the real-database "CROSS-ACCOUNT LEAK REPRO" regression test with `drift`/`drift/native`/`AppDatabase` imports.

## Decisions Made
- All decisions were pre-resolved in the plan (D-2, D-3, schema-none) and followed exactly — see `key-decisions` above for the ones worth restating.
- Confirmed via live-code read (not re-derived) that `getOrDefault()` and `watch()` both already map an absent row to `UserPreferencesValue.defaults()` without throwing, which is why a full-row delete is safe rather than a schema change.

## Deviations from Plan

None — plan executed exactly as written. No Rule 1-4 auto-fixes were needed; the plan's pre-resolved decisions (D-2, D-3, naming mirror) left no ambiguity to resolve during implementation.

## Adversarial Verification (required by task constraints)

Per the plan's `<verification>` section, the fix line was temporarily commented out and the regression test re-run before final commit:

**With `await _prefsDao.deleteAllPreferences();` commented out:**
```
AuthService.deleteAccount() CROSS-ACCOUNT LEAK REPRO: against a real in-memory AppDatabase seeded with Home/Office coordinates, deleteAccount() leaves them unreadable [E]
  Expected: null
    Actual: <12.9716>
Some tests failed.
```
The test FAILED as expected — `homeLat` was still `12.9716` after `deleteAccount()` returned, proving the test is actually tied to the fix and not a false-positive fake-DAO test.

**With the line restored:**
```
AuthService.deleteAccount() CROSS-ACCOUNT LEAK REPRO: against a real in-memory AppDatabase seeded with Home/Office coordinates, deleteAccount() leaves them unreadable
All tests passed!
```
The test PASSED. The fix was then re-verified in place for the final commit.

## Intended Side Effect

Deleting the entire `user_preferences` row (rather than clearing only the coordinate columns) also resets `hasSeenOnboarding` to `false`. This is intentional, not a bug: `deleteAccount()` signs the device out unconditionally as its last step, so there is no signed-in state left for onboarding to skip past — the device returns to the onboarding/login flow on next launch, identical to a fresh install. This was documented in the plan (D-1 / "Side effect that is intended, not a bug") and is now also called out in the `deleteAllPreferences()` dartdoc.

## Verify-and-Leave Audit (confirmed, not edited)

- `lib/sync/delete_trips_controller.dart` — untouched (`git diff --stat` shows no entry for this file across either commit). The "Delete all data" flow continues to preserve Home/Office coordinates and account setup.
- `landing/src/pages/Privacy.jsx:180-181` ("Your Home and Office coordinates and your synced preferences are removed with them") — read-only verified, not edited. This claim is now accurate on-device as well as server-side, since the server side (`delete-account.ts`) was already correct before this change.
- `backend/` — no files touched; no schema or migration file appears in either commit's diff.

## Issues Encountered

None.

## Verification Results (actually observed, not assumed)

- `dart run build_runner build --delete-conflicting-outputs` — completed cleanly, 600 outputs written, no new `.g.dart` diff required (the new DAO method needed no codegen).
- `dart format .` — 302 files formatted, 0 changed (already compliant) after each task.
- `flutter analyze` — **292 issues found, 0 errors, 0 warnings** after both tasks — exactly matches the stated baseline (292 info-level, 0 errors/warnings). No regressions.
- `flutter test test/unit/database/user_preferences_dao_test.dart` — 13/13 passed (10 pre-existing + 3 new).
- `flutter test test/unit/features/auth/auth_service_test.dart` — 5 run / 6 skipped (pre-existing RED-state skips from Plan 09-03, unrelated to this change) — all 5 run tests passed, including the new regression test.
- `flutter test` (full suite) — **1004 passed, 0 failed** (10 skipped, all pre-existing RED-state skips unrelated to this change).
- Adversarial check on the regression test — FAILED with the fix line removed, PASSED with it restored (full output above).

## Next Phase Readiness

This closes T-FVP-01/02/03/04 from the plan's threat register. No follow-up work identified — the fix, its dartdocs, and its regression test are complete and verified. The "Delete all data" button copy issue noted in the plan as "separate acknowledged issue" remains out of scope here.

## Self-Check: PASSED

All 6 claimed files found on disk; both commit hashes (`fc81104`, `4882d14`) found in `git log`.

---
*Quick task: 260802-fvp*
*Completed: 2026-08-02*
