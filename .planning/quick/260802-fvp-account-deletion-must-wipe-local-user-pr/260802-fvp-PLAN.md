---
phase: quick-260802-fvp
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/database/daos/user_preferences_dao.dart
  - test/unit/database/user_preferences_dao_test.dart
  - lib/features/auth/services/auth_service.dart
  - lib/features/auth/providers/delete_account_controller.dart
  - test/unit/features/auth/auth_service_test.dart
autonomous: true
requirements: [DEL-ACCOUNT]

must_haves:
  truths:
    - "After AuthService.deleteAccount() completes, reading preferences returns clean defaults with null homeLat/homeLng/officeLat/officeLng"
    - "A read immediately after the wipe returns defaults instead of throwing (D-04 create-on-demand contract holds)"
    - "When the server delete throws, NOTHING local is wiped — trips, sync queue, and preferences all survive intact"
    - "The 'Delete all data' flow still preserves Home/Office coordinates and account setup"
  artifacts:
    - path: "lib/database/daos/user_preferences_dao.dart"
      provides: "deleteAllPreferences() row wipe mirroring TripsDao.deleteAllTrips()"
      contains: "deleteAllPreferences"
    - path: "lib/features/auth/services/auth_service.dart"
      provides: "prefs wipe wired into deleteAccount() before signOut()"
      contains: "_prefsDao.deleteAllPreferences"
    - path: "test/unit/features/auth/auth_service_test.dart"
      provides: "call-order assertion including prefs wipe + real-database regression test"
      contains: "deleteAllPreferences"
  key_links:
    - from: "lib/features/auth/services/auth_service.dart"
      to: "UserPreferencesDao.deleteAllPreferences"
      via: "await inside deleteAccount(), after syncQueue clear, before signOut()"
      pattern: "_prefsDao\\.deleteAllPreferences\\(\\)"
---

<objective>
`AuthService.deleteAccount()` wipes local trips and the sync queue but never
clears the `user_preferences` row. That row holds the user's saved
`homeLat`/`homeLng`/`officeLat`/`officeLng` — the most sensitive data the app
stores. Delete your account, sign in with a different Google account on the same
device, and the previous user's Home and Office coordinates are still there:
shown in Settings, driving geofence direction labelling for the new user's trips,
and pushed up to the NEW account's cloud record by `PreferencesSyncService`.

Purpose: close a cross-account leak of precise home/work location on the exact
flow that exists to satisfy Google Play's account-deletion requirement.
Output: a `UserPreferencesDao` wipe method, wired into `deleteAccount()` in the
correct position, with a regression test that fails without the fix.

The server side is already correct — `delete-account.ts` erases trips, the
`users/{uid}` doc, and the Auth user. This is a client-only gap.
</objective>

<execution_context>
@/Users/coolman/Documents/Projects/bizzle/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@CLAUDE.md
@lib/database/daos/user_preferences_dao.dart
@lib/features/auth/services/auth_service.dart
@lib/features/auth/providers/delete_account_controller.dart
@test/unit/features/auth/auth_service_test.dart
@test/unit/database/user_preferences_dao_test.dart

## Pre-resolved decisions — do NOT re-investigate

**D-2 resolved: DELETE the row, do not reset it to defaults.**
Verified in live code, both null-row paths already return defaults safely:
- `getOrDefault()` (`user_preferences_dao.dart:174-180`) calls
  `getSingleOrNull()` and returns `const UserPreferencesValue.defaults()` when
  the row is null. It does not throw.
- `watch()` (`user_preferences_dao.dart:215-218`) uses `watchSingleOrNull()`
  — chosen deliberately over `watchSingle` for exactly this reason — and maps
  null to defaults.
Deleting the row is therefore the cleanest reset AND the one consistent with the
table's D-04 "create on demand, no seed row" contract. A fresh install has no row
either; after this wipe the device is in the identical state.

**Schema: no change needed.** No new column, no migration, no schema version
bump. If you conclude otherwise, STOP and report instead of migrating.

**Naming (D-2 mirror):** `TripsDao.deleteAllTrips()` is
`Future<int> deleteAllTrips() => delete(trips).go();` — a bare `delete(...).go()`
with no `where`, returning the row count. Mirror it exactly:
`Future<int> deleteAllPreferences() => delete(userPreferences).go();`

**D-3 resolved: insert the wipe AFTER `_syncQueueDao.clearAll()` and BEFORE
`signOut()`.** Two properties this preserves:
1. `_apiClient.deleteAccount()` stays FIRST. The method has no try/catch —
   sequential awaits mean the first throw aborts everything after it. A server
   failure must abort before any local destruction. Keep that discipline; add no
   try/catch.
2. Prefs-before-signOut, not after. If the prefs wipe throws while placed after
   `signOut()`, the user is silently signed out with the coordinates still on
   disk — the exact leak. Placed before, a throw leaves the user still signed in,
   which is a visible failure rather than a silent one.

Resulting sequence:
`_apiClient.deleteAccount()` → `_tripsDao.deleteAllTrips()` →
`_syncQueueDao.clearAll()` → `_prefsDao.deleteAllPreferences()` → `signOut()`

**Side effect that is intended, not a bug:** the wipe also resets
`hasSeenOnboarding` to false, so the device returns to onboarding. That is D-1's
stated end state.

**The existing test asserts the OLD behaviour and must be rewritten.**
`test/unit/features/auth/auth_service_test.dart:315-317` — the happy-path test is
literally named `'... syncQueueDao.clearAll -> signOut IN THAT ORDER, never
touches prefsDao'`. That name and its `expect(order.calls, [...])` list both
encode the bug. Rewrite them; do not add a parallel test alongside.

**Verify-and-leave (do NOT change these):**
- `lib/sync/delete_trips_controller.dart` — `DeleteTripsController.deleteAllTrips()`
  must NOT wipe preferences. That flow deliberately keeps the user's account and
  setup ("Your account itself is kept, so you can carry on with a clean slate",
  `landing/src/pages/Privacy.jsx:174`). Wiping prefs there would destroy Home/Office
  and bounce the still-signed-in user back to onboarding. Leave the file untouched.
- `landing/src/pages/Privacy.jsx:180-181` already claims "Your Home and Office
  coordinates and your synced preferences are removed with them." This change
  makes that claim true on-device as well as server-side. Read-only verification;
  do not edit.
- The backend (`delete-account.ts`, `delete-all-trips.ts`) — correct already.
- The "Delete all data" button label/copy — separate acknowledged issue.

## Interfaces the executor needs

```dart
// lib/database/daos/trips_dao.dart:266 — the pattern to mirror
Future<int> deleteAllTrips() => delete(trips).go();

// lib/features/auth/services/auth_service.dart:214-219 — current body
Future<void> deleteAccount() async {
  await _apiClient.deleteAccount();
  await _tripsDao.deleteAllTrips();
  await _syncQueueDao.clearAll();
  await signOut();
}

// AppDatabase generated accessors (@DriftDatabase daos list, database.dart:31)
db.tripsDao          // TripsDao
db.syncQueueDao      // SyncQueueDao
db.userPreferencesDao // UserPreferencesDao

// Existing test fixtures in auth_service_test.dart, reuse them:
class _CallOrder { final List<String> calls = <String>[]; }        // :375
class _OrderedFakeApiClient implements ApiClient { ... }           // :379
class _OrderedFakeTripsDao implements TripsDao { ... }             // :395
class _OrderedFakeSyncQueueDao implements SyncQueueDao { ... }     // :410
class _OrderedFakeSecureStorage / _OrderedFakeFirebaseAuth / _OrderedFakeGoogleSignIn
class _FakeUserPreferencesDao implements UserPreferencesDao { ... } // :115 (records backfill only)

// In-memory DB setup used by test/unit/database/user_preferences_dao_test.dart:12-19
db = AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);
```

Note: `test/unit/database/user_preferences_dao_test.dart:1` imports
`package:drift/drift.dart' hide isNotNull, isNull;` — keep that hide-list intact
if you add imports there.

## Project skills

`.agents/skills/flutter-architecting-apps` triggers on structuring a new project
or refactoring for scalability. This is a three-file bugfix inside an established
layered structure — the skill does not apply. `dynamodb-table-designer` is
unrelated (this project is on Firebase).
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add UserPreferencesDao.deleteAllPreferences() with its unit test</name>
  <files>lib/database/daos/user_preferences_dao.dart, test/unit/database/user_preferences_dao_test.dart</files>
  <behavior>
    - Seeding a row via `upsert` with real Home/Office coordinates and non-default
      settings, then calling `deleteAllPreferences()`, returns 1.
    - After the wipe, `getOrDefault()` returns clean defaults WITHOUT throwing:
      homeLat / homeLng / officeLat / officeLng all null, userId == kDefaultUserId,
      darkMode == kDarkModeSystem, hasSeenOnboarding == false.
    - Calling `deleteAllPreferences()` on an already-empty table returns 0 and does
      not throw (idempotent).
  </behavior>
  <action>
Add `deleteAllPreferences()` to `UserPreferencesDao`, mirroring
`TripsDao.deleteAllTrips()` in both signature and implementation:

```dart
Future<int> deleteAllPreferences() => delete(userPreferences).go();
```

Place it near the other write methods (after `upsert`, before
`setHasSeenOnboarding`, or at the end of the class — pick whichever keeps the
file's existing read-then-write ordering coherent).

Write a dartdoc in the style of the neighbouring methods that states:
  * It exists for the account-deletion flow ONLY (`AuthService.deleteAccount()`),
    and names that caller.
  * It deletes the ENTIRE single row at `id = 1` — every column, not just the
    PII-adjacent coordinates (D-1). Clearing only "sensitive" columns would
    recreate this same gap the next time a column is added.
  * Deleting is safe rather than destructive-of-contract because `getOrDefault()`
    and `watch()` both handle the absent row by returning
    `UserPreferencesValue.defaults()` — the D-04 "create on demand, no seed row"
    contract. The next read recreates defaults; the next write recreates the row.
  * The reset includes `hasSeenOnboarding`, so the device returns to onboarding.
    That is intended: account deletion signs the device out anyway.
  * It must NOT be called from the "Delete all data" flow
    (`DeleteTripsController`), which deliberately keeps the user's account and
    setup.
  * Returns the number of rows removed (0 or 1).

Then add tests to the existing `group('UserPreferencesDao', ...)` in
`test/unit/database/user_preferences_dao_test.dart` covering the three behaviours
above. Use the file's existing `upsert(UserPreferencesValue(...))` seeding style —
but unlike every existing test in that file, pass REAL non-null coordinates
(e.g. homeLat: 12.9716, homeLng: 77.5946, officeLat: 12.9352, officeLng: 77.6245)
plus a non-default darkMode/userId, so the wipe has something meaningful to erase.

Do not add a `where` clause to the delete. Do not touch the table definition,
`database.dart`, or any migration.
  </action>
  <verify>
    <automated>cd /Users/coolman/bizzle &amp;&amp; dart run build_runner build --delete-conflicting-outputs &amp;&amp; flutter test test/unit/database/user_preferences_dao_test.dart</automated>
  </verify>
  <done>`deleteAllPreferences()` exists with a dartdoc covering the points above; the three new tests pass; no schema/migration file changed.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Wire the wipe into deleteAccount(), update dartdocs, and add the leak regression test</name>
  <files>lib/features/auth/services/auth_service.dart, lib/features/auth/providers/delete_account_controller.dart, test/unit/features/auth/auth_service_test.dart</files>
  <behavior>
    - `deleteAccount()` calls, in order: apiClient.deleteAccount →
      tripsDao.deleteAllTrips → syncQueueDao.clearAll →
      prefsDao.deleteAllPreferences → firebaseAuth.signOut → googleSignIn.signOut
      → secureStorage.delete.
    - When apiClient.deleteAccount throws, `order.calls` is exactly
      `['apiClient.deleteAccount']` — the prefs wipe is NOT called, so
      coordinates survive a failed server delete.
    - REGRESSION (must fail without the Task 1 + Task 2 change): against a REAL
      in-memory AppDatabase seeded with Home and Office coordinates, after
      `deleteAccount()` returns, `db.userPreferencesDao.getOrDefault()` reports
      homeLat/homeLng/officeLat/officeLng all null.
  </behavior>
  <action>
**1. `lib/features/auth/services/auth_service.dart`** — insert the wipe:

```dart
Future<void> deleteAccount() async {
  await _apiClient.deleteAccount();
  await _tripsDao.deleteAllTrips();
  await _syncQueueDao.clearAll();
  await _prefsDao.deleteAllPreferences();
  await signOut();
}
```

No try/catch. No reordering of the existing three calls. `_prefsDao` is already a
constructor-injected field (`auth_service.dart:68`) — no constructor change needed.

Rewrite the trailing sentence of the `deleteAccount()` dartdoc. It currently reads
"Does NOT touch `user_preferences` — device-local (theme/reminders), matching
[signOut]'s existing scope", which is now false and was the reasoning error behind
the bug. Replace it with a statement that:
  * Local preferences are wiped too, INCLUDING the saved Home/Office coordinates.
  * Why: without it, signing in with a different Google account on the same device
    inherits the previous user's precise home and work locations — they show in
    Settings, drive geofence direction labelling, and get pushed up to the new
    account by `PreferencesSyncService`. A cross-account PII leak on the exact
    flow that exists to satisfy Play's account-deletion requirement.
  * The whole row is cleared, not just the coordinates (D-1).
  * Why this differs from [signOut], which deliberately keeps local data:
    sign-out is reversible, account deletion is not.
  * The wipe sits before [signOut] on purpose — if it throws, the user stays
    signed in (a visible failure) rather than being silently signed out with the
    coordinates still on disk.

**2. `lib/features/auth/providers/delete_account_controller.dart`** — the
`DeleteAccountSuccess` dartdoc (line 25-26) reads "server account + data gone,
local trips + sync queue wiped, and the device signed out". Extend that
enumeration to include local preferences, calling out the Home/Office coordinates
explicitly. Keep it to the existing one-to-two-line style. Change nothing else in
this file.

**3. `test/unit/features/auth/auth_service_test.dart`** — three edits inside
Group 5:

  a. Add an ordered prefs fake next to the other Group 5 fakes (after
     `_OrderedFakeSyncQueueDao`, ~line 423), same shape as its siblings:

     ```dart
     class _OrderedFakeUserPreferencesDao implements UserPreferencesDao {
       _OrderedFakeUserPreferencesDao(this.order);
       final _CallOrder order;
       @override
       Future<int> deleteAllPreferences() async {
         order.calls.add('prefsDao.deleteAllPreferences');
         return 1;
       }
       @override
       dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
     }
     ```

  b. In BOTH existing Group 5 tests, swap `prefsDao: _FakeUserPreferencesDao()`
     for `prefsDao: _OrderedFakeUserPreferencesDao(order)`. Rewrite the happy-path
     test's NAME — it currently ends "never touches prefsDao", which asserts the
     bug — and add `'prefsDao.deleteAllPreferences'` to its expected `order.calls`
     list between `'syncQueueDao.clearAll'` and `'firebaseAuth.signOut'`. The
     server-throws test's `expect(order.calls, ['apiClient.deleteAccount'])` needs
     no change: with the ordered prefs fake wired in it now additionally proves the
     prefs wipe does not run on server failure. Say so in a comment.
     Leave `_FakeUserPreferencesDao` itself in place — Groups 2-4 still use it.

  c. Add the regression test to Group 5, using a REAL `AppDatabase` rather than
     fake DAOs — fakes cannot catch this class of bug, and the point of this test
     is that it would have FAILED before the change. Shape:

     - Add imports `package:drift/drift.dart` (with the same `hide isNotNull, isNull`
       treatment if the matchers collide), `package:drift/native.dart`, and
       `package:traevy/database/database.dart`.
     - Build `AppDatabase(DatabaseConnection(NativeDatabase.memory(),
       closeStreamsSynchronously: true))`; close it in a `tearDown` or an
       `addTearDown(db.close)`.
     - Seed real coordinates via `db.userPreferencesDao.setHomeLocation(...)` and
       `.setOfficeLocation(...)`.
     - Sanity-assert the seed took (homeLat is non-null) BEFORE deleting, so a
       broken seed cannot produce a false pass.
     - Construct `AuthService` with `tripsDao: db.tripsDao`,
       `prefsDao: db.userPreferencesDao`, `syncQueueDao: db.syncQueueDao`, and the
       existing `_OrderedFake*` secureStorage/firebaseAuth/googleSignIn/apiClient
       (a throwaway `_CallOrder` is fine).
     - `await service.deleteAccount();`
     - Assert `getOrDefault()` returns homeLat, homeLng, officeLat, officeLng all
       null and does not throw.
     - Name the test so its intent survives: it is the cross-account leak repro.

**Do NOT touch** `lib/sync/delete_trips_controller.dart`,
`landing/src/pages/Privacy.jsx`, the backend, or any schema/migration file.
  </action>
  <verify>
    <automated>cd /Users/coolman/bizzle &amp;&amp; dart format . &amp;&amp; flutter analyze &amp;&amp; flutter test</automated>
  </verify>
  <done>Full suite green; `flutter analyze` reports 0 errors and 0 warnings; the happy-path order assertion includes `prefsDao.deleteAllPreferences`; the real-database regression test passes and is demonstrably tied to the fix.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user A → user B on one device | Local Drift state survives an account boundary that the user believes erased it |
| device → Firestore (`PreferencesSyncService`) | Leaked local coordinates are re-uploaded, binding user A's home/work address to user B's account |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-FVP-01 | Information Disclosure | `user_preferences.home_lat/lng`, `office_lat/lng` after `AuthService.deleteAccount()` | mitigate | Wipe the entire row via `deleteAllPreferences()` inside `deleteAccount()` before `signOut()` (Task 2); pinned by the real-database regression test |
| T-FVP-02 | Information Disclosure | `PreferencesSyncService` push after a same-device account switch | mitigate | Transitively closed by T-FVP-01 — with the row gone, there is no stale coordinate left to push to the new account |
| T-FVP-03 | Tampering | Partial wipe leaving the device in a half-deleted state | mitigate | Sequential awaits with no try/catch preserved; server-first ordering unchanged, so a server failure aborts before any local destruction (asserted by the existing server-throws test) |
| T-FVP-04 | Information Disclosure | Future PII column added to `user_preferences` | mitigate | Full-row delete rather than column-by-column clearing (D-1) — a new column is covered on the day it is added, with no code change |
| T-FVP-05 | Information Disclosure | Coordinates written to logs during the wipe | accept | `delete(userPreferences).go()` reads no values and logs nothing; T-21-03 "never log this coordinate" is unaffected |
</threat_model>

<verification>
Run from `/Users/coolman/bizzle` (the Bash working directory PERSISTS between
calls — after any `cd`, use absolute paths or `cd /Users/coolman/bizzle` back):

```bash
cd /Users/coolman/bizzle
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze
flutter test
```

Baseline for `flutter analyze`: 292 info-level issues, 0 errors, 0 warnings. Any
new ERROR or WARNING is a regression. Info count may shift slightly with the added
lines — that is fine.

Regression proof (do this, it is the point of the change): before committing,
temporarily comment out the `await _prefsDao.deleteAllPreferences();` line and
confirm the new real-database test FAILS. Restore the line and confirm it passes.
A regression test that passes both ways is worthless.

Verify-and-leave audit — confirm each, change none:
- `lib/sync/delete_trips_controller.dart` is untouched by `git diff --stat`.
- `landing/src/pages/Privacy.jsx:180-181` ("Your Home and Office coordinates and
  your synced preferences are removed with them") is now accurate on-device as
  well as server-side. Report; do not edit.
- No file under `backend/` and no schema/migration file appears in the diff.
</verification>

<success_criteria>
- `UserPreferencesDao.deleteAllPreferences()` exists, mirrors
  `TripsDao.deleteAllTrips()`, and carries a dartdoc naming its account-deletion
  caller and the D-1 full-row rationale.
- `AuthService.deleteAccount()` calls it after `syncQueueDao.clearAll()` and before
  `signOut()`, with server-first ordering and no-try/catch discipline preserved.
- The `deleteAccount()` dartdoc and `DeleteAccountSuccess`'s dartdoc both name
  local preferences including Home/Office coordinates.
- The happy-path ordering test asserts the prefs wipe; the old "never touches
  prefsDao" assertion is gone, not duplicated around.
- A real-database regression test proves the coordinates are unreadable after
  `deleteAccount()`, and was observed to fail with the fix removed.
- `dart format .` clean, `flutter analyze` at 0 errors / 0 warnings,
  `flutter test` fully green.
- `lib/sync/delete_trips_controller.dart`, `landing/src/pages/Privacy.jsx`,
  `backend/`, and all schema/migration files are untouched.
- Commits use the CLAUDE.md bracket convention (`[auth]`, optionally `[settings]`),
  NOT conventional-commit prefixes. One concern per commit.
</success_criteria>

<output>
After completion, create
`.planning/quick/260802-fvp-account-deletion-must-wipe-local-user-pr/260802-fvp-SUMMARY.md`
</output>
