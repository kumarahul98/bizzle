---
phase: 26
slug: sync-breaks-edit-metadata-to-cloud
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-12
---

# Phase 26 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (client unit/widget) + drift SchemaVerifier (migrations) + Jest 30 (backend; `unit` project fast, default project emulator-backed) |
| **Config file** | `test/generated_migrations/schema.dart` (client) · `backend/functions/jest.config.js` (backend) |
| **Quick run command** | `flutter test test/unit/sync/ test/unit/database/` · `cd backend/functions && npm run test:unit` |
| **Full suite command** | `flutter test` · `cd backend/functions && npm test` (Firestore + Auth emulators) |
| **Estimated runtime** | ~60 seconds (quick) / ~5 minutes (both full suites) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/sync/ test/unit/database/` (client tasks) and/or `cd backend/functions && npm run test:unit` (backend tasks)
- **After every plan wave:** Run `flutter test` AND `cd backend/functions && npm test` — phase spans both tiers
- **Before `/gsd:verify-work`:** Full suites green; backend deploy (`firebase deploy --only functions`) executed and verified per SC2 before any client task that emits new fields is mergeable
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | SC1 (zod schema shape) | V5 input validation | Bounded breaks array (.max), enum directionSource, ISO datetimes | unit | `cd backend/functions && npx jest --selectProjects unit utils/__tests__/validation.test.ts` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC1 (client wire contract) | — | toJson/fromJson round-trip 4 fields + breaks | unit | `flutter test test/unit/sync/trip_serializer_test.dart` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC3 (restore-then-edit) | — | Restored trip with breaks keeps paused time after edit | unit | `flutter test test/unit/sync/restore_controller_test.dart` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC4 (legacy-doc defaults) | — | fromFirestore on doc missing new fields returns defaults, no throw | integration | `cd backend/functions && npm test -- test/handlers/restore-trips.test.ts` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC4 (backfill once) | — | Marker-guarded auth transition enqueues exactly once | unit | `flutter test test/unit/` (new backfill test) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC5 (merge ride-along) | — | Breaks/pausedSeconds follow time-field winner (pure fn) | unit + widget | `flutter test test/unit/sync/merge_resolution_test.dart` + `flutter test test/widget/features/settings/conflict_resolution_sheet_test.dart` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | D-07 (metadata excluded) | — | Metadata-only difference never flags conflict | unit | `flutter test test/unit/sync/restore_controller_test.dart` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | Migration v6→v7 | — | Marker column defaults; existing rows survive | unit (SchemaVerifier) | `flutter test test/unit/database/migration_v7_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `backend/functions/src/utils/__tests__/validation.test.ts` — extend: 4 new fields accepted-omitted-with-defaults, oversized breaks rejected, invalid directionSource enum rejected
- [ ] `backend/functions/test/handlers/sync-trips.test.ts` — extend: new fields land in written Firestore doc (raw `db` handle from `test/helpers/emulator.ts`)
- [ ] `backend/functions/test/handlers/restore-trips.test.ts` — add legacy-doc-missing-fields case (seed via raw `db`, bypassing/extending `seedTrip`)
- [ ] `test/unit/sync/trip_serializer_test.dart` — create; round-trip 4 fields + breaks, empty-breaks and max-cap cases
- [ ] `test/unit/database/migration_v7_test.dart` — new, follow `migration_v6_test.dart` structure
- [ ] `test/unit/sync/merge_resolution_test.dart` — new; pin current 5-field merge contract BEFORE adding D-04 ride-along rules (25.1-01 convention)
- [ ] `test/unit/database/trip_breaks_dao_test.dart` — verify exists; extend with batch-query (`breaksForTripIds`) cases or create
- [ ] Resolve RESEARCH Pitfall 5 (duplicate `restore_controller_test.dart`) before adding cases

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Backend deploys before client emits new fields | SC2 | Deploy ordering is a process gate, not CI-testable | `firebase deploy --only functions` from `backend/`; verify deployed function version accepts new fields (e.g. curl a sync with breaks) BEFORE building/running the new client |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
