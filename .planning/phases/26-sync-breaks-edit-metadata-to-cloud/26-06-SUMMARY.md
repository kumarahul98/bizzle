---
phase: 26-sync-breaks-edit-metadata-to-cloud
plan: 06
subsystem: sync
tags: [drift, conflict-resolution, merge, breaks, transactions]

# Dependency graph
requires:
  - phase: 26-05
    provides: RestoreConflict.cloudBreaks/localBreaks (both sides' break lists, no further DB reads needed) + D-07 exclusion
  - phase: 26-02
    provides: kConflictBreaksDifferTemplate constant + TripBreaksDao (deleteBreaksForTrip/insertBreaks)
  - phase: 25.1-02
    provides: Merge default flipped to 'local' at all 5 field ternaries — preserved byte-for-byte by this plan's extraction
provides:
  - "lib/sync/merge_resolution.dart: resolveMerge({local, cloud, selections, localBreaks, cloudBreaks}) -> {trip, breaks} — pure, independently-unit-tested merge function"
  - "D-04 ride-along: breaks + totalPausedSeconds follow the startTime winner; directionSource follows the direction winner; isEdited always true in merge output"
  - "Use Cloud (bulk and per-trip) now also replaces local trip_breaks with cloud's breaks, closing the SC5 gap beyond Merge alone"
  - "Both Use-Cloud and Merge branches write trip + breaks atomically inside one database.transaction (T-26-17 — Use Cloud was NOT transactional before this plan)"
  - "D-05 read-only 'Local: N breaks · Cloud: M breaks' indicator in the conflict sheet, shown only when counts differ, for any resolution choice"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Winning-side breaks are always rebuilt with fresh UUIDs and tripId remapped to the LOCAL trip's id — never the parsed/losing side's original id (T-26-16)"
    - "Extract-then-pin-then-extend: a pure function is carved out of a widget's inline logic and unit-tested against the CURRENT contract BEFORE new behavior is layered on top (D-06 sequencing)"

key-files:
  created: []
  modified:
    - lib/sync/merge_resolution.dart
    - test/unit/sync/merge_resolution_test.dart
    - lib/features/settings/widgets/conflict_resolution_sheet.dart
    - test/widget/features/settings/conflict_resolution_sheet_test.dart

key-decisions:
  - "Task 2's ride-along fields (breaks, totalPausedSeconds, directionSource) all reuse the SAME resolved boolean the pre-existing startTime/direction ternaries already compute — no new/independent selection keys were introduced, per the plan's explicit instruction"
  - "cloud.totalPausedSeconds/directionSource are read via their Value.present guard (falling back to local's value if the cloud companion didn't carry the column) rather than assumed always-present, matching the defensive pattern already used elsewhere for optional TripsCompanion fields"
  - "The D-05 breaks-differ indicator is rendered as a sibling of the RadioListTile group, visible for ANY selected resolution (not gated behind Merge) — informational regardless of which action the user is about to take"

patterns-established:
  - "Winning-side breaks rebuilt with fresh UUIDs + tripId always remapped to the trip id under which the row is actually written (never a parsed/foreign trip id)"

requirements-completed: []

duration: ~10min (this session; Task 1 was committed in a prior session)
completed: 2026-07-13
---

# Phase 26 Plan 06: Merge Resolution Extraction + D-04/D-05 Breaks Ride-Along Summary

**Extracted `_applyAll`'s inline Merge logic into a pure, unit-tested `resolveMerge` function, then layered D-04's breaks/metadata ride-along rules on top; Use Cloud now also carries breaks (closing the SC5 gap) and both Use-Cloud and Merge writes are transactional; the conflict sheet shows a read-only breaks-differ indicator per D-05 — this is the last plan in Phase 26.**

## Performance

- **Duration:** ~10 min active work this session (Task 2 verification + commit); Task 1 was executed and committed (`5971d0f`) in a prior session before this executor was spawned
- **Completed:** 2026-07-13T02:24:10Z
- **Tasks:** 2 completed
- **Files modified:** 4

## Accomplishments

- `lib/sync/merge_resolution.dart`'s `resolveMerge` extracted verbatim from `_applyAll`'s inline Merge-branch `copyWith` chain (D-06 step 1), pinned by 5 pure-function unit tests covering the empty-selections-all-local default, per-field independence, and the `id`/`updatedAt` remap — with the pre-existing widget suite still green unchanged, proving the extraction was behavior-preserving
- D-04 ride-along layered on top (step 2): `breaks` and `totalPausedSeconds` follow whichever side won `startTime` (reusing the SAME resolved boolean, no new selection key); `directionSource` follows the `direction` field's own selection; `isEdited` is unconditionally `true` in merge output
- Winning-side breaks are always rebuilt with fresh UUIDs and `tripId` remapped to `local.id` — closing T-26-16 (a break could otherwise carry a foreign/parsed trip id)
- `kConflictUseCloud`'s branch (both bulk "Use All Cloud" and per-trip overrides) now also deletes+re-inserts the local trip's breaks from `conflict.cloudBreaks`, remapped to the local trip id — this closes the SC5 gap that existed beyond Merge alone
- Both the Use-Cloud and Merge branches now wrap `updateTrip` + `deleteBreaksForTrip` + `insertBreaks` in one `database.transaction()` — Use Cloud was NOT transactional before this plan (T-26-17)
- D-05: a read-only `Text` row using `kConflictBreaksDifferTemplate` appears in each conflict's expanded tile whenever `localBreaks.length != cloudBreaks.length`, visible for any resolution choice, with no per-break controls

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract resolveMerge as a pure function, pin the CURRENT 5-field behavior (D-06 step 1)** - `5971d0f` (test) — committed in a prior session before this executor run
2. **Task 2: D-04 ride-along rules + Use-Cloud breaks carry-along + D-05 indicator** - `6a001b4` (feat)

_Note: Task 1's implementation and test files were found already fully written and committed on `main` when this execution began (the working tree also already contained Task 2's uncommitted changes). This session's work was to verify Task 2's implementation against every `<behavior>`/`<acceptance_criteria>` bullet in the plan, run the full verification suite, and commit it — no code was rewritten, since the existing implementation matched the plan's specification exactly._

## Files Created/Modified

- `lib/sync/merge_resolution.dart` - `resolveMerge` gains `localBreaks`/`cloudBreaks` params; computes winning-side breaks (fresh UUID, `tripId` remapped to `local.id`); `totalPausedSeconds`/`directionSource` follow their respective field winners; `isEdited` forced `true`
- `test/unit/sync/merge_resolution_test.dart` - new `'resolveMerge — D-04 ride-along rules'` group: local-wins breaks, cloud-wins breaks, `totalPausedSeconds` follows time winner, `directionSource` follows direction winner, `isEdited` always true
- `lib/features/settings/widgets/conflict_resolution_sheet.dart` - `_applyAll` injects `tripBreaksDaoProvider`/`appDatabaseProvider`; Merge branch calls `resolveMerge(..., localBreaks:, cloudBreaks:)` and writes trip+breaks in one transaction; `kConflictUseCloud` branch remaps `conflict.cloudBreaks` to the local trip id and writes trip+breaks in the same transactional shape; new D-05 `Text` indicator row using `kConflictBreaksDifferTemplate`
- `test/widget/features/settings/conflict_resolution_sheet_test.dart` - new cases: D-05 indicator visible when counts differ, D-05 indicator absent when counts are equal (including both-zero), "Use All Cloud" on a conflict with differing breaks replaces `trip_breaks` rows with cloud's; all 3 pre-existing tests (Use All Cloud round-trip, per-trip overrides, field-by-field Merge) still pass unchanged plus the 25.1-02 two-differing-field Merge test

## Decisions Made

- **Reused the existing resolved booleans for all ride-along fields** — `useLocalTime` (from the `startTime` ternary) drives both `breaks` and `totalPausedSeconds`; `useLocalDirection` (from the `direction` ternary) drives `directionSource`. No new/independent selection key was introduced, exactly as the plan's action item specified.
- **`cloud.totalPausedSeconds`/`cloud.directionSource` read via `.present` guard** with a fallback to local's value — defensive against a `TripsCompanion` that didn't carry those optional columns present, consistent with how the rest of the merge companion already treats optional cloud fields.
- **D-05 indicator is unconditional on selected action** — it renders as a sibling of the `RadioListTile` group and the per-field `SegmentedButton` block, visible regardless of whether Keep Local/Use Cloud/Merge is currently selected, matching D-05's "shown only when the two sides differ" with no action-gating language.

## Deviations from Plan

None — plan executed exactly as written. Task 2's implementation (found already present in the working tree at session start) matches every `<action>` step and `<behavior>` bullet in the plan verbatim: reused selection booleans, fresh-UUID break rebuilding with `tripId` remapped to `local.id`, transactional writes in both Use-Cloud and Merge branches, and the D-05 indicator placed as a sibling (not nested inside) the per-field toggle loop.

## Issues Encountered

None. This executor run began with Task 1 already committed (`5971d0f`) and Task 2's full implementation already present but uncommitted in the working tree (from an interrupted prior session). Verification (both targeted test files, `flutter analyze` on touched files, the full `flutter test` suite, and whole-project `flutter analyze`) all confirmed the existing code satisfied every plan requirement before Task 2 was committed.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 26 is now complete: all 6 plans shipped. Conflict resolution (Keep Local / Use Cloud / Merge) is consistent end-to-end — breaks ride along with whichever side wins, with no per-break merge UI, closing roadmap SC5.
- Full project test suite green: 647 passed, 10 pre-existing skips, zero regressions (up from 634 passed at Plan 05's end-state — the +13 delta is this plan's new unit/widget tests).
- `flutter analyze` clean project-wide: 0 errors/warnings. New info-level lints (4 `prefer_int_literals` on the new D-05 `Padding` block, 1 `omit_local_variable_types` in `merge_resolution.dart`) are instances of the SAME pre-existing style lint categories already present in the baseline (13→17 infos on the two touched files) — no new lint rule categories introduced.
- No blockers. Phase 26 (sync-breaks-edit-metadata-to-cloud) ready to close out.

## Verification

- `flutter test test/unit/sync/merge_resolution_test.dart test/widget/features/settings/conflict_resolution_sheet_test.dart` — 18/18 green (11 unit + 7 widget tests), including all new D-04/D-05/Use-Cloud-breaks cases.
- `grep -n "deleteBreaksForTrip" lib/features/settings/widgets/conflict_resolution_sheet.dart` — 2 matches, one in the `kConflictUseCloud` branch and one in the Merge branch.
- `flutter analyze lib/sync/merge_resolution.dart lib/features/settings/widgets/conflict_resolution_sheet.dart` — 0 errors/warnings, 17 pre-existing-category style infos (baseline was 13; the delta is new instances of already-present lint types, not new rule categories).
- `flutter test` (full project suite) — 647 passed, 10 skipped, 0 failed.
- `flutter analyze` (whole project) — 0 errors, 267 info-level style lints (pre-existing pattern across the codebase).
- Threat register: T-26-16 mitigated (every winning-side break write in both `resolveMerge` and the `kConflictUseCloud` branch explicitly remaps `tripId` to `local.id`/`conflict.localTrip.id`, test-pinned by both the "never cloud-original-id" unit-test assertions and the widget-level breaks-replace test). T-26-17 mitigated (both branches wrap `updateTrip` + `deleteBreaksForTrip` + `insertBreaks` in one `database.transaction()`).

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, file access, or schema surface beyond the `<threat_model>`'s registered items (T-26-16, T-26-17), both mitigated as described above.

---
*Phase: 26-sync-breaks-edit-metadata-to-cloud*
*Completed: 2026-07-13*

## Self-Check: PASSED

All 4 claimed modified files verified present on disk; commits `5971d0f` (Task 1) and `6a001b4` (Task 2) verified present in `git log`.
