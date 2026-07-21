---
phase: 31-trip-detail-breaks-stuck-transparency
completed: 2026-07-22
status: code_complete_device_unverified
mode: manual-gsd
requirements: [UX-09, TRACK-15]
branch: main
commits:
  - bddd843 (Wave 1 · 31-01 accumulator + schema v9)
  - 8b9193f (Wave 1 · 31-02 shared InfoSheet)
  - 0587829 (Wave 2 · 31-03 screen, map, timeline)
result: >
  All three plans built on main. Schema v9 landed (first of the
  post-v0.3-UAT batch; Phase 33 v10 and Phase 35 v11 follow). The shared
  InfoSheet that Phases 32 and 33 consume is in place, so the batch
  dependency head is clear. Flutter 774 tests green (was 721), analyze
  0 errors / 0 warnings, dart format clean. SC#2 is device-only and NOT
  verified — no real drive has been recorded against this build.
---

# Phase 31 — Trip Detail: Breaks, Stuck Transparency, Edit Gating — SUMMARY

## What shipped

| Wave | Commit | Content |
|---|---|---|
| 1 (31-01) | `bddd843` | `StuckIntervalClass` + `StuckInterval` + pure `collapseStuckRuns`; index-parallel `_intervalClasses` in `TripAccumulator` (all 4 append sites + dumpState/restore); `trip_stuck_segments` table, DAO, provider; migration **v9**; `FinalizedTrip.stuckSegments`; persist-path wiring. 29 tests |
| 1 (31-02) | `8b9193f` | `lib/shared/widgets/info_sheet.dart` (`showInfoSheet` + `InfoIconButton`) and the Phase 31 constants banner. 5 tests |
| 2 (31-03) | `0587829` | Direction toggle + `_handleDirectionChanged` removed; `trip_map_section.dart` extracted and painting stuck runs; `TripTimeline` rewritten against real breaks + segments; stuck `InfoSheet` attached. 24 tests |

**Verification:** `flutter analyze` **0 errors / 0 warnings** · `flutter test`
**774 passed, 10 skipped** (measured baseline on `main` before this phase was
**721 passed, 10 skipped**, +53) · `dart format .` clean.

> The prompt for this phase quoted a 664-test baseline. That number is stale —
> it is the Phase 27 figure. The measured pre-phase baseline was 721.

## Success criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Direction not changeable from trip detail; only in `EditTripSheet` | ✅ toggle + handler deleted; widget test asserts `DirectionSegmentedToggle` is absent and the title still shows direction |
| 2 | A trip recorded after this phase shows red stretches where the user was actually <10 km/h for ≥60s | ⛔ **NOT verified** — device-only, no real drive recorded. Code + unit tests only |
| 3 | Sum of painted segment durations never exceeds `timeStuckSeconds` | ⚠️ **holds for recorded trips**, proven two ways; **can be violated by a Phase 19 edit** — see *Surprises* |
| 4 | A gap > `kTrackingMaxAttributableGapSeconds` never appears as a painted stretch | ✅ `unattributed` breaks runs; asserted at both the collapser and accumulator level |
| 5 | A pre-phase trip opens without error, plain single polyline, no stuck rows | ✅ widget tests: 1 polyline, only the two anchors, no empty state |
| 6 | Timeline shows real breaks + real stuck stretches in time order; the 40% marker is gone | ✅ `buildTimelineEntries` ordering tests + a test asserting no row lands at the old 40% instant; `grep` confirms the ratio exists nowhere |
| 7 | Info icon opens a plain-language explanation, no jargon | ✅ a test asserts the copy contains none of *m/s, sample, threshold, polyline, gps, interval, segment* |
| 8 | Phase 26 trip-payload key-set test passes unchanged | ✅ `lib/sync/` has a **zero-line diff** across all three commits; suite green |
| 9 | `schemaVersion` is 9 and v8 → v9 preserves every trip | ✅ `SchemaVerifier.migrateAndValidate(db, 9)` + row-survival + a cascade-delete test |

## Decisions as-built

D-01 through D-08 held. Three things were sharper in code than on paper:

**The index-parallel list needed a single write funnel, not four careful call
sites.** The plan correctly identified the four places that append to
`_samples`, and correctly named this the phase's most important correctness
property. Relying on four sites to stay in step is exactly the kind of
invariant that survives the commit that introduces it and dies in the next
one. So `_samples` is now grown ONLY through `_addSampleWithClass(p, interval)`
— appending a sample without its classification is no longer expressible.

**`dumpState`/`restore` was a fifth desynchronisation site the plan did not
list.** `TripAccumulator.restore` rebuilds `_samples` from the persisted
snapshot. Without carrying `_intervalClasses` too, an interrupted-then-resumed
trip would finalize with an empty class list against a full sample list, and
every segment index would address the wrong point. The classes are now
persisted alongside, and `_padIntervalClasses()` forces the restored list to
exactly `_samples.length` — padding with `unattributed`, truncating any excess.
A legacy snapshot (no `_intervalClasses` key) pads entirely to `unattributed`,
which yields **no segments** rather than fabricated ones. That is the D-06
rule applied to a case D-06 did not mention.

**The T-31-03 invariant is enforced on attributed seconds, not on timestamp
spans.** `StuckRun` carries `attributedSeconds` — the sum of the *same rounded
integers* the accumulator added to `timeStuckSeconds` — and both the 60s floor
and the invariant use that. Had the floor and the invariant used
`endTime - startTime` instead, the property would be *nearly* true and
adversarially false: `deltaSec.round()` loses up to 0.5 s per interval, so a
run of intervals consistently just over a whole second (e.g. 3.4 s each)
spans more wall-clock than it contributes to the counter. Using the counter's
own arithmetic makes `sum(retained runs) <= timeStuckSeconds` true by
construction rather than true in practice.

## Surprises

**SC#3 can be broken by a Phase 19 trip edit, and this phase does not fix it.**
`trip_management_providers.editTrip` rewrites `timeStuckSeconds` on a full
edit (`markEdited: true`) and replaces the trip's breaks wholesale — but
nothing touches `trip_stuck_segments`. So a user who edits a trip down can end
up with painted stretches summing to more than the trip's new stuck figure.
The plan does not mention trip editing at all, and adding recompute-or-delete
would have been unplanned scope, so it is **left as a follow-up rather than
silently patched**. It is not a regression (the rows did not exist before) but
it is a real way to reach a state the success criterion forbids, and calling
SC#3 a flat ✅ would be false.

**`StreamProviderFamily` is not a nameable type in this Riverpod.** The repo's
house style annotates every top-level provider with its explicit type, but
riverpod 3.2.1 does not export `StreamProviderFamily` from the public
`flutter_riverpod` surface — the explicit annotation is an `undefined_class`
error. `trip_detail_providers.dart` therefore uses inferred types, the only
providers in the codebase that do. Worth knowing before Phase 32 or 33 adds a
family and hits the same wall.

**`TripTimelineRow` hardcoded its duration colour to `tokens.stuck`.** Fine
when the only row with a duration WAS the stuck row; wrong the moment break
rows joined the timeline. Added an optional `durationColor` that defaults to
the old value, so every existing call site is unchanged.

**Five existing test files broke on the new constructor parameter.** Four pass
`TrackingServiceController(...)` directly; two subclass it and forward with
`required super.*`. Adding `tripStuckSegmentsDao` made the subclasses abstract
and the direct calls incomplete. All five now pass the real in-memory DAO —
these tests exercise the persist transaction, so a no-op stub would have
hidden a broken segment write.

## Correction to the `8b9193f` commit message

Its subject reads `Phase 31 Wave 2` — it is **Wave 1, plan 31-02**. The
`InfoSheet` is a Wave 1 deliverable (independent of 31-01, parallel-safe);
only `0587829` is Wave 2. The commit message is immutable; this note is the
correction.

## What is NOT done

**SC#2 — the whole point of the phase — is unverified.** No drive has been
recorded against this build. Everything proving stuck stretches land in the
right place is synthetic: hand-built interval sequences and hand-built
`Position` streams. The unit tests prove the *algorithm* maps classifications
to indices correctly; they cannot prove that a real Android GPS stream's
`Position.speed` in real stop-and-go traffic produces stretches a human
recognises as where they were stuck. That needs the manual drive the plan's
Verification section calls for.

**The other two manual checks are also outstanding**: opening a trip recorded
before this build on a real device, and recording a trip with a break to
confirm the bridge line across it is not painted red. Both are covered by
tests at the unit/widget level, neither has been seen on a device.

**No backfill, by design (D-06).** Every trip recorded before this build has
zero segments, permanently. The source speeds were never persisted.

## Follow-ups

1. **Device-verify SC#2** — record a real drive with genuine stop-and-go
   traffic; confirm red stretches land where you were actually stuck and not
   on free-flowing sections. Add to the Phase 23 device-only queue.
2. **Decide what a trip edit does to stuck segments.** Options: delete them on
   `markEdited` (honest — the recomputed figure no longer has a matching map),
   or leave them and accept SC#3 drift on edited trips. Deleting is the
   smaller lie. Worth folding into Phase 35 if that phase is already touching
   edit/delete paths.
3. **Device-verify the break bridge is unpainted** — the artifact line across
   a pause must not read as a road the user sat on.
4. Phases 32 and 33 consume `showInfoSheet` / `InfoIconButton`; their copy
   goes in the same `constants.dart` banner style and should get the same
   jargon-free assertion this phase's copy has.
