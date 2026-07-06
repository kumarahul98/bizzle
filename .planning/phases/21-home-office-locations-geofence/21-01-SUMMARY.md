---
phase: 21-home-office-locations-geofence
plan: 01
subsystem: database
tags: [drift, migration, geofence, geolocator, riverpod, direction-labeling]

# Dependency graph
requires:
  - phase: 17-tracking-ui-quick-direction
    provides: directionOverride at finalize + resolvedDirection live preview
  - phase: 19-full-trip-editing
    provides: editTrip single manual write path (quick toggle + edit sheet)
  - phase: 20-first-run-login
    provides: schema v5 + UserPreferencesValue threading convention
provides:
  - "Drift schema v6: nullable Home/Office coords on user_preferences + trips.direction_source (default time)"
  - "Pure GeofenceDirectionResolver implementing the D-04..D-09 proximity policy"
  - "Finalize precedence override ?? geofence ?? time, with direction_source recording the winning path"
  - "Manual write path (editTrip) stamps direction_source=manual so a user pick is backfill-proof"
affects: [21-02-picker-ui, 21-03-geofence-backfill]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure const policy service (GeofenceDirectionResolver) mirroring DirectionLabelService — no Drift/Riverpod/plugin, only static Geolocator.distanceBetween math"
    - "direction_source provenance column: durable manual/geofence/time record gating the Plan 03 backfill"
    - "Additive-only Drift migration (5× addColumn, no UPDATE/DROP) with a SchemaVerifier data-survival test"

key-files:
  created:
    - lib/features/trips/services/geofence_direction_resolver.dart
    - drift_schemas/drift_schema_v6.json
    - test/generated_migrations/schema_v6.dart
    - test/unit/database/migration_v6_test.dart
    - test/unit/features/trips/geofence_direction_resolver_test.dart
    - test/unit/features/tracking/persist_geofence_direction_test.dart
  modified:
    - lib/config/constants.dart
    - lib/database/database.dart
    - lib/database/tables/trips_table.dart
    - lib/database/tables/user_preferences_table.dart
    - lib/database/daos/user_preferences_dao.dart
    - lib/features/tracking/services/tracking_service_controller.dart
    - lib/features/tracking/providers/tracking_providers.dart
    - lib/features/trips/providers/trip_management_providers.dart
    - lib/features/settings/screens/settings_screen.dart

key-decisions:
  - "kGeofenceRadiusMeters = 250 m; strict < comparison so a point exactly at the radius is OUTSIDE (D-05/D-06)"
  - "Geofence resolution is finalize-only (needs the END coord); the live header/notification preview stays override ?? time (D-10)"
  - "Polyline decode in finalize is guarded — a malformed polyline never fails the persist; it falls back to time"
  - "Sync is unchanged: direction_source is local-only and the serializer does not carry it (T-21-02)"

patterns-established:
  - "Pure exhaustively-tested policy function reused identically at finalize (D-10) and the future backfill (D-11)"
  - "Provenance column gating a destructive re-label: backfill touches only rows where source != manual"

requirements-completed: [LOC-01, LOC-02]

# Metrics
duration: ~45min
completed: 2026-06-06
---

# Phase 21 Plan 01: Geofence Labeling Foundation Summary

**Drift schema v6 (Home/Office coords + trips.direction_source) plus a pure GeofenceDirectionResolver and finalize precedence `override ?? geofence ?? time`, with manual edits stamped backfill-proof.**

## Performance

- **Duration:** ~45 min
- **Tasks:** 3
- **Files modified:** 9 modified, 6 created
- **Test suite:** 536 passing / 10 skipped (up from 514; +22 new)

## Accomplishments
- Additive v5→v6 migration: four nullable Home/Office coord doubles on `user_preferences`, `trips.direction_source` text (default `time`), `schemaVersion` bumped to 6 with a guarded `from<6` branch. v6 snapshot dumped and generated migration schemas regenerated to `[1,2,3,4,5,6]`.
- Pure `GeofenceDirectionResolver` implementing the full D-04..D-09 policy (END primary, strict 250 m radius, outside-both→null, overlap START tie-break, only-one-set never guesses, additive null) with no Drift/Riverpod/plugin dependency.
- Finalize decodes polyline endpoints, runs the resolver against saved coords, applies `override ?? geofence ?? time`, and writes `direction_source` (manual/geofence/time).
- `editTrip` (the single manual write path for both the Phase 17 quick toggle and the Phase 19 edit sheet) stamps `direction_source=manual`.

## Task Commits

1. **Task 1: v6 schema + migration test** — `2e209ed` (`[infra]`)
2. **Task 2: pure GeofenceDirectionResolver + tests** — `35fa81f` (`[trips]`)
3. **Task 3: finalize wiring + manual tagging + persist test** — `2a51fdf` (`[tracking]`)

_Note: TDD tasks combined RED+GREEN into single atomic task commits (each task's test and implementation landed together with the test authored first and verified failing before implementation)._

## Files Created/Modified
- `lib/features/trips/services/geofence_direction_resolver.dart` — pure const resolver, D-04..D-09 policy.
- `lib/database/database.dart` — schemaVersion 6 + additive from<6 onUpgrade branch.
- `lib/database/tables/trips_table.dart` — `directionSource` text column, default `time`.
- `lib/database/tables/user_preferences_table.dart` — four nullable coord doubles.
- `lib/database/daos/user_preferences_dao.dart` — coords threaded through all five UserPreferencesValue sites.
- `lib/config/constants.dart` — `kGeofenceRadiusMeters` + the three `direction_source` literals.
- `lib/features/tracking/services/tracking_service_controller.dart` — decode endpoints, resolve, write `direction_source`.
- `lib/features/tracking/providers/tracking_providers.dart` — `resolvedDirection` dartdoc: geofence is finalize-only.
- `lib/features/trips/providers/trip_management_providers.dart` — `editTrip` stamps `direction_source=manual`.
- `lib/features/settings/screens/settings_screen.dart` — `_copyPrefs` preserves the new coords (compile requirement).
- `drift_schemas/drift_schema_v6.json`, `test/generated_migrations/schema_v6.dart`, `test/generated_migrations/schema.dart` — v6 snapshot + regenerated migration schemas.
- `test/unit/database/migration_v6_test.dart` — v5→v6 data-survival + defaults test.
- `test/unit/features/trips/geofence_direction_resolver_test.dart` — exhaustive D-04..D-08 + boundary tests.
- `test/unit/features/tracking/persist_geofence_direction_test.dart` — finalize geofence/time/manual/empty-polyline test.

## Decisions Made
- Geofence resolution runs at finalize only (END coord exists then); the live preview path deliberately stays `override ?? time` with no Drift coord read on the hot path.
- The finalize polyline decode is guarded against malformed input so a corrupt polyline can never lose a completed commute (it falls back to time).
- `direction_source` is local-only provenance; the sync serializer does not carry it (verified by the existing key-set test), so v0.3 sync is unchanged (T-21-02).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Thread the four coords through `_copyPrefs` in settings_screen.dart**
- **Found during:** Task 1
- **Issue:** The plan's interface note said to leave `_copyPrefs` alone (Plan 02 owns the picker wiring), but making the four coord fields `required` on the all-required `UserPreferencesValue` value type breaks `_copyPrefs` compilation — it must supply every field.
- **Fix:** Added `homeLat/homeLng/officeLat/officeLng: prefs.<field>` as pure preservation (mirroring how `hasSeenOnboarding` is carried). No picker wiring added; Plan 02 still owns the setters/UI.
- **Files modified:** lib/features/settings/screens/settings_screen.dart
- **Verification:** `flutter analyze` clean; full suite green.
- **Committed in:** `2e209ed`

**2. [Rule 1 - Bug] Migrate v3/v4/v5 migration tests to the terminal version**
- **Found during:** Task 1
- **Issue:** The v3/v4/v5 migration tests read the surviving row via `tripsDao.findById` / `userPreferencesDao.getOrDefault`. The current generated `TripRow`/`UserPreferencesRow` mapping now expects the v6 `direction_source`/coord columns, so reading after migrating only to v3/v4/v5 threw a null-check / missing-column error.
- **Fix:** Updated those three tests to `migrateAndValidate(db, 6)` (the new terminal version) — the targeted v2→v3 / v3→v4 / v4→v5 step still runs as part of the stepwise upgrade, and the DAO reads now see every column. Matches the existing convention already documented in the v3 test.
- **Files modified:** test/unit/database/migration_v3_test.dart, migration_v4_test.dart, migration_v5_test.dart
- **Verification:** All four migration tests green.
- **Committed in:** `2e209ed`

**3. [Rule 2 - Missing Critical] Guard the finalize polyline decode**
- **Found during:** Task 3
- **Issue:** `decodePolyline` throws `RangeError` on a malformed/garbage polyline string. Decoding it unguarded in finalize converted the result into `PersistFailed`, which would silently lose a completed commute on any corrupt polyline.
- **Fix:** Wrapped the decode in a try/catch that falls back to no endpoints (→ geofence null → time label). Error swallowed without logging (PII guard, T-21-02).
- **Files modified:** lib/features/tracking/services/tracking_service_controller.dart
- **Verification:** persist test's empty-polyline case + full suite green.
- **Committed in:** `2a51fdf`

**4. [Rule 1 - Bug] Thread `directionSource` / fix polyline fixtures in affected tests**
- **Found during:** Task 1 and Task 3
- **Issue:** The new required `directionSource` on the generated `TripRow` broke `TripRow(...)` construction in `api_client_test.dart` and `trip_serializer_test.dart`; the new required coord fields on `UserPreferencesValue` broke ~12 test construction sites; and `tracking_notifier_direction_test.dart` used the placeholder polyline `'encoded'`, which the new finalize decode rejected.
- **Fix:** Added `directionSource:` to the four `TripRow(...)` sites; added the four null coord fields to every `UserPreferencesValue(...)` site; replaced the placeholder polyline with a real `encodePolyline(...)` output (geofence inert with no coords set, so the override/auto-label intent is preserved).
- **Files modified:** test/unit/sync/api_client_test.dart, test/unit/sync/trip_serializer_test.dart, test/unit/features/tracking/tracking_notifier_direction_test.dart, plus ~8 UserPreferencesValue construction-site test files.
- **Verification:** Full `flutter test` suite green (536 passing).
- **Committed in:** `2e209ed` (UserPreferencesValue sites), `2a51fdf` (TripRow + polyline fixtures)

---

**Total deviations:** 4 auto-fixed (2 Rule 1 bugs, 1 Rule 2 missing-critical, 1 Rule 3 blocking)
**Impact on plan:** All auto-fixes were necessary for compilation, no-data-loss correctness, and keeping the prior suite green. No scope creep — no settings UI, no backfill, no sync change (those remain in Plans 02/03 and out of scope).

## Issues Encountered
- The D-07 "equidistant → null" resolver test initially flapped: a meridian-symmetric fixture produced a sub-millimeter great-circle asymmetry on the WGS84 ellipsoid, so `distanceBetween` picked a side. Resolved by switching the fixture to LONGITUDE-symmetric anchors on a shared parallel (east-west legs from a midpoint are exactly equal), making the equidistant case deterministic. The resolver's strict `<` / equal→null logic was correct throughout.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- Plan 02 (picker UI) can wire the dedicated Home/Office coordinate setters; the columns, the value-type fields, and `_copyPrefs` preservation are all in place.
- Plan 03 (backfill) can call the same `GeofenceDirectionResolver` over historical trips and safely re-label only rows where `direction_source != manual`.

---
*Phase: 21-home-office-locations-geofence*
*Completed: 2026-06-06*

## Self-Check: PASSED

All 6 created files exist on disk; all three task commits (`2e209ed`, `35fa81f`, `2a51fdf`) are present in the git log. Full suite: 536 passing / 10 skipped / 0 failing.
