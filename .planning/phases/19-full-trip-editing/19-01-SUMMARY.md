---
phase: 19-full-trip-editing
plan: 01
subsystem: database
tags: [drift, sqlite, migration, riverpod, trip-editing, recompute, transaction]

# Dependency graph
requires:
  - phase: 18-trip-pause-breaks
    provides: "trip_breaks table + total_paused_seconds + active-duration semantics (schema v3)"
provides:
  - "Schema v4: trips.is_edited bool column (default false) + additive v3→v4 migration"
  - "Pure TripEditRecompute service: active-duration recompute, proportional moving/stuck rescale (0/0 rule), break window/order/overlap validation, clamp/drop"
  - "TripBreaksDao.deleteBreaksForTrip for wholesale break replacement"
  - "editTrip atomic full-edit write path (trip row + breaks + sync enqueue in one transaction), backward-compatible with the direction-only path"
  - "EditBreakSegment value type + sealed EditValidationResult + Phase 19 constants"
affects: [19-02-edit-ui, stats, sync]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure recompute/validation service (no Drift/Flutter imports) feeds an I/O-only notifier — math is unit-tested in isolation"
    - "Guard onUpgrade branches with both from<N and to>=N so stepwise migrations stop at their target version"
    - "Single editTrip write path extended with optional params instead of a parallel method (D-12)"

key-files:
  created:
    - lib/features/trips/services/trip_edit_recompute.dart
    - drift_schemas/drift_schema_v4.json
    - test/generated_migrations/schema_v4.dart
    - test/unit/database/migration_v4_test.dart
    - test/unit/features/trips/trip_edit_recompute_test.dart
    - test/unit/features/trips/trip_management_edit_full_test.dart
  modified:
    - lib/database/tables/trips_table.dart
    - lib/database/database.dart
    - lib/database/daos/trip_breaks_dao.dart
    - lib/database/daos/trips_dao.dart
    - lib/features/trips/providers/trip_management_providers.dart
    - lib/config/constants.dart

key-decisions:
  - "is_edited is local-only: TripSerializer.toJson is an explicit key map and does NOT emit it, so the backend zod schema is unchanged (T-19-05 accept)"
  - "Guarded every onUpgrade branch with to>=N to fix a latent stepwise-migration overshoot exposed by adding v4"
  - "migration_v3 test now validates the full v2→v3→v4 chain because the live AppDatabase always upgrades to the current terminal version"

patterns-established:
  - "Pure service + I/O-only notifier split: TripEditRecompute computes, editTrip persists"
  - "Wholesale break replace (delete-all → insert with fresh UUIDs) inside the edit transaction"

requirements-completed: [TRACK-11]

# Metrics
duration: ~40min
completed: 2026-06-06
---

# Phase 19 Plan 01: Full Trip Editing — Data + Logic Foundation Summary

**Schema v4 (`trips.is_edited`) + a pure `TripEditRecompute` service (active-duration recompute, proportional moving/stuck rescale with the 0/0 rule, break validation + clamp/drop) + an atomic `editTrip` full-edit write path that replaces breaks and re-enqueues sync in one transaction.**

## Performance

- **Duration:** ~40 min
- **Completed:** 2026-06-06T06:47Z
- **Tasks:** 3
- **Files modified:** 6 created, 6 modified (12 total, excluding generated)

## Accomplishments
- Additive v3→v4 migration adds `trips.is_edited` (default false); existing rows survive reading false, proven by `migration_v4_test`.
- `TripEditRecompute` encodes every D-01..D-10 rule expressible as `fn(input) → output`, covered by 29 table-driven cases (incl. the `moving+stuck==active` invariant and the 0/0 manual-entry exception).
- `editTrip` now persists a full edit (recomputed duration/total_paused/moving/stuck + `is_edited=true` + wholesale break replace + one sync enqueue) in ONE atomic transaction, while the direction-only path is byte-for-byte unchanged and still green.
- Full suite: 488 passing / 10 skipped / 0 failing (baseline 453 → +35 net-new tests, no regression).

## Task Commits

1. **Task 1: Schema v4 + migration test + deleteBreaksForTrip** — `2891f10` (infra)
2. **Task 2: Pure TripEditRecompute service + table-driven tests** — `165f2b5` (trips/test)
3. **Task 3: Atomic full-edit editTrip write path** — `22e8a1f` (trips/test)
4. **Deviation fix: TripRow call sites for is_edited + lint tidy** — `30a86f8` (trips/test)

## Files Created/Modified
- `lib/database/tables/trips_table.dart` — added `isEdited` bool column (default false).
- `lib/database/database.dart` — schemaVersion 3→4; from<4 addColumn branch; guarded all branches with `to>=N`.
- `lib/database/daos/trip_breaks_dao.dart` — `deleteBreaksForTrip(tripId)`.
- `lib/database/daos/trips_dao.dart` — `TripSummary.isEdited` (defaulted false) + projection wiring.
- `lib/features/trips/services/trip_edit_recompute.dart` — pure recompute/validation/clamp service + `EditBreakSegment` + sealed `EditValidationResult`.
- `lib/features/trips/providers/trip_management_providers.dart` — `editTrip` extended with optional full-edit params; atomic transaction.
- `lib/config/constants.dart` — Phase 19 constants (validation messages, snackbar, estimated hint, UI copy).
- `drift_schemas/drift_schema_v4.json`, `test/generated_migrations/schema*.dart` — v4 snapshot + regenerated migration helpers (versions [1,2,3,4]).
- Tests: `migration_v4_test.dart`, `trip_edit_recompute_test.dart`, `trip_management_edit_full_test.dart`; extended `trip_breaks_dao_test.dart`; updated `migration_v3_test.dart`, `trip_serializer_test.dart`, `api_client_test.dart`.

## Decisions Made
- **is_edited stays local-only.** `TripSerializer.toJson` is an explicit key map; `is_edited` is not added, so the deployed backend zod schema needs no change (matches threat T-19-05 disposition `accept`).
- **`to>=N` migration guards.** The pre-existing `from<N`-only branches overshot once v4 existed (a verifier migrating v2→v3 also ran the v4 step). Added `&& to>=N` to every branch so stepwise migrations stop at their target — this is the standard drift stepwise pattern.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] onUpgrade branches overshot their target version**
- **Found during:** Task 1 (migration)
- **Issue:** The existing `if (from < N)` branches had no `to` guard. Adding the v4 branch made the `SchemaVerifier`'s v2→v3 migration also apply the v4 `addColumn`, so `migration_v3_test` failed (`unexpected entry: is_edited`).
- **Fix:** Guarded every branch with `&& to >= N`. A migration targeting v3 now stops at v3.
- **Files modified:** lib/database/database.dart
- **Verification:** migration_v3_test + migration_v4_test both green.
- **Committed in:** `2891f10`

**2. [Rule 1 - Bug] migration_v3_test asserted v3 as a terminal version**
- **Found during:** Task 1
- **Issue:** After the fix above, the live `AppDatabase` (schemaVersion 4) always upgrades fully to v4, but the test migrated/validated to v3 and then called `findById`, which reads `is_edited` — a column absent at the v3-shaped DB → null-check crash.
- **Fix:** Updated the test to `migrateAndValidate(db, 4)` (a real v2 install upgrades straight through to v4) while still asserting the v3-added columns (`total_paused_seconds`, `auto_pause_enabled`) survive.
- **Files modified:** test/unit/database/migration_v3_test.dart
- **Verification:** migration_v3_test green.
- **Committed in:** `2891f10`

**3. [Rule 3 - Blocking] TripRow constructor now requires isEdited**
- **Found during:** Full-suite run after Task 3
- **Issue:** Drift generates a required Dart param for the non-nullable `is_edited` column (the SQL default does not make the data-class param optional). Two sync tests construct `TripRow(...)` directly and failed to compile (`api_client_test.dart`, `trip_serializer_test.dart`).
- **Fix:** Passed `isEdited: false` at each `TripRow(...)` call site. Confirmed `TripSerializer.toJson` does not emit the field, so backend contract is unaffected.
- **Files modified:** test/unit/sync/api_client_test.dart, test/unit/sync/trip_serializer_test.dart
- **Verification:** Full `flutter test` → 488 passing, 0 failing.
- **Committed in:** `30a86f8`

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs, 1 Rule 3 blocking). All directly caused by the schema change and required for a green suite. No scope creep.

## Issues Encountered
- Pre-existing analyzer `info` items in `lib/config/constants.dart` (lines 215/302/708/713) and several widget test files are out of scope and unrelated to Phase 19. Logged to `deferred-items.md`; not fixed. My Phase 19 files are analyzer-clean.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The full-edit data/logic foundation is ready for Plan 02's edit sheet: the sheet computes via `TripEditRecompute` (active + rescale + validate + clamp) and calls `editTrip(..., breaks:, ...stats, markEdited: true)`. The `kEdit*` UI-copy constants and the `is_edited`-driven "~ estimated" hint are in place for Plan 02 to consume.
- No blockers.

---
*Phase: 19-full-trip-editing*
*Completed: 2026-06-06*

## Self-Check: PASSED

All 6 created files exist on disk and all 4 task commits (`2891f10`, `165f2b5`, `22e8a1f`, `30a86f8`) are present in git history.
