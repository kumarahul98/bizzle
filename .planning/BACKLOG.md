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

## 999.2 — App kill + relaunch trip recovery

**Source:** Phase 2 device verification (2026-04-15)
**Trigger:** Phase 3 planning
**Requirement tag:** TRACK-05 (resilience)

**Problem:**
If the app process is killed (force-stop or Android memory pressure) while a
trip is active and the user then taps Stop from the foreground service
notification, the service isolate finalizes the trip in memory and emits
`kTripFinalizedEvent` — but the UI isolate is dead so nothing receives it.
The trip is lost. On relaunch the app shows `TrackingIdle` with no result.

**Observed during device verification (2026-04-15):** force-stopping via
`adb shell am force-stop traevy.traevy` then tapping Stop from the notification
brought the app to foreground in a fresh idle state with no trip result.

**Proposed fix (Phase 3):**
In `tracking_service.dart` stop handler, before emitting `kTripFinalizedEvent`,
write the serialized trip to a local file using `dart:io`:

```dart
// Pass app cache dir from main() to service via fbs initial data,
// then in the stop handler:
final file = File('$cacheDir/pending_trip.json');
await file.writeAsString(jsonEncode(trip.toMap()));
```

In `main()`, on boot, check for `pending_trip.json`. If found, load it,
trigger `TrackingServiceController.persistFinalizedTrip`, and delete the file.
Use `path_provider`'s `getApplicationCacheDirectory()` in `main()` to get the
dir, pass the path string to the service via fbs initial configuration.

**Why deferred:**
Requires passing data from `main()` to the service isolate at startup, which
needs an fbs mechanism not yet used in the codebase. Force-stop while tracking
is an unusual edge case; Android rarely kills foreground services under normal
conditions. Folding into Phase 3 (which already touches tracking internals)
costs ~1 hour.

**Partial fix already merged:** `tracking_service.dart` stop handler now makes
a method channel call `savePendingTrip` as a placeholder. Replace with the
`dart:io` file approach in Phase 3 (remove the unused method channel import
and `dart:convert` import when doing so, or repurpose them for the file write).
