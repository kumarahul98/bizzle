---
phase: 10-backend-infrastructure
verified: 2026-06-01T00:00:00Z
status: human_needed
score: 5/5 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: none
  note: initial verification
human_verification:
  - test: "Live 2xx happy-path against the deployed function with a REAL Google ID token (sign in on device, trigger a sync, confirm a doc appears under Firestore `trips/`, then restore it back)"
    expected: "POST /trips/sync returns 200 with syncedIds; the trip document exists in production Firestore with userId forced to the signed-in uid and deleted:false; GET /trips/restore returns it; DELETE soft-deletes it (deleted:true, doc still present)"
    why_human: "Requires interactive Google sign-in to mint a production Firebase ID token — not feasible headlessly. The identical handler code is exhaustively proven by the 48-test emulator suite; live 401-on-no-token is already confirmed in prod (10-DEPLOY.md). This is end-to-end-wired in Phase 11, so it is a wake-up item, not a Phase 10 gap."
---

# Phase 10: Backend Infrastructure Verification Report

**Phase Goal:** Firebase backend is deployed with three working HTTPS Cloud Function endpoints protected by Firebase Auth token verification, writing to Firestore.
**Verified:** 2026-06-01
**Status:** human_needed (all 5 criteria MET in code/tests + live auth gate; one happy-path item needs a real Google token on-device)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | POST /trips/sync accepts a batch of trips and writes them to Firestore | ✓ VERIFIED | `sync-trips.ts:62-91` batch-upserts each trip to `trips/{id}` via Admin SDK `batch.set(...,{merge:true})`, chunked at ≤500 (`FIRESTORE_BATCH_LIMIT=17`), userId forced to token uid (`:68`), `deleted:false` (`:84`). Test `sync-trips.test.ts` "writes trip docs with forced userId and deleted:false" reads back real emulator docs and asserts `userId`, `deleted:false`, `deletedAt:null`, lossless ISO timestamps. "600 trips → 200 across 2 batches" proves chunking writes all 600. I ran the suite: GREEN. |
| 2 | DELETE /trips/{tripId} soft-deletes a trip in Firestore | ✓ VERIFIED | `delete-trip.ts:54-58` issues `ref.update({deleted:true, deletedAt, serverUpdatedAt})` — never `.delete()`. Test "sets deleted:true + deletedAt, doc still present" asserts `snap.exists===true` (not hard-deleted) and `data.deleted===true`. Cross-user test asserts userA deleting userB's trip → 404 with doc unchanged. GREEN. |
| 3 | GET /trips/restore returns all non-deleted trips for the authenticated user | ✓ VERIFIED | `restore-trips.ts:37-40` queries `where('userId','==',uid).where('deleted','==',false)`, projects to client `Trip` shape stripping server metadata (`:48-63`). Test "returns only the caller's non-deleted trips" seeds 2 active + 1 deleted (userA) + 1 (userB), asserts response = exactly the 2 active userA ids, excludes the deleted and userB, and asserts every returned field is ISO-string with NO `deleted`/`deletedAt`/`serverUpdatedAt` leak. Composite index shipped (`firestore.indexes.json`). GREEN. |
| 4 | All endpoints reject requests without a valid Firebase ID token | ✓ VERIFIED (code/tests) + ✓ VERIFIED LIVE | Every handler calls `verifyAuth` FIRST (`sync:43`, `delete:30`, `restore:29`); `auth.ts:45-53` runs `getAuth().verifyIdToken`, rethrowing as `AuthError(401)`. Each suite has auth-reject ×2 (no header → 401, invalid bearer → 401). `auth.test.ts` adds 9 unit cases incl. strict `Bearer <\S+>` regex (whitespace-only token rejected). LIVE: `10-DEPLOY.md` smoke shows 401 on all 3 endpoints in prod (sync/restore/delete) with no/invalid token, `/health` 200, function ACTIVE. |
| 5 | Firestore Security Rules deny all direct client access — only the Admin SDK can read/write trip data | ✓ VERIFIED (code/tests) + ✓ DEPLOYED | `firestore.rules`: `match /{document=**} { allow read, write: if false; }`. `deny-all.test.ts` loads the actual rules file and `assertFails` read AND write of `trips/*` for both an unauthenticated and a signed-in client context. Every other integration test reaching Firestore uses the Admin SDK (which bypasses rules) — proving the Admin path works while the client path is denied. Rules deployed to prod per `10-DEPLOY.md`. |

**Score:** 5/5 truths verified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/handlers/sync-trips.ts` | Batch-upsert endpoint | ✓ VERIFIED | 98 lines; verify→validate→trust; chunked batches; forced uid. Imported + routed in `index.ts:post`. |
| `src/handlers/delete-trip.ts` | Soft-delete endpoint | ✓ VERIFIED | 64 lines; UUID param validation; 404 existence-oracle defence; `update`, never `delete`. Routed. |
| `src/handlers/restore-trips.ts` | Filtered restore endpoint | ✓ VERIFIED | 70 lines; two-equality query; metadata-stripped projection. Routed. |
| `src/utils/auth.ts` | Token verification gate | ✓ VERIFIED | `extractBearerToken` (strict `\S+`) + `verifyAuth` (verifyIdToken → uid). Used by all 3 handlers. |
| `src/utils/firestore.ts` | Typed converter + collection | ✓ VERIFIED | `tripConverter` builds `TripDoc` field-by-field (no blind cast), coerces timestamps to ISO. Used everywhere via `tripsCollection()`. |
| `src/utils/validation.ts` | zod schemas + DoS cap | ✓ VERIFIED | `tripSchema`, `syncTripsBody` (.min(1).max(1000)), `tripIdParam` (UUID). |
| `src/types/trip.ts` | Trip/TripDoc contract | ✓ VERIFIED | Mirrors Drift table camelCase; TripDoc adds server metadata. |
| `src/index.ts` | Routing + express limit + single `api` fn | ✓ VERIFIED | Mounts /health + 3 routes; `express.json({limit:'10mb'})`; guarded `initializeApp`; `onRequest(app)`. |
| `firestore.rules` | Deny-all | ✓ VERIFIED | `allow read, write: if false`. |
| `firestore.indexes.json` | Composite index for restore | ✓ VERIFIED | `trips(userId ASC, deleted ASC)`. |
| `firebase.json` | Functions + rules + indexes + emulator config | ✓ VERIFIED | predeploy build hook; emulator ports for auth/firestore/functions. |
| Integration + unit test suites | Genuine assertions, no skips | ✓ VERIFIED | 48 tests (29 unit + 19 integration), 0 skipped, no `.only`. Integration has zero Firestore/auth mocks. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `index.ts` | 3 handlers | `app.post/get/delete` routes | WIRED | All three imported and mounted; unknown route → 404 (smoke test). |
| handlers | `verifyAuth` | first call in each | WIRED | Auth gate precedes all Firestore work; failure → 401, zero DB access. |
| handlers | Firestore | `tripsCollection()` Admin SDK | WIRED | Real emulator read-back assertions confirm writes/queries land. |
| sync handler | zod cap | `syncTripsBody.safeParse` | WIRED | 1001-trip test → 400 with zero docs written. |
| client SDK | Firestore | (denied) `firestore.rules` | DENIED (intended) | deny-all test proves both anon + authed client read/write fail. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| restore-trips | `trips` array | Live emulator Firestore query (`userId==uid && deleted==false`) | Yes — seeded docs returned, filtered correctly | ✓ FLOWING |
| sync-trips | `syncedIds` | Real `batch.commit()` to Firestore | Yes — read-back confirms docs exist | ✓ FLOWING |

No hollow/static returns: every endpoint's response is derived from real Admin SDK writes/queries, asserted by read-back in the emulator suite (not from the HTTP response alone).

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Unit suite genuinely passes | `npm run test:unit` | 29 passed / 29, 2 suites | ✓ PASS |
| Full emulator suite genuinely passes | `npm test` (boots auth+firestore emulators, jest --runInBand) | **48 passed / 48, 7 suites, 0 skipped, exit 0** | ✓ PASS (run by verifier) |
| TypeScript compiles strict, no `any` | `npm run build` (tsc) | exit 0, no errors | ✓ PASS |
| No skipped/only tests | grep `.skip/xit/xdescribe/.only` | none found | ✓ PASS |

These were executed by the verifier — not taken from the SUMMARY. The SUMMARY's 48/48 claim is independently confirmed.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| BACK-02 | 10-01/02/03 | POST /trips/sync batch-upserts trips | ✓ SATISFIED | Criterion 1 above |
| BACK-03 | 10-01/02/03 | DELETE /trips/{tripId} soft-deletes | ✓ SATISFIED | Criterion 2 above |
| BACK-04 | 10-01/02/03 | GET /trips/restore returns user trips | ✓ SATISFIED | Criterion 3 above |

BACK-01 (Firebase Auth Google provider) is owned by Phase 9 per ROADMAP/REQUIREMENTS — correctly NOT a Phase 10 requirement. No orphaned requirements for this phase.

### Anti-Patterns Found

None blocking. Notable items, all benign / by-design:

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `sync-trips.ts:84` | `deleted:false` on re-sync resurrects a soft-deleted trip | ℹ️ Info | Intentional per D-11 (client-authoritative); documented in-code so it isn't "fixed" away. Not a bug. |
| `restore-trips.ts` | No `.limit()` on restore query | ℹ️ Info | Documented v0.1 deferral (LO-02 in 10-REVIEW-FIX). Bounded in practice by per-user trip volume; acceptable for MVP. |
| `index.ts` | No CORS | ℹ️ Info | Intentional — only caller is the native Android `http` client (no preflight). Documented with a warning against `origin:'*'`. |
| `*` handlers | `catch {}` returns generic 500 / "Unauthorized" | ℹ️ Info | Deliberate — short typed messages only, never leaks tokens/stack traces (D-06). Correct. |

No `// TODO`, no placeholder returns, no stubbed handlers, no `return null`/empty-array-without-query, no dead code (response.ts was deleted in review-fix).

### Human Verification Required

#### 1. Live 2xx happy-path with a real Google ID token

**Test:** On the device (Phase 11 wiring), sign in with Google, trigger a sync of a real trip, then check production Firestore and run restore/delete.
**Expected:** `POST /trips/sync` → 200 with `syncedIds`; a document appears under prod `trips/{id}` with `userId` = the signed-in uid and `deleted:false`; `GET /trips/restore` returns it; `DELETE /trips/{id}` flips it to `deleted:true` with the doc still present.
**Why human:** Minting a production Firebase ID token requires interactive Google sign-in (not headless). The identical handler code is exhaustively proven by the 48-test emulator suite, and the live deploy already confirms the auth gate (401 on no/invalid token) on all three endpoints. This is end-to-end-wired in Phase 11, so it is a wake-up item — it does NOT block Phase 10.

### Gaps Summary

No genuine gaps. All five success criteria are MET:

- Criteria 1, 2, 3, 5 are VERIFIED IN CODE/TESTS — the emulator suite (run by the verifier, 48/48 green) asserts real Firestore state via Admin SDK read-back with zero mocks, covering writes, soft-delete, filtered restore, ownership isolation, the 1000-trip DoS cap, batch chunking, and deny-all rules for both anon and authed clients.
- Criterion 4 is additionally VERIFIED LIVE — `10-DEPLOY.md` records 401 on all three protected endpoints in production with `/health` 200 and the `api` function ACTIVE.
- The single non-proven item — a live 2xx happy-path with a real Google ID token — is correctly recorded as a human/device wake-up item, not a gap, because (a) the identical code path is proven on the emulator and (b) it is end-to-end-wired and exercised in Phase 11.

Build is clean (`tsc`, strict, no `any`). No skipped tests, no `.only`, no stubs, no dead code.

---

_Verified: 2026-06-01_
_Verifier: Claude (gsd-verifier)_
