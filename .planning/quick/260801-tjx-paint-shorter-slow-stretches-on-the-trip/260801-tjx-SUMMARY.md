---
phase: quick-260801-tjx
plan: 01
subsystem: trips
tags: [stuck-segments, trip-map, trip-edit, drift-dao, transaction]

# Dependency graph
requires: []
provides:
  - "kStuckSegmentMinSeconds lowered from 60s to 20s (recording-time floor, TripAccumulator/collapseStuckRuns unchanged)"
  - "TripStuckSegmentsDao.deleteSegmentsOutsideWindow — window-scoped delete replacing the old blanket deleteSegmentsForTrip"
affects: [trip detail map, trip timeline "Stuck in traffic" rows, trip edit flow]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Window-scoped Drift delete: s.tripId.equals(tripId) & (endTime.isSmallerOrEqualValue(start) | startTime.isBiggerOrEqualValue(end)) — the OR group MUST be parenthesized against Dart's tighter & binding or the tripId guard is silently dropped from the second disjunct"
    - "Retention-not-clamping: a segment overlapping an edited trip's new time window is kept with its original startTime/endTime/point-indices untouched, because those indices address an unedited polyline"

key-files:
  created:
    - test/unit/database/trip_stuck_segments_dao_test.dart
  modified:
    - lib/config/constants.dart
    - lib/database/daos/trip_stuck_segments_dao.dart
    - lib/features/trips/providers/trip_management_providers.dart
    - test/unit/features/tracking/stuck_run_collapser_test.dart
    - test/unit/features/trips/trip_management_edit_full_test.dart
    - test/unit/features/tracking/trip_accumulator_stuck_segments_test.dart
    - test/widget/shared/widgets/info_sheet_test.dart

key-decisions:
  - "deleteSegmentsForTrip was replaced in place rather than added-alongside-then-removed: the method's body and dartdoc were directly rewritten into deleteSegmentsOutsideWindow, so the plan's Task 2 dead-code gate found zero grep hits (not even the declaration) rather than one surviving unused declaration to delete."
  - "Two out-of-scope test files were fixed as Rule-1 auto-fixes because they broke as a direct, in-scope consequence of Task 1's floor/copy change, only surfaced by running the FULL suite as Task 3 instructs: test/unit/features/tracking/trip_accumulator_stuck_segments_test.dart (a 'below 60s floor' fixture that now clears 20s) and test/widget/shared/widgets/info_sheet_test.dart (asserted the exact 'less than the total' copy Task 1 removed). Committed separately under [tracking] rather than folded into either plan commit, keeping each commit to one concern."
  - "The T-TJX-01 cross-trip guard test was deliberately verified adversarially: the DAO's parentheses were temporarily removed, confirmed the new test fails (deletes another trip's row), then restored and reconfirmed green — not just written and trusted to be correct."

patterns-established: []

requirements-completed: [QUICK-260801-TJX]

# Metrics
duration: ~55min
completed: 2026-08-01
---

# Quick Task 260801-tjx: Paint Shorter Slow Stretches on the Trip Map Summary

**Lowered the persisted stuck-segment floor from 60s to 20s so real slow stretches actually get painted, and replaced trip-edit's blanket stuck-segment delete with a window-scoped delete that keeps every segment overlapping the trip's new time window untouched.**

## Performance

- **Duration:** ~55 min
- **Started:** 2026-08-01
- **Completed:** 2026-08-01
- **Tasks:** 3 completed (Task 1 solo commit; Task 2+3 combined per plan; one additional Rule-1 fix commit)
- **Files modified:** 8 (1 new test file, 7 modified: 3 lib, 4 test)

## Accomplishments

- `kStuckSegmentMinSeconds` (`lib/config/constants.dart`) lowered from `60` to `20`. Its doc comment was fully rewritten: states why a floor still exists (an ~8-15s traffic-light speck should not stipple the route), that beyond the floor the user's own 10 km/h definition of "stuck" wins, and — critically — the **recording-time limitation**: the per-interval classification lives only in `TripAccumulator._intervalClasses` and is cleared at finalize, so this change affects **newly recorded trips only**; already-recorded trips keep exactly the segments they were saved with and cannot be back-filled.
- `kStuckInfoBody`'s final paragraph rewritten: no longer claims the map only highlights "the longer stretches... a minute or more," and no longer claims the highlighted stretches "add up to less than the total above." It now says brief halts of a few seconds are left out, and that an edited trip's highlighted stretches may not add up to the total above.
- `TripStuckSegmentsDao.deleteSegmentsForTrip` (blanket delete, ran on every full edit) replaced by `deleteSegmentsOutsideWindow({tripId, startTimeUtc, endTimeUtc})`, implementing exactly `segment.endTime <= newStart OR segment.startTime >= newEnd`. Anything else — any overlap at all — is retained, and retained rows are kept **entirely untouched**, not clamped: their `startPointIndex`/`endPointIndex` address the original, unedited polyline, so clamping timestamps without clamping geometry would misreport which stretch of road was slow.
- `editTrip` (`trip_management_providers.dart`) rewired to call the new window-scoped delete inside the same existing `db.transaction`, still gated on `markEdited` so the direction-only path is byte-for-byte unchanged. The old Phase 31 D-06 comment block (which argued for the behavior just removed) was replaced with one explaining retention, no-clamping, and the now-explicitly-abandoned `sum(painted) <= timeStuckSeconds` invariant.
- The `&`/`|` operator-precedence hazard flagged in the threat model (T-TJX-01) was pinned with a real adversarial test: the parentheses around the OR group were removed, the new cross-trip test genuinely failed (another trip's segment was deleted), then the parentheses were restored and the suite went green again.

## Task Commits

1. **Task 1: Lower the stuck floor to 20s, fix the copy and doc comment**
   - `3d4c450` `[tracking] Lower stuck-segment floor to 20s so short slow stretches get painted`
2. **Task 2 + Task 3 combined (per plan): window-scoped delete + its tests**
   - `d3174ba` `[trips] Keep in-window stuck segments when a trip is edited`
3. **Rule-1 fix (not in original plan scope, discovered by the full-suite run Task 3 requires)**
   - `452e5bc` `[tracking] Fix full-suite regressions from the lowered stuck floor`

## Files Created/Modified

- `lib/config/constants.dart` — `kStuckSegmentMinSeconds` 60→20 with rewritten doc comment; `kStuckInfoBody` final paragraph and dartdoc rewritten
- `lib/database/daos/trip_stuck_segments_dao.dart` — `deleteSegmentsForTrip` replaced by `deleteSegmentsOutsideWindow`; `insertSegments`/`watch` untouched
- `lib/features/trips/providers/trip_management_providers.dart` — `editTrip`'s full-edit path calls the new window-scoped delete inside the existing transaction; old D-06 comment block replaced
- `test/unit/features/tracking/stuck_run_collapser_test.dart` — floor-sanity, exactly-at-floor, below-floor, mixed-run, and mismatched-length-list tests re-derived for the 20s floor; header comment updated. The T-31-03 property test was left unchanged (parameterized on the constant, still holds).
- `test/unit/database/trip_stuck_segments_dao_test.dart` (new) — wholly-before, touches-start (boundary equality), inside, straddles-start, straddles-end, touches-end (boundary equality), wholly-after, plus a cross-trip guard proving the `&`/`|` precedence fix; asserts a straddling segment's `startTime`/`endTime`/`startPointIndex`/`endPointIndex` are byte-identical after the delete
- `test/unit/features/trips/trip_management_edit_full_test.dart` — the test that asserted deletion now asserts retention (renamed, doc comment rewritten); added a same-transaction test proving only the segment stranded by the new window is removed
- `test/unit/features/tracking/trip_accumulator_stuck_segments_test.dart` — Rule-1 fix: "under the floor" fixture re-derived from 40s (now clears 20s) to a genuinely sub-floor 10s stretch
- `test/widget/shared/widgets/info_sheet_test.dart` — Rule-1 fix: assertion that asserted the removed "less than the total" copy claim replaced with assertions on the new copy contract

## Decisions Made

See `key-decisions` in the frontmatter above. In short: the DAO method was rewritten in place (no separate dead-code-removal step was needed, since grep found zero remaining hits including the declaration itself); two test files outside the plan's `files_modified` list were fixed as in-scope Rule-1 consequences of Task 1's change, committed separately to keep each commit single-concern; and the precedence-hazard test was adversarially verified rather than merely written.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `test/unit/features/tracking/trip_accumulator_stuck_segments_test.dart` broke under the new 20s floor**
- **Found during:** Task 3's mandated full `flutter test` run
- **Issue:** `'a stuck stretch under the 60s floor emits no segment'` fed a 4×10s = 40s stuck stretch, which now clears the new 20s floor and emits a segment — asserting `isEmpty` failed.
- **Fix:** Re-derived the fixture to a genuinely sub-floor 1×10s = 10s stretch. Test renamed to "under the 20s floor."
- **Files modified:** `test/unit/features/tracking/trip_accumulator_stuck_segments_test.dart`
- **Commit:** `452e5bc`

**2. [Rule 1 - Bug] `test/widget/shared/widgets/info_sheet_test.dart` asserted the exact copy claim Task 1 removed**
- **Found during:** Task 1's own verification run (`flutter test`), confirmed still failing at the mandated full-suite run in Task 3
- **Issue:** `expect(kStuckInfoBody, contains('less than the total'))` — this is the precise sentence Task 1's action step 3 requires deleting, since it is no longer true once edited trips retain overlapping segments (D-4).
- **Fix:** Replaced the assertion with checks on the new copy contract (`'brief halts'`, `'may not add up'`, still checks `'10 km/h'` and `'paused'`).
- **Files modified:** `test/widget/shared/widgets/info_sheet_test.dart`
- **Commit:** `452e5bc`

No other deviations. All `files_modified` boundaries and out-of-scope files listed in the plan (`trip_edit_recompute.dart`, `edit_trip_sheet.dart`, `trip_accumulator.dart`, the Drift schema, `collapseStuckRuns` itself, `kStuckPolylineStrokeWidth`) were left untouched.

## Issues Encountered

None beyond the two Rule-1 fixes above, both resolved within the same session.

## User Setup Required

None — no new dependencies, no config, no schema/migration, no backend change.

## Important Limitations (must be understood before testing this change)

1. **The lowered floor affects NEWLY RECORDED trips only.** The per-interval speed classification the floor is applied against lives only in `TripAccumulator._intervalClasses` during an active recording and is cleared once the trip is finalized — only the runs that survived the floor at finalize time are ever persisted to `trip_stuck_segments`. Trips already in the database keep exactly the segments they were saved with; there is nothing left to re-derive them from, so **existing trips cannot be back-filled** with the new, more generous floor. To see the effect of this change, record a brand-new trip.

2. **`sum(painted segments) <= timeStuckSeconds` is now deliberately abandoned for edited trips (D-4).** This reverses Phase 31 D-06 (commit `93c57f7`). It is intentional, not a bug: a stuck segment records WHERE the user was physically slow, and no edit to the trip's start/end times or hand-entered totals can make that stretch of road untrue. Destroying real geometry just to keep a derived total internally consistent was judged the worse trade-off. The collapse-time invariant inside `stuck_run_collapser.dart` (a freshly-collapsed run's summed seconds is `<=` the trip's live `timeStuckSeconds` at record time) still holds and was intentionally left untouched — only the post-edit persisted state now diverges from it.

3. **Overlapping segments are never clamped to the new window (D-3).** A segment's `startPointIndex`/`endPointIndex` address the trip's decoded polyline, and edits never touch the polyline itself. Clamping the segment's timestamps to the new window without also clamping which polyline points it covers would misreport which physical stretch of road was slow — so a segment that straddles a window edge is kept with its original timestamps and indices, even though part of it now falls outside the edited window. This is the accepted, honest cost.

## Verification

```
dart format .      # 302 files, 0 changed on final pass
flutter analyze    # 295 issues (all info-level, matching pre-existing baseline) — 0 errors, 0 warnings
flutter test       # 989 passed, 10 pre-existing skips, 0 failures
```

Static greps (all clean, matching plan's `<verification>` section):
- `grep -n "const int kStuckSegmentMinSeconds = 20" lib/config/constants.dart` → 1 hit
- `grep -rn "deleteSegmentsForTrip" lib test --include="*.dart"` → zero hits (method fully replaced, not left dangling)
- `grep -rn "kStuckSegmentMinSeconds" lib` → only the constant declaration and the unmodified `collapseStuckRuns`/table/finalized_trip doc references
- No file under `lib/database/` other than `trip_stuck_segments_dao.dart` changed — confirmed via `git diff --stat` against the pre-task commit
- `! grep -rn "stuck for a minute or more" lib/` and `! grep -n "add up to less than the total above" lib/config/constants.dart` → both clean

Adversarial check on T-TJX-01: with the DAO's parentheses temporarily removed, the new cross-trip test in `trip_stuck_segments_dao_test.dart` genuinely failed (deleted another trip's wholly-outside segment); restoring the parentheses restored a green suite.

## Next Phase Readiness

- No blockers. The map now paints real 20s+ slow stretches, and editing a trip's times no longer wipes its recorded traffic geometry.
- `trip_edit_recompute.dart`, `edit_trip_sheet.dart`, `trip_accumulator.dart`, the Drift schema/migrations, and the backend are byte-for-byte unchanged, as required by the plan's out-of-scope list.

---
*Phase: quick-260801-tjx*
*Completed: 2026-08-01*

## Self-Check: PASSED

- FOUND: lib/config/constants.dart
- FOUND: lib/database/daos/trip_stuck_segments_dao.dart
- FOUND: lib/features/trips/providers/trip_management_providers.dart
- FOUND: test/unit/database/trip_stuck_segments_dao_test.dart
- FOUND: test/unit/features/tracking/stuck_run_collapser_test.dart
- FOUND: test/unit/features/trips/trip_management_edit_full_test.dart
- FOUND: test/unit/features/tracking/trip_accumulator_stuck_segments_test.dart
- FOUND: test/widget/shared/widgets/info_sheet_test.dart
- FOUND: 3d4c450 (Task 1 commit)
- FOUND: d3174ba (Task 2+3 commit)
- FOUND: 452e5bc (Rule-1 fix commit)
