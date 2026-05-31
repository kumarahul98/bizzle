---
phase: 10
plan: 01
subsystem: "backend-infrastructure"
tags: [firebase, cloud-functions, typescript, firestore, zod, scaffold]
requires: []
provides: ["backend-scaffold", "trip-contract", "auth-util", "validation-util", "firestore-converter", "response-helper", "deny-all-rules", "health-endpoint"]
affects: ["backend"]
tech-stack:
  added:
    - "firebase-functions@7.2.5"
    - "firebase-admin@13.10.0"
    - "express@5.2.1"
    - "zod@4.4.3"
    - "typescript@5.9.3"
    - "jest@30.4.2 + ts-jest@29.4.11"
    - "supertest@7.2.2"
  patterns:
    - "Single HTTPS api function wrapping an exported Express app (D-04)"
    - "verify -> validate -> trust util ordering (D-07)"
    - "FirestoreDataConverter<TripDoc> typed reads/writes (D-10)"
    - "Canonical response shape { statusCode, body: { data?, error? } } (D-06)"
key-files:
  created:
    - "backend/firebase.json"
    - "backend/.firebaserc"
    - "backend/firestore.rules"
    - "backend/firestore.indexes.json"
    - "backend/functions/package.json"
    - "backend/functions/tsconfig.json"
    - "backend/functions/.gitignore"
    - "backend/functions/jest.config.js"
    - "backend/functions/src/index.ts"
    - "backend/functions/src/types/trip.ts"
    - "backend/functions/src/utils/auth.ts"
    - "backend/functions/src/utils/validation.ts"
    - "backend/functions/src/utils/firestore.ts"
    - "backend/functions/src/utils/response.ts"
    - "backend/functions/src/utils/__tests__/validation.test.ts"
    - "backend/functions/src/utils/__tests__/auth.test.ts"
  modified: []
decisions:
  - "Pinned express to v5 + @types/express v5 (same major) per RESEARCH; firebase-functions ships its own internal @types/express v4 transitively with no conflict"
  - "typescript resolved to 5.9.3 (^5.5 latest 5.x, NOT TS 6) per RESEARCH A4 for ts-jest stability"
  - "routePolyline capped at 100000 chars per cross-AI review amendment (memory hardening)"
metrics:
  duration: "~7m"
  completed: "2026-05-31T20:27:13Z"
---

# Phase 10 Plan 01: Backend Scaffold & Shared Infrastructure Summary

Stood up the self-contained `backend/` Firebase project plus the complete shared
infrastructure (Phase 10->11 type contract + four utils) the three `/trips` handlers in
Plan 02 will consume. The backend installs, builds clean under strict TS (no `any`), boots on
the Firebase Emulator Suite serving `GET /health` (200), ships deny-all Firestore rules + a
composite-index target, and has 27 green unit tests for the pure-logic utils.

## What Was Built

**Scaffold (Task 1):**
- `backend/firebase.json` — functions + firestore (rules + indexes) + emulators block (auth 9099, functions 5001, firestore 8080, ui 4000, `singleProjectMode:true`). Repo-root FlutterFire `firebase.json` left untouched (D-01).
- `backend/.firebaserc` — default project `travey-298a7`.
- `backend/firestore.rules` — deny-all (`allow read, write: if false`) (D-13, success criterion 5).
- `backend/firestore.indexes.json` — composite index `trips(userId ASC, deleted ASC)` for the restore query (M2 / Pitfall 5).
- `backend/functions/package.json` — Node 20 engine; RESEARCH-verified pinned deps; build/lint/serve/test/test:unit scripts.
- `backend/functions/tsconfig.json` — strict CommonJS, outDir lib, rootDir src, noUnusedLocals/Parameters.
- `backend/functions/.gitignore` — ignores `node_modules/` and `lib/`.
- `backend/functions/jest.config.js` — `projects` array with a `unit` project (load-bearing shape; Plan 03 appends `integration`).

**Contract + utils + boot (Task 2):**
- `src/types/trip.ts` — `Direction`, `Trip` (camelCase, ISO-string timestamps, mirrors Drift `trips`), `TripDoc` (adds `deleted`/`deletedAt`/`serverUpdatedAt`).
- `src/utils/auth.ts` — `AuthError` (statusCode 401), pure `extractBearerToken`, `verifyAuth` (`getAuth().verifyIdToken`, rethrows as AuthError; never echoes token/raw error).
- `src/utils/validation.ts` — `kMaxSyncBatchTrips=1000`, `tripSchema` (uuid id, ISO datetimes, enum direction, `routePolyline` `.max(100000).nullable()`, optional/ignored `userId`), `syncTripsBody` (`.min(1).max(1000)`), `tripIdParam` (uuid).
- `src/utils/firestore.ts` — `tripConverter: FirestoreDataConverter<TripDoc>`, `tripsCollection()`.
- `src/utils/response.ts` — `sendSuccess`/`sendError` in the canonical shape.
- `src/index.ts` — `initializeApp()`, `setGlobalOptions({region:'us-central1'})`, exported Express `app` with `express.json()`, `GET /health` -> 200 `{status:'ok'}`, `export const api = onRequest(app)`.

**Unit tests (Task 3):**
- `validation.test.ts` (20 tests) + `auth.test.ts` (7 tests) — 27 tests covering zod accept/reject (incl. non-UUID id, empty array, 1000 accept / 1001 reject DoS cap, routePolyline over-cap reject + at-cap accept, tripIdParam UUID) and bearer parsing + mocked `verifyAuth` success/failure.

## Task Commits

1. **Task 1: Backend scaffold** — `0ecf296` ([infra])
2. **Task 2: Contract types + utils + GET /health** — `cb015a3` ([backend])
3. **Task 3: Unit tests for validation + auth utils** — `6948644` ([backend])

## Commands Run (real output)

- `cd backend/functions && npm install` — `added 572 packages` (9 moderate transitive advisories in firebase-tools deps; not actionable here). Resolved pins: firebase-functions 7.2.5, firebase-admin 13.10.0, express 5.2.1, zod 4.4.3, typescript 5.9.3, jest 30.4.2, ts-jest 29.4.11, @types/jest 30.0.0, @types/express 5.0.6, supertest 7.2.2, @types/supertest 7.2.0, @types/node 20.19.41.
- `npm run build` — exit 0, zero TS errors. `grep` for ` any`/`as any`/`<any>` in `src/` -> none.
- `npm run lint` (`tsc --noEmit`) — clean.
- `firebase emulators:exec --only functions,firestore,auth 'curl ... /api/health'` — `functions[us-central1-api]: http function initialized`; `HTTP=200`.
- `npm run test:unit` — `Test Suites: 2 passed, 2 total / Tests: 27 passed, 27 total`.
- Deny-all + indexes greps: `DENY_ALL_OK`, `INDEXES_OK`.

## Key Decisions

- **Express 5 + @types/express 5 (same major)** per RESEARCH. firebase-functions pulls its own internal `@types/express@4`/`express@4` as deduped transitive deps; this is firebase-functions' own typing surface and does not conflict — build is clean.
- **typescript ^5.5 -> resolved 5.9.3** (latest 5.x, not TS 6.0.3) per RESEARCH A4/Open Q6 for ts-jest/eslint stability.
- **routePolyline `.max(100000).nullable()`** — applied the cross-AI review amendment (memory hardening) with the two added test cases (over-cap reject, at-cap accept).
- **`as TripDoc` in tripConverter.fromFirestore** is a typed assertion (not `any`); no `any` anywhere in `src/`.

## Deviations from Plan

None functional. Version note only: `typescript` resolved to 5.9.3 and `@types/node` to 20.19.41 (latest within the pinned `^5.5`/`^20` ranges); all other deps match the RESEARCH table exactly. Build, lint, emulator health, and all 27 unit tests are green.

## Node Runtime Callout (L1)

`engines.node` is pinned to `"20"` (locked D-02). Node 20 is a SUPPORTED but DEPRECATED Cloud
Functions runtime; Firebase / firebase-admin 13 recommend Node 22. The emulator used a host
node@20 successfully (local interpreter is Node 25, independent of the runtime pin). If a future
deploy is blocked on Node 20, surface the Node 22 recommendation to the user before changing the lock.

## Self-Check: PASSED

All 16 created files present on disk; all three task commits present in git history.
