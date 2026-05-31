---
phase: 10-backend-infrastructure
plan: 02
subsystem: backend
tags: [cloud-functions, express, firestore, auth, rest-api]
requires:
  - "10-01: Express app skeleton (app/api/onRequest), shared utils (auth, validation, firestore), Trip/TripDoc types, composite index"
provides:
  - "POST /trips/sync handler (batch upsert, forced uid, chunked <=500 writes, <=1000 cap)"
  - "DELETE /trips/:tripId handler (ownership-checked soft-delete)"
  - "GET /trips/restore handler (caller's non-deleted trips via typed query)"
  - "Express router mounting all three /trips/* routes on the api function"
affects:
  - "Phase 11 sync engine consumes these three REST endpoints"
tech-stack:
  added: []
  patterns:
    - "verify (ID token, 401) -> validate (zod, 400) -> trust ordering in every handler"
    - "server forces userId=uid from verified token; client value ignored (D-08)"
    - "soft-delete only (deleted:true + deletedAt); no hard delete"
    - "chunked Firestore batched writes at <=500 ops/batch, re-instantiated db.batch() per chunk"
    - "consistent { statusCode, body: { data? | error? } } response shape; no token/stack leakage"
key-files:
  created:
    - backend/functions/src/handlers/sync-trips.ts
    - backend/functions/src/handlers/delete-trip.ts
    - backend/functions/src/handlers/restore-trips.ts
  modified:
    - backend/functions/src/index.ts
decisions:
  - "No body-size limit added to express.json(): Plan 01 shipped a plain express.json(); the M1 DoS cap is enforced by the zod .max(1000) array cap (rejects oversized batches with 400 before any work), so a separate byte limit is redundant for the locked threat model."
  - "delete-trip returns 404 (not 403) for a foreign-owned trip to avoid an existence oracle (T-10-06)."
  - "restore strips server metadata (deleted/deletedAt/serverUpdatedAt) and returns the client Trip[] shape — avoids Firestore Timestamp serialization and matches the Phase 11 contract."
metrics:
  duration: ~15m
  completed: 2026-05-31
---

# Phase 10 Plan 02: Three HTTPS endpoints + Express routing Summary

Implemented the three REST handlers (`POST /trips/sync`, `DELETE /trips/:tripId`, `GET /trips/restore`) following the verify→validate→trust contract and mounted them on the Plan 01 Express `app`; all compile clean under strict TS with no `any`, and the Plan 01 27-test unit suite still passes.

## What Was Built

### Task 1 — `POST /trips/sync` (`sync-trips.ts`, commit `33ef4e3`)
- `verifyAuth(req)` first; `AuthError`/any failure → `401 {error:"Unauthorized"}` with zero Firestore work.
- `syncTripsBody.safeParse(req.body)` → `400 {error:"Invalid request body"}`. The `.min(1).max(1000)` cap lives in the schema (Plan 01), so an empty batch OR a >1000 batch is rejected here before any write (M1 DoS cap; no manual length check).
- For each trip: builds a `WithFieldValue<TripDoc>` with **`userId` forced to the token uid** (client value ignored, D-08), `deleted:false`, `deletedAt:null`, `serverUpdatedAt=FieldValue.serverTimestamp()`, all trip fields stored as received (ISO strings; nullable `routePolyline`).
- Chunked batched writes: `FIRESTORE_BATCH_LIMIT = 500`, `db.batch()` re-instantiated per chunk, `batch.set(collection.doc(trip.id), doc, {merge:true})`, `await batch.commit()` per chunk → idempotent re-sends keyed by UUID, handles the >500-but-≤1000 case.
- Returns `200 {data:{syncedIds}}`; write phase wrapped → `500 {error:"Internal error"}`.

### Task 2 — `DELETE /trips/:tripId` + `GET /trips/restore` (commit `29b2d06`)
- **delete-trip.ts**: auth → `tripIdParam` UUID validation (`400 {error:"Invalid trip id"}`) → `ref.get()`; missing OR `data.userId !== uid` → `404 {error:"Trip not found"}` (404 over 403 to avoid the existence oracle) → `ref.update({deleted:true, deletedAt, serverUpdatedAt})`. **No `.delete()` anywhere.** Returns `200 {data:{id}}`.
- **restore-trips.ts**: auth → `tripsCollection().where("userId","==",uid).where("deleted","==",false).get()` via the typed converter (composite index shipped in Plan 01 for prod) → maps each `TripDoc` to an explicit client `Trip` (server metadata stripped) → `200 {data:{trips}}`.

### Task 3 — Router wiring (`index.ts`, commit `cf955a6`)
- Imported the three handlers; registered `app.post("/trips/sync",…)`, `app.get("/trips/restore",…)`, `app.delete("/trips/:tripId",…)` on the existing `app`.
- Preserved `app.use(express.json())`, `GET /health`, `setGlobalOptions({region:"us-central1"})`, and `export const api = onRequest(app)` from Plan 01 unchanged.

## Commands + Real Results

| Command | Result |
|---------|--------|
| `npm run build` (tsc) | exit 0 — clean strict-TS compile |
| `npm run lint` (tsc --noEmit) | exit 0 — clean |
| `npm run test:unit` (jest unit project) | exit 0 — **Test Suites: 2 passed, Tests: 27 passed** (Plan 01 suite intact) |
| `grep -rE ": any|<any>|as any" src/handlers src/index.ts` | no matches — NO_ANY_OK |
| `grep ref.delete \| .doc().delete` in delete-trip.ts | no matches — NO_HARD_DELETE_OK |
| `grep -E "app.(post\|get\|delete)" src/index.ts` | shows `/health`, `/trips/sync` (post), `/trips/restore` (get), `/trips/:tripId` (delete) |
| auth-first ordering (line numbers) | sync L43<L59, delete L30<L46, restore L29<L37 — `verifyAuth` before any Firestore call in all three |

## Deviations from Plan

**1. [Rule 3 — interface reconciliation] `express.json()` body limit**
- **Found during:** Task 3 (reading the real `index.ts`).
- **Issue:** The execution prompt said "keep express.json with the body limit", but Plan 01 shipped a plain `app.use(express.json())` with no limit.
- **Resolution:** Kept it as-is (no byte limit). The M1 DoS cap is enforced by `syncTripsBody`'s `.max(1000)` array cap (400 before any Firestore work), which is the locked mitigation for T-10-07. Adding a byte limit would be a new, unlocked threshold not in CLAUDE.md/constants — out of scope.
- **Files modified:** none beyond planned `index.ts`.

Otherwise the plan executed as written. Real Plan 01 exports matched the `<interfaces>` contract (`verifyAuth`/`AuthError`, `syncTripsBody`/`tripIdParam`/`kMaxSyncBatchTrips`, `tripsCollection`/`tripConverter`, `Trip`/`TripDoc`, `app`/`api`). The only naming nuance: `tripsCollection` is an arrow-function const (not a `function`), called identically.

## Authentication Gates
None — no live credentials or external auth needed (static build + unit gate only; emulator integration is Plan 03).

## Known Stubs
None. All handlers are fully implemented (no TODOs, no placeholder returns, no dead code).

## Verification Note
Per plan D-15, this plan's gate is the clean strict-TS build + static wiring/security checks above. Full runtime/emulator verification (401 rejection, happy-path Firestore state, ownership 404s, 1001→400 no-writes) is **Plan 03**.

## Self-Check: PASSED
- FOUND: backend/functions/src/handlers/sync-trips.ts
- FOUND: backend/functions/src/handlers/delete-trip.ts
- FOUND: backend/functions/src/handlers/restore-trips.ts
- FOUND: backend/functions/src/index.ts (routes registered)
- FOUND commit 33ef4e3 (sync-trips)
- FOUND commit 29b2d06 (delete-trip + restore-trips)
- FOUND commit cf955a6 (index.ts routing)
