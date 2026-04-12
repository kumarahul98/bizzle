---
status: ready
phase: 02-core-tracking
requirements: [TRACK-01, TRACK-02, TRACK-04, TRACK-05, UX-03]
date: 2026-04-12
confidence: HIGH
---

# Phase 2: Core Tracking - Research

**Researched:** 2026-04-12
**Domain:** Flutter background GPS, Android 14 foreground service, Riverpod tracking state, trip persistence
**Confidence:** HIGH (key package versions verified on pub.dev; core API surfaces confirmed; Tracelet verified as real but not adopted)

---

## User Constraints (from 02-CONTEXT.md)

### Locked Decisions
- **D-01** Try Tracelet first; cap verification at 1 task; fall back to geolocator + flutter_background_service if in doubt.
- **D-02** Use each sample's `speed` field directly for moving/stuck classification. Do not compute speed from distance/time deltas.
- **D-03** Streaming accumulators for `timeMovingSeconds` / `timeStuckSeconds` during tracking. On each sample, add `(sample.time - prev.time)` to moving if `prev.speed >= kStuckSpeedThresholdKmh`, else stuck.
- **D-04** Distance accumulated sample-to-sample via Haversine into a single `distanceMeters` counter during tracking.
- **D-05** GPS sampling config is Claude's discretion (must be battery-reasonable for a 30-minute commute).
- **D-06** In-memory only. No `live_trip_samples` table. Process kill = lost trip; user restarts manually.
- **D-07** Two-step permission dance: fine location first, background location on first Start tap.
- **D-08** Background denied → tracking works only while foregrounded. Show banner. Don't block Start.
- **D-09** Fine location denied → Start disabled, CTA to settings.
- **D-10** Save only if duration ≥ 30s AND distance ≥ 100m. Below threshold: snackbar "Trip too short to save". Constants: `kMinTripDurationSeconds = 30`, `kMinTripDistanceMeters = 100`.
- **D-11** Direction column gets neutral Phase-2 default; Phase 3 backfills.
- **D-12** Tracking screen = big Stop button + duration/distance/current-speed tiles. No map.
- **D-13** Dashboard is Phase 6. Phase 2 ships minimal home with "Start commute" CTA.
- **D-14** Notification: static text "Recording commute" + Stop action button. Tap body → tracking screen. Tap Stop → finalize trip. No per-sample updates.
- **D-15** `flutter_local_notifications` for the notification. Channel: "Active commute", importance LOW.

### Claude's Discretion
- Tracelet verification details (done in this research)
- GPS sampling frequency and distance filter values
- Polyline encoding approach
- Haversine implementation
- Riverpod provider graph for tracking state
- File/folder layout within `lib/features/tracking/`
- Exact snackbar/banner copy
- Whether `timeMoving + timeStuck` must exactly equal `duration`

### Deferred Ideas (OUT OF SCOPE)
- Dashboard / home screen (Phase 6)
- Trip detail screen with route map (Phase 4)
- Direction auto-labeling (Phase 3)
- Trip edit / delete / manual entry (Phase 3)
- Stats dashboard (Phase 5)
- Incremental sample persistence for crash recovery (backlog)
- Weekly summary / reminder notifications (Phase 7)

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRACK-01 | User can start and stop commute recording with a single tap | Tracking screen (§11), Riverpod tracking notifier (§8), permission pre-flight (§5) |
| TRACK-02 | GPS captures location in background via foreground service | `flutter_background_service` + `FOREGROUND_SERVICE_LOCATION` (§3, §4) |
| TRACK-04 | Trip records start/end, duration, distance, polyline | Position stream + Haversine + polyline encoding (§3, §6, §7) |
| TRACK-05 | Per-trip time moving vs time stuck (<10 km/h) | Streaming accumulators with `Position.speed` in m/s (§3, §6) |
| UX-03 | Persistent notification while tracking is active | `flutter_local_notifications` with Stop action (§4) |

---

## 1. Summary

- **Tracelet verdict: fall back.** Tracelet IS a real pub.dev package (v1.8.10, verified publisher `ikolvi.com`, Apache-2.0, published 5 days ago on 2026-04-07), but it is brand new (25 likes, 2.49k weekly downloads, 160 pub points), its class definitions (`Location`, `Coords`) are not publicly documented, its `ForegroundServiceConfig` has no Stop-action-button support per available docs, and it bundles its own SQLite persistence and HTTP sync — features we already own via Drift and our API layer. D-14 (Stop action button) is the hard blocker. **Use `geolocator ^14.0` + `flutter_background_service ^5.1` + `flutter_local_notifications ^21.0` instead.** [VERIFIED: pub.dev 2026-04-12]
- **Stack is three packages**, all verified current on pub.dev: `geolocator 14.0.2`, `flutter_background_service 5.1.0`, `flutter_local_notifications 21.0.0`, plus `permission_handler 12.0.1` for the two-step permission flow, and either `google_polyline_algorithm 3.1.0` or a hand-rolled 30-line encoder.
- **Android 14 requires `FOREGROUND_SERVICE_LOCATION` permission + `android:foregroundServiceType="location"` on the service element** in AndroidManifest.xml. Phase 1 did NOT actually add any location permissions despite the Phase 2 CONTEXT claiming so — Phase 2 must add ALL of them from scratch. [VERIFIED: read `android/app/src/main/AndroidManifest.xml` — no permissions present].
- **Two-isolate architecture.** `flutter_background_service` runs its `onStart` handler in a background isolate. Pattern: background isolate owns the `Geolocator.getPositionStream` subscription AND the streaming accumulators. It pushes periodic state snapshots to the UI via `service.invoke('tracking_state', ...)` and receives `stop` commands via `service.on('stop_tracking')`. On stop, the background isolate sends the final trip summary to the UI isolate, which writes to Drift and dismisses the notification.
- **Polyline encoding is NOT provided by `flutter_polyline_points`** (decode-only). Options: (a) `google_polyline_algorithm 3.1.0` — 5 years stale but the algorithm is frozen; (b) hand-roll a 30-line encoder in `lib/shared/utils/polyline_codec.dart`. **Recommendation: hand-roll.** The Google Polyline Algorithm is a simple, public, stable spec; adding a 5-year-old single-purpose dependency for ~30 lines is worse than owning the code.

**Primary recommendation:** Ship Phase 2 on `geolocator 14.0.2` + `flutter_background_service 5.1.0` + `flutter_local_notifications 21.0.0` + `permission_handler 12.0.1`. Accumulate samples in the service isolate. Use `Position.speed` (m/s, convert to km/h for threshold comparison) for moving/stuck classification. Hand-roll the polyline encoder. Write the trip to Drift via `TripsDao.insertTrip(...)` + `SyncQueueDao.enqueueCreate(tripId)` from the UI isolate on stop.

---

## 2. Tracelet Verification

### Verdict: FALL BACK (do not adopt)

| Check | Result | Evidence |
|-------|--------|----------|
| Package exists on pub.dev | ✓ YES | [VERIFIED: pub.dev/packages/tracelet] |
| Verified publisher | ✓ YES | `ikolvi.com` [VERIFIED] |
| License | Apache-2.0 | [VERIFIED] |
| Latest version | 1.8.10 | [VERIFIED — published 2026-04-07, 5 days before this research] |
| Community adoption | **LOW** | 25 likes, 2.49k weekly downloads, 160 pub points [VERIFIED] |
| Feature set (claimed) | GPS, Kalman filter, geofencing, SQLite persistence, HTTP sync, headless exec, battery-conscious | [CITED: pub.dev listing] |
| Android 14 foreground service | Claimed yes, undocumented config surface | [CITED: README mentions `ForegroundServiceConfig`; no Stop-action API visible in docs] |
| `Position.speed` field | Unconfirmed | Docs describe `coords.latitude`, `coords.longitude`, `coords.accuracy` — speed field NOT explicitly listed in public API docs or README [VERIFIED: WebFetch of GitHub README and API.md] |
| Stop-action button on notification | **NO** (not documented) | Only `notificationTitle` and `notificationText` mentioned in public `ForegroundServiceConfig` usage [VERIFIED] |
| Tracelet brings own SQLite + HTTP sync | Yes | Conflicts with our Drift + custom sync engine [CITED: pub.dev description] |

### Why fall back
1. **D-14 blocker**: Phase 2 requires a Stop action button on the notification. Tracelet's documented `ForegroundServiceConfig` exposes only title/text. Adding a custom notification layer on top of Tracelet's built-in foreground service means having two notifications, which is worse than using a generic foreground service package.
2. **Undocumented API**: Cannot verify `Position.speed` exists in Tracelet's `Coords`. Our core traffic-stuck calculation depends on this field. Investigating it further violates D-01's "cap at 1 task" budget.
3. **Feature overlap**: Tracelet bundles SQLite + HTTP sync. We already have Drift (Phase 1) and will have our own sync engine (Phase 10). We'd be paying binary/dependency cost for dead features.
4. **Newness**: 5 days since last publish, 25 likes. Our core GPS path depends on this package — too much risk for too little benefit.
5. **Budget**: D-01 explicitly says "Do not spend more than 1 investigation task on Tracelet — ship with the fallback if in doubt." We are in doubt.

### What would change this verdict
A future phase can reconsider Tracelet if: (a) it ships a documented action-button API, (b) its `Location.coords.speed` field is officially documented, and (c) it gains significant community adoption (500+ likes). None of these are true today.

---

## 3. GPS Stack (Fallback = Chosen Path)

### Packages

| Package | Version | Purpose | Source |
|---------|---------|---------|--------|
| `geolocator` | `^14.0.2` | Position stream with speed, permission checks | [VERIFIED: pub.dev — latest 14.0.2, published ~9 months ago] |
| `flutter_background_service` | `^5.1.0` | Android 14-compliant foreground service, isolate lifecycle | [VERIFIED: pub.dev — latest 5.1.0] |
| `flutter_local_notifications` | `^21.0.0` | Notification with Stop action button | [VERIFIED: pub.dev — latest 21.0.0, published ~38 days ago, NOT 18.0 as listed in STACK.md] |
| `permission_handler` | `^12.0.1` | Two-step location permission flow (fine then background) | [VERIFIED: pub.dev — latest 12.0.1] |

> **Version drift note:** The whole-project `STACK.md` listed `flutter_local_notifications ^18.0` and `geolocator ^13.0`. Both are stale. Phase 2 uses the verified current versions above.

### `Position` class (geolocator_platform_interface)

[VERIFIED: pub.dev/documentation/geolocator_platform_interface]

```dart
class Position {
  final double latitude;        // degrees
  final double longitude;       // degrees
  final double accuracy;        // meters
  final double altitude;        // meters
  final double altitudeAccuracy;
  final double heading;         // degrees
  final double headingAccuracy;
  final double speed;           // m/s over ground  <-- CRITICAL FOR D-02
  final double speedAccuracy;   // m/s
  final DateTime timestamp;
}
```

**Critical for D-02:** `Position.speed` is in **meters per second**, NOT km/h. When comparing to `kStuckSpeedThresholdKmh = 10`, convert:

```dart
const double _msToKmh = 3.6;
final speedKmh = position.speed * _msToKmh;
final isMoving = speedKmh >= kStuckSpeedThresholdKmh;
```

Or pre-compute the threshold in m/s once in `constants.dart`:

```dart
/// Stuck-threshold in m/s (matches `kStuckSpeedThresholdKmh` converted
/// to the unit Geolocator's `Position.speed` reports in).
const double kStuckSpeedThresholdMs = kStuckSpeedThresholdKmh / 3.6;
// == 2.777... m/s
```

Phase 2 should add `kStuckSpeedThresholdMs` as a derived constant so the sample classification code can compare directly without per-sample unit conversion.

### Why NOT use `geolocator`'s built-in foreground service

`geolocator_android` exposes `AndroidSettings.foregroundNotificationConfig` which automatically runs the position stream as a foreground service with a persistent notification. This is simpler than `flutter_background_service`. **But it has no action-button API.** [VERIFIED: read `ForegroundNotificationConfig` source — fields are `notificationTitle`, `notificationText`, `notificationChannelName`, `notificationIcon`, `enableWifiLock`, `enableWakeLock`, `setOngoing`, `color` — nothing else.]

D-14 requires a Stop action button. Therefore:
- **Do NOT pass `foregroundNotificationConfig` to `AndroidSettings`**.
- Use `flutter_background_service` to own the foreground service.
- Use `flutter_local_notifications` to own the notification (with Stop action).
- `Geolocator.getPositionStream(locationSettings: ...)` runs inside the service isolate.

### LocationSettings / AndroidSettings — Phase 2 config

```dart
// In lib/features/tracking/services/tracking_service.dart
import 'package:geolocator_android/geolocator_android.dart';

final LocationSettings kTrackingLocationSettings = AndroidSettings(
  accuracy: LocationAccuracy.high,      // GPS, not coarse network
  distanceFilter: 0,                     // emit every fix — time-based throttling instead
  intervalDuration: const Duration(seconds: 3),  // target fix every 3s
  // NO foregroundNotificationConfig — flutter_background_service owns the foreground service.
  // forceLocationManager defaults to false = use FusedLocationProvider on Android.
);
```

**Why these values:**
- `LocationAccuracy.high` = GPS-grade fix; `best` is marginally more accurate but burns battery harder. High is the documented "use for navigation/tracking" level.
- `distanceFilter: 0` — do NOT filter by distance. Stuck-in-traffic detection needs samples even when the car is stationary so we can attribute time to the "stuck" accumulator. A distance filter would silently suppress stuck-traffic time.
- `intervalDuration: 3s` — balances battery vs fidelity for a 30-minute commute. At 3s interval, 30 min = 600 samples. Each sample is ~64 bytes of in-memory struct (lat, lng, speed, timestamp, etc.) ≈ 40 KB for the whole trip. Well within D-06's "in-memory" budget.
- `forceLocationManager: false` (the default) — FusedLocationProvider is Google Play Services' smart provider. More battery-efficient, better stuck/moving detection (uses sensors to infer motion).

**Sampling math:**
- 3s interval → 20 samples/min → 600 samples / 30-min commute
- Memory (service isolate): 600 × ~80 bytes = ~48 KB (negligible)
- Worst case (60-min commute): 1200 samples × 80 bytes ≈ 96 KB (also negligible)
- Battery: LocationAccuracy.high at 3s interval on FusedLocationProvider draws ~60–120 mAh over a 30-minute trip on modern devices — acceptable.

---

## 4. Android 14 Foreground Service

### AndroidManifest.xml changes

**Phase 1 did not add location permissions.** [VERIFIED: grep of `/android/app/src/main/AndroidManifest.xml` returned no matches for `ACCESS_FINE_LOCATION`, `FOREGROUND_SERVICE`, `ACCESS_BACKGROUND_LOCATION`.] The Phase 2 CONTEXT claim that permissions already exist is incorrect. Phase 2 adds all of them.

Add the following inside `<manifest>` (sibling of `<application>`, not inside it):

```xml
<!-- Internet is required by Phase 10 sync engine; added now for forward-compat -->
<uses-permission android:name="android.permission.INTERNET"/>

<!-- Fine-grained GPS (required for tracking) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

<!-- Background location for Android 10+ (requested as a second step, per D-07) -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>

<!-- Generic foreground service permission (Android 9+) -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>

<!-- Android 14 (SDK 34) REQUIRES a typed sub-permission matching the service type.
     For a location foreground service the type is "location". Without this, the
     service fails to start with a SecurityException on Android 14. -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>

<!-- Needed to keep CPU awake during active tracking (D-06: best-effort, no
     incremental persistence — wake lock keeps the service isolate alive) -->
<uses-permission android:name="android.permission.WAKE_LOCK"/>

<!-- Post-notification on Android 13+ for the foreground notification -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

[VERIFIED: developer.android.com/develop/background-work/services/fgs/service-types — "`FOREGROUND_SERVICE_LOCATION`" permission required on Android 14 for a service with `foregroundServiceType="location"`.]

### Service element

`flutter_background_service` declares its own service in its manifest. For Android 14 you MUST override its service type to `location` so Android allows it to access location while backgrounded. Add to the `<application>` block:

```xml
<service
    android:name="id.flutter.flutter_background_service.BackgroundService"
    android:foregroundServiceType="location"
    android:exported="false"
    tools:replace="android:foregroundServiceType"/>
```

Also add `xmlns:tools="http://schemas.android.com/tools"` to the `<manifest>` root element (required for `tools:replace`).

> **Pitfall:** If `android:foregroundServiceType="location"` is missing on Android 14, calling `startForeground()` throws `ForegroundServiceTypeException` and kills the app. The `tools:replace` is required because `flutter_background_service` declares this service in its own manifest with a default type that doesn't include location.

### Notification channel

Create a single channel at app startup (not per-trip):

```dart
// lib/features/tracking/services/tracking_notification_service.dart
static const String kTrackingChannelId = 'traevy_active_commute';
static const String kTrackingChannelName = 'Active commute';
static const String kTrackingChannelDescription =
    'Shown while Traevy is recording a commute.';
static const int kTrackingNotificationId = 1001;

Future<void> ensureChannel() async {
  const channel = AndroidNotificationChannel(
    kTrackingChannelId,
    kTrackingChannelName,
    description: kTrackingChannelDescription,
    importance: Importance.low,         // D-15: LOW so no heads-up alert
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );
  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}
```

### Stop action button wiring

`flutter_local_notifications ^21` supports action buttons via `AndroidNotificationAction`. [VERIFIED: pub.dev listing "On Android and Linux, the actions are configured directly on the notification."] Callbacks fire through `onDidReceiveNotificationResponse` (app-foreground) and `onDidReceiveBackgroundNotificationResponse` (app-backgrounded or terminated).

```dart
Future<void> showTrackingNotification() async {
  const androidDetails = AndroidNotificationDetails(
    kTrackingChannelId,
    kTrackingChannelName,
    channelDescription: kTrackingChannelDescription,
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,                      // non-dismissible by swipe
    autoCancel: false,
    category: AndroidNotificationCategory.service,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction(
        'stop_tracking',                // action id — matched in response handler
        'Stop',
        showsUserInterface: false,       // no UI bump, just finalize
        cancelNotification: false,       // we dismiss explicitly on trip save
      ),
    ],
  );
  await FlutterLocalNotificationsPlugin().show(
    kTrackingNotificationId,
    'Recording commute',
    null,                                // D-14: static text, no body updates
    const NotificationDetails(android: androidDetails),
    payload: 'tracking_active',
  );
}
```

```dart
// Register in main.dart during app init, BEFORE any tracking can start.
await FlutterLocalNotificationsPlugin().initialize(
  const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ),
  onDidReceiveNotificationResponse: _onNotificationResponse,
  onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
);

void _onNotificationResponse(NotificationResponse r) {
  if (r.actionId == 'stop_tracking') {
    FlutterBackgroundService().invoke('stop_tracking');
  } else if (r.notificationResponseType ==
      NotificationResponseType.selectedNotification) {
    // Tap body → navigate to /tracking (handled by a router/state).
  }
}

@pragma('vm:entry-point')   // Required for background isolate callbacks.
void _onBackgroundNotificationResponse(NotificationResponse r) {
  if (r.actionId == 'stop_tracking') {
    FlutterBackgroundService().invoke('stop_tracking');
  }
}
```

> **Critical:** `@pragma('vm:entry-point')` is required on the background callback to prevent tree-shaking. Missing this annotation causes silent no-ops in release builds. [CITED: pub.dev flutter_local_notifications listing.]

### Notification lifecycle (Pitfall 5 mitigation)

- **Show:** in service `onStart` after `startForeground()`.
- **Dismiss:** in the UI isolate after trip save completes (or discard on short-trip). `FlutterLocalNotificationsPlugin().cancel(kTrackingNotificationId)` + `FlutterBackgroundService().invoke('stop_service')`.
- **Stale notification after kill:** `flutter_background_service.stopSelf()` on `onStart`'s cleanup path auto-clears the foreground notification on Android. Test path: kill the app via Android settings while tracking, reopen — notification must be gone.

---

## 5. Permission Flow

### Package choice: `permission_handler ^12.0.1`

Why `permission_handler` over geolocator's built-in permission methods:
- `Geolocator.checkPermission()` / `Geolocator.requestPermission()` work but only surface a single `LocationPermission` enum conflating fine/background. They can't distinguish "fine granted but background denied" from "fine granted only while in use."
- `permission_handler` exposes `Permission.locationWhenInUse` and `Permission.locationAlways` as separate permissions, each with `isGranted`, `isDenied`, `isPermanentlyDenied`, and `request()` — exactly what D-07/D-08/D-09 need.
- `permission_handler` provides `openAppSettings()` for the "permanently denied" deep link (D-09).

[VERIFIED: pub.dev/packages/permission_handler — "When requesting the 'location always' permission directly, or when requesting both permissions at the same time, the system will ignore the request."]

### Two-step dance

```dart
// lib/features/tracking/services/tracking_permission_service.dart

enum TrackingPermissionStatus {
  fullyGranted,              // fine + background — full feature set
  foregroundOnly,            // fine granted, background denied — D-08 banner
  denied,                    // fine denied, can still request — show rationale
  permanentlyDenied,         // fine denied "don't ask again" — D-09 settings CTA
}

Future<TrackingPermissionStatus> preflight() async {
  final fine = await Permission.locationWhenInUse.status;
  if (fine.isPermanentlyDenied) return TrackingPermissionStatus.permanentlyDenied;
  if (!fine.isGranted) {
    final req = await Permission.locationWhenInUse.request();
    if (req.isPermanentlyDenied) return TrackingPermissionStatus.permanentlyDenied;
    if (!req.isGranted) return TrackingPermissionStatus.denied;
  }
  // Fine granted — now check/request background.
  final bg = await Permission.locationAlways.status;
  if (bg.isGranted) return TrackingPermissionStatus.fullyGranted;
  // Android 11+ will open system settings for this request; on 10 it shows a dialog.
  final bgReq = await Permission.locationAlways.request();
  return bgReq.isGranted
      ? TrackingPermissionStatus.fullyGranted
      : TrackingPermissionStatus.foregroundOnly;
}

Future<void> openSettings() => openAppSettings();
```

### Pre-flight on the tracking screen

Call `preflight()` in `initState` of the tracking screen (or as the first build of a FutureProvider). Based on the result:

| Status | UI behavior |
|--------|-------------|
| `fullyGranted` | Start button enabled. No banner. |
| `foregroundOnly` | Start button enabled. Dismissible banner: "Tracking will stop when the app is backgrounded. [Enable always-on]" — tap opens app settings. (D-08) |
| `denied` | Start button **disabled**. Full-width card: "Traevy needs location to record your commute. [Grant location]" — tap calls `preflight()` again. |
| `permanentlyDenied` | Start button disabled. Full-width card: "Location permission is permanently denied. [Open settings]" — tap calls `openAppSettings()`. (D-09) |

### Android 11+ behavior note

On Android 11+, `Permission.locationAlways.request()` cannot show a runtime dialog. It opens the system Location Settings screen where the user manually picks "Allow all the time." After the user returns to the app, re-check `Permission.locationAlways.status`. This is an OS-enforced flow — we cannot bypass it.

On Android 14 specifically, the user must also have the "All the time" toggle enabled in system settings, AND the app must have `ACCESS_BACKGROUND_LOCATION` in the manifest.

### Starting the service guard

Even with permissions granted, `flutter_background_service.startService()` can fail if location services are disabled at the device level. Check `await Geolocator.isLocationServiceEnabled()` before calling `startService()`. If disabled, show a dialog prompting the user to enable Location in system settings, and call `Geolocator.openLocationSettings()`.

---

## 6. Streaming Metrics

### Haversine source

**Use `Geolocator.distanceBetween(lat1, lng1, lat2, lng2)`** — it's a static method on `Geolocator` that returns meters as a `double`, built into the package we're already adding. [VERIFIED: geolocator pub.dev API.]

```dart
final meters = Geolocator.distanceBetween(
  prev.latitude,
  prev.longitude,
  curr.latitude,
  curr.longitude,
);
```

Do NOT hand-roll Haversine. The geolocator implementation is well-tested, handles the edge-of-equator and pole cases, and adds zero dependency weight (already imported).

### Streaming accumulator (D-03, D-04)

Accumulator state lives in the service isolate as a plain Dart object:

```dart
// lib/features/tracking/services/trip_accumulator.dart

class TripAccumulator {
  TripAccumulator({required this.startedAt});

  final DateTime startedAt;
  Position? _lastAccepted;
  double _distanceMeters = 0;
  int _movingSeconds = 0;
  int _stuckSeconds = 0;
  final List<Position> _samples = [];   // retained for polyline encoding at stop

  void addSample(Position p) {
    // Accuracy gate: drop samples worse than 30m (pitfall 2)
    if (p.accuracy > 30) return;

    final prev = _lastAccepted;
    if (prev == null) {
      _lastAccepted = p;
      _samples.add(p);
      return;
    }

    final deltaSec =
        p.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
    if (deltaSec <= 0 || deltaSec > 30) {
      // Clock skew or long gap — still record the position but don't
      // attribute time to either bucket (would corrupt moving/stuck math).
      _lastAccepted = p;
      _samples.add(p);
      return;
    }

    // D-04: distance delta
    _distanceMeters += Geolocator.distanceBetween(
      prev.latitude, prev.longitude,
      p.latitude, p.longitude,
    );

    // D-03: classify the prev→curr INTERVAL by the prev sample's speed.
    // Use m/s comparison against kStuckSpeedThresholdMs to avoid per-sample
    // unit conversion.
    final deltaSecInt = deltaSec.round();
    if (prev.speed >= kStuckSpeedThresholdMs) {
      _movingSeconds += deltaSecInt;
    } else {
      _stuckSeconds += deltaSecInt;
    }

    _lastAccepted = p;
    _samples.add(p);
  }

  TripSnapshot snapshot(DateTime now) => TripSnapshot(
        startedAt: startedAt,
        elapsedSeconds: now.difference(startedAt).inSeconds,
        distanceMeters: _distanceMeters,
        timeMovingSeconds: _movingSeconds,
        timeStuckSeconds: _stuckSeconds,
        currentSpeedMs: _lastAccepted?.speed ?? 0,
      );

  /// Build the final immutable trip on Stop. `endedAt` is wall-clock stop
  /// time from the service isolate.
  FinalizedTrip finalize(DateTime endedAt) => FinalizedTrip(
        id: const Uuid().v4(),
        startTime: startedAt.toUtc(),
        endTime: endedAt.toUtc(),
        durationSeconds: endedAt.difference(startedAt).inSeconds,
        distanceMeters: _distanceMeters,
        timeMovingSeconds: _movingSeconds,
        timeStuckSeconds: _stuckSeconds,
        samples: List.unmodifiable(_samples),
      );
}
```

### Accuracy filtering and noise handling

**Keep it simple for Phase 2**, following the research's Pitfall 2 guidance:

1. **Accuracy gate**: drop samples with `position.accuracy > 30` meters. Urban canyons produce high-accuracy-value samples; these would poison both distance and speed accumulators.
2. **Clamp huge time gaps**: if `deltaSec > 30` (e.g., user was in a tunnel, GPS dropped, then re-acquired), record the position but skip the moving/stuck attribution for that interval. Better a small undercount than a massive misattribution.
3. **Use `prev.speed` for the interval classification**, not `curr.speed`. This is the spec from D-03.

**What we do NOT do in Phase 2** (deferred to Phase 3 polish if noise is bad in field testing):
- Rolling-median filter for speed (adds state, complexity)
- Doppler vs position-derived speed comparison (geolocator already uses Doppler from the OS)
- Speed floor (treating <3 km/h as zero) — the `prev.speed >= kStuckSpeedThresholdMs` comparison already handles this since zero is definitely < 10 km/h

### `timeMoving + timeStuck` vs `duration`

They will drift below `duration` because:
- Dropped high-accuracy samples produce no attribution.
- Gaps > 30s are intentionally excluded.
- Integer-second rounding loses sub-second precision.

**Recommendation (answering the D-discretion question):** accept sub-second drift. Do NOT enforce `moving + stuck == duration`. The dashboard will compute `(moving + stuck) / duration` when it needs a percentage; any slight drift is invisible to the user. Adding reconciliation logic to force exact equality is dead code without a clear UX benefit.

Document this in a doc comment on `TripAccumulator` so Phase 3/5 don't re-open the question.

---

## 7. Polyline Encoding

### Verdict: hand-roll in `lib/shared/utils/polyline_codec.dart`

**Why not `flutter_polyline_points`**: Decode-only. [VERIFIED: package description "get polyline points by either passing the coordinates or google encoded polyline string" — decoding only, no encode method.]

**Why not `google_polyline_algorithm 3.1.0`**: 5 years stale. [VERIFIED: pub.dev — "published 5 years ago"]. The algorithm itself is frozen (it's a Google public spec from 2010), so the package works, but introducing a dependency that hasn't been updated in 5 years is a maintenance red flag and `very_good_analysis` may flag it.

**Why not `polyline_tools 0.0.2`**: Sub-1.0 version, published 18 months ago, API undocumented.

**Why hand-rolled wins**:
- The algorithm is ~30 lines of Dart.
- It's a pure function with no platform dependencies — perfectly unit-testable.
- Phase 1's `very_good_analysis` lint will happily accept it.
- Decoding lives in Phase 4 (map display) — we can add the decoder then, or add both now and unit-test round-trip encoding/decoding.

### Reference implementation

The Google Polyline Algorithm Format is a lossy compression of signed coordinates using base64-like encoding with 5-decimal-place precision. [CITED: https://developers.google.com/maps/documentation/utilities/polylinealgorithm]

```dart
// lib/shared/utils/polyline_codec.dart
//
// Google Polyline Encoding Algorithm.
// Spec: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
//
// Encodes a list of (lat, lng) pairs into a compact ASCII string. Only
// encoding is needed in Phase 2 — the decode path will be added in
// Phase 4 when the trip-detail map screen lands.

String encodePolyline(List<({double lat, double lng})> points) {
  final sb = StringBuffer();
  int prevLat = 0;
  int prevLng = 0;

  for (final p in points) {
    final lat = (p.lat * 1e5).round();
    final lng = (p.lng * 1e5).round();
    _encodeSigned(lat - prevLat, sb);
    _encodeSigned(lng - prevLng, sb);
    prevLat = lat;
    prevLng = lng;
  }
  return sb.toString();
}

void _encodeSigned(int value, StringBuffer sb) {
  int v = value < 0 ? ~(value << 1) : value << 1;
  while (v >= 0x20) {
    sb.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  sb.writeCharCode(v + 63);
}
```

### Sample reduction (Pitfall 7 mitigation)

A 3-second-interval 30-minute commute produces 600 samples. Encoded with full precision, that's ~3.5 KB per trip. A 60-minute commute ≈ 7 KB. Per Pitfall 7, at 500 trips/year we'd be at 1.75–3.5 MB of polyline data — acceptable, but NOT great.

**Phase 2 scope: encode every accepted sample.** Do not implement Ramer-Douglas-Peucker downsampling. This is a Phase 4 (or Phase 11 polish) optimization. The schema already isolates polylines to the detail view via `TripSummary` projection (Phase 1 D-01), so list performance is not affected.

---

## 8. Riverpod State Model

### Provider graph

All providers are **manual** (no `@riverpod` annotation) per Phase 1 D-12 (analyzer-9/10 conflict).

```dart
// lib/features/tracking/providers/tracking_providers.dart

// Permission status (FutureProvider - re-runs when invalidated)
final Provider<TrackingPermissionService> trackingPermissionServiceProvider =
    Provider<TrackingPermissionService>(
  (ref) => TrackingPermissionService(),
  name: 'trackingPermissionServiceProvider',
);

final FutureProvider<TrackingPermissionStatus>
    trackingPermissionStatusProvider =
    FutureProvider<TrackingPermissionStatus>(
  (ref) => ref.read(trackingPermissionServiceProvider).preflight(),
  name: 'trackingPermissionStatusProvider',
);

// The service wrapper around FlutterBackgroundService (thin singleton)
final Provider<TrackingServiceController> trackingServiceControllerProvider =
    Provider<TrackingServiceController>(
  (ref) {
    final tripsDao = ref.watch(tripsDaoProvider);
    final syncQueueDao = ref.watch(syncQueueDaoProvider);
    final notifications = ref.watch(trackingNotificationServiceProvider);
    return TrackingServiceController(
      tripsDao: tripsDao,
      syncQueueDao: syncQueueDao,
      notifications: notifications,
    );
  },
  name: 'trackingServiceControllerProvider',
);

// The LIVE tracking state — a NotifierProvider holding a sealed state.
// Receives service invoke events via an internal StreamSubscription and
// exposes a ticking state to the UI.
final NotifierProvider<TrackingNotifier, TrackingState> trackingStateProvider =
    NotifierProvider<TrackingNotifier, TrackingState>(
  TrackingNotifier.new,
  name: 'trackingStateProvider',
);
```

### Sealed tracking state

```dart
// lib/features/tracking/state/tracking_state.dart

sealed class TrackingState {
  const TrackingState();
}

final class TrackingIdle extends TrackingState {
  const TrackingIdle();
}

final class TrackingStarting extends TrackingState {
  const TrackingStarting();
}

final class TrackingActive extends TrackingState {
  const TrackingActive({
    required this.startedAt,
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.currentSpeedKmh,
    required this.timeMovingSeconds,
    required this.timeStuckSeconds,
  });

  final DateTime startedAt;
  final int elapsedSeconds;
  final double distanceMeters;
  final double currentSpeedKmh;
  final int timeMovingSeconds;
  final int timeStuckSeconds;
}

final class TrackingStopping extends TrackingState {
  const TrackingStopping();
}

final class TrackingError extends TrackingState {
  const TrackingError(this.message);
  final String message;
}
```

### Notifier

```dart
// lib/features/tracking/providers/tracking_notifier.dart

class TrackingNotifier extends Notifier<TrackingState> {
  StreamSubscription<Map<String, dynamic>?>? _sub;

  @override
  TrackingState build() {
    ref.onDispose(() => _sub?.cancel());
    _attachToService();
    return const TrackingIdle();
  }

  void _attachToService() {
    final service = FlutterBackgroundService();
    _sub = service.on('tracking_state').listen((data) {
      if (data == null) return;
      if (data['status'] == 'active') {
        state = TrackingActive(
          startedAt: DateTime.parse(data['startedAt'] as String),
          elapsedSeconds: data['elapsedSeconds'] as int,
          distanceMeters: (data['distanceMeters'] as num).toDouble(),
          currentSpeedKmh: (data['currentSpeedKmh'] as num).toDouble(),
          timeMovingSeconds: data['timeMovingSeconds'] as int,
          timeStuckSeconds: data['timeStuckSeconds'] as int,
        );
      } else if (data['status'] == 'idle') {
        state = const TrackingIdle();
      }
    });
    // Also listen for the "trip_finalized" event to persist to Drift.
    service.on('trip_finalized').listen((data) async {
      if (data == null) return;
      state = const TrackingStopping();
      await ref
          .read(trackingServiceControllerProvider)
          .persistFinalizedTrip(data);
      state = const TrackingIdle();
    });
  }

  Future<void> start() async {
    state = const TrackingStarting();
    final ok = await ref.read(trackingServiceControllerProvider).start();
    if (!ok) {
      state = const TrackingError('Failed to start tracking');
    }
    // Actual TrackingActive transition happens when the service emits
    // its first 'tracking_state' event.
  }

  Future<void> stop() async {
    await ref.read(trackingServiceControllerProvider).stop();
    // State transitions to TrackingStopping -> TrackingIdle via the
    // 'trip_finalized' handler above.
  }
}
```

### Isolate boundary

| Isolate | Responsibility |
|---------|----------------|
| **Service isolate** (flutter_background_service `onStart`) | Owns `TripAccumulator`. Subscribes to `Geolocator.getPositionStream`. Emits snapshot via `service.invoke('tracking_state', snapshot.toMap())` every 1s on a `Timer.periodic`. Listens for `service.on('stop_tracking')`. On stop: builds `FinalizedTrip`, emits `service.invoke('trip_finalized', finalTrip.toMap())`, cancels stream, calls `service.stopSelf()`. |
| **UI isolate** (Flutter app) | Runs `TrackingNotifier`. Subscribes to `service.on('tracking_state')` and `service.on('trip_finalized')`. On finalize: runs the D-10 threshold check, persists via `TripsDao` + `SyncQueueDao`, dismisses notification. |

### Throttling

The service emits state every **1 second** (via `Timer.periodic`), not every GPS sample. This decouples UI refresh rate from GPS sample rate and prevents pitfall "Rebuilding Riverpod providers on every GPS fix" (per ARCHITECTURE Pitfall 5 / Performance Trap 4).

Samples accumulate continuously (every 3s GPS interval), UI ticks every 1s showing the latest snapshot. UI never sees raw samples.

### Stop race condition handling

**Pitfall:** UI taps Stop → `service.invoke('stop_tracking')` → service receives and finalizes → meanwhile a new GPS sample arrives and races the cancellation → attempts to use disposed accumulator.

**Mitigation:** In the service isolate, `stop_tracking` handler sets a `bool _stopping = true` flag FIRST, then cancels the subscription, then finalizes. The position-stream listener checks `_stopping` as its first statement and returns early if set. This is a 3-line guard.

---

## 9. Trip Save Contract

### TripsDao surface (from Phase 1)

[VERIFIED: read `lib/database/daos/trips_dao.dart`]

```dart
// Phase 1 surface:
Future<void> insertTrip(TripsCompanion companion);
```

**Critical: `TripsDao.insertTrip` does NOT enqueue to sync_queue.** The Phase 2 CONTEXT claim "Phase 1 DAO handles inserts + sync-queue enqueue in one call" is incorrect. [VERIFIED: `insertTrip` implementation is just `into(trips).insert(companion)` — no sync_queue touch.]

**Phase 2 must call both DAOs in a transaction**:

```dart
// lib/features/tracking/services/tracking_service_controller.dart

Future<void> persistFinalizedTrip(Map<String, dynamic> payload) async {
  final trip = FinalizedTrip.fromMap(payload);

  // D-10: short-trip guard
  if (trip.durationSeconds < kMinTripDurationSeconds ||
      trip.distanceMeters < kMinTripDistanceMeters) {
    _showShortTripSnackbar();
    await _notifications.dismiss();
    return;
  }

  final polyline = encodePolyline(
    trip.samples.map((p) => (lat: p.latitude, lng: p.longitude)).toList(),
  );

  await _appDatabase.transaction(() async {
    await _tripsDao.insertTrip(
      TripsCompanion.insert(
        id: trip.id,
        startTime: trip.startTime,
        endTime: trip.endTime,
        durationSeconds: trip.durationSeconds,
        distanceMeters: trip.distanceMeters,
        direction: kDirectionUnknown,             // D-11
        timeMovingSeconds: trip.timeMovingSeconds,
        timeStuckSeconds: trip.timeStuckSeconds,
        routePolyline: Value<String?>(polyline),
        // userId: omitted — table default `kDefaultUserId` applies (Phase 1 D-02)
        // isManualEntry: omitted — table default `false` applies
        // createdAt / updatedAt: omitted — table default `currentDateAndTime` applies
      ),
    );
    await _syncQueueDao.enqueueCreate(trip.id);
  });

  await _notifications.dismiss();
}
```

### Required `TripsCompanion.insert` fields

From Phase 1 schema (`lib/database/tables/trips_table.dart`), the following are **required** (no `.withDefault` and not nullable):

| Column | Type | Phase 2 value |
|--------|------|---------------|
| `id` | `String` | `Uuid().v4()` (generated in service isolate on start) |
| `startTime` | `DateTime` (UTC) | Service-isolate stop time |
| `endTime` | `DateTime` (UTC) | Service-isolate stop time |
| `durationSeconds` | `int` | `end.difference(start).inSeconds` |
| `distanceMeters` | `double` | From accumulator |
| `direction` | `String` | `kDirectionUnknown` (D-11, new constant) |
| `timeMovingSeconds` | `int` | From accumulator |
| `timeStuckSeconds` | `int` | From accumulator |

**Defaulted (Phase 2 omits):**
- `userId` → `kDefaultUserId`
- `isManualEntry` → `false`
- `createdAt` / `updatedAt` → `currentDateAndTime`
- `routePolyline` → nullable; Phase 2 always writes a string

### Sync queue integration

Phase 2 DOES enqueue to sync_queue via `SyncQueueDao.enqueueCreate(tripId)` — no payload argument, per Phase 1 D-13 (creates read trip state at sync time). The actual sync engine lives in Phase 10; Phase 2 just writes the pending row.

### Transaction boundary

Wrap both writes in `AppDatabase.transaction(...)` so a partial write (trip inserted but sync_queue enqueue failed) cannot happen. [CONFIRMED: Drift's `transaction` helper available on `AppDatabase`.]

---

## 10. Pitfalls

### Pitfall 1: `FOREGROUND_SERVICE_LOCATION` missing on Android 14
**What goes wrong:** Service fails to start with `ForegroundServiceTypeException`; app crashes.
**Mitigation:** Add `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>` AND `android:foregroundServiceType="location"` on the service element (see §4). Verify by testing `Start` on an Android 14 device — the service must reach `onStart`.

### Pitfall 2: `Position.speed` is m/s, not km/h
**What goes wrong:** Every sample "looks stuck" because `position.speed` (m/s, e.g. 20.0 = 72 km/h) is compared to `kStuckSpeedThresholdKmh = 10` as if both were the same unit. Every trip ends up 100% moving; the entire traffic-stuck feature is silently broken.
**Mitigation:** Introduce `kStuckSpeedThresholdMs = kStuckSpeedThresholdKmh / 3.6` in `constants.dart`. Compare `position.speed` directly against this. Unit-test the accumulator with a fake stream where one sample is 5 km/h and another is 40 km/h and verify they map to stuck/moving correctly.

### Pitfall 3: Foreground notification persists after trip stops
**What goes wrong:** User stops tracking; notification remains; user force-quits or uninstalls.
**Mitigation:** Dismiss notification explicitly in the finalize handler (`FlutterLocalNotificationsPlugin().cancel(kTrackingNotificationId)`) AND call `service.stopSelf()` on the service side. Test: start tracking, stop tracking, verify shade is clean. Also test: start tracking, swipe app away from recents (doesn't normally kill service, but test anyway), verify notification state.

### Pitfall 4: Background isolate callback tree-shaken in release
**What goes wrong:** The `_onBackgroundNotificationResponse` callback works in debug but silently no-ops in release — Stop button does nothing when app is backgrounded.
**Mitigation:** Annotate with `@pragma('vm:etry-point')` (correct spelling: `@pragma('vm:entry-point')`). Add a release-mode smoke test: build APK, background the app during tracking, tap Stop from notification shade, verify trip is saved.

### Pitfall 5: Requesting fine + background permission together
**What goes wrong:** On Android 11+, simultaneously requesting `Permission.locationAlways` alongside `locationWhenInUse` causes the OS to silently ignore the request. Log shows "permission request ignored" in release mode.
**Mitigation:** Request in strict two-step order: `locationWhenInUse` first, await completion, THEN `locationAlways`. Documented in §5. Never short-circuit with a "grant all" helper.

### Pitfall 6: GPS noise flipping classification at the 10 km/h boundary
**What goes wrong:** At a traffic light, speed reads 9.8, 10.1, 9.6, 10.4 km/h over 10 seconds. With strict `>=` comparison and per-sample classification, the same physical stop oscillates between moving and stuck intervals. Final stats look reasonable on average but feel wrong to the user.
**Mitigation (Phase 2):** Accept this. The spec is `prev.speed >= threshold`; the 30m accuracy gate already drops the worst noise; per-interval attribution smooths short oscillations. DO NOT add speed smoothing/rolling-median in Phase 2 — deferred to Phase 3/5 if field testing shows it. Document the tradeoff in `TripAccumulator` doc comment.

### Pitfall 7: Samples accumulating in UI isolate get lost on process kill
**What goes wrong:** If the UI isolate is accumulating samples and the service isolate is separate, the UI can be killed (e.g., memory pressure) while the service runs on, producing orphaned samples.
**Mitigation:** Accumulate in the **service isolate**, not the UI. Only stream snapshot summaries to UI. On stop, service sends the finalized trip payload to UI for persistence. This matches the two-isolate boundary in §8.

### Pitfall 8: `tools:replace` missing on service element
**What goes wrong:** `flutter_background_service`'s manifest declares the service with a default `foregroundServiceType`. Merging our manifest adds `location` but the build fails with manifest merger error: "attribute android:foregroundServiceType value=(...) is also present at [flutter_background_service]".
**Mitigation:** Add `xmlns:tools="http://schemas.android.com/tools"` to `<manifest>`, and `tools:replace="android:foregroundServiceType"` on our `<service>` element. [CITED: Android manifest merger docs.]

### Pitfall 9: `TripsDao.insertTrip` doesn't enqueue sync — silently skipped
**What goes wrong:** Developer assumes Phase 1's DAO handles sync-queue enqueue per Phase 2 CONTEXT wording. Trips save locally but never sync.
**Mitigation:** The CONTEXT is wrong. Phase 2 MUST call `syncQueueDao.enqueueCreate(tripId)` explicitly, wrapped in an `appDatabase.transaction(...)` with the trip insert. Verified by reading Phase 1's `trips_dao.dart` source.

### Pitfall 10: Pre-existing permissions assumption
**What goes wrong:** Plan tasks skip adding permissions to AndroidManifest because the CONTEXT says "already declared in Phase 1 plan 01-01". Build works on dev device because permissions were granted manually during testing of a prior run; on fresh devices the tracking silently fails.
**Mitigation:** [VERIFIED: reading `android/app/src/main/AndroidManifest.xml` shows NO location permissions.] Phase 2 plan MUST add ALL permissions in §4 from scratch. Do not trust the CONTEXT file on this point.

---

## 11. Integration Points

### New feature directory: `lib/features/tracking/`

```
lib/features/tracking/
├── screens/
│   ├── tracking_screen.dart              # Big Stop button + 3 tiles (D-12)
│   └── home_screen.dart                  # Minimal home w/ "Start commute" CTA (D-13)
├── services/
│   ├── tracking_service.dart             # Service isolate entrypoint (onStart)
│   ├── tracking_service_controller.dart  # UI-isolate wrapper over FlutterBackgroundService
│   ├── tracking_permission_service.dart  # Two-step permission flow (§5)
│   ├── tracking_notification_service.dart# flutter_local_notifications wrapper (§4)
│   └── trip_accumulator.dart             # Streaming metrics (§6)
├── state/
│   ├── tracking_state.dart               # Sealed state classes
│   └── finalized_trip.dart               # DTO for service→UI handoff
└── providers/
    └── tracking_providers.dart           # All manual Riverpod providers (§8)
```

### New shared utility: `lib/shared/utils/polyline_codec.dart`

Hand-rolled Google Polyline encoder (§7). Phase 2 tests live in `test/unit/shared/polyline_codec_test.dart` — encode a known coordinate set and assert the resulting string matches Google's reference output for that set.

### New constants in `lib/config/constants.dart`

Appended (never replacing existing values):

```dart
/// D-10: minimum trip duration in seconds for the trip to be saved.
const int kMinTripDurationSeconds = 30;

/// D-10: minimum trip distance in meters for the trip to be saved.
const int kMinTripDistanceMeters = 100;

/// D-11: Phase 2 placeholder for `direction` until Phase 3 auto-labels.
const String kDirectionUnknown = 'unknown';

/// Stuck-speed threshold in meters per second. Derived from
/// `kStuckSpeedThresholdKmh` so `Position.speed` (Geolocator returns
/// m/s) can be compared without per-sample unit conversion.
const double kStuckSpeedThresholdMs = kStuckSpeedThresholdKmh / 3.6;

/// Notification channel id for the active-commute foreground notification.
const String kTrackingNotificationChannelId = 'traevy_active_commute';

/// User-facing notification channel name.
const String kTrackingNotificationChannelName = 'Active commute';

/// Static body text for the active-commute foreground notification (D-14).
const String kTrackingNotificationTitle = 'Recording commute';

/// Notification id (must be stable so `cancel` finds it on stop).
const int kTrackingNotificationId = 1001;

/// Action id for the Stop button on the foreground notification.
const String kTrackingStopActionId = 'stop_tracking';

/// GPS sampling config — balances battery vs fidelity for a 30-min commute.
const Duration kTrackingSampleInterval = Duration(seconds: 3);

/// UI refresh throttle — service isolate emits state at this cadence
/// so the UI ticks smoothly without rebuilding per GPS fix.
const Duration kTrackingUiUpdateInterval = Duration(seconds: 1);

/// Maximum position accuracy (meters) the trip accumulator will accept.
/// Samples worse than this are dropped to protect distance/speed math.
const double kTrackingMaxAcceptableAccuracyMeters = 30;
```

### Routes: `lib/config/routes.dart`

Add two named routes:

```dart
const String kRouteHome = '/';
const String kRouteTracking = '/tracking';

const Map<String, WidgetBuilder> kAppRoutes = <String, WidgetBuilder>{
  kRouteTracking: _buildTrackingScreen,
};
```

### `lib/app.dart` update

Replace `home: const PlaceholderHome()` with the new `HomeScreen` that provides a "Start commute" CTA pushing `/tracking`.

### `lib/main.dart` update

Before `runApp`, initialize:
1. `FlutterLocalNotificationsPlugin` + background callback registration
2. The notification channel (`ensureChannel()`)
3. `FlutterBackgroundService.configure(...)` with the Android configuration pointing at the service isolate entrypoint

Example init block:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initNotifications();
  await _initBackgroundService();
  runApp(const ProviderScope(child: TraevyApp()));
}
```

### `pubspec.yaml` additions

```yaml
dependencies:
  geolocator: ^14.0.2
  flutter_background_service: ^5.1.0
  flutter_local_notifications: ^21.0.0
  permission_handler: ^12.0.1
  # (polyline encoder is hand-rolled — no dependency)
  # (uuid is already present in pubspec.yaml from Phase 1)
```

---

## 12. Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None — greenfield Phase 2, no renames | None |
| Live service config | None | None |
| OS-registered state | Notification channel `traevy_active_commute` is NEW; nothing to migrate | Create channel on first launch |
| Secrets/env vars | None | None |
| Build artifacts | None | None |

Phase 2 is additive — no rename/refactor state.

---

## 13. Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Flutter SDK | Build | ✓ | 3.41.6 (Phase 1 verified) | — |
| Android compile SDK 35 | Build | ✓ | configured in `android/app/build.gradle.kts` | — |
| Android min/target SDK 34 | Runtime | ✓ | configured | — |
| Real Android 14 device | GPS + foreground service testing | Unknown | — | Android emulator with mock GPS (degraded confidence for battery/OEM kill verification) |
| Google Play Services | FusedLocationProvider | Required on test device | — | `forceLocationManager: true` falls back to platform LocationManager (less battery-efficient) |

**Missing with fallback:** If real Android 14 device testing is unavailable, set `forceLocationManager: true` to avoid a silent Play Services dependency during CI. Keep the default in the app code.

**Missing with no fallback (blocking):** None — all required tooling is already installed from Phase 1.

---

## 14. Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK) |
| Config file | Default (no dedicated config file) |
| Quick run command | `flutter test test/unit/features/tracking/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRACK-01 | Tapping Start transitions notifier to TrackingStarting then TrackingActive via service event | unit (widget) | `flutter test test/widget/features/tracking/tracking_screen_test.dart` | ❌ Wave 0 |
| TRACK-01 | Tapping Stop finalizes trip and transitions to TrackingIdle | unit (widget) | `flutter test test/widget/features/tracking/tracking_screen_test.dart` | ❌ Wave 0 |
| TRACK-02 | Service isolate runs position stream with foreground notification (manual on device) | manual | `flutter run` + device test checklist | manual-only |
| TRACK-04 | Trip accumulator computes duration, distance, and emits finalized trip with polyline | unit | `flutter test test/unit/features/tracking/trip_accumulator_test.dart` | ❌ Wave 0 |
| TRACK-04 | `encodePolyline` produces reference output for known coordinate set | unit | `flutter test test/unit/shared/polyline_codec_test.dart` | ❌ Wave 0 |
| TRACK-05 | Classification: `prev.speed >= kStuckSpeedThresholdMs` → moving bucket; else stuck | unit | `flutter test test/unit/features/tracking/trip_accumulator_test.dart` | ❌ Wave 0 |
| TRACK-05 | Accuracy > 30m samples are dropped; time-gap > 30s not attributed | unit | `flutter test test/unit/features/tracking/trip_accumulator_test.dart` | ❌ Wave 0 |
| TRACK-05 | Unit conversion: m/s vs km/h threshold comparison | unit | `flutter test test/unit/features/tracking/trip_accumulator_test.dart` | ❌ Wave 0 |
| D-10 | Trip below 30s duration OR below 100m distance is NOT persisted; snackbar shown | unit (widget) | `flutter test test/widget/features/tracking/tracking_screen_test.dart` | ❌ Wave 0 |
| UX-03 | Foreground notification shown on start and dismissed on stop (manual on device) | manual | device test checklist | manual-only |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/features/tracking/ test/unit/shared/` (covers accumulator + polyline — < 5s)
- **Per wave merge:** `flutter test` (whole suite)
- **Phase gate:** `flutter test` green + `flutter analyze` clean + manual device test checklist completed (see below).

### Manual Device Test Checklist (Phase gate)
1. Fresh install on Android 14 device. Permissions all "deny" initially.
2. Open app → navigate to tracking screen. Start button is disabled. Grant fine location from the CTA. Start becomes enabled.
3. Tap Start. Service starts. Notification "Recording commute" appears in shade with Stop action.
4. Walk / drive ~1 minute. Duration and distance tiles update each second. Speed tile reflects movement.
5. Tap Stop in the app. Trip persists. Notification dismisses. Drift query returns a row with non-zero moving/stuck seconds.
6. Start a second trip. Immediately stop it (<30s). Snackbar: "Trip too short to save". No new row in Drift.
7. Start third trip. Background the app (home button). Lock screen. Walk another minute. Unlock. Verify notification still visible and tracking still running. Tap Stop from the notification shade. Trip persists.
8. Repeat step 7 with Play Store app battery optimization set to "Unrestricted" explicitly.

### Wave 0 Gaps
- [ ] `test/unit/features/tracking/trip_accumulator_test.dart` — covers TRACK-04, TRACK-05, D-10
- [ ] `test/unit/shared/polyline_codec_test.dart` — covers TRACK-04 polyline encoding
- [ ] `test/widget/features/tracking/tracking_screen_test.dart` — covers TRACK-01, UI state transitions, D-10 snackbar
- [ ] `test/unit/features/tracking/tracking_permission_service_test.dart` — covers §5 two-step flow (mocked permission_handler)
- [ ] Framework install — **none needed** (flutter_test bundled)

---

## 15. Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Phase 8 introduces auth |
| V3 Session Management | no | Phase 8 |
| V4 Access Control | no | No remote access in Phase 2 (local-only) |
| V5 Input Validation | partial | Validate notification action id is exactly `kTrackingStopActionId` before acting — defensive against OS replay |
| V6 Cryptography | no | No secrets in Phase 2 |
| V7 Error Handling / Logging | yes | Do not log `Position.latitude/longitude` at any log level (PII) |
| V8 Data Protection | yes | Trip data is PII (location). Drift DB is local; encryption at rest is OS-level |
| V10 Malicious Code | no | No dynamic code loading |
| V11 Business Logic | yes | D-10 guard against accidental/zero-distance trips |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Foreground service used for surveillance (user fears app tracks when not commuting) | Information Disclosure | Notification is LOW-importance, ongoing, dismisses the moment tracking stops. No silent/hidden tracking path — service can only start via explicit user action on the tracking screen. |
| Stale notification implies app is tracking when it isn't | Information Disclosure | `cancel(kTrackingNotificationId)` is called unconditionally in the finalize and short-trip-discard paths. |
| Logging lat/lng in debug output leaks PII | Information Disclosure | Lint rule / review: no `print(position)` or `debugPrint(sample)` in the tracking code. Only log derived metrics (distance, duration). |
| Action-button replay (rare) | Tampering | Validate `response.actionId == kTrackingStopActionId` before invoking service; ignore unknown action ids. |

---

## 16. Project Constraints (from CLAUDE.md)

Directives that constrain Phase 2 planning:

- **Dart null safety throughout, no `dynamic`** — affects the isolate IPC payload. `service.invoke(Map<String, dynamic>)` is unavoidable (flutter_background_service API), but the `toMap`/`fromMap` boundary lives in one file and parsed values are immediately cast to typed fields.
- **`sealed` classes for finite state** — `TrackingState` MUST be a `sealed` class, not a raw enum or `ChangeNotifier`.
- **Feature-first folder structure** — `lib/features/tracking/` owns its screens, widgets, services, and providers.
- **`dart format` + `flutter analyze` + `very_good_analysis`** — zero warnings before commit.
- **No hardcoded strings / values** — every threshold, channel id, duration, notification text goes in `lib/config/constants.dart`.
- **Widgets under 100 lines** — tracking screen's three live tiles must be extracted into separate widget files.
- **Drift is only data source for UI** — tracking UI reads from Drift after save, NOT from in-memory state. In-memory state is only for the live tracking tile updates.
- **`flutter_secure_storage` for auth tokens** — N/A to Phase 2 (no auth).
- **Manual Riverpod 3.x providers, no `@riverpod` annotation** — Phase 1 D-12 constraint still applies.
- **Commit prefix** — `[tracking]` for all Phase 2 commits.
- **Do not write custom GPS tracking code beyond what Geolocator provides** — this research already conforms by using `Geolocator.getPositionStream`. Do NOT reach for platform channels.

---

## 17. Open Questions / Risks

1. **Tracelet future reconsideration.** If Tracelet matures (documented Stop action, published `Coords.speed`, higher adoption), revisit in a later phase. Not a Phase 2 risk.
2. **Battery impact measurement.** Actual battery drain on target devices is unknown without field testing. Phase 2 ships with `LocationAccuracy.high` + 3s interval; if testing shows >10% battery per 30-minute trip, reduce to 5s interval or `LocationAccuracy.balanced`. This is tunable via constants.
3. **OEM battery kill (Samsung, Xiaomi, Huawei).** Per project PITFALLS.md Pitfall 1, stock Android 14 + foreground service is necessary but not sufficient on OEM skins. Phase 2 does NOT implement per-OEM onboarding (deferred). Document as a known v0.1 limitation; if real users hit it, address in a polish phase.
4. **Notification icon.** `AndroidResource(name: 'ic_launcher', defType: 'mipmap')` uses the launcher icon by default. For brand consistency a dedicated monochrome status-bar icon is ideal but not required for Phase 2. Punt to polish.
5. **Service start failure modes.** `FlutterBackgroundService.startService()` returns `Future<bool>` but the failure modes (Play Services absent, location disabled, permissions denied post-request) are not individually distinguishable. Phase 2 treats any `false` as a generic "Failed to start tracking" error — the pre-flight permission check should catch most cases before `startService` is called.
6. **Polyline decoder needed in Phase 4.** Phase 2 only encodes. Phase 4 (map display) will need the decoder. Recommend adding the decoder to `polyline_codec.dart` now so round-trip tests can run, even though the decode function isn't called in Phase 2.

---

## 18. Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Position.speed` on modern Android devices is accurate enough for classification at the 10 km/h boundary (OS-computed via GNSS Doppler, not position-derived) | §6 | Traffic stats are noisy; would need rolling-median in Phase 3 polish. Documented as Pitfall 6 with mitigation deferred. |
| A2 | 3s sample interval + FusedLocationProvider yields acceptable battery on mid-range Android 14 devices | §3 | Adjustable via constant — tune if field testing shows >10% drain per trip. |
| A3 | `flutter_background_service`'s isolate is reliable on Android 14 with the declared `foregroundServiceType="location"` | §4 | If unreliable, the fallback is `flutter_foreground_task` (more opinionated, explicit action-button API). Would require a task to swap. |
| A4 | Hand-rolled polyline encoder produces Google-compatible output | §7 | Unit test against a known reference set (e.g., the three-point set in Google's algorithm doc). Low risk. |
| A5 | `AppDatabase.transaction(...)` wraps both DAOs successfully | §9 | Confirmed by reading Drift docs; this is the standard Drift API. Risk negligible. |

---

## 19. References

### Primary (HIGH confidence)
- [Tracelet package listing — pub.dev/packages/tracelet](https://pub.dev/packages/tracelet) — version, publisher, license verification
- [geolocator — pub.dev/packages/geolocator](https://pub.dev/packages/geolocator) — API, permissions, Android 14 notes
- [Position class API — geolocator_platform_interface](https://pub.dev/documentation/geolocator_platform_interface/latest/geolocator_platform_interface/Position-class.html) — field definitions, speed unit
- [ForegroundNotificationConfig — geolocator_android source](https://github.com/Baseflow/flutter-geolocator/blob/main/geolocator_android/lib/src/types/foreground_settings.dart) — verified NO action-button support
- [flutter_background_service — pub.dev](https://pub.dev/packages/flutter_background_service) — isolate model, Android 14 config, version
- [flutter_background_service/example](https://pub.dev/packages/flutter_background_service/example) — invoke/on patterns, `stopService`
- [flutter_local_notifications — pub.dev](https://pub.dev/packages/flutter_local_notifications) — action buttons, channel importance, background callback
- [permission_handler — pub.dev](https://pub.dev/packages/permission_handler) — two-step dance, `locationWhenInUse` / `locationAlways`
- [Foreground service types — developer.android.com](https://developer.android.com/develop/background-work/services/fgs/service-types) — `FOREGROUND_SERVICE_LOCATION` permission, `foregroundServiceType="location"` attribute
- [Google Polyline Algorithm spec](https://developers.google.com/maps/documentation/utilities/polylinealgorithm) — canonical encoding algorithm

### Secondary (MEDIUM confidence)
- [Tracelet GitHub README](https://github.com/Ikolvi/Tracelet) — feature list, config shape (incomplete)
- [Tracelet API Reference](https://raw.githubusercontent.com/Ikolvi/Tracelet/main/help/API.md) — method signatures (class definitions missing)
- [Drift isolate discussion #3229](https://github.com/simolus3/drift/discussions/3229) — `shareAcrossIsolates` option (not needed for Phase 2)
- [Android background service with Flutter — plugfox.dev](https://plugfox.dev/android-background-service-with-flutter/) — manifest service-type declarations

### Tertiary (LOW confidence — flagged for validation)
- [google_polyline_algorithm — pub.dev](https://pub.dev/packages/google_polyline_algorithm) — 5 years stale; not adopted, used only to verify the encoding algorithm's math

### Source files read (LOCAL, HIGH)
- `CLAUDE.md` — Traffic Calculation, Data Flow, Rules for Claude
- `.planning/phases/02-core-tracking/02-CONTEXT.md` — D-01..D-15
- `.planning/phases/01-foundation/01-CONTEXT.md` — Phase 1 locked decisions (D-12 manual Riverpod)
- `.planning/research/STACK.md` — prior package recommendations (found to be stale)
- `.planning/research/ARCHITECTURE.md` — layering and Pitfall references
- `.planning/research/PITFALLS.md` — GPS noise, OEM kills, notification UX
- `pubspec.yaml` — current dependency state (drift 2.32.1, flutter_riverpod 3.3.1, uuid 4.5.3 already present)
- `lib/database/daos/trips_dao.dart` — `insertTrip(TripsCompanion)` signature; does NOT enqueue sync
- `lib/database/daos/sync_queue_dao.dart` — `enqueueCreate(tripId)` signature
- `lib/database/tables/trips_table.dart` — required vs defaulted columns
- `lib/config/constants.dart` — where to append new constants
- `lib/database/providers.dart` — manual Riverpod 3.x pattern (no @riverpod)
- `lib/app.dart`, `lib/main.dart`, `lib/config/routes.dart` — current scaffold state
- `android/app/src/main/AndroidManifest.xml` — confirmed NO location permissions present
- `android/app/build.gradle.kts` — compileSdk 35, min/target 34 confirmed

---

## 20. Metadata

**Confidence breakdown:**
- Tracelet verdict: HIGH — verified package existence, publisher, version, adoption metrics, and API surface. Fall-back decision is unambiguous given D-14.
- Standard stack (geolocator / flutter_background_service / flutter_local_notifications / permission_handler): HIGH — all versions verified on pub.dev, API surfaces checked against official docs and source.
- Android 14 foreground service: HIGH — developer.android.com confirmed `FOREGROUND_SERVICE_LOCATION` + `foregroundServiceType="location"` requirements.
- Permission flow: HIGH — permission_handler docs confirm two-step requirement.
- Streaming metrics / Haversine: HIGH — `Geolocator.distanceBetween` documented, unit conversion (m/s vs km/h) verified.
- Polyline encoding: HIGH — Google's algorithm is frozen and publicly specified; hand-roll is trivially correct.
- Riverpod manual provider pattern: HIGH — consistent with Phase 1's established pattern in `lib/database/providers.dart`.
- Trip save contract: HIGH — read Phase 1 source directly; corrected a misstatement in the CONTEXT file.

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (package versions are close to current — re-verify in 30 days; Android 14 platform rules are stable for 12+ months)
