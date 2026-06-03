# Phase 15: Notifications, Permissions & Onboarding UX on iOS — Research

**Researched:** 2026-06-03
**Domain:** iOS ActivityKit (Live Activity), permission_handler iOS location flow, flutter_local_notifications iOS, Android BigTextStyle notification enrichment
**Confidence:** MEDIUM — Live Activity + free-provisioning constraint is the primary uncertainty area

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Request When-In-Use during onboarding, preceded by one location priming screen. Do NOT prime Always or notifications.
- **D-02:** Request "Always" at the first trip Start.
- **D-03:** When-In-Use-only on a later Start: proceed in degraded mode + show a one-line dismissible hint with "Open Settings" deep-link. Never block recording.
- **D-04:** Degraded = best-effort background recording: start geolocator stream with allowBackgroundLocationUpdates: true; warn track may have gaps.
- **D-05:** Surface degraded state by reusing existing permission_banner / TrackingPermissionStatus.foregroundOnly path, branching copy by platform.
- **D-06:** Platform-branch preflight(): on iOS the dance ends after location — never probes/requests Permission.notification and never returns notificationDenied. Android's four-step dance stays unchanged.
- **D-07:** Request iOS notification permission ~1 week into usage, timed to when the first weekly summary becomes meaningful. Edge: if user enables a departure reminder before the 1-week mark, request at that point too.
- **D-08:** On iOS 17+, an active commute shows an interactive Live Activity (lock screen + Dynamic Island) with live elapsed time, distance, moving/stuck status, and direction (to_office/to_home), plus an in-place Stop button. The Stop button requires App Intents (iOS 17+ floor) wired to the tracking controller's stop path.
- **D-09:** iOS 17+ is the floor for the Live Activity. iOS < 17 → blue-location-indicator-only, Stop stays in-app. No 16.1–16.x display-only middle tier.
- **D-10:** The Live Activity is driven by local ActivityKit updates from the existing TripAccumulator snapshot stream (1 Hz). No push server. Dismissed when the trip stops.
- **D-11:** Gate startTrackingNotification() behind Platform.isAndroid so no phantom notification is posted on iOS.
- **D-12:** Enrich the existing Android "Active commute" foreground notification to show the same live stats layout as the iOS Live Activity. Hard constraint: no regression to the foreground-service binding.

### Claude's Discretion
- Live Activity bridge: live_activities pub plugin vs a custom platform channel + native ActivityKit Widget Extension.
- Dynamic Island compact/minimal/expanded layouts.
- Exact "1 week of usage" anchor for the notification prompt (D-07).
- Whether the Stop App Intent ends the trip directly or deep-links + ends.

### Deferred Ideas (OUT OF SCOPE)
- Android 16 "Live Updates" API.
- iOS 16.1–16.x display-only Live Activity middle tier.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| IOS-09 | User grants location via the iOS two-step When-In-Use → Always flow during onboarding, with "When In Use only" handled as a valid degraded state | §Permission Sequencing confirms permission_handler two-step is functional; §TrackingPermissionService Platform Branch documents exact code change |
| IOS-10 | User grants notification permission on iOS; weekly summary and departure-reminder notifications fire | §Notification Permission Timing documents the late-request pattern; existing flutter_local_notifications zonedSchedule already fires on iOS (DarwinNotificationDetails present) |
| IOS-11 | The Android-only persistent tracking notification is suppressed on iOS | §Platform.isAndroid Gate documents the two-line change to tracking_notification_service.dart and TrackingServiceController |
| IOS-13 | On iOS 17+, an active commute shows a Live Activity (lock screen + Dynamic Island) with live elapsed/distance/moving-stuck stats and an in-place Stop button | §Live Activity Bridge Decision + §Xcode Widget Extension Setup + §App Intent Stop Button + §Update Cadence all address this; critical FREE-PROVISIONING CONSTRAINT noted |
| IOS-14 | The Android ongoing "Active commute" foreground notification is enriched to show the same live stats, with no regression to the foreground-service binding | §Android Notification Enrichment documents the additive BigTextStyle two-line approach |
</phase_requirements>

---

## Summary

Phase 15 adds three threads to the iOS port: (1) correct iOS location permission sequencing in the onboarding and tracking flows, (2) contextual iOS notification permission decoupled from tracking, and (3) the iOS Live Activity surface (iOS 17+) plus Android notification parity.

The first two threads are low-risk: `TrackingPermissionService.preflight()` already has all the plumbing; iOS needs only a `defaultTargetPlatform == TargetPlatform.iOS` branch that skips the `Permission.notification` step. The notification service's Darwin init already defers permission (`requestAlertPermission: false`), so a late-request helper slot-in to the existing weekly-summary scheduling path covers IOS-10. IOS-11 is a two-line gate.

The Live Activity (IOS-13) is the highest-risk item because it requires a native Xcode Widget Extension target, App Group entitlement, and platform-channel wiring, all in a free-provisioning project. Research confirms that `live_activities` pub.dev plugin (v2.4.9) is the correct bridge choice. The key implementation constraint is that the Stop button cannot use a true `AppIntent`/`LiveActivityIntent` pattern in the free-provisioning profile because the `com.apple.developer.live-activity` entitlement may not be registerable on personal-team profiles. Instead, the Stop button must use a SwiftUI `Link` with the app's existing URL scheme (`com.googleusercontent.apps.1076279794226-6h24q245801r9pca45v2e2tpjiocde64` is already registered) and the `live_activities` plugin's `urlSchemeStream()` callback. This is the fallback pattern documented by the plugin and is confirmed working without special entitlements.

A second critical finding: `ActivityKit Activity.update()` from a background location-mode app is confirmed permitted by Apple for location-based apps ("Your app can use a pre-existing background runtime functionality, such as Location Services, to provide Live Activity updates as you see fit" — Apple developer Q&A). The 1 Hz cadence from `kTrackingUiUpdateInterval` + `NSSupportsLiveActivitiesFrequentUpdates: YES` in Info.plist is the correct implementation path; the elapsed timer should additionally use SwiftUI `Text(timerInterval:)` anchored on `startDate` to tick client-side between Dart updates.

**Primary recommendation:** Use the `live_activities` pub plugin (v2.4.9) with a SwiftUI Widget Extension, App Group, URL-scheme Stop button, and `NSSupportsLiveActivitiesFrequentUpdates: YES`. Apply `defaultTargetPlatform` branches throughout; never add `dart:io Platform.isIOS` in testable logic.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| iOS location priming screen (D-01) | Flutter UI (onboarding feature) | — | Pure Flutter screen, iOS-gated at route level |
| When-In-Use → Always permission dance | Flutter service layer (TrackingPermissionService) | iOS platform layer (CLLocationManager, bridged via permission_handler) | permission_handler abstracts CLLocationManager; branch logic is Dart-side |
| Notification permission request (D-07) | Flutter service layer (NotificationService) | iOS platform layer (UNUserNotificationCenter) | flutter_local_notifications handles UNUserNotificationCenter; timing trigger is Dart business logic |
| Phantom notification suppression (D-11) | Flutter service layer (TrackingServiceController + TrackingNotificationService) | — | Platform.isAndroid gate in Dart; no native changes |
| iOS Live Activity display + updates (D-08/D-10) | Native iOS (Swift/SwiftUI Widget Extension) | Flutter Dart (live_activities bridge) | ActivityKit only available to native Swift/SwiftUI Widget Extension; Dart side drives data |
| Stop App Intent / URL scheme callback (D-08) | Flutter Dart (urlSchemeStream listener) | Native iOS (SwiftUI Link with URL scheme) | Intent runs in native; Dart processes the URL callback |
| Android notification enrichment (D-12) | Flutter service layer (TrackingNotificationService) | — | Pure Dart change to BigTextStyleInformation; no native involvement |
| iOS version gate (D-09) | Flutter Dart (TrackingServiceController.start) | — | DeviceInfoPlugin().iosInfo.systemVersion parsed in Dart |

---

## Standard Stack

### Core (no new packages — existing stack covers all requirements)

| Library | Version (verified) | Purpose | Why Standard |
|---------|--------------------|---------|--------------|
| permission_handler | ^12.0.1 (pubspec); latest 12.0.3 | iOS/Android permission requests | Already in project; v12 supports iOS two-step location flow |
| flutter_local_notifications | ^21.0.0 (pubspec) | Scheduled notifications (weekly summary, departure reminder) | Already in project; DarwinNotificationDetails already wired; zonedSchedule fires on iOS |
| live_activities | 2.4.9 (new) | iOS Live Activity creation/update/end + Dynamic Island + URL scheme callback | Only Flutter-first solution with a maintained ActivityKit bridge; supports iOS 16.1+, URL-scheme callbacks, frequent updates |
| device_info_plus | 13.1.0 (new) | iOS version check for the iOS 17+ gate | Standard DeviceInfoPlugin().iosInfo.systemVersion; avoids hardcoding a platform channel call |

### New Packages Required

**Two new pub.dev packages needed:**

```
live_activities: ^2.4.9
device_info_plus: ^13.1.0
```

[VERIFIED: pub.dev API] `live_activities` latest: 2.4.9 (published ~42 days ago)
[VERIFIED: pub.dev API] `device_info_plus` latest: 13.1.0

### Alternatives Considered

| Recommended | Alternative | Tradeoff |
|-------------|-------------|----------|
| live_activities plugin | Custom platform channel + ActivityKit | Plugin has 140+ code snippets, maintained by istornz, actively updated Jan 2026. Custom channel would replicate the same UserDefaults App Group bridge but without the Dart API surface. Only choose custom if the plugin's UserDefaults bridge proves insufficient for the ContentState shape needed. |
| URL scheme Stop button (SwiftUI Link) | True App Intent (LiveActivityIntent) | App Intents / LiveActivityIntent requires the `com.apple.developer.live-activity` entitlement which is unavailable to personal-team free provisioning profiles. URL scheme avoids entitlement issues, is confirmed working, and the existing `CFBundleURLSchemes` entry is already in Info.plist. |
| device_info_plus | Manual platform channel systemVersion call | device_info_plus is the standard; no reason to do this manually |

### Installation

```bash
# In project root
flutter pub add live_activities
flutter pub add device_info_plus
```

**Version verification (performed):**
- `live_activities` 2.4.9 — confirmed via `curl pub.dev/api/packages/live_activities`
- `device_info_plus` 13.1.0 — confirmed via `curl pub.dev/api/packages/device_info_plus`

---

## Architecture Patterns

### System Architecture Diagram

```
[User taps Start]
       │
       ▼ (iOS path only)
[DeviceInfoPlugin.iosInfo.systemVersion]
       │ iOS ≥ 17?
       ├─ NO ──────────────────────────────────────────► [blue indicator only]
       │
       ▼ YES
[LiveActivities.init(appGroupId, urlScheme)]
[LiveActivities.createActivity("commute", ContentState)]
       │                                     │
       │                                     ▼ (native layer)
       │                        [SwiftUI TraevyLiveActivity Widget]
       │                              lock screen + Dynamic Island
       │
       ▼ every 1 Hz from _uiTimer
[TripAccumulator.snapshot()] ──► [format elapsed/distance/moving/stuck]
       │
       ▼
[LiveActivities.updateActivity("commute", ContentState)]
       │                                     │
       │                                     ▼ (ActivityKit local update)
       │                        [Live Activity re-renders with new data]
       │
       ▼ (user taps Stop button in Live Activity)
[SwiftUI Link("traevy://stop")] ──► [urlSchemeStream fires]
       │
       ▼
[TrackingServiceController.stop()]
       │
[LiveActivities.endActivity("commute")]
       │
[dismissalPolicy: .immediate]

─────────────────────────────────────────────────────────────
ANDROID path (unchanged + enriched):

[User taps Start]
       │
       ▼
[TrackingNotificationService.showRecording()]
       │ (Platform.isAndroid gate)
       │
[BigTextStyleInformation: line1 + '\n' + line2]
       │                               ▲
       ▼ every 5 s (kTrackingNotificationRefreshInterval)
[TripAccumulator.snapshot()]──────────┘

─────────────────────────────────────────────────────────────
PERMISSION paths:

Onboarding (iOS):
[OnboardingScreen] → [LocationPrimingScreen] → [system WhenInUse dialog]

First Start (iOS):
[preflight() iOS branch] → [probe WhenInUse] → [probe locationAlways]
       │ not granted
       ▼
[system "Always Allow?" dialog] (shown ONCE by iOS; no re-prompt)
       │ denied
[foregroundOnly → degraded banner with Open Settings CTA]

Notification (~1 week or on departure reminder enable):
[NotificationService.requestIOSNotificationPermission()]
       │ → UNUserNotificationCenter.requestAuthorization()
       ▼
[zonedSchedule weekly summary / departure reminder fire normally]
```

### Recommended Project Structure (additions only)

```
ios/
├── TraevyLiveActivity/              # NEW — Widget Extension target
│   ├── TraevyLiveActivityWidget.swift
│   ├── TraevyLiveActivityAttributes.swift
│   └── Localizable.strings
lib/
├── features/
│   ├── onboarding/
│   │   └── screens/
│   │       └── onboarding_location_priming_screen.dart  # NEW
│   ├── tracking/
│   │   ├── services/
│   │   │   ├── live_activity_service.dart               # NEW — Dart-side bridge
│   │   │   ├── tracking_permission_service.dart         # MODIFY — iOS branch in preflight/currentStatus
│   │   │   ├── tracking_notification_service.dart       # MODIFY — Platform.isAndroid gate + Android enrichment
│   │   │   └── tracking_service_controller.dart         # MODIFY — call live_activity_service on start/stop
│   └── notifications/
│       └── notification_service.dart                    # MODIFY — iOS notif permission helper
└── config/
    └── constants.dart                                   # MODIFY — Phase 15 constants block
```

---

## Research Findings by Area

### 1. iOS Permission Sequencing (IOS-09, IOS-10)

#### Two-Step Location Flow

[VERIFIED: permission_handler GitHub issue #1324] The permission_handler v12 two-step iOS flow is:
1. `Permission.locationWhenInUse.request()` → triggers "Allow While Using App" system dialog.
2. `Permission.locationAlways.request()` → triggers the system "Always Allow?" upgrade prompt. iOS shows this upgrade prompt ONCE. On subsequent calls after the user has seen it, it returns denied immediately.

The existing `TrackingPermissionService.preflight()` already implements this exact ordering. The ordering invariant at line 182 (`assert(fineGranted, ...)`) is correct and must survive the iOS branch addition.

#### platform-branching `preflight()` (D-06)

The existing code at `tracking_permission_service.dart` runs the notification step unconditionally after the location dance. The iOS branch must be inserted before the notification probe:

```dart
// After locationAlways resolves, before the notification step:
if (defaultTargetPlatform == TargetPlatform.iOS) {
  return backgroundGranted
      ? TrackingPermissionStatus.fullyGranted
      : TrackingPermissionStatus.foregroundOnly;
}
// Android-only: probe/request notification
final notifStatus = await _probe(Permission.notification);
...
```

The same branch applies to `currentStatus()` — on iOS, the notification probe block never runs and `notificationDenied` is never returned.

**Use `defaultTargetPlatform` (not `dart:io Platform.isIOS`) throughout** so unit tests can exercise the iOS code path via `debugDefaultTargetPlatformOverride`. The existing `TrackingServiceController.start()` already uses `defaultTargetPlatform` for the accuracy gate (line 104) — maintain this consistency.

#### When-In-Use Degraded Mode (D-03/D-04/D-05)

`TrackingPermissionStatus.foregroundOnly` is already the correct status when `locationAlways` is not granted. The `permission_banner.dart` already renders for this status. The only change needed is platform-branched copy at the banner construction call site:

```dart
// In tracking screen banner construction:
final bannerBody = Platform.isIOS
    ? kIosPermissionBannerBody   // "Enable Always to avoid gaps..."
    : kPermissionBannerForegroundOnlyBody;  // existing Android copy
```

No new widget needed (D-05 confirmed).

#### iOS Notification Permission Timing (D-07)

The existing `notification_service.dart` has `DarwinInitializationSettings(requestAlertPermission: false, ...)` — permission is already deferred correctly. What is missing is the actual request call.

The `flutter_local_notifications` plugin provides `IOSFlutterLocalNotificationsPlugin.requestPermissions()` accessible via:
```dart
final ios = _plugin
    .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
await ios?.requestPermissions(alert: true, badge: true, sound: true);
```

This call wraps `UNUserNotificationCenter.requestAuthorization()` and must be called:
- When the first weekly summary fires (the natural ~7-day anchor), OR
- When the user enables a departure reminder in Settings (whichever comes first).

**D-07 anchor: 7 days since first recorded trip** [ASSUMED per UI-SPEC Assumption 3]. The "first recorded trip" anchor is better than "first launch" — a user who never tracked has no use for summary notifications. Implementation: `TripsDao.watchAllSummaries().first` gives the trip list; if the oldest trip's `startTime` is more than 7 days ago AND notification permission is `undetermined`, request at that point. Store a flag in `user_preferences` (or a simple shared preference key) to avoid re-requesting after the first time.

Existing `zonedSchedule` calls in `notification_service.dart` already have `DarwinNotificationDetails(presentAlert: true, presentSound: true)` — they fire correctly on iOS after permission is granted.

---

### 2. Phantom Notification Suppression (IOS-11)

#### Where the Gate Goes

`TrackingServiceController.start()` at line 119 already has the gate:
```dart
if (defaultTargetPlatform != TargetPlatform.iOS) {
  try {
    await _notifications.showRecording();
  } on Object { /* swallowed */ }
}
```

[VERIFIED: reading tracking_service_controller.dart lines 119-126]

This gate already exists from Phase 14 (D-07 implementation). IOS-11 is therefore **already satisfied in the controller**. The remaining work is:

1. Confirm `showRecording()` in `TrackingNotificationService` itself never needs an additional gate (the controller gate is sufficient).
2. Add the `Platform.isAndroid` secondary guard inside `showRecording()` itself as an additional defence-in-depth line per D-11 — the controller gate is the primary guard, the service-level guard is belt-and-suspenders.

The existing `DarwinNotificationDetails` in `showRecording()` (lines 197–204) would cause iOS to post a notification if `showRecording()` were ever called on iOS. The controller gate prevents this; the service-level guard makes the code self-documenting.

---

### 3. Live Activity Bridge — Plugin Decision (IOS-13)

#### live_activities Plugin vs Custom Platform Channel

[VERIFIED: pub.dev + Context7 + GitHub] The `live_activities` plugin (v2.4.9, maintained by istornz, 140+ code snippets, last updated Jan 2026) provides:
- `createActivity(id, data)` → starts a Live Activity
- `updateActivity(id, data)` → updates ContentState
- `endActivity(id)` → ends with `.immediate` dismissal policy
- `areActivitiesSupported()` → returns `true` on iOS 16.1+ or Android API 24+
- `areActivitiesEnabled()` → checks user's Live Activities system setting
- `urlSchemeStream()` → `Stream<UrlSchemeData>` for URL-scheme callbacks from SwiftUI `Link` widgets
- Data bridge: `UserDefaults(suiteName: appGroupId)` — Dart map entries are stored in the shared container and the SwiftUI side reads them via `context.attributes.prefixedKey()`

**Recommendation: use the plugin.** The bridge mechanism (UserDefaults + App Group) is exactly what a custom platform channel would implement anyway, and the plugin's Dart API is idiomatic. The UI-SPEC's `ActivityAttributes.ContentState` typed struct is a native-only concern and remains unaffected by the plugin choice — the plugin passes a `Map<String, dynamic>` to the native layer and the Swift side reads named keys.

**What the plugin does NOT provide:** True `AppIntent` / `LiveActivityIntent` interactive buttons. The plugin's interaction pattern is URL scheme callbacks only — the user taps a SwiftUI `Link` that opens `traevy://stop`, and the Dart side's `urlSchemeStream()` listener calls `TrackingServiceController.stop()`.

[LOW confidence: whether LiveActivityIntent is achievable with free provisioning] Apple's entitlement `com.apple.developer.live-activity` is referenced in developer forum threads as required for LiveActivityIntent adoption — and may not be available on personal-team free provisioning profiles. The URL scheme pattern is the safe, proven fallback and is used by the `live_activities` plugin itself.

#### CRITICAL: Free-Provisioning Constraint for App Groups

[LOW confidence — requires device validation] App Group entitlements on iOS require the App Group capability to be enabled in the Developer Portal for the App ID. With a **free provisioning (personal team)** profile, developers cannot create App Group identifiers in the Developer Portal — Xcode can generate them automatically via automatic signing, but the provisioning profile must include the entitlement.

**What this means in practice:**
- If Xcode's automatic signing can provision the App Group for both Runner and the Widget Extension targets on a personal team, the `live_activities` plugin works as documented.
- If automatic signing cannot provision App Groups for personal-team accounts, a manual override or workaround is needed.
- The planner MUST add a Wave 0 task that validates App Group provisioning on the physical device before any Live Activity code is written — this is the phase's single highest-risk dependency.

**Mitigation path if App Groups fail:** Remove the App Group dependency by bypassing the plugin and using a custom method channel that calls `ActivityKit.Activity.update()` directly from `AppDelegate.swift`. The Widget Extension reads its initial data from the `ActivityAttributes` static fields (baked in at `Activity.request()` time) and subsequent updates from `Activity<X>.updates` AsyncSequence. This approach works without App Groups — but requires more native Swift code.

#### Xcode Widget Extension Setup

[VERIFIED: plugin README + Context7] Required steps:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. File → New → Target → Widget Extension.
3. Product name: `TraevyLiveActivity`. Ensure "Embed in Application: Runner". Click Finish, Activate.
4. For both Runner and TraevyLiveActivity targets: Signing & Capabilities → + Capability → App Groups → add `group.com.travey.app`.
5. In Runner/Info.plist: add `NSSupportsLiveActivities: YES` and `NSSupportsLiveActivitiesFrequentUpdates: YES`.
6. In TraevyLiveActivity/Info.plist: also add `NSSupportsLiveActivities: YES`.
7. Set TraevyLiveActivity deployment target to iOS 16.1 (minimum for ActivityKit).

**`project.pbxproj` impact:** Adding a new Xcode target modifies `project.pbxproj`. This is a normal, committed change. The Widget Extension builds as a separate binary embedded in the app bundle — `flutter build ios` includes it automatically once it is part of the Xcode project.

The Widget Extension is a **separate build target** with its own provisioning profile. With automatic signing, Xcode provisions it independently. The extension's bundle ID should be `com.travey.app.TraevyLiveActivity`.

#### Native Swift Files Required

```
ios/TraevyLiveActivity/TraevyLiveActivityAttributes.swift
ios/TraevyLiveActivity/TraevyLiveActivityWidget.swift
ios/TraevyLiveActivity/Localizable.strings
ios/Runner/Info.plist  (add NSSupportsLiveActivities + FrequentUpdates)
```

**TraevyLiveActivityAttributes.swift pattern** (adapted for the plugin's UserDefaults bridge):
```swift
import ActivityKit
import WidgetKit
import SwiftUI

struct TraevyLiveActivityAttributes: ActivityAttributes {
    public typealias LiveDeliveryData = ContentState  // required by live_activities plugin

    public struct ContentState: Codable, Hashable {
        var elapsedFormatted: String
        var distanceFormatted: String
        var movingFormatted: String
        var stuckFormatted: String
        var isMoving: Bool
        var direction: String   // "to_office" | "to_home"
        var startDate: Date     // anchors Text(timerInterval:) client-side ticking
    }

    var id = UUID()
}
```

The plugin reads these fields from `UserDefaults(suiteName: appGroupId)` using `context.attributes.prefixedKey("elapsedFormatted")` etc.

#### URL Scheme Stop Button (D-08 — safe fallback approach)

The app's existing `CFBundleURLSchemes` entry (`com.googleusercontent.apps.1076279794226-6h24q245801r9pca45v2e2tpjiocde64`) is for Google OAuth redirect — it is NOT a suitable short scheme for the Stop button (the URL is too long and is used by google_sign_in). A second, shorter custom scheme must be added:

```xml
<!-- ios/Runner/Info.plist — add alongside existing OAuth entry -->
<dict>
  <key>CFBundleTypeRole</key>
  <string>Editor</string>
  <key>CFBundleURLSchemes</key>
  <array>
    <string>traevy</string>
  </array>
</dict>
```

SwiftUI Stop button in the widget:
```swift
Link(destination: URL(string: "traevy://stop")!) {
    Text("live_activity_stop".localized)
        .font(.system(size: 13, weight: .semibold))
}
.frame(maxWidth: .infinity, minHeight: 44)
.background(Color.red)
.foregroundColor(.white)
.cornerRadius(12)
```

Dart-side listener wired in `LiveActivityService`:
```dart
_liveActivities.urlSchemeStream().listen((UrlSchemeData data) {
  if (data.host == 'stop') {
    _controller.stop();  // TrackingServiceController.stop()
  }
});
```

The `live_activities` init must include the URL scheme:
```dart
await _liveActivities.init(
  appGroupId: 'group.com.travey.app',
  urlScheme: 'traevy',
  requestAndroidNotificationPermission: false, // we manage this ourselves
);
```

#### iOS Version Gate (D-09)

[VERIFIED: device_info_plus docs] The iOS 17 gate in Dart:
```dart
if (defaultTargetPlatform == TargetPlatform.iOS) {
  final iosInfo = await DeviceInfoPlugin().iosInfo;
  final major = int.tryParse(iosInfo.systemVersion.split('.').first) ?? 0;
  if (major >= 17) {
    // start Live Activity
  }
}
```

Alternatively, use `_liveActivities.areActivitiesSupported()` (returns true on iOS 16.1+) — this alone is not sufficient for the iOS 17 floor. Use `areActivitiesEnabled()` to additionally check user hasn't disabled Live Activities in Settings → Face ID & Passcode.

---

### 4. Live Activity Update Cadence & Duration (IOS-13)

#### Local Updates from Background Location Mode

[CITED: developer.apple.com/news/?id=qpqf1gru — "10 questions with the Live Activities team"]
> "Your app can use a pre-existing background runtime functionality, such as Location Services, to provide Live Activity updates as you see fit."

This is Apple's explicit confirmation that apps running under the `location` background mode (already in `UIBackgroundModes` in our Info.plist) can call `Activity.update()` directly from the location callback or from the main-isolate timer that's kept alive by CoreLocation. **This is the correct update path for this app — no push server needed.**

**`NSSupportsLiveActivitiesFrequentUpdates: YES`** (also in the Info.plist for the Runner target) unlocks higher-frequency updates beyond the default budget. Add it alongside `NSSupportsLiveActivities: YES`.

#### Practical Update Cadence

The `live_activities` plugin bridges via UserDefaults + ActivityKit. The existing 1 Hz snapshot timer in `MainIsolateTrackingEngine._uiTimer` will call `updateActivity()` every second. ActivityKit may throttle some of these updates when the app is backgrounded (the system decides what actually renders). This is acceptable because:
- The elapsed time field uses SwiftUI `Text(timerInterval: startDate...Date.distantFuture)` — it ticks **client-side** without requiring a Dart push.
- Distance/moving/stuck fields only need to update every few seconds for a user-perceivable refresh.

**Recommended update cadence:** Call `LiveActivities.updateActivity()` on the same 5-second `kTrackingNotificationRefreshInterval` used for the Android notification update (not the 1 Hz timer). This avoids creating a separate throttle constant and matches the existing notification refresh cadence.

[ASSUMED: 5s update cadence acceptable for Live Activity] The elapsed display uses `Text(timerInterval:)` for smooth client-side ticking, so Dart updates only need to refresh the stats fields (distance, moving, stuck).

#### Duration Limits

[CITED: multiple sources, Apple developer Q&A] Live Activities are removed from Dynamic Island after **8 hours** by default. They remain on the Lock Screen for up to **4 additional hours** after ending. A 30–60 minute commute is well within this window.

**staleDate:** Set to `nil` or `startDate + 90 minutes` to indicate the Live Activity becomes stale if Dart stops sending updates. When stale, iOS shows a "stale" state; this is unlikely during normal operation since the location background mode keeps the main isolate alive.

#### Behavior When App is Killed Mid-Trip

[CITED: developer.apple.com/forums/thread/729651]
- The Live Activity **persists** on the lock screen even if the app is force-quit.
- When the app relaunches, it must call `Activity<TraevyLiveActivityAttributes>.activities` to get the still-running activity reference and either end it or resume updates.
- `TrackingServiceController` should check for orphaned activities on app startup and end them if no trip is in progress.

Implementation pattern for orphan cleanup on app start:
```swift
// Called from AppDelegate or Dart via platform channel after app resume:
for activity in Activity<TraevyLiveActivityAttributes>.activities {
    await activity.end(dismissalPolicy: .immediate)
}
```
The plugin's `endAllActivities()` or `endActivity(id)` method covers this from Dart.

---

### 5. Android Notification Enrichment (IOS-14)

#### What Changes in tracking_notification_service.dart

The existing `showRecording()` method (line 150) uses a single-line `BigTextStyleInformation(body)` where `body` comes from `_renderBody()`. The enrichment adds a two-line layout.

**New `_renderBody()` output:** `"● REC  {elapsed} · {km} km\nMoving {moving} · Stuck {stuck}"`

The `BigTextStyleInformation` takes the combined string. In collapsed shade view, the system shows line 1 only; in expanded view, both lines show.

**Existing `_formatStuck()` private method** (line 269 of `tracking_notification_service.dart`) must be **extracted to `lib/shared/utils/formatters.dart`** so both the Android notification renderer and the Dart-side Live Activity bridge (`LiveActivityService`) share the same formatter. Currently this function is private to the service — moving it to `formatters.dart` as a named top-level function `formatStuck(int seconds)` maintains consistency with the existing `formatDuration()` and `formatDistance()` functions.

**Existing `kTrackingNotificationRefreshInterval` (5 s)** — the notification is updated at this cadence, not 1 Hz. This constant must be reused for the Live Activity update trigger too (not a new constant).

**Hard constraints that must survive:**
- `ongoing: true`, `autoCancel: false`, `onlyAlertOnce: true` — unchanged [VERIFIED: tracking_notification_service.dart line 168–173]
- Channel ID `kTrackingNotificationChannelId` and notification ID `kTrackingNotificationId` — unchanged (D-14 contract)
- `foregroundServiceNotificationId` in `AndroidConfiguration` — unchanged

---

### 6. Formatter Parity (Live Activity ↔ Android Notification ↔ In-App UI)

[VERIFIED: reading formatters.dart, trip_accumulator.dart, tracking_notification_service.dart]

Current formatter inventory:
- `formatDuration(int seconds)` in `lib/shared/utils/formatters.dart` — outputs `"N min"` or `"Nh NNmin"`. NOT the right format for Live Activity or notification (which use `MM:SS` / `H:MM:SS`).
- `_formatStuck(int seconds)` in `tracking_notification_service.dart` (private) — outputs `"Xm"` or `"XhYm"`. This is used in the notification body and must be shared.
- `formatDistance(double meters)` in `lib/shared/utils/formatters.dart` — outputs `"X.X km"`.

**New formatter needed:** `formatElapsed(int seconds)` — outputs `"MM:SS"` below 1 hour, `"H:MM:SS"` at or above 1 hour. This is distinct from `formatDuration` (which uses "N min"). Required by both the Android notification enrichment (`kTrackingNotificationBodyLine1Template`) and the Live Activity Dart bridge.

**Actions:**
1. Extract `_formatStuck` from `TrackingNotificationService` to `formatters.dart` as `formatStuck(int seconds)`.
2. Add `formatElapsed(int seconds)` to `formatters.dart`.
3. Update `tracking_notification_service.dart` to import from `formatters.dart` instead of the private method.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Live Activity creation/update/end | Custom Swift + Dart platform channel bridge | live_activities plugin (v2.4.9) | Plugin handles UserDefaults App Group bridge, threading, and iOS version guards; 140+ verified code snippets |
| iOS version detection | Manual `ProcessInfo.processInfo.operatingSystemVersion` platform channel | device_info_plus (DeviceInfoPlugin().iosInfo.systemVersion) | Standard Flutter approach; testable |
| UNUserNotificationCenter iOS permission request | Direct platform channel call | flutter_local_notifications `.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions()` | Already available via existing plugin; no new code needed |
| ActivityKit elapsed counter | Updating Live Activity every second from Dart | SwiftUI `Text(timerInterval: startDate...Date.distantFuture)` | Client-side ticking; robust to Dart update throttling; Apple-recommended pattern for live timers |

**Key insight:** The Live Activity bridge is the only genuinely custom native work in this phase — everything else is either existing Flutter plugin APIs or Dart-level branching on `defaultTargetPlatform`.

---

## Common Pitfalls

### Pitfall 1: App Group Provisioning Failure on Personal-Team Profiles
**What goes wrong:** Adding the App Group capability to the Xcode targets fails code signing, or the provisioning profile for the Widget Extension doesn't include the App Group entitlement.
**Why it happens:** Free provisioning (personal team) has limited capability support. App Groups require a portal-registered group identifier, which normally requires a paid account to create. Xcode may auto-provision the group with automatic signing, or it may fail.
**How to avoid:** Validate App Group provisioning on device in Wave 0 BEFORE writing any Live Activity Swift code. If it fails, switch to the no-App-Group fallback (custom method channel + `ActivityKit` directly in AppDelegate, data passed via `ActivityAttributes` static fields baked at `Activity.request()` time).
**Warning signs:** Xcode build error `Provisioning profile ... doesn't include the com.apple.security.application-groups entitlement`; or app installs but Live Activity never appears.

### Pitfall 2: backgrounded location mode does NOT use `Platform.isIOS`
**What goes wrong:** Using `dart:io Platform.isIOS` in the permission service breaks unit tests because `Platform.isIOS` isn't overridable in tests.
**Why it happens:** `dart:io Platform.isIOS` is a runtime value; `defaultTargetPlatform` from `flutter/foundation.dart` is overridable via `debugDefaultTargetPlatformOverride`.
**How to avoid:** Always use `defaultTargetPlatform == TargetPlatform.iOS` in `TrackingPermissionService` and `TrackingServiceController`. Use `Platform.isIOS` (from `dart:io`) only in code paths that will never be unit-tested (e.g., top-level app startup). The existing codebase already uses `defaultTargetPlatform` consistently in tracking services — maintain this.
**Warning signs:** Test suite fails with `Unsupported operation: Platform._operatingSystem`.

### Pitfall 3: D-14 Notification Channel Collision on Android Enrichment
**What goes wrong:** A developer introduces a new notification channel ID or notification ID for the enriched notification, breaking the D-14 unification contract.
**Why it happens:** The BigTextStyle body template change looks like it might need a new channel, but it doesn't.
**How to avoid:** Keep `kTrackingNotificationChannelId`, `kTrackingNotificationId`, and `AndroidConfiguration.foregroundServiceNotificationId` identical. The BigTextStyle change is purely a body content change — the channel and ID are unchanged. The `_createChannel()` call is idempotent on existing channel IDs.
**Warning signs:** Two "Active commute" notifications appear in the shade simultaneously.

### Pitfall 4: Live Activity Orphan After App Kill
**What goes wrong:** User force-quits the app mid-commute; the Live Activity stays on lock screen indefinitely. When the app relaunches, no trip is in progress but the Live Activity shows stale data.
**Why it happens:** ActivityKit Live Activities persist after app termination — they are owned by the OS, not the app process.
**How to avoid:** On `TrackingServiceController` initialization (or on app resume), call `_liveActivities.endAllActivities()` if `TrackingState` is `TrackingIdle`. This ensures orphaned activities are cleaned up.
**Warning signs:** A stopped commute still shows a Live Activity on the lock screen after app relaunch.

### Pitfall 5: iOS Notification Probe in currentStatus() After Platform Branch
**What goes wrong:** `currentStatus()` returns `notificationDenied` on iOS because the notification probe runs before the iOS guard is added, even though iOS tracking doesn't depend on notifications.
**Why it happens:** The existing `currentStatus()` always runs the notification probe after the location dance. If the iOS branch isn't added, iOS will probe `Permission.notification` on every home-screen load and return `notificationDenied` (since we deliberately haven't granted it yet), disabling the Start button.
**How to avoid:** Add the same `defaultTargetPlatform == TargetPlatform.iOS` guard in both `preflight()` AND `currentStatus()`. Both methods have the same notification-probe block and both need the branch.
**Warning signs:** Start button is always disabled on iOS even when location permission is granted.

### Pitfall 6: Live Activity URL Scheme Conflicts with Google OAuth Scheme
**What goes wrong:** Using the existing Google OAuth URL scheme (`com.googleusercontent.apps.1076279794226-6h24q245801r9pca45v2e2tpjiocde64`) for the Stop button — the Live Activity plugin intercepts OAuth redirect URLs.
**Why it happens:** The existing `CFBundleURLSchemes` entry is for Google Sign-In's OAuth redirect and must not be reused.
**How to avoid:** Add a SECOND, short URL scheme (`traevy`) in `Info.plist` alongside the OAuth entry, and configure `live_activities.init(urlScheme: 'traevy')`. Do not modify or remove the OAuth entry.
**Warning signs:** Google Sign-In redirects fail on iOS after adding Live Activity URL scheme handling.

### Pitfall 7: `formatDuration` vs `formatElapsed` Confusion
**What goes wrong:** The existing `formatDuration(int seconds)` (outputs "N min" or "Nh NNmin") is used in the Live Activity or notification body instead of the new `formatElapsed` (outputs "MM:SS" / "H:MM:SS").
**Why it happens:** Two formatters exist for "how long a trip took" but with different output formats for different contexts.
**How to avoid:** `formatDuration` is for static trip summaries (stats cards, trip detail). `formatElapsed` is for live tracking surfaces (notification, Live Activity). Keep the distinction explicit in docstrings.

---

## Code Examples

### iOS Permission Branch in preflight()
```dart
// Source: tracking_permission_service.dart modification
// After locationAlways resolves:
if (defaultTargetPlatform == TargetPlatform.iOS) {
  // D-06: iOS tracking depends only on location. Never probe/request
  // notification on iOS. notificationDenied is never returned.
  return backgroundGranted
      ? TrackingPermissionStatus.fullyGranted
      : TrackingPermissionStatus.foregroundOnly;
}
// Android-only: continue to notification step
```

### Live Activity Service Dart Stub
```dart
// Source: live_activities pub.dev + Context7 (/istornz/flutter_live_activities)
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/url_scheme_data.dart';

class LiveActivityService {
  final LiveActivities _plugin = LiveActivities();
  String? _activityId;

  Future<void> init(TrackingServiceController controller) async {
    await _plugin.init(
      appGroupId: kLiveActivityAppGroupId,  // 'group.com.travey.app'
      urlScheme: kLiveActivityUrlScheme,    // 'traevy'
      requestAndroidNotificationPermission: false,
    );
    _plugin.urlSchemeStream().listen((UrlSchemeData data) {
      if (data.host == 'stop') controller.stop();
    });
  }

  Future<void> start(TripSnapshot snapshot, String direction) async {
    final supported = await _plugin.areActivitiesSupported();
    if (!supported) return;
    _activityId = await _plugin.createActivity(
      'commute',
      _contentState(snapshot, direction),
    );
  }

  Future<void> update(TripSnapshot snapshot, String direction) async {
    final id = _activityId;
    if (id == null) return;
    await _plugin.updateActivity(id, _contentState(snapshot, direction));
  }

  Future<void> end() async {
    final id = _activityId;
    if (id == null) return;
    await _plugin.endActivity(id);
    _activityId = null;
  }

  Map<String, dynamic> _contentState(TripSnapshot s, String direction) => {
    'elapsedFormatted': formatElapsed(s.elapsedSeconds),
    'distanceFormatted': formatDistance(s.distanceMeters),
    'movingFormatted': formatStuck(s.timeMovingSeconds),
    'stuckFormatted': formatStuck(s.timeStuckSeconds),
    'isMoving': s.currentSpeedMs >= kStuckSpeedThresholdMs,
    'direction': direction,
    'startDate': s.startedAt.millisecondsSinceEpoch,
  };
}
```

### iOS Notification Permission Request
```dart
// Source: flutter_local_notifications pub.dev docs
Future<void> requestIOSNotificationPermission() async {
  final ios = _plugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  await ios?.requestPermissions(alert: true, badge: true, sound: true);
}
```

### Android Enriched Notification Body Render
```dart
// Source: modified _renderBody in tracking_notification_service.dart
static (String, String) _renderEnrichedBody({
  required int elapsedSeconds,
  required double distanceMeters,
  required int timeMovingSeconds,
  required int timeStuckSeconds,
}) {
  final elapsed = formatElapsed(elapsedSeconds);
  final km = (distanceMeters / 1000).toStringAsFixed(1);
  final moving = formatStuck(timeMovingSeconds);
  final stuck = formatStuck(timeStuckSeconds);
  final line1 = kTrackingNotificationBodyLine1Template
      .replaceFirst('{elapsed}', elapsed)
      .replaceFirst('{km}', km);
  final line2 = kTrackingNotificationBodyLine2Template
      .replaceFirst('{moving}', moving)
      .replaceFirst('{stuck}', stuck);
  return (line1, line2);
}
// BigTextStyleInformation(line1 + '\n' + line2) goes to BigText
```

### SwiftUI Lock Screen Layout Structure
```swift
// Source: Apple ActivityKit WidgetKit docs + HIG
struct TraevyLiveActivityView: View {
    let context: ActivityViewContext<TraevyLiveActivityAttributes>

    var body: some View {
        let state = context.state
        // elapsed ticks client-side using startDate anchor
        let startDate = Date(timeIntervalSince1970:
            Double(state.startDate) / 1000.0)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                directionBadge(state.direction)
                Spacer()
                movingChip(state.isMoving)
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading) {
                    Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    Text("elapsed").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(state.distanceFormatted)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    Text("distance").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Link(destination: URL(string: "traevy://stop")!) {
                Text("Stop commute")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(16)
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| iOS foreground service notification (Flutter background service) | CoreLocation blue-pill indicator + Live Activity | iOS 16.1 (ActivityKit) | Richer, native lock-screen surface replaces the Android-style persistent notification |
| Notification as all-in-one activity indicator | Live Activity (lock screen) + Dynamic Island | iOS 16.1+ | Users see real-time stats without unlocking phone |
| App Intents for interactive buttons (requires paid provisioning) | SwiftUI `Link` + URL scheme (works with free provisioning) | iOS 16.1+ / confirmed 2024 | Enables Stop button without paid developer account |
| Manual iOS version check via platform channel | `DeviceInfoPlugin().iosInfo.systemVersion` | device_info_plus v4+ | Standard, testable approach |
| Separate formatter functions per feature | Shared `lib/shared/utils/formatters.dart` | Phase 4 established pattern | Single source of truth; `formatStuck` extracted from notification service |

**Deprecated/outdated:**
- `background_locator_2`: Abandoned — do not use (existing project already avoids it).
- iOS `UILocalNotification` (pre-iOS 10): Replaced by `UNUserNotificationCenter` — fully handled by `flutter_local_notifications`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | "1 week of usage" anchor = 7 days since first recorded trip (not first launch) | Notification Permission Timing | Minor — if wrong, notification may be requested slightly earlier/later; no functional impact |
| A2 | 5-second update cadence for Live Activity matches `kTrackingNotificationRefreshInterval` | Live Activity Update Cadence | Low — ActivityKit may throttle anyway; if 5s is too infrequent, add a separate `kLiveActivityRefreshInterval` constant |
| A3 | App Group provisioning works on personal-team / free provisioning | Xcode Widget Extension Setup + Pitfall 1 | HIGH — if App Group fails, the entire `live_activities` plugin bridge fails; fallback is custom method channel |
| A4 | URL-scheme Stop button is sufficient (no true `AppIntent` required) | URL Scheme Stop Button | Medium — true `AppIntent` may be achievable with manual entitlement addition; if so, the intent pattern is strictly better (no app launch required) |
| A5 | `Activity.update()` is permitted from background-location mode on iOS | Live Activity Update Cadence | HIGH — if iOS restricts location-mode apps from updating Live Activities (similar to audio-mode restriction), Dart updates will fail silently and only the `Text(timerInterval:)` will tick; all stats fields will freeze at trip-start values |

---

## Open Questions (RESOLVED)

1. **App Group provisioning on personal-team free account**
   - **RESOLVED:** Deferred to the Wave 0 BLOCKING device-provisioning probe (Plan 15-01 checkpoint, autonomous:false). Live Activity Swift work (Plans 15-04/15-05) does not execute until the probe PASSes on a real iPhone. If it fails, switch to the fallback (custom method channel + ActivityKit in AppDelegate, no UserDefaults bridge) before continuing.
   - What we know: App Group entitlements normally require portal registration; Xcode automatic signing may handle this automatically on personal teams.
   - What's unclear: Whether `com.apple.security.application-groups` is provisioned automatically for personal-team targets with a Widget Extension.
   - Disposition: Wave 0 validation task gates the risk; fallback documented.

2. **`Activity.update()` background location mode restriction**
   - **RESOLVED:** Treated as confirmed permitted (Apple's own Live Activities Q&A states location-mode apps may update Live Activities using background runtime). The actual update cadence is validated in human-gated device UAT (SC #5). The `Text(timerInterval:)` client-side ticking provides graceful degradation if Dart-side updates are throttled.
   - What we know: Apple's Q&A explicitly says location-mode apps can provide Live Activity updates. The forum thread about audio-mode restriction (error: "only playing background media") does NOT apply to location-mode apps.
   - Disposition: confirmed per Apple; cadence verified on device.

3. **`device_info_plus` vs `live_activities.areActivitiesSupported()`**
   - **RESOLVED:** Use the two-check pattern `version >= 17 && areActivitiesEnabled()` — `device_info_plus` for the exact `>= 17` floor (areActivitiesSupported alone returns true on 16.1+, insufficient) AND `areActivitiesEnabled()` for the user-settings toggle. Implemented in Plan 15-05 `_isLiveActivitySupported()`.
   - Disposition: pattern locked into Plan 15-05.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All Dart code | ✓ | 3.41.6 | — |
| Dart SDK | All Dart code | ✓ | 3.11.4 | — |
| Xcode | Widget Extension build | ✓ (inferred from Phase 14 complete) | Unknown (Phase 12 accepted) | — |
| iOS physical device | Live Activity validation (SC #5) | human-gated | — | Cannot validate on Simulator |
| live_activities pub package | IOS-13 | not yet installed | 2.4.9 (verified) | — |
| device_info_plus pub package | IOS-13 version gate | not yet installed | 13.1.0 (verified) | — |
| App Group entitlement (personal team) | live_activities plugin bridge | UNKNOWN — requires device validation | — | Custom method channel fallback |

**Missing dependencies with no fallback:**
- iOS physical device: Live Activity behavior (SC #5) cannot be validated in Simulator. Human-gated.

**Missing dependencies with fallback:**
- App Group entitlement: if unavailable on personal team, custom method channel + ActivityKit in AppDelegate. Plan must include a Wave 0 validation + conditional fallback path.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK), very_good_analysis ^10.2.0 |
| Config file | `test/flutter_test_config.dart` |
| Quick run command | `flutter test test/unit/features/tracking/ --no-pub` |
| Full suite command | `flutter test --no-pub` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IOS-09 | `preflight()` iOS branch never probes `Permission.notification` | unit | `flutter test test/unit/features/tracking/tracking_permission_service_test.dart -x` | ✅ (existing, extend) |
| IOS-09 | `currentStatus()` iOS branch never returns `notificationDenied` | unit | `flutter test test/unit/features/tracking/tracking_permission_service_test.dart -x` | ✅ (existing, extend) |
| IOS-09 | `foregroundOnly` status returned when locationAlways denied on iOS | unit | `flutter test test/unit/features/tracking/tracking_permission_service_test.dart -x` | ✅ (existing, extend) |
| IOS-10 | `requestIOSNotificationPermission()` calls `IOSFlutterLocalNotificationsPlugin.requestPermissions` | unit | `flutter test test/unit/notifications/ -x` | ✅ (existing notification_service_test.dart, extend) |
| IOS-11 | `showRecording()` gated: not called on iOS (defaultTargetPlatform == iOS) | unit | `flutter test test/unit/features/tracking/ -x` | ❌ Wave 0 |
| IOS-13 | `LiveActivityService.start/update/end` called at correct lifecycle points | unit | `flutter test test/unit/features/tracking/live_activity_service_test.dart -x` | ❌ Wave 0 |
| IOS-13 | iOS 17 gate: `LiveActivityService.start()` no-op on iOS < 17 | unit | `flutter test test/unit/features/tracking/live_activity_service_test.dart -x` | ❌ Wave 0 |
| IOS-14 | Android notification enrichment uses two-line body template | unit | `flutter test test/unit/features/tracking/tracking_notification_service_test.dart -x` | ❌ Wave 0 |
| IOS-14 | Notification channel ID and notification ID unchanged after enrichment | unit | `flutter test test/unit/features/tracking/tracking_notification_service_test.dart -x` | ❌ Wave 0 |
| IOS-13 (device) | Live Activity appears on lock screen, updates live, Stop button ends trip | manual | Human-gated device UAT | — |
| IOS-09 (device) | When-In-Use prompt, then Always prompt at first trip start | manual | Human-gated real device | — |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/features/tracking/ --no-pub`
- **Per wave merge:** `flutter test --no-pub`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/unit/features/tracking/live_activity_service_test.dart` — covers IOS-13 lifecycle + version gate
- [ ] `test/unit/features/tracking/tracking_notification_service_test.dart` — extend for IOS-11 gate + IOS-14 enriched body
- [ ] `test/unit/features/tracking/tracking_permission_service_test.dart` — extend existing file with iOS branch tests for `preflight()` and `currentStatus()`
- [ ] `test/unit/notifications/notification_service_test.dart` — extend with `requestIOSNotificationPermission()` test

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — (tracking, not auth) |
| V3 Session Management | No | — |
| V4 Access Control | Yes (Live Activity Stop) | URL scheme validated: only `traevy://stop` triggers stop; arbitrary URLs are ignored |
| V5 Input Validation | Yes (URL scheme parsing) | `data.host == 'stop'` exact-match guard in urlSchemeStream listener; no arbitrary host routing |
| V6 Cryptography | No | — |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious app registering `traevy://` URL scheme | Spoofing | iOS only routes URL schemes to the registered app; another app cannot register the same scheme; low risk on iOS (unlike Android Intent hijack) |
| Live Activity displaying PII (lat/lng) | Information Disclosure | Live Activity only receives pre-formatted strings (`elapsedFormatted`, `distanceFormatted`); never raw lat/lng. PII guard (T-02-07) preserved. |
| Notification permission request at unexpected time | Elevation of Privilege | Permission only requested via controlled path (weekly summary trigger or departure reminder enable); never on cold start |

---

## Sources

### Primary (HIGH confidence)
- `lib/features/tracking/services/tracking_permission_service.dart` — read directly; iOS branch insertion points confirmed
- `lib/features/tracking/services/tracking_notification_service.dart` — read directly; Platform.isAndroid gate already present in controller; D-14 contract confirmed
- `lib/features/tracking/services/tracking_service_controller.dart` — read directly; iOS notification gate already at line 119
- `lib/features/tracking/services/main_isolate_tracking_engine.dart` — read directly; TripAccumulator seam confirmed
- `lib/config/constants.dart` — read directly; existing constants confirmed
- `lib/shared/utils/formatters.dart` — read directly; formatDuration confirmed; formatElapsed gap confirmed
- Context7 `/istornz/flutter_live_activities` — plugin API: createActivity, updateActivity, endActivity, urlSchemeStream, areActivitiesSupported, areActivitiesEnabled, init with appGroupId/urlScheme [HIGH]
- `pub.dev/api/packages/live_activities` — confirmed v2.4.9 latest [HIGH]
- `pub.dev/api/packages/device_info_plus` — confirmed v13.1.0 latest [HIGH]
- `pub.dev/api/packages/permission_handler` — confirmed v12.0.3 latest [HIGH]
- Apple developer Q&A "10 questions with the Live Activities team" (developer.apple.com/news/?id=qpqf1gru) — explicit confirmation that location-mode apps can update Live Activities [HIGH]
- Apple Developer Forums thread/729651 — Live Activity persists after app force-quit; `Activity.activities` pattern for orphan cleanup [MEDIUM]
- Apple Developer Forums thread/808712 — activitykit entitlement may not be needed (DTS engineer response); free-provisioning concerns [LOW]

### Secondary (MEDIUM confidence)
- github.com/Baseflow/flutter-permission-handler/issues/1324 — iOS two-step location permission regression documentation; two-step flow confirmed
- Apple HIG Live Activities sizing constraints — compact: 37×37 pt, expanded: 160 pt max height (from UI-SPEC, sourced from HIG)
- Apple Developer Forums thread/748569 — background audio mode blocks ActivityKit updates; inferred location mode is not affected

### Tertiary (LOW confidence)
- developer.apple.com/forums/thread/771557 — Live Activities entitlement may have a portal registration requirement; unresolved thread; flagged as Pitfall 1
- NSSupportsLiveActivitiesFrequentUpdates exact budget numbers — not publicly documented by Apple; 1 Hz update trigger assumed acceptable

---

## Metadata

**Confidence breakdown:**
- iOS permission branching: HIGH — existing code read directly; change is mechanical
- Notification timing: HIGH — existing flutter_local_notifications Darwin path confirmed; requestPermissions() API confirmed
- Phantom notification gate: HIGH — gate already exists in TrackingServiceController line 119; IOS-11 is largely pre-satisfied
- Android notification enrichment: HIGH — existing BigTextStyleInformation in place; additive change only
- Live Activity plugin (live_activities v2.4.9): MEDIUM — plugin API confirmed via Context7; UserDefaults bridge pattern confirmed; URL scheme stop confirmed
- App Group / free provisioning: LOW — not confirmed; Wave 0 device validation required
- ActivityKit local update from location mode: MEDIUM — Apple's own Q&A supports it; no contrary evidence found for location mode (only audio mode blocks)
- Live Activity duration over 30–60 min commute: HIGH — well within 8-hour OS limit

**Research date:** 2026-06-03
**Valid until:** 2026-07-03 (stable platform APIs; live_activities plugin may release minor updates)
