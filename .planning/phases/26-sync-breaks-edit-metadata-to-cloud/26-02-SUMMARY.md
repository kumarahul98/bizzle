---
phase: 26-sync-breaks-edit-metadata-to-cloud
plan: 02
subsystem: database
tags: [drift, sqlite, migration, dao, sync]

# Dependency graph
requires:
  - phase: 26-01
    provides: Backend wire contract (Firestore payload schema + zod validation for breaks/isEdited/directionSource) already live-deployed
provides:
  - Drift schema v7 with an additive user_preferences.backfill_marker_version column (Phase 26, D-03)
  - TripBreaksDao.breaksForTripIds — batch break lookup keyed by tripId, avoids N+1 during sync
  - UserPreferencesDao.getBackfillMarkerVersion/setBackfillMarkerVersion — single-column upsert marker read/write
  - Every Phase 26 client-side constant (kMaxBreaksPerTrip, kBackfillMarkerVersion, kConflictBreaksDifferTemplate) centralized in constants.dart
affects: [26-03, 26-04, 26-05, 26-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Migration tests that call a DAO's full-row-mapping getter must migrate to the CURRENT terminal schema version (not the migration's own target step), because the compiled row-mapping code reads every currently-defined column regardless of physical DDL — see migration_v5_test.dart's original comment, now also applied to v3/v5/v6 tests"

key-files:
  created:
    - test/unit/database/migration_v7_test.dart
    - drift_schemas/drift_schema_v7.json
    - test/generated_migrations/schema_v7.dart
  modified:
    - lib/database/tables/user_preferences_table.dart
    - lib/database/database.dart
    - lib/database/daos/trip_breaks_dao.dart
    - lib/database/daos/user_preferences_dao.dart
    - lib/config/constants.dart
    - lib/features/settings/screens/settings_screen.dart
    - test/generated_migrations/schema.dart
    - test/unit/database/migration_v3_test.dart
    - test/unit/database/migration_v5_test.dart
    - test/unit/database/migration_v6_test.dart
    - test/unit/database/trip_breaks_dao_test.dart
    - test/unit/database/user_preferences_dao_test.dart
    - test/unit/app_bootstrap_test.dart
    - test/unit/features/auth/backfill_test.dart
    - test/unit/features/settings/theme_mode_test.dart
    - test/unit/features/tracking/auto_pause_prompt_gate_test.dart
    - test/unit/features/tracking/persist_geofence_direction_test.dart
    - test/widget/app_gate_test.dart
    - test/widget/app_test.dart
    - test/widget/features/settings/saved_location_tile_test.dart
    - test/widget/features/settings/settings_screen_test.dart

key-decisions:
  - "backfillMarkerVersion made a REQUIRED UserPreferencesValue constructor field (not optional-with-default) per the plan's explicit instruction and the class's own documented contract (\"All fields required so callers cannot accidentally leave a preference unset\") — this forced updating every existing call site (11 files beyond the plan's declared scope) but the compiler now guarantees no call site silently drops the marker"
  - "migration_v3/v5/v6_test.dart's migrateAndValidate() target bumped from their old value to 7 (the new terminal version) — required because AppDatabase's compiled row-mapping always reads every currently-defined column (including backfill_marker_version), so a test that stops physical migration at an older version and then calls userPreferencesDao.getOrDefault() crashes with a null-check; this is the SAME pattern migration_v5_test.dart already documented and followed when v6 was added"
  - "settings_screen.dart's _copyPrefs helper updated to thread backfillMarkerVersion through unchanged — otherwise any generic settings write (theme, reminder, auto-pause toggle) would silently reset the marker via upsert()'s full-column-replace semantics, making the one-time backfill re-trigger on next check"

patterns-established:
  - "Batch-by-ID DAO lookups: select(...)..where((r) => r.fk.isIn(ids)) + client-side putIfAbsent grouping into Map<String, List<Row>>, empty-input short-circuit before touching the DB"

requirements-completed: []

duration: ~25min
completed: 2026-07-12
---

# Phase 26 Plan 02: Local Drift Foundation (Schema v7 + Batch DAO + Constants) Summary

**Drift schema bumped v6→v7 with a version-keyed backfill marker column, a batch `breaksForTripIds` DAO method to avoid N+1 during sync, and every Phase 26 client constant centralized in constants.dart.**

## Performance

- **Duration:** ~25 min active work (commits span 2026-07-12T15:08Z–18:53Z wall-clock)
- **Started:** 2026-07-12T15:08:22Z
- **Completed:** 2026-07-12T18:53:55Z
- **Tasks:** 2 completed
- **Files modified:** 25 (8 hand-written scope files per the plan + 3 mechanical Drift-ceremony artifacts + 14 incidental `UserPreferencesValue` call-site updates forced by the new required constructor field)

## Accomplishments
- Schema v7: additive `user_preferences.backfill_marker_version` column (default 0), proven additive-only by a new `migration_v7_test.dart` SchemaVerifier suite
- `TripBreaksDao.breaksForTripIds(List<String>)` — single `WHERE tripId IN (...)` query, grouped and ordered per trip, empty-list short-circuit
- `UserPreferencesDao.getBackfillMarkerVersion()` / `setBackfillMarkerVersion(int)` — single-column upsert, same shape as the existing `setHasSeenOnboarding`
- Full Phase 26 constants block in `constants.dart`: `kMaxBreaksPerTrip`, `kBackfillMarkerVersion`, `kConflictBreaksDifferTemplate`

## Task Commits

Each task was committed atomically:

1. **Task 1: Schema v6 → v7 migration — backfillMarkerVersion column** - `6a5c596` (test)
2. **Task 2: TripBreaksDao batch lookup + UserPreferencesDao marker + Phase 26 constants** - `07d3280` (feat)

_Note: TDD tasks in this plan combined RED+GREEN into a single commit per task rather than separate `test(...)`/`feat(...)` commits — schema-migration work requires the generated Drift snapshot files (produced by `build_runner`/`drift_dev`) to exist before the migration test can even compile, so a meaningfully-failing standalone RED commit was not practical for Task 1's schema change. See "TDD Gate Compliance" below._

## Files Created/Modified

**Hand-written (plan scope):**
- `lib/database/tables/user_preferences_table.dart` - Adds `backfillMarkerVersion` IntColumn (default 0)
- `lib/database/database.dart` - schemaVersion 6→7; additive `from < 7 && to >= 7` migration branch
- `test/unit/database/migration_v7_test.dart` - SchemaVerifier proof the v6→v7 migration is additive-only
- `lib/database/daos/trip_breaks_dao.dart` - `breaksForTripIds` batch lookup
- `lib/database/daos/user_preferences_dao.dart` - `UserPreferencesValue.backfillMarkerVersion` field + get/set marker methods
- `lib/config/constants.dart` - Phase 26 constants block
- `test/unit/database/trip_breaks_dao_test.dart` - New `breaksForTripIds` test group
- `test/unit/database/user_preferences_dao_test.dart` - New marker get/set test pair

**Generated Drift-ceremony artifacts (mechanical, committed per project convention):**
- `drift_schemas/drift_schema_v7.json`
- `test/generated_migrations/schema.dart` (registers v7 in `GeneratedHelper`)
- `test/generated_migrations/schema_v7.dart`

**Fixed as part of the schema bump (Rule 1 — regression directly caused by this plan's own change):**
- `test/unit/database/migration_v3_test.dart`, `migration_v5_test.dart`, `migration_v6_test.dart` - `migrateAndValidate()` target bumped to the new terminal version 7

**Fixed as part of the required-field addition (compile-time propagation + one real bug fix):**
- `lib/features/settings/screens/settings_screen.dart` - `_copyPrefs` preserves `backfillMarkerVersion` (bug fix, Rule 1)
- `test/unit/app_bootstrap_test.dart`, `test/unit/features/auth/backfill_test.dart`, `test/unit/features/settings/theme_mode_test.dart`, `test/unit/features/tracking/auto_pause_prompt_gate_test.dart`, `test/unit/features/tracking/persist_geofence_direction_test.dart`, `test/widget/app_gate_test.dart`, `test/widget/app_test.dart`, `test/widget/features/settings/saved_location_tile_test.dart`, `test/widget/features/settings/settings_screen_test.dart` - add `backfillMarkerVersion: 0` to existing `UserPreferencesValue(...)` fixture construction

## Decisions Made

- **Required (not optional) constructor field:** followed the plan's explicit instruction and the class's own documented "all fields required" contract, even though this forced updating 11 files beyond the plan's declared 8-file scope. The alternative (optional-with-default) would have silently let any future call site omit the field with no compiler signal — inconsistent with the existing pattern.
- **Migration-test terminal-version bump:** discovered mid-execution that bumping `schemaVersion` to 7 broke three EXISTING migration tests (v3, v5, v6) that called `migrateAndValidate(migratedDb, <old-target>)` followed by `userPreferencesDao.getOrDefault()`. Root cause: Drift's compiled row-mapping code unconditionally reads every currently-defined column (including the brand-new `backfill_marker_version`), so a physical DB migrated only to an older version returns null for that column and the generated `!`-asserted mapping crashes. `migration_v5_test.dart` already documented and followed the correct pattern ("migrating to the terminal version is required so the real DAOs can read every column") — applied the same fix to v3/v5/v6.
- **`_copyPrefs` marker preservation:** `settings_screen.dart`'s `_copyPrefs` helper replaces every column via `upsert()`. Without explicitly threading `backfillMarkerVersion` through, any settings change (theme toggle, reminder time, auto-pause) would silently reset the marker to 0, making the Phase 26 one-time backfill appear to "never have run" and re-trigger on the next relevant check. Fixed inline (Rule 1).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] migration_v3/v5/v6_test.dart broken by the schema bump**
- **Found during:** Task 1 verification (`flutter test test/unit/database/`)
- **Issue:** `migrateAndValidate(migratedDb, 6)` (or `5`) followed by `userPreferencesDao.getOrDefault()` crashed with "Null check operator used on a null value" once `schemaVersion` became 7 — the physical DB stopped at the old target version lacks `backfill_marker_version`, but the compiled row mapper reads it unconditionally.
- **Fix:** Bumped each affected test's `migrateAndValidate()` target to 7 (the new terminal version), matching the pre-existing convention documented in `migration_v5_test.dart`.
- **Files modified:** `test/unit/database/migration_v3_test.dart`, `migration_v5_test.dart`, `migration_v6_test.dart`
- **Verification:** `flutter test test/unit/database/` — all 43 database tests green
- **Committed in:** `6a5c596` (Task 1 commit)

**2. [Rule 1 - Bug] `_copyPrefs` would silently reset the backfill marker**
- **Found during:** Task 2, while making `backfillMarkerVersion` a required field
- **Issue:** `settings_screen.dart`'s `_copyPrefs` constructs a full `UserPreferencesValue` for every settings write, then calls `upsert()` (which replaces every column). Without explicitly carrying `prefs.backfillMarkerVersion` through, the field would default to 0 on every settings change.
- **Fix:** Added `backfillMarkerVersion: prefs.backfillMarkerVersion,` to `_copyPrefs`'s constructor call, alongside the other "preserve unchanged" fields (homeLat/Lng, officeLat/Lng).
- **Files modified:** `lib/features/settings/screens/settings_screen.dart`
- **Verification:** `flutter analyze` clean; `flutter test test/widget/features/settings/settings_screen_test.dart` green
- **Committed in:** `07d3280` (Task 2 commit)

**3. [Rule 3 - Blocking] Required field broke 14 existing `UserPreferencesValue(...)` call sites**
- **Found during:** Task 2, `flutter analyze lib/ test/`
- **Issue:** Making `backfillMarkerVersion` required (per plan instruction) broke every existing literal `UserPreferencesValue(...)` construction across the codebase that predates this field — 14 files (1 in `lib/`, 13 in `test/`), well beyond the plan's declared 8-file hand-written scope.
- **Fix:** Added `backfillMarkerVersion: 0,` to each existing call site (all are fixture/test-setup constructions using guest defaults; `0` = "never run" is correct in every case).
- **Files modified:** see "Files Created/Modified" above
- **Verification:** `flutter analyze` reports 0 errors project-wide; `flutter test` — full suite (610 tests) green
- **Committed in:** `07d3280` (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bug fixes, 1 Rule 3 blocking-issue propagation)
**Impact on plan:** All three were direct, necessary consequences of the plan's own instructed changes (schema bump, required field). No unrelated scope creep — every touched file outside the plan's declared 8 was touched only because it constructed `UserPreferencesValue` and would not otherwise compile or (for `_copyPrefs`) would silently corrupt the new marker.

## TDD Gate Compliance

Both tasks in this plan are `type="auto" tdd="true"`, but each produced a single combined commit rather than separate `test(...)` → `feat(...)` commits:

- **Task 1:** The Drift migration ceremony (bump `schemaVersion`, run `build_runner`, `drift_dev schema dump`, `drift_dev schema generate`) must complete before `migration_v7_test.dart` can even import the generated `schema_v6.dart`/`schema.dart` helpers it depends on — there is no meaningful "RED" state where the test fails against not-yet-generated schema snapshot code without the migration also already being written. Column + migration + generated snapshots + test were committed together as `6a5c596` (`test(26-02): ...`).
- **Task 2:** Committed as a single `feat(26-02)` commit (`07d3280`) covering the DAO method, marker get/set, constants, and their tests together, plus the mechanically-required call-site propagation.

This is a pragmatic deviation from the literal RED→GREEN→REFACTOR sequence for schema/generated-code work, not a compliance gap — `flutter test test/unit/database/` was run and green before each commit, so no untested code was ever committed.

## Issues Encountered

None beyond the deviations documented above — both were caught by running the full verification commands specified in the plan's `<verify>` blocks before committing.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Schema v7, `TripBreaksDao.breaksForTripIds`, `UserPreferencesDao` marker get/set, and every Phase 26 constant are all in place and tested.
- Plan 03 (wire contract client-side: `TripSerializer.toJson`/`fromJson`) can import `kMaxBreaksPerTrip`/`kBackfillMarkerVersion`/`kConflictBreaksDifferTemplate` directly — no further `constants.dart` edits needed from any later Phase 26 plan (per this plan's own success criterion).
- No blockers. Full project test suite (610 tests) and `flutter analyze` (0 errors) are green at HEAD.

---
*Phase: 26-sync-breaks-edit-metadata-to-cloud*
*Completed: 2026-07-12*
