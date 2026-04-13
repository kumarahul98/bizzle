# Backlog — Parking Lot

Ideas and deferred items that are out of scope for the active milestone
but worth remembering. Entries are promoted into the roadmap via
`/gsd:review-backlog` during milestone planning.

## 999.1 — Velocity-jump gate in TripAccumulator

**Source:** Phase 2 device verification (2026-04-13)
**Trigger:** Phase 3 planning (core-tracking polish)
**Requirement tag:** TRACK-04 (hardening)

**Problem:**
`TripAccumulator.addSample()` calls `Geolocator.distanceBetween(prev, current)`
with no sanity check on the sample-to-sample delta. A single GPS "teleport"
(emulator switching routes, fused provider returning a stale cached fix, or
a rare real-device hiccup between tunnels / Wi-Fi positioning handoffs)
gets added verbatim to the running distance counter.

**Observed during emulator testing:** a trip recorded distance = 14,021,378 m
(14,021 km) in 6 minutes because one sample crossed roughly half the globe.

**Proposed fix (Phase 3):**
In `trip_accumulator.dart:addSample`, before attributing the interval to
distance / moving / stuck, compute `velocityMs = deltaMeters / deltaSeconds`.
If `velocityMs > kTripMaxPlausibleVelocityMs` (e.g., 300 m/s ≈ 1,080 km/h —
faster than a jumbo jet), drop the sample entirely and log a tracking-error
event via `service.invoke(kTrackingErrorEvent, {'reason': 'velocity_jump'})`
so the UI can decide how to react.

Add a unit test in `trip_accumulator_test.dart` that feeds two samples
50 km apart with a 1-second timestamp gap and asserts neither distance nor
moving/stuck counters moved.

**Why deferred:**
Real-device GPS won't teleport. The bug was only discovered via emulator
Route Player transitions. Blocking Phase 2 on this would cost a day; folding
it into Phase 3 (which already touches the tracking feature for direction
auto-labeling) costs ~30 minutes.

**Also consider:** adding `kTripMaxPlausibleVelocityMs` to
`lib/config/constants.dart` alongside `kTrackingMaxAcceptableAccuracyMeters`
and `kTrackingMaxAttributableGapSeconds` — they form the same family of
"reject obviously-wrong GPS samples" constants.
