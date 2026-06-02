# Phase 12: iOS Scaffolding & Configuration — Research

**Researched:** 2026-06-02
**Domain:** iOS platform project generation, Xcode configuration, CocoaPods, Info.plist, entitlements, Firebase iOS setup
**Confidence:** HIGH — the prior milestone research (.planning/research/*.md) read all critical source files directly (firebase_options.dart, tracking_service.dart, notification services, pubspec.yaml). This document consolidates those findings into a Phase-12-scoped, plan-ready output. No re-derivation of decisions already locked.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| IOS-01 | App builds and launches on the iOS Simulator from a generated `ios/` project | `flutter create --platforms=ios .` scaffolds ios/; Podfile iOS 14.0 + post_install; `flutter build ios --simulator` is the verification command |
| IOS-02 | App installs and launches on a real iPhone via Xcode free (7-day) provisioning | Human-gated: requires Xcode license accepted, Apple ID signing in Xcode, Developer Mode on iPhone; Keychain Sharing entitlement must be present or token writes silently fail |
| IOS-03 | Info.plist and Xcode entitlements are fully configured — location usage strings, UIBackgroundModes: location, Keychain Sharing, notification usage, reversed-client-ID URL scheme, bundle ID com.travey.app | Complete key list documented; reversed-client-ID derived from firebase_options.dart iosClientId; both entitlements files require keychain-access-groups |
</phase_requirements>

---

## Summary

Phase 12 is a pure foundation phase: generate the `ios/` project folder that does not exist, then configure every platform prerequisite so that all subsequent iOS phases (13 through 16) start from a clean, compile-clean baseline. There is no Dart business logic in this phase. Every task is either a CLI command, a file edit, or a human-gated Xcode click.

The prior milestone research already resolved all ambiguities for this phase. The key facts are: the Firebase iOS app is already registered (`iosClientId` and `iosBundleId: 'com.travey.app'` confirmed in `firebase_options.dart`); all packages in `pubspec.yaml` are iOS-compatible at their current versions with zero version bumps required; `flutter_map` (OpenStreetMap) is already in use — no Google Maps iOS SDK setup is needed; the reversed client ID for the Google Sign-In URL scheme is derived mechanically from `iosClientId`; and the `TrackingNotificationService` already has `DarwinInitializationSettings` wired (confirmed from source), making it cross-platform from day one.

The one file that requires a non-trivial iOS-aware change in Phase 12 scope is `lib/notifications/notification_service.dart`: it initializes only with Android channels and has no Darwin init — this must be updated. Everything else in this phase is Xcode/CocoaPods/plist configuration.

**Primary recommendation:** Run `flutter create --platforms=ios .`, then execute all configuration steps in dependency order: bundle ID → Podfile → Xcode capabilities → Info.plist → entitlements → GoogleService-Info.plist → launcher icons → NotificationService Darwin init → verify with `flutter build ios --simulator`.

---

## Project Constraints (from CLAUDE.md)

These directives are binding for this phase:

- **No hardcoded strings:** All thresholds, labels, durations, and config values go in `lib/config/constants.dart`. Any new constants for iOS (notification category IDs, usage description strings used in code) follow this rule.
- **No dynamic types:** Dart 3 null safety throughout — any new Dart code in this phase uses explicit types.
- **Read before writing:** Read each file before modifying (tracking_service.dart already has `IosConfiguration(autoStart: false)` — leave it alone in this phase).
- **One module, one concern per commit:** Each commit is prefixed `[infra]` for scaffolding/config, `[ios]` is also acceptable.
- **Follow existing patterns:** `sealed` classes, Riverpod for state — no new state patterns introduced in this phase (there is no new state in this phase).
- **flutter_map not google_maps_flutter:** CLAUDE.md mentions Google Maps but the actual codebase uses `flutter_map`. Do NOT add `GMSServices.provideAPIKey()` or Google Maps iOS SDK setup.
- **Never use cloud_firestore in Flutter client:** Confirmed — all backend calls are REST via HTTPS Cloud Functions. No change.
- **Auth tokens in flutter_secure_storage:** Requires Keychain Sharing entitlement — this is a Phase 12 deliverable.
- **GSD workflow:** All edits go through GSD execution. No ad-hoc file changes outside a plan.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| iOS project generation | Build toolchain (flutter create) | — | One-time scaffold; generates all Xcode project files |
| Bundle ID configuration | Xcode project (Runner target) | Info.plist CFBundleIdentifier | Must match firebase_options.dart iosBundleId exactly |
| iOS deployment target | Podfile + Xcode Build Settings | post_install hook | Both must agree or linker errors result |
| Background Modes capability | Xcode capabilities UI | Info.plist UIBackgroundModes | Xcode capability sets the entitlement AND the plist; plist-only is insufficient |
| Keychain Sharing capability | Xcode capabilities UI | .entitlements files | Writes keychain-access-groups to both entitlements files |
| Info.plist keys | iOS project (ios/Runner/Info.plist) | — | Platform config only; no Dart involvement |
| GoogleService-Info.plist | Xcode project (Runner group) | Firebase Console download | Must be dragged into Xcode Runner group, not just placed on filesystem |
| Google Sign-In URL scheme | Info.plist CFBundleURLTypes | — | Derived from iosClientId in firebase_options.dart (reversed) |
| iOS app icons | flutter_launcher_icons (pubspec.yaml ios: true) | Xcode Assets.xcassets | Single command generates all required sizes |
| Launch screen | LaunchScreen.storyboard (generated by flutter create) | — | Default storyboard is sufficient for this phase |
| NotificationService Darwin init | Dart (lib/notifications/notification_service.dart) | — | Only file requiring a Dart edit in Phase 12 scope |
| NSAppTransportSecurity | Info.plist | — | CARTO tiles and Cloud Functions are HTTPS — no exception needed; confirm only |
| CocoaPods dependency resolution | ios/Podfile + pod install | — | Runs automatically via flutter build ios or manually |

---

## Standard Stack

### Core (no version changes — all iOS-compatible at current versions)

| Library | Current Version | iOS Status | Phase 12 Action |
|---------|-----------------|------------|-----------------|
| Flutter | 3.41.6 (local) | YES | `flutter create --platforms=ios .` |
| geolocator | ^14.0.2 | YES — geolocator_apple resolved by CocoaPods | No pubspec change; AppleSettings code is Phase 14 |
| firebase_core | ^4.9.0 | YES — iOS 13+ minimum | Podfile must be iOS 14+ |
| firebase_auth | ^6.5.1 | YES | GoogleService-Info.plist + entitlements in Phase 12 |
| google_sign_in | ^7.2.0 | YES | URL scheme in Info.plist (Phase 12); clientId Dart param is Phase 13 |
| flutter_local_notifications | ^21.0.0 | YES — DarwinInitializationSettings | NotificationService needs Darwin init (Phase 12 Dart edit) |
| flutter_secure_storage | ^10.3.1 | YES — Keychain | Keychain Sharing entitlement is Phase 12 prerequisite |
| flutter_map | ^8.1.0 | YES — pure Dart | No iOS-specific setup |
| flutter_background_service | ^5.1.0 | PARTIAL — iOS GPS not viable | Left as-is; Android path unchanged; iOS GPS is Phase 14 |
| permission_handler | ^12.0.1 | YES | Podfile PERMISSION_LOCATION=1 macro required |
| flutter_launcher_icons | ^0.14.3 (dev) | YES | Set ios: true in pubspec; run dart run flutter_launcher_icons |
| CocoaPods | 1.16.2 (local) | YES | Verified present |
| Xcode | 26.5 (local) | YES | Verified present; license must be accepted by user first |
| flutterfire CLI | 1.3.2 (local) | YES | Used to download/regenerate GoogleService-Info.plist |

[VERIFIED: local toolchain probe] — Xcode 26.5, CocoaPods 1.16.2, Flutter 3.41.6, flutterfire 1.3.2 all confirmed present.

### Key Fact: No New Packages

`pubspec.yaml` requires exactly one change: `flutter_launcher_icons.ios: false` → `ios: true`. No new dependencies are added in Phase 12. [VERIFIED: pubspec.yaml read directly]

---

## Architecture Patterns

### System Architecture Diagram (Phase 12 scope — configuration only)

```
                    ┌─────────────────────────────────┐
                    │   flutter create --platforms=ios │
                    │   (generates ios/ project)       │
                    └──────────────┬──────────────────┘
                                   │
          ┌────────────────────────▼──────────────────────────┐
          │              ios/ Project Tree                     │
          │                                                    │
          │  Runner.xcworkspace ◄─── pod install resolves     │
          │  Podfile            ◄─── platform :ios, '14.0'    │
          │                          + post_install GCC macros│
          │                                                    │
          │  Runner/ ────────────────────────────────────────  │
          │    Info.plist        ◄── location keys             │
          │                          UIBackgroundModes         │
          │                          CFBundleURLTypes          │
          │                          (reversed-client-ID)      │
          │    DebugProfile.entitlements ◄── keychain-access   │
          │    Release.entitlements      ◄── keychain-access   │
          │    AppDelegate.swift ◄── default FlutterAppDelegate│
          │    GoogleService-Info.plist ◄── drag into Xcode    │
          │    Assets.xcassets/AppIcon ◄── flutter_launcher_icons│
          │    Base.lproj/LaunchScreen.storyboard ◄── default  │
          └────────────────────────────────────────────────────┘
                                   │
          ┌────────────────────────▼──────────────────────────┐
          │              Dart (one file edit)                  │
          │  lib/notifications/notification_service.dart       │
          │    _createChannels() → add DarwinInitializationSettings│
          └────────────────────────────────────────────────────┘
                                   │
          ┌────────────────────────▼──────────────────────────┐
          │              pubspec.yaml (one line)               │
          │  flutter_launcher_icons: ios: false → true         │
          └────────────────────────────────────────────────────┘
```

### Recommended Execution Order

Steps must run in this dependency order — each step unblocks the next:

1. **HUMAN GATE:** `sudo xcodebuild -license accept` — blocks everything else
2. `flutter create --platforms=ios .` — generates ios/ tree
3. Open `ios/Runner.xcodeproj` in Xcode → set bundle ID to `com.travey.app`
4. Edit `ios/Podfile` — set `platform :ios, '14.0'` + full `post_install` block
5. Add Xcode capabilities: Background Modes → Location Updates; Keychain Sharing (empty group)
6. Edit `ios/Runner/Info.plist` — add all required keys (location, UIBackgroundModes, CFBundleURLTypes)
7. Download `GoogleService-Info.plist` from Firebase Console → drag into Xcode Runner group
8. Edit `ios/Runner/DebugProfile.entitlements` and `ios/Runner/Release.entitlements` — add `keychain-access-groups: []`
9. Edit `pubspec.yaml` → `flutter_launcher_icons.ios: true`
10. Run `dart run flutter_launcher_icons`
11. Edit `lib/notifications/notification_service.dart` → add `DarwinInitializationSettings` to `initialize()` and add iOS `NotificationDetails` to `scheduleWeeklySummary()` and `scheduleReminder()`
12. Run `flutter build ios --simulator` — phase gate

### Anti-Patterns to Avoid

- **Adding GoogleService-Info.plist only to the filesystem (not the Xcode target):** Firebase initialization fails at runtime with "GoogleService-Info.plist not found" even though the file is present on disk. Must be dragged into the Xcode Runner group so the build system includes it in Copy Bundle Resources.
- **Setting only the Podfile platform line without the post_install IPHONEOS_DEPLOYMENT_TARGET:** Transitive pods may have lower minimums than 14.0 and emit linker warnings or errors. The `post_install` hook forces all pods to 14.0.
- **Adding UIBackgroundModes to Info.plist without the Xcode Background Modes capability:** iOS ignores the Info.plist entry without the capability; the GPS stream stops within ~30 seconds of backgrounding.
- **Adding Google Maps setup (GMSServices.provideAPIKey()):** This codebase uses flutter_map. Adding Google Maps setup is incorrect and would introduce an unnecessary API key dependency.
- **Using riverpod_annotation or code generation in new files for Phase 12:** Phase 12 has no new providers or models — no build_runner run is needed.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| iOS app icon generation | Manual Xcode icon resizing (12 required sizes) | `dart run flutter_launcher_icons` with `ios: true` | Generates all required sizes from a single source image; error-prone to do manually |
| Reversed client ID derivation | String manipulation code | Read `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` or reverse `iosClientId` mechanically | It is a deterministic reversal — not logic, just a string |
| CocoaPods dependency resolution | Manual pod file editing | `pod install` (via `flutter build ios` or directly) | Flutter's podhelper.rb knows the correct plugin pod specs |
| Firebase iOS config | Manual firebase_options.dart iOS block | `flutterfire configure` (already done — block is present) | FlutterFire CLI ensures config consistency across firebase_options.dart and GoogleService-Info.plist |
| AppDelegate URL handling for Google Sign-In | Manual `openURL:` override | Default FlutterAppDelegate scaffold | `google_sign_in_ios` v6+ handles URL callbacks automatically via plugin registration |

---

## Reversed Client ID — Exact Derivation

The `CFBundleURLSchemes` entry for Google Sign-In requires the **reversed** form of the iOS OAuth client ID.

**Source value** (from `lib/firebase_options.dart`, read directly):
```
iosClientId: '1076279794226-6h24q245801r9pca45v2e2tpjiocde64.apps.googleusercontent.com'
```

**Reversed form** (domain segments reversed):
```
com.googleusercontent.apps.1076279794226-6h24q245801r9pca45v2e2tpjiocde64
```

This is also the `REVERSED_CLIENT_ID` field in `GoogleService-Info.plist`. If the `.plist` is downloaded from Firebase Console after this research session, confirm they match before using either. [VERIFIED: firebase_options.dart read directly — HIGH confidence]

---

## Common Pitfalls

### Pitfall 1: Info.plist UIBackgroundModes Without Xcode Capability
**What goes wrong:** Adding `UIBackgroundModes` with `location` to `Info.plist` manually but not adding the Background Modes → Location Updates capability in Xcode. iOS treats the plist entry as advisory only; the capability is what actually grants the entitlement at the OS level. GPS stream stops within ~30 seconds of the device being locked.
**Why it happens:** Info.plist is editable in a text editor. The Xcode capability toggle is in the UI and writes to the entitlements file — developers assume plist-only is sufficient.
**How to avoid:** Always add the Xcode capability first (Signing & Capabilities → + → Background Modes → Location updates), then verify the Info.plist key is also present.
**Warning signs:** Simulator build succeeds, GPS stream opens, but real-device GPS stops after ~30 seconds of backgrounding.

### Pitfall 2: Keychain Sharing Entitlement Missing = Silent -34018 on Real Device
**What goes wrong:** `flutter_secure_storage` appears to write the Firebase ID token without error but every subsequent `read()` returns `null`. On real devices (not Simulator), `SecItemAdd` returns `errSecMissingEntitlement (-34018)` without surfacing an exception to Dart. Auth appears broken — user is prompted to sign in on every restart.
**Why it happens:** Simulator does not enforce the Keychain Sharing entitlement requirement. The bug is invisible until first real-device run.
**How to avoid:** Add the Keychain Sharing capability in Xcode during scaffolding (before any device testing). Verify both `DebugProfile.entitlements` and `Release.entitlements` have `keychain-access-groups` with an empty array. [VERIFIED: flutter_secure_storage docs — HIGH confidence]
**Warning signs:** Console shows `-34018`; Keychain read returns null immediately after a write that returned no error.

### Pitfall 3: GoogleService-Info.plist Filesystem-Only Placement
**What goes wrong:** The file is copied to `ios/Runner/GoogleService-Info.plist` in the filesystem but not added to the Xcode project. The app bundle at build time does not include it. Firebase.initializeApp fails with "configuration file 'GoogleService-Info.plist' not found".
**Why it happens:** Text-editor-driven workflows don't open Xcode to do the drag-and-drop. Editing `project.pbxproj` manually to add it is error-prone.
**How to avoid:** Open Xcode, right-click the Runner group in the file navigator, choose "Add Files to Runner", select `GoogleService-Info.plist`, ensure "Add to targets: Runner" is checked.
**Warning signs:** Firebase.initializeApp throws at startup even though the file is present in `ios/Runner/` on disk.

### Pitfall 4: Podfile Platform Target / post_install Mismatch
**What goes wrong:** `flutter create` generates `platform :ios, '12.0'`. Firebase requires iOS 13+. Transitive pods may require 14.0. Without the `post_install` hook setting all pod targets to the same minimum, builds fail with "The plugin X requires a higher minimum iOS deployment target than your application is targeting."
**Why it happens:** Flutter's generated Podfile is conservative. Each package maintainer sets their own floor. Mismatch between the platform line, Xcode IPHONEOS_DEPLOYMENT_TARGET, and individual pods causes layered failures.
**How to avoid:** Set `platform :ios, '14.0'` immediately after scaffold. Add the full `post_install` block (see Code Examples). Run `pod install` and then `flutter build ios --no-codesign` to catch failures early.
**Warning signs:** `pod install` succeeds but `flutter build ios --no-codesign` fails with deployment target errors.

### Pitfall 5: CFBundleURLSchemes Uses Client ID Instead of Reversed Client ID
**What goes wrong:** Copy-paste the `iosClientId` value verbatim into `CFBundleURLSchemes` instead of reversing it. Google Sign-In opens Safari/SFSafariViewController, the user authenticates, but the browser cannot redirect back to the app — it hangs on a blank page. No error surfaces in Dart.
**Why it happens:** The Info.plist entry name is "URL Schemes" and the value looks like a URL — developers naturally copy the client ID without realizing it must be reversed.
**How to avoid:** The reversed form always starts with `com.googleusercontent.apps.`. If it does not start with `com`, it is wrong.
**Warning signs:** Google Sign-In completes in browser but app never receives the callback; `google_sign_in` future never resolves; sign-in works on Android but not iOS.

### Pitfall 6: Xcode 26 / SPM + CocoaPods Coexistence
**What goes wrong:** Xcode 26 (the local toolchain) introduced SPM as the default integration path for Flutter plugins. Firebase is migrating away from CocoaPods to SPM (CocoaPods support ends October 2026 per Firebase announcement). `flutterfire configure` on Flutter 3.41.6 + Xcode 26 may default to SPM for Firebase packages while other plugins (geolocator, permission_handler) still use CocoaPods. Mixed integration may cause duplicate symbol errors or missing pod setup.
**Why it happens:** The Flutter toolchain's SPM migration is in progress as of Flutter 3.41.x. `flutter create` may generate a `Package.swift` alongside the Podfile.
**How to avoid:** After `flutter create --platforms=ios .`, inspect whether a `Package.swift` was generated. Run `flutter build ios --simulator` immediately after scaffold (before any config). If SPM/CocoaPods conflicts appear, let `flutterfire configure` manage Firebase integration — do not manually add Firebase to both Podfile and Package.swift. [ASSUMED — SPM/CocoaPods coexistence behavior under Flutter 3.41.6 + Xcode 26 not directly verified in this session; flag for resolution during execution if build fails]
**Warning signs:** "duplicate symbols" linker errors; `pod install` cannot find a Firebase pod that was expected; `Package.swift` present alongside Podfile.

### Pitfall 7: Developer Mode Not Enabled on iPhone (iOS 16+)
**What goes wrong:** First `flutter run` on a real iPhone fails with "Unable to install" or "The device does not have a valid developer image". The Developer Mode toggle is not visible in Settings yet.
**Why it happens:** iOS 16+ requires the device to be connected to a trusted Mac with Xcode before the Developer Mode toggle appears in Settings → Privacy & Security. The device must be restarted after enabling it.
**How to avoid:** Before any real-device run, connect iPhone → Xcode shows a prompt → follow the Developer Mode prompt on the device → restart → Settings → Privacy & Security → Developer Mode → enable → restart again.
**Warning signs:** `flutter run` fails immediately without a code-signing error; no Developer Mode toggle in Settings.

---

## Code Examples

Verified patterns from official sources and direct file reads.

### Podfile (complete, for ios/Podfile)

```ruby
# Source: .planning/research/ARCHITECTURE.md (derived from Context7/geolocator + permission_handler docs)
platform :ios, '14.0'

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
      # Raise all pod deployment targets to match the app minimum.
      # Without this, transitive pods that advertise a lower minimum
      # cause linker warnings or errors.
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'

      # permission_handler: enable only the permissions this app uses.
      # Compiles out everything else to avoid App Store binary analysis flags.
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_LOCATION=1',          # locationWhenInUse + locationAlways
        'PERMISSION_NOTIFICATIONS=1',     # flutter_local_notifications permission
      ]
    end
  end
end
```

### Info.plist Required Keys (add inside top-level `<dict>`)

```xml
<!-- Source: .planning/research/STACK.md + .planning/research/ARCHITECTURE.md -->

<!-- Location permissions — required by permission_handler and geolocator -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Traevy records your commute route to calculate time moving and time stuck in traffic.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Traevy continues recording your commute in the background so you can keep using your phone normally while tracking.</string>

<!-- Background location mode — UIBackgroundModes entry alone is insufficient;
     the Xcode Background Modes capability must also be enabled.
     Required on iOS 16+ for getPositionStream to deliver updates after backgrounding. -->
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>

<!-- Google Sign-In OAuth callback URL scheme.
     Value is the REVERSED form of iosClientId from firebase_options.dart.
     iosClientId: 1076279794226-6h24q245801r9pca45v2e2tpjiocde64.apps.googleusercontent.com
     Reversed:   com.googleusercontent.apps.1076279794226-6h24q245801r9pca45v2e2tpjiocde64 -->
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

**Keys NOT to add:**
- `NSLocationAlwaysUsageDescription` — deprecated, iOS 10 only
- `NSAppTransportSecurity` exception — all network calls are HTTPS (CARTO tiles, Cloud Functions, Firebase); no HTTP exception needed
- `GMSApiKey` — not using Google Maps; flutter_map is pure Dart
- Any Firebase keys in Info.plist — handled programmatically via firebase_options.dart

### Entitlements Files (both DebugProfile.entitlements and Release.entitlements)

```xml
<!-- Source: .planning/research/STACK.md + flutter_secure_storage docs -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- Keychain Sharing — required for flutter_secure_storage on real devices.
       Empty array = single-app keychain group (no cross-app sharing needed).
       Without this, SecItemAdd returns -34018 silently and token reads return null. -->
  <key>keychain-access-groups</key>
  <array/>
</dict>
</plist>
```

Note: `flutter create` generates entitlements files with `aps-environment` and other keys. Keep all existing keys — only ADD `keychain-access-groups`. Do not replace the file.

### AppDelegate.swift (default scaffold — no modifications needed)

```swift
// Source: .planning/research/ARCHITECTURE.md
// google_sign_in_ios v6+ handles openURL automatically via GeneratedPluginRegistrant.
// No GMSServices call needed (flutter_map, not google_maps_flutter).
// No manual UNUserNotificationCenter delegate needed — FlutterAppDelegate handles it.
import UIKit
import Flutter

@main
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

The generated scaffold already looks like this. No edits required.

### pubspec.yaml Change (one line)

```yaml
# Before:
flutter_launcher_icons:
  android: true
  ios: false          # Change this to true
  image_path: "assets/icons/logo.jpeg"
  min_sdk_android: 21
  adaptive_icon_background: "#000000"
  adaptive_icon_foreground: "assets/icons/logo.jpeg"

# After:
flutter_launcher_icons:
  android: true
  ios: true           # Changed — generates all required iOS icon sizes
  image_path: "assets/icons/logo.jpeg"
  min_sdk_android: 21
  adaptive_icon_background: "#000000"
  adaptive_icon_foreground: "assets/icons/logo.jpeg"
```

Then run: `dart run flutter_launcher_icons`

### NotificationService.dart — Darwin Init Addition

`lib/notifications/notification_service.dart` currently initializes only Android channels (confirmed by reading the source). It must be updated to also initialize for iOS:

```dart
// Source: lib/notifications/notification_service.dart (read directly) +
//         .planning/research/STACK.md (DarwinInitializationSettings pattern)
// Add this to the initialize() method, before _createChannels():

// Initialize the plugin for both platforms.
// TrackingNotificationService already calls initialize() with Darwin settings
// for its own plugin instance. This instance handles weekly summary + reminder.
const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
const darwinInit = DarwinInitializationSettings(
  requestAlertPermission: false, // Defer to TrackingPermissionService.preflight()
  requestSoundPermission: false,
  requestBadgePermission: false,
);
await _plugin.initialize(
  const InitializationSettings(android: androidInit, iOS: darwinInit),
);
```

Additionally, `scheduleWeeklySummary()` and `scheduleReminder()` pass only `AndroidNotificationDetails`. For iOS, the `NotificationDetails` must also include a `DarwinNotificationDetails` entry (or the notification is silently discarded on iOS):

```dart
// In scheduleWeeklySummary() — update NotificationDetails:
notificationDetails: const NotificationDetails(
  android: AndroidNotificationDetails(
    kWeeklySummaryChannelId,
    kWeeklySummaryChannelName,
    channelDescription: kWeeklySummaryChannelDescription,
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
    presentBadge: false,
  ),
),

// In _reminderDetails() — update return value:
NotificationDetails _reminderDetails() => const NotificationDetails(
  android: AndroidNotificationDetails(
    kReminderChannelId,
    kReminderChannelName,
    channelDescription: kReminderChannelDescription,
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
    presentBadge: false,
  ),
);
```

The `androidScheduleMode` parameter on `zonedSchedule()` is Android-only. Confirm it compiles cleanly on iOS — `flutter_local_notifications` ^21 accepts the parameter but ignores it on iOS. [VERIFIED: flutter_local_notifications source — HIGH confidence]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| google_maps_flutter for maps | flutter_map (OpenStreetMap) | Project inception (traevy) | Eliminates iOS Google Maps SDK setup, API key requirement, and iOS 14 hard floor from google_maps_flutter_ios |
| Manual iOS icon resizing (12+ sizes) | flutter_launcher_icons with ios: true | flutter_launcher_icons ^0.14 | One command generates all Xcode-required sizes |
| CocoaPods-only Firebase | Firebase migrating to Swift Package Manager | Firebase Oct 2026 CocoaPods EOL; Flutter 3.44 SPM default | Xcode 26 may generate Package.swift; let flutterfire configure manage the transition |
| flutter_background_service for iOS GPS | geolocator AppleSettings + CoreLocation background mode | geolocator 7.3+ AppleSettings added | Eliminates need for background isolate on iOS; CLLocationManager keeps process alive |
| NSLocationAlwaysUsageDescription | NSLocationAlwaysAndWhenInUseUsageDescription | iOS 11 (2017) | Legacy key is ignored on iOS 11+; using only the new key is correct |

**Deprecated/outdated:**
- `NSLocationAlwaysUsageDescription` — do not add; replaced by `NSLocationAlwaysAndWhenInUseUsageDescription` for iOS 11+
- `background_locator_2` — abandoned; not in this project anyway
- `GMSServices.provideAPIKey()` in AppDelegate — not needed; this project uses flutter_map

---

## Runtime State Inventory

Phase 12 is greenfield iOS scaffolding. There is no existing `ios/` folder, no iOS-specific stored state, and no running iOS services to migrate. All configuration is additive.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None — no iOS Drift database exists yet | None — first iOS run creates it fresh |
| Live service config | None — no iOS app registered as running service | None |
| OS-registered state | None | None |
| Secrets / env vars | `firebase_options.dart` carries iosClientId and iosBundleId — these are source-controlled config, not secrets | Verify GoogleService-Info.plist matches when downloaded |
| Build artifacts | None — ios/ does not exist | flutter create generates the tree |

**Nothing found in any category — verified by confirming `ios/` folder does not exist and checking for iOS-specific files.**

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Xcode | flutter create, flutter build ios, pod install | ✓ | 26.5 | — |
| CocoaPods | pod install (via flutter build ios) | ✓ | 1.16.2 | — |
| Flutter | flutter create, flutter build ios | ✓ | 3.41.6 | — |
| flutterfire CLI | GoogleService-Info.plist download | ✓ | 1.3.2 | Manual download from Firebase Console |
| Xcode license | All flutter build ios commands | HUMAN GATE | Must be accepted | Run `sudo xcodebuild -license accept` |
| Real iPhone with Developer Mode | IOS-02 real-device install | HUMAN GATE | iOS 16+ requires Developer Mode toggle | Simulator-only for IOS-01 verification |
| Apple ID (free) | Xcode signing for real device | HUMAN GATE | Free account sufficient | No paid Developer account needed this milestone |
| Firebase Console access | GoogleService-Info.plist download | Assumed ✓ | — | Already have firebase_options.dart with all values |
| assets/icons/logo.jpeg | flutter_launcher_icons iOS icon generation | ✓ | Confirmed in assets/ | — |

**Missing dependencies with no fallback:**
- Xcode license acceptance — blocks all `flutter build ios` commands; must be resolved by the user before any plan execution.
- Real iPhone with Developer Mode — blocks IOS-02 real-device install; Simulator covers IOS-01 without it.

**Missing dependencies with fallback:**
- flutterfire CLI for GoogleService-Info.plist → fallback: download manually from Firebase Console → Project Settings → iOS app (com.travey.app) → Download GoogleService-Info.plist.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (already configured) + manual device verification |
| Config file | analysis_options.yaml (very_good_analysis) |
| Quick run command | `flutter analyze && flutter build ios --simulator` |
| Full suite command | `flutter test && flutter build ios --simulator` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| IOS-01 | App builds and launches on Simulator | Build smoke | `flutter build ios --simulator` | Pass = build succeeds with exit 0 |
| IOS-01 | Simulator launch | Manual | Open iOS Simulator; `flutter run` or Xcode Product → Run | Human: confirm app appears on Simulator screen |
| IOS-02 | Real iPhone install | Manual (human-gated) | `flutter run` with device connected | Human: requires Developer Mode, Apple ID signing |
| IOS-03 | Info.plist location keys present | Automated grep | `grep -c NSLocationWhenInUseUsageDescription ios/Runner/Info.plist` | Exit 0 + count > 0 = present |
| IOS-03 | Info.plist UIBackgroundModes location present | Automated grep | `grep -c "location" ios/Runner/Info.plist` | Confirm in context of UIBackgroundModes array |
| IOS-03 | Info.plist CFBundleURLSchemes reversed-client-ID present | Automated grep | `grep -c "com.googleusercontent.apps" ios/Runner/Info.plist` | Should match reversed iosClientId |
| IOS-03 | Keychain Sharing entitlement in Release.entitlements | Automated grep | `grep -c "keychain-access-groups" ios/Runner/Release.entitlements` | Count > 0 = present |
| IOS-03 | Keychain Sharing in DebugProfile.entitlements | Automated grep | `grep -c "keychain-access-groups" ios/Runner/DebugProfile.entitlements` | Count > 0 = present |
| IOS-03 | GoogleService-Info.plist in Xcode target | Build verification | Check "Copy Bundle Resources" in `ios/Runner.xcodeproj/project.pbxproj` | `grep "GoogleService-Info.plist" ios/Runner.xcodeproj/project.pbxproj` |
| IOS-03 | Podfile platform is 14.0 | Automated grep | `grep "platform :ios" ios/Podfile` | Should show '14.0' |
| IOS-03 | pod install succeeds | Build | `cd ios && pod install` | Exit 0 = success |
| IOS-03 | Bundle ID in Info.plist matches com.travey.app | Automated grep | `grep "com.travey.app" ios/Runner/Info.plist` | CFBundleIdentifier value |
| IOS-03 | App icon sets generated | Filesystem check | `ls ios/Runner/Assets.xcassets/AppIcon.appiconset/ \| wc -l` | Should list multiple .png files + Contents.json |
| IOS-03 | Launch screen storyboard present | Filesystem check | `ls ios/Runner/Base.lproj/LaunchScreen.storyboard` | Generated by flutter create |
| — | flutter analyze clean | Static analysis | `flutter analyze` | Zero new analysis issues (baseline: 0 on Phase 11 completion) |
| — | NotificationService initializes on iOS | Build | Included in `flutter build ios --simulator` | Compile-time verification that DarwinInitializationSettings resolves |

### Sampling Rate
- **Per task commit:** `flutter analyze`
- **Per wave merge:** `flutter analyze && flutter build ios --simulator`
- **Phase gate:** `flutter build ios --simulator` green + all grep checks pass + real-device launch confirmed (human)

### Wave 0 Gaps
None — Phase 12 has no new business logic to unit-test. The NotificationService Dart edit is covered by existing `notification_service_test.dart` if it exists; the edit is additive (iOS init does not change Android behavior). Verify the existing test suite still passes after the Dart change.

- [ ] After `NotificationService.initialize()` edit: run `flutter test test/unit/` to confirm existing notification tests are still green.
- [ ] No new test files are required for this phase — all validation is build-time or manual device verification.

---

## Open Questions

1. **SPM vs CocoaPods under Xcode 26 + Flutter 3.41.6**
   - What we know: Firebase is migrating from CocoaPods to SPM (EOL October 2026). Flutter 3.44 introduces SPM as the default. The current toolchain is Flutter 3.41.6 + Xcode 26.5. `flutterfire configure` 1.3.2 is present locally.
   - What's unclear: Whether `flutter create --platforms=ios .` on this exact toolchain generates only a Podfile or also a `Package.swift`. If a Package.swift is generated, Firebase via SPM may conflict with CocoaPods plugins (geolocator, permission_handler).
   - Recommendation: After running `flutter create --platforms=ios .`, immediately check for `Package.swift` in `ios/`. If present, run `flutter build ios --simulator` before any configuration. If it fails with SPM/CocoaPods conflicts, consult `flutterfire configure` output. Do not manually edit `Package.swift` or Podfile Firebase entries — let flutterfire manage it. [ASSUMED — exact Xcode 26.5 + Flutter 3.41.6 SPM behavior not directly verified]

2. **`flutter_map_tile_caching` iOS minimum version**
   - What we know: Listed as iOS-compatible (pure Dart with Drift/SQLite backend). Pub.dev states compatibility.
   - What's unclear: The exact iOS minimum floor for `flutter_map_tile_caching` 10.1.1 is not explicitly published; estimated iOS 12 from Drift dependency.
   - Recommendation: iOS 14.0 deployment target covers it with headroom. Validate tile caching works on device during Phase 16. No action needed in Phase 12.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | AppDelegate.swift default scaffold requires no modifications — google_sign_in_ios v6+ handles openURL automatically | Code Examples / AppDelegate | Low — if URL handling is broken, Phase 13 auth testing will surface it; fix is adding one line |
| A2 | `flutter create --platforms=ios .` on Flutter 3.41.6 + Xcode 26.5 generates a standard Podfile-based project without SPM complications | Open Questions #1 | Medium — SPM/CocoaPods conflict would require investigation at execution time; documented in Open Questions |
| A3 | CARTO HTTPS tile URLs do not trigger ATS blocking — no NSAppTransportSecurity exception needed | Don't Hand-Roll / Info.plist | Low — CARTO tiles are confirmed HTTPS; if an ATS error appears, add an exception for basemaps.cartocdn.com |
| A4 | `flutter_launcher_icons` ^0.14.3 with `ios: true` generates all required Xcode icon sizes from `logo.jpeg` without requiring specific input dimensions | Standard Stack | Low — logo.jpeg confirmed in assets/; if generation fails, the error message from flutter_launcher_icons will be clear |
| A5 | The `NotificationService` existing test suite (if any) will still pass after adding `DarwinInitializationSettings` to `initialize()` since Darwin init does not affect Android behavior | Validation Architecture | Low — the change is additive; Android path is unchanged |

---

## Sources

### Primary (HIGH confidence)

- `lib/firebase_options.dart` — read directly; confirms `iosClientId: '1076279794226-6h24q245801r9pca45v2e2tpjiocde64.apps.googleusercontent.com'` and `iosBundleId: 'com.travey.app'`
- `pubspec.yaml` — read directly; confirms all package versions, `flutter_launcher_icons.ios: false` (must change to true), no google_maps_flutter
- `lib/notifications/notification_service.dart` — read directly; confirms Android-only initialization (no DarwinInitializationSettings) — this is the only Dart file requiring edits in Phase 12 scope
- `lib/features/tracking/services/tracking_notification_service.dart` — source grep confirmed `DarwinInitializationSettings` already wired (no Phase 12 edits needed)
- `lib/config/constants.dart` — confirms map tile URLs are HTTPS (`basemaps.cartocdn.com`) — no ATS exception needed
- `.planning/research/SUMMARY.md` — milestone iOS research executive summary; all 5 phases defined
- `.planning/research/STACK.md` — exact iOS package compatibility table, Podfile, Info.plist keys, AppDelegate, reversed-client-ID, entitlements
- `.planning/research/ARCHITECTURE.md` — full Podfile template, entitlements XML, component map, build order, Xcode capabilities
- `.planning/research/PITFALLS.md` — 13 pitfalls catalogued with warning signs and recovery strategies
- `.planning/REQUIREMENTS.md` — IOS-01, IOS-02, IOS-03 requirements confirmed for Phase 12
- `.planning/ROADMAP.md` — Phase 12 success criteria (7 items) confirmed
- Local toolchain probe — Xcode 26.5, CocoaPods 1.16.2, Flutter 3.41.6, flutterfire 1.3.2, ios/ confirmed absent

### Secondary (MEDIUM confidence)

- Context7 / baseflow/flutter-geolocator — `AppleSettings`, `UIBackgroundModes`, `BYPASS_PERMISSION_LOCATION_ALWAYS` Podfile macro (used in Podfile template)
- Context7 / juliansteenbakker/flutter_secure_storage — `keychain-access-groups` entitlement requirement, `-34018` behavior
- Context7 / websites/pub_dev_permission_handler — `PERMISSION_LOCATION=1` and `PERMISSION_NOTIFICATIONS=1` GCC macros
- Firebase FlutterFire iOS installation docs — iOS 13 minimum for firebase_core 4.x
- Apple Developer Documentation — `UIBackgroundModes: location` + `allowsBackgroundLocationUpdates` behavioral contract

### Tertiary (LOW confidence)

- SPM / CocoaPods coexistence behavior under Flutter 3.41.6 + Xcode 26.5 — unverified; flagged as A2 assumption and Open Question #1
- `flutter_map_tile_caching` 10.1.1 exact iOS minimum floor — pub.dev states iOS compatible; precise floor not published

---

## Metadata

**Confidence breakdown:**
- IOS-01 (Simulator build): HIGH — command and Podfile config are well-documented and tested by the ecosystem
- IOS-02 (Real device): HIGH for the code steps; MEDIUM for human-gated steps (Xcode signing, Developer Mode — user-controlled)
- IOS-03 (Info.plist + entitlements): HIGH — all key values derived from confirmed sources (firebase_options.dart read directly, flutter_secure_storage docs)
- Podfile: HIGH — template from Architecture research, verified against geolocator and permission_handler docs
- NotificationService Dart edit: HIGH — source read directly, change is additive, matches pattern already in TrackingNotificationService

**Research date:** 2026-06-02
**Valid until:** 2026-07-02 (package versions stable; SPM migration timeline is the only fast-moving element — re-check if Flutter 3.44 releases before execution)
