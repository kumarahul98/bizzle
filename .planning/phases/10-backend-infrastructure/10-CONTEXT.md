# Phase 10: Backend Infrastructure - Context

**Gathered:** 2026-06-01
**Status:** Ready for planning
**Mode:** `--auto` (gray areas auto-resolved to recommended/safe defaults; no interactive prompts)

<domain>
## Phase Boundary

Stand up the Firebase backend: a self-contained `backend/` directory (Firebase
CLI project) exposing three HTTPS Cloud Function endpoints, each protected by
Firebase ID-token verification and writing to Firestore via the Admin SDK.
Firestore Security Rules deny all direct client access.

**In scope:**
- `backend/` scaffold: `firebase.json`, `.firebaserc` (default project `travey-298a7`), `firestore.rules`, `functions/` (TypeScript, Node 20, Functions 2nd gen)
- `POST /trips/sync` — batch upsert trips from the client sync queue
- `DELETE /trips/{tripId}` — soft-delete a trip (`deleted: true`)
- `GET /trips/restore` — return all non-deleted trips for the authenticated user
- Firebase ID-token verification at every handler entry (`verifyIdToken`)
- zod input validation at every handler entry
- FirestoreDataConverter-typed trip documents
- Firestore Security Rules: deny-all to clients (Admin SDK only)
- Firebase Emulator Suite config (auth + functions + firestore) for local tests
- Emulator-based handler tests (auth-reject 401 + happy path for all 3 endpoints)
- Live deploy to `travey-298a7` (functions + firestore:rules)

**Out of scope:**
- Client sync engine, api_client, retry/backoff (Phase 11)
- Settings "Cloud sync" / "Restore from cloud" UI wiring (Phase 11)
- Any `cloud_firestore` SDK use in the Flutter client (forbidden by architecture)
- Server-side analytics/aggregation (out of scope for v0.1)
- Server→client sync, conflict resolution (client-authoritative; not needed)
</domain>

<decisions>
## Implementation Decisions (auto-selected — recommended/safe defaults)

### Project Layout & Tooling

- **D-01:** Backend is **self-contained under `backend/`** per CLAUDE.md project structure. It gets its own `backend/firebase.json` (functions + firestore + emulators), `backend/.firebaserc` (default project `travey-298a7`), and `backend/firestore.rules`. The existing repo-root `firebase.json` is FlutterFire's app config and is **left untouched**. Deploy runs from `backend/` (`cd backend && firebase deploy …`).
- **D-02:** Runtime: **Node.js 20**, **Cloud Functions 2nd gen**, `firebase-functions` v2 `onRequest`. Region **`us-central1`** (Firebase default; lowest friction, no data-residency requirement for v0.1).
- **D-03:** **Strict TypeScript** (`"strict": true`, no `any`). `firebase-admin` for Firestore + Auth. `zod` for validation. Lint via the functions' own ESLint (Firebase init default) — not the Flutter analyzer.

### Endpoint / Routing Architecture

- **D-04:** Expose the REST surface through a **single HTTPS function** (`api`) that mounts an **Express app** routing to the three handlers. Rationale: cleanly supports the `/trips/{tripId}` path param and HTTP-method routing in one deployable, while each handler stays self-contained in its own file (`backend/functions/src/handlers/*.ts`) per CLAUDE.md "one handler per file". Express is the standard, well-supported v2 pattern for path-param REST.
- **D-05:** Routes: `POST /trips/sync` → `sync-trips.ts`; `DELETE /trips/:tripId` → `delete-trip.ts`; `GET /trips/restore` → `restore-trips.ts`. Auth + validation run as the first lines of each handler (no shared middleware trust shortcut — verify → validate → trust, per handler).
- **D-06:** Consistent response shape everywhere: `{ statusCode, body: { data?, error? } }` (matches CLAUDE.md). HTTP status code mirrors `statusCode`. Errors are typed; never leak stack traces or tokens.

### Auth, Validation & Ownership

- **D-07:** Every handler **verifies the Firebase ID token first** (`getAuth().verifyIdToken(bearer)` from the `Authorization: Bearer <token>` header). Missing/invalid/expired → `401` with `{ error }`, no further work. Then **zod-validate** body/params; invalid → `400`. After that, data is trusted and typed.
- **D-08:** **Server forces ownership.** The authenticated `uid` from the verified token is authoritative. On sync upsert, each trip's `userId` is **set to the token uid server-side** (any client-supplied `userId` is ignored/overwritten) — prevents cross-user writes. On delete, the handler reads the doc and rejects (`404`/`403`) if `userId !== uid`. On restore, query is filtered by `userId == uid`.

### Firestore Data Model

- **D-09:** **Top-level `trips` collection**, document id = **client trip UUID**. Rationale: trip UUIDs are globally unique (client-generated v4), so `DELETE /trips/{tripId}` maps directly to a doc path, sync upsert is `set(merge)` keyed by UUID (idempotent), and restore is `where('userId','==',uid).where('deleted','==',false)`. (Subcollection `users/{uid}/trips/{id}` was considered and rejected — adds path nesting with no security benefit since rules deny-all and only the Admin SDK touches data.)
- **D-10:** **Document shape** (typed via `FirestoreDataConverter`): all trip fields from the Drift schema (`id, userId, startTime, endTime, durationSeconds, distanceMeters, routePolyline, direction, timeMovingSeconds, timeStuckSeconds, isManualEntry, createdAt, updatedAt`) **plus server metadata**: `deleted: boolean` (default false), `deletedAt: Timestamp|null`, `serverUpdatedAt: Timestamp` (set to `FieldValue.serverTimestamp()` on every write for audit). Trip timestamps are stored as **ISO 8601 UTC strings** exactly as received (round-trip fidelity for restore → Drift); server metadata uses Firestore `Timestamp`.
- **D-11:** **Soft delete only** (CLAUDE.md): delete sets `deleted: true`, `deletedAt: serverTimestamp()`; the doc is never removed. Sync upsert of an existing id sets `deleted: false` (a re-created/edited trip resurfaces). Restore excludes `deleted == true`.

### Batch Upsert Semantics

- **D-12:** `POST /trips/sync` accepts `{ trips: Trip[] }`. Writes use a Firestore **batched write** (`set(ref, doc, { merge: true })` per trip). Firestore's 500-op batch limit is respected by **chunking** into batches of ≤500. Returns `{ data: { syncedIds: string[] } }`. Idempotent: re-sending the same trips is safe.

### Security Rules

- **D-13:** `firestore.rules`: **deny-all to clients** — `match /{document=**} { allow read, write: if false; }`. Only the Admin SDK (Cloud Functions) reads/writes. Deployed alongside functions.

### Emulator & Testing

- **D-14:** `backend/firebase.json` includes an **`emulators`** block: auth (9099), functions (5001), firestore (8080), ui (4000), `singleProjectMode: true`. Tests run against the emulator (`firebase emulators:exec` or a started suite), never against prod.
- **D-15:** **Tests cover, per endpoint:** (a) **auth-reject** — request with no token and with an invalid token both return 401; (b) **happy path** — a valid (emulator-minted) token yields the correct 2xx behavior and the expected Firestore state (sync writes docs; delete sets `deleted:true`; restore returns only non-deleted trips for that uid). Plus an **ownership** test (user A cannot delete / cannot restore user B's trip). Test runner: the Firebase functions test setup (Jest or vitest — planner picks per Firebase init default; Jest is the Firebase scaffold default).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — BACK-02 (POST /trips/sync), BACK-03 (DELETE /trips/{tripId}), BACK-04 (GET /trips/restore)
- `.planning/ROADMAP.md` — Phase 10 goal + 5 success criteria

### Conventions & Architecture (MUST follow)
- `CLAUDE.md` — Backend / Cloud Functions Rules (strict TS + zod, verify→validate→trust, one handler per file, FirestoreDataConverter, deny-all rules), API endpoints table, Drift schema summary (trip fields the doc shape must mirror), response shape `{ statusCode, body: { data?, error? } }`

### Carried-forward context
- `.planning/phases/09-authentication/09-CONTEXT.md` — D-10/D-10a: ID token cached in `flutter_secure_storage` under `kFirebaseIdTokenKey`; FlutterFire handles refresh. Firebase project `travey-298a7`. This is the token Phase 11 will attach to these endpoints.

### External Docs
- `cloud-vendor-tradeoffs.pdf` — backend vendor decision rationale (AWS→Firebase)
</canonical_refs>

<code_context>
## Reusable Assets & Integration Points

- **Greenfield backend** — no `backend/`, `functions/`, or `firestore.rules` exist yet; nothing to refactor. Everything in this phase is new.
- **Repo-root `firebase.json`** — FlutterFire app config (projectId `travey-298a7`). Do NOT modify; backend gets its own config dir.
- **Drift trip schema** — `lib/database/tables/trips_table.dart` defines the canonical trip fields the Firestore document and zod schema must mirror (snake_case ↔ the JSON the Phase 11 client will send). The shared TypeScript `Trip` type (`backend/functions/src/types/trip.ts`) is the contract between Phase 10 (server) and Phase 11 (client api_client).
- **Auth contract** — verified token `uid` is the `userId`. Matches Phase 9's userId-backfill (`local_user` → Firebase uid).
</code_context>

<deferred>
## Reviewed / Deferred (not folded into Phase 10)

- **Todo `bug-manual-entry-missing-traffic-fields` (area: trips, score 0.9)** — keyword false-positive for a backend phase. It concerns manual-entry trips missing traffic/distance fields, which is a **client-side trip-data / sync-payload concern**. Reviewed, **not folded** (folding would be scope creep into the backend phase). Flagged for **Phase 11** consideration when defining the sync payload shape, or for a separate `trips` fix. Preserved in `.planning/todos/`.
</deferred>

---

## Auto-Selected Gray Areas (audit log)

`[--auto] Selected all gray areas: Project layout, Routing architecture, Firestore data model, Auth/ownership model, Batch upsert semantics, Testing strategy.`

- `[auto] Project layout — Q: "Self-contained backend/ dir vs merge into root firebase.json?" → Selected: "Self-contained backend/ (own firebase.json/.firebaserc/rules)" (recommended; matches CLAUDE.md structure, keeps Flutter config untouched)`
- `[auto] Routing — Q: "Single Express-routed function vs 3 separate onRequest exports?" → Selected: "Single 'api' function with Express router → per-file handlers" (recommended; clean path-param + method routing, one deployable)`
- `[auto] Firestore model — Q: "Top-level trips/{uuid} vs subcollection users/{uid}/trips/{id}?" → Selected: "Top-level trips collection keyed by trip UUID" (recommended; direct by-id delete, idempotent upsert)`
- `[auto] Auth/ownership — Q: "Trust client userId vs force token uid?" → Selected: "Force server-side uid; ownership-check delete & restore" (safe default; prevents cross-user writes)`
- `[auto] Timestamps — Q: "Store trip times as ISO strings vs Firestore Timestamp?" → Selected: "ISO 8601 UTC strings as received + server Timestamp metadata" (recommended; lossless restore round-trip)`
- `[auto] Batch upsert — Q: "Single batch vs chunked writes?" → Selected: "Chunked batched writes (≤500/batch), set(merge) idempotent" (safe default; respects Firestore limits)`
- `[auto] Testing — Q: "Emulator tests scope?" → Selected: "auth-reject (401) + happy path + ownership, per endpoint, on Emulator Suite" (recommended; matches phase success criteria)`
</content>
