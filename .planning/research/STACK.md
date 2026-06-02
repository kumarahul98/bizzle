# Technology Stack — iOS Port (v0.2)

**Project:** Commute Tracker — iOS Support Milestone
**Researched:** 2026-06-02
**Scope:** What stack/config changes are needed to run the existing Flutter Android app on iOS with full feature parity. New product features are explicitly out of scope.
**Overall Confidence:** HIGH for the critical background-GPS question; HIGH for auth/maps/notifications config; MEDIUM for CocoaPods minimum version (derived from highest-requiring dependency).

---

## Critical Decision: Background GPS on iOS

### Verdict: Drop flutter_background_service for iOS GPS. Use geolocator's native AppleSettings.

**flutter_background_service ^5.1 does NOT support continuous background GPS on iOS.**

The plugin's own README states it directly: "iOS does not support long-running services in the background like Android. Applications are suspended by the OS. The onBackground method can be executed periodically via iOS's Background Fetch capability, with limitations of execution speed (no faster than 15 minutes) and duration (15-30 seconds)." (Source: Context7/ekasetiawans/flutter_background_service — HIGH confidence.)

The existing `tracking_service.dart` already reflects this limitation: `IosConfiguration(autoStart: false)` is set and the position stream uses `AndroidSettings(...)` exclusively. The service will do nothing useful on iOS as written.

**What to use instead for iOS:** `geolocator`'s native `AppleSettings` with `allowBackgroundLocationUpdates: true` and `pauseLocationUpdatesAutomatically: false`. Geolocator uses CoreLocation's `CLLocationManager` under the hood. When the app is backgrounded, iOS keeps the location stream alive via the `UIBackgroundModes → location` capability — no separate background isolate is needed. This is the standard Apple-blessed pattern for navigation and tracking apps. (Source: Context7/baseflow/flutter-geolocator + Apple developer docs — HIGH confidence.)

`flutter_background_service` is still needed in pubspec.yaml for the Android path — it must not be removed. The tracking service code must be made platform-conditional.

---

## Packages: iOS Compatibility Status

All packages currently in pubspec.yaml are iOS-compatible with the changes noted below. No package swaps are needed.

| Package | Current Version | iOS Compatible? | Change Required |
|---------|-----------------|-----------------|-----------------|
| geolocator | ^14.0.2 | YES | Add `AppleSettings` branch in `tracking_service.dart`; add `geolocator_apple` transitive dep is automatic |
| flutter_background_service | ^5.1.0 | PARTIAL — Android-only for GPS; iOS config stays as `autoStart: false` | No version change; code must guard `Platform.isAndroid` around the `AndroidSettings` + service start path |
| firebase_core | ^4.9.0 | YES | Podfile platform line must be iOS 13.0+ (firebase_core pulls FirebaseCoreOnly which requires iOS 13) |
| firebase_auth | ^6.5.1 | YES | No code change; `DefaultFirebaseOptions.currentPlatform` already returns the iOS options from `firebase_options.dart` |
| google_sign_in | ^7.2.0 | YES | iOS URL scheme required in `Info.plist` (see Auth section below); optionally pass `clientId: DefaultFirebaseOptions.currentPlatform.iosClientId` in Dart |
| flutter_local_notifications | ^21.0.0 | YES | iOS initialization requires `DarwinInitializationSettings`; permission must be explicitly requested; AppDelegate UNUserNotificationCenter delegate setup needed |
| flutter_secure_storage | ^10.3.1 | YES — uses Keychain natively | Keychain Sharing capability must be enabled; entitlements files must include `keychain-access-groups` key |
| flutter_map | ^8.1.0 | YES | Pure Dart, no native setup |
| flutter_map_tile_caching | ^10.1.1 | YES | Pure Dart with Drift (SQLite) backend, no native iOS deps |
| drift / drift_flutter | ^2.32.1 / ^0.3.0 | YES | Platform-agnostic SQLite via sqlite3_flutter_libs |
| flutter_riverpod | ^3.3.1 | YES | Platform-agnostic |
| connectivity_plus | ^7.1.1 | YES | No config change needed |
| permission_handler | ^12.0.1 | YES | Podfile `post_install` macro `PERMISSION_LOCATION=1` required; Info.plist keys required |
| fl_chart | ^1.2.0 | YES | Pure Dart |
| http | ^1.6.0 | YES | Platform-agnostic |
| uuid, intl, latlong2, path_provider, table_calendar, timezone, google_fonts, flutter_svg, cupertino_icons | all current | YES | No iOS-specific config needed |

**Not in pubspec.yaml — NOT needed for this milestone:**
- `google_maps_flutter` (the app uses `flutter_map` + OpenStreetMap, not Google Maps — confirmed from pubspec). The `google_maps_flutter` iOS API key setup documented in CLAUDE.md is irrelevant to this codebase.

---

## iOS Scaffolding

The `ios/` directory does not exist. Generate it:

```bash
# Run from the project root (same directory as pubspec.yaml)
flutter create --platforms=ios .
```

This scaffolds `ios/Runner/`, `ios/Runner.xcworkspace`, `Podfile`, `AppDelegate.swift`, `Info.plist`, and the two entitlements files. The `iosBundleId` already registered in Firebase is `com.travey.app` (from `firebase_options.dart`), so open `ios/Runner.xcodeproj` in Xcode and set the Bundle Identifier to `com.travey.app` before doing anything else.

---

## Podfile: Minimum iOS Deployment Target

Set `platform :ios, '14.0'` in `ios/Podfile`.

Rationale (highest minimum wins):
- `firebase_core` / `firebase_auth`: iOS 13.0 minimum (FirebaseCoreOnly pod requirement — confirmed via web search and Codemagic discussion thread)
- `google_maps_flutter_ios`: iOS 14.0 minimum (confirmed via pub.dev and multiple Flutter GitHub issues)
- `geolocator_apple`: iOS 11.0 minimum
- `flutter_local_notifications`: iOS 10.0 minimum (some features iOS 12+)
- `flutter_secure_storage`: iOS 12.0 minimum
- `permission_handler`: iOS 11.0 minimum
- `flutter_map_tile_caching`: iOS 12.0 minimum (Drift/SQLite dependency)

The binding constraint is `google_maps_flutter_ios` at iOS 14. However, this project uses `flutter_map` (not `google_maps_flutter`), so the binding constraint drops to Firebase at iOS 13. Setting iOS 14 is the safe recommendation: it covers all packages with headroom, `google_maps_flutter` is not used but may appear transitively via Firebase SDKs, and iOS 14+ covers ~95%+ of active iPhones as of 2026.

```ruby
# ios/Podfile — first non-comment line
platform :ios, '14.0'
```

The `post_install` block must include the `permission_handler` macro and the deployment-target fix:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      # Raise all pod targets to match the app minimum
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      # permission_handler: enable location (always + when-in-use)
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_LOCATION=1',
      ]
    end
  end
end
```

---

## Capability 1: Background GPS (geolocator + CoreLocation)

### What must change in `tracking_service.dart`

The existing service uses `AndroidSettings` for the position stream and `flutter_background_service` to keep the isolate alive. On iOS, both mechanisms must be replaced with `AppleSettings` and the native CoreLocation background mode — no background isolate is required.

The service file must become platform-conditional. The minimal change is a platform branch around the `LocationSettings` construction:

```dart
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';

LocationSettings _buildLocationSettings() {
  if (Platform.isAndroid) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      intervalDuration: kTrackingSampleInterval,
    );
  }
  // iOS: CoreLocation background mode keeps the stream alive without
  // a background isolate. pauseLocationUpdatesAutomatically: false
  // prevents CoreLocation from suspending updates on slow movement
  // (e.g. the user is actually stuck in traffic — exactly when we
  // need samples). activityType.automotiveNavigation gives CoreLocation
  // the best signal quality hint for car commutes.
  return AppleSettings(
    accuracy: LocationAccuracy.high,
    activityType: ActivityType.automotiveNavigation,
    pauseLocationUpdatesAutomatically: false,
    allowBackgroundLocationUpdates: true,
    showBackgroundLocationIndicator: true,
  );
}
```

The `AndroidServiceInstance.setAsForegroundService()` call must also be guarded (`if (service is AndroidServiceInstance)`), which is already the case in the existing code. The iOS path of `configureBackgroundService()` already has `IosConfiguration(autoStart: false)` — this is correct and must stay.

On iOS, `TrackingServiceController.start()` must NOT call `FlutterBackgroundService().startService()`. It should instead start the geolocator stream directly in the foreground isolate (or a Dart isolate) using `AppleSettings`. This is a code architecture decision for the phase, but the package configuration is correct.

### Info.plist keys (GPS)

```xml
<!-- Required for any location access -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Commute Tracker records your route while you travel to calculate time spent in traffic.</string>

<!-- Required for background location (UIBackgroundModes location triggers this check) -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Commute Tracker continues recording your route in the background so you can use other apps during your commute.</string>

<!-- Required for iOS 16+ background location stream -->
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
```

`NSLocationAlwaysUsageDescription` (the legacy pre-iOS 11 key) is NOT required — iOS 11+ uses `NSLocationAlwaysAndWhenInUseUsageDescription` only.

### Xcode capability

In Xcode: select the `Runner` target → `Signing & Capabilities` → `+ Capability` → `Background Modes` → tick `Location updates`. This writes `UIBackgroundModes` to `Info.plist`, but it is safer to add it manually in both places to ensure it survives regeneration.

### Entitlements

No special entitlement key is needed for background GPS (it is declared via `UIBackgroundModes`, not entitlements). The `com.apple.locationd.backgroundlocation` entitlement is managed internally by the OS when `UIBackgroundModes → location` is present.

---

## Capability 2: Google Sign-In + Firebase Auth

### `firebase_options.dart` — already correct

`DefaultFirebaseOptions.ios` is already populated with the iOS `apiKey`, `appId`, `iosClientId`, and `iosBundleId: 'com.travey.app'`. No code changes needed here.

### Two approaches for Google Sign-In iOS: choose the Dart-side clientId approach

**Approach A (recommended): pass `clientId` in Dart, no `GoogleService-Info.plist` in the Runner target.**

```dart
final googleSignIn = GoogleSignIn(
  clientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
  // iosClientId is: 1076279794226-6h24q245801r9pca45v2e2tpjiocde64.apps.googleusercontent.com
);
```

The URL scheme (reversed client ID) must still be in `Info.plist` so the OAuth callback can return to the app. See below.

**Approach B (not recommended):** Add `GoogleService-Info.plist` to the Xcode Runner target. This works, but duplicates the Firebase config that `firebase_options.dart` already provides via FlutterFire CLI. Approach A is cleaner for this project.

### Info.plist keys (Google Sign-In)

The reversed client ID URL scheme is mandatory regardless of which approach is used. The reversed form of `1076279794226-6h24q245801r9pca45v2e2tpjiocde64.apps.googleusercontent.com` is `com.googleusercontent.apps.1076279794226-6h24q245801r9pca45v2e2tpjiocde64`.

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Reversed iOS client ID — required for Google Sign-In OAuth callback -->
      <string>com.googleusercontent.apps.1076279794226-6h24q245801r9pca45v2e2tpjiocde64</string>
    </array>
  </dict>
</array>
```

Alternatively in Xcode: select the `Runner` target → `Info` tab → `URL Types` → add a new entry with the reversed client ID as the URL Scheme.

### AppDelegate.swift — URL handling

`google_sign_in_ios` requires the app delegate to forward OAuth callback URLs to `GIDSignIn`. Flutter's default `AppDelegate.swift` inherits from `FlutterAppDelegate` which handles `openURL:options:` automatically via the registered plugin. No manual `application(_:open:options:)` override is needed as long as `GeneratedPluginRegistrant.register(with: self)` is called (which the default scaffold does). (Source: Context7/google/googlesignin-ios — HIGH confidence.)

If the project opts into `UISceneDelegate` lifecycle (it should not for simplicity), URL handling must be added to the scene delegate instead. Stick with the standard `FlutterAppDelegate` scaffold.

---

## Capability 3: Local Notifications

### iOS initialization

The existing `NotificationService` must be updated to initialize with `DarwinInitializationSettings`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const darwinInit = DarwinInitializationSettings(
  requestAlertPermission: false,  // Defer to explicit request (better UX)
  requestSoundPermission: false,
  requestBadgePermission: false,
);

const initSettings = InitializationSettings(
  android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  iOS: darwinInit,
);

await flutterLocalNotificationsPlugin.initialize(initSettings);
```

Permission must be explicitly requested at the right moment (e.g., during onboarding after the user has seen value from the app, not at cold launch):

```dart
// iOS only — request at onboarding or first tracking completion
final iosPlugin = flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
await iosPlugin?.requestPermissions(
  alert: true,
  badge: true,
  sound: true,
);
```

### AppDelegate.swift — UNUserNotificationCenter delegate

Add to `application:didFinishLaunchingWithOptions:` in `AppDelegate.swift`:

```swift
import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required for flutter_local_notifications to receive foreground
    // notification events on iOS.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

`FlutterAppDelegate` already conforms to `UNUserNotificationCenterDelegate` in the Flutter SDK so the cast is safe. If the cast is rejected at compile time, set the delegate via `UNUserNotificationCenter.current().delegate = self` directly since `FlutterAppDelegate` already implements the protocol.

### Persistent tracking notification on iOS

The existing `TrackingNotificationService` shows a persistent "Recording..." notification via `flutter_local_notifications`. On iOS this works differently from Android: there is no foreground service concept, and iOS will show the notification in the notification centre but cannot guarantee it stays pinned. The banner will appear and the user can dismiss it. For this milestone (no App Store submission) this is acceptable.

`IOSNotificationDetails` options to use:

```dart
const iosDetails = DarwinNotificationDetails(
  presentAlert: true,
  presentSound: false,  // Silent for tracking notification
  presentBadge: false,
);
```

---

## Capability 4: Secure Storage (Keychain)

`flutter_secure_storage` uses iOS Keychain automatically — no code changes. Two configuration steps are required:

### Entitlements files

Add to BOTH `ios/Runner/DebugProfile.entitlements` AND `ios/Runner/Release.entitlements`:

```xml
<key>keychain-access-groups</key>
<array/>
```

An empty array is sufficient for a single-app Keychain group (no App Groups needed for this milestone).

### IOSOptions accessibility

For an auth token that must be available even after reboot (so the user does not have to re-authenticate every time the device restarts), use `first_unlock`:

```dart
const iOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock,
);
await storage.write(key: 'firebase_id_token', value: token, iOptions: iOptions);
```

`first_unlock` allows access after the first device unlock post-reboot, which is the correct choice for a background-capable app that may try to sync before the user opens it.

Do NOT use `useSecureEnclave: true` for this milestone — it requires Face ID/Touch ID and will fail on devices without biometrics.

---

## Capability 5: Maps (flutter_map)

`flutter_map` is pure Dart with no native platform code. No iOS-specific setup required. Tile fetching uses the `http` package over the network.

`flutter_map_tile_caching` uses Drift (SQLite) for its cache — also platform-agnostic.

Note: The original CLAUDE.md referenced `google_maps_flutter` and an `AppDelegate GMSServices.provideAPIKey()` call. This codebase uses `flutter_map` instead. The Google Maps iOS setup is NOT required and must not be added.

---

## AppDelegate.swift: Final Composite

The scaffolded `AppDelegate.swift` needs the `UNUserNotificationCenter` delegate line only. Google Sign-In URL handling is automatic via `FlutterAppDelegate`. There is no `GMSServices` call (no `google_maps_flutter`).

```swift
import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

## Info.plist: Complete Set of Keys Needed

Below is every key this milestone requires. Add to `ios/Runner/Info.plist` inside the top-level `<dict>`:

```xml
<!-- Location permissions -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Commute Tracker records your route while you travel to calculate time spent in traffic.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Commute Tracker continues recording your route in the background so you can use other apps during your commute.</string>

<!-- Background location mode (iOS 16+ requires this explicitly) -->
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>

<!-- Google Sign-In OAuth callback URL scheme -->
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

Keys that do NOT need to be added:
- `NSLocationAlwaysUsageDescription` — deprecated, iOS 10 only, not needed for iOS 11+
- `NSMotionUsageDescription` — not needed (CoreLocation handles motion internally for `activityType`)
- `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` — not used
- Any Firebase `GoogleService-Info.plist`-derived keys — handled programmatically via `DefaultFirebaseOptions`

---

## pubspec.yaml Changes

**No package version changes are required.** All current versions in pubspec.yaml are iOS-compatible.

One line in `flutter_launcher_icons` must be updated to generate an iOS icon:

```yaml
flutter_launcher_icons:
  android: true
  ios: true         # Change from false to true
  image_path: "assets/icons/logo.jpeg"
  min_sdk_android: 21
  adaptive_icon_background: "#000000"
  adaptive_icon_foreground: "assets/icons/logo.jpeg"
```

After running `dart run flutter_launcher_icons`, the generated icon set will populate `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

---

## Free Provisioning (7-Day) Constraints

Without an Apple Developer Program account, Xcode uses personal team signing with a 7-day certificate. Constraints:
- App must be re-signed every 7 days to run on the same device
- Maximum 3 apps per team with free provisioning
- Background modes (location) work on real devices with free provisioning
- Push notifications do NOT work with free provisioning — this affects weekly summary and reminder notifications. They can be triggered manually in testing but will not fire from background. Acceptable for this milestone since TestFlight/App Store is out of scope.
- The `com.travey.app` bundle ID must not already be registered to another team in the same Xcode installation

---

## Platform-Conditional Code: What Must Change

| File | Current State | Required Change |
|------|--------------|-----------------|
| `lib/features/tracking/services/tracking_service.dart` | Uses `AndroidSettings` + `setAsForegroundService()` exclusively | Add `_buildLocationSettings()` with `Platform.isAndroid ? AndroidSettings : AppleSettings`; guard service start with `Platform.isAndroid` |
| `lib/features/tracking/services/tracking_service_controller.dart` | Calls `FlutterBackgroundService().startService()` | Gate the background service start behind `Platform.isAndroid`; on iOS, start the geolocator stream directly in the UI or a separate Dart isolate |
| `lib/features/tracking/services/tracking_notification_service.dart` | Android foreground service notification | On iOS, show the notification via `flutter_local_notifications` as a standard notification (no `setAsForegroundService` equivalent) |
| `lib/notifications/notification_service.dart` | Android `AndroidInitializationSettings` only (likely) | Add `DarwinInitializationSettings` and `IOSFlutterLocalNotificationsPlugin.requestPermissions()` |
| `lib/features/auth/services/` (auth service) | `GoogleSignIn()` construction | Add `clientId: DefaultFirebaseOptions.currentPlatform.iosClientId` to `GoogleSignIn(...)` |

---

## Packages NOT Changed

`flutter_background_service` remains in pubspec.yaml and remains configured — it is still used for the Android path. The Android foreground service, `AndroidConfiguration`, and `kTrackingNotificationId` deduplication contract (D-14) are unchanged.

---

## Alternatives Considered

| Decision | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| iOS background GPS mechanism | geolocator `AppleSettings` + `UIBackgroundModes location` | `flutter_background_geolocation` (transistorsoft) | Paid license for production use; adds a new package dependency; overkill for a single trip-tracking use case that does not need post-termination location |
| iOS background GPS mechanism | geolocator `AppleSettings` | `flutter_background_service` on iOS | Explicitly unsupported for continuous location; iOS BGTaskScheduler fires at most every 15 min for 15-30 seconds — completely unsuitable for a 30-minute commute recording |
| Google Sign-In config | Dart-side `clientId` via `DefaultFirebaseOptions` | `GoogleService-Info.plist` in Runner target | Duplicates config already managed by FlutterFire CLI; error-prone to keep in sync |
| Map rendering | `flutter_map` (already in use) | `google_maps_flutter` | Not what this codebase uses; `google_maps_flutter` requires Maps SDK API key, `GMSServices.provideAPIKey` in AppDelegate, and iOS 14 minimum — all unnecessary complexity |

---

## Sources

- Context7 / ekasetiawans/flutter_background_service — iOS limitation quote direct from README (HIGH confidence)
- Context7 / baseflow/flutter-geolocator — `AppleSettings` constructor, `UIBackgroundModes`, permission keys (HIGH confidence)
- Context7 / juliansteenbakker/flutter_secure_storage — `IOSOptions`, `KeychainAccessibility`, entitlements (HIGH confidence)
- Context7 / google/googlesignin-ios — `handleURL`, `GIDConfiguration`, URL scheme (HIGH confidence)
- Context7 / websites/pub_dev_flutter_local_notifications — `DarwinInitializationSettings` constructor (HIGH confidence)
- pub.dev / google_maps_flutter_ios — iOS 14.0 minimum deployment target (HIGH confidence)
- pub.dev / flutter_local_notifications — v21.0.0 current, iOS 10+ base (HIGH confidence)
- pub.dev / geolocator — v14.0.2 verified current (HIGH confidence)
- pub.dev / flutter_secure_storage — v10.3.1 current (HIGH confidence)
- pub.dev / permission_handler — v12.0.3 current (HIGH confidence)
- Firebase GitHub issue #13114 + Codemagic discussion #2727 — firebase_auth iOS 13.0 minimum confirmed (MEDIUM confidence — multiple corroborating sources)
- `lib/features/tracking/services/tracking_service.dart` — read directly; confirms `AndroidSettings` usage and `IosConfiguration(autoStart: false)` (HIGH confidence — primary source)
- `lib/firebase_options.dart` — read directly; confirms `iosClientId` and `iosBundleId: 'com.travey.app'` (HIGH confidence — primary source)
