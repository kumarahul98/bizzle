---
phase: 18-trip-pause-breaks
plan: 01
subsystem: database
tags: [drift, sqlite, migration, schema-v3, trip-breaks, foreign-key]

# Dependency graph
requires:
  - phase: 07-polish-notifications
    provides: "v1→v2 migration pattern (weeklyNotificationEnabled addColumn) + drift_dev schema dump/generate workflow"
  - phase: 01-foundation
    provides: "AppDatabase, Trips/UserPreferences tables, DAO + manual Riverpod provider conventions, UserPreferencesValue value-type"
provides:
  - "trip_breaks normalized table (UUID PK, FK trip_id→trips.id, UTC start/end, nullable endTime for open breaks)"
  - "trips.total_paused_seconds denormalized aggregate column (default 0)"
  - "user_preferences.auto_pause_enabled opt-in column (default false)"
  - "v2→v3 additive-only Drift migration that preserves all existing rows"
  - "TripBreaksDao (batch insertBreaks, ordered breaksForTrip, watch) + tripBreaksDaoProvider"
  - "v3 schema snapshot + SchemaVerifier migration test proving data survival"
affects: [18-02-finalize-persist, 18-04-auto-pause, 19-trip-editing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Normalized 1:N child table with hard FK enforced by PRAGMA foreign_keys=ON (references(Trips, #id))"
    - "Denormalized aggregate column with safe default to avoid JOINs in list/stats reads"
    - "Additive-only migration branch (createTable + addColumn, no UPDATE/DROP) for zero-data-loss upgrades"

key-files:
  created:
    - lib/database/tables/trip_breaks_table.dart
    - lib/database/daos/trip_breaks_dao.dart
    - lib/database/daos/trip_breaks_dao.g.dart
    - drift_schemas/drift_schema_v3.json
    - test/generated_migrations/schema_v3.dart
    - test/unit/database/migration_v3_test.dart
    - test/unit/database/trip_breaks_dao_test.dart
  modified:
    - lib/database/database.dart
    - lib/database/database.g.dart
    - lib/database/tables/trips_table.dart
    - lib/database/tables/user_preferences_table.dart
    - lib/database/daos/user_preferences_dao.dart
    - lib/database/providers.dart
    - lib/features/settings/screens/settings_screen.dart
    - test/generated_migrations/schema.dart

key-decisions:
  - "D-01: breaks are a normalized table (not a JSON column) so Phase 19 can edit individual segments; FK enforced via existing PRAGMA foreign_keys=ON"
  - "D-02: total_paused_seconds denormalized onto trips (default 0) so list/stats render without a JOIN"
  - "D-03: duration_seconds redefined as ACTIVE duration (wall-clock − paused); storage unchanged, historical rows unaffected since total_paused_seconds defaults 0"
  - "D-05: persistence is finalize-time batch insert — no incremental per-segment writes, so an abandoned recording leaves no orphan break rows"
  - "D-10: auto_pause_enabled added in the SAME v3 migration, default false (opt-in)"

patterns-established:
  - "Pattern: child-table FK via references(Trips, #id) relying on the global beforeOpen PRAGMA — no per-migration FK toggling"
  - "Pattern: when a Drift @DataClassName row or value-type gains a required field, thread it through every construction site (UserPreferencesValue _copyPrefs preserves it on partial upserts; TripRow test fixtures) in the same atomic commit to keep the build green"

requirements-completed: [TRACK-09, TRACK-10]

# Metrics
duration: 13min
completed: 2026-06-06
---

# Phase 18 Plan 01: Pause/Breaks Schema Foundation Summary

**Normalized trip_breaks table with FK-enforced trip linkage, a denormalized total_paused_seconds aggregate, an opt-in auto_pause_enabled preference, and a zero-data-loss v2→v3 Drift migration proven by a SchemaVerifier test.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-06-06T04:27:02Z
- **Completed:** 2026-06-06T04:40:10Z
- **Tasks:** 2
- **Files modified:** 21 (8 modified, 7 created source/test, plus regenerated `.g.dart`/schema snapshots)

## Accomplishments
- Created the normalized `trip_breaks` table (UUID PK, `trip_id` FK → `trips.id`, UTC `start_time`/`end_time`, `end_time` nullable only while a break is open) per D-01.
- Added `trips.total_paused_seconds` (default 0) and `user_preferences.auto_pause_enabled` (default false) and an additive-only `from < 3` migration branch that creates the table and both columns without touching any existing row.
- Added `TripBreaksDao` (batch `insertBreaks`, ordered `breaksForTrip`, reactive `watch`) and `tripBreaksDaoProvider`, mirroring the existing DAO/provider conventions.
- Regenerated `database.g.dart`, `trip_breaks_dao.g.dart`, and the v3 schema snapshot (`drift_schema_v3.json`, `schema_v3.dart`, `versions = [1, 2, 3]`) via the proven `drift_dev schema dump`/`generate` workflow.
- Authored two automated test suites: a `SchemaVerifier` v2→v3 migration test proving an existing trip row survives with `total_paused_seconds = 0` and `auto_pause_enabled = false`, and a `TripBreaksDao` test proving ordered round-trip, open-break null round-trip, and FK rejection of an orphan break.

## Task Commits

1. **Task 1 + Task 2: schema foundation, DAO, migration, and both test suites** - `39d9797` (`[infra]`)

Both plan tasks plus all required value-type call-site updates landed in a single atomic commit because the schema change makes `TripRow` and `UserPreferencesValue` gain required fields — splitting would leave an intermediate non-compiling tree. All per-task verifications (build_runner, schema dump/generate, analyze, targeted tests) passed before the commit.

## Files Created/Modified
- `lib/database/tables/trip_breaks_table.dart` - TripBreaks table: UUID PK, FK tripId→trips.id, UTC start/end (end nullable while open).
- `lib/database/daos/trip_breaks_dao.dart` (+ `.g.dart`) - Batch insert + ordered/reactive reads for break segments.
- `lib/database/tables/trips_table.dart` - Added `total_paused_seconds` (default 0); documented duration_seconds = ACTIVE duration.
- `lib/database/tables/user_preferences_table.dart` - Added `auto_pause_enabled` (default false).
- `lib/database/daos/user_preferences_dao.dart` - Threaded `autoPauseEnabled` through all five `UserPreferencesValue` sites (ctor, `.defaults()`, `getOrDefault`, `watch`, `upsert`).
- `lib/database/database.dart` (+ `.g.dart`) - schemaVersion 3, registered TripBreaks/TripBreaksDao, added `from < 3` migration branch.
- `lib/database/providers.dart` - Added `tripBreaksDaoProvider`.
- `lib/features/settings/screens/settings_screen.dart` - `_copyPrefs` now preserves `autoPauseEnabled` on partial upserts (T-07-04-01 zero-column mitigation).
- `drift_schemas/drift_schema_v3.json`, `test/generated_migrations/schema_v3.dart`, `test/generated_migrations/schema.dart` - v3 snapshot + helper regenerated to versions [1, 2, 3].
- `test/unit/database/migration_v3_test.dart`, `test/unit/database/trip_breaks_dao_test.dart` - New automated test suites.
- `test/unit/database/user_preferences_dao_test.dart`, `test/unit/features/auth/backfill_test.dart`, `test/unit/features/settings/theme_mode_test.dart`, `test/unit/sync/api_client_test.dart`, `test/unit/sync/trip_serializer_test.dart`, `test/widget/features/settings/settings_screen_test.dart` - Threaded the new required `autoPauseEnabled`/`totalPausedSeconds` fields through existing fixtures.

## Decisions Made
Followed the plan's D-01/D-02/D-03/D-05/D-10 decisions exactly. The only execution-level judgment was committing the schema change plus its value-type call-site fallout as one atomic commit (rather than artificially splitting into a non-compiling intermediate state), consistent with CLAUDE.md "one concern per commit" — the concern here is the v3 schema, and the call-site edits are inseparable from it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Migration/DAO test DateTime + import-collision fixes**
- **Found during:** Task 2 (authoring the test suites)
- **Issue:** (a) Drift's default datetime storage persists a Unix timestamp and reads it back as a local-time DateTime, so direct `expect(actual, utcLiteral)` comparisons failed on the timezone tag; (b) `isNotNull`/`isNull` collide between `package:drift` and `package:matcher` when both are imported.
- **Fix:** Compared instants with `isAtSameMomentAs` (the stored instant is correct); imported drift with `hide isNotNull, isNull`. Also marked literal `Variable`s const to satisfy `prefer_const_constructors`.
- **Files modified:** test/unit/database/trip_breaks_dao_test.dart, test/unit/database/migration_v3_test.dart
- **Verification:** Both suites green; analyze clean on the new files.
- **Committed in:** 39d9797

**2. [Rule 3 - Blocking] Threaded new required fields through every value-type / row call site**
- **Found during:** Task 1 (post-build_runner) and the full-suite run
- **Issue:** The plan warned `UserPreferencesValue` gains a required field; additionally the Drift-generated `TripRow` gained a required `totalPausedSeconds`. Both broke compilation at construction sites across settings, auth, theme, and sync tests, and in the settings `_copyPrefs` helper.
- **Fix:** Added `autoPauseEnabled` to all five `UserPreferencesValue` sites in the DAO and every test fixture, preserved it through `_copyPrefs` on partial upserts (so a settings toggle never zeroes the new column), and added `totalPausedSeconds: 0` to every `TripRow` test fixture. Verified `TripSerializer.toJson` is an explicit key-set map that does NOT emit the new column, so no behaviour change leaked into sync (consistent with the plan: serialization changes land in Plan 02).
- **Files modified:** lib/features/settings/screens/settings_screen.dart and the six test files listed above.
- **Verification:** Full `flutter test` green (412 passed, 10 pre-existing skips, 0 failures).
- **Committed in:** 39d9797

---

**Total deviations:** 2 auto-fixed (1 test-correctness bug, 1 blocking compile fallout)
**Impact on plan:** Both were necessary to keep the build/test suite green and were directly caused by the schema change. No scope creep — `TripSerializer` and all runtime behaviour are unchanged, exactly as the plan requires (behaviour changes land in Plan 02).

## Issues Encountered
- `SchemaVerifier` migration test required inserting a v2-shaped row through the generated `DatabaseAtV2` raw `RawValuesInsertable` API (snake_case columns) and sharing the same underlying connection (`schema.newConnection()`) across the v2 insert and the v3 migrate so data persists across the upgrade. Resolved by using `verifier.schemaAt(2)` and reading back through the live `AppDatabase` after `migrateAndValidate(db, 3)`.

## Verification Results
- `dart run build_runner build --delete-conflicting-outputs`: success (339 outputs).
- `drift_dev schema dump` + `schema generate`: success; `schema.dart` regenerated with `versions = [1, 2, 3]` and a `DatabaseAtV3`.
- `flutter analyze` on all substantively-edited files (lib/database, settings_screen, new + modified DB/sync/settings tests): No issues found. (Six pre-existing lint infos remain on untouched lines of `backfill_test.dart` and `theme_mode_test.dart` — out of scope per the scope boundary; not introduced by this plan.)
- `flutter test test/unit/database/`: 28 passed.
- Full `flutter test`: 412 passed, 10 skipped (pre-existing), 0 failed.

## Threat Model Compliance
- T-18-01 (migration tampering): mitigated — additive-only migration; `migration_v3_test` asserts an existing trip row survives with `total_paused_seconds = 0`.
- T-18-02 (FK integrity): mitigated — `references(Trips, #id)` + PRAGMA foreign_keys=ON; `trip_breaks_dao_test` asserts an orphan-break insert throws `SqliteException`.
- T-18-03 (info disclosure): accepted — break rows store only UTC timestamps, no PII.

## Known Stubs
None — every column has a real default, the DAO methods are fully implemented, and all assertions are automated. No placeholders or TODOs.

## Next Phase Readiness
- Schema v3 is in place: Plan 02 (finalize/persist) can write `total_paused_seconds` and batch-insert break segments via `TripBreaksDao.insertBreaks`, and redefine saved duration as active duration.
- Plan 04 (auto-pause) can read/write `user_preferences.auto_pause_enabled` through the already-threaded `UserPreferencesValue`.
- No blockers.

## Self-Check: PASSED

All created files exist on disk and commit `39d9797` is present in the git log.

---
*Phase: 18-trip-pause-breaks*
*Completed: 2026-06-06*
