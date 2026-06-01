---
status: resolved
trigger: "Diagnose stale SPEED tile during active recording — tile shows 42 km/h when vehicle is stationary; distance/elapsed/stuck appear correct."
created: 2026-05-15T00:00:00Z
updated: 2026-06-01
resolved: 2026-06-01
resolved_by: 914b5cc
---

## Resolution (2026-06-01)

Diagnosed root cause (snapshot surfaced last-accepted speed with no decay)
was fixed by commit `914b5cc fix(08-09): SPEED tile decays to 0 when GPS
samples stop arriving`. Verified in current code:
- `kTrackingSpeedFreshnessWindow = Duration(seconds: 6)` — constants.dart:230
- `TripAccumulator.snapshot()` gates `currentSpeedMs` on
  `now.difference(lastAt) <= kTrackingSpeedFreshnessWindow` — trip_accumulator.dart:207
- Tests green: trip_accumulator_test.dart "speed freshness (gap 08-02)" group,
  incl. "decays to 0 when last sample is older than the freshness window".


## Current Focus

hypothesis: TripAccumulator.snapshot() returns the last *accepted* sample's speed; once samples either stop arriving (Android throttles GPS stream when device is stationary) or get dropped by the accuracy gate (stationary fixes often have higher reported accuracy / scatter), `_lastAccepted` is stuck on the last moving sample and `currentSpeedMs` stays pinned at the in-motion value. The pipeline downstream copies that value verbatim into `currentSpeedKmh` on every UI tick — there is no decay, no "no recent sample" check, no zero-fill.
test: read TripAccumulator + tracking_state mapping + UI tile
expecting: confirm that the only producer of `currentSpeedMs` is `_lastAccepted?.speed` and that the UI path is a transparent passthrough
next_action: return ROOT CAUSE FOUND

## Symptoms

expected: SPEED tile shows current speed; drops to 0 km/h within a few seconds after the vehicle stops moving
actual: SPEED tile stays at last-seen moving value (e.g. 42 km/h) for the rest of the trip even though distance stops growing and STUCK seconds increment
errors: none — no exception thrown, app continues to function
reproduction: Start tracking on a moving vehicle, accumulate non-zero speed, then bring vehicle to a stop. Wait. SPEED tile remains at the highest-observed-recently value instead of decaying to 0.
started: appears since Phase 2 introduced active tracking; Phase 8 Plan 05 restyle did NOT introduce the bug (verified — `CurrentSpeedTile` is a transparent adapter that displays `speedKmh` as-is)

## Eliminated

- hypothesis: Phase 8 Plan 05 hardcoded a stale speed or read the wrong field in CurrentSpeedTile
  evidence: lib/features/tracking/widgets/current_speed_tile.dart line 24-30 — StatMiniCard reads `speedKmh` parameter; no constants, no caching, no derived value. tracking_tiles_row.dart line 42 passes `currentSpeedKmh` straight from TrackingActive. tracking_active_layout.dart line 64 forwards `currentSpeedKmh` from constructor. tracking_screen.dart line 62-68 destructures the sealed `TrackingActive` and passes `currentSpeedKmh` straight through. No transformation.
  timestamp: 2026-05-15

- hypothesis: Display reads `averageSpeedKmh` or `maxSpeedKmh` (a derived/aggregate value)
  evidence: TrackingActive sealed state (tracking_state.dart line 46-79) has exactly six fields and only one speed field: `currentSpeedKmh`. No average/max speed exists anywhere in the tracking module. grep across `lib/features/tracking/` shows zero references to averageSpeed/maxSpeed.
  timestamp: 2026-05-15

- hypothesis: Riverpod selector bug — state IS being updated to 0 but UI isn't rebuilding
  evidence: The UI watches the entire TrackingState (tracking_screen.dart line 119 `ref.watch(trackingStateProvider)`), not a select() of one field, so any new TrackingActive triggers rebuild. The user reports distance and stuck-time ARE updating live in the same widget tree — so the parent IS rebuilding on every snapshot. If the new state object's `currentSpeedKmh` were actually 0, the tile would re-render as 0. The notifier overwrites `state` wholesale with a fresh `TrackingActive` on every snapshot (tracking_providers.dart line 173: `state = trackingActiveFromSnapshotMap(...)`), so there's no copyWith preservation either.
  timestamp: 2026-05-15

- hypothesis: copyWith bug preserving old currentSpeedKmh while updating other fields
  evidence: There is no copyWith on TrackingActive. The notifier's `_stateSub.listen` builds a fresh TrackingActive from the snapshot map on every emission. Every field, including `currentSpeedKmh`, comes from the latest service-isolate snapshot. No partial update path exists.
  timestamp: 2026-05-15

## Evidence

- timestamp: 2026-05-15
  checked: lib/features/tracking/widgets/current_speed_tile.dart
  found: Tile is a thin adapter over StatMiniCard. Reads `speedKmh` parameter, formats with `_formatSpeed` (rounds to int; sub-0.5 → "0"). Tone switches at 10 km/h. No internal state, no caching, no providers consumed inside.
  implication: Display layer is correct. If the SPEED tile shows 42, the value passed in WAS 42 at that moment.

- timestamp: 2026-05-15
  checked: lib/features/tracking/widgets/tracking_tiles_row.dart + tracking_active_layout.dart
  found: Both are pure-forwarding StatelessWidgets. `currentSpeedKmh` flows: TrackingActiveLayout → TrackingTilesRow → CurrentSpeedTile (line 42: `CurrentSpeedTile(speedKmh: currentSpeedKmh)`). No transformations.
  implication: Plumbing layer is correct.

- timestamp: 2026-05-15
  checked: lib/features/tracking/screens/tracking_screen.dart lines 59-71
  found: The screen destructures the sealed TrackingActive and forwards the four fields it needs to TrackingActiveLayout. `currentSpeedKmh` is passed through directly.
  implication: Screen-level is correct.

- timestamp: 2026-05-15
  checked: lib/features/tracking/state/tracking_state.dart line 146
  found: trackingActiveFromSnapshotMap builds a fresh TrackingActive on every isolate snapshot. `currentSpeedKmh: _req<num>(map, 'currentSpeedMs').toDouble() * 3.6`. The ONE and ONLY m/s → km/h conversion site. Multiplication is correct.
  implication: Isolate-boundary conversion is correct. The value of `currentSpeedKmh` reflects exactly `currentSpeedMs * 3.6` from the snapshot.

- timestamp: 2026-05-15
  checked: lib/features/tracking/providers/tracking_providers.dart lines 165-175 (_stateSub listener)
  found: On every `kTrackingStateEvent`, the notifier overwrites `state` wholesale with `trackingActiveFromSnapshotMap(data.cast<String, Object?>())`. No partial update; no copyWith; no field preservation. Update cadence is `kTrackingUiUpdateInterval` = 1 second.
  implication: UI state is unconditionally replaced once per second. If the SPEED tile is stuck, the SNAPSHOT itself must have a stale value.

- timestamp: 2026-05-15
  checked: lib/features/tracking/services/tracking_service.dart lines 131-137 (UI timer)
  found: `Timer.periodic(kTrackingUiUpdateInterval, (_) { service.invoke(kTrackingStateEvent, accumulator.snapshot(DateTime.now().toUtc()).toMap()); });`. Timer runs every 1 second and pushes a fresh snapshot regardless of whether new GPS samples arrived. So the UI gets a tick every second — but the snapshot's `currentSpeedMs` is sourced from `_lastAccepted?.speed ?? 0`.
  implication: 1 Hz UI tick is independent of GPS sample arrival rate. The snapshot pulls whatever `_lastAccepted.speed` was at tick time. If `_lastAccepted` hasn't been replaced since the user stopped moving, the same 42 km/h value gets emitted forever.

- timestamp: 2026-05-15
  checked: lib/features/tracking/services/trip_accumulator.dart lines 187-198 (snapshot method)
  found: `TripSnapshot(... currentSpeedMs: _lastAccepted?.speed ?? 0)`. `_lastAccepted` is updated inside `addSample` (lines 137-184) but ONLY when a sample passes the accuracy gate `p.accuracy > kTrackingMaxAcceptableAccuracyMeters` (line 135 — note: the condition `if (p.accuracy > kTrackingMaxAcceptableAccuracyMeters) return;` DROPS the sample). The accuracy threshold is 30 meters (constants.dart line 182).
  implication: ROOT CAUSE — `currentSpeedMs` in the snapshot reflects ONLY the last sample that passed the accuracy gate. There is no "freshness" check, no time decay, no zero-fill when no fresh sample has arrived. When the vehicle stops, two things can happen, both producing the bug:
    (1) Android's location service throttles or batches GPS emissions when the device is stationary (HIGH probability — well-documented Android behaviour), so `addSample` simply isn't called for many seconds.
    (2) Stationary GPS fixes often have larger reported accuracy (the device is no longer triangulating against a moving reference, so the EKF widens), causing samples to be rejected by the 30m gate.
    In both cases `_lastAccepted` is pinned to the last in-motion fix, which had `speed ≈ 11.67 m/s ≈ 42 km/h`, and every subsequent 1 Hz snapshot re-emits that exact value.

- timestamp: 2026-05-15
  checked: lib/features/tracking/services/trip_accumulator.dart lines 169-181 (stuck classification)
  found: `if (deltaSec <= kTrackingMaxAttributableGapSeconds) { if (prev.speed >= kStuckSpeedThresholdMs) timeMoving += deltaSecInt else timeStuck += deltaSecInt; }`. Classification uses `prev.speed`, and `prev = _lastAccepted` (line 137).
  implication: The user reports STUCK ticks ARE incrementing (19s on screenshot). For the stuck counter to increment, at least SOME samples ARE arriving where `prev.speed < kStuckSpeedThresholdMs`. So scenario (1) above (zero samples) is not the exclusive cause — at least some low-speed samples are coming through. BUT: the speed shown in the UI is `_lastAccepted.speed` taken at SNAPSHOT TIME, and the snapshot fires every 1s while samples arrive every ~3s. So in the gap between samples, the snapshot keeps reading the SAME `_lastAccepted` — which after a stationary sample arrives, IS now a near-zero value. Yet the user reports it stays at 42 the WHOLE rest of the trip. This means low-speed samples are NOT replacing the in-motion `_lastAccepted` — they're being filtered out by accuracy OR they're being received but `prev.speed` from a moment ago classifies them as stuck while the LATEST speed reading on those same samples is still elevated.
  implication-2: Possible sub-cause — `Position.speed` on Android can be a *smoothed/sticky* value from the platform-level location filter. The Android fused location provider often retains a non-zero `speed` for several seconds after the device actually stops, even when the GPS fix itself updates with new lat/lng (or with the same lat/lng but updated accuracy). That would explain why STUCK ticks up (the classification uses the PREVIOUS sample's speed which by now reads ≤ threshold) yet `currentSpeedMs` from the LATEST sample still reads ≈ 11.67 m/s.

## Resolution

root_cause: |
  `TripSnapshot.currentSpeedMs` is sourced from `_lastAccepted?.speed` in
  `TripAccumulator.snapshot()` (lib/features/tracking/services/trip_accumulator.dart:196).
  This value reflects whatever `Position.speed` was on the last sample that
  passed the accuracy gate — there is no staleness check, no decay, and no
  zero-fill when no fresh fast-moving sample has been seen recently.

  Two compounding factors keep the value pinned at the in-motion value
  after the vehicle stops:

  1. Android throttles GPS stream emissions when the device is stationary,
     so `addSample` is called less frequently — but the UI snapshot timer
     still fires once per second and re-publishes the same `_lastAccepted`.
     The UI keeps showing the stale value because nothing has overwritten
     `_lastAccepted`.

  2. When stationary samples DO arrive, `Position.speed` from Android's
     fused location provider is a smoothed, sticky value that decays slowly
     toward zero over several seconds — it does not snap to 0 the moment
     the user stops. Combined with the 3-second sample interval and the
     possibility of stationary samples being rejected by the 30-meter
     accuracy gate, `_lastAccepted.speed` can remain at the in-motion
     value for the entire stationary period.

  This is NOT a Phase 8 / Plan 05 regression. The UI path
  (CurrentSpeedTile → TrackingTilesRow → TrackingActiveLayout → tracking_screen)
  is a transparent passthrough — the value displayed exactly equals
  `TrackingActive.currentSpeedKmh`, which exactly equals
  `TripSnapshot.currentSpeedMs * 3.6`. The bug is in the producer
  (`TripAccumulator.snapshot()`), not the displayer.

  The other tiles do not show this symptom because:
  - DISTANCE is a monotonically accumulating sum — it stops growing when
    the device is stationary because no new distance is added, which
    matches user expectation ("distance updating correctly" = "not
    increasing").
  - ELAPSED is computed from wall-clock time minus startedAt — always
    fresh, never sourced from sample data.
  - STUCK is classified on the prev → curr interval using prev.speed,
    which (eventually) drops below 10 km/h once at least one low-speed
    sample has been accepted; stuck-seconds then increment by deltaSec
    every interval. This produces the visible 19s STUCK counter even
    while currentSpeedMs is still stale.

fix: |
  Add a freshness guard to `TripAccumulator.snapshot()`. The fix should be
  scoped to the producer (trip_accumulator.dart) so the rest of the
  pipeline stays a pure passthrough.

  Proposed contract:
    - Track the wall-clock timestamp at which `_lastAccepted` was set
      (call it `_lastAcceptedAt`, written inside `addSample` together
      with `_lastAccepted = p`).
    - In `snapshot(DateTime now)`, treat the last accepted sample as
      "stale" if `now - _lastAcceptedAt > kTrackingSpeedFreshnessWindow`
      (suggested value: 6 seconds — i.e. 2× `kTrackingSampleInterval`).
    - When stale, emit `currentSpeedMs: 0` in the snapshot.

  Additionally, to handle the sticky-speed case where samples ARE
  arriving but `Position.speed` is still elevated despite a stationary
  device, cross-validate with distance: if the cumulative distance
  delta since `_lastAcceptedAt` is zero (or near zero, e.g. < 5m)
  for the freshness window, force `currentSpeedMs` to 0 even if the
  sample itself reports non-zero. This is a defensive cross-check
  against Android's smoothed speed value.

  Concrete shape of the snapshot method:
    TripSnapshot snapshot(DateTime now) {
      final last = _lastAccepted;
      final lastAt = _lastAcceptedAt;
      var speed = last?.speed ?? 0.0;
      if (last == null || lastAt == null ||
          now.difference(lastAt) > kTrackingSpeedFreshnessWindow) {
        speed = 0.0;
      }
      return TripSnapshot(
        startedAt: startedAt,
        elapsedSeconds: now.difference(startedAt).inSeconds,
        distanceMeters: _distanceMeters,
        timeMovingSeconds: _timeMovingSeconds,
        timeStuckSeconds: _timeStuckSeconds,
        currentSpeedMs: speed,
      );
    }

  New constant in lib/config/constants.dart:
    /// How fresh `_lastAccepted.speed` must be for the snapshot to surface it
    /// as `currentSpeedMs`. Older than this and the snapshot reports 0 so the
    /// UI SPEED tile decays correctly when the device stops moving.
    const Duration kTrackingSpeedFreshnessWindow = Duration(seconds: 6);

  Required unit-test additions in test/unit/features/tracking/trip_accumulator_test.dart:
    - Given a `TripAccumulator` that received a 42 km/h sample at t=0,
      `snapshot(t = 10s later)` returns `currentSpeedMs == 0`.
    - Given a sample at t=0 and another at t=2s with speed 0,
      `snapshot(t=2s)` returns 0 (latest sample wins).
    - Given a sample at t=0 and no further samples, `snapshot(t=4s)` still
      returns the original speed (under the 6-second window).

  This fix is small, local to the producer, and preserves the unit-conversion
  contract documented in tracking_state.dart (the boundary still divides by
  3.6 at exactly one site).

verification: |
  (pending — fix not applied; this session is diagnose-only per UAT goal:
  find_root_cause_only)

files_changed: []
