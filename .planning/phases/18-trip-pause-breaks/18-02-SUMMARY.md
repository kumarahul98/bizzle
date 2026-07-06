---
phase: 18-trip-pause-breaks
plan: 02
subsystem: tracking
tags: [trip-accumulator, pause, breaks, drift, isolate-boundary, tdd]

# Dependency graph
requires:
  - phase: 18-01
    provides: trip_breaks table + TripBreaksDao.insertBreaks + trips.totalPausedSeconds column + tripBreaksDaoProvider
provides:
  - Pause-aware TripAccumulator (pause/resume model, frozen elapsed, polyline-only paused samples)
  - FinalizedTrip DTO extended with totalPausedSeconds + primitive breaks list
  - TripSnapshot extended with isPaused/pausedSeconds/breakCount (primitive isolate-safe fields)
  - Atomic persist path writing trip_breaks rows + total_paused_seconds inside the existing transaction
affects: [18-03 pause UI wiring, 19 trip/break editing, 22 home-screen widget state]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pause model on a streaming accumulator: closed (start,end) segment list + accumulated paused seconds + open-break anchor"
    - "Frozen-timer formula: elapsed = (isPaused ? pauseStart : now) - startedAt - accumulatedPausedSeconds (closed segments only)"
    - "Backward-tolerant primitive decode: new isolate-channel fields read via `map['k'] as T? ?? default` so legacy maps still parse"
    - "Deep value-equality for a primitive List<Map> via per-element mapEquals (foundation) — no extra dependency"

key-files:
  created: []
  modified:
    - lib/features/tracking/services/trip_accumulator.dart
    - lib/features/tracking/state/finalized_trip.dart
    - lib/features/tracking/services/tracking_service_controller.dart
    - lib/features/tracking/providers/tracking_providers.dart
    - test/unit/features/tracking/trip_accumulator_test.dart
    - test/unit/features/tracking/persist_finalized_trip_test.dart
    - test/unit/features/tracking/tracking_notifier_test.dart
    - test/unit/features/tracking/tracking_notifier_direction_test.dart

key-decisions:
  - "Frozen elapsed subtracts only CLOSED paused segments; the open break is excluded by freezing refNow at the pause instant (avoids double-count → negative elapsed)"
  - "pausedSeconds in the snapshot DOES include the open break span (UI affordance), but elapsedSeconds does NOT (timer is frozen) — distinct semantics, both correct"
  - "Break list equality uses mapEquals from flutter/foundation per-element instead of package:collection DeepCollectionEquality to avoid a non-transitive depend_on_referenced_packages lint"
  - "totalPausedSeconds written explicitly into TripsCompanion.insert (not left to DB default) so the trip row and its break rows are always internally consistent"

patterns-established:
  - "Paused addSample appends the Position to the polyline then early-returns BEFORE any distance/time attribution — the bridge line draws but no metric moves (T-18-04)"
  - "finalize closes an open break at endedAt so a persisted trip never carries a null-endTime segment"

requirements-completed: [TRACK-09]

# Metrics
duration: 52min
completed: 2026-06-06
---

# Phase 18 Plan 02: Pause-Aware Accumulator + Break Persistence Summary

**TripAccumulator now pauses: while paused it draws the polyline bridge but attributes zero distance/moving/stuck and freezes the displayed timer; finalize emits ACTIVE duration (wall − paused) plus primitive break segments, and the persist path writes trip_breaks rows + total_paused_seconds atomically inside the existing transaction.**

## Performance

- **Duration:** 52 min
- **Started:** 2026-06-06T04:42:41Z
- **Completed:** 2026-06-06T05:34:37Z
- **Tasks:** 2 completed
- **Files modified:** 8

## Accomplishments
- `TripAccumulator` gained a full pause/resume model: `pause(at)`/`resume(at)` (UTC, idempotent no-op guards), a closed-segment list, accumulated paused seconds, and an open-break anchor. While paused, `addSample` appends the position to the polyline then early-returns before any distance/moving/stuck attribution — the core "time stuck in traffic" metric is never corrupted by paused time (T-18-04).
- `snapshot.elapsedSeconds` freezes the instant pause fires and resumes ticking after resume (D-06). The snapshot also carries primitive `isPaused`/`pausedSeconds`/`breakCount` fields that round-trip through `toMap`/`fromMap` (T-18-05) with backward-tolerant decode for legacy maps.
- `finalize(endedAt)` closes any open break at `endedAt`, sets `durationSeconds = wall − totalPaused` (ACTIVE duration, D-03/D-07), and emits the completed `(start,end)` segments on `FinalizedTrip.breaks` as a primitive `List<Map<String,Object?>>` of UTC microseconds.
- The persist path (`persistFinalizedTrip`) now writes `trips.total_paused_seconds` and batch-inserts `trip_breaks` rows via `TripBreaksDao` inside the SAME `_database.transaction` as the trip + sync-queue insert — atomic, all-or-nothing (T-18-06).
- 19 new TDD tests added (406 → no, 407 → 426 total green); a no-pause trip is byte-for-byte identical to before (regression-safe).

## Task Commits

1. **Task 1: Pause-aware TripAccumulator + extended snapshot/DTO** — `88d4a45` (feat, TDD test+impl in one atomic commit)
2. **Task 2: Persist break segments + total_paused_seconds atomically** — `bae7cac` (feat, TDD test+impl + construction-site fixes)

_TDD note: per project convention the new failing tests and their implementation were authored together and verified RED→GREEN in-session, then committed atomically with the production code (matching the existing repo history style of combined `[tracking]` commits)._

## Files Created/Modified
- `lib/features/tracking/services/trip_accumulator.dart` — pause/resume model, paused-branch early-return in addSample, frozen-elapsed snapshot, finalize close-open-break + active duration + primitive breaks; TripSnapshot gains isPaused/pausedSeconds/breakCount.
- `lib/features/tracking/state/finalized_trip.dart` — `totalPausedSeconds` + `breaks` threaded through ctor/fromMap/toMap/copyWith/==/hashCode with deep value-equality.
- `lib/features/tracking/services/tracking_service_controller.dart` — required `TripBreaksDao` dep; transaction writes total_paused_seconds + batch break rows; `_breakRowsFor` helper.
- `lib/features/tracking/providers/tracking_providers.dart` — injects `tripBreaksDaoProvider`.
- `test/unit/features/tracking/trip_accumulator_test.dart` — 13 new pause/snapshot/DTO assertions.
- `test/unit/features/tracking/persist_finalized_trip_test.dart` — 2 new persist assertions + break-rollback assertion on the failure path.
- `test/unit/features/tracking/tracking_notifier_test.dart`, `tracking_notifier_direction_test.dart` — updated controller construction for the new required dep.

## Verification

- `flutter test test/unit/features/tracking/trip_accumulator_test.dart` — 29 passed.
- `flutter test test/unit/features/tracking/persist_finalized_trip_test.dart` — 7 passed.
- Full `flutter test` — **426 passed, 10 skipped, 0 failed** (was 407 green pre-plan; +19 new tests, no regressions).
- `flutter analyze` on the four modified `lib/` files — **No issues found**.
- Full-project `flutter analyze` — 111 pre-existing `info` lints, NONE in this plan's modified files (verified).

## Decisions Made

1. **Frozen elapsed subtracts only closed paused segments.** The open break is already excluded by freezing `refNow` at the pause instant; subtracting the open span again drove elapsed negative in the first RED run. Fixed to use `_accumulatedPausedSeconds` (closed segments) in the elapsed formula while `pausedSeconds` (the reported field) still includes the open span for the UI.
2. **`mapEquals` (foundation) over `DeepCollectionEquality` (collection).** The first implementation imported `package:collection`, which is only a transitive dependency and triggered `depend_on_referenced_packages`. Switched to per-element `mapEquals` from `flutter/foundation` (already imported) — no pubspec change, no resolve.
3. **`totalPausedSeconds` written explicitly into `TripsCompanion.insert`** rather than relying on the DB default, keeping the trip row consistent with its break rows.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated two extra TrackingServiceController construction sites**
- **Found during:** Task 2 (full-suite compile)
- **Issue:** The plan listed only `persist_finalized_trip_test.dart` as a controller construction site, but the new required `tripBreaksDao` param broke compilation in `tracking_notifier_test.dart` (via a `_RecordingController extends TrackingServiceController` subclass using `super.` forwarding) and `tracking_notifier_direction_test.dart`.
- **Fix:** Added `required super.tripBreaksDao` to the subclass and `tripBreaksDao: db.tripBreaksDao` to all three test construction sites.
- **Files modified:** `test/unit/features/tracking/tracking_notifier_test.dart`, `test/unit/features/tracking/tracking_notifier_direction_test.dart`
- **Commit:** `bae7cac`

**2. [Rule 1 - Bug] Frozen-elapsed double-count produced negative elapsed**
- **Found during:** Task 1 (first GREEN run)
- **Issue:** Using `_pausedSecondsAt(now)` (which includes the open span) in the elapsed formula together with a frozen `refNow` double-subtracted the open break, yielding `elapsed = -20`.
- **Fix:** Elapsed subtracts only `_accumulatedPausedSeconds`; the open span stays out of elapsed but remains in the reported `pausedSeconds`.
- **Files modified:** `lib/features/tracking/services/trip_accumulator.dart`
- **Commit:** `88d4a45`

### Library deviation
- Plan §Task 1 suggested `package:collection` `DeepCollectionEquality` "if needed". Used `mapEquals` from `flutter/foundation` instead to avoid adding a non-transitive package reference (see Decision 2). No behavioural difference — both give deep value equality for the primitive break list.

### TDD-commit-granularity note
- The plan's `tdd="true"` tasks imply separate RED `test(...)` then GREEN `feat(...)` commits. This repo's existing tracking history (e.g. prior `[tracking]` commits) combines test+impl into one atomic `[tracking]` commit, and CLAUDE.md mandates the `[tracking]` prefix and "one concern per commit". To match the established repo convention, each task's tests and implementation were authored and verified RED→GREEN in-session, then committed together. No RED-only commit exists in git history for this plan.

## Threat Surface

No new threat surface beyond the plan's `<threat_model>`. T-18-04 (paused-time leak), T-18-05 (non-primitive isolate field), and T-18-06 (partial persist) are all mitigated and covered by dedicated tests:
- T-18-04: "paused addSample adds no distance/moving/stuck" + "no-pause regression".
- T-18-05: "toMap/fromMap round-trips breaks + totalPausedSeconds as primitives" + snapshot round-trip + legacy-map decode.
- T-18-06: "persists break rows + total_paused_seconds atomically" + "rolls back ... no break row survives".

## Known Stubs

None. No backend sync contract changed; breaks stay local this phase (per plan and CLAUDE.md client-authoritative one-way sync — breaks are not yet in the REST payload, by design for Phase 18).

## Self-Check: PASSED

All modified lib files, the SUMMARY, and both task commits (88d4a45, bae7cac) verified present on disk and in git history.
