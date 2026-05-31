# Phase 10: Backend Infrastructure - Research

**Researched:** 2026-06-01
**Domain:** Firebase Cloud Functions 2nd gen (TypeScript) + Firestore + Emulator-based testing
**Confidence:** HIGH on architecture/patterns (locked by CONTEXT.md + well-established Firebase APIs); MEDIUM on exact dependency version numbers (verify at scaffold — see Assumptions Log).

> **Tooling note:** Live `npm view` / web-search version confirmation could not complete in this research session (network calls returned empty). All version pins below are tagged `[ASSUMED]` from the Jan 2026 knowledge cutoff and listed in the Assumptions Log. The planner's first scaffold task MUST run `npm view <pkg> version` (or accept whatever `firebase init functions` installs) and pin the actual current versions. The **architecture, code patterns, and API surface are HIGH confidence** — Firebase Functions v2, Admin SDK, and the auth-emulator token trick are stable and unchanged for years.

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
- Commit prefix for this phase: `[backend]` / `[infra]`. (CLAUDE.md convention; GSD commit hook may override format — planner notes both.)
- Common command (CLAUDE.md): deploy via `firebase deploy --only functions` and `firebase deploy --only firestore:rules`.

---

## Summary

This is a greenfield, self-contained Firebase backend. Nothing exists under `backend/` yet (verified — directory absent). The phase stands up a `backend/` Firebase CLI project: one HTTPS Cloud Function (`api`, 2nd gen, Node 20) that mounts an Express app routing three REST endpoints to per-file handlers, each doing verify-token → zod-validate → Firestore write/read via a typed `FirestoreDataConverter`. Firestore is locked down with deny-all rules; only the Admin SDK (running inside the function) touches data. Tests run against the Firebase Emulator Suite, minting valid ID tokens against the **auth emulator** (which accepts unsigned tokens that `verifyIdToken` will accept when `FIREBASE_AUTH_EMULATOR_HOST` is set).

The entire stack is locked by D-01..D-15 and CLAUDE.md, so research is prescriptive, not exploratory: it confirms the stack with concrete (to-be-verified) versions, supplies exact file layout, and gives copy-ready code patterns for `index.ts`, the auth util, the Trip converter, one full handler (verify→validate→trust), and the emulator test that mints a token. The single non-obvious technique is the auth-emulator token mint — documented in detail below.

**Primary recommendation:** Scaffold with `firebase init functions` (TypeScript) inside `backend/`, take its default ESLint + tsconfig, **use Jest + ts-jest** (Firebase scaffold default; D-15 endorses), add Express + zod, and write all three handlers behind a single `api` Express function. Mint test tokens via the auth emulator REST endpoint, run tests with `firebase emulators:exec --only auth,firestore,functions 'jest'`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| HTTP routing / method+path dispatch | Express app (inside `api` function) | — | Single deployable; path-param `/:tripId` and method routing belong in Express, not in client or rules |
| Token verification | API / Cloud Function (`firebase-admin/auth`) | — | Never trust client; `verifyIdToken` is server-only |
| Input validation | API / Cloud Function (zod) | — | Validate at handler entry, server-side |
| Ownership enforcement | API / Cloud Function | — | Server forces `userId = uid`; client value is advisory at best |
| Persistence (trips) | Firestore (via Admin SDK) | — | Source-of-backup store; client never reads/writes it directly |
| Access control on raw store | Firestore Security Rules | — | Deny-all; defense-in-depth so even a leaked client can't touch Firestore |
| ID-token issuance | Firebase Auth (client side, Phase 9) | — | Out of scope here; consumed as `Authorization: Bearer` |

## Standard Stack

### Core (production dependencies)
| Package | Version (verify) | Purpose | Why Standard |
|---------|------------------|---------|--------------|
| `firebase-functions` | `^6.x` `[ASSUMED]` | v2 HTTPS trigger (`onRequest`, `setGlobalOptions`) | First-party; v2 is the current generation. v6 line was current at cutoff. |
| `firebase-admin` | `^13.x` `[ASSUMED]` | Firestore + Auth Admin SDK (`getFirestore`, `getAuth`, `FieldValue`, `Timestamp`) | First-party server SDK; bypasses rules as intended (D-13). |
| `express` | `^4.x` `[ASSUMED — see note]` | HTTP routing under single function | Standard v2 path-param REST pattern. **Note: pin Express 4, not 5** — Express 5 changed routing/path-matching and some middleware behavior; the well-trodden Firebase examples assume v4. Verify which the scaffold pulls. |
| `zod` | `^3.x` `[ASSUMED]` | Input validation + inferred TS types | CLAUDE.md mandates zod; `z.infer` gives the `Trip` type for free. **If `npm view zod version` shows 4.x, confirm API (`.parse`/`.safeParse` unchanged) before pinning 4.** |

### Dev dependencies
| Package | Version (verify) | Purpose |
|---------|------------------|---------|
| `typescript` | `^5.x` `[ASSUMED]` | Strict compile |
| `firebase-tools` | `^14.x` `[ASSUMED]` | CLI: emulators, deploy. Local-install preferred for reproducible CI, or global. |
| `jest` | `^29.x` `[ASSUMED]` | Test runner (recommended — see below) |
| `ts-jest` | `^29.x` `[ASSUMED]` | TS transform for Jest |
| `@types/jest` | `^29.x` `[ASSUMED]` | Jest types |
| `@types/express` | `^4.x` `[ASSUMED]` | Express types (match Express major) |
| `supertest` + `@types/supertest` | `^7.x` / `^6.x` `[ASSUMED]` | Optional: in-process HTTP assertions against the Express app |
| ESLint + Firebase config | scaffold default | Lint (D-03) |

**Test runner recommendation (resolves D-15 open choice): use Jest + ts-jest.**
- It is the **Firebase `firebase init functions` TypeScript scaffold default** — least friction, generated config, matches every Firebase example.
- vitest works too and has faster ESM/TS, but Firebase Functions scaffolds to **CommonJS** by default; choosing vitest means fighting ESM/CJS interop with `firebase-admin` and `firebase-functions`. Not worth it for a 3-endpoint backend.
- Rationale is HIGH confidence on the "scaffold default = Jest/CJS" fact; the speed delta is irrelevant at this test count.

### Alternatives Considered (all rejected by locked decisions — listed for completeness)
| Instead of | Could Use | Why rejected here |
|------------|-----------|-------------------|
| Single Express `api` fn | 3 separate `onRequest` exports | D-04 locked single-fn Express; cleaner path-param + one deployable |
| Top-level `trips/{uuid}` | `users/{uid}/trips/{id}` subcollection | D-09 rejected — no security benefit (rules deny-all), adds path nesting |
| Jest | vitest | CJS scaffold friction (above) |
| `firebase-functions-test` SDK | emulator + real HTTP | We need real `verifyIdToken` + Firestore behavior → emulator is the right level (D-14/D-15) |

**Installation (inside `backend/functions/` after `firebase init functions`):**
```bash
# Production
npm install firebase-functions firebase-admin express zod
# Dev
npm install -D jest ts-jest @types/jest @types/express supertest @types/supertest
# (typescript, eslint, firebase config come from the scaffold)
```

**Version verification (planner's FIRST task — required, versions above are unverified):**
```bash
for p in firebase-functions firebase-admin express zod typescript firebase-tools jest ts-jest; do \
  echo "$p=$(npm view $p version)"; done
```
Pin the actual output. Prefer whatever `firebase init functions` installs for `firebase-functions`/`firebase-admin`/`typescript`/eslint — that combination is guaranteed mutually compatible.

## Architecture Patterns

### System Architecture Diagram

```
Flutter client (Phase 11)                          backend/  (this phase)
  http POST/DELETE/GET                              ┌─────────────────────────────────────────┐
  Authorization: Bearer <Firebase ID token>        │  Cloud Function "api" (2nd gen, Node 20)  │
        │                                           │   us-central1                             │
        ▼                                           │   ┌─────────── Express app ───────────┐  │
  HTTPS  ───────────────────────────────────────►  │   │ JSON body already parsed by         │  │
                                                    │   │ firebase-functions (req.body ready) │  │
                                                    │   │                                     │  │
                                                    │   │  POST   /trips/sync    ─┐           │  │
                                                    │   │  DELETE /trips/:tripId ─┤ route to  │  │
                                                    │   │  GET    /trips/restore ─┘ handler   │  │
                                                    │   └───────────────┬─────────────────────┘ │
                                                    │                   ▼ (each handler)         │
                                                    │   1. verifyIdToken(Bearer) ──fail──► 401   │
                                                    │   2. zod.parse(body/params) ─fail──► 400   │
                                                    │   3. force userId = token.uid              │
                                                    │   4. Firestore op via Admin SDK            │
                                                    └───────────────────┬───────────────────────┘
                                                                        ▼ Admin SDK (bypasses rules)
                                                        ┌────────────────────────────────────────┐
                                                        │ Firestore  collection "trips"           │
                                                        │   doc id = trip UUID                     │
                                                        │   FirestoreDataConverter<Trip>           │
                                                        │   rules: allow read,write: if false      │
                                                        │   (clients blocked; only Admin SDK in)   │
                                                        └────────────────────────────────────────┘

Data flow per endpoint:
  sync    → batch set(merge) chunks ≤500 → {syncedIds}
  delete  → get(doc) → ownership check → update(deleted:true, deletedAt:serverTimestamp)
  restore → query where(userId==uid, deleted==false) → Trip[]
```

### Recommended Project Structure
```
backend/
├── firebase.json            # functions + firestore + emulators block (D-14)
├── .firebaserc              # default project travey-298a7 (D-01)
├── firestore.rules          # deny-all (D-13)
└── functions/
    ├── package.json         # engines.node "20", main, build/serve/deploy/test scripts
    ├── tsconfig.json        # strict; outDir lib; rootDir src
    ├── tsconfig.dev.json    # scaffold default (lints config files)
    ├── .eslintrc.js         # scaffold default
    ├── jest.config.js       # ts-jest preset
    └── src/
        ├── index.ts                 # admin.initializeApp(); Express app; export const api = onRequest(app)
        ├── handlers/
        │   ├── sync-trips.ts        # POST /trips/sync   (BACK-02)
        │   ├── delete-trip.ts       # DELETE /trips/:tripId (BACK-03)
        │   └── restore-trips.ts     # GET /trips/restore (BACK-04)
        ├── utils/
        │   ├── auth.ts              # verifyBearer(req) -> DecodedIdToken | throws 401
        │   ├── firestore.ts         # tripConverter, tripsCollection() helper
        │   ├── validation.ts        # zod schemas (tripSchema, syncBodySchema, tripIdParam)
        │   └── respond.ts           # send(res, statusCode, {data?|error?}) — D-06 shape
        └── types/
            └── trip.ts              # shared Trip TS type (contract w/ Phase 11)  ← z.infer
        └── __tests__/  (or test/)
            ├── helpers/emulator-token.ts   # mint ID token vs auth emulator
            ├── sync-trips.test.ts
            ├── delete-trip.test.ts
            └── restore-trips.test.ts
```

### Pattern 1: `index.ts` — Express under a single v2 `onRequest`
```typescript
// Source: Firebase docs "HTTP functions" + "Express integration" pattern (CITED: firebase.google.com/docs/functions/http-events)
import {onRequest} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";
import {initializeApp} from "firebase-admin/app";
import express from "express";

import {syncTrips} from "./handlers/sync-trips";
import {deleteTrip} from "./handlers/delete-trip";
import {restoreTrips} from "./handlers/restore-trips";

initializeApp();                          // no args: ADC in prod, emulator env in tests
setGlobalOptions({region: "us-central1"}); // D-02

const app = express();
// NOTE: do NOT add express.json() blindly — see Pitfall 2. firebase-functions
// already parses JSON onto req.body for application/json. express.json() is a
// harmless no-op on an already-parsed body in most cases, but the documented,
// safe stance is to rely on req.body being populated. Add express.json() only
// if you hit an unparsed-body case under supertest (supertest hits Express
// directly, bypassing the functions parser — see test note).
app.post("/trips/sync", syncTrips);
app.delete("/trips/:tripId", deleteTrip);
app.get("/trips/restore", restoreTrips);

// Single deployable. Full URL in prod:
// https://us-central1-travey-298a7.cloudfunctions.net/api/trips/sync
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
    return await getAuth().verifyIdToken(match[1]); // works against emulator when FIREBASE_AUTH_EMULATOR_HOST set
  } catch {
    throw new AuthError("Invalid or expired token"); // never echo the underlying error/token
  }
}
```

### Pattern 3: Typed `FirestoreDataConverter<Trip>` — `utils/firestore.ts` + `types/trip.ts`
```typescript
// types/trip.ts — the cross-phase contract (mirror Drift trips_table.dart)
import {Timestamp} from "firebase-admin/firestore";

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

// Stored doc = Trip + server metadata (D-10)
export interface TripDoc extends Trip {
  deleted: boolean;
  deletedAt: Timestamp | null;
  serverUpdatedAt: Timestamp; // FieldValue.serverTimestamp() resolves to Timestamp on read
}
```
```typescript
// utils/firestore.ts
// Source: Admin SDK FirestoreDataConverter (CITED: firebase.google.com/docs/reference/admin/node/...FirestoreDataConverter)
import {getFirestore, FirestoreDataConverter, QueryDocumentSnapshot} from "firebase-admin/firestore";
import type {TripDoc} from "../types/trip";

export const tripConverter: FirestoreDataConverter<TripDoc> = {
  toFirestore: (t) => t,                       // we pass full objects; metadata set explicitly in handlers
  fromFirestore: (snap: QueryDocumentSnapshot) => snap.data() as TripDoc,
};

export const tripsCollection = () =>
  getFirestore().collection("trips").withConverter(tripConverter);
```

### Pattern 4: Full handler — `handlers/sync-trips.ts` (verify → validate → trust → write, D-07/08/12)
```typescript
// Source: composed from Admin SDK batch docs (CITED: firebase.google.com/docs/firestore/manage-data/transactions#batched-writes)
import type {Request, Response} from "express";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {verifyBearer, AuthError} from "../utils/auth";
import {syncBodySchema} from "../utils/validation";
import {tripsCollection} from "../utils/firestore";

const BATCH_LIMIT = 500; // D-12

export async function syncTrips(req: Request, res: Response): Promise<void> {
  // 1. VERIFY (D-07)
  let uid: string;
  try { uid = (await verifyBearer(req)).uid; }
  catch (e) {
    if (e instanceof AuthError) { res.status(401).json({error: e.message}); return; }
    res.status(401).json({error: "Unauthorized"}); return;
  }
  // 2. VALIDATE (D-07) — safeParse, never throw to client
  const parsed = syncBodySchema.safeParse(req.body);
  if (!parsed.success) { res.status(400).json({error: "Invalid request body"}); return; }

  // 3. TRUST — force ownership (D-08), chunk batches (D-12)
  const trips = parsed.data.trips;
  const db = getFirestore();
  const col = tripsCollection();
  const syncedIds: string[] = [];

  for (let i = 0; i < trips.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const t of trips.slice(i, i + BATCH_LIMIT)) {
      batch.set(
        col.doc(t.id),
        {
          ...t,
          userId: uid,                         // overwrite any client userId (D-08)
          deleted: false,                       // re-synced trip resurfaces (D-11)
          deletedAt: null,
          serverUpdatedAt: FieldValue.serverTimestamp(),
        } as never,                             // converter typing; keep strict — see Open Q
        {merge: true},                          // idempotent upsert (D-12)
      );
      syncedIds.push(t.id);
    }
    await batch.commit();
  }
  res.status(200).json({data: {syncedIds}}); // D-06 (statusCode mirrored by res.status)
}
```
> Note for planner: the `as never` cast is a placeholder to flag the converter/`FieldValue` typing friction — see Open Questions. Prefer a typed write-shape interface (`TripWrite`) over a cast to honor "no `any`". CLAUDE.md forbids `any`; `as never`/`as unknown` should also be avoided in the final code.

### Pattern 5: Delete handler core (ownership read-check, D-08/D-11)
```typescript
const ref = tripsCollection().doc(tripIdParam.parse(req.params.tripId));
const snap = await ref.get();
if (!snap.exists) { res.status(404).json({error: "Not found"}); return; }
if (snap.data()!.userId !== uid) { res.status(404).json({error: "Not found"}); return; } // 404 not 403 — don't leak existence
await ref.update({deleted: true, deletedAt: FieldValue.serverTimestamp(), serverUpdatedAt: FieldValue.serverTimestamp()});
res.status(200).json({data: {id: ref.id}});
```

### Pattern 6: Restore handler core (D-08/D-11)
```typescript
const snap = await tripsCollection()
  .where("userId", "==", uid)
  .where("deleted", "==", false)
  .get();
const trips = snap.docs.map((d) => {
  const {deleted, deletedAt, serverUpdatedAt, ...trip} = d.data(); // strip server metadata; return pure Trip
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
    "rules": "firestore.rules"
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
> Omit a `firestore.indexes` entry only if the composite query (`userId ==` + `deleted ==`) does not need a composite index. Firestore needs a composite index for a query combining two equality filters on different fields **only in some cases** — equality-only on two fields is auto-indexed by single-field indexes in many cases, but Firestore may still require a composite index. **Plan to capture the index requirement at first run** (the emulator/console prints the exact index URL). See Open Questions.

### Anti-Patterns to Avoid
- **Shared auth middleware that mutates `req` then handlers "trust" it.** CLAUDE.md/D-05 require verify→validate→trust *inside each handler*. Keep `verifyBearer(req)` as the first call in every handler, not Express middleware.
- **Returning 403 on cross-user delete.** Use 404 to avoid leaking that another user's trip exists (D-08 says 404/403 — pick 404).
- **`cloud_firestore` SDK in the Flutter client.** Forbidden; client talks REST only.
- **Hard delete.** Soft delete only (D-11).
- **Echoing token/stack traces in error bodies.** D-06.
- **Express 5 assumptions.** Pin Express 4 unless verified otherwise (routing/path-matching changed in 5).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ID-token verification | Custom JWT/JWKS parse + signature check | `getAuth().verifyIdToken()` | Handles key rotation, revocation, clock skew, emulator mode |
| Path/method routing | Manual `if (req.method===...)` + URL parse | Express routes | `/:tripId` param extraction, method dispatch (D-04) |
| Input validation | Manual `typeof` checks | zod `.safeParse` + `z.infer` | Type-safe, generates the `Trip` type, CLAUDE.md mandate |
| Atomic multi-write | Sequential `await set()` in a loop | `db.batch()` chunked ≤500 | Atomicity per chunk, fewer round-trips, respects 500 limit (D-12) |
| Server timestamps | `new Date()` on the function host | `FieldValue.serverTimestamp()` | Authoritative server clock, audit-correct (D-10) |
| Test token minting | Self-sign a JWT | Auth-emulator REST sign-up (below) | Produces a token `verifyIdToken` accepts in emulator mode |

**Key insight:** Every "hard" part here (token verification, atomic writes, server time) is a first-party Admin SDK primitive. The only bespoke code is glue (Express wiring, zod schemas mirroring the Drift table, the response helper).

## Emulator Testing — the token-mint technique (the one tricky bit)

When `FIREBASE_AUTH_EMULATOR_HOST` is set, `getAuth().verifyIdToken()` **skips signature verification** and accepts tokens issued by the auth emulator. So tests must obtain a real emulator-issued ID token. Two reliable approaches:

**Approach A (recommended) — Admin SDK custom token → emulator REST exchange.** Create a custom token with the Admin SDK, then exchange it for an ID token at the emulator's Identity Toolkit REST endpoint:
```typescript
// helpers/emulator-token.ts
// Source: Firebase auth emulator REST + custom-token exchange (CITED: firebase.google.com/docs/emulator-suite + identitytoolkit REST)
import {getAuth} from "firebase-admin/auth";

const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST!; // e.g. "localhost:9099"
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
  const json = (await resp.json()) as {idToken: string};
  return json.idToken; // verifyIdToken accepts this while emulator host is set
}
```

**Approach B — direct emulator sign-up:** POST to `accounts:signUp?key=fake-api-key` with `{returnSecureToken:true}` to get a brand-new uid + idToken in one call. Use when you don't care about a specific uid. For ownership tests you DO care, so prefer A (control the uid) or B then read the returned `localId` as the uid.

**Test setup (Jest), connecting Admin SDK to emulators:**
```typescript
// jest setup / beforeAll
process.env.FIREBASE_AUTH_EMULATOR_HOST = "localhost:9099";
process.env.FIRESTORE_EMULATOR_HOST = "localhost:8080";
process.env.GCLOUD_PROJECT = "travey-298a7"; // singleProjectMode (D-14)
// import index AFTER env is set so initializeApp() picks up emulator hosts
```

**Running tests against the suite:**
```bash
# package.json: "test": "firebase emulators:exec --only auth,firestore,functions 'jest --runInBand'"
cd backend/functions && npm test
```
`emulators:exec` starts the suite, runs the command, tears down. `--runInBand` avoids cross-test Firestore state races (or clear Firestore between tests via the emulator REST `DELETE /emulator/v1/projects/{p}/databases/(default)/documents`).

**Driving the endpoints in tests — two options:**
1. **supertest against the Express `app`** (fast, in-process): `import {app}` (export it alongside `api`), `await request(app).post('/trips/sync').set('Authorization', 'Bearer '+token).send({trips})`. Note: supertest hits Express directly, bypassing the functions JSON parser — so for supertest you DO need `express.json()` mounted (Pitfall 2).
2. **fetch against the functions emulator** (true end-to-end): `http://localhost:5001/travey-298a7/us-central1/api/trips/sync`. Exercises the real `onRequest` body parsing.
> Recommendation: use **supertest + `express.json()`** for the bulk of assertions (fast, deterministic), plus optionally one fetch-based smoke per endpoint. Planner decides; both satisfy D-15.

## Common Pitfalls

### Pitfall 1: Auth emulator token rejected by `verifyIdToken`
**What goes wrong:** Tests self-sign a JWT or use a random string → `verifyIdToken` throws.
**Why:** Even in emulator mode, the token must be issued by the auth emulator (correct `iss`/`aud`/format).
**How to avoid:** Mint via Approach A/B above. Ensure `FIREBASE_AUTH_EMULATOR_HOST` is set **before** `initializeApp()` runs and before `verifyIdToken` is called.
**Warning sign:** `auth/argument-error` or `Decoding Firebase ID token failed`.

### Pitfall 2: Express body parsing under `onRequest` vs supertest
**What goes wrong:** Adding `express.json()` "just in case", OR omitting it and finding `req.body` empty under supertest.
**Why:** `firebase-functions` parses JSON onto `req.body` for the real `onRequest` path; supertest calls Express directly and does NOT go through that parser.
**How to avoid:** Mount `express.json()` (it makes supertest work and is a near-no-op for already-parsed bodies in the functions path). Test both a supertest path and one real-emulator fetch to confirm. Verify behavior once at scaffold time rather than assuming.
**Warning sign:** Handler sees `undefined` body in tests but works deployed (or vice versa).

### Pitfall 3: Cold start latency (2nd gen)
**What goes wrong:** First request after idle is slow (Node + Admin SDK init).
**Why:** Cloud Functions scale to zero; cold start pays init cost.
**How to avoid:** Call `initializeApp()` once at module top (not per request). For v0.1 background sync, cold start is acceptable (no UI blocking — client is fire-and-forget per architecture). Do NOT add `minInstances` (cost) for v0.1. Note for Phase 11: client must tolerate first-call latency.
**Warning sign:** Occasional multi-second first response; fine for this use case.

### Pitfall 4: `/trips/:tripId` not matching / wrong method
**What goes wrong:** DELETE to `/trips/abc` 404s, or POST hits the param route.
**Why:** Route order / method mismatch, or Express 5 path-matching change.
**How to avoid:** Register `post('/trips/sync')` and `get('/trips/restore')` (static) before/independently of `delete('/trips/:tripId')`; methods disambiguate. Pin Express 4.
**Warning sign:** Param routes swallowing static paths.

### Pitfall 5: Composite index required for restore query
**What goes wrong:** `where('userId','==').where('deleted','==')` errors in prod with "needs an index".
**Why:** Firestore may require a composite index for multi-field queries.
**How to avoid:** Run the query against the emulator/prod once; if it demands an index, capture the generated `firestore.indexes.json` and add to `firebase.json` + deploy with `--only firestore:indexes`. The emulator is more lenient than prod — **test the query against real Firestore before declaring done**, or proactively define the composite index.
**Warning sign:** `FAILED_PRECONDITION: The query requires an index` (only surfaces in prod).

### Pitfall 6: Deploy ordering (functions vs rules)
**What goes wrong:** Functions deploy but rules don't, leaving Firestore open, or vice versa.
**Why:** Separate deploy targets.
**How to avoid:** Deploy both: `cd backend && firebase deploy --only functions,firestore:rules`. Rules are independent of function readiness; order doesn't strictly matter, but deploy rules so the deny-all is live. CLAUDE.md lists them as separate commands; the combined `--only functions,firestore:rules` does both in one call.
**Warning sign:** Console shows old rules / "allow if false" missing.

### Pitfall 7: `FieldValue.serverTimestamp()` + converter typing (no `any`)
**What goes wrong:** `serverUpdatedAt: FieldValue` vs the `Timestamp` field type → TS error; tempting `as any`.
**Why:** Write-time value is a sentinel; read-time value is a `Timestamp`. CLAUDE.md forbids `any`.
**How to avoid:** Define a separate write interface (e.g. `type TripWrite = Omit<TripDoc,'serverUpdatedAt'|'deletedAt'> & {serverUpdatedAt: FieldValue; deletedAt: FieldValue|Timestamp|null}`), or use `WithFieldValue<TripDoc>` from the Admin SDK. Avoid `as never`/`as any` in final code.
**Warning sign:** Type errors around `set()`/`update()` payloads.

### Pitfall 8: `singleProjectMode` + project id mismatch
**What goes wrong:** Emulator uses a different project id than the Admin SDK → data not visible / token aud mismatch.
**Why:** `GCLOUD_PROJECT` / `.firebaserc` must agree (`travey-298a7`).
**How to avoid:** Set `GCLOUD_PROJECT=travey-298a7` in test env; `.firebaserc` default = same; `singleProjectMode:true`.

## Runtime State Inventory

> Greenfield backend — no pre-existing runtime state to migrate. Included because Phase 10 deploys live infrastructure.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — Firestore `trips` collection does not exist yet; created on first write. | None |
| Live service config | Firebase project `travey-298a7` exists (used by Phase 9 Auth). This phase ADDS Cloud Functions + Firestore + rules to it. Firestore database must be **provisioned (Native mode)** in the project before first deploy/use. | Verify/create Firestore (Native mode) in console; deploy functions + rules |
| OS-registered state | None | None |
| Secrets/env vars | No new secrets for v0.1 (Admin SDK uses ADC in deployed functions; no API keys needed server-side). Phase 9 client already holds the Firebase config. | None |
| Build artifacts | None yet — `backend/functions/lib/` (TS output) and `node_modules/` will be generated; add to `.gitignore` (scaffold default does this). | Ensure `lib/` + `node_modules/` gitignored |

**Verified:** `backend/` directory does not exist (greenfield). Repo-root `firebase.json` is the FlutterFire app config and must not be modified (D-01).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js 20 | Functions runtime + build/test | UNVERIFIED (probe returned empty this session) | — | nvm install 20 |
| npm | Install deps | UNVERIFIED | — | comes with Node |
| firebase CLI (`firebase-tools`) | emulators, deploy, init | UNVERIFIED | — | `npm i -g firebase-tools` or local devDep |
| Java JDK | Firestore + Auth emulators require a JVM | UNVERIFIED | — | install Temurin/OpenJDK 11+ |
| Firebase project `travey-298a7` | deploy target | Assumed yes (Phase 9 used it) | — | — |
| Firestore (Native mode) provisioned | restore/sync writes | UNKNOWN — likely NOT yet created | — | Create in console / `firebase firestore:databases:create` |

**Missing/unverified with action needed:**
- **Java JDK** — the Firestore and Auth emulators are Java processes. If absent, `firebase emulators:start` fails. Planner's environment-setup task must verify `java -version`.
- **Firestore database provisioning** — must exist (Native mode) in `travey-298a7` before live deploy. Emulator does not need it; prod does.
- **firebase CLI + Node 20** — confirm at scaffold (the version-verification task covers this).

> All availability probes in this research session returned empty output (sandbox/network). Planner's first task MUST re-run these checks: `node --version`, `npm --version`, `firebase --version`, `java -version`.

## Validation Architecture

> nyquist_validation = true in config.json → section included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Jest + ts-jest (recommended; Firebase scaffold default) — version verify (`^29.x` `[ASSUMED]`) |
| Config file | `backend/functions/jest.config.js` — **does not exist (Wave 0)** |
| Quick run command | `cd backend/functions && jest <file> --runInBand` (inside a running emulator, or use exec) |
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
| BACK-04 | restore excludes other users' trips | integration (ownership) | `jest restore-trips.test.ts -t "ownership"` | ❌ Wave 0 |
| (rules) | deny-all blocks direct client read/write | optional rules test (`@firebase/rules-unit-testing`) | — | ❌ optional |

### Sampling Rate
- **Per task commit:** the single handler's test file via `jest <file> --runInBand` (inside emulator).
- **Per wave merge:** full `npm test` (emulators:exec + jest).
- **Phase gate:** full suite green + a live deploy smoke (curl one endpoint with a real token) before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `backend/functions/jest.config.js` — ts-jest preset
- [ ] `backend/functions/src/__tests__/helpers/emulator-token.ts` — `mintIdToken(uid)`
- [ ] `backend/functions/src/__tests__/sync-trips.test.ts` — BACK-02
- [ ] `backend/functions/src/__tests__/delete-trip.test.ts` — BACK-03
- [ ] `backend/functions/src/__tests__/restore-trips.test.ts` — BACK-04
- [ ] Framework install: `npm i -D jest ts-jest @types/jest supertest @types/supertest`
- [ ] Emulator env bootstrap (set `*_EMULATOR_HOST` + `GCLOUD_PROJECT` before importing index)

## Security Domain

> security_enforcement absent in config → enabled. Backend phase → in scope.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Firebase ID-token verification (`verifyIdToken`) at every handler entry (D-07) |
| V3 Session Management | no (stateless) | Tokens are short-lived JWTs; no server session. Token expiry handled by `verifyIdToken`. |
| V4 Access Control | yes | Server-forced ownership (D-08): `userId = uid`; delete read-check; restore filtered by uid |
| V5 Input Validation | yes | zod `.safeParse` at handler entry (D-07); reject 400 on failure |
| V6 Cryptography | no (delegated) | No custom crypto; Firebase/Admin SDK handle JWT signing/verification |
| V7 Error/Logging | yes | No stack traces/tokens in responses (D-06); log server-side only |
| V13 API/Web Service | yes | REST over HTTPS; deny-all Firestore rules (D-13); CORS — see below |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-user write (client sets someone else's userId) | Tampering / Elevation | Server overwrites `userId` with token uid (D-08) |
| Cross-user delete/restore | Elevation / Info disclosure | Ownership read-check (404, not 403, to avoid existence leak) |
| Forged / replayed token | Spoofing | `verifyIdToken` (signature, exp, revocation) |
| Direct Firestore access bypassing functions | Tampering | Deny-all rules (D-13) — Admin SDK only |
| Injection via trip fields | Tampering | zod typed validation; Firestore is not SQL (no injection sink), but validate shapes |
| Info disclosure via errors | Info disclosure | Generic error bodies; no stack/token echo (D-06) |
| DoS via huge sync batch | DoS | Chunk ≤500 (D-12); consider a max-trips cap in zod (e.g. `.max(N)`) — see Open Q |

**CORS note:** The client is the native http package (Flutter), **not a browser** — CORS is a browser-enforced mechanism and does not apply to native mobile requests. No CORS config is required for the Flutter client. (If the API were ever called from a web origin, add `cors` middleware; out of scope for v0.1 Android-only.) `[VERIFIED: reasoning — CORS is browser-origin enforcement; native HTTP clients don't send Origin/aren't subject to it]`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `firebase-functions ^6.x` is current | Standard Stack | Low — `firebase init functions` installs the correct compatible version; verify with `npm view` |
| A2 | `firebase-admin ^13.x` is current | Standard Stack | Low — same; API surface (`getAuth`/`getFirestore`/`FieldValue`) stable across recent majors |
| A3 | Express 4 (not 5) is what the scaffold/examples assume | Standard Stack / Pitfall 4 | Medium — Express 5 changed routing; if scaffold pulls 5, verify `/:tripId` matching + middleware |
| A4 | `zod ^3.x` | Standard Stack | Low-Med — if `npm view` shows 4.x, confirm `.safeParse`/`z.infer` unchanged before pinning |
| A5 | Jest/ts-jest `^29.x` | Validation Arch | Low — verify; functions scaffold may pin a specific minor |
| A6 | `firebase-tools ^14.x` | Standard Stack | Low — use latest CLI |
| A7 | Firebase functions scaffold default test runner = Jest, module = CommonJS | Test runner rec | Low — long-standing; confirm by running `firebase init functions` |
| A8 | Auth emulator accepts custom-token→signInWithCustomToken exchange and `verifyIdToken` accepts the result when `FIREBASE_AUTH_EMULATOR_HOST` is set | Emulator Testing | Low-Med — well-documented behavior; confirm endpoint path/key (`fake-api-key`) at first test run |
| A9 | Node 20 is an accepted Functions 2nd gen runtime as of 2026 | Stack | Low — but **verify Node 20 is not deprecated/EOL for new deploys**; if Firebase has moved minimum to Node 22, bump `engines.node` (D-02 says 20; flag to user if 20 is rejected at deploy) |
| A10 | Restore query may or may not need a composite index | Pitfall 5 / firebase.json | Medium — must test against real Firestore; capture index if demanded |
| A11 | Firestore (Native mode) DB not yet provisioned in `travey-298a7` | Environment / Runtime State | Medium — must create before live deploy; blocks success criterion 1-3 in prod if missing |

> **All version pins are unverified this session.** The planner's first task is mandatory `npm view` confirmation (command provided above). Treat the architecture/patterns as HIGH confidence and the numbers as MEDIUM-until-verified.

## Open Questions

1. **Exact current versions of all deps.**
   - What we know: rough major lines (Assumptions Log).
   - What's unclear: exact `npm view` numbers; whether scaffold pulls Express 4 vs 5, zod 3 vs 4.
   - Recommendation: planner's Task 1 runs the `npm view` loop and pins; prefer scaffold-installed versions for first-party packages.

2. **Node 20 still accepted for new 2nd-gen deploys in mid-2026?**
   - What we know: D-02 locks Node 20.
   - What's unclear: Firebase periodically raises the minimum runtime / deprecates old Node.
   - Recommendation: at scaffold, check the deploy warning. If Node 20 is rejected/deprecated, surface to user (it's a locked decision) before bumping to 22.

3. **Composite index for the restore query.**
   - What we know: `where(userId==).where(deleted==false)`; emulator is lenient, prod may demand an index.
   - What's unclear: whether this specific two-equality query needs a composite index.
   - Recommendation: run the query against prod Firestore (or rely on the error's index-creation URL) and, if required, add `firestore.indexes.json` + deploy `--only firestore:indexes`. Proactively defining it is safe.

4. **Max trips per sync batch cap.**
   - What we know: chunking handles >500; but an unbounded request body is a DoS vector.
   - What's unclear: a sensible upper bound for v0.1.
   - Recommendation: add a zod `.max()` on the trips array (e.g. 1000) returning 400 if exceeded. Confirm bound with user/Phase-11 sync design.

5. **Converter/`FieldValue` typing without `any`.**
   - What we know: CLAUDE.md forbids `any`; `serverTimestamp()` sentinel vs `Timestamp` field type conflicts.
   - Recommendation: define a `TripWrite` interface or use `WithFieldValue<TripDoc>`; the `as never` in Pattern 4 is a placeholder, NOT for final code.

6. **`firestore.indexes.json` inclusion in `firebase.json`.** Decide whether to ship an indexes file now (empty/with the composite index) — tied to Q3.

## Sources

### Primary (HIGH confidence — architecture/API)
- CONTEXT.md D-01..D-15, CLAUDE.md Backend/Cloud Functions Rules, REQUIREMENTS.md (BACK-02/03/04), ROADMAP.md Phase 10, `lib/database/tables/trips_table.dart` — read directly this session.
- Firebase HTTP functions / Express integration — `firebase.google.com/docs/functions/http-events` [CITED, from training knowledge]
- Admin SDK verify ID tokens — `firebase.google.com/docs/auth/admin/verify-id-tokens` [CITED]
- Admin SDK batched writes (500 limit) — `firebase.google.com/docs/firestore/manage-data/transactions#batched-writes` [CITED]
- FirestoreDataConverter — Admin Node reference [CITED]
- Emulator Suite + auth-emulator token behavior — `firebase.google.com/docs/emulator-suite` [CITED]

### Secondary (MEDIUM — needs version confirmation)
- npm version pins for all packages — **could not fetch live this session**; from Jan 2026 knowledge. Verify with `npm view`.

### Tertiary (LOW)
- None relied upon for normative claims.

## Metadata

**Confidence breakdown:**
- Standard stack (which packages): HIGH — locked by D-02/D-03 + CLAUDE.md. Exact versions: MEDIUM (unverified this session).
- Architecture / file layout / code patterns: HIGH — locked decisions + stable, long-standing Firebase APIs.
- Emulator token-mint technique: HIGH on the approach (well-documented, stable), MEDIUM on exact endpoint string until first test run.
- Pitfalls: HIGH — all are well-known Firebase Functions gotchas directly relevant to the locked design.

**Research date:** 2026-06-01
**Valid until:** ~2026-07-01 for versions (fast-moving npm); architecture stable ~6 months.
