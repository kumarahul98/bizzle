# Phase 14: Background GPS Platform Branch — Research

**Researched:** 2026-06-02
**For:** IOS-06, IOS-07, IOS-08
**Method:** Ground-truth inspection of installed package source (`~/.pub-cache` geolocator 14.0.2 / geolocator_apple 2.3.13 / geolocator_platform_interface 4.2.6) + existing tracking code. Architecture is already locked in `14-CONTEXT.md` (Option B — bypass fbs on iOS). This research de-risks *implementing* that decision; it does not re-open it.

> **Note for planner:** the first researcher run dropped on a socket error before writing; this file was authored by the orchestrator from authoritative package source. Treat API signatures below as verified against the installed versions, not from memory.

---

## 1. geolocator 14.0.2 API — verified signatures

### `AppleSettings` (geolocator_apple 2.3.13, `lib/src/types/apple_settings.dart`)
Extends `LocationSettings`. Constructor (verified):
```dart
AppleSettings({
  bool pauseLocationUpdatesAutomatically = false,   // default false
  ActivityType activityType = ActivityType.other,    // default other
  LocationAccuracy? accuracy,                         // from LocationSettings
  int? distanceFilter,                                // from LocationSettings (meters)
  Duration? timeLimit,                                // from LocationSettings
  bool showBackgroundLocationIndicator = false,
  bool allowBackgroundLocationUpdates = true,         // default TRUE
});
```
**Every field named in CONTEXT D-02 exists.** Final iOS settings:
```dart
AppleSettings(
  accuracy: LocationAccuracy.high,
  allowBackgroundLocationUpdates: true,
  pauseLocationUpdatesAutomatically: false,   // IOS-07 guarantee
  activityType: ActivityType.automotiveNavigation,
  showBackgroundLocationIndicator: true,
)
```
- **No `intervalDuration`** field (that is Android-only). iOS cadence is driven by `distanceFilter` (meters) + the OS. See §2.

### `ActivityType` enum (`activity_type.dart`)
Values verified: `automotiveNavigation`, `fitness`, `otherNavigation`, `airborne`, `other`. → `ActivityType.automotiveNavigation` is valid.

### Reduced-accuracy API (`geolocator-14.0.2/lib/geolocator.dart`)
```dart
static Future<LocationAccuracyStatus> getLocationAccuracy();
static Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({
  required String purposeKey,
});
```
`enum LocationAccuracyStatus { reduced, precise }` (verified, `geolocator_platform_interface-4.2.6`). `requestTemporaryFullAccuracy` returns the resulting status — check it `== precise` to decide whether to proceed.

### `getPositionStream` accepts the base type
`Geolocator.getPositionStream({LocationSettings? locationSettings})` takes a `LocationSettings`. `AppleSettings` and `AndroidSettings` both extend it, so the platform branch just builds the right subclass and passes it — no separate stream API.

---

## 2. iOS sample cadence (IOS-06/07)

- iOS has no time-interval throttle in `AppleSettings`. Use `distanceFilter` (meters) — set it **low** (e.g. `0` or a small value like `5`) so a car in **stop-and-go traffic** (near-zero speed) still emits samples and `pauseLocationUpdatesAutomatically: false` prevents CoreLocation from suspending updates. A high `distanceFilter` would silently starve samples when the car is barely moving → exactly the IOS-07 failure mode. **Recommendation: `distanceFilter: 0`** (let `pauseLocationUpdatesAutomatically:false` + high accuracy drive cadence) and rely on the existing `TripAccumulator` which is cadence-agnostic.
- `TripAccumulator.addSample(Position)` / `snapshot(now)` / `finalize(now)` make **no assumption** about a fixed 3 s cadence — it timestamps each accepted sample and integrates moving/stuck time from per-sample speed. Variable iOS cadence is therefore safe. (Confirmed: accumulator imports only foundation/geolocator/constants/finalized_trip/polyline_codec/uuid — no fbs, no timer dependency.)
- The UI snapshot cadence (`kTrackingUiUpdateInterval = 1s`) is driven by a `Timer.periodic` in the engine, independent of GPS cadence — reuse the same 1 Hz timer on the iOS main-isolate path.

---

## 3. The iOS main-isolate engine + the seam

### Current Android flow (unchanged)
`TrackingNotifier.build()` (`tracking_providers.dart`) subscribes to FOUR channels off the `FlutterBackgroundService()` singleton, each delivering `Map<String,dynamic>?`:
- `kServiceReadyEvent` → re-post action notification
- `kTrackingStateEvent` → `accumulator.snapshot(now).toMap()` → update `TrackingState`
- `kTripFinalizedEvent` → `trip.toMap()` → `persistFinalizedTrip`
- `kTrackingErrorEvent` → `{reason}` → error state

`TrackingServiceController.start()` → `service.startService()`; `.stop()` → `service.invoke(kStopTrackingEvent)`.

### Minimal seam (implements CONTEXT D-03/D-04)
Introduce a platform-agnostic **event source** the notifier subscribes to instead of touching `FlutterBackgroundService()` directly:

```dart
abstract interface class TrackingEventSource {
  Stream<Map<String, dynamic>?> get onState;       // snapshot maps (1 Hz)
  Stream<Map<String, dynamic>?> get onFinalized;    // FinalizedTrip.toMap()
  Stream<Map<String, dynamic>?> get onError;        // {reason}
  Stream<Map<String, dynamic>?> get onReady;        // android-only; iOS = const Stream.empty()
  Future<bool> start();                             // android: startService; ios: start main-isolate stream
  Future<void> stop();                              // android: invoke(kStop); ios: cancel sub + finalize
}
```
- **`FbsTrackingEventSource` (Android):** thin wrapper — `onState => service.on(kTrackingStateEvent)`, etc.; `start()`/`stop()` as today. Behavior byte-for-byte identical (CONTEXT D-08 regression guard).
- **`MainIsolateTrackingEngine` (iOS):** owns a `TripAccumulator`, a `StreamSubscription<Position>` on `Geolocator.getPositionStream(AppleSettings(...))`, a 1 Hz `Timer.periodic` feeding a `StreamController` for `onState`, and on `stop()` runs the **same stop-race order** as the isolate (`stopping=true` → `await sub.cancel()` → `accumulator.finalize()` → emit on `onFinalized` controller). `onError` mirrors the isolate's `position_stream_error` handling.
- The map shapes are produced by the SAME `accumulator.snapshot(now).toMap()` / `trip.toMap()`, so `TrackingNotifier`'s decoders (`trackingActiveFromSnapshotMap`, `FinalizedTripCodec`) are reused unchanged — only the *source* of the streams changes.
- Selection: `trackingServiceControllerProvider` / the notifier build picks `Platform.isIOS ? MainIsolateTrackingEngine() : FbsTrackingEventSource(FlutterBackgroundService())`.

**Right-sizing (CONTEXT D-03):** this is additive — the Android isolate (`tracking_service.dart`) is untouched; the controller's `persistFinalizedTrip` transaction is reused as-is. The `defaultTargetPlatform` LocationSettings branch (SC#4) lives where the stream is created (Android: inside `tracking_service.dart`; iOS: inside the engine). Keep one shared helper `buildLocationSettings()` returning `AndroidSettings`/`AppleSettings` so SC#4's branch is in exactly one place.

---

## 4. IOS-08 reduced-accuracy gate

Flow (at trip start, iOS only — implements CONTEXT D-05/D-06):
```dart
var status = await Geolocator.getLocationAccuracy();
if (status == LocationAccuracyStatus.reduced) {
  status = await Geolocator.requestTemporaryFullAccuracy(purposeKey: 'PreciseCommute');
}
if (status != LocationAccuracyStatus.precise) {
  // block recording — surface a clear message; do NOT start the stream
  return /* a BLOCKED result the UI maps to a banner/snackbar */;
}
```
- Place it in the iOS `start()` preflight (alongside the existing `Geolocator.isLocationServiceEnabled()` check in `TrackingServiceController.start()`), gated by `Platform.isIOS`.
- **Info.plist:** add to `ios/Runner/Info.plist`:
```xml
<key>NSLocationTemporaryUsageDescriptionDictionary</key>
<dict>
  <key>PreciseCommute</key>
  <string>Traevy needs precise location during your trip to accurately calculate time moving versus time stuck in traffic.</string>
</dict>
```
The `purposeKey` literal `PreciseCommute` MUST match the dict key exactly, and should live in `constants.dart` (e.g. `kPreciseCommitePurposeKey`) per project no-hardcoded-values rule.

---

## 5. Landmines / pitfalls

1. **"Always" vs "When In Use" for background updates (HIGH — affects device validation).** `AppleSettings` docs state `allowBackgroundLocationUpdates` wants `NSLocationAlwaysUsageDescription` and `showBackgroundLocationIndicator: true` "must have granted 'always' permissions". In practice, iOS *does* continue background updates for a session **started in the foreground** under "When In Use" + `UIBackgroundModes: location` + `allowBackgroundLocationUpdates: true` (the blue pill shows). The full **"Always" two-step upgrade is Phase 15 (IOS-09/10)** — out of scope here. **Plan implication:** Phase 14 ships the code; if the human device test shows background gaps under "When In Use", the fix is the Phase 15 "Always" prompt, not a Phase 14 code defect. Flag this explicitly in must_haves so verification doesn't mis-attribute a gap.
2. **Simulator cannot validate background location.** The iOS Simulator does not exercise real CoreLocation background suspension; SC#1/SC#2 are **strictly human-gated on a real iPhone**. Automated coverage must target the platform-branch + accumulator + gate logic, not the actual background behavior. Don't let a green Simulator run masquerade as SC#1 pass.
3. **`Platform.isIOS` vs `defaultTargetPlatform`.** SC#4 literally requires a `defaultTargetPlatform` branch in `tracking_service.dart`. Use `defaultTargetPlatform == TargetPlatform.iOS` for the LocationSettings selection (testable by overriding `debugDefaultTargetPlatformOverride` in unit tests). Use `dart:io Platform.isIOS` only where runtime engine selection happens (not unit-test-overridable). Prefer `defaultTargetPlatform` for both so the branch is unit-testable.
4. **Don't start fbs on iOS at all.** `configureBackgroundService()` currently configures `IosConfiguration(autoStart: false)`. Leave fbs uninitialized/idle on iOS — do not call `startService()` on iOS (it would spin the BGTaskScheduler path the architecture rejects). The iOS engine never touches `FlutterBackgroundService`.
5. **PII guard carries over.** The isolate file warns: never log `Position` lat/lng (threat T-02-07). The iOS main-isolate path runs in the same process as UI — be *more* careful: do not log positions; only the encoded polyline egresses.
6. **Notification.** iOS shows the system blue background-location indicator automatically (`showBackgroundLocationIndicator: true`); no `flutter_local_notifications` foreground notification on iOS (CONTEXT D-07). The Android notification unification (D-14) stays Android-only.

---

## 6. Validation Architecture (Nyquist)

| Behavior | Coverage type | How |
|---|---|---|
| LocationSettings branch returns `AppleSettings` on iOS with the 4 locked params; `AndroidSettings` on Android | **Automated unit** | Override `debugDefaultTargetPlatformOverride`; assert the returned settings type + field values |
| `TripAccumulator` integrates moving/stuck time correctly under variable cadence (incl. near-zero-speed stop-and-go samples) | **Automated unit** | Feed synthetic `Position` sequences (already covered by Phase 2 accumulator tests; add a variable-cadence + slow-traffic case) |
| Reduced-accuracy gate: `reduced` → request → still `reduced` → BLOCK; `precise` → proceed | **Automated unit** | Mock `getLocationAccuracy`/`requestTemporaryFullAccuracy` via a thin wrapper/injectable; assert start() returns blocked vs proceeds |
| iOS engine stop-race ordering (stopping flag before cancel; late sample dropped) | **Automated unit** | Drive the engine with a controllable `StreamController<Position>`; assert no post-stop sample reaches the accumulator |
| Android path unchanged (fbs isolate, notification, stop) | **Automated regression** | Existing Phase 2 tracking tests must still pass |
| Info.plist contains `NSLocationTemporaryUsageDescriptionDictionary`/`PreciseCommute` | **Automated (file assert)** | grep/plist check in a test or CI step |
| **SC#1** full backgrounded/locked-screen commute → no GPS gaps | **HUMAN-GATED (real device)** | User drives a commute with screen locked; inspect resulting track |
| **SC#2** stop-and-go commute → accurate moving/stuck (no silent pause) | **HUMAN-GATED (real device)** | User drives stop-and-go; verify breakdown is plausible |
| **SC#3** reduced-accuracy warning/block on device with "Approximate" set | **HUMAN-GATED (real device)** | User toggles Approximate Location in Settings; confirm block/prompt |

**Free-provisioning reminder:** the device cert expires every 7 days (signing memory) — re-run `flutter run -d <device>` before a test session if the last install was >7 days ago.

---

## 7. Files the planner should target

- `lib/features/tracking/services/tracking_service.dart` — `defaultTargetPlatform` LocationSettings branch (SC#4); keep Android isolate body unchanged; do NOT start fbs on iOS.
- New: `lib/features/tracking/services/main_isolate_tracking_engine.dart` (iOS) + a `TrackingEventSource` seam (interface + Android fbs wrapper).
- `lib/features/tracking/services/tracking_service_controller.dart` — platform-branch start/stop + iOS reduced-accuracy preflight; reuse `persistFinalizedTrip`.
- `lib/features/tracking/providers/tracking_providers.dart` — subscribe the notifier to `TrackingEventSource` instead of `FlutterBackgroundService()` directly; platform-select the source.
- `lib/features/tracking/services/trip_accumulator.dart` — reused unchanged (maybe add a slow-traffic unit test).
- `lib/config/constants.dart` — `kPreciseCommitePurposeKey = 'PreciseCommute'`, any iOS distanceFilter constant.
- `ios/Runner/Info.plist` — `NSLocationTemporaryUsageDescriptionDictionary`.
- Tests under `test/` for the branch, gate, and stop-race.
