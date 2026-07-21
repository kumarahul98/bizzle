---
phase: 31-trip-detail-breaks-stuck-transparency
created: 2026-07-21
status: not_started
mode: manual-gsd
requirements: [UX-09, TRACK-15]
depends_on: [18, 19, 27]
result: >
  NOT STARTED. Plan only. This phase adds the first schema (v9) of the
  post-v0.3-UAT batch and must land before Phase 33 (v10) and Phase 35 (v11).
  It also introduces the shared InfoSheet widget that Phases 32 and 33 consume,
  so it is the head of the batch dependency chain.
---

# Phase 31 — Trip Detail: Breaks, Stuck Transparency, Edit Gating

**Goal**: Opening a trip shows what actually happened on that drive — the breaks the
user took, where on the map they were actually stuck, and an honest explanation of how
"stuck" is measured — while direction edits move behind the Edit button where every
other trip edit already lives.

**Depends on**: Phase 18 (the `trip_breaks` table and the pause model this surfaces),
Phase 19 (`EditTripSheet`, which becomes the sole direction write path), Phase 27 (the
accuracy work in `TripAccumulator` that this phase extends rather than re-derives)

---

## D-01 — Direction becomes read-only outside Edit

Today the trip detail screen carries a live `DirectionSegmentedToggle`
(`trip_detail_screen.dart:377-380`) that writes immediately via `_handleDirectionChanged`
(`:120-145`). Every other field on a trip — start time, end time, breaks — is editable
only inside `EditTripSheet`. Direction is the lone exception, and it is a destructive
one: a mis-tap on a scrolling screen silently rewrites a trip's classification and, with
it, that trip's contribution to the to-office/to-home averages.

Remove the toggle and `_handleDirectionChanged`. Direction stays **visible** as the
existing title text (`:358-372`). `EditTripSheet`'s own `_DirectionField`
(`edit_trip_sheet.dart:267`) becomes the single write path.

This also collapses a real duplication. There are currently **three** direction
controls in the codebase — the detail-screen toggle, the edit-sheet field, and the
tracking-screen toggle. After this phase there are two, each with a distinct purpose
(label-while-recording, and edit-after-the-fact).

Note the incidental benefit: `_handleDirectionChanged` is the only writer that forced
the non-reactive `_loadTrip()` refresh dance on this screen. Removing it shrinks the
screen's state surface.

## D-02 — Persist stuck runs as polyline index ranges

The blocker for painting stuck locations is that the classification **already exists**
and is then thrown away. `TripAccumulator.addSample()` classifies every interval at
`trip_accumulator.dart:375` (`prev.speed < kStuckSpeedThresholdMs`), adds it to the
aggregate counter, and discards the per-interval result. At `finalize()` (`:482-486`)
the samples collapse into an encoded polyline and speed is gone forever.

| Option | Verdict |
|---|---|
| Full `trip_points` table (lat/lng/speed/accuracy/ts per sample) | **Rejected.** ~900 rows per 45-minute commute, ~650k rows/year, and a large new sync surface — to serve one map colour. |
| Encoded speed array on `trips` | **Rejected.** Puts a per-point blob on the hottest row in the schema and re-derives the classification at render time, risking divergence from the stored aggregate. |
| **Contiguous stuck runs as polyline index ranges** | **Chosen.** ~5–20 rows per trip, stores the decision rather than the inputs, and cannot disagree with `timeStuckSeconds` because it is written from the same classification. |

New table `trip_stuck_segments`:

| Column | Type | Notes |
|---|---|---|
| `id` | text (UUID) | PK, client-generated |
| `tripId` | text | FK → `trips.id`, **`onDelete: KeyAction.cascade`** |
| `startPointIndex` | integer | index into the decoded polyline |
| `endPointIndex` | integer | inclusive |
| `startTime` | dateTime | UTC |
| `endTime` | dateTime | UTC |

**The index correlation is exact and requires no heuristics.** Every sample that
survives the accuracy gate is appended to `_samples` (three sites: `:308`-guarded first
sample, the `deltaMillis <= 0` branch, the paused branch, and the normal path), and
`encodePolyline` maps `_samples` in order. Therefore **sample index == polyline point
index**, always. The accuracy gate drops samples *before* they reach `_samples`, so it
cannot desynchronise the two; the min-move floor affects only `_distanceMeters` and
never the sample list.

Add a parallel `List<StuckIntervalClass> _intervalClasses` written at each site that
appends to `_samples`, where entry `i` classifies the interval from point `i-1` to point
`i`. Three values:

- `stuck` — `prev.speed < kStuckSpeedThresholdMs`
- `moving` — otherwise
- `unattributed` — first sample, accuracy drop, `deltaMillis <= 0`, paused, or gap >
  `kTrackingMaxAttributableGapSeconds`

**Reuse the existing classification at `:375`. Never compute a second speed comparison.**
This is the D-11 rule from Phase 18 that keeps the auto-pause detector and the stuck
metric from drifting apart, and it applies with equal force here: a segment painted red
on the map that disagrees with the number printed above it would be worse than no
segments at all.

## D-03 — Run-collapsing rules at finalize

At `finalize()`, walk `_intervalClasses` and collapse **contiguous** `stuck` runs.

- `unattributed` intervals **break a run** rather than extending it. A GPS blackout is
  not evidence of being stuck; bridging one would paint a red line through a tunnel the
  user drove at speed.
- `moving` intervals break a run, obviously.
- Runs shorter than a new `kStuckSegmentMinSeconds` (**60s**) are discarded. Without a
  floor, every red light produces a 15-second speck and the map becomes stippled noise
  that communicates nothing. 60s also aligns with the user-facing framing: the explainer
  (D-07) says "stuck", and a normal signal wait is not what anyone means by stuck.

The sum of retained segment durations is therefore **≤ `timeStuckSeconds`**. This is
expected, not a bug, and the explainer copy must not claim the map accounts for the
whole figure.

## D-04 — Stuck segments are local-only

Not added to `trip_serializer.dart`, not sent to Firestore, not returned by restore.

They are derived presentation data. Firestore is a backup, not a source of truth
(CLAUDE.md), and the segments are reconstructible from nothing once the raw samples are
gone — so syncing them would grow every payload permanently to protect data that has no
independent value. The Phase 26 trip payload key-set test must still pass **unchanged**,
proving trip sync did not silently gain a field.

Consequence: restored trips have no segments. See D-06.

## D-05 — Map paints stuck runs as additional polylines

`_MapSection` (`trip_detail_screen.dart:616-682`) currently emits exactly one
`Polyline` (`:659-667`). Change it to emit the base route in `colorScheme.primary` plus
one `tokens.stuck`-coloured `Polyline` per segment over its sub-range, **duplicating the
boundary point** so segments visually join rather than leaving a hairline gap.
`PolylineLayer.polylines` already takes a list; no package change, no new dependency.

Extract `_MapSection` into `lib/features/trips/widgets/trip_map_section.dart`.
`trip_detail_screen.dart` is 682 lines and CLAUDE.md caps widgets at ~100; this phase
adds to that screen, so the extraction is not optional tidying.

Draw order matters: stuck segments must render **after** (on top of) the base route, or
the primary-coloured line hides them.

## D-06 — Graceful degradation, and no backfill is possible

Trips recorded before this phase, manual entries, and trips arriving via cloud restore
all have zero segment rows. They render exactly as today: one polyline, no stuck rows in
the timeline. No error, no empty state, no "data unavailable" badge — the map simply
looks like it does now.

**Backfill is impossible and must not be attempted.** The source samples were never
persisted; `TripStatePersister`'s snapshot (which does carry speed) is deleted at
`finalize()` (`trip_accumulator.dart:500`). Any "backfill" would be fabrication. This is
the same failure mode as the current `TripTimeline`, which D-07 exists to remove.

## D-07 — Real breaks and stuck rows replace the fabricated timeline

`TripTimeline` today invents a "Stuck in traffic" row and places it at a **hardcoded 40%
of trip duration** (`trip_timeline.dart:44-46`). It is not derived from anything. A user
comparing that marker against their memory of the drive is being shown a fiction.

Replace the synthetic rows with real ones, ordered by time:

- **Breaks** from `trip_breaks`, via `TripBreaksDao.watch(tripId)` — a reactive stream
  that already exists and is currently called from nowhere.
- **Stuck segments** from the new table, using `startTime`/`endTime`.
- Retain the real Started / Arrived anchors.

Breaks are **not** painted on the map. While paused, samples are still appended so the
path bridges the gap as one straight line (Phase 18 D-05) — that line is an artifact of
the bridge, not a road the user travelled, so colouring it would assert a location that
was never visited.

This makes the timeline and the map agree, which they do not today.

## D-08 — Shared `InfoSheet` (owned here, consumed by 32 and 33)

No info-icon or explanation-sheet pattern exists anywhere in the codebase. Three items
across this batch need one (stuck time here, weekly summary in Phase 32, auto-pause in
Phase 33), so it is built once here rather than three times inconsistently.

New `lib/shared/widgets/info_sheet.dart`: a small tappable info icon plus a
`showModalBottomSheet` explainer, styled after `sign_in_sheet.dart:30`
(`surfaceContainerLowest`). All copy lives in `constants.dart` per CLAUDE.md.

Stuck-time copy is plain-language and honest about the floor from D-03: anything under
10 km/h counts as stuck, it is measured continuously while recording, time during breaks
is excluded, and the map highlights the longer stretches rather than every brief halt.

---

## Execution waves (conflict-safe)

**Wave 1 — data and the shared widget** (no shared files between the two)

- `31-01` — `StuckIntervalClass` + `_intervalClasses` in `TripAccumulator`, the
  run-collapsing algorithm at finalize, the `trip_stuck_segments` table + DAO, migration
  **v9**, and the `FinalizedTrip` DTO extension carrying segments across the isolate
  boundary as primitive maps. **Owns all Drift work in this phase.**
- `31-02` — `lib/shared/widgets/info_sheet.dart` + constants. *(Independent of 31-01;
  may run in parallel.)*

**Wave 2 — the screen** *(blocked on both Wave 1 plans)*

- `31-03` — remove the direction toggle and `_handleDirectionChanged`; extract
  `trip_map_section.dart` and paint segments; rewrite `TripTimeline` against real breaks
  and segments; attach the stuck `InfoSheet`.

---

## Threat model

| ID | Category | Asset | Decision | Mitigation |
|---|---|---|---|---|
| T-31-01 | Information disclosure | Stuck segments reveal where the user idles — home, workplace, a clinic | mitigate | Local-only by D-04; never synced, never logged. Strictly less exposure than the route polyline already stored on the same row. |
| T-31-02 | Tampering | Segment indices out of range for the stored polyline | mitigate | Clamp on read: any segment whose `endPointIndex` exceeds the decoded point count is skipped, not drawn partially. Guards against a truncated polyline after a failed write. |
| T-31-03 | Data integrity | Map contradicting the printed `timeStuckSeconds` | mitigate | Segments are written from the *same* classification that feeds the counter (D-02). The explainer states the map shows longer stretches only, so `sum(segments) ≤ timeStuckSeconds` is stated, not hidden. |
| T-31-04 | Data loss | Orphaned segment rows after trip deletion | mitigate | `onDelete: KeyAction.cascade` on the FK from the outset. Note the pre-existing `trip_breaks` cascade gap is fixed in Phase 35, not here. |
| T-31-05 | Denial of service | Unbounded segment rows on a pathological trip | mitigate | The 60s floor (D-03) bounds count at `duration / 60`. A 2-hour trip cannot exceed 120 rows even in the worst alternating case. |

---

## Success criteria (what must be TRUE)

1. Direction **cannot** be changed from the trip detail view; it is changeable only
   inside `EditTripSheet`, and the direction shown on the detail screen updates after an
   edit is saved.
2. A trip recorded after this phase shows red stuck stretches on its map that correspond
   to where the user was actually below 10 km/h for at least 60 continuous seconds.
3. The sum of painted segment durations never exceeds the trip's `timeStuckSeconds`.
4. A GPS gap longer than `kTrackingMaxAttributableGapSeconds` never appears as a painted
   stuck stretch.
5. A trip recorded **before** this phase opens without error and renders a plain single
   polyline with no stuck rows — no empty state, no error message.
6. The trip timeline shows the user's real breaks and real stuck stretches in time
   order; the hardcoded 40% marker no longer exists anywhere in the codebase.
7. An info icon beside the stuck figure opens a plain-language explanation with no
   technical jargon (no "m/s", no "sample", no "threshold").
8. The Phase 26 trip-payload key-set test passes unchanged — trip sync gained no field.
9. `schemaVersion` is 9 and a v8 → v9 upgrade preserves every existing trip.

## Verification

- Unit: run-collapsing algorithm — contiguous stuck merges; `moving` splits;
  `unattributed` splits (does not bridge); sub-60s runs discarded; a run at the very
  first and very last interval; an all-stuck trip; an all-moving trip.
- Unit: `sum(segment durations) <= timeStuckSeconds` asserted over generated sample
  sequences.
- Unit: index correlation — a sequence including accuracy-rejected samples asserts
  segment indices still address the correct decoded polyline points.
- Unit: `TripBreaksDao.watch` drives timeline rows; ordering with interleaved breaks and
  stuck segments.
- Widget: detail screen has no direction control; a segment-less trip renders one
  polyline; a trip with segments renders `1 + N` polylines.
- Migration: `SchemaVerifier` v8 → v9.
- `flutter analyze` and `dart format .` clean.
- **Manual**: record a real drive with genuine stop-and-go traffic; confirm red stretches
  land where you were actually stuck and not on free-flowing sections.
- **Manual**: open a trip recorded before this build; confirm it renders cleanly.
- **Manual**: record a trip with a break; confirm the break appears in the timeline and
  that the bridge line across the break is **not** painted red.
