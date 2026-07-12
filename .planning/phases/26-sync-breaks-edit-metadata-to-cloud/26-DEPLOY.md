# Phase 26 — Live Deploy Record (Plan 01, SC2 gate)

**Date:** 2026-07-12
**Project:** travey-298a7 (Blaze)
**Branch:** main

## Deployed

`cd backend && firebase deploy --only functions --project travey-298a7`

- **Function `api`** — v2, https, region us-central1, runtime nodejs20, memory 256Mi — **Successful update operation** (first redeploy since Phase 10's original deploy; no backend/functions changes shipped between then and now).
- **What changed:** the Phase 26 wire-contract extension — `tripSchema` (zod), `Trip`/`TripDoc` types, `tripConverter.fromFirestore`, and both handlers now accept, store, and round-trip `totalPausedSeconds`, `isEdited`, `directionSource`, and `breaks` (max 50/trip). All four fields are `.default()`-backed so pre-Phase-26 clients keep syncing unchanged.
- **Pre-deploy gate:** `npm run build` clean (strict TS) + full emulator suite `npm test` green — **60/60 tests, 7 suites, both jest projects, zero skipped** — run immediately before the deploy.

## Live function URL (stable Cloud Run gen2 URL)

```
https://us-central1-travey-298a7.cloudfunctions.net/api
```

Endpoints: `POST /trips/sync`, `GET /trips/restore`, `DELETE /trips/{tripId}`, `GET /health`.

## Live smoke test results

| Request | Expected | Actual |
|---------|----------|--------|
| `GET /api/health` (no auth) | 200 | **200** ✓ |
| `GET /api/trips/restore` (no token) | 401 | **401** ✓ |
| `POST /api/trips/sync` (no token, `{"trips":[]}`) | 401 | **401** ✓ |

Auth gate is enforced live on both extended endpoints; the function is reachable. (Note: the plan's smoke-test URLs omitted the `/api` path prefix — corrected here to match the Phase 10 base URL; bare `.../cloudfunctions.net/health` is a 404 by design.)

## Deploy warnings (non-blocking)

- **Node.js 20 deprecated 2026-04-30, decommission 2026-10-30** — deploy still succeeds today; the runtime must be bumped to nodejs22 before 2026-10-30 or future deploys will be blocked. (Escalated from Phase 10's "bump post-MVP" note — there is now a hard deadline.)
- **No Artifact Registry cleanup policy in us-central1** — functions deployed successfully, but the CLI exited non-zero because it could not auto-create a container-image cleanup policy. Cosmetic/billing-hygiene only; fix at leisure with `firebase functions:artifacts:setpolicy` (or pass `--force` on a future deploy).

## Not done live (recorded for wake-up verification)

- **Live 2xx happy-path with a REAL Google ID token** — same limitation as Phase 10: minting a prod ID token requires an interactive Google sign-in, not feasible headlessly. The happy paths (4-field sync write, legacy-doc restore defaults, lossless round-trip) are proven by the 60-test emulator suite against identical code.
- **Wake-up check:** sign in on a real device/emulator client, sync a trip that has breaks, then confirm in the Firebase console that the Firestore doc under `trips/{id}` carries all 4 new fields (`totalPausedSeconds`, `isEdited`, `directionSource`, `breaks`).
