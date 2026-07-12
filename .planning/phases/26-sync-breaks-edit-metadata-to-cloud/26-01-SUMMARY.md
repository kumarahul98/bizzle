---
phase: 26-sync-breaks-edit-metadata-to-cloud
plan: 01
subsystem: backend
tags: [firebase, cloud-functions, zod, firestore, sync, wire-contract, deploy]
requires:
  - phase: 10-backend-infrastructure
    provides: "api Cloud Function (sync/delete/restore handlers, tripSchema, tripConverter) live on travey-298a7"
  - phase: 18-pause-resume-breaks
    provides: "Client-side break/pause data model (trip_breaks, total_paused_seconds) this wire contract mirrors"
provides:
  - "Deployed backend accepts + losslessly round-trips totalPausedSeconds, isEdited, directionSource, breaks (SC1)"
  - "Old-client compatibility: all 4 fields .default()-backed in tripSchema (omitting them still validates)"
  - "Legacy Firestore docs restore cleanly with defaults 0/false/'time'/[] via tripConverter (SC4)"
  - "Live api function redeployed on travey-298a7 BEFORE any Phase 26 client plan (SC2 gate)"
affects:
  - 26-02+ client plans (serializer/backfill/restore) may now emit the 4 new fields safely
tech-stack:
  added: []
  patterns:
    - "zod 4 .default()-backed optional fields for backward-compatible wire-contract extension"
    - "Read-side defaulting in FirestoreDataConverter.fromFirestore (field-by-field ?? defaults, no zod on read path)"
key-files:
  created:
    - .planning/phases/26-sync-breaks-edit-metadata-to-cloud/26-DEPLOY.md
  modified:
    - backend/functions/src/types/trip.ts
    - backend/functions/src/utils/validation.ts
    - backend/functions/src/utils/firestore.ts
    - backend/functions/src/handlers/sync-trips.ts
    - backend/functions/src/handlers/restore-trips.ts
    - backend/functions/test/helpers/fixtures.ts
    - backend/functions/test/helpers/emulator.ts
    - backend/functions/src/utils/__tests__/validation.test.ts
    - backend/functions/test/handlers/sync-trips.test.ts
    - backend/functions/test/handlers/restore-trips.test.ts
decisions:
  - "kMaxBreaksPerTrip=50 (T-26-01 DoS cap), mirroring the kMaxRoutePolylineChars/kMaxSyncBatchTrips bound pattern"
  - "directionSource enum locked to literal 'manual'/'geofence'/'time' matching client kDirectionSource* constants byte-for-byte"
  - "SC4 legacy-doc test seeds via raw db handle (literally omitting the 4 keys), not seedTrip, whose TripDoc literal always includes them"
metrics:
  duration: "~25 min (plus one stalled background-deploy detour, restarted in foreground)"
  completed: "2026-07-12"
  tasks: 3
  files: 11
---

# Phase 26 Plan 01: Backend Wire-Contract Extension + Live Deploy Summary

**One-liner:** Extended the deployed sync/restore wire contract with `totalPausedSeconds`, `isEdited`, `directionSource`, and a bounded `breaks` array (zod `.default()`-backed for old clients, converter-defaulted for legacy docs) and redeployed the `api` function live on travey-298a7 — SC2 gate satisfied before any client plan runs.

## What Was Built

### Task 1 — Types + zod schema (`afd0952`)
- `types/trip.ts`: new `DirectionSource` union (`'manual' | 'geofence' | 'time'`) and `TripBreak` interface; `Trip` gains the 4 fields (`TripDoc` inherits via `extends`).
- `validation.ts`: exported `kMaxBreaksPerTrip = 50`; local `tripBreakSchema` (per-break `.datetime()` validation, T-26-03); `tripSchema` extended with 4 `.default()`-backed fields — zod 4 semantics make the keys optional on input AND fill defaults in parsed output, so old clients keep syncing.
- `fixtures.ts` `makeTrip` and `validation.test.ts` `makeValidTrip` extended so all existing tests exercise a complete payload; new `describe('tripSchema — Phase 26 metadata fields')` block covers omitted-defaults, breaks present, 50-at-cap/51-over-cap, all 3 valid + 1 invalid `directionSource` values, malformed break timestamp, negative `totalPausedSeconds`.

### Task 2 — Converter + handlers + integration tests (`8ae6140`)
- `firestore.ts` `tripConverter.fromFirestore`: 4 field-by-field defaulted mappings (`?? 0 / false / 'time' / []`) in the exact `routePolyline` shape — the ONLY read-side defaulting seam; no zod on the read path.
- `sync-trips.ts`: doc literal writes the 4 fields straight from already-validated zod output (no re-defaulting).
- `restore-trips.ts`: Trip projection returns the 4 fields from the converter's defaulted output.
- `emulator.ts`: `SeedTripInput`/`seedTrip` gain optional overrides for the 4 fields, fully backward compatible.
- `sync-trips.test.ts` happy path asserts the 4 fields land on the raw Firestore doc unchanged; `restore-trips.test.ts` new `describe('legacy doc + new metadata (SC4)')` — (a) raw-db-seeded doc literally omitting the 4 keys restores 200 with defaults, (b) explicit non-default metadata round-trips unchanged.

### Task 3 — Full suite + live deploy (`2503da3`)
- Pre-deploy gate: `npm run build` clean; full emulator suite `npm test` green — **60/60 tests, 7 suites, both jest projects, zero skipped**.
- `firebase deploy --only functions --project travey-298a7`: `api` (v2, us-central1, nodejs20) — Successful update operation; first redeploy since Phase 10.
- Live smoke checks: `GET /api/health` → **200**, `GET /api/trips/restore` (no token) → **401**, `POST /api/trips/sync` (no token) → **401**.
- `26-DEPLOY.md` written mirroring `10-DEPLOY.md`'s format, including the wake-up check (device sync of a trip with breaks → confirm 4 fields in Firestore console).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan's live smoke-test URLs omitted the `/api` path prefix**
- **Found during:** Task 3 (all three curls returned 404)
- **Issue:** Task 3 specified `https://us-central1-travey-298a7.cloudfunctions.net/health` etc., but the Express app is mounted at the `api` function — the correct base (per 10-DEPLOY.md) is `.../cloudfunctions.net/api`.
- **Fix:** Re-ran the smoke checks against `/api/health`, `/api/trips/restore`, `/api/trips/sync` → exactly 200/401/401. Documented the correction in 26-DEPLOY.md.
- **Files modified:** none (verification-command fix only)
- **Commit:** 2503da3

**2. [Rule 3 - Blocking] Bare `jest` not on PATH inside `emulators:exec`**
- **Found during:** Task 2 verification (exit 127: `jest: command not found`)
- **Issue:** The plan's scoped emulator command invokes `jest` directly; it is a local devDependency, not global.
- **Fix:** Ran via `npx jest --runInBand ...` (identical semantics to the `npm test` script's resolution).
- **Files modified:** none
- **Commit:** n/a (command-invocation fix)

### Non-blocking observations (deferred, no action)

- **nodejs20 deprecation now has a hard deadline:** deploy warned Node.js 20 was deprecated 2026-04-30 and is decommissioned 2026-10-30 — future deploys will be blocked after that. Recorded in 26-DEPLOY.md; runtime bump is out of this plan's scope.
- **Artifact Registry cleanup policy missing:** the deploy CLI exited non-zero AFTER a successful function update because it couldn't auto-create an image cleanup policy (billing hygiene only). Recorded in 26-DEPLOY.md with the `firebase functions:artifacts:setpolicy` remedy; not applied here (config change outside plan scope).

### Execution note

The first deploy attempt was launched as a background job that never produced output and had to be abandoned; the deploy was re-run in the foreground and completed normally. No duplicate side effects (first process never reached the upload stage before the session was redirected).

## Verification

- `npm run build` clean (strict TS, zero `any` in touched files) after every task.
- Task 1: `npm run test:unit` 39/39 green (includes the 10 new Phase 26 schema cases).
- Task 2: scoped emulator run (sync-trips + restore-trips suites) 11/11 green, zero skipped.
- Task 3: full `npm test` 60/60 green immediately pre-deploy; live 200/401/401 smoke checks post-deploy.
- Threat register: T-26-01 (`.max(kMaxBreaksPerTrip)`), T-26-02 (`z.enum` closed set), T-26-03 (per-break `.datetime()`) all implemented and test-covered; T-26-04/05/06 accepted per plan.

## Known Stubs

None — all four fields are wired end-to-end (validate → write → convert → restore) with no placeholders.

## Threat Flags

None — no new network endpoints, auth paths, or trust-boundary surface beyond the `<threat_model>`'s registered items (all mitigations applied).

## Self-Check: PASSED

All created/modified files exist on disk; commits afd0952, 8ae6140, 2503da3 present in git history.
