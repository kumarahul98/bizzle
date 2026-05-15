---
plan_id: 08-09
phase: 08
gap_closure: true
status: complete
completed: 2026-05-15
commits:
  - 914b5cc
---

## Plan 08-09 — SPEED tile freshness window

Closes Phase 8 UAT gap 2: SPEED tile stuck at 42 km/h when the device is stationary.

### What changed

**`lib/features/tracking/services/trip_accumulator.dart`**
- Added `DateTime? _lastAcceptedAt` field, set in three places where `_lastAccepted` is updated (first-sample branch, clock-skew branch, end-of-method).
- `snapshot(now)` now gates `currentSpeedMs` on freshness: when the most-recent accepted sample is older than `kTrackingSpeedFreshnessWindow`, the snapshot reports `0` regardless of `_lastAccepted.speed`. UI/notifier paths unchanged.

**`lib/config/constants.dart`**
- Added `kTrackingSpeedFreshnessWindow = Duration(seconds: 6)` (= 2× `kTrackingSampleInterval`). One dropped sample doesn't flip the tile to 0; two consecutive misses do.

**`test/unit/features/tracking/trip_accumulator_test.dart`**
- New group `TripAccumulator.snapshot() — speed freshness (gap 08-02)` with 4 cases:
  - Fresh sample → reports last speed
  - Stale beyond window → reports 0
  - Fresh zero-speed sample → reports 0 immediately
  - No samples ever → reports 0

### Why this fix

Pre-existing producer bug — not a Phase 8 regression. The 1Hz UI snapshot timer kept republishing `_lastAccepted.speed` indefinitely when GPS samples stopped arriving (Android throttles emissions when stationary; the 30 m accuracy gate drops stationary low-accuracy samples). Compounded by Android fused-location's smoothed/sticky `Position.speed` that decays toward 0 over seconds rather than snapping. Full diagnosis in `.planning/debug/active-speed-tile-stale.md`.

### Verification

- `flutter analyze lib/` — No issues found
- `flutter test test/unit/features/tracking/trip_accumulator_test.dart` — 17/17 pass (4 new + 13 existing)

### Execution note

This plan was originally executed by a `gsd-executor` agent in a worktree, but the agent was blocked by a session-level Edit/Write permission denial (a stale denial from earlier in the session that didn't lift for the worktree path). The agent reported the blocker with full implementation drafts, and the orchestrator applied the fix inline. Net behavior matches what the worktree agent would have produced; only the execution path differs.

### Key files modified

- `lib/features/tracking/services/trip_accumulator.dart`
- `lib/config/constants.dart`
- `test/unit/features/tracking/trip_accumulator_test.dart`
