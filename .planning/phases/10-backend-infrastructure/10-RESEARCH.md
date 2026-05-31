# Phase 10: Backend Infrastructure - Research

**Researched:** 2026-06-01
**Domain:** Firebase Cloud Functions 2nd gen (TypeScript) + Firestore + Emulator-based testing
**Confidence:** HIGH — architecture/patterns locked by CONTEXT.md + stable Firebase APIs; **dependency versions VERIFIED against the npm registry on 2026-06-01** and local tooling probed.

> **Tooling note:** All versions below are `[VERIFIED: npm registry, 2026-06-01]` unless marked otherwise. Local environment confirmed: **Node v25.2.1, npm 11.12.1, firebase-tools 15.19.0** (global, Homebrew `/opt/homebrew/bin/firebase`).
>
> **Three deltas from naive assumptions — read before planning:**
> 1. **Node runtime:** local Node 25 is fine for build/test but is **NOT** an accepted Cloud Functions runtime. `engines.node` MUST be `"20"` or `"22"`. D-02 locks **20** — still supported but **deprecated**; Firebase and `firebase-admin` 13.10 strongly recommend **22**. Flag to user (Open Q2). Deploy with Node 20 still works today.
> 2. **Express is at 5.x** (`5.2.1` current) — Express 5 is now the default major. Named path params (`/trips/:tripId`) are **unchanged** and work in v5; only the `*` wildcard syntax changed. So the locked routing design is fine on Express 5. (You may still pin Express 4 for maximum example-parity — see Standard Stack note.)
> 3. **zod is at 4.x** (`4.4.3`) — `.safeParse`, `.parse`, `z.infer`, `z.object`, `.max()` are all unchanged from the v3 API used below. Safe to use zod 4.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions (D-01 … D-15 — do NOT re-litigate)

- **D-01** Self-contained `backend/` dir: own `backend/firebase.json`, `backend/.firebaserc` (default project `travey-298a7`), `backend/firestore.rules`, `backend/functions/`. Repo-root `firebase.json` (FlutterFire app config) is LEFT UNTOUCHED. Deploy runs from `backend/`.
- **D-02** Node.js 20, Cloud Functions 2nd gen, `firebase-functions` v2 `onRequest`. Region `us-central1`.
- **D-03** Strict TypeScript (`"strict": true`, no `any`). `firebase-admin` for Firestore + Auth. `zod` for validation. Functions' own ESLint (Firebase init default).
- **D-04** Single HTTPS function `api` mounting an Express app → routes to per-file handlers. Each handler self-contained in `backend/functions/src/handlers/*.ts`.
- **D-05** Routes: `POST /trips/sync` → `sync-trips.ts`; `DELETE /trips/:tripId` → `delete-trip.ts`; `GET /trips/restore` → `restore-trips.ts`. Auth + validation are the FIRST lines of each handler (no shared-middleware trust shortcut — verify → validate → trust, per handler).
- **D-06** Response shape everywhere: `{ statusCode, body: { data?, error? } }`. HTTP status mirrors `statusCode`. Never leak stack traces or tokens.
- **D-07** Verify ID token FIRST (`getAuth().verifyIdToken(bearer)` from `Authorization: Bearer <token>`). Missing/invalid/expired → 401, no further work. Then zod-validate → 400 on failure. Then trust.
- **D-08** Server forces ownership. Sync sets each trip's `userId` to token `uid` (client value ignored). Delete reads doc, rejects 404/403 if `userId !== uid`. Restore filters `userId == uid`.
- **D-09** Top-level `trips` collection, doc id = client trip UUID. Delete maps to doc path; sync upsert = `set(merge)` keyed by UUID (idempotent); restore = `where('userId','==',uid).where('deleted','==',false)`.
- **D-10** Doc shape (FirestoreDataConverter-typed): all Drift trip fields (`id, userId, startTime, endTime, durationSeconds, distanceMeters, routePolyline, direction, timeMovingSeconds, timeStuckSeconds, isManualEntry, createdAt, updatedAt`) **plus** `deleted: boolean` (default false), `deletedAt: Timestamp|null`, `serverUpdatedAt: Timestamp` (= `FieldValue.serverTimestamp()` on every write). Trip timestamps stored as **ISO 8601 UTC strings exactly as received**; server metadata uses Firestore `Timestamp`.
- **D-11** Soft delete only: delete sets `deleted:true`, `deletedAt:serverTimestamp()`; doc never removed. Sync upsert of an existing id sets `deleted:false` (resurfaces). Restore excludes `deleted==true`.
- **D-12** `POST /trips/sync` accepts `{ trips: Trip[] }`. Batched write (`set(ref, doc, {merge:true})` per trip), chunked ≤500/batch. Returns `{ data: { syncedIds: string[] } }`. Idempotent.
- **D-13** `firestore.rules`: deny-all — `match /{document=**} { allow read, write: if false; }`. Admin SDK only. Deployed alongside functions.
- **D-14** `backend/firebase.json` `emulators` block: auth 9099, functions 5001, firestore 8080, ui 4000, `singleProjectMode: true`. Tests run against emulator only, never prod.
- **D-15** Tests per endpoint: (a) auth-reject — no token AND invalid token both → 401; (b) happy path — emulator-minted valid token → correct 2xx + expected Firestore state; (c) ownership — user A cannot delete/restore user B's trip. Runner: Jest is the Firebase scaffold default (planner confirms).

### Claude's Discretion
- Test runner choice between Jest and vitest (D-15 leaves it to planner; **recommendation below: use Jest** = Firebase scaffold default).
- Exact zod schema field-by-field (must mirror the Drift trip fields — see contract below).
- HTTP request library for tests (recommend `supertest` against the Express app, OR raw `fetch`/`node:http` against the running functions emulator).

### Deferred Ideas (OUT OF SCOPE — do not build)
- Client sync engine, `api_client`, retry/backoff → Phase 11.
- Settings "Cloud sync" / "Restore from cloud" UI → Phase 11.
- Any `cloud_firestore` SDK use in the Flutter client (architecturally forbidden).
- Server-side analytics/aggregation; server→client sync; conflict resolution.
- Todo `bug-manual-entry-missing-traffic-fields` → Phase 11 / separate trips fix.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BACK-02 | `POST /trips/sync` Cloud Function batch-upserts trips from client | Express POST route → `sync-trips.ts`; chunked `db.batch()` `set(merge)`; zod array schema; ownership forced (D-08); idempotent (D-12) |
| BACK-03 | `DELETE /trips/{tripId}` Cloud Function soft-deletes a trip | Express `delete('/trips/:tripId')` → `delete-trip.ts`; read-then-ownership-check; `update({deleted:true, deletedAt:serverTimestamp()})` (D-11) |
| BACK-04 | `GET /trips/restore` Cloud Function returns all non-deleted trips for the user | Express GET route → `restore-trips.ts`; `where('userId','==',uid).where('deleted','==',false).get()`; converter maps docs back to `Trip` JSON |

Phase success criteria (ROADMAP) covered: (1) sync writes batch → BACK-02; (2) delete soft-deletes → BACK-03; (3) restore returns non-deleted → BACK-04; (4) all reject without valid token → auth util + D-07; (5) deny-all rules → `firestore.rules` D-13.
</phase_requirements>

## Project Constraints (from CLAUDE.md)

These have the authority of locked decisions. Planner MUST NOT contradict:

- Strict TypeScript, **no `any`**. Explicit types for every request/response payload, Firestore doc, function param.
- Use Admin SDK with **typed interfaces** — `FirestoreDataConverter` (or typed wrappers) so reads/writes map to interfaces.
- **Verify auth → validate (zod) → trust.** No redundant checks deeper in the code after that.
- Firestore Security Rules **default-deny**; only Admin SDK touches data.
- **Each handler self-contained**, one file per handler in `backend/functions/src/handlers/`; shared utils in `backend/functions/src/utils/`; **no cross-handler dependencies**.
- Use `firebase-functions` **v2 HTTPS triggers** + Admin SDK (`firebase-admin/firestore`, `firebase-admin/auth`).
- Response shape `{ statusCode, body: { data?, error? } }`.
- UUIDs client-generated; all timestamps ISO 8601 / UTC.
- Soft deletes everywhere (`deleted: true`); never hard-delete from Firestore.
- Commit prefix for this phase: `[backend]` / `[infra]`. (CLAUDE.md convention; GSD commit hook may override format.)
- Deploy via `firebase deploy --only functions` and `firebase deploy --only firestore:rules` (combine: `--only functions,firestore:rules`).

---

## Summary

Greenfield, self-contained Firebase backend. Nothing exists under `backend/` yet (verified — directory absent). The phase stands up a `backend/` Firebase CLI project: one HTTPS Cloud Function (`api`, 2nd gen, Node 20) that mounts an Express app routing three REST endpoints to per-file handlers, each doing verify-token → zod-validate → Firestore write/read via a typed `FirestoreDataConverter`. Firestore is locked with deny-all rules; only the Admin SDK touches data. Tests run against the Emulator Suite, minting valid ID tokens against the **auth emulator** (which issues unsigned tokens that `verifyIdToken` accepts when `FIREBASE_AUTH_EMULATOR_HOST` is set).

The stack is fully locked by D-01..D-15 + CLAUDE.md, so this research is prescriptive. All dependency versions are **verified against the live npm registry** (table below). The single non-obvious technique is the auth-emulator token mint — documented in detail.

**Primary recommendation:** Scaffold with `firebase init functions` (TypeScript, ESLint yes) inside `backend/`, take its tsconfig/eslint, **use Jest + ts-jest** (scaffold default; D-15 endorses), add Express + zod, write all three handlers behind a single `api` Express function. Mint test tokens via the auth-emulator REST endpoint; run with `firebase emulators:exec --only auth,firestore,functions 'jest --runInBand'`. Set `engines.node` to `"20"` (locked) but surface to the user that Firebase recommends **22**.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| HTTP routing / method+path dispatch | Express app (inside `api` function) | — | Single deployable; `/:tripId` + method routing belong in Express |
| Token verification | API / Cloud Function (`firebase-admin/auth`) | — | Server-only; never trust client |
| Input validation | API / Cloud Function (zod) | — | Validate at handler entry, server-side |
| Ownership enforcement | API / Cloud Function | — | Server forces `userId = uid` |
| Persistence (trips) | Firestore (via Admin SDK) | — | Backup store; client never reads/writes directly |
| Access control on raw store | Firestore Security Rules | — | Deny-all; defense-in-depth |
| ID-token issuance | Firebase Auth (client, Phase 9) | — | Out of scope; consumed as `Authorization: Bearer` |

## Standard Stack

### Core (production dependencies) — versions VERIFIED 2026-06-01
| Package | Latest (npm) | Pin | Purpose | Notes |
|---------|--------------|-----|---------|-------|
| `firebase-functions` | **7.2.5** | `^7.2.5` | v2 HTTPS trigger (`onRequest`, `setGlobalOptions`) | `[VERIFIED: npm]` `engines.node >=18`; peer `firebase-admin ^11.10 \|\| ^12 \|\| ^13`. v2 modular import `firebase-functions/v2/https`. |
| `firebase-admin` | **13.10.0** | `^13.10.0` | Firestore + Auth Admin SDK | `[VERIFIED: npm]` Satisfies the v7 functions peer. Node 18/20 **deprecated**, 22+ recommended. |
| `express` | **5.2.1** | `^5.2.1` (or `^4.21` for example-parity) | HTTP routing under single function | `[VERIFIED: npm]` Named params `/:tripId` unchanged in v5; only `*` wildcard syntax changed. Either major works for this design — see note. |
| `zod` | **4.4.3** | `^4.4.3` | Input validation + inferred TS types | `[VERIFIED: npm]` `.safeParse`/`.parse`/`z.infer`/`z.object`/`.max()` API used below is stable from v3→v4. |

> **Express 4 vs 5 decision (planner picks; either is fine):** The locked routes use only named params, which behave identically in both. Pick **Express 5** to match the current registry default and `@types/express` 5, OR **Express 4** if you want maximum parity with older Firebase tutorials. If you pin Express 4, also pin `@types/express ^4`. Do NOT mix Express 5 runtime with `@types/express 4`.

### Dev dependencies — versions VERIFIED 2026-06-01
| Package | Latest (npm) | Pin | Purpose |
|---------|--------------|-----|---------|
| `typescript` | **6.0.3** | `^5.x` recommended (see note) | Strict compile |
| `firebase-tools` | **15.19.0** | global already installed | CLI: emulators, deploy, init |
| `jest` | **30.4.2** | `^30.4.2` | Test runner (recommended) |
| `ts-jest` | **29.4.11** | `^29.4.11` | TS transform for Jest |
| `@types/jest` | **30.0.0** | `^30.0.0` | Jest types (match jest major) |
| `@types/express` | **5.0.6** | match Express major | Express types |
| `supertest` | **7.2.2** | `^7.2.2` | In-process HTTP assertions vs the Express app |
| `@types/supertest` | **7.2.0** | `^7.2.0` | supertest types |
| `firebase-functions-test` | **3.5.0** | optional | Not needed for emulator-based tests; listed for awareness |
| ESLint + Firebase config | scaffold default | — | Lint (D-03) |

> **TypeScript version caution:** registry latest is **6.0.3**, but `ts-jest 29.4.11` and the Firebase scaffold's eslint/tsconfig were validated against the **TS 5.x** line. **Recommendation: pin `typescript ^5.x`** (whatever `firebase init functions` installs — currently the 5.x it scaffolds) to avoid TS6/ts-jest/eslint-parser churn. Only move to TS 6 if `ts-jest` and `@typescript-eslint` confirm support. `[VERIFIED: npm latest=6.0.3; compatibility caution from ts-jest peer range]`

**Test runner recommendation (resolves D-15): use Jest + ts-jest.**
- It is the **`firebase init functions` TypeScript scaffold default** — least friction, generated config, matches every Firebase example. Firebase scaffolds to **CommonJS**.
- vitest (4.1.7) works and is faster, but choosing it means fighting ESM/CJS interop with the CJS scaffold. Not worth it for 3 endpoints.
- `[VERIFIED: npm]` jest 30 / ts-jest 29.4.11 are mutually compatible (ts-jest 29.4 supports jest 30).

### Alternatives Considered (rejected by locked decisions)
| Instead of | Could Use | Why rejected |
|------------|-----------|--------------|
| Single Express `api` fn | 3 separate `onRequest` exports | D-04 locked single-fn Express |
| Top-level `trips/{uuid}` | `users/{uid}/trips/{id}` subcollection | D-09 — no security benefit (deny-all), adds nesting |
| Jest | vitest | CJS scaffold friction |
| `firebase-functions-test` SDK | emulator + real HTTP | Need real `verifyIdToken` + Firestore → emulator (D-14/15) |

**Installation (inside `backend/functions/` after `firebase init functions`):**
```bash
# Production
npm install firebase-functions@^7.2.5 firebase-admin@^13.10.0 express@^5.2.1 zod@^4.4.3
# Dev
npm install -D jest@^30.4.2 ts-jest@^29.4.11 @types/jest@^30.0.0 \
  @types/express@^5.0.6 supertest@^7.2.2 @types/supertest@^7.2.0
# typescript (^5.x), eslint, firebase config come from the scaffold
```

**Re-verify at scaffold (versions move; confirm before committing pins):**
```bash
for p in firebase-functions firebase-admin express zod typescript jest ts-jest supertest; do \
  echo "$p=$(npm view $p version)"; done
node --version && npm --version && firebase --version && java -version
```

## Architecture Patterns

### System Architecture Diagram

```
Flutter client (Phase 11)                          backend/  (this phase)
  http POST/DELETE/GET                              ┌─────────────────────────────────────────┐
  Authorization: Bearer <Firebase ID token>        │  Cloud Function "api" (2nd gen, Node 20)  │
        │                                           │   us-central1                             │
        ▼                                           │   ┌─────────── Express app ───────────┐  │
  HTTPS  ───────────────────────────────────────►  │   │ JSON body parsed (firebase-functions│  │
                                                    │   │ on real path / express.json() for   │  │
                                                    │   │ supertest — see Pitfall 2)          │  │
                                                    │   │  POST   /trips/sync    ─┐           │  │
                                                    │   │  DELETE /trips/:tripId ─┤ route to  │  │
                                                    │   │  GET    /trips/restore ─┘ handler   │  │
                                                    │   └───────────────┬─────────────────────┘ │
                                                    │                   ▼ (each handler)         │
                                                    │   1. verifyIdToken(Bearer) ──fail──► 401   │
                                                    │   2. zod.safeParse(body/params) fail► 400  │
                                                    │   3. force userId = token.uid              │
                                                    │   4. Firestore op via Admin SDK            │
                                                    └───────────────────┬───────────────────────┘
                                                                        ▼ Admin SDK (bypasses rules)
                                                        ┌────────────────────────────────────────┐
                                                        │ Firestore  collection "trips"           │
                                                        │   doc id = trip UUID                     │
                                                        │   FirestoreDataConverter<Trip>           │
                                                        │   rules: allow read,write: if false      │
                                                        └────────────────────────────────────────┘

Per endpoint:
  sync    → batch set(merge) chunks ≤500 → {syncedIds}
  delete  → get(doc) → ownership check → update(deleted:true, deletedAt:serverTimestamp)
  restore → query where(userId==uid, deleted==false) → Trip[]
```

### Recommended Project Structure
```
backend/
├── firebase.json            # functions + firestore + emulators (D-14)
├── .firebaserc              # default project travey-298a7 (D-01)
├── firestore.rules          # deny-all (D-13)
└── functions/
    ├── package.json         # engines.node "20"; main; build/serve/deploy/test scripts
    ├── tsconfig.json        # strict; outDir lib; rootDir src
    ├── tsconfig.dev.json    # scaffold default
    ├── .eslintrc.js         # scaffold default
    ├── jest.config.js       # ts-jest preset
    └── src/
        ├── index.ts                 # initializeApp(); Express app; export const api = onRequest(app)
        ├── handlers/
        │   ├── sync-trips.ts        # POST /trips/sync   (BACK-02)
        │   ├── delete-trip.ts       # DELETE /trips/:tripId (BACK-03)
        │   └── restore-trips.ts     # GET /trips/restore (BACK-04)
        ├── utils/
        │   ├── auth.ts              # verifyBearer(req) -> DecodedIdToken | throws AuthError
        │   ├── firestore.ts         # tripConverter, tripsCollection()
        │   ├── validation.ts        # zod schemas (tripSchema, syncBodySchema, tripIdParam)
        │   └── respond.ts           # send(res, statusCode, {data?|error?}) — D-06 shape
        ├── types/
        │   └── trip.ts              # shared Trip TS type (contract w/ Phase 11) ← z.infer
        └── __tests__/
            ├── helpers/emulator-token.ts   # mint ID token vs auth emulator
            ├── sync-trips.test.ts
            ├── delete-trip.test.ts
            └── restore-trips.test.ts
```

### Pattern 1: `index.ts` — Express under a single v2 `onRequest`
```typescript
// Source: Firebase HTTP functions + Express integration (CITED: firebase.google.com/docs/functions/http-events)
import {onRequest} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";
import {initializeApp} from "firebase-admin/app";
import express from "express";

import {syncTrips} from "./handlers/sync-trips";
import {deleteTrip} from "./handlers/delete-trip";
import {restoreTrips} from "./handlers/restore-trips";

initializeApp();                          // no args: ADC in prod; emulator hosts via env in tests
setGlobalOptions({region: "us-central1"}); // D-02

export const app = express();             // export so supertest can hit it in-process
app.use(express.json());                  // see Pitfall 2 — required for supertest; near-no-op on real path
app.post("/trips/sync", syncTrips);
app.delete("/trips/:tripId", deleteTrip);  // named param — unchanged in Express 4 AND 5
app.get("/trips/restore", restoreTrips);

// Single deployable. Prod URL (2nd gen Cloud Run-backed):
//   https://api-<hash>-uc.a.run.app/trips/sync   (or the cloudfunctions.net alias)
export const api = onRequest(app);
```

### Pattern 2: Auth util — `utils/auth.ts` (verify FIRST, D-07)
```typescript
// Source: firebase-admin Auth (CITED: firebase.google.com/docs/auth/admin/verify-id-tokens)
import {getAuth} from "firebase-admin/auth";
import type {Request} from "express";
import type {DecodedIdToken} from "firebase-admin/auth";

export class AuthError extends Error {}

export async function verifyBearer(req: Request): Promise<DecodedIdToken> {
  const header = req.get("authorization") ?? "";
  const match = /^Bearer (.+)$/.exec(header);
  if (!match) throw new AuthError("Missing or malformed Authorization header");
  try {
    return await getAuth().verifyIdToken(match[1]); // accepts emulator tokens when FIREBASE_AUTH_EMULATOR_HOST set
  } catch {
    throw new AuthError("Invalid or expired token"); // never echo underlying error/token
  }
}
```

### Pattern 3: Typed `FirestoreDataConverter<Trip>` — `types/trip.ts` + `utils/firestore.ts`
```typescript
// types/trip.ts — cross-phase contract (mirror Drift trips_table.dart)
import {Timestamp, FieldValue} from "firebase-admin/firestore";

export interface Trip {
  id: string;
  userId: string;
  startTime: string;          // ISO 8601 UTC string (D-10)
  endTime: string;            // ISO 8601 UTC string
  durationSeconds: number;
  distanceMeters: number;
  routePolyline: string | null;
  direction: string;          // "to_office" | "to_home"
  timeMovingSeconds: number;
  timeStuckSeconds: number;
  isManualEntry: boolean;
  createdAt: string;          // ISO 8601 UTC string
  updatedAt: string;          // ISO 8601 UTC string
}

// On-read shape: Trip + resolved server metadata (D-10)
export interface TripDoc extends Trip {
  deleted: boolean;
  deletedAt: Timestamp | null;
  serverUpdatedAt: Timestamp;
}

// On-write shape: serverUpdatedAt / deletedAt may be FieldValue sentinels.
// Use this (NOT `any`/`never`) to satisfy strict TS — resolves Pitfall 7.
export type TripWrite = Omit<TripDoc, "serverUpdatedAt" | "deletedAt"> & {
  serverUpdatedAt: FieldValue;
  deletedAt: FieldValue | Timestamp | null;
};
```
```typescript
// utils/firestore.ts
// Source: Admin SDK FirestoreDataConverter (CITED: firebase.google.com/docs/firestore/manage-data/add-data#custom_objects)
import {getFirestore, FirestoreDataConverter, QueryDocumentSnapshot} from "firebase-admin/firestore";
import type {TripDoc} from "../types/trip";

export const tripConverter: FirestoreDataConverter<TripDoc> = {
  toFirestore: (t) => t,
  fromFirestore: (snap: QueryDocumentSnapshot) => snap.data() as TripDoc,
};

export const tripsCollection = () =>
  getFirestore().collection("trips").withConverter(tripConverter);
```

### Pattern 4: Full handler — `handlers/sync-trips.ts` (verify → validate → trust → write, D-07/08/12)
```typescript
// Source: composed from Admin SDK batched-writes (CITED: firebase.google.com/docs/firestore/manage-data/transactions#batched-writes)
import type {Request, Response} from "express";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {verifyBearer, AuthError} from "../utils/auth";
import {syncBodySchema} from "../utils/validation";
import {tripsCollection} from "../utils/firestore";
import type {TripWrite} from "../types/trip";

const BATCH_LIMIT = 500; // D-12

export async function syncTrips(req: Request, res: Response): Promise<void> {
  // 1. VERIFY (D-07)
  let uid: string;
  try { uid = (await verifyBearer(req)).uid; }
  catch (e) {
    res.status(401).json({error: e instanceof AuthError ? e.message : "Unauthorized"});
    return;
  }
  // 2. VALIDATE (D-07) — safeParse, never throw to client
  const parsed = syncBodySchema.safeParse(req.body);
  if (!parsed.success) { res.status(400).json({error: "Invalid request body"}); return; }

  // 3. TRUST — force ownership (D-08), chunk batches (D-12)
  const db = getFirestore();
  const col = tripsCollection();
  const trips = parsed.data.trips;
  const syncedIds: string[] = [];

  for (let i = 0; i < trips.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const t of trips.slice(i, i + BATCH_LIMIT)) {
      const write: TripWrite = {
        ...t,
        userId: uid,                              // overwrite any client userId (D-08)
        deleted: false,                           // re-synced trip resurfaces (D-11)
        deletedAt: null,
        serverUpdatedAt: FieldValue.serverTimestamp(),
      };
      batch.set(col.doc(t.id), write as unknown as Parameters<typeof batch.set>[1], {merge: true});
      syncedIds.push(t.id);
    }
    await batch.commit();                         // atomic per chunk
  }
  res.status(200).json({data: {syncedIds}});      // D-06
}
```
> Typing note: `TripWrite` (Pattern 3) keeps this `any`-free. The `as unknown as ...` on `batch.set` only bridges the converter's `WithFieldValue` typing; planner may instead drop the converter on writes and use a plain `getFirestore().collection("trips").doc(id)` typed via `TripWrite`. Either path avoids `any`. **Final code must contain no `any`** (CLAUDE.md). See Open Q5.

### Pattern 5: Delete handler core (ownership read-check, D-08/D-11)
```typescript
import {tripIdParam} from "../utils/validation";
// uid already obtained via verifyBearer
const idParse = tripIdParam.safeParse(req.params.tripId);
if (!idParse.success) { res.status(400).json({error: "Invalid trip id"}); return; }

const ref = tripsCollection().doc(idParse.data);
const snap = await ref.get();
if (!snap.exists || snap.data()!.userId !== uid) {
  res.status(404).json({error: "Not found"}); return;   // 404 (not 403) — don't leak existence
}
await ref.update({
  deleted: true,
  deletedAt: FieldValue.serverTimestamp(),
  serverUpdatedAt: FieldValue.serverTimestamp(),
});
res.status(200).json({data: {id: ref.id}});
```

### Pattern 6: Restore handler core (D-08/D-11)
```typescript
const snap = await tripsCollection()
  .where("userId", "==", uid)
  .where("deleted", "==", false)
  .get();
const trips = snap.docs.map((d) => {
  const {deleted, deletedAt, serverUpdatedAt, ...trip} = d.data(); // strip server metadata → pure Trip
  return trip;
});
res.status(200).json({data: {trips}});
```

### Pattern 7: `firestore.rules` (D-13)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;   // Admin SDK only; clients fully denied
    }
  }
}
```

### Pattern 8: `backend/firebase.json` (D-01/D-13/D-14)
```json
{
  "functions": {
    "source": "functions",
    "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"]
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "emulators": {
    "auth": {"port": 9099},
    "functions": {"port": 5001},
    "firestore": {"port": 8080},
    "ui": {"enabled": true, "port": 4000},
    "singleProjectMode": true
  }
}
```
> Ship a `firestore.indexes.json` (even `{"indexes":[],"fieldOverrides":[]}`) so the indexes target exists. The restore query (`userId ==` + `deleted ==`) is **two equality filters** — these are often serviceable by single-field indexes, but Firestore can still demand a composite index in prod. Plan to verify against real Firestore and add the composite index if demanded (the error gives the exact index-creation URL). See Pitfall 5 / Open Q3.

### Pattern 9: zod schemas — `utils/validation.ts` (mirror Drift fields)
```typescript
import {z} from "zod";

export const tripSchema = z.object({
  id: z.string().uuid(),
  // userId intentionally NOT required from client — server forces it (D-08).
  startTime: z.string().datetime(),     // ISO 8601 UTC
  endTime: z.string().datetime(),
  durationSeconds: z.number().int().nonnegative(),
  distanceMeters: z.number().nonnegative(),
  routePolyline: z.string().nullable(),
  direction: z.enum(["to_office", "to_home"]),
  timeMovingSeconds: z.number().int().nonnegative(),
  timeStuckSeconds: z.number().int().nonnegative(),
  isManualEntry: z.boolean(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
});

export const syncBodySchema = z.object({
  trips: z.array(tripSchema).min(1).max(1000),   // .max caps DoS (Open Q4)
});

export const tripIdParam = z.string().uuid();
```
> Note: client sends camelCase JSON matching this schema (the Phase 11 `api_client` contract). The Drift table stores camelCase Dart identifiers → snake_case SQL; the **JSON over the wire is camelCase** to match `types/trip.ts`. Lock this with Phase 11. If the client instead sends `userId`, the server ignores it (D-08) — keep `userId` out of the required schema or `.strip()` it.

### Anti-Patterns to Avoid
- **Shared auth middleware that mutates `req`, then handlers "trust" it.** D-05/CLAUDE.md require verify→validate→trust *inside each handler*. Keep `verifyBearer(req)` as the first call in every handler.
- **403 on cross-user delete.** Use **404** to avoid leaking that another user's trip exists (D-08 permits 404/403 — pick 404).
- **`cloud_firestore` SDK in the Flutter client.** Forbidden; REST only.
- **Hard delete.** Soft delete only (D-11).
- **Echoing token/stack traces in error bodies.** D-06.
- **`any` / `as never` in final code.** Use `TripWrite` (Pattern 3). CLAUDE.md forbids `any`.
- **Mixing Express 5 runtime with `@types/express` 4** (or vice versa).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ID-token verification | Custom JWT/JWKS parse + signature check | `getAuth().verifyIdToken()` | Key rotation, revocation, clock skew, emulator mode |
| Path/method routing | Manual `if (req.method===...)` + URL parse | Express routes | `/:tripId` extraction, method dispatch (D-04) |
| Input validation | Manual `typeof` checks | zod `.safeParse` + `z.infer` | Type-safe; generates `Trip` type; CLAUDE.md mandate |
| Atomic multi-write | Sequential `await set()` loop | `db.batch()` chunked ≤500 | Atomicity per chunk; fewer round-trips; 500 limit (D-12) |
| Server timestamps | `new Date()` on function host | `FieldValue.serverTimestamp()` | Authoritative server clock (D-10) |
| Test token minting | Self-sign a JWT | Auth-emulator REST exchange (below) | Produces a token `verifyIdToken` accepts in emulator mode |

**Key insight:** Every hard part (token verify, atomic writes, server time) is a first-party Admin SDK primitive. Bespoke code is just glue: Express wiring, zod schemas mirroring the Drift table, the response helper.

## Emulator Testing — the token-mint technique (the one tricky bit)

When `FIREBASE_AUTH_EMULATOR_HOST` is set, `getAuth().verifyIdToken()` **skips signature verification** and accepts tokens issued by the auth emulator (`[VERIFIED: web — firebase.google.com/docs/emulator-suite/connect_auth]`: "Firebase Admin SDKs accept unsigned ID Tokens issued by the Authentication emulator via verifyIdToken when FIREBASE_AUTH_EMULATOR_HOST is set"). Tests must therefore obtain a real emulator-issued ID token.

**Approach A (recommended) — Admin custom token → emulator REST exchange (lets you control the uid, needed for ownership tests):**
```typescript
// helpers/emulator-token.ts
// Source: auth emulator REST + signInWithCustomToken (CITED: firebase.google.com/docs/emulator-suite/connect_auth)
import {getAuth} from "firebase-admin/auth";

const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST!; // e.g. "127.0.0.1:9099"
const PROJECT = process.env.GCLOUD_PROJECT ?? "travey-298a7";

export async function mintIdToken(uid: string): Promise<string> {
  const customToken = await getAuth().createCustomToken(uid);
  const url =
    `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key`;
  const resp = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({token: customToken, returnSecureToken: true}),
  });
  if (!resp.ok) throw new Error(`emulator token mint failed: ${resp.status}`);
  const {idToken} = (await resp.json()) as {idToken: string};
  return idToken; // verifyIdToken accepts this while emulator host is set
}
```

**Approach B — direct emulator sign-up** (`POST accounts:signUp?key=fake-api-key` with `{returnSecureToken:true}`) returns a fresh uid (`localId`) + idToken in one call. Use when you don't care about the specific uid; for ownership tests prefer A.

> **Known gotcha** (`[VERIFIED: web — firebase-tools issue #5821, #2764]`): emulator ID tokens historically failed `verifyIdToken()` with *"no 'kid' claim"* **only when called outside an emulator-aware context** (e.g. `FIREBASE_AUTH_EMULATOR_HOST` not set in the verifying process). Ensure the SAME process that runs the handlers has `FIREBASE_AUTH_EMULATOR_HOST` set **before** `initializeApp()`. Running tests under `firebase emulators:exec` sets these for you.

**Test setup (Jest) — connect Admin SDK to emulators BEFORE importing index:**
```typescript
// e.g. a setup file referenced by jest.config.js `setupFiles`
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "travey-298a7"; // singleProjectMode (D-14)
// THEN, inside the test: import {app} from "../index"; (env is read at initializeApp)
```

**Running tests:**
```bash
# package.json: "test": "firebase emulators:exec --only auth,firestore,functions 'jest --runInBand'"
cd backend/functions && npm test
```
`emulators:exec` starts the suite, runs the command, tears down, and injects the `*_EMULATOR_HOST` env. `--runInBand` avoids Firestore state races; alternatively clear Firestore between tests via the emulator REST `DELETE /emulator/v1/projects/{p}/databases/(default)/documents`.

**Driving endpoints — two options (both satisfy D-15):**
1. **supertest against the exported `app`** (fast, in-process): `await request(app).post('/trips/sync').set('Authorization', 'Bearer '+token).send({trips})`. Requires `express.json()` mounted (Pitfall 2) because supertest bypasses the functions parser.
2. **fetch against the functions emulator** (true E2E): `http://127.0.0.1:5001/travey-298a7/us-central1/api/trips/sync`.
> Recommendation: **supertest + `express.json()`** for the bulk of assertions, plus optionally one fetch smoke per endpoint.

## Common Pitfalls

### Pitfall 1: Auth emulator token rejected by `verifyIdToken`
**What goes wrong:** Tests self-sign a JWT / use a random string → `verifyIdToken` throws (`auth/argument-error`, or "no 'kid' claim").
**Why:** Even in emulator mode the token must be issued by the auth emulator, and the verifying process must have `FIREBASE_AUTH_EMULATOR_HOST` set before `initializeApp()`.
**How to avoid:** Mint via Approach A/B. Set the env first; run under `emulators:exec`.
**Warning sign:** `Decoding Firebase ID token failed` / `no 'kid' claim`.

### Pitfall 2: Express body parsing — `onRequest` vs supertest
**What goes wrong:** Omitting `express.json()` → `req.body` undefined under supertest; or worrying about double-parse on the real path.
**Why:** `firebase-functions` parses JSON onto `req.body` on the real `onRequest` path; supertest calls Express directly and does NOT.
**How to avoid:** Mount `express.json()` (Pattern 1). It makes supertest work and is effectively a no-op on already-populated bodies. Verify once with a real-emulator fetch.
**Warning sign:** Handler sees `undefined` body in tests but works deployed.

### Pitfall 3: Cold start latency (2nd gen)
**What goes wrong:** First request after idle is slow (Node + Admin SDK init).
**Why:** Functions scale to zero.
**How to avoid:** `initializeApp()` once at module top (not per request). For v0.1 background sync this is acceptable (client is fire-and-forget per architecture). Do NOT set `minInstances` (cost). Note for Phase 11: client must tolerate first-call latency.

### Pitfall 4: `/trips/:tripId` routing / method mismatch
**What goes wrong:** DELETE to `/trips/abc` 404s, or a static path hits the param route.
**Why:** Route/method confusion.
**How to avoid:** Static routes (`post /trips/sync`, `get /trips/restore`) and the param route (`delete /trips/:tripId`) are disambiguated by HTTP method — order doesn't matter here. Named params work identically in Express 4 and 5 (`[VERIFIED: web]`). Only Express 5's `*` wildcard changed — not used here.
**Warning sign:** Unexpected 404 on a valid path+method.

### Pitfall 5: Composite index for the restore query
**What goes wrong:** `where('userId','==').where('deleted','==')` errors in prod with "query requires an index".
**Why:** Firestore may require a composite index; the emulator is more lenient than prod.
**How to avoid:** Test the query against **real** Firestore before declaring done, or proactively add the composite index to `firestore.indexes.json` and deploy `--only firestore:indexes`. The prod error includes the exact index-creation URL.
**Warning sign:** `FAILED_PRECONDITION: The query requires an index` — only surfaces in prod, not the emulator.

### Pitfall 6: Deploy ordering (functions vs rules) + provisioning
**What goes wrong:** Functions deploy but rules don't (Firestore left open), or Firestore DB isn't provisioned at all.
**Why:** Separate deploy targets; Firestore Native DB must exist in the project.
**How to avoid:** From `backend/`: `firebase deploy --only functions,firestore:rules`. Ensure the Firestore (Native mode) database exists in `travey-298a7` first (console or `firebase firestore:databases:create`). Order between functions and rules doesn't matter, but deploy rules so deny-all is live.
**Warning sign:** Console shows missing deny-all rules, or deploy errors "Firestore database not found".

### Pitfall 7: `FieldValue.serverTimestamp()` + converter typing (no `any`)
**What goes wrong:** Write-time `FieldValue` sentinel vs read-time `Timestamp` field type → TS error; tempting `as any`.
**How to avoid:** Use the `TripWrite` interface (Pattern 3) / `WithFieldValue<TripDoc>`. CLAUDE.md forbids `any`.
**Warning sign:** Type errors around `set()`/`update()` payloads.

### Pitfall 8: `singleProjectMode` + project id mismatch
**What goes wrong:** Emulator project id ≠ Admin SDK project id → data invisible / token aud mismatch.
**How to avoid:** `GCLOUD_PROJECT=travey-298a7` in test env; `.firebaserc` default = same; `singleProjectMode:true`.

### Pitfall 9: Wrong `engines.node` blocks deploy
**What goes wrong:** Setting `engines.node` to local Node (25) → deploy rejected ("unsupported runtime").
**Why:** Only Node 20/22/24 are accepted runtimes (`[VERIFIED: web — firebase.google.com/docs/functions/manage-functions]`); 18 deprecated, 14/16 decommissioned.
**How to avoid:** `engines.node: "20"` (locked D-02) or `"22"` (recommended). Local Node 25 still builds/tests fine; the runtime pin is independent of the local interpreter.

## Runtime State Inventory

> Greenfield backend — no pre-existing runtime state to migrate. Included because Phase 10 deploys live infrastructure.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — Firestore `trips` collection doesn't exist yet; created on first write. | None |
| Live service config | Firebase project `travey-298a7` exists (Phase 9 Auth). This phase ADDS Functions + Firestore + rules. Firestore (Native mode) DB must be **provisioned** before first prod deploy. | Verify/create Firestore Native DB; deploy functions + rules |
| OS-registered state | None | None |
| Secrets/env vars | No new secrets for v0.1 (deployed functions use ADC; no server-side API keys). | None |
| Build artifacts | `backend/functions/lib/` (TS output) + `node_modules/` will be generated. | Ensure both gitignored (scaffold `.gitignore` does this) |

**Verified:** `backend/` directory does not exist (greenfield). Repo-root `firebase.json` is the FlutterFire app config (projectId `travey-298a7`); there is **no root `.firebaserc`**. Do NOT modify root `firebase.json` (D-01).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | build + test (local) | ✓ | **v25.2.1** (local) | — (runtime pin is 20/22, independent) |
| npm | install deps | ✓ | **11.12.1** | — |
| firebase CLI | emulators, deploy, init | ✓ | **15.19.0** (`/opt/homebrew/bin/firebase`) | — |
| Java JDK | Firestore + Auth emulators (JVM processes) | UNVERIFIED (probe not run) | — | install Temurin/OpenJDK 11+ |
| Firebase project `travey-298a7` | deploy target | ✓ (Phase 9 used it) | — | — |
| Firestore (Native mode) provisioned | sync/delete/restore in prod | UNKNOWN — likely NOT yet created | — | Create in console / `firebase firestore:databases:create` |
| Node 20 or 22 runtime acceptance | deploy | ✓ (20 supported, deprecated; 22 recommended) | — | use 22 if 20 rejected |

**Action items for planner's environment-setup task:**
- **`java -version`** — emulators are Java; install JDK if missing (the one un-probed dependency).
- **Provision Firestore (Native mode)** in `travey-298a7` before live deploy (success criteria 1–3 fail in prod without it).
- Confirm `engines.node` = `"20"` deploys cleanly; if Firebase warns/blocks, surface the Node 22 recommendation to the user (Open Q2).

## Validation Architecture

> nyquist_validation = true → section included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Jest 30.4.2 + ts-jest 29.4.11 (`[VERIFIED: npm]`; Firebase scaffold default) |
| Config file | `backend/functions/jest.config.js` — **does not exist (Wave 0)** |
| Quick run command | `cd backend/functions && jest <file> --runInBand` (inside a running emulator) |
| Full suite command | `cd backend/functions && npm test` → `firebase emulators:exec --only auth,firestore,functions 'jest --runInBand'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BACK-02 | sync no token → 401 | integration (emulator) | `jest sync-trips.test.ts -t "rejects missing token"` | ❌ Wave 0 |
| BACK-02 | sync invalid token → 401 | integration | `jest sync-trips.test.ts -t "rejects invalid token"` | ❌ Wave 0 |
| BACK-02 | sync valid token → 200 + docs written, userId forced | integration | `jest sync-trips.test.ts -t "happy path"` | ❌ Wave 0 |
| BACK-02 | sync idempotent (re-send safe) | integration | `jest sync-trips.test.ts -t "idempotent"` | ❌ Wave 0 |
| BACK-03 | delete no/invalid token → 401 | integration | `jest delete-trip.test.ts -t "auth reject"` | ❌ Wave 0 |
| BACK-03 | delete sets deleted:true | integration | `jest delete-trip.test.ts -t "soft delete"` | ❌ Wave 0 |
| BACK-03 | user A cannot delete B's trip → 404 | integration (ownership) | `jest delete-trip.test.ts -t "ownership"` | ❌ Wave 0 |
| BACK-04 | restore no/invalid token → 401 | integration | `jest restore-trips.test.ts -t "auth reject"` | ❌ Wave 0 |
| BACK-04 | restore returns only non-deleted for uid | integration | `jest restore-trips.test.ts -t "happy path"` | ❌ Wave 0 |
| BACK-04 | restore excludes other users' / deleted trips | integration (ownership) | `jest restore-trips.test.ts -t "ownership"` | ❌ Wave 0 |
| (rules) | deny-all blocks direct client read/write | optional (`@firebase/rules-unit-testing`) | — | ❌ optional |

### Sampling Rate
- **Per task commit:** the handler's test file via `jest <file> --runInBand` (inside emulator).
- **Per wave merge:** full `npm test` (emulators:exec + jest).
- **Phase gate:** full suite green + a live-deploy smoke (curl one endpoint with a real token) before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `backend/functions/jest.config.js` — ts-jest preset + `setupFiles` for emulator env
- [ ] `backend/functions/src/__tests__/helpers/emulator-token.ts` — `mintIdToken(uid)`
- [ ] `backend/functions/src/__tests__/sync-trips.test.ts` — BACK-02
- [ ] `backend/functions/src/__tests__/delete-trip.test.ts` — BACK-03
- [ ] `backend/functions/src/__tests__/restore-trips.test.ts` — BACK-04
- [ ] Framework install: `npm i -D jest@^30 ts-jest@^29.4 @types/jest@^30 supertest@^7 @types/supertest@^7`
- [ ] Emulator env bootstrap (set `*_EMULATOR_HOST` + `GCLOUD_PROJECT` before importing index)

## Security Domain

> security_enforcement absent in config → enabled. Backend phase → in scope.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Firebase ID-token verification (`verifyIdToken`) at every handler entry (D-07) |
| V3 Session Management | no (stateless) | Short-lived JWTs; expiry via `verifyIdToken`; no server session |
| V4 Access Control | yes | Server-forced ownership (D-08): `userId = uid`; delete read-check; restore filter |
| V5 Input Validation | yes | zod `.safeParse` at handler entry (D-07) → 400 |
| V6 Cryptography | no (delegated) | No custom crypto; Firebase/Admin SDK handle JWT signing/verification |
| V7 Error/Logging | yes | No stack traces/tokens in responses (D-06); log server-side only |
| V13 API/Web Service | yes | REST over HTTPS; deny-all Firestore rules (D-13); CORS — see note |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-user write (client sets foreign userId) | Tampering / Elevation | Server overwrites `userId` with token uid (D-08) |
| Cross-user delete/restore | Elevation / Info disclosure | Ownership read-check (404, not 403) |
| Forged / replayed token | Spoofing | `verifyIdToken` (signature, exp, revocation) |
| Direct Firestore access bypassing functions | Tampering | Deny-all rules (D-13) — Admin SDK only |
| Malformed trip fields | Tampering | zod typed validation (Firestore is not SQL — no injection sink, but validate shapes) |
| Info disclosure via errors | Info disclosure | Generic error bodies; no stack/token echo (D-06) |
| DoS via huge sync batch | DoS | Chunk ≤500 (D-12) + zod `.max(1000)` on the array (Open Q4) |

**CORS note:** `[VERIFIED: reasoning]` The client is the native Flutter `http` package, **not a browser** — CORS is browser-origin enforcement and does not apply to native mobile requests. No CORS config needed for v0.1 (Android-only). If a web origin ever calls the API, add the `cors` option to `onRequest` or `cors` middleware (out of scope).

## Assumptions Log

> Most prior assumptions were RESOLVED by live `npm view` + web search this session. Remaining items:

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Java JDK is installed (emulators need a JVM) — NOT probed this session | Environment | Medium — `emulators:start` fails without it; planner must run `java -version` |
| A2 | Firestore (Native mode) DB not yet provisioned in `travey-298a7` | Environment / Runtime State | Medium — must create before live deploy; blocks prod success criteria 1–3 if missing |
| A3 | Node 20 still deploys cleanly mid-2026 (supported but deprecated) | Pitfall 9 / Open Q2 | Low — verified supported; if Firebase blocks at deploy, bump to 22 and notify user (D-02 locks 20) |
| A4 | `pin typescript ^5.x` (not 6) for ts-jest/eslint compatibility | Standard Stack | Low-Med — TS6 latest exists but ts-jest 29.4 validated on TS5; use scaffold-installed TS |
| A5 | Restore two-equality query may need a composite index in prod | Pitfall 5 / Open Q3 | Medium — verify against real Firestore; add index if demanded |
| A6 | Auth-emulator `signInWithCustomToken` exchange works with `key=fake-api-key` | Emulator Testing | Low — documented + corroborated by firebase-tools issues; confirm exact response at first run |
| A7 | Over-the-wire JSON is camelCase (matches `types/trip.ts`), client omits `userId` | Pattern 9 | Low-Med — lock the payload contract with Phase 11 |

**Versions are VERIFIED** (npm registry, 2026-06-01): firebase-functions 7.2.5, firebase-admin 13.10.0, express 5.2.1, zod 4.4.3, typescript 6.0.3, firebase-tools 15.19.0, jest 30.4.2, ts-jest 29.4.11, @types/jest 30.0.0, @types/express 5.0.6, supertest 7.2.2, @types/supertest 7.2.0, firebase-functions-test 3.5.0.

## Open Questions

1. **Express 4 vs 5 (planner picks).** Both support the locked named-param routes identically. Default to 5 (current major + `@types/express 5`) unless tutorial-parity with v4 is preferred. Decide and keep `express` + `@types/express` on the same major.

2. **Node 20 vs 22 runtime.** D-02 locks **20** (supported but deprecated; Firebase/admin-SDK recommend **22**). Recommendation: deploy with 20 per the lock, but **surface to the user** that 22 is the recommended path — this is a locked decision, so the user should confirm before any change.

3. **Composite index for the restore query.** Two equality filters may or may not need a composite index in prod. Recommendation: ship `firestore.indexes.json`, run the query against real Firestore, and add/deploy the composite index if Firestore demands it (error URL provides it).

4. **Max trips per sync batch.** Chunking handles >500, but unbounded bodies are a DoS vector. Recommendation: `z.array(tripSchema).max(1000)` → 400 if exceeded. Confirm the bound with Phase 11 sync design.

5. **Converter/`FieldValue` write typing without `any`.** Pattern 3 supplies `TripWrite`; planner chooses converter-on-write (with a narrow bridging cast) vs. plain typed collection on writes. Final code must be `any`-free (CLAUDE.md).

6. **TypeScript major.** Pin TS 5.x (scaffold default) for ts-jest/eslint stability, or validate TS 6 with ts-jest/@typescript-eslint before adopting.

7. **Payload contract direction (camelCase JSON, `userId` omitted).** Lock the exact wire shape with Phase 11's `api_client`.

## Sources

### Primary (HIGH confidence)
- CONTEXT.md D-01..D-15, CLAUDE.md Backend/Cloud Functions Rules, REQUIREMENTS.md (BACK-02/03/04), ROADMAP.md Phase 10, `lib/database/tables/trips_table.dart`, repo-root `firebase.json` — read directly this session.
- npm registry (`npm view`, 2026-06-01) — all dependency versions VERIFIED.
- Firebase HTTP functions / Express integration — firebase.google.com/docs/functions/http-events `[CITED + web-corroborated]`
- Verify ID tokens — firebase.google.com/docs/auth/admin/verify-id-tokens `[CITED]`
- Connect to Auth Emulator (unsigned-token acceptance) — firebase.google.com/docs/emulator-suite/connect_auth `[VERIFIED: web]`
- Manage functions / runtime support (Node 20/22 supported, 18 deprecated) — firebase.google.com/docs/functions/manage-functions `[VERIFIED: web]`
- Batched writes (500 limit) — firebase.google.com/docs/firestore/manage-data/transactions#batched-writes `[CITED]`

### Secondary (MEDIUM)
- firebase-tools issues #5821 / #2764 (emulator token "no kid claim" gotcha context) `[VERIFIED: web]`
- firebase-admin release notes (Node 18/20 deprecation, 22 recommended) `[VERIFIED: web]`

### Tertiary (LOW)
- None relied upon for normative claims.

## Metadata

**Confidence breakdown:**
- Standard stack + versions: HIGH — locked by D-02/D-03 + CLAUDE.md; all versions verified against npm.
- Architecture / file layout / code patterns: HIGH — locked decisions + stable Firebase APIs; Express 5 named-param behavior verified.
- Emulator token-mint technique: HIGH on approach (documented + corroborated); confirm exact response payload at first run.
- Pitfalls: HIGH — well-known Firebase Functions gotchas directly relevant to the locked design.
- Environment: MEDIUM — Node/npm/CLI verified present; Java + Firestore provisioning unverified (flagged).

**Research date:** 2026-06-01
**Valid until:** ~2026-07-01 for versions (fast-moving npm); architecture stable ~6 months.
