# Phase 10: Backend Infrastructure — Plan Check (Re-verification)

**Checked:** 2026-06-01 (re-verification after revision commit 22be806 — supersedes the prior FAIL)
**Plans verified:** 10-01, 10-02, 10-03 (all re-read in full)
**Prior verdict:** ⚠️ FAIL — 2 BLOCKERS, 4 MEDIUM, 3 LOW
**Verdict:** ✅ **PASS** — both blockers fixed, all four MEDIUMs resolved, no new contradictions introduced.

The revision pass cleanly closed every blocking and medium finding from the prior check. Version pins now match the verified RESEARCH table, the jest config double-definition is resolved (extend-not-overwrite), the DoS cap + composite index + UUID validation are in, and live deploy is explicitly recorded as a manual post-execution checkpoint. The still-solid items (5-criteria coverage, dependency order, CLAUDE.md compliance, live-emulator test genuineness, no skipped tests) all continue to hold.

---

## Prior Findings — Resolution Confirmation

### BLOCKER-1 — stale "no RESEARCH" note + wrong dependency majors → ✅ RESOLVED
- The false "NO `10-RESEARCH.md` exists" note is GONE. 10-01 `<notes>` (lines 132-138) now states version pins come from `10-RESEARCH.md` (npm-verified 2026-06-01) and explicitly calls out the "same major for @types/X and runtime X" rule.
- Version pins now match the RESEARCH Standard Stack table exactly (10-01 Task 1, lines 245-258):
  | Package | 10-01 pin (now) | RESEARCH verified | Match |
  |---|---|---|---|
  | firebase-functions | `^7.2.5` | `^7.2.5` | ✅ |
  | firebase-admin | `^13.10.0` | `^13.10.0` | ✅ |
  | express | `^5.2.1` | `^5.2.1` | ✅ |
  | @types/express | `^5.0.6` | match express major 5 | ✅ |
  | zod | `^4.4.3` | `^4.4.3` | ✅ |
  | typescript | `^5.5` | `^5.x` (TS6 avoided per A4/Open Q6) | ✅ |
  | jest / @types/jest | `^30.4.2` / `^30.0.0` | `^30` / `^30` | ✅ |
  | ts-jest | `^29.4.11` | `^29.4.11` | ✅ |
  | supertest | `^7.2.2` | `^7.2.2` | ✅ |
  | **@types/supertest** | **`^7.2.0`** | `^7.2.0` | ✅ (was `^6` — the flagged 6/7 mismatch is FIXED) |
- Every `@types/X` is now on the same major as its runtime X. The previously-mismatched `@types/supertest 6 vs supertest 7` is corrected to `^7.2.0` (10-01 line 257).

### BLOCKER-2 — jest.config.js defined twice / orphaned util tests → ✅ RESOLVED
- 10-01 OWNS `jest.config.js` and creates it with a `projects` array containing a single `unit` project (`src/utils/__tests__/**`), with inline comments instructing Plan 03 to APPEND, not replace (10-01 lines 280-298).
- 10-03 now EXTENDS rather than overwrites: Task 1 step 3 (lines 298-326) reads the existing config and APPENDS an `integration` project to the SAME `projects` array, keeping the `unit` project byte-for-byte. This is repeated in must_haves, objective, dependency_contract, verification, and success_criteria — consistently framed as "extend, not replace (BLOCKER-2)".
- `test:unit` (`jest --selectProjects unit`) is preserved intact (10-03 line 295) and explicitly re-verified after extension (10-03 verify line 344 + 461; must_have line 31). The `unit` util tests are no longer orphaned and `test:unit` no longer breaks.
- Project names are consistent: both plans use `displayName: 'unit'` and `'integration'` — no name mismatch. `--selectProjects unit` and `--selectProjects integration` references all align with these names.

### M1 — no array-length cap (DoS) → ✅ RESOLVED
- 10-01 validation.ts: `syncTripsBody = z.object({ trips: z.array(tripSchema).min(1).max(kMaxSyncBatchTrips) })` with `kMaxSyncBatchTrips = 1000` as a named constant (no magic number, per CLAUDE.md) (10-01 lines 365-378).
- Unit tests: empty array (0) rejected, 1000 accepted, 1001 rejected (10-01 Task 3 lines 425-427, 446-449).
- Integration tests: 1001 → 400 with zero docs written, AND a 600-trip → 200 across 2 chunks test (10-03 must_have line 27; Task 2 behavior lines 358-359; criterion_map lines 265-266).
- 10-02 sync handler relies on the schema cap (no separate length check) and the prior "accept the DoS risk" disposition (old T-10-07) is explicitly removed and re-dispositioned to "mitigate" (10-02 T-10-07 line 393).

### M2 — composite-index risk → ✅ RESOLVED
- `backend/firestore.indexes.json` is now a first-class artifact: listed in 10-01 `files_modified` (line 11), must_haves artifacts (lines 49-51), and created in Task 1 step 4 (lines 215-237) with the real composite index for the restore query (`userId` ASC, `deleted` ASC).
- `firebase.json` wires it: `"firestore": { "rules": "...", "indexes": "firestore.indexes.json" }` (10-01 Task 1 step 1, line 195), with a key_link + verify grep (`firestore.indexes.json` in firebase.json) and `node -e require` JSON-validity check (10-01 verify line 302).
- The restore handler note (10-02 line 296-303) and the deploy checkpoint (10-03 deploy_note step 4) both reference deploying this index to avoid the prod-only FAILED_PRECONDITION.

### M3 — "deployed" goal / no deploy task → ✅ RESOLVED
- 10-03 adds an explicit `<deploy_note>` (lines 106-127) stating live deploy is a POST-EXECUTION MANUAL checkpoint (M3), with the exact RESEARCH commands: `java -version`, `firestore:databases:create`, `firebase deploy --only functions,firestore:rules`, `firebase deploy --only firestore:indexes`, and a real-token curl smoke. Repeated in verification (line 472) and success_criteria (line 488). The "deployed" criterion is no longer silently dropped — it is consciously scoped as a manual step.

### M4 — weak uuid validation → ✅ RESOLVED
- `id` is `z.string().uuid()` and `tripIdParam` is `z.object({ tripId: z.string().uuid() })`, with explicit "do NOT downgrade to .min(1)" guards (10-01 lines 368-380). Tests assert NON-UUID id rejected and non-UUID tripId rejected (10-01 lines 422, 427). 10-03 fixtures are required to use valid UUIDs (line 391). Matches D-09 / RESEARCH Pattern 9.

### LOW-1 — Node 20 deprecation user heads-up → ✅ addressed
- 10-01 `<notes>` lines 139-143 + Task 1 line 242 surface the Node 20 (deprecated) / Node 22 (recommended) callout as an L1 note, with the deploy checkpoint (10-03 deploy_note step 5) repeating "if deploy is blocked, surface the Node 22 recommendation".

### LOW-2 / LOW-3 → resolved/non-issues (LOW-2 auto-resolved with BLOCKER-1; LOW-3 was never a real defect — forward-referenced SUMMARYs).

---

## Still-Solid Items — Re-confirmed

### 5 Success Criteria — full coverage (delivering task + proving test)
| # | Criterion | Delivering | Proving test | Status |
|---|-----------|-----------|--------------|--------|
| 1 | POST /trips/sync writes batch | 10-02 T1 | 10-03 sync happy-path + forced-uid + 600-chunk | ✅ |
| 2 | DELETE soft-deletes | 10-02 T2 (`deleted:true`, no `.delete()`) | 10-03 delete soft-delete + cross-user | ✅ |
| 3 | GET /trips/restore non-deleted only | 10-02 T2 (where uid + deleted==false) | 10-03 restore filter + isolation | ✅ |
| 4 | All endpoints reject without valid token | 10-01 auth.ts + 10-02 all handlers (auth first line) | 10-03 no-token + bad-token ×3 | ✅ |
| 5 | Deny-all rules | 10-01 firestore.rules | 10-03 deny-all.test.ts (anon + authed) | ✅ |

Requirement coverage BACK-02/03/04 present in all three plans' `requirements` frontmatter. ✅

### Dependency order 01→02→03
- 10-01 wave 1 `depends_on: []`; 10-02 wave 2 `depends_on: [10-01]`; 10-03 wave 3 `depends_on: [10-01, 10-02]`. Acyclic, no forward refs, wave = max(deps)+1. Independently executable in order. ✅

### CLAUDE.md backend rules
- Strict TS / no `any` (tsconfig strict + grep guards in 10-02 verify line 402); verify→validate→trust ordering (10-02 mandates auth-first, verify line 404); zod at entry; FirestoreDataConverter; deny-all; server-forced uid; soft-delete only (grep `.delete(` absent, 10-02 verify line 406); consistent response shape; one handler per file. All honored. ✅

### Test genuineness (D-15) — live emulator, not mocks
- Handler tests drive the live exported Express `app` via supertest and assert real emulator Firestore state via Admin SDK read-back; `grep jest.mock test/` must return nothing for firestore/auth (10-03 verify lines 466-467). Emulator token mint via createCustomToken → signInWithCustomToken REST (RESEARCH Approach A). ✅

### No skipped tests
- Zero-skip guard in must_haves, both task `<done>` blocks, and verification grep (`.skip|xit|xdescribe|test.todo` → nothing), 10-03 lines 21, 422-423, 463. ✅

---

## New-Contradiction Scan (introduced by the edits)

| Check | Result |
|-------|--------|
| express 5 vs 4 references | ✅ Consistent — all references are express `^5` / `@types/express ^5`; 10-02 line 352 confirms "pinned express ^5". No stray express 4. |
| @types/supertest 6 vs 7 | ✅ Fixed to `^7.2.0` everywhere; no `^6` remnant. |
| zod 3 vs 4 | ✅ `^4.4.3` only; no zod 3 reference. |
| firebase-functions 6 vs 7 | ✅ `^7.2.5` only; no `^6`. |
| jest project name mismatch (`unit`/`integration`) | ✅ Names match across 10-01 + 10-03; `--selectProjects` flags use the exact names. |
| `test:unit` script consistency | ✅ Defined in 10-01 (`jest --selectProjects unit`), preserved + re-verified in 10-03. |
| jest `--runInBand` vs `maxWorkers:1` | ✅ No conflict — `--runInBand` forces global serial; `integration` project's `maxWorkers:1` is consistent/redundant, not contradictory. |
| Cross-user delete disposition (403 vs 404) | ✅ 10-02 firmly specifies 404 (no existence leak, D-08); 10-03 accepts "403 or 404" in the test assertion — tolerant superset of the handler's 404, not a contradiction. |
| firestore.indexes.json path/wiring | ✅ Created in 10-01, wired in firebase.json, referenced by 10-02 restore + 10-03 deploy_note — consistent. |
| MISSING automated verify | ✅ None — every task has runnable `<automated>` verify commands. |

No new contradictions found.

---

## Nyquist / Automated-Verify (Dimension 8)
- VALIDATION.md note: this phase carries its validation architecture inside RESEARCH.md ("Validation Architecture" section) rather than a separate VALIDATION.md; the per-task `<automated>` verify blocks are present on all tasks (build, grep contracts, emulator curl, `test:unit`, emulators:exec jest). Wave 0 test scaffolding is owned by 10-03 Task 1 (jest config + harness) before the handler suites in Task 2/3. Sampling continuity holds (every wave has automated verify). ✅

---

## Recommendation

**PASS — plans are ready for execution.** Both prior blockers and all four MEDIUM findings are resolved with consistent, cross-referenced edits; no new contradictions were introduced by the revision. Coverage of the 5 success criteria, dependency order (01→02→03), CLAUDE.md compliance, live-emulator test genuineness, and the no-skipped-tests guard all remain solid.

Residual non-blocking note (carry into execution, not a plan defect): the M2 composite index and M3 live deploy are correctly scoped as a MANUAL post-execution checkpoint (10-03 `<deploy_note>`). The orchestrator/developer must actually run those deploy + Firestore-provisioning + Java-check steps for the literal "deployed" ROADMAP goal to be satisfied in prod — the plans deliver a green emulator suite, which is the correct execution boundary.

**FINAL VERDICT: ✅ PASS — proceed to `/gsd-execute-phase 10`.**
