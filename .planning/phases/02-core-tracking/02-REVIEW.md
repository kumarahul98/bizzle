---
phase: 02-core-tracking
reviewed: 2026-04-12T00:00:00Z
depth: standard
files_reviewed: 29
files_reviewed_list:
  - lib/features/tracking/services/trip_accumulator.dart
  - lib/features/tracking/services/tracking_permission_service.dart
  - lib/features/tracking/services/tracking_service.dart
  - lib/features/tracking/services/tracking_service_controller.dart
  - lib/features/tracking/services/tracking_service_events.dart
  - lib/features/tracking/services/tracking_notification_service.dart
  - lib/features/tracking/state/tracking_state.dart
  - lib/features/tracking/state/finalized_trip.dart
  - lib/features/tracking/providers/tracking_providers.dart
  - lib/features/tracking/screens/home_screen.dart
  - lib/features/tracking/screens/tracking_screen.dart
  - lib/features/tracking/widgets/duration_tile.dart
  - lib/features/tracking/widgets/distance_tile.dart
  - lib/features/tracking/widgets/current_speed_tile.dart
  - lib/features/tracking/widgets/permission_banner.dart
  - lib/features/tracking/widgets/permission_gate.dart
  - lib/features/tracking/widgets/tracking_tiles_row.dart
  - lib/features/tracking/widgets/tracking_idle_layout.dart
  - lib/features/tracking/widgets/tracking_active_layout.dart
  - lib/features/tracking/widgets/tracking_status_layout.dart
  - lib/features/tracking/widgets/tracking_error_layout.dart
  - lib/shared/utils/polyline_codec.dart
  - lib/config/constants.dart
  - lib/config/routes.dart
  - lib/app.dart
  - lib/main.dart
  - android/app/build.gradle.kts
  - android/app/src/main/AndroidManifest.xml
  - pubspec.yaml
findings:
  critical: 0
  warning: 4
  info: 7
  total: 11
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-04-12
**Depth:** standard
**Files Reviewed:** 29
**Status:** issues_found

## Summary

Phase 2 delivers a well-scoped two-isolate tracking pipeline: `TripAccumulator` + `TripSnapshot` own the accumulation math, `tracking_service.dart` hosts the background isolate entrypoint with the D-14 notification unification, and `TrackingServiceController.persistFinalizedTrip` wraps the Drift insert + sync-queue enqueue in a single transaction. Tests cover the Pitfall 2 m/s tripwire (5 km/h → 40 km/h), the transaction rollback path, the two-step permission ordering invariant, and the notifier state machine. Unit conventions (sealed states, const-singleton idle/starting/stopping variants, feature-local event constants) and CLAUDE.md rules (no hardcoded thresholds, widgets under 100 lines, Drift-only UI reads) are respected throughout.

No critical issues were found. Four warnings cluster around the service-isolate ↔ UI-isolate boundary: missing `onError` on the geolocator stream, a state-machine gap that allows Start to be re-triggered during the post-`trip_finalized` persist window, a lack of recovery if the notifier's fbs subscriptions error out, and an unguarded Stop-button double-tap window. The info items are refinements (const support for `TrackingActive`, snapshot dedup, polyline decoder hardening, etc.) rather than defects.

## Warnings

### WR-01: Geolocator position stream has no `onError` handler — service isolate can crash silently on mid-trip failure

**File:** `lib/features/tracking/services/tracking_service.dart:90-98`

**Issue:** `Geolocator.getPositionStream(...).listen((position) { ... })` subscribes with only an `onData` callback. If the underlying location stream emits an error mid-trip — which is expected, e.g. when the user toggles Location Services off while a trip is active, when a transient platform error surfaces, or when permissions are revoked — the error propagates to the isolate's zone and is either silently swallowed or tears the isolate down with no path for the UI to observe the failure. `TrackingNotifier` would then be stuck in `TrackingActive` with no further events ever arriving, and the Stop button would be able to send `kStopTrackingEvent` to a dead service.

**Fix:**
```dart
positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
  (position) {
    if (stopping) return;
    accumulator.addSample(position);
  },
  onError: (Object error, StackTrace stack) async {
    // PII-safe: never log `error.toString()` if it can contain lat/lng.
    // Emit a structured failure event so the UI notifier can transition
    // to TrackingError and the user can retry.
    if (stopping) return;
    stopping = true;
    uiTimer?.cancel();
    await positionSub?.cancel();
    service.invoke('tracking_error', <String, Object?>{
      'reason': 'position_stream_error',
    });
    await service.stopSelf();
  },
  cancelOnError: true,
);
```
Add a matching `kTrackingErrorEvent` constant in `tracking_service_events.dart` and wire a third listener in `TrackingNotifier._attach` that sets `state = TrackingError(...)`.

---

### WR-02: Notifier allows Start re-entry during the persist window → second tracking session can spawn over the first

**File:** `lib/features/tracking/providers/tracking_providers.dart:145-154, 166-173`

**Issue:** The `kTripFinalizedEvent` listener is `async`: it sets `state = TrackingStopping()`, awaits `persistFinalizedTrip`, then sets `state = TrackingIdle()`. During the `await` (which includes a Drift transaction — non-trivial on a cold cache) the state is `TrackingStopping`. `TrackingNotifier.start()` guards only against `TrackingActive` and `TrackingStarting`:

```dart
if (state is TrackingActive || state is TrackingStarting) return;
```

A user who taps Start again in that window (or a retry flow that calls `start()` programmatically from the error layout) will bypass the guard, transition to `TrackingStarting`, and call `controller.start()` → `FlutterBackgroundService().startService()`. Although `startService()` is typically idempotent while the service is already running, the state machine itself is now incoherent: the outer `_attach` listener is still inside its `await persistFinalizedTrip`, and when that resolves, it unconditionally writes `state = TrackingIdle()`, clobbering whatever `TrackingStarting`/`TrackingActive` state the new session just produced.

**Fix:** Add `TrackingStopping` to the guard:
```dart
Future<void> start() async {
  if (state is TrackingActive ||
      state is TrackingStarting ||
      state is TrackingStopping) {
    return;
  }
  state = const TrackingStarting();
  final ok = await ref.read(trackingServiceControllerProvider).start();
  if (!ok) {
    state = TrackingError('Unable to start tracking');
  }
}
```
And, for defence in depth, the `kTripFinalizedEvent` handler should only transition back to `TrackingIdle` if the state is still `TrackingStopping`:
```dart
final result = await ref.read(...).persistFinalizedTrip(trip);
_lastPersistResult = result;
if (state is TrackingStopping) {
  state = const TrackingIdle();
}
```

---

### WR-03: Notifier fbs subscriptions have no `onError` — a stream error leaves the UI permanently stuck in `TrackingActive`

**File:** `lib/features/tracking/providers/tracking_providers.dart:136-154`

**Issue:** Both `_stateSub` and `_finalizeSub` call `.listen(...)` with only a data callback:

```dart
_stateSub = service.on(kTrackingStateEvent).listen((data) { ... });
_finalizeSub = service.on(kTripFinalizedEvent).listen((data) async { ... });
```

If the fbs channel emits an error (e.g. the background isolate died abruptly, the platform channel dropped a message), the default behaviour is to forward the error to the surrounding zone. That zone is Riverpod's notifier build zone — the error is not observable by the UI, the notifier stays attached to a dead stream, and the tracking screen remains in `TrackingActive` with stale tiles and no way to recover except killing the app.

Combined with WR-01, this is the full "stuck UI" scenario: the service isolate's position stream fails → the service isolate is dead → the notifier's listeners never see `kTripFinalizedEvent` → the UI is frozen.

**Fix:**
```dart
_stateSub = service.on(kTrackingStateEvent).listen(
  (data) {
    if (data == null) return;
    state = trackingActiveFromSnapshotMap(data.cast<String, Object?>());
  },
  onError: (Object error, StackTrace stack) {
    state = TrackingError('Tracking stream failed');
  },
);
_finalizeSub = service.on(kTripFinalizedEvent).listen(
  (data) async { ... },
  onError: (Object error, StackTrace stack) {
    state = TrackingError('Unable to finalize trip');
  },
);
```

---

### WR-04: Stop button has no debounce — double-tap fires `kStopTrackingEvent` twice and leaves UI in `TrackingActive` until the service responds

**File:** `lib/features/tracking/providers/tracking_providers.dart:182-185` and `lib/features/tracking/screens/tracking_screen.dart:62`

**Issue:** `TrackingNotifier.stop()` guards `if (state is! TrackingActive) return;`, but the notifier never transitions out of `TrackingActive` until `kTripFinalizedEvent` arrives from the service isolate. Between the first Stop tap and the event arriving (which includes the stop-race guard's `await positionSub?.cancel()` + `accumulator.finalize(...)` round trip), every subsequent Stop tap passes the guard and sends another `kStopTrackingEvent`. The service isolate's `.on(kStopTrackingEvent).listen` handler is also async and will run the stop sequence a second time on a finalized accumulator — `finalize()` is a no-op after the first call so the math is safe, but `service.invoke(kTripFinalizedEvent, trip.toMap())` fires twice, and the UI notifier will run `persistFinalizedTrip` on the same trip twice. The second invocation will hit a `UNIQUE constraint` failure on `trips.id` inside the Drift transaction and return `PersistFailed`, stomping the first `PersistSaved` result in `_lastPersistResult`.

**Fix:** Add a locally optimistic transition in the notifier so the guard is effective immediately:
```dart
Future<void> stop() async {
  if (state is! TrackingActive) return;
  state = const TrackingStopping();
  await ref.read(trackingServiceControllerProvider).stop();
}
```
This also simplifies WR-02's re-entry guard because the window where `state is TrackingActive` collapses to a single frame.

## Info

### IN-01: `TrackingActive` has no `operator ==` / `hashCode` and is not `const`-constructible → every 1 Hz snapshot triggers a rebuild even when values are unchanged

**File:** `lib/features/tracking/state/tracking_state.dart:46-79`

**Issue:** The notifier writes a fresh `TrackingActive` instance on every `kTrackingStateEvent`. Riverpod's `NotifierProvider` uses `==` to decide whether to notify listeners; without equality, every snapshot forces a rebuild of the tracking screen and all three tile widgets even if all six fields are byte-identical (e.g., during a stationary wait at a traffic light).

**Fix:** Add `@immutable`-style `operator ==` / `hashCode` on `TrackingActive` mirroring `FinalizedTrip`'s pattern (lines 118-142).

---

### IN-02: `TrackingError` is not `@immutable` and has no equality

**File:** `lib/features/tracking/state/tracking_state.dart:90-105`

**Issue:** All other `TrackingState` variants use `final class` + singleton or immutable fields; `TrackingError` is a `final class` with a `final` field, so it is effectively immutable, but it lacks `@immutable` annotation and `==` / `hashCode`. Two `TrackingError('same message')` instances compare non-equal, causing spurious rebuilds if the error state is re-emitted.

**Fix:** Add `@immutable`, `operator ==` comparing `message`, and `hashCode`.

---

### IN-03: `TripSnapshot` lacks `operator ==` / `hashCode` unlike sibling `FinalizedTrip`

**File:** `lib/features/tracking/services/trip_accumulator.dart:14-71`

**Issue:** `FinalizedTrip` (finalized_trip.dart:118-142) overrides both operators for its DTO role; `TripSnapshot` is the same kind of isolate-boundary DTO but does not. If `TripSnapshot` is ever compared in tests or caching logic, the default identity comparison will mislead. Low impact today — it is only used in one direction through `toMap`/`fromMap` — but the asymmetry will bite a future reader.

**Fix:** Add `operator ==` + `hashCode` on `TripSnapshot` mirroring `FinalizedTrip`'s pattern, or document in the class comment why the two DTOs diverge.

---

### IN-04: `decodePolyline` can throw `RangeError` on a truncated or corrupted input

**File:** `lib/shared/utils/polyline_codec.dart:49-78`

**Issue:** The decoder advances `index` inside a do-while `encoded.codeUnitAt(index++)` loop with no bounds check, so an input string that ends mid-delta (e.g. a lat delta with no matching lng delta, or a continuation byte without its low-bit terminator) throws a `RangeError` instead of a well-named domain error. This is only called from tests and — later — Phase 4 trip detail maps reading from Drift; the Drift values come from `encodePolyline` so the path is trusted today. Still worth hardening before Phase 4 mounts user-visible trip detail screens.

**Fix:** Either bail gracefully with an empty list on a short read, or throw `FormatException('Truncated polyline at byte N')`.

---

### IN-05: `TripAccumulator._samples` grows unbounded → potential memory pressure on multi-hour trips

**File:** `lib/features/tracking/services/trip_accumulator.dart:126, 140, 149, 184`

**Issue:** Every accepted GPS fix is appended to `_samples` in memory and only consumed once at `finalize()`. At the 3-second sampling cadence from `kTrackingSampleInterval`, a 2-hour commute accumulates 2,400 `Position` objects — a few megabytes, well within Android's per-process budget. A marathon 8-hour trip would climb to ~10,000 objects. Not a bug for v0.1 (commutes are the target), but worth calling out as a future-tuning point if the app is ever repurposed for long-distance tracking. A streaming polyline encoder would avoid the allocation entirely.

**Fix:** None required for Phase 2. Consider adding a comment in the class doc noting the linear memory growth and the current 30-minute-commute assumption, or swap to an incremental polyline encoder in a future phase.

---

### IN-06: `TrackingServiceController.start()` swallows all notification-show errors including `Error` subtypes

**File:** `lib/features/tracking/services/tracking_service_controller.dart:84-92`

**Issue:** `try { await _notifications.showRecording(); } on Object { }` intentionally ignores failures per the file comment (Deviation Rule 4 — Android 13+ POST_NOTIFICATIONS may be denied). This is correct, but catching `Object` also swallows `Error` subtypes such as `StateError`, which hide bugs in the notification channel setup during development. A narrower `on PlatformException catch (_)` (or at worst `on Exception catch (_)`) would keep the Android 13 path happy while surfacing programmer errors.

**Fix:**
```dart
try {
  await _notifications.showRecording();
} on PlatformException catch (_) {
  // POST_NOTIFICATIONS denied on Android 13+ → tracking still works.
}
```

---

### IN-07: `main.dart` constructs a throwaway `TrackingNotificationService` to call `initialize()`

**File:** `lib/main.dart:31`

**Issue:** `await TrackingNotificationService().initialize();` creates an instance purely to call an instance method. The comment in `tracking_notification_service.dart` (lines 64-69) explains that the underlying `FlutterLocalNotificationsPlugin` is a singleton so the initialisation sticks, but a reader has to follow that comment to understand why the discarded instance is correct. A static `TrackingNotificationService.initializeOnce()` factory would make the intent explicit and let `main.dart` read as `await TrackingNotificationService.initializeOnce();`.

**Fix:** Optional — promote the initialisation to a static method and call it without constructing an instance.

---

_Reviewed: 2026-04-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
