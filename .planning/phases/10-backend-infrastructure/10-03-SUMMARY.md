---
phase: 10-backend-infrastructure
plan: 03
subsystem: testing
tags: [jest, ts-jest, supertest, firebase-emulator, firestore, firebase-auth, rules-unit-testing, integration-tests]

requires:
  - phase: 10-01
    provides: backend scaffold, jest unit project, firebase.json emulator block, deny-all firestore.rules, firestore.indexes.json
  - phase: 10-02
    provides: exported Express app + three handlers (sync-trips, delete-trip, restore-trips), Trip/TripDoc types, zod validation with DoS cap
provides:
  - Emulator-backed integration suite proving every Phase 10 success criterion against live handlers (no mocks)
  - Reusable harness mintIdToken(uid) + emulator Admin-SDK wiring + clearFirestore/seedTrip
  - Extended jest config (integration project) that preserves the 10-01 unit project
  - Deny-all Firestore rules test (anon + authed client read/write denied)
affects: [phase-11-client-sync, backend-deploy]

tech-stack:
  added: ["@firebase/rules-unit-testing ^5.0.1 (dev)"]
  patterns:
    - "supertest drives the in-process exported Express app; Firestore state asserted via Admin SDK read-back (no Firestore/auth mocks)"
    - "mintIdToken: createCustomToken -> accounts:signInWithCustomToken yields an emulator ID token verifyIdToken accepts for a deterministic uid"
    - "Admin SDK emulator wiring via env vars set in jest setupFiles BEFORE firebase-admin init"
    - "node:crypto randomUUID for valid v4 UUID fixtures (no @types/uuid dependency)"

key-files:
  created:
    - backend/functions/test/helpers/emulator.ts
    - backend/functions/test/helpers/mint-token.ts
    - backend/functions/test/helpers/fixtures.ts
    - backend/functions/test/helpers/harness.smoke.test.ts
    - backend/functions/test/handlers/sync-trips.test.ts
    - backend/functions/test/handlers/delete-trip.test.ts
    - backend/functions/test/handlers/restore-trips.test.ts
    - backend/functions/test/rules/deny-all.test.ts
  modified:
    - backend/functions/jest.config.js
    - backend/functions/package.json
    - backend/functions/src/index.ts

key-decisions:
  - "Guarded initializeApp() in src/index.ts with getApps() so importing the exported app in-process does not double-init the Admin app (handler bug fix)"
  - "Used node:crypto randomUUID for UUID fixtures instead of adding @types/uuid for the untyped transitive uuid@8.3.2"
  - "Cross-user delete asserts 404 (matches handler's existence-oracle defence, D-08), not 403"

patterns-established:
  - "Integration tests assert real emulator Firestore state via Admin SDK read-back, never just the HTTP response"
  - "jest.config.js multi-project: unit (src/utils/__tests__) + integration (test/**, emulator setupFiles, maxWorkers:1)"

requirements-completed: [BACK-02, BACK-03, BACK-04]

duration: ~20min
completed: 2026-05-31
---

# Phase 10 Plan 03: Emulator-backed Integration Test Suite Summary

**46-test suite (27 unit + 19 emulator integration) proving auth-reject, write/soft-delete/restore, server-forced ownership, the 1001-trip DoS cap, 600-trip 2-batch chunking, cross-user isolation, and deny-all rules — all GREEN against the live Firebase Auth+Firestore emulator via supertest, zero mocks.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-05-31T20:42Z
- **Tasks:** 3
- **Files created:** 8 / modified: 3

## Accomplishments
- Reusable emulator harness: `mintIdToken(uid)` (emulator ID token `verifyIdToken` accepts for a known uid), Admin-SDK-to-emulator wiring, `clearFirestore`/`seedTrip`.
- Three handler suites driving the **live exported Express app** with supertest and asserting real emulator Firestore state via Admin-SDK read-back (no Firestore/auth mocks).
- Deny-all rules suite proving both anonymous and signed-in client contexts are denied read AND write of `trips/*`.
- jest config extended with an `integration` project while keeping the 10-01 `unit` project intact — `npm run test:unit` still discovers the 27 util tests.

## Test Command + Results (REAL)

Full suite (both jest projects), canonical entrypoint:
```
cd backend/functions && npm test
# -> firebase --project travey-298a7 --config ../firebase.json emulators:exec --only auth,firestore "jest --runInBand"
```
Result:
```
Test Suites: 7 passed, 7 total
Tests:       46 passed, 46 total
Ran all test suites in 2 projects.
```

Integration-only:
```
Test Suites: 5 passed, 5 total
Tests:       19 passed, 19 total
```

Unit-only (BLOCKER-2 — config extended, not replaced):
```
cd backend/functions && npm run test:unit
Test Suites: 2 passed, 2 total
Tests:       27 passed, 27 total
```

Breakdown of the 19 integration tests: harness smoke 4, sync-trips 6, delete-trip 5, restore-trips 2, deny-all rules 2.
Zero skipped tests (`grep .skip/xit/only` → none). Zero `jest.mock` of Firestore/auth.

## Criterion → Test Mapping (confirmed)

| Criterion | Test group | File | Status |
|-----------|-----------|------|--------|
| 4 — token rejection (no-token 401, bad-token 401) on all 3 endpoints | auth-reject ×3 | sync/delete/restore.test.ts | PASS |
| 1 — sync writes docs, forced userId, deleted:false | happy path | sync-trips.test.ts | PASS |
| 1 (hardening, D-08) — spoofed userId overwritten with token uid | server-forces-ownership | sync-trips.test.ts | PASS |
| 1 (M1 DoS cap) — 1001 trips → 400, zero docs written | DoS cap | sync-trips.test.ts | PASS |
| 1 (D-12 chunking) — 600 trips → 200, all 600 written across 2 batches | chunking | sync-trips.test.ts | PASS |
| 2 — soft-delete: deleted:true + deletedAt, doc still present | soft-delete | delete-trip.test.ts | PASS |
| 2 (D-08) — userA cannot delete userB's trip → 404, doc unchanged | cross-user ownership | delete-trip.test.ts | PASS |
| 3 — restore returns only caller's non-deleted trips (excludes deleted + other user) | filtered + isolation | restore-trips.test.ts | PASS |
| 5 (D-13) — deny-all blocks anon AND authed client read+write | deny-all | deny-all.test.ts | PASS |

## Task Commits

1. **Task 1: harness + extend jest config** — `9ea54fa` ([backend])
2. **Task 2: endpoint suites (sync/delete/restore)** — `e1eed0f` ([backend])
3. **Task 3: deny-all rules test + full green suite** — `af3bc59` ([backend])

## Handler Bug Found + Fixed

**[Rule 3 — Blocking] `src/index.ts` double-init of the Admin app.**
- **Found during:** Task 1 — the harness smoke test imports the exported `app`, but `src/index.ts` called bare `initializeApp()` while the integration setupFiles had already initialized the Admin app against the emulator. Firebase threw `"[DEFAULT]" already exists with a different configuration`, failing the whole suite to load.
- **Fix:** Guarded the init with `if (!getApps().length) initializeApp();`. Idempotent init is also correct for the production runtime (the Functions container may re-import). No handler logic changed.
- **Verification:** Harness smoke test then loaded and passed 4/4; full suite green.
- **Committed in:** `9ea54fa` (Task 1).

This was an init-safety bug exposed by the in-process import, not a behavioural handler bug — no test was weakened to accommodate it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Guarded initializeApp() in src/index.ts** — see "Handler Bug" above. Committed `9ea54fa`.

**2. [Rule 3 — Blocking] UUID fixtures via node:crypto instead of `uuid` package**
- **Found during:** Task 2 — fixtures imported `uuid`, but the transitive `uuid@8.3.2` ships no type declarations (TS7016) and is not a declared dependency.
- **Fix:** Switched all fixtures/tests to `node:crypto.randomUUID()` (Node 20, fully typed, produces valid v4 UUIDs the zod `.uuid()` schema accepts). Avoids adding a runtime dep on a transitive package or an `@types/uuid` dev dep.
- **Files modified:** test/helpers/fixtures.ts, test/handlers/delete-trip.test.ts, test/handlers/restore-trips.test.ts
- **Verification:** build clean; 13 handler tests green.
- **Committed in:** `e1eed0f` (Task 2).

**3. [Rule 3 — Blocking, planned] Added `@firebase/rules-unit-testing` dev dep**
- The plan's Task 3 explicitly calls for this; recorded as a dependency addition. Committed `af3bc59`.

---
**Total deviations:** 3 (all Rule 3 blocking; #1 is the handler init fix, #2 a dependency-typing fix, #3 the plan-specified rules dep). No scope creep — no test mocked or weakened.

## Issues Encountered
- **"Jest did not exit one second after the test run"** warning on integration runs: a benign Firestore gRPC keepalive socket left open by the Admin SDK. The `emulators:exec` script still exits 0 and the emulator tears down cleanly. Left as-is rather than adding `--forceExit`, which would risk masking a genuine hang. Not a test failure.
- **`PERMISSION_DENIED` console warnings** in the deny-all run are the EXPECTED denials being logged by the client SDK — exactly what `assertFails` asserts. Both rules tests pass.

## Environment Notes (no blockers)
- `java -version` → Java 26 present; emulators boot fine. No Java blocker.
- `firebase` CLI 15.19.0 on PATH (`/opt/homebrew/bin/firebase`), project `travey-298a7`. No port conflicts.

## Live Deploy (post-execution manual checkpoint — M3, NOT a plan task)
Per the plan `<deploy_note>`, "deployed" is a manual orchestrator step run AFTER this green suite, from `backend/`:
1. `java -version` (JVM present — confirmed above).
2. Ensure the Firestore (Native mode) DB exists in `travey-298a7`.
3. `firebase deploy --only functions,firestore:rules` (deploys the `api` function + deny-all rules together).
4. `firebase deploy --only firestore:indexes` (composite index for the restore two-equality query — avoids prod-only FAILED_PRECONDITION the emulator can't catch).
5. Smoke one endpoint with a real Firebase ID token (Node 20 runtime; surface Node 22 recommendation if deploy is blocked).

## Next Phase Readiness
- Backend is provably correct and secure on the emulator; green suite is the gate before deploy.
- Phase 11 (client sync) can consume the `Trip` contract and the three endpoints with confidence in auth, ownership, soft-delete, restore filtering, the DoS cap, and deny-all behaviour.
- Only remaining Phase 10 item is the manual live deploy checkpoint above.

## Self-Check: PASSED

All 8 created test files exist on disk; all 3 task commits (`9ea54fa`, `e1eed0f`, `af3bc59`) present in git history.

---
*Phase: 10-backend-infrastructure*
*Completed: 2026-05-31*
