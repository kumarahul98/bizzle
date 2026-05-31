---
phase: 10-backend-infrastructure
reviewed: 2026-06-01T00:00:00Z
depth: standard
files_reviewed: 24
files_reviewed_list:
  - backend/.firebaserc
  - backend/firebase.json
  - backend/firestore.indexes.json
  - backend/firestore.rules
  - backend/functions/jest.config.js
  - backend/functions/package.json
  - backend/functions/tsconfig.json
  - backend/functions/src/index.ts
  - backend/functions/src/handlers/sync-trips.ts
  - backend/functions/src/handlers/delete-trip.ts
  - backend/functions/src/handlers/restore-trips.ts
  - backend/functions/src/types/trip.ts
  - backend/functions/src/utils/auth.ts
  - backend/functions/src/utils/firestore.ts
  - backend/functions/src/utils/validation.ts
  - backend/functions/src/utils/response.ts
  - backend/functions/src/utils/__tests__/auth.test.ts
  - backend/functions/src/utils/__tests__/validation.test.ts
  - backend/functions/test/handlers/sync-trips.test.ts
  - backend/functions/test/handlers/delete-trip.test.ts
  - backend/functions/test/handlers/restore-trips.test.ts
  - backend/functions/test/rules/deny-all.test.ts
  - backend/functions/test/helpers/emulator.ts
  - backend/functions/test/helpers/fixtures.ts
  - backend/functions/test/helpers/mint-token.ts
  - backend/functions/test/helpers/harness.smoke.test.ts
findings:
  critical: 0
  high: 1
  medium: 3
  low: 3
  total: 7
status: issues_found
---

# Phase 10: Backend Infrastructure — Code Review Report

**Reviewed:** 2026-06-01
**Depth:** standard (language-aware, per-file; full source + test suite)
**Files Reviewed:** 26
**Status:** issues_found

## Summary

Solid, spec-faithful implementation. Across all three handlers the ordering is correct — **verify auth FIRST, then zod-validate, then trust** (D-07): every handler returns 401 before any Firestore access, validates body/params before any write/read, and error bodies leak only short typed strings (`'Unauthorized'`, `'Invalid request body'`, `'Invalid trip id'`, `'Trip not found'`, `'Internal error'`) — no tokens, stacks, or SDK detail (the catch blocks are bare `catch {}`, so nothing internal can escape). `verifyAuth` rethrows every SDK failure as a generic `AuthError`, so the raw `auth/id-token-expired`-style message never reaches the client.

Ownership is enforced correctly: `sync` force-sets `userId = uid` ignoring any client value (D-08, and there's a direct test seeding `userId:'attacker'` and asserting the stored doc is `userA`); `delete` returns **404 not 403** on owner-mismatch to avoid the existence oracle (D-08), with a test proving userA cannot touch userB's trip and the doc is left unchanged; `restore` filters `userId == uid AND deleted == false` (D-08/D-11), with a test seeding a deleted trip and a foreign-user trip and asserting both are excluded. Soft-delete is honored — there is **no `.delete()` anywhere** in handler code (the only `.delete()` is in the test `clearFirestore` helper). Batch chunking is correct: `db.batch()` is re-instantiated **inside** the chunk loop, chunks are `slice(start, start+500)` ≤500, committed sequentially, and `set(merge:true)` keyed by UUID is idempotent — with an integration test asserting 600 trips land across 2 batches and 1001 trips 400 with **zero** docs written.

The test suite is genuine, not trivially-passing: integration tests read state back through the Admin SDK and assert concrete field values (`deleted`, `deletedAt`, `serverUpdatedAt`, `userId`, ISO round-trip). The deny-all rules test uses `@firebase/rules-unit-testing` with **`assertFails`** on real `getDoc`/`setDoc` for both unauthenticated and signed-in client contexts — it asserts actual permission denials, not a no-op. No `.only`/`.skip`/`xit`/`fdescribe` anywhere. Config is sound: `.firebaserc` default `travey-298a7`, strict tsconfig (`strict`, `noImplicitAny`, `noUnusedLocals/Parameters`), node 20 engine, `firebase.json` wires rules + indexes + emulators, and jest defines coherent `unit` + `integration` projects with the emulator harness as `setupFiles`.

No Critical findings. One High: the `FirestoreDataConverter` does not actually convert — it `as`-casts raw snapshot data — which the CLAUDE.md backend rules explicitly forbid and which silently undermines the JSON-safety guarantee `restore` claims in its own comment. The rest are a dead-code file, a couple of robustness nits, and a script/posture gap.

## High

### HI-01: `tripConverter` does not convert — `fromFirestore` is a blind `as TripDoc` cast, violating the "FirestoreDataConverter maps reads to interfaces" rule and undermining `restore`'s claimed JSON-safety

**File:** `backend/functions/src/utils/firestore.ts:12-16`, consumed at `backend/functions/src/handlers/restore-trips.ts:42-58`

**Problem:** The converter is a no-op:
```ts
toFirestore: (trip: TripDoc) => trip,
fromFirestore: (snapshot) => snapshot.data() as TripDoc,
```
CLAUDE.md (Backend rules) requires: "Use `FirestoreDataConverter` (or typed wrappers) so reads/writes are **mapped** to interfaces." Here nothing is mapped — `fromFirestore` asserts the stored shape *is* `TripDoc` without checking, which is exactly the "untyped Firestore read behind an `as` cast" the rules exist to prevent. Concrete consequence in `restore`: the handler header promises the response is "JSON-safe (no Firestore `Timestamp` serialization)" and then re-emits `doc.startTime`/`doc.createdAt`/etc. directly. That guarantee is **asserted, not enforced** — if any field were ever stored as a Firestore `Timestamp` (a future write bug, a manual console edit, a schema drift), `restore` would emit `{_seconds,_nanoseconds}` to the client instead of an ISO string and TypeScript would not catch it, because the cast already lied about the type. Today it round-trips only because every writer happens to store ISO strings; the converter provides no protection.

**Fix:** Make the read path coerce instead of trust. Lowest-risk, most-targeted change is in `restore-trips.ts` — normalize timestamp-shaped values to ISO before returning:
```ts
const toIso = (v: string | { toDate?: () => Date }): string =>
  typeof v === 'string' ? v : (v.toDate?.()?.toISOString() ?? '');
// in the map:
startTime: toIso(doc.startTime),
endTime: toIso(doc.endTime),
createdAt: toIso(doc.createdAt),
updatedAt: toIso(doc.updatedAt),
```
Alternatively, do the coercion once inside `fromFirestore` by building the `TripDoc` explicitly (no `as`). Either way, remove reliance on the bare `as TripDoc` as the sole typing of reads.

## Medium

### ME-01: `src/utils/response.ts` is dead code — `sendSuccess`/`sendError` are defined but never imported

**File:** `backend/functions/src/utils/response.ts:1-18`

**Problem:** All three handlers and the `/health` route inline the response shape (`res.status(...).json({ statusCode, body: { ... } })`); `grep` confirms `sendSuccess`/`sendError` are referenced **only** in their own definition file. CLAUDE.md: "No dead code… No speculative abstractions. Only build what is needed right now." This is both, and it creates two sources of truth for the canonical `{statusCode, body}` shape that can drift apart. `noUnusedLocals` does not flag unused *exports*, so the build stays green and this slips past lint.

**Fix:** Pick one and apply it in the --fix pass:
- **(Recommended, smallest diff)** Delete `backend/functions/src/utils/response.ts`. The inline form is already consistent across every handler.
- *Or* refactor all handlers + the `/health` paths to call `sendSuccess`/`sendError`, eliminating the inline duplication. Do not leave the file unused.

### ME-02: No CORS posture declared, and no `test:integration` npm script — the integration jest project can only be run via the full `test` (emulators:exec) entry, never in isolation

**File:** `backend/functions/package.json:13-15`, `backend/functions/src/index.ts:24-41`

**Problem:** Two small gaps the brief asked about:
1. **CORS:** the Express app configures no CORS. For the Phase 11 native Android client (`http` package) this is harmless — native HTTP issues no preflight, so CORS is irrelevant and *not* a security hole. But the decision is undeclared: a future browser caller (admin tool / the Vite landing page) would hit an unhandled `OPTIONS` and get a confusing 404, and there's no comment recording that CORS was omitted intentionally.
2. **Scripts:** `package.json` defines `test:unit` (`jest --selectProjects unit`) but **no** `test:integration` counterpart, even though `jest.config.js` defines a named `integration` project. The integration suite is therefore only reachable through the umbrella `test` script (which spins emulators). A dev wanting to run just the integration project (against an already-running emulator) has no script for it — a minor ergonomics/consistency gap.

**Fix:**
- Add a one-line comment at the `express()` setup stating CORS is intentionally off (native client only); if a browser caller is anticipated, add locked-origin CORS — **not** `cors({origin:'*'})`, which is a worse default for an auth-gated API.
- Add the symmetric script: `"test:integration": "jest --selectProjects integration"` (and optionally `"test:unit"` already exists). Keep the emulator-wrapping `test` as the CI entry.

### ME-03: `sync` resurrects a server-soft-deleted trip on any stale re-sync (`deleted:false` blind-overwrite) — per D-11 spec, but undocumented at the code site and a genuine sharp edge

**File:** `backend/functions/src/handlers/sync-trips.ts:66-84`

**Problem:** Every sync write rebuilds the full doc with `deleted:false` and `merge:true`, so syncing a stale client copy of a trip the server already soft-deleted will silently set `deleted:false` again — un-deleting it. D-11 explicitly *intends* this ("a re-created/edited trip resurfaces"), so it is spec-conformant and **not a bug**. But an offline client that never observed the delete will resurrect it on next sync, and there is no comment at the write site flagging that `deleted:false` is deliberate — a future reader could "fix" it into one. (Same note applies to `createdAt`: the client value is rewritten every sync with no server-side immutability; acceptable under client-authoritative D-10.)

**Fix:** No code change required (spec-conformant). Add a one-line comment at `sync-trips.ts:80` documenting that `deleted:false` intentionally resurrects per D-11. If un-delete-on-stale-sync is later deemed undesirable, that is a Phase 11 contract decision (read-before-write to preserve `deleted:true` unless the client signals re-creation) — out of scope here.

## Low

### LO-01: `extractBearerToken` regex accepts a single-character / whitespace token

**File:** `backend/functions/src/utils/auth.ts:30-34`

**Problem:** `/^Bearer (.+)$/` matches `Bearer ` + any single char (including a stray space-padded value). Not a security hole — `verifyIdToken` rejects garbage with 401 regardless — but malformed-but-nonempty headers take the slower SDK round-trip instead of failing fast as "malformed."

**Fix:** Tighten to a non-whitespace token: `const match = /^Bearer (\S+)$/.exec(header);`

### LO-02: `restore` has no result-size bound (no `.limit()`)

**File:** `backend/functions/src/handlers/restore-trips.ts:37-61`

**Problem:** The query returns every matching doc and serializes them in one response with no pagination. For v0.1 a user's trip count is small, so low severity, but a user with years of trips would materialize the whole slice in memory in a single response. The composite index exists (so the query is fine); the unbounded materialization is the nit.

**Fix:** Acceptable for v0.1. If hardening: add a `kMaxRestoreTrips` constant `.limit()` and document restore is capped, or add cursor pagination in a later phase. At minimum make any cap an explicit constant rather than implicit "unbounded."

### LO-03: `seedTrip` writes via `set(doc as unknown as Record<string, unknown>)` — double-cast bypasses the typed collection in the test helper

**File:** `backend/functions/test/helpers/emulator.ts:89-92`

**Problem:** The seed helper writes to `db.collection(TRIPS)` (no converter) and force-casts `doc as unknown as Record<string, unknown>`. It works and the value is a well-formed `TripDoc`, but the `as unknown as` double-cast is the kind of unsafe escape hatch the project's strict-typing rules discourage; it also means seeded docs are not validated against the `tripConverter`/`TripDoc` write path the handlers use. Test-only, hence Low.

**Fix:** Seed through the typed collection helper instead — `import { tripsCollection } from '../../src/utils/firestore'` and `await tripsCollection().doc(input.id).set(doc)` — which is converter-typed and drops the double-cast. (Minor; test-only.)

## Notes (verified clean — no action)

- **Auth-first ordering:** confirmed in all three handlers — `verifyAuth` is the first statement; Firestore is only touched after both auth and validation pass.
- **Error-body leakage:** all catch blocks are bare `catch {}` returning a fixed string; `AuthError` messages are static and safe. No stack/token exposure path found.
- **Deny-all rules + test:** `firestore.rules` is correct (`allow read, write: if false`); the test asserts real `assertFails` denials for both anon and signed-in clients on read AND write.
- **Idempotent app init** in `index.ts` (`if (!getApps().length)`) correctly prevents the "[DEFAULT] already exists" throw when supertest imports `app`.
- **express.json `{ limit: '10mb' }`** is present (index.ts:30), sized to the 1000-trip cap; the zod `.max(1000)` rejects oversized batches at 400 before any write.
- **`tripId` path param** is uuid-validated (`tripIdParam`) before any Firestore lookup — no path abuse.
- **No `any`** in source; the only casts are the converter `as TripDoc` (HI-01) and the test-helper double-cast (LO-03).

---

## Counts

- Critical: 0
- High: 1
- Medium: 3
- Low: 3
- Total: 7

## Verdict

Backend is spec-faithful and secure — auth-first, ownership-forced, soft-delete-only, no error leakage, and a genuine read-back test suite (including a real deny-all assertion); the only correctness-leaning fix is the no-op `FirestoreDataConverter` (HI-01), plus deleting dead `response.ts` (ME-01).

---

_Reviewed: 2026-06-01_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard (full source + test suite, 26 files)_
