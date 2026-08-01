---
phase: quick-260801-tjx
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/config/constants.dart
  - lib/database/daos/trip_stuck_segments_dao.dart
  - lib/features/trips/providers/trip_management_providers.dart
  - test/unit/features/tracking/stuck_run_collapser_test.dart
  - test/unit/database/trip_stuck_segments_dao_test.dart
  - test/unit/features/trips/trip_management_edit_full_test.dart
autonomous: true
requirements: [QUICK-260801-TJX]
user_setup: []

must_haves:
  truths:
    - "A contiguous stuck run of 20 seconds or more is persisted and painted on the trip map; a run under 20 seconds is still discarded, so a single traffic-light speck never stipples the route."
    - "Editing a trip's times no longer erases its stuck stretches: the red overlays on the map AND the 'Stuck in traffic' rows in the timeline survive a full edit."
    - "A stuck segment that falls WHOLLY outside the new [startTimeUtc, endTimeUtc] window is deleted; every segment that overlaps the window at all is retained."
    - "A retained segment that straddles a window edge keeps its ORIGINAL startTime/endTime — no clamping — because its point indices address an unedited polyline."
    - "The window-scoped delete runs inside the SAME existing db.transaction as the trip update, break replace, and sync enqueue."
    - "The direction-only edit path (markEdited == false) is byte-for-byte unchanged and still touches no stuck segments."
    - "No user-facing copy claims the painted stretches add up to less than the printed stuck total, and no doc comment argues for the 60s floor."
    - "dart format ., flutter analyze (0 errors, 0 warnings), and the full flutter test suite all pass."
  artifacts:
    - path: "lib/config/constants.dart"
      provides: "kStuckSegmentMinSeconds = 20 with a doc comment justifying 20s and stating the recording-time-only limitation; kStuckInfoBody with an accurate final paragraph"
      contains: "const int kStuckSegmentMinSeconds = 20"
    - path: "lib/database/daos/trip_stuck_segments_dao.dart"
      provides: "deleteSegmentsOutsideWindow — window-scoped delete implementing the endTime <= newStart OR startTime >= newEnd rule"
      contains: "deleteSegmentsOutsideWindow"
    - path: "lib/features/trips/providers/trip_management_providers.dart"
      provides: "editTrip full-edit path calling the window-scoped delete instead of the blanket delete, with a comment explaining the new behavior"
      contains: "deleteSegmentsOutsideWindow"
    - path: "test/unit/database/trip_stuck_segments_dao_test.dart"
      provides: "Four-case coverage of the window delete: wholly-before dropped, wholly-after dropped, fully-inside kept, straddling each edge kept UNTOUCHED"
      contains: "deleteSegmentsOutsideWindow"
  key_links:
    - from: "lib/features/trips/providers/trip_management_providers.dart"
      to: "lib/database/daos/trip_stuck_segments_dao.dart"
      via: "stuckSegmentsDao.deleteSegmentsOutsideWindow inside db.transaction"
      pattern: "deleteSegmentsOutsideWindow\\("
    - from: "lib/features/tracking/services/stuck_run_collapser.dart"
      to: "lib/config/constants.dart"
      via: "runSeconds >= kStuckSegmentMinSeconds floor check (caller unchanged, only the constant it reads)"
      pattern: "kStuckSegmentMinSeconds"
---

<objective>
Paint far more of the user's real slow time on the trip map, and stop a trip edit
from destroying the slow stretches that were actually recorded.

Two independent fixes, both rooted in `trip_stuck_segments`:

1. **Floor 60s → 20s.** `collapseStuckRuns` discards any contiguous stuck run
   summing under `kStuckSegmentMinSeconds`. At 60s, most real crawls and slow
   corners are counted in `timeStuckSeconds` but never persisted, so the map
   never paints them. 20s still filters the ~8-15s speck at a single red light.

2. **Edits stop wiping stuck geometry.** `editTrip` currently calls
   `deleteSegmentsForTrip` on every full edit, which removes the red stretches
   from `TripMapSection` AND every "Stuck in traffic" row from `TripTimeline`
   (both read `tripStuckSegmentsProvider`). Replace with a window-scoped delete:
   drop only segments lying wholly outside the new time window.

Purpose: the segments record WHERE the user was physically slow. No time edit can
invalidate that. Destroying real geometry to protect a derived total was the wrong
trade.

Output: a lowered floor, a new window-scoped DAO delete wired into the existing
edit transaction, corrected user-facing copy, and unit coverage for all of it.
</objective>

<execution_context>
@/Users/coolman/Documents/Projects/bizzle/.claude/get-shit-done/workflows/execute-plan.md
@/Users/coolman/Documents/Projects/bizzle/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.agents/skills/flutter-coding-guidelines/SKILL.md

@lib/config/constants.dart
@lib/database/daos/trip_stuck_segments_dao.dart
@lib/database/tables/trip_stuck_segments_table.dart
@lib/features/trips/providers/trip_management_providers.dart
@lib/features/tracking/services/stuck_run_collapser.dart
@test/unit/features/tracking/stuck_run_collapser_test.dart
@test/unit/features/trips/trip_management_edit_full_test.dart
@test/unit/database/trip_breaks_dao_test.dart

<binding_project_rules>
From CLAUDE.md — these override anything else:
- ALL user-facing copy lives in `lib/config/constants.dart`. No hardcoded strings.
- No dead code: no commented-out code, unused imports, unreachable branches, or
  unreferenced methods. Delete what is not needed.
- Read before writing. Follow existing patterns; do not introduce new ones.
- Verify after changes — run formatter, analyzer, tests.
- Commit prefixes are bracketed feature areas (`[trips]`, `[tracking]`), NOT
  conventional-commit prefixes. One concern per commit.
</binding_project_rules>

<interfaces>
<!-- Extracted from the codebase. Use directly — no exploration needed. -->

Current DAO surface (lib/database/daos/trip_stuck_segments_dao.dart):
```dart
@DriftAccessor(tables: [TripStuckSegments])
class TripStuckSegmentsDao extends DatabaseAccessor<AppDatabase>
    with _$TripStuckSegmentsDaoMixin {
  TripStuckSegmentsDao(super.attachedDatabase);
  Future<void> insertSegments(List<TripStuckSegmentsCompanion> rows);
  Future<void> deleteSegmentsForTrip(String tripId);   // ← see Task 2 dead-code gate
  Stream<List<TripStuckSegmentRow>> watch(String tripId);
}
```

Table columns (lib/database/tables/trip_stuck_segments_table.dart) — all UTC:
```dart
TextColumn     id            // UUID v4 PK
TextColumn     tripId        // FK → trips.id, onDelete: cascade
IntColumn      startPointIndex
IntColumn      endPointIndex // INCLUSIVE
DateTimeColumn startTime
DateTimeColumn endTime
```

Current call site (lib/features/trips/providers/trip_management_providers.dart:150-160),
inside `await db.transaction(() async { ... })`:
```dart
        // Phase 31 (D-03 invariant): ... [10-line comment arguing FOR deletion]
        if (markEdited) {
          await stuckSegmentsDao.deleteSegmentsForTrip(tripId);
        }
        await syncDao.enqueueUpdate(tripId);
```

Collapser floor check (lib/features/tracking/services/stuck_run_collapser.dart:124)
— NOT edited by this plan, only the constant it reads:
```dart
    if (runStartInterval != -1 && runSeconds >= kStuckSegmentMinSeconds) {
```

Drift note: `@DriftAccessor` generates `_$TripStuckSegmentsDaoMixin` from the
TABLE list, not from the method list. Adding or removing a DAO method does NOT
require `dart run build_runner build`. Do not run it for this change.
</interfaces>

<known_findings>
Findings from planning-time greps. Do not re-investigate; verify only where the
task says to.

1. `deleteSegmentsForTrip` has exactly ONE caller in the whole repo:
   `trip_management_providers.dart:159`. It appears in no test and no other
   production file. Task 2 replaces that call, which makes the method dead.
   See Task 2's dead-code gate.
2. `tripStuckSegmentsProvider` has exactly two consumers —
   `trip_map_section.dart:57` and `trip_timeline.dart:94`. Neither needs a change:
   both already degrade to an empty list, and both will simply receive more rows.
3. The `trip_stuck_segments` schema needs NO change and NO migration for this work.
   If you conclude otherwise, STOP and report instead of writing a migration.
4. Analyze baseline is 295 info-level lints. New ERRORS or WARNINGS are
   regressions. Info-level lints matching existing test-suite convention are fine.
</known_findings>

<out_of_scope>
Do not touch, do not "improve while you are in there":
- `lib/features/trips/services/trip_edit_recompute.dart` and its D-02 rescale rule.
- `lib/features/trips/widgets/edit_trip_sheet.dart`.
- The render path from quick task 260801-oux: `formatTrafficDuration`, `StuckBar`,
  `TripTrafficSection`, `TripRowInfo`. It is correct and finished.
- The Drift schema and any migration.
- The backend, the sync payload, and
  `lib/features/tracking/services/trip_accumulator.dart`.
- `kStuckPolylineStrokeWidth` and map styling. The user chose a plain lowered
  floor, NOT differentiated styling for shorter runs.
- `collapseStuckRuns` itself and the `StuckInterval` typedef dartdoc. Its
  "sum(retained runs) <= timeStuckSeconds" claim stays TRUE at collapse time —
  only the persisted post-edit state abandons the invariant.
</out_of_scope>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Lower the stuck floor to 20s, fix the copy and the doc comment that argued for 60s</name>
  <files>
lib/config/constants.dart
test/unit/features/tracking/stuck_run_collapser_test.dart
  </files>

  <behavior>
    stuck_run_collapser_test.dart, re-derived for a 20s floor with the existing
    `_intervalSeconds = 10` fixture (the floor is now crossed at 2 characters,
    not 6). Do NOT weaken an assertion to make it pass — re-derive the number.
    - Fixture-sanity test: `kStuckSegmentMinSeconds` is 20; `2 * _intervalSeconds`
      >= the floor; `1 * _intervalSeconds` < the floor. (Rename the test — its
      current name says "60s floor sits at 6 ten-second intervals".)
    - A run BELOW the floor is still discarded: `collapse('mmsmm')` (one 10s
      interval) is empty. This coverage MUST survive.
    - A run exactly AT the floor is retained: `collapse('mmssmm')` yields one run
      with `attributedSeconds == kStuckSegmentMinSeconds` (20).
    - Short-dropped-while-long-survives: `collapse('sm${'s' * 7}ms')` yields
      exactly one run of 70s — the two 10s runs are dropped. (The old spec's 30s
      and 20s "short" runs now clear the floor, so the spec itself must change.)
    - Mismatched list lengths still degrade rather than throw: with
      `fixture('ssssssss')` and `sampleTimes` truncated to 4, the collapser now
      emits ONE run (30s clears the 20s floor) bounded by the shorter list —
      `endPointIndex == 3`, `attributedSeconds == 30`, and no RangeError. This is
      a stronger assertion than the old `isEmpty`, not a weaker one.
    - Every other test in the file already uses runs of 60s+ and keeps passing
      unchanged. Re-read each one and confirm rather than assuming.
    - The T-31-03 property test is unchanged: it asserts against the constant and
      still holds at collapse time.
    - Update the file's header comment, which currently says "the 60s floor is
      crossed at exactly 6 characters".
  </behavior>

  <action>
1. `lib/config/constants.dart` line ~1494: change `kStuckSegmentMinSeconds` from
   `60` to `20` (D-1). Do NOT remove the floor.

2. Rewrite that constant's ENTIRE doc comment. The current one argues FOR 60s
   ("60s also matches the user-facing framing: a normal signal wait is not what
   anyone means by 'stuck'") and asserts a `<=` consequence that Task 2 breaks.
   The replacement must state, in the file's existing voice:
   - A floor still exists so a single traffic light — an ~8-15 second speck —
     does not stipple the route with noise.
   - Beyond that the user's definition wins: every interval under 10 km/h is
     stuck, and a 20-second crawl or slow corner is exactly what they want painted.
     60s was too coarse; it discarded most real slow stretches to keep a tidier map.
   - **The recording-time limitation, stated plainly:** the floor is applied at
     trip finalize, not at display time. The per-interval classification lives
     only in `TripAccumulator._intervalClasses` and is cleared at finalize, so
     only the surviving collapsed runs are ever persisted. Changing this value
     therefore affects NEWLY RECORDED trips only — already-recorded trips keep
     exactly the segments they were saved with and cannot be back-filled.
   - No `<=` invariant is claimed between painted segments and the trip's
     `timeStuckSeconds`; point at `editTrip` in `trip_management_providers.dart`
     for why (an edited trip retains overlapping segments).

3. `kStuckInfoBody` (~line 1522): replace ONLY the final paragraph. It currently
   reads "On the map, Traevy highlights only the longer stretches where you were
   stuck for a minute or more, so brief halts do not clutter your route. That
   means the highlighted stretches add up to less than the total above." Both
   claims are now false (D-4). Write an accurate, jargon-free replacement in the
   surrounding copy's tone — no "m/s", no "sample", no "threshold". It must say
   the map highlights where you were crawling or stopped, that very brief halts
   of a few seconds are left out so they do not clutter the route, and that on an
   edited trip the highlighted stretches may not add up to the total above.
   Avoid apostrophes inside the single-quoted string literals rather than
   escaping them — match the file's existing style. Also update that constant's
   own dartdoc, which currently describes the final sentence as "the honest
   statement of D-03's floor ... it accounts for less time than the stuck figure
   above it".

4. Update the two existing paragraphs of `kStuckInfoBody` ONLY if they repeat the
   60s claim. Read them first; the first two paragraphs (10 km/h rule, breaks
   excluded) are still correct and should be left alone.

5. Apply the `<behavior>` changes to `stuck_run_collapser_test.dart`.

6. `dart format .`, then `flutter analyze`, then
   `flutter test test/unit/features/tracking/stuck_run_collapser_test.dart`.

7. Commit: `[tracking] Lower stuck-segment floor to 20s so short slow stretches get painted`
  </action>

  <verify>
    <automated>dart format . &amp;&amp; flutter analyze &amp;&amp; flutter test test/unit/features/tracking/stuck_run_collapser_test.dart</automated>
    <automated>grep -n "const int kStuckSegmentMinSeconds = 20" lib/config/constants.dart</automated>
    <automated>! grep -n "add up to less than the total above" lib/config/constants.dart</automated>
    <automated>! grep -rn "stuck for a minute or more" lib/</automated>
  </verify>

  <done>
`kStuckSegmentMinSeconds` is 20 with a doc comment that justifies 20s, states the
newly-recorded-trips-only limitation, and claims no `<=` invariant.
`kStuckInfoBody`'s final paragraph is accurate on both counts. The collapser test
file passes with re-derived expectations and still proves a sub-floor run is
discarded. `flutter analyze` shows no new errors or warnings.
  </done>
</task>

<task type="auto">
  <name>Task 2: Replace the blanket stuck-segment delete on edit with a window-scoped delete</name>
  <files>
lib/database/daos/trip_stuck_segments_dao.dart
lib/features/trips/providers/trip_management_providers.dart
  </files>

  <action>
1. **Add `deleteSegmentsOutsideWindow` to `TripStuckSegmentsDao`.** Implement the
   overlap rule EXACTLY: a segment is deleted only when
   `segment.endTime <= newStart` OR `segment.startTime >= newEnd`. Anything else
   is retained. Signature — named params, matching the DAO's existing terse style:

   ```dart
   Future<void> deleteSegmentsOutsideWindow({
     required String tripId,
     required DateTime startTimeUtc,
     required DateTime endTimeUtc,
   }) {
     return (delete(tripStuckSegments)..where(
       (s) =>
           s.tripId.equals(tripId) &
           (s.endTime.isSmallerOrEqualValue(startTimeUtc) |
               s.startTime.isBiggerOrEqualValue(endTimeUtc)),
     )).go();
   }
   ```

   The parentheses around the `|` group are load-bearing — Dart binds `&` tighter
   than `|`, so without them the tripId guard would be lost and the delete would
   cross trips. Keep them.

   Its dartdoc must state: only segments lying WHOLLY outside the window are
   removed; a segment overlapping the window at ALL is kept, and kept ENTIRELY
   UNTOUCHED — its `startTime`/`endTime` are NOT clamped to the window (D-3),
   because `startPointIndex`/`endPointIndex` address the polyline and the polyline
   is not edited; clamping timestamps without clamping the geometry in step would
   misreport which stretch of road was slow, so partial overflow past the window
   edge is the honest, lesser evil.

2. **Rewire `editTrip`** (`trip_management_providers.dart`, inside the EXISTING
   `db.transaction` block — do not open a second transaction, do not move the call
   outside it). Keep the `if (markEdited)` gate so the direction-only path stays
   byte-for-byte unchanged. Replace the call:

   ```dart
   await stuckSegmentsDao.deleteSegmentsOutsideWindow(
     tripId: tripId,
     startTimeUtc: startTimeUtc,
     endTimeUtc: endTimeUtc,
   );
   ```

3. **Replace the Phase 31 D-06 comment block at lines 150-160 entirely.** It
   argues for the behavior being deleted and must not survive as a contradiction.
   The new comment must cover, in the file's voice:
   - A stuck segment records WHERE the user was physically slow; no edit of the
     trip's times can make that stretch of road untrue, so an edit no longer
     destroys it (D-2).
   - Only segments wholly outside the new window — the parts of the recording the
     user cut away — are removed.
   - **D-3 verbatim in substance:** an overlapping segment is kept entirely
     untouched, NOT clamped, because its point indices address an unedited
     polyline and clamping timestamps without clamping geometry would misreport
     which stretch of road was slow.
   - The accepted consequence (D-4): `sum(painted segments) <= timeStuckSeconds`
     is now explicitly ABANDONED for edited trips, and `kStuckInfoBody` no longer
     claims it.

4. **Dead-code gate (CLAUDE.md: "No dead code").** After step 2, run:
   `grep -rn "deleteSegmentsForTrip" lib test --include="*.dart"`
   - If the ONLY remaining hit is the declaration in
     `trip_stuck_segments_dao.dart`: DELETE the method and its dartdoc. Planning
     confirmed `editTrip:159` was its sole caller; leaving it is dead code, and
     its dartdoc argues for the behavior this task removes. Record the removal in
     the summary.
   - If grep finds any OTHER caller: KEEP the method untouched and note the caller
     in the summary. Act on what grep prints, not on this note.
   - Do NOT delete `insertSegments` or `watch` under any circumstance.

5. No `build_runner` run — `_$TripStuckSegmentsDaoMixin` is generated from the
   table list, not the method list. No schema change, no migration (see
   known_findings #3).

6. `dart format .` then `flutter analyze`. Do not commit yet — Task 3 commits
   this change together with its tests.
  </action>

  <verify>
    <automated>dart format . &amp;&amp; flutter analyze</automated>
    <automated>grep -n "deleteSegmentsOutsideWindow" lib/database/daos/trip_stuck_segments_dao.dart lib/features/trips/providers/trip_management_providers.dart</automated>
    <automated>! grep -n "deleteSegmentsForTrip" lib/features/trips/providers/trip_management_providers.dart</automated>
    <automated>! grep -rn "Phase 31 (D-03 invariant)" lib/features/trips/providers/trip_management_providers.dart</automated>
  </verify>

  <done>
`deleteSegmentsOutsideWindow` exists on the DAO implementing exactly
`endTime <= newStart OR startTime >= newEnd`, with the tripId guard correctly
parenthesized. `editTrip`'s full-edit path calls it inside the existing
transaction; the direction-only path is unchanged. The old comment block is gone,
replaced by one explaining retention, no-clamping (D-3), and the abandoned
invariant (D-4). The dead-code gate was executed and its outcome recorded.
`flutter analyze` shows no new errors or warnings.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Prove the retention contract — DAO window tests plus updated edit tests</name>
  <files>
test/unit/database/trip_stuck_segments_dao_test.dart
test/unit/features/trips/trip_management_edit_full_test.dart
  </files>

  <behavior>
    NEW `test/unit/database/trip_stuck_segments_dao_test.dart`. Follow the setup
    pattern already used by `test/unit/database/trip_breaks_dao_test.dart`
    (in-memory `NativeDatabase.memory()`, insert a parent trip row first — the FK
    to `trips.id` is enforced). Use whole-second UTC timestamps so Drift's
    DateTime storage cannot introduce truncation ambiguity.

    Window under test: 08:00Z → 09:00Z. Insert five segments in one trip and call
    `deleteSegmentsOutsideWindow` once, then assert on the surviving rows:
    - `before`: 07:00 → 07:30 — wholly before the window → DELETED.
    - `touchesStart`: 07:30 → 08:00 (`endTime == newStart`) → DELETED. The rule is
      `endTime <= newStart`, so an exact touch at the boundary is outside.
    - `inside`: 08:10 → 08:20 — fully within → KEPT.
    - `straddlesStart`: 07:50 → 08:10 → KEPT, and assert BOTH its `startTime` and
      `endTime` are unchanged (still 07:50 / 08:10). This is the assertion that
      proves D-3 — no clamping.
    - `straddlesEnd`: 08:50 → 09:10 → KEPT, timestamps likewise asserted unchanged.
    - `after`: 09:30 → 09:40 — wholly after → DELETED. Also cover
      `startTime == newEnd` (09:00 → 09:10) as DELETED, matching
      `startTime >= newEnd`.
    - A segment belonging to a DIFFERENT trip, wholly outside the window, is NOT
      deleted — proves the tripId guard survived the `&`/`|` precedence.
    Also assert `startPointIndex`/`endPointIndex` on a retained straddling segment
    are unchanged, since the geometry is the thing being protected.

    UPDATE `test/unit/features/trips/trip_management_edit_full_test.dart`. The
    existing test named 'full edit drops stuck segments stranded by the new stuck
    total' (~line 214) asserts the OPPOSITE of the new contract — it edits with an
    unchanged 08:00–09:00 window and expects `isEmpty`. Update it to the new
    contract rather than deleting it: rename it to reflect retention, and assert
    the in-window segment SURVIVES with its timestamps and point indices intact,
    even though `timeStuckSeconds` was rewritten to 60s (far below the segment's
    own span — the abandoned invariant, D-4, made explicit in the test's doc
    comment, which currently argues for the old behavior and must be rewritten).

    ADD one editTrip test proving the window delete actually runs inside the
    transaction: a trip with two segments (one early, one late), edited so the new
    window excludes the early one → after the edit exactly one segment remains,
    and it is the late one.

    KEEP the existing 'direction-only edit keeps stuck segments' test as-is — it
    still holds and now guards the `if (markEdited)` gate.
  </behavior>

  <action>
1. Write `test/unit/database/trip_stuck_segments_dao_test.dart` per `<behavior>`,
   matching `trip_breaks_dao_test.dart`'s structure and naming conventions. Read
   that file first and mirror it; do not invent a new test-setup pattern.
2. Update `trip_management_edit_full_test.dart` per `<behavior>`.
3. `dart format .`
4. `flutter analyze` — 0 errors, 0 warnings. Baseline is 295 info-level lints;
   info-level lints matching the existing test-suite convention are acceptable,
   new errors or warnings are regressions.
5. `flutter test` — the FULL suite, not just the touched files. A regression in
   `trip_detail_screen_test.dart`, `trip_map_section_test.dart`, or
   `persist_finalized_trip_test.dart` would mean the change reached further than
   intended; fix the cause, do not relax the assertion.
6. Commit Task 2 + Task 3 together as one concern:
   `[trips] Keep in-window stuck segments when a trip is edited`
  </action>

  <verify>
    <automated>dart format . &amp;&amp; flutter analyze &amp;&amp; flutter test</automated>
    <automated>flutter test test/unit/database/trip_stuck_segments_dao_test.dart test/unit/features/trips/trip_management_edit_full_test.dart</automated>
    <automated>! grep -n "full edit drops stuck segments" test/unit/features/trips/trip_management_edit_full_test.dart</automated>
  </verify>

  <done>
A new DAO test file covers all four required cases plus both boundary equalities
and the cross-trip guard, and asserts a straddling segment's timestamps and point
indices are byte-identical after the delete (D-3 proven). The edit test that
asserted deletion now asserts retention under the new contract, with a rewritten
doc comment. The full `flutter test` suite is green and `flutter analyze` reports
0 errors and 0 warnings. Both tasks are committed with bracketed prefixes.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user edit sheet → local Drift write | User-supplied start/end times reach a SQL DELETE predicate. No network, no other user's data — the DB is single-user and local. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-TJX-01 | Tampering | `deleteSegmentsOutsideWindow` predicate | mitigate | The `tripId.equals` guard must be parenthesized against the `|` group (Dart binds `&` tighter than `|`). A malformed predicate would delete another trip's segments. Task 3 pins this with an explicit cross-trip test. |
| T-TJX-02 | Denial of Service | edit path data loss | mitigate | Over-broad deletion is unrecoverable — stuck segments are local-only (D-04) and never restored from Firestore. The delete runs inside the existing transaction, so a failure anywhere in `editTrip` rolls it back; the existing 'transaction rolls back on failure' test still guards this. |
| T-TJX-03 | Information disclosure | stuck segments reveal where the user idles (T-31-01) | accept | Unchanged by this plan. Rows stay local-only and are never serialized into a sync payload. Lowering the floor increases row count, not blast radius. |
</threat_model>

<verification>
1. `dart format .` — no reformatting churn left uncommitted.
2. `flutter analyze` — 0 errors, 0 warnings. Baseline 295 info-level lints;
   new errors/warnings are regressions.
3. `flutter test` — full suite green.
4. `grep -rn "kStuckSegmentMinSeconds" lib` — the collapser is the only production
   consumer of the constant and is itself unmodified.
5. `grep -rn "deleteSegmentsForTrip" lib test --include="*.dart"` — either zero
   hits (method removed per the dead-code gate) or a documented surviving caller.
6. No file under `lib/database/` other than the DAO changed — no schema edit, no
   migration, no `.g.dart` regeneration.
</verification>

<success_criteria>
- `kStuckSegmentMinSeconds == 20`; a 20s run is retained, a 10s run is discarded.
- A full edit retains every stuck segment overlapping the new window and deletes
  only those wholly outside it.
- A retained straddling segment's `startTime`, `endTime`, `startPointIndex`, and
  `endPointIndex` are provably unchanged.
- The direction-only edit path is unchanged.
- No production or test file claims the painted stretches sum to less than
  `timeStuckSeconds`, and no comment argues for the 60s floor or the blanket delete.
- Full test suite green; analyze clean of new errors and warnings.
- Two commits, bracketed prefixes, one concern each.
</success_criteria>

<summary_notes>
These MUST appear in the SUMMARY — they are the parts a future session will
otherwise get wrong:

1. **The lowered floor affects NEWLY RECORDED trips only.** Filtering happens at
   recording time (trip finalize), not display time: the per-interval
   classification lives only in `TripAccumulator._intervalClasses` and is cleared
   at finalize, so only surviving collapsed runs are ever persisted. Trips already
   in the database keep exactly the segments they were saved with and CANNOT be
   back-filled — there is nothing left to re-derive them from. A user testing this
   must record a NEW trip to see the difference.

2. **The `sum(painted) <= timeStuckSeconds` invariant is deliberately abandoned
   for edited trips** (D-4), reversing Phase 31 D-06 / commit 93c57f7. This is not
   a bug and not a regression to "fix" later: the segments record WHERE the user
   was physically slow, which no time edit can invalidate, and destroying real
   geometry to protect a derived total was judged the worse outcome. The
   collapse-time invariant in `stuck_run_collapser.dart` still holds and was
   intentionally left alone.

3. **Overlapping segments are NOT clamped** (D-3). Their point indices address a
   polyline that edits never touch; clamping timestamps without clamping geometry
   in step would misreport which stretch of road was slow. Partial overflow past
   the window edge is the accepted, honest cost.

4. Record the outcome of the `deleteSegmentsForTrip` dead-code gate — whether the
   method was removed and on what grep evidence.
</summary_notes>

<output>
After completion, create
`.planning/quick/260801-tjx-paint-shorter-slow-stretches-on-the-trip/260801-tjx-SUMMARY.md`
</output>
</content>
</invoke>
