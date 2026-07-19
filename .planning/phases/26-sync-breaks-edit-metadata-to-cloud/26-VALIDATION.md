---
phase: 26
slug: sync-breaks-edit-metadata-to-cloud
status: final
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-12
updated: 2026-07-12
---

# Phase 26 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Updated 2026-07-12 (revision issue 5): reflects the finalized 6-plan / 4-wave structure.
> No separate Wave 0 exists — every test file is created or extended INLINE in the same
> `tdd="true"` task as the code it proves (behavior blocks written before implementation).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (client unit/widget) + drift SchemaVerifier (migrations) + Jest 30 (backend; `unit` project fast, `integration` project emulator-backed) |
| **Config file** | `test/generated_migrations/schema.dart` (client) · `backend/functions/jest.config.js` (backend) |
| **Quick run command** | `flutter test test/unit/sync/ test/unit/database/` · `cd backend/functions && npm run test:unit` |
| **Full suite command** | `flutter test` · `cd backend/functions && npm test` (Firestore + Auth emulators) |
| **Estimated runtime** | ~60 seconds (quick) / ~5 minutes (both full suites) |

---

## Sampling Rate

- **After every task commit:** Run the task's own `<automated>` verify (see map below) — client tasks stay under 90s; backend integration tasks (26-01 T2) use a SCOPED emulator run (only the 2 touched handler suites via `emulators:exec "jest --runInBand test/handlers/sync-trips.test.ts test/handlers/restore-trips.test.ts"`), not the full `npm test`
- **After every plan wave:** Run `flutter test` AND (for waves touching backend) `cd backend/functions && npm test` — phase spans both tiers
- **Before `/gsd:verify-work`:** Full suites green; backend deploy (`firebase deploy --only functions`) executed and verified per SC2 (26-01 Task 3) before any Wave 2+ client plan that emits new fields runs
- **Max feedback latency:** 90 seconds for all client tasks and backend unit tasks; documented exception: 26-01 Task 2's scoped emulator run (~2 min) — Firestore-converter/handler behavior is emulator-only by nature, and the full ~5-min `npm test` is reserved for the Task 3 pre-deploy gate (revision issue 4)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 26-01-T1 | 26-01 | 1 | SC1 (zod schema shape) | T-26-01/02/03 | Bounded breaks array (.max 50), enum directionSource, per-break ISO datetimes, nonneg ints | unit | `cd backend/functions && npm run build && npm run test:unit` | inline (T1 extends validation.test.ts) | ⬜ pending |
| 26-01-T2 | 26-01 | 1 | SC1 (Firestore round-trip) + SC4 (legacy-doc defaults) | T-26-04 | fromFirestore defaults 4 fields on legacy docs, no throw; write path lossless | integration (scoped) | `cd backend/functions && npm run build && firebase --project travey-298a7 --config ../firebase.json emulators:exec --only auth,firestore "jest --runInBand test/handlers/sync-trips.test.ts test/handlers/restore-trips.test.ts"` | inline (T2 extends both handler suites) | ⬜ pending |
| 26-01-T3 | 26-01 | 1 | SC2 (deploy-before-client gate) | T-26-06 | Auth gate live: /health 200, unauthed sync/restore 401 | full suite + live smoke | `npm test` (pre-deploy) then `curl -s -o /dev/null -w "%{http_code}" .../health` | n/a (deploy record: 26-DEPLOY.md) | ⬜ pending |
| 26-02-T1 | 26-02 | 1 | Migration v6→v7 (D-03 marker column) | T-26-07 | Additive-only migration; existing rows survive; marker defaults 0 | unit (SchemaVerifier) | `flutter test test/unit/database/migration_v7_test.dart test/unit/database/migration_v6_test.dart` | inline (T1 creates migration_v7_test.dart) | ⬜ pending |
| 26-02-T2 | 26-02 | 1 | Batch break lookup + D-03 marker DAO + Phase 26 constants | — | Single IN query (no N+1); single-column marker upsert | unit | `flutter test test/unit/database/trip_breaks_dao_test.dart test/unit/database/user_preferences_dao_test.dart` | inline (T2 extends both DAO suites) | ⬜ pending |
| 26-03-T1 | 26-03 | 2 | SC1 (client wire contract) + 50-break client truncation | T-26-18 | toJson caps breaks at kMaxBreaksPerTrip (oldest-first) — no 400 poison pill; fromJson defaults on omission | unit | `flutter test test/unit/sync/trip_serializer_test.dart` | inline (T1 creates trip_serializer_test.dart) | ⬜ pending |
| 26-03-T2 | 26-03 | 2 | SC1 (engine batch-fetch + emit) | T-26-10 | breaksForTripIds called once per drain; breaks passed to syncTrips | unit | `flutter test test/unit/sync/sync_engine_test.dart` | inline (T2 extends sync_engine_test.dart) | ⬜ pending |
| 26-03-T3 | 26-03 | 2 | Signature-ripple compile fixes (no new coverage) | — | No test file left non-compiling | unit + widget | `flutter test test/unit/sync/ test/widget/features/settings/conflict_resolution_sheet_test.dart test/sync/restore_controller_test.dart` | existing files, mechanical fixes | ⬜ pending |
| 26-04-T1 | 26-04 | 2 | SC4 (D-01 backfill candidate query) | — | breaks/isEdited/directionSource candidates, no duplicate ids | unit | `flutter test test/unit/database/trips_dao_test.dart` | inline (T1 extends trips_dao_test.dart) | ⬜ pending |
| 26-04-T2 | 26-04 | 2 | SC4 (backfill exactly-once, D-02/D-03) | T-26-12 | Marker-guarded; sequenced after auto-restore; second sign-in no-op | widget | `flutter test test/widget/features/shell/main_shell_test.dart` | inline (T2 extends main_shell_test.dart) | ⬜ pending |
| 26-05-T1 | 26-05 | 3 | D-07 (metadata excluded from conflict detection) | T-26-14 | Metadata-only diff never flags conflict; 8 real-field checks intact | widget (backward-compat) | `flutter test test/widget/features/settings/conflict_resolution_sheet_test.dart` | existing file (compat proof) | ⬜ pending |
| 26-05-T2 | 26-05 | 3 | Restore rewire (ParsedTrip, split insert, D-10/D-11 impl) | T-26-13 | Enrichment never overwrites real local values; no sync_queue writes | analyze + smoke (pre-existing suite) | `flutter analyze lib/sync/restore_controller.dart && flutter test test/unit/sync/restore_controller_test.dart` | existing file (smoke gate) | ⬜ pending |
| 26-05-T3 | 26-05 | 3 | SC3 (restore-then-edit) + D-07/D-10/D-11 coverage + Pitfall 5 | T-26-13/14 | Restored breaks/paused time survive direction-only edit; atomic trip+breaks insert | unit | `flutter test test/unit/sync/restore_controller_test.dart` | inline (T3 adds 4 new groups) | ⬜ pending |
| 26-06-T1 | 26-06 | 4 | D-06 (merge extraction, pin current 5-field contract) | — | Extraction preserves behavior byte-for-byte (pre-existing widget suite still green) | unit + widget | `flutter test test/unit/sync/merge_resolution_test.dart test/widget/features/settings/conflict_resolution_sheet_test.dart` | inline (T1 creates merge_resolution_test.dart) | ⬜ pending |
| 26-06-T2 | 26-06 | 4 | SC5 (D-04 ride-along + Use-Cloud breaks) + D-05 indicator | T-26-16/17 | Breaks follow time-field winner; transactional tripId-remapped writes; read-only indicator | unit + widget | `flutter test test/unit/sync/merge_resolution_test.dart test/widget/features/settings/conflict_resolution_sheet_test.dart` | inline (T2 extends both suites) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 → Inline-Per-Task (superseded)

There is NO separate Wave 0 test-scaffold plan in the finalized structure. Every item below is
created or extended INLINE within the `tdd="true"` task that implements the matching behavior
(each task's `<behavior>` block defines expectations before implementation), so no task ever has
a `MISSING` automated verify:

- [x] `backend/functions/src/utils/__tests__/validation.test.ts` — extended in **26-01 T1** (defaults-on-omission, over/at-cap breaks, enum, bad timestamps, negative ints)
- [x] `backend/functions/test/handlers/sync-trips.test.ts` — extended in **26-01 T2** (new fields land in raw Firestore doc)
- [x] `backend/functions/test/handlers/restore-trips.test.ts` — extended in **26-01 T2** (SC4 legacy-doc-missing-fields via raw `db` seed + round-trip case)
- [x] `test/unit/database/migration_v7_test.dart` — created in **26-02 T1** (mirrors migration_v6_test.dart structure)
- [x] `test/unit/database/trip_breaks_dao_test.dart` — extended in **26-02 T2** (`breaksForTripIds` batch cases)
- [x] `test/unit/sync/trip_serializer_test.dart` — created in **26-03 T1** (round-trip, empty-breaks, at-cap, >50 truncation)
- [x] `test/unit/sync/merge_resolution_test.dart` — created in **26-06 T1** (pins CURRENT 5-field merge contract BEFORE D-04 ride-along lands in T2 — 25.1-01 pin-before-change convention)
- [x] Resolve RESEARCH Pitfall 5 (duplicate `test/sync/restore_controller_test.dart`) — compile-triaged in **26-03 T3**, final delete-or-fix call in **26-05 T3**

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Backend deploys before client emits new fields | SC2 | Deploy ordering is a process gate; live happy-path needs a real Google ID token (not available headlessly) | Automated within 26-01 T3: full `npm test` pre-deploy, `firebase deploy --only functions --project travey-298a7`, 3 curl smoke checks (200/401/401), recorded in `26-DEPLOY.md`. Remaining manual wake-up check: sign in on a real device, sync a trip with breaks, confirm the Firestore `trips/{id}` doc carries all 4 new fields |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or inline test creation in the same task (no MISSING references — see map)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (every task has one)
- [x] Wave 0 superseded: all formerly-Wave-0 test files are created/extended inline per task (see section above)
- [x] No watch-mode flags (no `--watch`/`test:watch` in any verify command)
- [x] Feedback latency < 90s for all client and backend-unit tasks; documented exception: 26-01 T2's scoped emulator run (~2 min, emulator-only behavior) and 26-01 T3's full-suite pre-deploy gate (~5 min, wave-boundary gate per revision issue 4)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved (planner revision, 2026-07-12 — reflects 26-01..26-06 as revised for checker issues 1-6)
