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

## 999.2 — App kill + relaunch trip recovery — ✅ IMPLEMENTED 2026-07-20 (device verification pending)

**Status:** Implemented on main in `ef4d03e` (merged `53ffb6d`). The file-based
approach proposed below was built essentially as specified, with two deliberate
deviations and one correction to the deferral rationale — see "Resolution" at the
end of this item. **Device verification has NOT been run**; the repro below is the
acceptance test and is still outstanding.

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

---

### Resolution (2026-07-20, `ef4d03e`)

The "partial fix" above was worse than it sounds: **the MethodChannel had no
native handler anywhere in `android/`**, so every stop threw
`MissingPluginException` into the swallowing `on Object` catch. It never
persisted anything, on any build, ever. Worse, `TripAccumulator.finalize()`
clears `active_trip.json` immediately BEFORE that call — so both recovery nets
were down at the same moment, and the second existed specifically to cover the
first being cleared.

Registering the handler would NOT have fixed it. That code runs in the
`flutter_background_service` isolate, which has its own `FlutterEngine`; a
handler bound to `MainActivity`'s engine is invisible to it. Do not cite this
item as precedent for a `configureFlutterEngine` MethodChannel.

**Built as:** `lib/features/tracking/services/pending_trip_store.dart` —
temp-file + atomic rename, cleared by the controller on both terminal outcomes
(saved / discarded-too-short) and deliberately RETAINED on failure so recovery
retries. Recovery imports on launch, deduping by trip id via the existing
`TripsDao.findById`. 9 unit tests.

**Deviations from the proposal above, both deliberate:**

| Proposed | Built | Why |
|---|---|---|
| `getApplicationCacheDirectory()` | `getApplicationDocumentsDirectory()` | Android can evict the cache dir under storage pressure. A recovery file the OS may delete is not a recovery file. |
| Check in `main()` | Check in `TrackingNotifier.build()` | Needs the DAO + controller; `main()` has no clean Riverpod access. |

**The deferral rationale was wrong.** "Requires passing data from `main()` to the
service isolate… needs an fbs mechanism not yet used" — no such mechanism is
needed. `path_provider` works *inside* the background isolate; `TripStatePersister`
already calls it there on the GPS hot path. No cache-dir hand-off, no fbs initial
data. The ~1 hour estimate was inflated by an untested assumption.

**STILL OUTSTANDING — device verification.** Run the 2026-04-15 repro against the
fix: force-stop while tracking, tap Stop from the notification, relaunch, and
confirm the trip now appears in history instead of a fresh idle state. No test in
the repo can exercise this.
