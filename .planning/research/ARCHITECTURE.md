# Architecture Research

**Domain:** Offline-first GPS commute tracking — iOS port (v0.2 milestone)
**Researched:** 2026-06-02
**Confidence:** HIGH (existing Dart/Flutter code read directly; iOS integration details verified via Context7 + official geolocator/flutter_background_service/permission_handler docs)

---

## iOS Port: The Central Architectural Question

The existing tracking architecture runs entirely inside a `flutter_background_service` isolate on Android. The isolate:
1. Opens a `Geolocator.getPositionStream(AndroidSettings(...))` with a 3-second interval.
2. Feeds samples into `TripAccumulator`.
3. Fires a 1 Hz UI timer that invokes `kTrackingStateEvent` across the service-UI isolate boundary.
4. Responds to `kStopTrackingEvent` by calling `accumulator.finalize()`, invoking `kTripFinalizedEvent`, and calling `service.stopSelf()`.

**iOS does not have an equivalent foreground service.** The `flutter_background_service` README explicitly states: _"iOS doesn't have a long running service feature like Android. The OS will suspend your application soon."_ The `IosConfiguration.onBackground` callback runs via `BGTaskScheduler`, fires at most every 15 minutes, and is alive for only ~15–30 seconds — entirely unsuitable for continuous GPS recording during a commute.

### The Correct iOS Background GPS Mechanism

iOS does support continuous GPS while the app is running or backgrounded, but through a different mechanism: **CLLocationManager with `allowsBackgroundLocationUpdates = true`**. When set, the system does not suspend the app while the location manager has an active session. The Geolocator package exposes this via `AppleSettings(allowBackgroundLocationUpdates: true)`.

This means the `flutter_background_service` isolate is **not needed for iOS background GPS**. Geolocator's native CLLocationManager integration keeps the app process running as long as location updates are active, which is exactly the behavior the tracking session requires.

---

## Abstraction Seam: The Minimal-Change Path

The cleanest seam is the `LocationSettings` argument passed to `Geolocator.getPositionStream()` inside `tracking_service.dart`. The service isolate currently constructs `AndroidSettings` unconditionally:

```dart
// tracking_service.dart — current code (Android-only)
final settings = AndroidSettings(
  accuracy: LocationAccuracy.high,
  intervalDuration: kTrackingSampleInterval,
);
```

The platform-conditional fix is a single `if/else` block in the same file:

```dart
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:geolocator_apple/geolocator_apple.dart';

final LocationSettings settings;
if (defaultTargetPlatform == TargetPlatform.iOS) {
  settings = AppleSettings(
    accuracy: LocationAccuracy.best,
    activityType: ActivityType.automotiveNavigation,
    distanceFilter: 0,           // time-throttle only, same as Android path
    pauseLocationUpdatesAutomatically: false,
    showBackgroundLocationIndicator: true,
    allowBackgroundLocationUpdates: true,
  );
} else {
  settings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    intervalDuration: kTrackingSampleInterval,
  );
}
```

**What does NOT change:**
- `TripAccumulator` — pure Dart, zero platform awareness, unchanged.
- `TrackingServiceController` — unchanged. On iOS, `_service.startService()` starts the `flutter_background_service` isolate in foreground mode; the isolate opens the CLLocationManager stream via `AppleSettings` and remains alive because CLLocationManager holds the process.
- `TrackingNotificationService` — `DarwinInitializationSettings` and `DarwinNotificationDetails` are already wired in the existing code (confirmed in source). iOS just starts using them.
- `TrackingPermissionService` — `Permission.locationWhenInUse`, `Permission.locationAlways`, and `Permission.notification` are cross-platform. The permission dance works identically on iOS; only the UI copy changes (see iOS Pitfalls).
- Riverpod providers, Drift DAOs, sync engine, auth service — all unchanged.

**What DOES change (tracking-specific Dart):**
- `tracking_service.dart`: add `geolocator_apple` import + the `defaultTargetPlatform` branch above.
- `configureBackgroundService()` in the same file: `IosConfiguration` already has `autoStart: false` — add `onForeground: trackingServiceOnStart` to wire the same entrypoint for iOS.

```dart
// Updated IosConfiguration in configureBackgroundService()
iosConfiguration: IosConfiguration(
  autoStart: false,
  onForeground: trackingServiceOnStart,  // ADD THIS
),
```

**Why this works on iOS:** The `flutter_background_service` isolate runs as the `onForeground` handler. The isolate opens `AppleSettings(allowBackgroundLocationUpdates: true)`, which sets `CLLocationManager.allowsBackgroundLocationUpdates = true`. iOS will not suspend the process while CLLocationManager is actively delivering updates with this flag set. The app receives continuous GPS fixes for the duration of the recording session, regardless of whether the user is looking at the app.

**The notification difference on iOS:** Android requires `flutter_background_service`'s foreground service notification (the D-14 unification contract) to keep the process alive. iOS does not — CLLocationManager alone is sufficient. The notification is still shown on iOS (via `DarwinNotificationDetails`) as a user-facing tracking indicator, but it is not the keep-alive mechanism.

---

## Component Map: New vs Modified vs Unchanged

### New components required for iOS

| Component | Location | What it is |
|-----------|----------|------------|
| `ios/` folder | Project root | Generated by `flutter create . --platforms ios` |
| `ios/Runner/Info.plist` | iOS project | All required keys (see section below) |
| `ios/Runner/Runner.entitlements` | iOS project | Keychain Sharing entitlement |
| `ios/Runner/DebugProfile.entitlements` | iOS project | Keychain Sharing entitlement (debug) |
| `ios/Runner/GoogleService-Info.plist` | iOS project | Firebase iOS app config (download from Firebase Console) |
| `ios/Podfile` | iOS project | Platform target + permission_handler + geolocator macros |
| `flutter_launcher_icons` update | `pubspec.yaml` | Set `ios: true` to generate app icons for iOS |

### Modified Dart files (minimal)

| File | Change |
|------|--------|
| `lib/features/tracking/services/tracking_service.dart` | Add `defaultTargetPlatform` branch for `AppleSettings`; add `onForeground: trackingServiceOnStart` to `IosConfiguration` |
| `lib/notifications/notification_service.dart` | Add `DarwinInitializationSettings` to `NotificationService.initialize()` (weekly summary + reminder channels). The tracking notification service already has this. |
| `pubspec.yaml` | Set `flutter_launcher_icons.ios: true` |

### Unchanged Dart (confirmed from source reading)

- All Riverpod providers
- `TripAccumulator` (pure Dart)
- `TrackingServiceController`
- `TrackingPermissionService`
- `TrackingNotificationService` (Darwin settings already present)
- All Drift tables, DAOs, database class
- Sync engine + API client
- Auth service + auth providers
- All feature screens, widgets
- `firebase_options.dart` (iOS block already present with `iosClientId` and `iosBundleId`)

---

## Required Info.plist Keys

These keys go in `ios/Runner/Info.plist`. Every key listed below is load-bearing — the app will be rejected by the OS or crash silently if any are missing.

### Location permissions

```xml
<!-- Required for foreground location (tracking screen visible) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Traevy records your commute route to calculate time moving and time stuck in traffic.</string>

<!-- Required for background GPS (CLLocationManager allowsBackgroundLocationUpdates) -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Traevy continues recording your commute in the background so you can keep using your phone normally while tracking.</string>

<!-- Required on iOS 16+ for getPositionStream to deliver background updates -->
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
```

### Google Sign-In (OAuth return URL)

Values come from `GoogleService-Info.plist`. The `REVERSED_CLIENT_ID` is derived from the `iosClientId` in `firebase_options.dart` (`1076279794226-6h24q245801r9pca45v2e2tpjiocde64.apps.googleusercontent.com`). Reversed: `com.googleusercontent.apps.1076279794226-6h24q245801r9pca45v2e2tpjiocde64`.

```xml
<!-- iOS OAuth 2.0 client ID for Google Sign-In -->
<key>GIDClientID</key>
<string>1076279794226-6h24q245801r9pca45v2e2tpjiocde64.apps.googleusercontent.com</string>

<!-- OAuth callback URL scheme — REVERSED_CLIENT_ID from GoogleService-Info.plist -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.1076279794226-6h24q245801r9pca45v2e2tpjiocde64</string>
    </array>
  </dict>
</array>
```

### Notifications (flutter_local_notifications)

iOS requires explicit user permission for notifications. No Info.plist key is needed for basic notification permissions (those are requested at runtime), but the usage description is required if the app ever accesses notification settings. The `TrackingNotificationService` already sets `requestAlertPermission: false` in `DarwinInitializationSettings`, deferring to the `TrackingPermissionService.preflight()` flow — this is the correct approach.

---

## Required Entitlements

### `ios/Runner/DebugProfile.entitlements` and `ios/Runner/Release.entitlements`

Both files must include the Keychain Sharing entitlement for `flutter_secure_storage` to write to iOS Keychain. Without this, writes appear to succeed but values are never actually stored.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>keychain-access-groups</key>
  <array/>
</dict>
</plist>
```

This must also be registered in Xcode: Runner target → Signing & Capabilities → + Capability → Keychain Sharing. Adding the empty `<array/>` means no group sharing (single-app keychain), which is correct for this app.

---

## Podfile Configuration

`ios/Podfile` must set the platform version and enable the correct permission macros for `permission_handler` and `geolocator_apple`. Both packages use GCC preprocessor definitions to compile only the permission groups the app actually uses.

```ruby
platform :ios, '14.0'

# Required for flutter_local_notifications and other plugins
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end
  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig and running flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    target.build_configurations.each do |config|
      # permission_handler: enable only the permissions this app uses.
      # Compile out everything else to avoid App Store binary analysis flags.
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_LOCATION=1',             # locationWhenInUse + locationAlways
        'PERMISSION_LOCATION_WHENINUSE=0',   # don't enable the separate when-in-use macro
        'PERMISSION_NOTIFICATIONS=1',        # flutter_local_notifications permission
      ]

      # geolocator_apple: bypass the NSLocationAlwaysAndWhenInUseUsageDescription
      # requirement at compile time. The key IS present in Info.plist (required
      # at runtime), but this flag prevents a compile-time linker error on
      # the simulator build path where Always permission is unavailable.
      if target.name == "geolocator_apple"
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
          '$(inherited)',
          'BYPASS_PERMISSION_LOCATION_ALWAYS=1',
        ]
      end
    end
  end
end
```

**Platform target rationale:** `platform :ios, '14.0'` is required because `google_maps_flutter_ios` dropped iOS 12/13 support (App Store privacy manifest requirement). `flutter_map` has no explicit floor but transitively pulls packages that require 14.0. Setting 14.0 is safe — iOS 14 was released in 2020 and covers all devices that can run iOS 17/18.

---

## AppDelegate / Runner Changes

`flutter create . --platforms ios` generates `ios/Runner/AppDelegate.swift` with the standard FlutterAppDelegate boilerplate. No custom AppDelegate code is required for this app:

- `firebase_auth` + `google_sign_in` handle their own URL scheme interception via `GIDSignIn.sharedInstance.handle(_:)` internally through the FlutterPlugin protocol.
- `flutter_background_service` registers its own plugin.
- `flutter_local_notifications` registers its own plugin.

The generated AppDelegate looks like:

```swift
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

This is sufficient. **Do not add manual GIDSignIn setup** — `google_sign_in_ios` v6+ handles this automatically through the plugin registration path.

### ~~MethodChannel `traevy/tracking` (savePendingTrip)~~ — REMOVED 2026-07-20

> **This channel no longer exists.** Removed in `ef4d03e`; see BACKLOG item 999.2.
> The section below is retained only because it explains a trap worth not
> re-entering.

The original text read: *"`tracking_service.dart` contains a
`MethodChannel('traevy/tracking')` call for `savePendingTrip` — an Android
platform channel call made inside the service isolate. On iOS this call will
throw and be caught by the surrounding `on Object` block… the worst case is that
a force-killed trip is lost."*

Two things were wrong with that. It threw on **Android** too — no native handler
for the channel was ever registered anywhere in `android/`, so every stop hit
`MissingPluginException` and the recovery never ran on any platform. And the
"worst case" was not contained: `TripAccumulator.finalize()` clears
`active_trip.json` immediately before that call, so both recovery paths were
down simultaneously.

**Replaced by** `PendingTripStore` (`lib/features/tracking/services/pending_trip_store.dart`)
— a plain `dart:io` file with an atomic temp-file + rename write.

**Note for the iOS port:** a MethodChannel registered in
`MainActivity.configureFlutterEngine` (or the iOS equivalent) would NOT have
worked, because the call originates in the `flutter_background_service` isolate,
which runs its own `FlutterEngine`. The file-based store has no such problem and
is platform-neutral — it would work on iOS unchanged. It is currently wired only
on the Android path; iOS still loses a force-killed trip (see the table below).

---

## Xcode Capabilities Required

These must be enabled manually in Xcode after `flutter create` generates the `ios/` folder:

| Capability | Where | Why |
|-----------|-------|-----|
| Background Modes → Location updates | Runner target → Signing & Capabilities | Required for `UIBackgroundModes location` to take effect at runtime; Info.plist entry alone is insufficient |
| Keychain Sharing (empty group) | Runner target → Signing & Capabilities | Required for `flutter_secure_storage` to write to Keychain |

Both capabilities write back to the entitlements files, so once added in Xcode they are committed to the repo.

---

## `geolocator_apple` Dependency

The `geolocator` package uses a federated plugin architecture. `geolocator_apple` is the iOS/macOS implementation pod and is NOT listed in `pubspec.yaml` — CocoaPods resolves it automatically as a transitive dependency of `geolocator ^14.0.2`. No `pubspec.yaml` change is needed. The `geolocator_apple` pod will appear in `Podfile.lock` after the first `pod install`.

The `AppleSettings` class lives in `package:geolocator_apple/geolocator_apple.dart`. Add this import alongside the existing `package:geolocator_android/geolocator_android.dart` usage in `tracking_service.dart`.

---

## Notifications on iOS: What Changes

### Active tracking notification (UX-03)

`TrackingNotificationService` already initializes with `DarwinInitializationSettings` (source confirmed). On iOS:
- There is no persistent "foreground service" notification in the Android sense. The notification is shown via `flutter_local_notifications` `show()` as a regular notification.
- iOS will display it in the lock screen and notification centre while the app is running. It will not appear as an always-visible banner like Android's ongoing notification.
- The OPEN and STOP action buttons in `DarwinNotificationCategory` are already registered with `DarwinNotificationActionOption.foreground` — they will appear when the notification is expanded on iOS 15+ (long-press the notification).
- No Dart changes required.

### Weekly summary + reminder notifications

`NotificationService.initialize()` currently creates only Android notification channels. It must also initialize with `DarwinInitializationSettings` for iOS. Modify `NotificationService.initialize()` to pass `DarwinInitializationSettings(requestAlertPermission: false, ...)` alongside the existing Android init settings — same pattern as `TrackingNotificationService`.

### Notification permission on iOS

On iOS, `Permission.notification` maps to `UNUserNotificationCenter.requestAuthorization`. The `TrackingPermissionService.preflight()` flow calls `Permission.notification.request()` — this will trigger the iOS system permission dialog. No code change required; the cross-platform `permission_handler` abstraction handles both platforms.

---

## Firebase Auth + Google Sign-In on iOS

The `firebase_options.dart` file already has the `ios` block with the correct `iosClientId` and `iosBundleId: 'com.travey.app'`. Steps required:

1. Download `GoogleService-Info.plist` from Firebase Console → Project Settings → iOS app (`com.travey.app`). Place it at `ios/Runner/GoogleService-Info.plist`. Drag it into the Xcode Runner group so it is included in the build.
2. Add `GIDClientID` and `CFBundleURLSchemes` to `Info.plist` as shown above.
3. The `firebase_auth` and `google_sign_in` packages handle the rest automatically via `GeneratedPluginRegistrant`.

The `GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId)` call in `main.dart` already runs on iOS — `kGoogleServerClientId` is the Web client ID which is required for Firebase ID token issuance on both platforms.

---

## System Architecture Diagram (iOS-Aware)

```
┌──────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  (unchanged — all screens, widgets, Riverpod providers)      │
└─────────────────────────┬────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────┐
│                    SERVICE LAYER                              │
│                                                              │
│  TrackingServiceController  ←──── unchanged                  │
│  TrackingNotificationService ←─── unchanged (Darwin already) │
│  TrackingPermissionService  ←──── unchanged (cross-platform) │
│  AuthService                ←──── unchanged                  │
│  NotificationService        ←──── add DarwinInitSettings     │
└─────────────────────────┬────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────┐
│           BACKGROUND ISOLATE (flutter_background_service)    │
│                                                              │
│  trackingServiceOnStart()  ←── iOS: add onForeground wiring  │
│                                                              │
│  LocationSettings (SEAM)                                     │
│  ┌──────────────────────────────────┐                        │
│  │ Android: AndroidSettings(        │                        │
│  │   accuracy: high,                │                        │
│  │   intervalDuration: 3s           │                        │
│  │ )                                │                        │
│  │ iOS: AppleSettings(              │                        │
│  │   accuracy: best,                │                        │
│  │   activityType: automotive,      │                        │
│  │   allowBackgroundLocationUpdates │  ← keep-alive on iOS   │
│  │   pauseAuto: false,              │                        │
│  │   showBgIndicator: true          │                        │
│  │ )                                │                        │
│  └──────────────────────────────────┘                        │
│                                                              │
│  Geolocator.getPositionStream(settings)                      │
│       │                                                      │
│       ▼                                                      │
│  TripAccumulator  ←── unchanged (pure Dart)                  │
│       │                                                      │
│       ▼                                                      │
│  service.invoke(kTripFinalizedEvent, trip.toMap())            │
└─────────────────────────┬────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────┐
│                    DATA LAYER                                 │
│  Drift (SQLite) ←── unchanged, single source of truth        │
│  SyncEngine + ApiClient ←── unchanged                        │
└──────────────────────────────────────────────────────────────┘
                          │
              ┌───────────▼───────────┐
              │   Firebase Backend    │
              │  (unchanged — same    │
              │   3 Cloud Functions)  │
              └───────────────────────┘
```

---

## Recommended Build Order for iOS Port

Each phase has a dependency-ordered rationale. Do not skip steps — each unblocks the next.

### Phase A: Scaffold (prerequisite for everything)

1. Run `flutter create . --platforms ios` in project root. This generates `ios/` with `Runner.xcodeproj`, `Podfile`, `Info.plist`, entitlements files, and `AppDelegate.swift`.
2. Set bundle ID to `com.travey.app` in Xcode (must match `firebase_options.dart`'s `iosBundleId`).
3. Set iOS deployment target to 14.0 in Xcode and update `Podfile` to `platform :ios, '14.0'`.
4. Add Background Modes → Location Updates capability in Xcode.
5. Add Keychain Sharing capability (empty group) in Xcode.
6. Set `flutter_launcher_icons.ios: true` in `pubspec.yaml` and run `dart run flutter_launcher_icons`.
7. Run `flutter build ios --simulator` to verify the project compiles clean.

**Dependency rationale:** Nothing else can be tested until the `ios/` folder exists and compiles.

### Phase B: Permissions and Info.plist

1. Add the four location keys to `Info.plist` (`NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes location`).
2. Add Google Sign-In keys (`GIDClientID`, `CFBundleURLTypes`/`CFBundleURLSchemes` with REVERSED_CLIENT_ID).
3. Add Keychain entitlements to both entitlements files.
4. Update `Podfile` with the `permission_handler` GCC macros and `geolocator_apple` `BYPASS_PERMISSION_LOCATION_ALWAYS=1` macro.
5. Run `pod install` inside `ios/` to resolve all CocoaPods dependencies.

**Dependency rationale:** Auth (Phase C) will crash on launch without the CFBundleURLSchemes entry. GPS (Phase D) will silently fail without the location Info.plist keys. Keychain (required by secure storage) will silently drop writes without the entitlement.

### Phase C: Auth (Google Sign-In + Firebase)

1. Download `GoogleService-Info.plist` from Firebase Console and add to `ios/Runner/` (drag into Xcode's Runner group).
2. Verify `firebase_options.dart` has the correct `ios` block (it does — confirmed from source).
3. Run the app on a simulator. Confirm `Firebase.initializeApp` succeeds and `firebaseReady = true`.
4. Test the Google Sign-In flow on a real device (simulator cannot complete Google OAuth).
5. Verify `flutter_secure_storage` writes and reads back the Firebase ID token (Keychain entitlement validation).

**Dependency rationale:** Auth must work before sync can be tested. `AuthService` and `AuthStateNotifier` are entirely cross-platform; only the platform plumbing (Info.plist + GoogleService-Info.plist) was missing.

### Phase D: Background GPS (tracking feature)

1. In `tracking_service.dart`: add `geolocator_apple` import and the `defaultTargetPlatform` branch that constructs `AppleSettings`.
2. In `configureBackgroundService()`: add `onForeground: trackingServiceOnStart` to `IosConfiguration`.
3. Run on a real iPhone (not simulator — GPS simulation is unreliable for speed calculations).
4. Tap Start, background the app, walk/drive for 2+ minutes, tap Stop from notification action.
5. Verify `TripAccumulator` finalized the trip with non-zero `distanceMeters`, `timeMovingSeconds`, `timeStuckSeconds`.
6. Verify the blue background location indicator appears in the iOS status bar during recording.

**Dependency rationale:** GPS requires the `UIBackgroundModes location` Info.plist key (Phase B) and real device testing. `TripAccumulator` is unchanged — only the `LocationSettings` seam changes.

**Critical test:** Background the app immediately after tapping Start. If the GPS stream stops delivering samples within ~30 seconds, the `allowBackgroundLocationUpdates` flag is not taking effect. Check that the Xcode Background Modes capability was added (Xcode UI, not just Info.plist).

### Phase E: Notifications

1. Verify the active tracking notification appears on iOS when tracking starts (no code change needed — `TrackingNotificationService` is already cross-platform).
2. Modify `NotificationService.initialize()` to add `DarwinInitializationSettings` alongside the Android init.
3. Test weekly summary notification scheduling on iOS (use a short interval for manual QA).
4. Test commute reminder notification on iOS.
5. Verify that tapping a notification action (STOP button) while the app is backgrounded calls `FlutterBackgroundService().invoke(kStopTrackingEvent)` and the trip is finalized.

**Dependency rationale:** Notifications require the notification permission, which is requested during the `TrackingPermissionService.preflight()` flow (already cross-platform). The notification channels are a no-op on iOS (iOS does not have channel concepts), but the `flutter_local_notifications` API handles this silently.

### Phase F: Maps and Trip Detail

1. Verify `flutter_map` renders on iOS (it is a pure-Dart tile renderer — no native Maps SDK dependency).
2. Verify CARTO tile URLs (`kMapTileUrlDark`, `kMapTileUrlLight`) load on iOS. iOS enforces ATS (App Transport Security) for HTTP connections — CARTO tiles are HTTPS, so this should work without an `NSAppTransportSecurity` exception.
3. Verify `flutter_svg` renders SVG assets (Google logo in sign-in button).

**Dependency rationale:** Maps are display-only and depend on network (tile loading). No code changes expected.

### Phase G: Sync Verification

1. Record a trip on iOS and verify sync queue entry is created in Drift.
2. Verify the sync engine fires (connectivity-aware trigger already cross-platform).
3. Verify the Firebase Cloud Function accepts the Firebase ID token minted by the iOS client.
4. Verify the restore flow downloads and inserts trips.

**Dependency rationale:** Sync depends on auth (Phase C) working. The `ApiClient` and `SyncEngine` are pure Dart — no platform changes expected.

### Phase H: Polish and Device QA

1. Test permission denial flows on iOS (permanently denied location = show settings CTA; works via `openAppSettings()` from `permission_handler` which calls `UIApplication.openURL` on iOS).
2. Test dark mode toggle (system, light, dark) — `ThemeData` is cross-platform.
3. Test that the short-trip discard path (< 30s or < 100m) works correctly on iOS.
4. Test the manual entry form.
5. Test calendar view and trip history.

---

## Key Differences Between iOS and Android Tracking

| Concern | Android | iOS |
|---------|---------|-----|
| Keep-alive mechanism | `flutter_background_service` foreground service + Android notification | `CLLocationManager.allowsBackgroundLocationUpdates = true` (no service needed) |
| Notification style | Persistent ongoing notification (mandatory for foreground service) | Regular notification shown during session; not ongoing |
| Permission model | `locationWhenInUse` → `locationAlways` → `notification` (3-step sequential) | Same sequence; iOS shows a separate "Always" confirmation later |
| GPS settings class | `AndroidSettings(intervalDuration: 3s)` | `AppleSettings(activityType: automotive, allowBackgroundLocationUpdates: true)` |
| Speed value unit | `Position.speed` in m/s (same) | `Position.speed` in m/s (same) — `TripAccumulator` unchanged |
| Accuracy filter | `kTrackingMaxAcceptableAccuracyMeters = 30` (same) | Same constant applies — `TripAccumulator` unchanged |
| Background process | `flutter_background_service` isolate (Android foreground service type = location) | `flutter_background_service` isolate (onForeground, kept alive by CLLocationManager) |
| Force-stop recovery | `PendingTripStore` — `pending_trip.json` via `dart:io` (was a dead MethodChannel until `ef4d03e`) | Not wired on iOS; trip still lost on force-stop (acceptable for v0.2). The store is platform-neutral, so enabling it is cheap if this becomes unacceptable. |

---

## Pitfalls Specific to This Port

### 1. Missing Xcode capability vs Info.plist-only entry

Adding `UIBackgroundModes location` to Info.plist is not sufficient. Xcode must also have the Background Modes → Location Updates capability enabled on the Runner target. Without the Xcode capability, iOS ignores the Info.plist key. This is a silent failure — the stream opens but stops delivering samples ~30 seconds after backgrounding.

### 2. `AppleSettings` import is from `geolocator_apple`, not `geolocator`

The `AppleSettings` class lives in `package:geolocator_apple/geolocator_apple.dart`. Using `package:geolocator/geolocator.dart` alone will result in a compile error on the import-free reference. The `geolocator_apple` pod is automatically resolved by CocoaPods but the Dart import must be explicit. Use `defaultTargetPlatform == TargetPlatform.iOS` guards around the import, or import it unconditionally (the Dart-side class has no platform channel calls — it is safe on Android at the type level, the platform channel call fails gracefully).

### 3. Keychain Sharing entitlement missing = silent token write failure

`flutter_secure_storage` on iOS writes to the Keychain via `SecItemAdd`. Without the `keychain-access-groups` entitlement, `SecItemAdd` returns `errSecMissingEntitlement (-34018)`. The Dart API returns without error. The next `read()` call returns `null`. This causes auth to break silently — the user appears signed out on every app restart. Fix: add the Keychain Sharing capability in Xcode and commit the updated entitlements files.

### 4. GoogleService-Info.plist must be in Xcode's file list

Placing `GoogleService-Info.plist` in the filesystem at `ios/Runner/` is not enough. It must be dragged into the Xcode Runner group so the build system includes it in the app bundle. If it is only on the filesystem, `Firebase.initializeApp` will fail with "GoogleService-Info.plist not found". Use Xcode's file navigator drag-and-drop — do not edit `project.pbxproj` manually.

### 5. `permission_handler` always and when-in-use ordering on iOS

iOS 13+ changed the behavior of `locationAlways` requests. If `NSLocationAlwaysAndWhenInUseUsageDescription` is absent from Info.plist, the `locationAlways` request silently downgrades to `whenInUse` without showing an error. The existing `TrackingPermissionService` already handles the case where `locationAlways` is denied (returns `foregroundOnly`), but the silent downgrade means the user never sees the "Always" dialog if the key is missing. Always include both description keys.

### 6. `flutter_background_service` `onForeground` is not the Android foreground service

On iOS, `flutter_background_service`'s `onForeground` callback runs the Dart isolate while the app is in the foreground UI sense (not a background process). The CLLocationManager with `allowBackgroundLocationUpdates: true` is what keeps the process alive. If the user force-quits the app (swipes up in the app switcher), the CLLocationManager session ends and the trip is lost — same behavior as Android force-quit. There is no equivalent of Android's `autoStartOnBoot` on iOS for this use case.

---

## Sources

- `lib/features/tracking/services/tracking_service.dart` — source read, confirmed Android-only `AndroidSettings` usage and `IosConfiguration(autoStart: false)` stub (HIGH confidence)
- `lib/features/tracking/services/tracking_notification_service.dart` — source read, confirmed `DarwinInitializationSettings` already wired (HIGH confidence)
- `lib/features/tracking/services/tracking_permission_service.dart` — source read, confirmed cross-platform `permission_handler` usage (HIGH confidence)
- `lib/firebase_options.dart` — source read, confirmed `ios` block present with `iosClientId` and `iosBundleId: 'com.travey.app'` (HIGH confidence)
- Context7 `/baseflow/flutter-geolocator` — `AppleSettings` API, `UIBackgroundModes location` requirement, `BYPASS_PERMISSION_LOCATION_ALWAYS` Podfile macro (HIGH confidence)
- Context7 `/ekasetiawans/flutter_background_service` — iOS limitation quote ("iOS doesn't have a long running service"), `IosConfiguration.onForeground` / `onBackground` semantics (HIGH confidence)
- Context7 `/websites/pub_dev_permission_handler` — `permission_handler` iOS Podfile GCC macros, `PERMISSION_LOCATION=1` (HIGH confidence)
- Context7 `/websites/pub_dev_flutter_local_notifications` — `DarwinInitializationSettings` constructor (HIGH confidence)
- `pub.dev/packages/flutter_secure_storage` — Keychain Sharing entitlement requirement, silent failure without it (HIGH confidence)
- `pub.dev/packages/google_sign_in_ios` — `GIDClientID` Info.plist key, `CFBundleURLSchemes`/`REVERSED_CLIENT_ID` setup (HIGH confidence)
- Apple Developer Documentation (CLLocationManager `allowsBackgroundLocationUpdates`) — process-level keep-alive behavior when background updates enabled (MEDIUM confidence — fetched via secondary source summary)
- `google_maps_flutter_ios` iOS 14 platform minimum — confirmed via WebSearch (MEDIUM confidence)

*No git commit — written per task instructions.*
