---
phase: 26-sync-breaks-edit-metadata-to-cloud
plan: 05
subsystem: sync
tags: [restore, conflicts, breaks, enrichment, drift, transactions]

# Dependency graph
requires:
  - phase: 26-03
    provides: ParsedTrip record shape from ApiClient.restoreTrips() with break companions materialized at the exact restore() call site
  - phase: 26-02
    provides: TripBreaksDao.breaksForTrip/insertBreaks + kDirectionSourceTime constant
provides:
  - "RestoreConflict (both variants) carries cloudBreaks + localBreaks, default const [] — Plan 06's merge/indicator work needs no further DB reads"
  - "D-07: _isDifferent excludes totalPausedSeconds/directionSource/isEdited (and breaks) — metadata never triggers a same-UUID conflict"
  - "restore() split insert path: bulk insertOrIgnoreTrips for breakless new trips; per-trip db.transaction (trip row then break rows) for trips with breaks"
  - "D-10/D-11 enrichment: same-UUID non-conflicting local trips adopt cloud breaks/metadata per-field ONLY when local value is still default"
affects: [26-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-field default-vs-real enrichment guard: each metadata field adopted independently, only default→real, never real→anything (T-26-13)"
    - "Split bulk/transactional insert path keyed on child-row presence (RESEARCH.md Pitfall 2 resolution)"

key-files:
  created: []
  modified:
    - lib/sync/restore_conflict.dart
    - lib/sync/restore_controller.dart
    - test/unit/sync/restore_controller_test.dart
    - test/sync/restore_controller_test.dart

key-decisions:
  - "test/sync/restore_controller_test.dart KEPT (not deleted): its overlap-conflict tests (>1min flags, <=1min ignored) are genuinely NOT covered by the test/unit/sync copy, so per the plan's Pitfall-5 conditional it received the shape fixes (in-memory AppDatabase overrides for the eager appDatabaseProvider/tripBreaksDaoProvider reads)"
  - "Enrichment write does NOT bump updatedAt: the plan locks the enrichment companion to id + ONLY the enrichable fields (everything else Value.absent()), and a pure-download enrichment should not make the local row look newer than the cloud copy"
  - "updateTrip skipped inside the enrichment transaction when only breaks are enrichable — avoids writing an all-absent companion"

patterns-established:
  - "Conflict objects carry both sides' child rows (cloudBreaks/localBreaks) so downstream UI never re-queries"

requirements-completed: []

duration: ~20min
completed: 2026-07-13
---

# Phase 26 Plan 05: Restore-side Breaks + Metadata (D-07/D-10/D-11) Summary

**restore() now consumes ParsedTrip end-to-end: metadata differences never spawn conflicts (D-07), new trips with breaks insert atomically, and existing default-metadata local trips are enriched per-field from the cloud — all without ever touching sync_queue.**

## Performance

- **Duration:** ~20 min (2026-07-13T01:16Z → 01:36Z)
- **Tasks:** 3 completed
- **Files modified:** 4

## Accomplishments

- `RestoreConflict` base + both variants gain `cloudBreaks` (`List<TripBreaksCompanion>`) and `localBreaks` (`List<TripBreakRow>`), both defaulting to `const []` — all 5 pre-existing widget-test call sites compiled unchanged (backward-compat verified by the conflict-sheet suite)
- D-07: `_isDifferent` dropped its `totalPausedSeconds`/`directionSource`/`isEdited` checks; a locked doc comment explains WHY (conflict-prompt storm on first post-upgrade restore, T-26-14) so no future reader re-adds them
- `restore()` rewired to iterate `ParsedTrip`s: conflicts now carry both sides' breaks (one `breaksForTrip` fetch per conflict); new trips split into a breakless bulk path (`insertOrIgnoreTrips`, unchanged) and a per-trip `db.transaction()` path (trip row THEN break rows — a crash can never separate them, RESEARCH.md Pitfall 2)
- D-10/D-11 `_enrichFromCloud`: each of the 4 metadata fields adopted independently, only when local is at its default (breaks empty / paused 0 / source `'time'` / not edited) AND cloud carries a real value — a real local value is provably never replaced (T-26-13); all writes in ONE transaction, zero sync_queue rows
- 13 new tests across 4 groups (D-07, atomic insert, D-10/D-11, SC3 restore-then-edit) — SC3 proves restored breaks + `totalPausedSeconds` survive a direction-only `editTrip(breaks: null)`

## Task Commits

Each task was committed atomically:

1. **Task 1: RestoreConflict shape + D-07 _isDifferent subtraction** - `7c3703c` (feat)
2. **Task 2: Rewire restore() — ParsedTrip, split insert path, D-10/D-11 enrichment** - `1654b81` (feat)
3. **Task 3: D-07/D-10/D-11/atomic/SC3 coverage + Pitfall-5 resolution** - `9596cd5` (test)

_Note: Tasks 1–2 were `tdd="true"` but landed as combined test+impl commits — the plan itself assigns ALL new behavior coverage to Task 3 (Task 2's action item 6 explicitly forbids adding tests there), so there is no meaningful standalone RED state per task. Every commit was preceded by a green run of its plan-specified verify gate; no untested code was committed. Same pragmatic pattern documented in 26-02/26-03._

## Files Created/Modified

- `lib/sync/restore_conflict.dart` - abstract `cloudBreaks`/`localBreaks` on the sealed base; optional-with-default fields on both variants
- `lib/sync/restore_controller.dart` - D-07 subtraction with locked doc comment; ParsedTrip loop; conflict construction fetches local breaks; split bulk/transactional insert; `_enrichFromCloud` helper; class doc updated to the new contract
- `test/unit/sync/restore_controller_test.dart` - `_FakeApiClient.parsed` + `_parsedTrip`/`_tripJson` metadata/breaks helpers; container overrides gain `appDatabaseProvider`/`tripBreaksDaoProvider`; 4 new groups (13 tests)
- `test/sync/restore_controller_test.dart` - kept per Pitfall-5 conditional (unique overlap coverage); in-memory `AppDatabase` + provider overrides added for the eager Phase 26 provider reads

## Decisions Made

- **Pitfall 5 resolved as KEEP-and-fix:** the duplicate's two overlap tests (`> 1 min` flags `OverlapConflict`, `<= 1 min` ignored) have no equivalent in the `test/unit/sync/` copy, so deletion would have lost real coverage. It received the minimal shape fixes (real in-memory DB backing `appDatabaseProvider`/`tripBreaksDaoProvider`; its trip fakes untouched).
- **Enrichment never bumps `updatedAt`:** the plan locks the companion to id + enrichable fields only; a restore-side enrichment is a download and should not make the local row look newer than its cloud source.
- **`updateTrip` call skipped when only breaks are enrichable** — writing a companion with zero present columns would be a pointless (and potentially throwing) UPDATE.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] test/unit/sync container fixture missing the newly-read providers**
- **Found during:** Task 2 verification (`flutter test test/unit/sync/restore_controller_test.dart`)
- **Issue:** `restore()` now reads `appDatabaseProvider` + `tripBreaksDaoProvider` eagerly; the test container overrode neither, so the real `AppDatabase` constructor hit platform channels and every restore test errored to `RestoreError`.
- **Fix:** Added `appDatabaseProvider.overrideWithValue(db)` and `tripBreaksDaoProvider.overrideWithValue(db.tripBreaksDao)` to the existing `containerWith` helper — minimal fixture adaptation, no behavior change.
- **Files modified:** `test/unit/sync/restore_controller_test.dart`
- **Commit:** 1654b81

**2. [Rule 3 - Blocking] test/sync duplicate broken by the same provider reads**
- **Found during:** Task 2 verification (observed), fixed in Task 3 (its plan-assigned owner)
- **Issue:** Same root cause — no `appDatabaseProvider` override → `RestoreError` in 4 of its 5 tests.
- **Fix:** In-memory `AppDatabase` in `setUp` + the two provider overrides; closed in `tearDown`. Handled inside Task 3 because the plan explicitly assigns this file's fate (Pitfall 5) to Task 3.
- **Files modified:** `test/sync/restore_controller_test.dart`
- **Commit:** 9596cd5

---

**Total deviations:** 2 auto-fixed (both Rule 3 — direct consequences of the plan's own instructed provider reads). No scope creep.

## TDD Gate Compliance

All three tasks are `type="auto" tdd="true"`. Gate sequence in git: `feat` (7c3703c) → `feat` (1654b81) → `test` (9596cd5). There is no standalone RED commit: the plan concentrates ALL new-behavior test authorship in Task 3 (Task 2's action item 6: "Do NOT add new test cases here") while Tasks 1–2 use pre-existing suites as backward-compat/smoke gates — so a failing-first commit per task was structurally impossible without violating the plan's own task boundaries. Every commit shipped with its specified verify gate green.

## Verification

- Task 1: `flutter test test/widget/features/settings/conflict_resolution_sheet_test.dart` — 4/4 green (default-args backward compat); grep confirms metadata field names appear only in `_isDifferent`'s D-07 doc comment; analyze clean (info count dropped 13→10, all pre-existing style infos).
- Task 2: `flutter analyze lib/sync/restore_controller.dart` — zero errors/warnings; `flutter test test/unit/sync/restore_controller_test.dart` — 9/9 pre-existing tests green against the rewired restore(); greps: `database.transaction`/`appDatabaseProvider` ×3, `enqueueCreate|enqueueUpdate` ×0.
- Task 3: `flutter test test/unit/sync/restore_controller_test.dart` — 17/17 green (13 new); `flutter test test/sync/restore_controller_test.dart` — 5/5 green; **full `flutter test` — 634 passed, 10 pre-existing skips, zero regressions**; `flutter analyze` on all touched files — zero errors/warnings.
- Threat register: T-26-13 mitigated (per-field default-only guard, test-pinned by the D-11 never-overwrite test); T-26-14 mitigated (D-07 subtraction, test-pinned by both metadata-only-no-conflict tests); T-26-15 accepted per plan (no-enqueue contract test-pinned in both the atomic-insert and enrichment tests).

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, file access, or schema surface beyond the `<threat_model>`'s registered items.

## Next Phase Readiness

- Plan 06 (conflict-sheet breaks indicator + merge handling) can read `conflict.cloudBreaks`/`conflict.localBreaks` directly — no DB reads needed, `kConflictBreaksDifferTemplate` already in constants.
- Restore now losslessly reproduces a trip's v0.3 metadata (roadmap SC1/SC3/SC4/SC5 restore-side half done).
- No blockers. Full suite and analyze green at HEAD.

---
*Phase: 26-sync-breaks-edit-metadata-to-cloud*
*Completed: 2026-07-13*

## Self-Check: PASSED

All 4 claimed modified files exist on disk; commits 7c3703c, 1654b81, 9596cd5 verified in git history.
