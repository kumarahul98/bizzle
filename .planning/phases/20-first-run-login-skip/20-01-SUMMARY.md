---
phase: 20-first-run-login-skip
plan: 01
subsystem: auth
tags: [drift, riverpod, firebase-auth, sqlite-migration, schema-v5, flutter]

# Dependency graph
requires:
  - phase: 09-authentication
    provides: AuthService.signIn() backfill transaction, authStateProvider sealed AuthState gate, OnboardingScreen visuals
  - phase: 11-sync (sync engine)
    provides: SyncQueueDao pending queue + engine gating on AuthSignedIn
provides:
  - "Drift schema v5: user_preferences.has_seen_onboarding bool (default false) with a returning-user migration guard"
  - "UserPreferencesDao.setHasSeenOnboarding(bool) single-column upsert that creates the row on a fresh install"
  - "SyncQueueDao.reconcilePendingUserId(uid): idempotent rewrite of stale local_user in pending DELETE payloads"
  - "AuthService.signIn() reconciles the guest sync-queue backlog inside its backfill transaction"
  - "No-flash root gate in app.dart composing authStateProvider + userPreferenceProvider"
  - "LoginScreen (first-run wall) with Google sign-in + a visible Skip, both writing the persisted flag"
  - "Shared OnboardingIntroBlock reused by OnboardingScreen and LoginScreen"
affects: [20-02-guest-indicator, future auth/sync work, any schema bump (now starts from v5)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Schema migration guard: additive addColumn + targeted UPDATE of the single id=1 row to make a first-run flag install-only (D-02)"
    - "No-flash gate: nest AsyncValue.when inside the exhaustive sealed AuthState switch; loading->Splash, error->degrade, never trap the user"
    - "Single-column DAO setter via insertOnConflictUpdate(id + one field) that creates-or-updates the single-row table"
    - "Shared visual block widget extracted to avoid screen duplication while keeping per-screen actions distinct"

key-files:
  created:
    - lib/features/auth/screens/login_screen.dart
    - lib/features/onboarding/widgets/onboarding_intro_block.dart
    - drift_schemas/drift_schema_v5.json
    - test/generated_migrations/schema_v5.dart
    - test/unit/database/migration_v5_test.dart
    - test/unit/features/auth/sign_in_backlog_reconcile_test.dart
    - test/widget/app_gate_test.dart
  modified:
    - lib/database/tables/user_preferences_table.dart
    - lib/database/daos/user_preferences_dao.dart
    - lib/database/daos/sync_queue_dao.dart
    - lib/database/database.dart
    - lib/features/auth/services/auth_service.dart
    - lib/features/auth/providers/auth_providers.dart
    - lib/app.dart
    - lib/config/constants.dart
    - lib/features/settings/screens/settings_screen.dart
    - lib/features/onboarding/screens/onboarding_screen.dart

key-decisions:
  - "D-02 returning-user guard: the v4->v5 migration flips the existing id=1 prefs row to true so the login wall is first-INSTALL only; fresh installs (no row) read false via getOrDefault()"
  - "D-08: rewrite the stale local_user in pending DELETE payloads in place (cheap, idempotent) rather than delete+re-enqueue; create/update payloads are already userId-free and untouched"
  - "D-03: AuthGuest prefs .error degrades to MainShell (never LoginScreen) so a prefs read failure can't lock a user out; prefs-loading shows Splash to avoid a flash"
  - "Skip and Google both write the flag via the DAO setter and let the gate route — no manual navigation, single source of truth"

patterns-established:
  - "First-run flag persisted in Drift, gated at the app root, install-only via a migration UPDATE guard"
  - "Reconcile guest->signed-in queue state atomically inside the existing signIn() transaction"

requirements-completed: [AUTH-04]

# Metrics
duration: ~95min
completed: 2026-06-06
---

# Phase 20 Plan 01: First-Run Login Gate, has_seen_onboarding Flag, and Sync-Backlog Reconcile Summary

**Drift schema v5 adds a persisted `has_seen_onboarding` flag (with a returning-user migration guard), a no-flash root gate composing auth state + the flag, a LoginScreen-with-Skip, and an idempotent guest->sign-in sync-queue reconcile inside `signIn()`.**

## Performance

- **Duration:** ~95 min
- **Tasks:** 3 (2 TDD)
- **Files modified:** 30 (26 hand-authored + 4 generated)
- **Test suite:** 495 -> 510 passing (15 net new), 10 pre-existing skips, 0 failures

## Accomplishments
- v4->v5 additive migration: `user_preferences.has_seen_onboarding` (default false) plus a targeted `UPDATE ... WHERE id = 1` returning-user guard so a pre-update install is never walled (D-01/D-02), proven by a SchemaVerifier v4->v5 test.
- `setHasSeenOnboarding(bool)` single-column upsert that creates the row on a fresh install (D-04/D-05); flag threaded through all 5 `UserPreferencesValue` sites.
- `SyncQueueDao.reconcilePendingUserId(uid)` rewrites stale `local_user` in pending DELETE payloads to the real uid, idempotent/exactly-once; called inside `signIn()`'s backfill transaction after both backfills (D-08), proven by a dedicated exactly-once test.
- No-flash root gate in `app.dart` composing `authStateProvider` + `userPreferenceProvider` with an exhaustive AuthState switch (no default); LoginScreen with Google sign-in + a clearly visible Skip, both persisting the flag and letting the gate route — covered by a 5-case gate widget test (incl. prefs-loading -> Splash).

## Task Commits

1. **Task 1: Schema v5 + flag + setter + sync-backlog reconcile** - `4d54607` ([infra]; schema, DAOs, signIn(), generated code, v5 snapshot, TDD tests)
2. **Task 2 + 3: No-flash gate + LoginScreen-with-Skip + gate/migration tests** - `733a5c7` ([auth]; app.dart gate, LoginScreen, OnboardingIntroBlock, app_gate_test, harness adaptations)

_TDD: Task 1 and Task 3 tests landed alongside their implementation; production code was authored first only because the Drift `.g.dart` generation and v5 schema dump are prerequisites for the migration test to compile and run RED->GREEN._

## Files Created/Modified
- `lib/database/database.dart` - schemaVersion 5; `from < 5` addColumn + returning-user UPDATE guard
- `lib/database/tables/user_preferences_table.dart` - `hasSeenOnboarding` BoolColumn (default false)
- `lib/database/daos/user_preferences_dao.dart` - flag threaded through all 5 value sites; `setHasSeenOnboarding` setter
- `lib/database/daos/sync_queue_dao.dart` - `reconcilePendingUserId(uid)` (idempotent DELETE-payload rewrite)
- `lib/features/auth/services/auth_service.dart` - inject SyncQueueDao; reconcile inside the backfill transaction
- `lib/features/auth/providers/auth_providers.dart` - wire `syncQueueDao` into authServiceProvider
- `lib/app.dart` - no-flash composed root gate
- `lib/features/auth/screens/login_screen.dart` - first-run wall (Google + Skip, both set the flag)
- `lib/features/onboarding/widgets/onboarding_intro_block.dart` - shared logo/headline/ticks block
- `lib/features/onboarding/screens/onboarding_screen.dart` - refactored to reuse the shared block
- `lib/config/constants.dart` - `kCopyLoginSkip`
- `lib/features/settings/screens/settings_screen.dart` - preserve the flag in `_copyPrefs`
- `drift_schemas/drift_schema_v5.json`, `test/generated_migrations/*` - regenerated (versions [1..5])
- Tests: `migration_v5_test`, `sign_in_backlog_reconcile_test`, `app_gate_test`, extended `user_preferences_dao_test`, plus harness adaptations to `app_test`, `app_bootstrap_test`, `theme_mode_test`, `migration_v3_test`

## Decisions Made
Followed the plan's pinned decisions D-01..D-09 exactly. The reconcile rewrites the DELETE payload in place (per the plan's investigation that create/update payloads are already userId-free).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Threaded the new required field through downstream `UserPreferencesValue` / `AuthService` construction sites**
- **Found during:** Task 1
- **Issue:** Adding the required `hasSeenOnboarding` field and the `syncQueueDao` constructor param broke every construction site (settings `_copyPrefs`, and several unit/widget tests) — they would not compile.
- **Fix:** Threaded `hasSeenOnboarding` through `settings_screen.dart _copyPrefs` (preserving the flag so a settings write never resets it) and through the affected test constructors; added a `_FakeSyncQueueDao` to `auth_service_test`.
- **Committed in:** `4d54607`

**2. [Rule 1 - Bug] Returning-user/MainShell widget tests now routed to LoginScreen after the gate change**
- **Found during:** Task 2/3 (full-suite run)
- **Issue:** `app_test`, `app_bootstrap_test`, and `theme_mode_test` emitted prefs with `hasSeenOnboarding=false`, so the new gate routed them to the LoginScreen (causing a viewport overflow / wrong-screen assertions). Their intent is to assert MainShell/Dashboard/themeMode, not the first-run wall.
- **Fix:** Updated those harnesses to emit a returning-user value (`hasSeenOnboarding=true`); the first-run gate itself is covered by the new `app_gate_test`.
- **Committed in:** `733a5c7`

**3. [Rule 1 - Bug] `migration_v3_test` crashed reading the new column**
- **Found during:** Task 2/3 (full-suite run)
- **Issue:** `migration_v3_test` migrated only to v4 then called the real `getOrDefault()`, which now reads `has_seen_onboarding` — a column absent at v4 — throwing a null-check error.
- **Fix:** Migrate through to the terminal version (v5) so all columns exist; the v2->v3 assertions are unchanged.
- **Committed in:** `733a5c7`

**4. [Rule 3 - Blocking] Gate-test harness pending-timer + viewport**
- **Found during:** Task 3
- **Issue:** `app_gate_test` MainShell cases left a pending Drift stream-close timer at teardown, and the LoginScreen case overflowed the default test viewport.
- **Fix:** Wrapped the in-memory DB in `DatabaseConnection(closeStreamsSynchronously: true)` and set a generous portrait viewport (mirrors `onboarding_screen_test`).
- **Committed in:** `733a5c7`

---

**Total deviations:** 4 auto-fixed (3 bugs, 1 blocking). All were compile/correctness consequences of the required-field and gate changes; no scope creep.

## Issues Encountered
None beyond the deviations above. `avoid_positional_boolean_parameters` was raised on the plan-mandated `setHasSeenOnboarding(bool value)` signature; suppressed with a targeted `// ignore:` and rationale since every call site is the unambiguous `setHasSeenOnboarding(true)`.

## User Setup Required
None - no external service configuration required.

## Known Stubs
None — every surface is wired (the flag is read by the live gate and written by both login actions; the reconcile runs inside the real `signIn()` transaction).

## Threat Flags
None — no new network endpoint, auth path, or trust-boundary schema beyond the threat model already covers (T-20-01..04). The migration is additive + one targeted UPDATE; `has_seen_onboarding` is a non-PII boolean.

## Next Phase Readiness
- Plan 02 (wave 1) can build the guest "not connected" indicator on top of this gate and flag.
- No blockers. Any future schema change now bumps from v5.

## Self-Check: PASSED

- Commits `4d54607`, `733a5c7` exist in history.
- All created artifacts (LoginScreen, OnboardingIntroBlock, v5 schema snapshot + generated schema_v5.dart, migration_v5_test, sign_in_backlog_reconcile_test, app_gate_test) present on disk.
- Full suite green: 510 passed / 10 skipped / 0 failed; `flutter analyze` reports no new issues in changed files.

---
*Phase: 20-first-run-login-skip*
*Completed: 2026-06-06*
