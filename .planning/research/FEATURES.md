# Feature Research — iOS Parity (v0.2)

**Domain:** iOS behavioral parity for an existing Flutter Android commute tracker
**Researched:** 2026-06-02
**Confidence:** MEDIUM-HIGH overall (geolocator iOS behavior HIGH via official docs + changelog; flutter_background_service iOS limits HIGH via pub.dev; notification model MEDIUM via flutter_local_notifications docs; some permission UX details MEDIUM from community sources)

---

## Scope

This document replaces the prior v0.1 FEATURES.md for the v0.2 milestone. Every feature already exists and works on Android. The question for each feature is: **does it work identically on iOS, or does it need iOS-specific handling?**

Three categories are used throughout:

- **WORKS IDENTICALLY** — the Flutter/Dart layer is platform-neutral; no iOS code changes needed beyond Info.plist entries
- **NEEDS iOS HANDLING** — different permission model, capability, or platform API; implementation work required
- **FUNDAMENTALLY DIFFERENT** — the Android pattern has no direct iOS equivalent; a different UX or technical approach is required

---

## Feature-by-Feature iOS Assessment

### 1. Google Sign-In + Firebase Auth

**Android implementation:** `google_sign_in` + `firebase_auth`, configured via `google-services.json`. Auth persists across restarts via FlutterFire's session management. Works with no explicit URL scheme registration.

**iOS behavior: NEEDS iOS HANDLING**

iOS requires the OAuth redirect to return control to your app via a custom URL scheme. Without it, the sign-in flow opens Safari, completes, and then has no way to return the user to the app.

**What must change:**

1. Add `GoogleService-Info.plist` to `ios/Runner/` in Xcode (Runner target → Add Files). This is the iOS equivalent of `google-services.json`. It must be registered as an Xcode resource, not just dropped in the folder.

2. Register the `REVERSED_CLIENT_ID` URL scheme in `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

The value is the `REVERSED_CLIENT_ID` field from `GoogleService-Info.plist`. Without this, sign-in crashes or silently fails after the browser returns.

3. The `google_sign_in` package (v7.x) reads the client ID from `GoogleService-Info.plist` automatically on iOS. No Dart-level change is needed as long as the plist is in the bundle.

**Session persistence:** Works identically once configured. FlutterFire manages the Firebase ID token refresh automatically on both platforms.

**Onboarding UX:** Identical — the same Dart sign-in screen and Firebase auth state stream work on iOS without changes.

---

### 2. Background GPS Tracking (geolocator + flutter_background_service)

**Android implementation:** `flutter_background_service` runs a persistent Android Foreground Service. `geolocator` streams GPS positions into it. The foreground service keeps the Dart isolate alive indefinitely when the user puts the phone in their pocket.

**iOS behavior: FUNDAMENTALLY DIFFERENT**

This is the highest-risk feature for iOS parity. The two packages play completely different roles on iOS:

**`flutter_background_service` on iOS:**
The package explicitly states in its documentation: *"iOS doesn't have a long running service feature like Android. So, it's not possible to keep your application running when it's in background because the OS will suspend your application soon."*

On iOS, the package uses `BGTaskScheduler` (iOS 13+ Background Fetch), which fires at most every 15 minutes and runs for only 15–30 seconds per invocation. This is **not suitable** for continuous commute recording that may last 20–90 minutes. Do not use `flutter_background_service`'s `onBackground` callback as the GPS engine on iOS.

**`geolocator` on iOS — the correct approach:**
`geolocator` uses `CLLocationManager` natively on iOS. When configured correctly, iOS's location background mode keeps GPS streaming even when the app is suspended, without needing a separate background service. This is because CLLocationManager with background location enabled is a special OS-managed capability that bypasses normal app suspension rules.

**Required configuration for continuous background GPS on iOS:**

Step 1 — Xcode capability: In Xcode, open `Runner` target → Signing & Capabilities → `+` Capability → **Location Updates**. This writes `UIBackgroundModes` with `location` into the entitlements file.

Step 2 — Info.plist entries (all four required):
```xml
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Commute Tracker records your route while you commute.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Commute Tracker continues recording if you switch apps during your commute.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Commute Tracker continues recording if you switch apps during your commute.</string>
```

Step 3 — `AppleSettings` in Dart when starting the position stream:
```dart
final locationSettings = AppleSettings(
  accuracy: LocationAccuracy.high,
  activityType: ActivityType.automotiveNavigation,
  distanceFilter: 10, // metres — avoids flooding DB with stationary noise
  pauseLocationUpdatesAutomatically: false, // must be false for commute tracking
  showBackgroundLocationIndicator: true,    // shows blue pill in status bar
  allowsBackgroundLocationUpdates: true,    // activates CLLocationManager background mode
);
```

`allowsBackgroundLocationUpdates` was added to `AppleSettings` in geolocator 8.2.0 and is present in the project's installed version (14.0.2). This is the critical flag that maps to `CLLocationManager.allowsBackgroundLocationUpdates = true` on the native side, and it requires the `UIBackgroundModes: location` entitlement to be set or iOS will throw an exception at runtime.

**iOS 16.4+ caveat:** Apple tightened background location behavior in iOS 16.4. Apps that call both `startUpdatingLocation()` and `startMonitoringSignificantLocationChanges()` with low accuracy may get suspended. The mitigation is to set `desiredAccuracy` to `kCLLocationAccuracyHundredMeters` or better (which `LocationAccuracy.high` covers) and not set a distance filter above ~100 m. The `AppleSettings` above are safe.

**What happens to `flutter_background_service` on iOS:**
The service is still initialized but its iOS `onBackground` callback only runs for background data sync (15–30 s windows). This is acceptable for the sync engine (brief HTTP calls to Cloud Functions) but not for GPS. The GPS stream must be driven by geolocator's CLLocationManager, not by the background service isolate.

**Architecture change required:**
On Android, the GPS stream lives inside the `flutter_background_service` isolate. On iOS, the GPS stream must be started in the foreground (when the user taps Start) and configured with `allowsBackgroundLocationUpdates: true`. CLLocationManager then keeps delivering positions to the main isolate even when the app is backgrounded — iOS does not suspend CLLocationManager with background location mode active.

The trip recording service needs a platform branch:
- Android path: start `flutter_background_service`, run geolocator stream inside it
- iOS path: start geolocator stream directly on the main isolate with `AppleSettings(allowsBackgroundLocationUpdates: true)`

---

### 3. Location Permission Model (Onboarding Flow)

**Android implementation:** Single permission request for `ACCESS_FINE_LOCATION` + `ACCESS_BACKGROUND_LOCATION`. Both are requested once during onboarding. If granted, tracking works permanently.

**iOS behavior: NEEDS iOS HANDLING — two-step model with deferred upgrade**

iOS enforces a two-step, deliberately non-simultaneous flow. Attempting to request "Always" permission directly without first granting "When In Use" produces unpredictable results (often silently ignored). The correct flow:

**Step 1 — Request "When In Use" first:**
Use `permission_handler` or `geolocator.requestPermission()`. The user sees:
> *"Allow [App] to use your location? — Only While Using the App / Allow Once / Don't Allow"*

Do not mention background location in this prompt. Present this during onboarding, contextualised with "Commute Tracker needs location access to record your route."

**Step 2 — Request "Always" as a deferred upgrade:**
After "When In Use" is granted, request "Always Allow" via `requestAlwaysAuthorization()`. iOS then shows a second dialog:
> *"Allow [App] to use your location? — Change to Always Allow / Keep Only While Using"*

This second dialog is shown by iOS on its own schedule and may not appear immediately. iOS has deferred this upgrade since iOS 13: the user will see the prompt approximately the next time the app is used in the foreground after the app has been used in the background with "When In Use" permission.

**Consequence for onboarding:** The onboarding screen cannot complete location setup in a single step on iOS. The recommended UX:

1. Onboarding step 1: Request "When In Use" — required for tracking to start at all.
2. Explain in a custom in-app dialog: "For uninterrupted tracking when you switch apps, allow 'Always' access. iOS will ask you shortly." Then request upgrade.
3. Accept that the user may only have "When In Use" initially. In that case, tracking works while the app is in the foreground but stops if the user puts the phone away. Show a banner in the active tracking screen: "Location access is set to 'While Using'. Switch apps to see continuous tracking." Link to Settings.
4. Track permission state via `geolocator.checkPermission()` on each app resume and prompt upgrade if still `whenInUse`.

**"Allow Once" path:** If the user selects "Allow Once," `geolocator` returns `LocationPermission.whileInUse` but the permission resets on next app launch. Detect this by checking permission on every cold start in the tracking service initialisation.

**Restricted state:** On supervised/managed devices (uncommon for consumer), location may be `LocationPermission.unableToDetermine`. Surface an error state.

**Key Info.plist requirement:** Both `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` must be present. iOS will crash at the permission request if either is missing. The description strings are shown verbatim in the system dialog — they must be user-facing sentences, not developer notes.

---

### 4. Blue Background Location Indicator (iOS-specific)

**Android equivalent:** The persistent foreground service notification serves as the "tracking is active" signal.

**iOS behavior: FUNDAMENTALLY DIFFERENT — this is the iOS equivalent**

When `allowsBackgroundLocationUpdates = true` and the app enters the background while streaming location, iOS displays a blue pill/bar at the top of the screen (in the status bar area, where signal/battery icons live). The text reads the app name and is not customisable.

This indicator:
- Appears automatically when background location starts
- Disappears when the location stream is stopped (trip ended)
- Cannot be suppressed if `allowsBackgroundLocationUpdates = true` and the app is backgrounded
- On newer iPhones with Dynamic Island: appears as a blue pill in the Dynamic Island
- On older iPhones: appears as a blue status bar replacing the carrier name

`showBackgroundLocationIndicator: true` in `AppleSettings` makes this explicit. Setting it to `false` suppresses the indicator but **only if the app has "Always" permission** — with "When In Use," the indicator is always shown and cannot be hidden.

**UX implication:** There is no equivalent of the Android persistent foreground service notification on iOS during active tracking. The blue status bar indicator is the system-provided signal. The app does not need to (and cannot) post a custom persistent notification to indicate tracking is active. The app can show an in-app banner or the tracking screen itself, but no custom notification is shown in Notification Center during a trip.

---

### 5. Persistent Tracking Notification

**Android implementation:** `flutter_background_service` with `isForegroundMode: true` posts a persistent Android notification (shown in the notification tray) that cannot be dismissed while tracking is active. This is mandatory for foreground services on Android 8.0+.

**iOS behavior: FUNDAMENTALLY DIFFERENT — no equivalent concept**

iOS has no foreground service. There is no API to post a "sticky" undismissable notification. The concepts map as follows:

| Android | iOS |
|---------|-----|
| Foreground service notification (required by OS) | Not required; OS handles background permission transparently |
| Notification visible in notification tray during tracking | Blue status bar indicator (OS-provided, not customisable) |
| User can see tracking notification without opening app | User cannot see a custom tracking state notification |

**What to do on iOS:**
- Do not post any notification when tracking starts. There is nothing to post.
- The blue location indicator in the status bar tells the user the app is accessing location.
- If the user explicitly opens Notification Center while tracking, they will not see a tracking notification — this is expected iOS behavior.
- If the app returns to the foreground mid-trip, the tracking screen shows the live tracking state (timer, distance). This is the primary in-app signal.
- Consider posting a local notification when a trip ends (not while tracking is active): "Your commute has been recorded — 32 min, 14.2 km." This gives the user feedback without a persistent notification.

**Implementation change:** The `notification_service.dart` `startTrackingNotification()` / `stopTrackingNotification()` calls must be gated behind a platform check (`if (Platform.isAndroid)`). On iOS, these calls should be no-ops.

---

### 6. Weekly Summary Notification + Departure Reminder

**Android implementation:** `flutter_local_notifications` with channel configuration. Channels are declared with importance and sound settings. No runtime permission required on Android < 13 (added in Android 13 / targetSdk 33+).

**iOS behavior: NEEDS iOS HANDLING — permission required first**

On iOS, notification permission is a runtime requirement that must be explicitly requested. The system shows one prompt asking for alert, badge, and sound — once denied, the user must go to Settings to re-enable.

**Key differences:**

1. **No notification channels on iOS.** The Android channel concept (`AndroidNotificationChannel` with importance, sound, vibration) does not exist on iOS. iOS controls notification appearance via user settings. Existing channel setup code is Android-only and must be wrapped in `if (Platform.isAndroid)`.

2. **Permission must be requested.** On iOS, call:
```dart
await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
    ?.requestPermissions(alert: true, badge: true, sound: true);
```
Request this after the user has engaged with the app (not at cold launch), ideally when the user explicitly enables weekly summaries or departure reminders in Settings.

3. **DarwinInitializationSettings:** The `IOSInitializationSettings` (now `DarwinInitializationSettings`) must be configured. Set `requestAlertPermission`, `requestBadgePermission`, `requestSoundPermission` to `false` to avoid prompting at initialization — request permission later in Settings when the user opts in.

4. **Provisional authorization:** iOS 12+ supports provisional authorization (notifications delivered silently to Notification Center without interrupting the user). This can be requested by passing `provisionalPermission: true` to `requestPermissions()`. Note: there is a reported bug in `flutter_local_notifications` where provisional permission returns `false` immediately without a dialog. Treat provisional as a best-effort enhancement, not a critical path.

5. **Timing of permission prompt:** Unlike Android where permissions can be bundled with location permission at onboarding, iOS best practice is to request notification permission only when the user enables a notification feature (weekly summary toggle or departure reminder toggle in Settings screen). This maximises opt-in rate.

6. **Notification display while app is in foreground:** On iOS, by default, notifications are not displayed if the app is in the foreground. To display them (e.g., a weekly summary fires while the app is open), configure `DarwinNotificationDetails` with presentation options or implement the `UNUserNotificationCenterDelegate`.

**flutter_local_notifications v21.0.0** (the installed version) supports all of the above. No version change is needed.

---

### 7. Map Display (flutter_map / Route Visualization)

**Android implementation:** `flutter_map` with OpenStreetMap tiles. No API key. Works fully offline if tile caching is active (`flutter_map_tile_caching`). Route polyline rendered from the stored encoded polyline string.

**iOS behavior: WORKS IDENTICALLY**

`flutter_map` is a pure Dart + WebView implementation that works identically on iOS. OpenStreetMap tile fetching uses standard HTTPS — no iOS-specific API key, URL scheme, or entitlement is needed. Tile caching via `flutter_map_tile_caching` works through the same Drift/SQLite layer and is platform-neutral.

The project already switched from `google_maps_flutter` (which would require a separate iOS Maps API key in `AppDelegate.swift` and `Info.plist`) to `flutter_map`. This decision benefits iOS directly: there is no additional Google Maps iOS setup to perform.

**One caveat:** If the device does not have internet access and no tiles are cached for a given trip's route area, the map background will be blank (grey tiles). The route polyline itself will still render since it is stored locally. This is the same behavior as Android.

---

### 8. Trip Recording Logic (Duration, Distance, Traffic Calculation)

**Android implementation:** All Dart — speed samples from geolocator are processed in the trip processor service. `time_moving_seconds` and `time_stuck_seconds` computed from the 10 km/h threshold. Stored in Drift.

**iOS behavior: WORKS IDENTICALLY**

The trip processing logic is pure Dart and platform-neutral. geolocator provides `Position.speed` in m/s on both Android and iOS (from `CLLocationManager` on iOS). The 10 km/h threshold calculation (`kStuckSpeedThresholdKmh` constant) is unchanged.

**One iOS-specific note:** On iOS, geolocator's speed value is `-1.0` when the device is stationary and `CLLocationManager` has not received a valid speed reading. The trip processor must treat `speed < 0` as stationary (stuck), not as invalid data requiring a skip. On Android, geolocator returns `0.0` for stationary, so this edge case does not arise. Add a guard: `speed < 0 || speed < kStuckSpeedThresholdMs` → stuck.

---

### 9. Direction Auto-Labeling

**iOS behavior: WORKS IDENTICALLY**

Pure Dart time-of-day logic. No platform dependency.

---

### 10. Trip Editing, Deletion, Manual Entry

**iOS behavior: WORKS IDENTICALLY**

Pure Dart + Drift. All forms and Drift DAOs are platform-neutral. The only UI consideration: iOS users expect navigation to use `CupertinoPageRoute`-style slide transitions instead of Material's bottom-up slide. Flutter Material widgets render on iOS but look and feel slightly non-native. For v0.2 (test on real iPhone via Xcode), this is acceptable — full Cupertino adaptation is v0.3+ polish.

---

### 11. Daily Log (List + Calendar View)

**iOS behavior: WORKS IDENTICALLY**

`table_calendar` and the trip list widget are pure Dart. No platform-specific code.

---

### 12. Stats Dashboard (Charts, Trend Lines, Traffic Breakdown)

**iOS behavior: WORKS IDENTICALLY**

`fl_chart` renders via Flutter's canvas and is platform-neutral. All stats queries are Drift SQL, platform-neutral. No changes needed.

---

### 13. Sync Engine (Drift → Cloud Functions → Firestore)

**iOS behavior: WORKS IDENTICALLY**

The sync engine uses `http` (Dart) + `connectivity_plus` (iOS-compatible) + Drift. All three packages have iOS support. The sync triggers (app resume, connectivity change, post-save) work identically via `connectivity_plus`'s `ConnectivityResult` stream on iOS.

**One iOS note:** On iOS, `connectivity_plus` uses `SCNetworkReachability` which does not require additional permissions. No Info.plist entry needed for network connectivity detection.

---

### 14. Cloud Restore (Settings → GET /trips/restore)

**iOS behavior: WORKS IDENTICALLY**

HTTP GET call from Dart, write results to Drift, deduplicate by UUID. Fully platform-neutral.

---

### 15. Secure Storage (Auth Tokens)

**Android implementation:** `flutter_secure_storage` uses Android Keystore.

**iOS behavior: WORKS IDENTICALLY (with one setup step)**

`flutter_secure_storage` uses iOS Keychain automatically. No code change required — the package handles the Keystore vs Keychain distinction internally.

**Setup step required:** Xcode → Runner target → Signing & Capabilities → `+` Capability → **Keychain Sharing**. Add this to Debug, Profile, and Release configurations. Without the capability, writes to Keychain may fail silently with error `-34018` on real devices (works on simulator but fails on device).

**Optional but recommended:** Add `NSFaceIDUsageDescription` to `Info.plist` if Face ID or Touch ID is used as an access control. For this app, auth tokens are not biometric-gated (they are read programmatically during sync), so no biometric entitlement is needed.

---

### 16. Dark Mode

**iOS behavior: WORKS IDENTICALLY**

Flutter's `ThemeMode.system` reads `MediaQuery.platformBrightness` which maps to the iOS system appearance setting. The existing `theme.dart` with `ThemeMode.system` / `ThemeMode.light` / `ThemeMode.dark` works identically on iOS. No changes needed.

---

### 17. Dashboard Home Screen

**iOS behavior: WORKS IDENTICALLY**

Pure Flutter widget tree with Drift data sources. Platform-neutral.

---

## Summary: iOS Handling Matrix

| Feature | iOS Status | Work Required |
|---------|------------|---------------|
| Google Sign-In + Firebase Auth | NEEDS iOS HANDLING | Add `GoogleService-Info.plist`, register `REVERSED_CLIENT_ID` URL scheme in Info.plist |
| Background GPS (geolocator) | NEEDS iOS HANDLING | `AppleSettings(allowsBackgroundLocationUpdates: true)`, `UIBackgroundModes: location`, Xcode Location Updates capability, iOS platform branch in tracking service |
| `flutter_background_service` role on iOS | FUNDAMENTALLY DIFFERENT | GPS must NOT go through the background service on iOS; use geolocator directly. Background service remains for opportunistic sync only (15–30 s windows) |
| Location permission model | NEEDS iOS HANDLING | Two-step onboarding (When In Use first, Always upgrade deferred). Both `NSLocation*` description keys in Info.plist. Handle `whileInUse` degraded state gracefully |
| Blue background location indicator | FUNDAMENTALLY DIFFERENT | iOS-provided, not customisable. No app code needed — it appears automatically when background location is active |
| Persistent tracking notification | FUNDAMENTALLY DIFFERENT | Do not post on iOS. Gate `startTrackingNotification()` behind `Platform.isAndroid`. The blue status bar indicator is the iOS equivalent |
| Weekly summary + departure reminder notifications | NEEDS iOS HANDLING | Request permission via `IOSFlutterLocalNotificationsPlugin.requestPermissions()` when user enables each feature in Settings. No notification channels on iOS |
| flutter_local_notifications init | NEEDS iOS HANDLING | `DarwinInitializationSettings` with all permission flags `false` (defer prompt). Add `UNUserNotificationCenterDelegate` in AppDelegate |
| Map display (flutter_map + OSM) | WORKS IDENTICALLY | No changes |
| Trip recording logic + traffic calc | WORKS IDENTICALLY | Add `speed < 0` guard for iOS CLLocationManager stationary state |
| Direction auto-labeling | WORKS IDENTICALLY | No changes |
| Trip editing / deletion / manual entry | WORKS IDENTICALLY | No changes (Material UI acceptable for v0.2) |
| Daily log (list + calendar) | WORKS IDENTICALLY | No changes |
| Stats dashboard (fl_chart) | WORKS IDENTICALLY | No changes |
| Sync engine | WORKS IDENTICALLY | No changes |
| Cloud restore | WORKS IDENTICALLY | No changes |
| Secure storage (Keychain) | WORKS IDENTICALLY | Add Keychain Sharing capability in Xcode |
| Dark mode | WORKS IDENTICALLY | No changes |
| Dashboard home screen | WORKS IDENTICALLY | No changes |

---

## Permission Flow — Concrete Order

The following is the correct, sequenced iOS permission acquisition flow for v0.2:

```
App first launch (onboarding):
  1. Sign in with Google → opens browser → URL scheme returns to app
  2. Request location "When In Use" → system dialog
     ├── Granted → proceed
     ├── Denied → block onboarding, show Settings deep-link
     └── Allow Once → accepted for onboarding; will need re-request
  3. Request "Always" upgrade → system dialog (may be deferred by iOS)
     ├── Granted → ideal state; blue indicator appears during background tracking
     └── Not yet / When In Use only → accepted; show degraded-state banner during tracking

App Settings screen (user enables notification features):
  4. Request notification permission → system dialog (first time only)
     ├── Granted → schedule weekly summary / departure reminders
     └── Denied → show Settings deep-link; disable toggle

During active trip (if "When In Use" only):
  5. Show in-app banner: "Enable 'Always Allow' for location to track when switching apps."
     Tapping banner → open iOS Settings > Privacy > Location Services > [App]
```

---

## Architecture Changes for iOS

The following code modules require platform-specific branching for iOS:

1. **`tracking/services/tracking_service.dart`** (or equivalent)
   - Android path: configure `flutter_background_service`, start service, GPS inside it
   - iOS path: start geolocator stream directly with `AppleSettings(allowsBackgroundLocationUpdates: true)`
   - Use `Platform.isIOS` / `Platform.isAndroid` to branch

2. **`notifications/notification_service.dart`**
   - `startTrackingNotification()` → no-op on iOS (`if (!Platform.isAndroid) return;`)
   - `stopTrackingNotification()` → no-op on iOS
   - `initialize()` → use `DarwinInitializationSettings` on iOS; omit channel declaration on iOS

3. **`features/auth/services/auth_service.dart`**
   - No Dart change. `google_sign_in` package handles the URL scheme redirect internally on iOS.

4. **`ios/Runner/Info.plist`** (new file — does not exist yet)
   - `NSLocationWhenInUseUsageDescription`
   - `NSLocationAlwaysAndWhenInUseUsageDescription`
   - `NSLocationAlwaysUsageDescription`
   - `UIBackgroundModes: [location]`
   - `CFBundleURLTypes` with `REVERSED_CLIENT_ID`
   - `BGTaskSchedulerPermittedIdentifiers` (for flutter_background_service background fetch, used for sync)

5. **`ios/Runner/AppDelegate.swift`** (new file from `flutter create --platforms ios`)
   - `UNUserNotificationCenter.current().delegate = self`
   - `SwiftFlutterBackgroundServicePlugin.taskIdentifier = "dev.flutter.background.refresh"` (for sync)

6. **`ios/Runner/` Xcode capabilities** (configured in Xcode, not in Dart):
   - Location Updates
   - Keychain Sharing
   - Background Modes → Background fetch (for flutter_background_service sync windows)

---

## iOS-Specific Pitfalls for This Feature Set

| Feature | Pitfall | Mitigation |
|---------|---------|------------|
| Background GPS | Using `flutter_background_service` as the GPS engine on iOS — it only runs 15–30 s every ≥15 min | Use geolocator with `AppleSettings(allowsBackgroundLocationUpdates: true)` directly |
| Location permission | Requesting "Always" before "When In Use" — iOS ignores or mis-handles this | Always request "When In Use" first, then upgrade |
| Location permission | Assuming Android single-step permission model works on iOS | Two-step with possible deferral; handle `whileInUse` as valid degraded state |
| Tracking notification | Calling `startTrackingNotification()` on iOS — will post a visible notification at start of trip, no equivalent to foreground service, confuses users | Gate behind `Platform.isAndroid` |
| Notification channels | Declaring `AndroidNotificationChannel` globally without platform guard — will compile but is irrelevant / confusing on iOS | Wrap all channel creation in `if (Platform.isAndroid)` |
| Notification permission | Requesting notification permission at app start (onboarding) — iOS users decline permission when asked too early, before value is established | Defer to when user enables a specific notification feature |
| Secure storage | Skipping Keychain Sharing capability — writes fail silently on real device with `-34018` | Add Keychain Sharing capability in Xcode before first test on device |
| Google Sign-In | Omitting `CFBundleURLTypes` / URL scheme — sign-in flow never returns to the app | Add `REVERSED_CLIENT_ID` to `CFBundleURLTypes` in Info.plist |
| Maps API key | If ever switching back to `google_maps_flutter`, iOS needs a separate Maps API key in `AppDelegate.swift` | Stay on `flutter_map` (already decided) |
| Speed reading | geolocator returns `-1.0` for speed on iOS when stationary, not `0.0` — trip processor may misclassify | Add `if (speed < 0) speed = 0.0` guard before threshold comparison |
| Info.plist missing keys | Any missing `NSLocation*` key causes a crash when permission is requested at runtime (no warning at build time) | Validate all four location string keys exist before first device run |
| 7-day free provisioning | Free developer provisioning (no Apple Developer account) invalidates after 7 days — app must be rebuilt and reinstalled | Document re-signing cadence; milestone scope is "runs on real iPhone via Xcode," not persistent install |

---

## What Does Not Need to Change for iOS

The following can be implemented without any platform branching. All use the same Dart code on both platforms:

- Drift database schema and all DAOs
- All Riverpod providers
- All stats computation logic
- Trip direction auto-labeling
- All UI screens except notification service initialization
- `http` sync calls to Cloud Functions
- `connectivity_plus` network state detection
- `fl_chart` chart widgets
- `table_calendar` calendar widget
- `flutter_map` map rendering
- UUID generation
- Dark mode theming
- `intl` date/time formatting

---

## Sources

- geolocator pub.dev documentation + changelog: `AppleSettings` class, `allowsBackgroundLocationUpdates`, `showBackgroundLocationIndicator` added in v8.2.0; UIBackgroundModes docs added in v14.0.2 (HIGH confidence — official package docs)
- flutter_background_service pub.dev documentation: explicit iOS limitations ("cannot keep running when in background," "only 15–30 seconds"), `BGTaskScheduler` usage (HIGH confidence — official package docs)
- flutter_local_notifications pub.dev documentation: `DarwinInitializationSettings`, `requestPermissions()` API, no iOS notification channels (HIGH confidence — official package docs)
- google_sign_in_ios pub.dev + Firebase iOS Google Sign-In docs: `REVERSED_CLIENT_ID` URL scheme requirement, `GoogleService-Info.plist` placement (HIGH confidence — official docs)
- flutter_secure_storage pub.dev: Keychain Sharing capability requirement, `-34018` error on real device (MEDIUM confidence — community-confirmed)
- Apple CLLocationManager documentation: `allowsBackgroundLocationUpdates`, `pausesLocationUpdatesAutomatically`, blue indicator behavior (HIGH confidence — official Apple docs, confirmed via multiple sources)
- iOS 16.4 background location change: `startUpdatingLocation` + high accuracy required to avoid suspension (MEDIUM confidence — cropsly.com blog + Apple developer forums)
- Notificare iOS location permission deep-dive: two-step permission flow, deferred "Always" upgrade (MEDIUM confidence — third-party but detailed and consistent with Apple docs)
- iOS provisional notification permission bug in flutter_local_notifications (GitHub issue #2235, February 2024): provisional returns false without dialog (LOW-MEDIUM confidence — single issue report)
- flutter_map with OpenStreetMap: no iOS API key required (HIGH confidence — well-established)

---
*Feature research for: iOS behavioral parity — Commute Tracker v0.2*
*Researched: 2026-06-02*
