---
phase: 10-backend-infrastructure
fixed_at: 2026-06-01T00:00:00Z
review_path: .planning/phases/10-backend-infrastructure/10-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 10: Code Review Fix Report

**Source review:** `.planning/phases/10-backend-infrastructure/10-REVIEW.md`
**Branch:** `gsd/phase-10-11-backend-sync`

## Summary

- Findings actioned: 5 (HI-01, ME-01, ME-03, LO-01, ME-02 note)
- Deferred per instructions: LO-02 (unbounded restore — documented v0.1 deferral), LO-03 (test-helper double-cast — not requested)
- Fixed: 5
- Skipped: 0

## Fixed Issues

### HI-01: `tripConverter` no-op cast / restore JSON-safety not enforced
**Files:** `src/utils/firestore.ts`, `src/handlers/restore-trips.ts`, `test/handlers/restore-trips.test.ts`
**Commit:** `618ddd0`
**Fix:** Rewrote `tripConverter.fromFirestore` to build `TripDoc` field-by-field (no blind `as TripDoc` cast) and coerce timestamp-shaped time fields (`startTime`/`endTime`/`createdAt`/`updatedAt`) to ISO strings via a `toIsoString` helper. `deletedAt`/`serverUpdatedAt` are normalized through the SDK `Timestamp` guard. `restore` continues to project to the client `Trip` shape, now backed by an enforcing (not asserting) read path; added a clarifying comment. Strengthened the restore integration test to assert all returned time fields match the ISO-8601 pattern and that `deleted`/`deletedAt`/`serverUpdatedAt` are absent from each returned trip.
**Test result:** restore integration suite green; ISO + no-metadata assertions pass.

### ME-01: dead code `src/utils/response.ts`
**Files:** `src/utils/response.ts` (deleted)
**Commit:** `546263a`
**Fix:** Confirmed via grep that `sendSuccess`/`sendError` are referenced only in their own definition file — all handlers and `/health` inline the `{statusCode, body}` shape. Deleted the file (CLAUDE.md forbids dead code; smallest-diff option from the review).
**Test result:** build/lint clean, no broken imports.

### ME-03: `sync` resurrects soft-deleted trip on re-sync (spec-conformant, undocumented)
**Files:** `src/handlers/sync-trips.ts`
**Commit:** `08e1e79`
**Fix:** Added a comment at the upsert site documenting that `deleted:false` deliberately resurrects a server-soft-deleted trip per D-11 (client-authoritative), so a future reader does not "fix" it into preserving `deleted:true`. No behavior change.
**Test result:** sync suite green (idempotency/ownership/batch tests unaffected).

### LO-01: loose bearer-token regex accepts whitespace-only token
**Files:** `src/utils/auth.ts`, `src/utils/__tests__/auth.test.ts`
**Commit:** `801d47d`
**Fix:** Tightened `extractBearerToken` from `/^Bearer (.+)$/` to `/^Bearer (\S+)$/` so empty/whitespace-only tokens are rejected as malformed (fail fast) rather than taking the SDK round-trip. Existing 27 unit tests used non-whitespace tokens and remained valid (no behavior they encoded changed). Added two unit tests asserting the new strict behavior (`Bearer ` and `Bearer    ` → AuthError).
**Test result:** auth unit tests green (29 unit tests total, up from 27).

### ME-02 (note only): CORS posture undeclared
**Files:** `src/index.ts`
**Commit:** `a085b6c`
**Fix:** Per instructions, did NOT add CORS (native Android `http` client needs none). Added a one-line comment recording the intentional omission and warning against `origin:'*'` for any future browser caller. No behavior change. (The `test:integration` script half of ME-02 was not requested and left as-is.)
**Test result:** no change to runtime behavior; suite green.

## Deferred (per instructions, not actioned)

- **LO-02** (restore has no `.limit()`): documented v0.1 deferral — left unchanged.
- **LO-03** (`seedTrip` double-cast in test helper): test-only nit, not requested — left unchanged.

## Verification (committed state)

- `npm run build` → clean (tsc, no `any`)
- `npm run lint` → clean (tsc --noEmit)
- `npm run test:unit` → **29 passed, 29 total** (2 suites)
- `npm test` (full emulator suite, auth+firestore, `jest --runInBand`) → **48 passed, 48 total** (7 suites), **0 skipped**, script exited 0

No tests were weakened or skipped. The only test change was strengthening the restore assertion (HI-01) and adding two strict-token tests (LO-01) — both assert correct behavior.

---

_Fixed: 2026-06-01_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
