# Pitfalls Research

**Domain:** Flutter iOS port of an Android GPS-tracking commute app (geolocator + flutter_background_service, firebase_auth + google_sign_in 7.x, flutter_local_notifications 21, flutter_secure_storage 10.3, Drift, flutter_map)
**Researched:** 2026-06-02
**Confidence:** MEDIUM-HIGH (training data + live web verification against official docs and GitHub issues)

---

## Scope Note

This document covers pitfalls for **milestone v0.2 only**: porting the existing Android-first Flutter app to iOS. The target is a real iPhone (free 7-day Xcode provisioning, no App Store submission this milestone). The existing Android-first PITFALLS.md covers the original v0.1 Android pitfalls — this file does not repeat them.

---

## Critical Pitfalls

### Pitfall 1: iOS Suspends the App — flutter_background_service Does NOT Keep GPS Alive

**What goes wrong:**
On Android, `flutter_background_service` runs a foreground service that iOS has no equivalent for. On iOS, the plugin's `onBackground` callback is invoked by the OS's Background Fetch mechanism — which fires at most every 15 minutes and runs for only 15–30 seconds. If you configure the service the same way you do on Android (expecting a persistent isolate), GPS recording silently stops the moment the user locks their iPhone. Trips get truncated. The app appears to work on the iOS Simulator (which does not enforce background suspension) and then catastrophically fails on a real device.

**Why it happens:**
iOS does not expose a persistent background service primitive analogous to Android's `START_STICKY` foreground service. The only approved mechanism for continuous background GPS is the CoreLocation `UIBackgroundModes: location` capability, combined with `allowsBackgroundLocationUpdates = true` on the `CLLocationManager` instance. `flutter_background_service` does not configure this natively — it wraps Background Fetch. The geolocator plugin *does* support iOS background location mode, but you must configure it explicitly via `AppleSettings` and enable the Xcode Background Modes capability.

**How to avoid:**
1. On iOS, do NOT rely on `flutter_background_service` for GPS continuity. Use `geolocator`'s own iOS background location support instead.
2. In `Xcode → Runner → Signing & Capabilities`, add the **Background Modes** capability and check **Location updates**.
3. In `Info.plist`, add `UIBackgroundModes` with the string `location`.
4. Pass `AppleSettings` to `getPositionStream` with `allowsBackgroundLocationUpdates: true` and `showsBackgroundLocationIndicator: true`.
5. Set `pausesLocationUpdatesAutomatically: false` (see Pitfall 2 for why this is a separate pitfall).
6. Use platform-conditional code: keep `flutter_background_service` for Android only; on iOS let geolocator's native background mode carry the stream.

**Warning signs:**
- Trip GPS trace ends within 30 seconds of locking the iPhone
- iOS Simulator tests pass but first real-device test breaks
- `flutter_background_service` initialized identically on both platforms with no `if (Platform.isIOS)` branching

**Phase to address:** iOS Platform Scaffolding / GPS porting phase (the very first iOS implementation phase — this must be solved before any other iOS feature is testable)

**Safe to defer?** No. This is the single most load-bearing iOS gotcha. Everything else depends on GPS working.

---

### Pitfall 2: pausesLocationUpdatesAutomatically Silently Kills Mid-Trip Recording

**What goes wrong:**
`CLLocationManager.pausesLocationUpdatesAutomatically` is `true` by default in iOS CoreLocation. When the device detects that the user is "not moving" (e.g., parked at a red light for 90+ seconds, or walking slowly), iOS pauses location updates to save battery. Once paused, updates do not resume until the user moves significantly. For a commuter stuck in traffic — exactly the scenario this app measures — iOS will suspend GPS at the worst possible moment. The trip log shows a gap during the stationary period, making "time stuck in traffic" calculations completely wrong.

**Why it happens:**
The default is designed for fitness apps that want to save battery when a runner stops. It is the wrong default for a commuter tracking app. `geolocator`'s `AppleSettings` exposes `pausesLocationUpdatesAutomatically` and it must be explicitly set to `false`.

**How to avoid:**
Configure `AppleSettings` like this when starting the position stream:
```dart
if (Platform.isIOS) {
  return Geolocator.getPositionStream(
    locationSettings: AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: 0,
      pausesLocationUpdatesAutomatically: false,  // CRITICAL
      allowsBackgroundLocationUpdates: true,
      showsBackgroundLocationIndicator: true,
    ),
  );
}
```
The `activityType: ActivityType.automotiveNavigation` hint also helps CoreLocation optimize for vehicle movement rather than pedestrian patterns.

**Warning signs:**
- Trip polyline has unexplained gaps during slow traffic sections
- GPS resumes after the vehicle starts moving again (confirming it was paused, not killed)
- "Time stuck" is dramatically under-reported because GPS drops during standstill
- Problem only reproducible on real device, not simulator

**Phase to address:** GPS porting phase (same phase as Pitfall 1 — these are tightly coupled)

**Safe to defer?** No. Getting this wrong produces systematically wrong traffic data, which breaks the app's core value proposition.

---

### Pitfall 3: The Persistent Blue Location Indicator — UX Surprise and App Review Risk

**What goes wrong:**
When an iOS app accesses location in the background, the system displays a blue bar (or blue dot in the Dynamic Island on iPhone 14 Pro+) at the top of the screen. This appears whenever the app is backgrounded and tracking is active. Users who have not been warned about this interpret it as a privacy violation. On older devices without Dynamic Island, it is a persistent blue banner that interrupts other apps. Additionally, if you request `NSLocationAlwaysAndWhenInUseUsageDescription` without explaining why background location is needed, Apple's review team may reject the app.

**Why it happens:**
iOS requires the blue indicator for any app using background location — this cannot be suppressed. Setting `showsBackgroundLocationIndicator: false` in `AppleSettings` disables the indicator *while tracking in the background* when using "When In Use" authorization mode, but with "Always" authorization you cannot remove it. The indicator exists to ensure users know location is being used.

**How to avoid:**
1. Set `showsBackgroundLocationIndicator: true` in `AppleSettings` explicitly — hiding it creates a mismatch that can cause review issues.
2. On the onboarding screen, explain the blue indicator before it appears: "While tracking your commute, a blue indicator appears to show your location is in use. This is a required iOS privacy feature."
3. In `Info.plist`, write a clear `NSLocationAlwaysAndWhenInUseUsageDescription`: "Commute Tracker records your route while you commute, including when the app is in the background, to accurately measure time spent in traffic."
4. Keep the indicator duration minimal: only enable background location when a trip is actively recording. Stop the location stream (and the indicator) as soon as tracking stops.

**Warning signs:**
- No mention of the blue indicator in onboarding copy
- Background location mode left enabled after trip stops (indicator persists unnecessarily)
- `NSLocationAlwaysAndWhenInUseUsageDescription` string is generic or missing

**Phase to address:** iOS onboarding / permissions phase

**Safe to defer?** Partially. The indicator cannot be avoided. The UX explanation copy can be refined post-launch, but the `Info.plist` description must be accurate before any real-device testing.

---

### Pitfall 4: iOS "Always" Location Authorization UX — The Two-Step Gotcha

**What goes wrong:**
iOS 13+ does not allow apps to jump directly to "Always" authorization in a single permission prompt. The system forces the app to first request "When In Use" and then separately escalate to "Always." If you call `Geolocator.requestPermission()` and immediately expect `LocationPermission.always` back, it will return `LocationPermission.whileInUse` on the first request. The "Always" authorization is only grantable from the Settings app (iOS 13) or from a second system prompt that iOS shows at its discretion (iOS 14+). Many developers miss this and leave the app requiring "Always" but never guiding users to grant it.

**Why it happens:**
Apple deliberately restricts direct "Always" prompts to protect user privacy. On iOS 13, the permission dialog shows only "Allow Once," "Allow While Using App," and "Don't Allow." The user can later upgrade to "Always" in Settings. On iOS 14+, a second prompt may appear from the OS after the user has used the "When In Use" permission for a period — but this is at the OS's discretion, not the app's.

**How to avoid:**
1. During onboarding, request "When In Use" first. Confirm the stream works before escalating.
2. After "When In Use" is granted, check `Geolocator.checkPermission()`. If it returns `whileInUse`, show an explicit in-app explanation screen: "For background trip tracking, tap 'Always Allow' in the next screen." Then call `requestPermission()` again to trigger the escalation prompt.
3. If the user lands on "While Using" and does not upgrade, deep-link to Settings: `await Geolocator.openAppSettings()`. Show a banner explaining why "Always" is needed.
4. Handle the case where the user permanently denies "Always": fall back gracefully, explaining that trips will only be recorded when the app is in the foreground.
5. Add a permission-status indicator in Settings screen so users can see their current authorization level.

**Warning signs:**
- Permission request code does not branch between "whileInUse" and "always" return values
- No in-app explanation between the first and second permission prompt
- App crashes or fails silently when `LocationPermission.whileInUse` is returned instead of `LocationPermission.always`
- No Settings deep-link for permanently denied permission

**Phase to address:** iOS onboarding / permissions phase

**Safe to defer?** No. Without correct "Always" authorization, background GPS (Pitfall 1) cannot work at all.

---

### Pitfall 5: Accuracy Authorization on iOS 14+ — Reduced Accuracy Breaks Traffic Calculation

**What goes wrong:**
iOS 14 introduced a second location permission axis: Precise vs. Reduced Accuracy. When a user grants location permission but selects "Approximate Location" (Reduced Accuracy), CoreLocation delivers positions with 1–10 km accuracy, updated 4 times per hour. This renders trip distance, route polyline, and speed-based traffic calculation completely unusable — but the app receives location updates without errors. Speed values will be near zero or wildly inconsistent.

**Why it happens:**
Geolocator 7.3.0+ (and 14.0.x is the version in this project) exposes `getLocationAccuracy()` returning `LocationAccuracyStatus.reduced` or `LocationAccuracyStatus.precise`. If you do not check this, reduced-accuracy positions silently corrupt trip data.

**How to avoid:**
1. After location permission is granted, call `await Geolocator.getLocationAccuracy()`. If it returns `LocationAccuracyStatus.reduced`, block trip recording and show an explanation.
2. Call `await Geolocator.requestTemporaryFullAccuracy(purposeKey: 'commute_tracking')` with a corresponding key in `Info.plist` under `NSLocationTemporaryUsageDescriptionDictionary`. This shows a system dialog requesting temporary precise access.
3. Add the `NSLocationTemporaryUsageDescriptionDictionary` plist key with a meaningful description: "Commute Tracker needs precise location to accurately measure your route and time spent in traffic."
4. In onboarding, explicitly tell users to select "Precise Location" when prompted.

**Warning signs:**
- No `Geolocator.getLocationAccuracy()` call anywhere in the codebase
- Trip distances reporting as 0 or unrealistically large values
- Speed always near 0 despite the user commuting
- No `NSLocationTemporaryUsageDescriptionDictionary` in Info.plist

**Phase to address:** iOS onboarding / permissions phase (same phase as Pitfall 4)

**Safe to defer?** No. This breaks the core traffic-time feature on iOS 14+ devices, which is the entire target market.

---

### Pitfall 6: CocoaPods / Podfile Minimum Deployment Target Trap

**What goes wrong:**
When `flutter create --platforms=ios` generates the `ios/` folder, the default `Podfile` sets `platform :ios, '12.0'` (or sometimes lower). Several packages in this project require higher minimum versions: `firebase_core` 4.x requires iOS 13+, `geolocator` 14.x requires iOS 12+, `flutter_local_notifications` 21 requires iOS 12+, and `flutter_background_service` 5.x requires iOS 12+. The build fails with messages like "The plugin X requires a higher minimum iOS deployment target." The fix is setting `platform :ios, '13.0'` in the Podfile AND setting the `IPHONEOS_DEPLOYMENT_TARGET` in `ios/Runner.xcodeproj` to match. If only one is updated, the mismatch causes cryptic linker errors.

Additionally, there is a second-level trap: pods themselves may have transitive dependencies requiring higher deployment targets. The standard fix is a `post_install` hook in the Podfile that sets all pod targets to the app's minimum:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

**Why it happens:**
Flutter generates a conservative Podfile. Package maintainers raise minimum deployment targets as the ecosystem moves forward but do not always loudly announce it. The mismatch between the Podfile `platform` line, the Xcode project `IPHONEOS_DEPLOYMENT_TARGET`, and the pod requirements causes build failures that surface late (after `pod install` succeeds but Xcode build fails).

**How to avoid:**
1. Set `platform :ios, '13.0'` in the Podfile from the start. iOS 13 is the minimum for this dependency set.
2. Set `IPHONEOS_DEPLOYMENT_TARGET = 13.0` in `ios/Runner.xcodeproj/project.pbxproj` (or via Xcode Build Settings).
3. Add the `post_install` hook above to ensure all transitive pod dependencies are also set to 13.0.
4. Run `flutter build ios --no-codesign` after any `pod install` to catch deployment target mismatches early.

**Xcode 26 / SPM context:** Firebase will stop publishing to CocoaPods in October 2026. Flutter 3.44 introduces SPM as the default. For this milestone (targeting Xcode 26.5), geolocator and other plugins that still use CocoaPods will coexist with Firebase SPM packages. Do NOT mix CocoaPods and SPM in the same Xcode target — Firebase via SPM should be isolated. The `flutterfire configure` command handles this automatically. If manual editing is needed, check whether any `Podfile` entries for `firebase_core` conflict with the SPM resolution.

**Warning signs:**
- `pod install` succeeds but `flutter build ios --no-codesign` fails with deployment target errors
- Error message: "The plugin X requires a higher minimum iOS deployment version than your application is targeting"
- Xcode shows a yellow warning: "Runner project's deployment target is set to X, which is lower than required..."
- Linker errors referencing `_OBJC_CLASS_$_` symbols from Firebase

**Phase to address:** iOS platform scaffolding phase (before any other iOS work)

**Safe to defer?** No. Build infrastructure must be correct before any feature work begins.

---

### Pitfall 7: google_sign_in 7.x Reversed-Client-ID URL Scheme Misconfiguration

**What goes wrong:**
Google Sign-In on iOS requires a custom URL scheme registered in `Info.plist` — specifically the reversed client ID from `GoogleService-Info.plist`. This is how Google's OAuth flow redirects back to the app after authentication in Safari. If this URL scheme is missing, the sign-in flow opens a browser, the user authenticates, and then the browser cannot redirect back to the app. The user sees a white browser screen. The app waits indefinitely. No error is surfaced.

With `google_sign_in` 7.x and `firebase_auth` 6.x, there are two valid configuration approaches. Both require matching the `REVERSED_CLIENT_ID` from `GoogleService-Info.plist`.

**How to avoid:**
1. Open `GoogleService-Info.plist` and copy the value of `REVERSED_CLIENT_ID` (it looks like `com.googleusercontent.apps.XXXXXXXXXX-xxxx...`).
2. In `Info.plist`, add:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID_HERE</string>
    </array>
  </dict>
</array>
<key>GIDClientID</key>
<string>YOUR_IOS_CLIENT_ID_FROM_GOOGLESERVICE_INFO_PLIST</string>
```
3. Alternatively (and more robustly for this project since `firebase_options.dart` already exists), pass `clientId` programmatically in Dart: `GoogleSignIn(clientId: DefaultFirebaseOptions.currentPlatform.iosClientId)`. However, the URL scheme in `Info.plist` is STILL required even with this approach — it controls the redirect, not the client ID.
4. After adding the URL scheme, test sign-in on a real device. The iOS Simulator sometimes handles redirects differently due to browser app availability.

**Warning signs:**
- Google sign-in opens Safari or SFSafariViewController but never returns to the app
- No `CFBundleURLTypes` entry in `Info.plist`
- `CFBundleURLSchemes` array contains the client ID verbatim instead of the reversed version (a common copy-paste error)
- Sign-in works on Android but not iOS (the two platforms use entirely different OAuth redirect mechanisms)

**Phase to address:** iOS auth phase

**Safe to defer?** No. Auth is a hard dependency for sync and restore features.

---

### Pitfall 8: GoogleService-Info.plist vs firebase_options.dart Mismatch

**What goes wrong:**
The project already has a Firebase iOS app registered and `firebase_options.dart` generated. When the `ios/` folder is created, `GoogleService-Info.plist` must be placed at `ios/Runner/GoogleService-Info.plist` with bundle ID, client ID, and project ID that exactly match `firebase_options.dart` and the Xcode project's bundle ID. Any mismatch causes Firebase initialization to fail silently or throw `FirebaseException: No Firebase app '[DEFAULT]' has been created`. Mismatches happen when:
- The `ios/` folder is generated with a different bundle ID than what was registered in Firebase Console
- An old `GoogleService-Info.plist` from a dev/staging environment is reused
- `flutterfire configure` is run again and updates `firebase_options.dart` but the `.plist` in the Xcode project is stale (a known bug in `flutterfire_cli`)

**How to avoid:**
1. Before creating the `ios/` folder, confirm the bundle ID that will be used (e.g., `com.yourcompany.commutetracker`) and ensure a Firebase iOS app with that exact bundle ID exists in Firebase Console.
2. After `flutter create --platforms=ios`, run `flutterfire configure` again to regenerate both `firebase_options.dart` AND `GoogleService-Info.plist` for the iOS target simultaneously.
3. Verify that `BUNDLE_ID` in `GoogleService-Info.plist` matches the `CFBundleIdentifier` in `Info.plist` and the bundle ID in Xcode's Signing & Capabilities.
4. After `pod install` and before testing auth, add a startup assertion: `assert(Firebase.app().options.iosClientId != null)`.
5. Check `firebase.json` in the project root — `flutterfire_cli` tracks configured platforms here. If iOS is missing, run configure again.

**Warning signs:**
- `FirebaseException: No Firebase app '[DEFAULT]'` at startup
- Google Sign-In returns error code 10 (developer error) — this always means a bundle ID or SHA/client ID mismatch
- `firebase_options.dart` has `iosClientId` field but it does not match `CLIENT_ID` in `GoogleService-Info.plist`
- `GOOGLE_APP_ID` in `GoogleService-Info.plist` differs from `appId` in `firebase_options.dart`

**Phase to address:** iOS platform scaffolding phase (must be verified before auth phase begins)

**Safe to defer?** No. A Firebase config mismatch blocks all auth and sync functionality.

---

### Pitfall 9: Free 7-Day Provisioning Expiry and Developer Mode Requirements

**What goes wrong:**
Without a paid Apple Developer account, a Xcode-signed app installed on a physical iPhone expires after exactly 7 days. After expiry, the app refuses to launch with the message "App is no longer available." For a milestone that involves commute testing — which requires multiple real-device sessions over days — this is a practical blocker. Additionally, iPhones running iOS 16+ require Developer Mode to be enabled before they can run a Xcode-signed build. If Developer Mode is not enabled when the device is first connected, the option does not appear in Settings until the device is paired with Xcode.

**Why it happens:**
Free Apple Developer accounts use development certificates limited to 7-day provisioning profiles. The Developer Mode requirement (iOS 16+) is a security gate that Apple added to prevent non-developer users from inadvertently running potentially harmful development builds.

**How to avoid:**
1. **Enable Developer Mode first.** Connect the iPhone to the Mac with Xcode open. iOS will prompt a security dialog. In iPhone Settings → Privacy & Security → Developer Mode, toggle it on. The phone requires a restart and a confirmation tap. This sequence must be done before the first `flutter run` attempt.
2. **7-day expiry workflow:** When the app expires, simply re-run from Xcode (`flutter run` or Product → Run). Xcode automatically re-signs and re-installs. The actual trip data (Drift SQLite database) survives because it is in the app's documents sandbox — it is not deleted on reinstall unless you delete the app manually.
3. **Trust the developer certificate on device.** After the first install, go to iPhone Settings → General → VPN & Device Management → your Apple ID → Trust. This step is required every time a new development certificate is used (i.e., after ~365 days or if the certificate is regenerated).
4. Document the 7-day cadence in the milestone README so the developer knows to re-run from Xcode mid-milestone if the app stops launching.

**Warning signs:**
- App launches on day 1 but shows "no longer available" a week later
- Developer Mode toggle missing from Settings (device not yet paired with Xcode)
- "Unable to install" error during first `flutter run` (certificate not trusted)
- Simulator passes all tests but first real-device run fails at launch

**Phase to address:** iOS platform scaffolding phase (before any feature work; first-time device setup)

**Safe to defer?** The setup is one-time. The 7-day renewal is an ongoing workflow concern for the duration of v0.2 development.

---

### Pitfall 10: Sign In With Apple — Required at App Store Submission, Not This Milestone

**What goes wrong:**
Apple's App Store Review Guideline 4.8 (Login Services) requires that any app using a third-party login (Google Sign-In qualifies) must also offer an alternative login with comparable privacy features. In practice, this means Sign In With Apple. **This is NOT required to run the app on a physical device via free provisioning.** It is only enforced at App Store submission. Building Sign In With Apple now would add scope and complexity to a milestone focused on feature parity, not distribution.

**Why it's flagged:**
If not planned, it will be a surprise blocker when the App Store submission milestone arrives. The `sign_in_with_apple` Flutter package requires an Apple Developer account (paid) for the entitlement, an ASAuthorizationAppleIDProvider server-side verification endpoint, and handling the case where Apple hides the user's email after first sign-in.

**How to avoid (deferred to submission milestone):**
1. Add `sign_in_with_apple` package and implement the auth flow alongside existing Google Sign-In.
2. Register the "Sign In with Apple" capability in Apple Developer portal (requires paid account).
3. Store the Apple user identifier (not email, which is hidden after first sign-in) in Drift and link it to the Firebase user.
4. Handle the email-only-on-first-sign-in constraint: capture and store the email the first time, never expect it again.

**Phase to address:** App Store submission milestone (future, beyond v0.2)

**Safe to defer?** YES — explicitly safe to defer until App Store submission. Free provisioning + sideloading does not require it.

---

### Pitfall 11: iOS Simulator GPS Is Useless for Traffic Calculation Testing

**What goes wrong:**
The iOS Simulator can inject a static "simulated location" (e.g., Apple HQ coordinates) or play back a GPX file. However, it cannot reliably simulate realistic commute speeds, variable GPS accuracy, or the speed field populated by the CoreLocation Doppler measurement. The simulated speed in the `CLLocation.speed` field during Simulator GPX playback is often 0.0 or calculated from point-to-point distance with unrealistic smoothing. This means all traffic calculation logic that depends on speed thresholds (< 10 km/h = stuck) cannot be validated in the Simulator. This is the iOS equivalent of the Android emulator GPS warning already documented in the v0.1 pitfalls.

**Why it happens:**
The iOS Simulator is a CPU emulator running a simulated OS, not hardware emulation. It has no GPS chipset to produce Doppler-derived speed. GPX file playback interpolates between waypoints, but the speed value in the `CLLocation` object depends on the file having explicit `<speed>` tags — which most GPX files lack.

**How to avoid:**
1. Test traffic calculation (speed-based time bucketing) only on a real iPhone, during real commutes.
2. For CI/automated testing, unit test the speed classification algorithm in isolation (pass mock `Position` objects with explicit speed values).
3. Do not use Simulator GPS output as a signal that traffic calculation works. Use it only to verify that the location stream is established and the UI responds to position updates.
4. When testing on device, record at least 2–3 full real commutes before declaring the traffic calculation correct.

**Warning signs:**
- Traffic stats validated only in Simulator
- `Position.speed` is always 0.0 or always a fixed value during Simulator testing
- No unit tests for the speed-threshold classification logic that could run without hardware GPS

**Phase to address:** GPS porting / testing phase

**Safe to defer?** The unit tests are not deferrable. Real-device validation can be done during the testing sub-phase of the same milestone.

---

### Pitfall 12: flutter_local_notifications iOS — Permissions Are Not Automatic

**What goes wrong:**
On Android, notification permissions are either granted by default (pre-API 33) or requested at runtime. On iOS, notification permission must always be explicitly requested and can be denied permanently. `flutter_local_notifications` does NOT automatically request notification permission on initialization. If `requestPermissions` is not called — with the correct combination of `alert: true, badge: true, sound: true` — notifications are silently discarded. Additionally, iOS 12+ supports "provisional" permissions that deliver notifications quietly (to Notification Center only, no banner/sound) without a user prompt, but the API behavior in `flutter_local_notifications` 21.x has a known bug where provisional permission reporting returns inconsistent results.

**How to avoid:**
1. Explicitly call `flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true)` during onboarding after the user has seen a rationale screen.
2. Do NOT use provisional permissions for this app — the persistent tracking notification and weekly summary need full (banner + sound) permission to be useful.
3. After requesting permission, call `checkPermissions()` and store the result. If denied, show a Settings deep-link explaining what notifications the user will miss.
4. Test notification permission on a device that has previously denied permission — the re-request flow must show the correct "open Settings" fallback.

**Warning signs:**
- No `requestPermissions` call in the notification service initialization
- Notifications work in development (first install, permission prompt shows) but "stop working" for testers who denied permission on a previous build
- `flutter_local_notifications` initialized but no iOS-specific platform plugin resolution

**Phase to address:** Notifications porting phase

**Safe to defer?** Partially. The persistent tracking notification can be tested with a prompt accepted. The weekly summary can be deferred within the milestone but permission infrastructure must be in place.

---

### Pitfall 13: flutter_secure_storage iOS — Keychain Sharing Entitlement Required

**What goes wrong:**
`flutter_secure_storage` uses the iOS Keychain via the `Security` framework. On the first launch of a development build on a real device (not Simulator), the Keychain API can return error code `-34018` ("A required entitlement isn't present") if the **Keychain Sharing** entitlement is not configured in Xcode. The app crashes or silently fails to store the auth token. This surfaces as a sign-in loop: the user signs in, the token cannot be written, the app restarts and finds no token, and sign-in is required again.

**Why it happens:**
The Keychain Sharing entitlement (`keychain-access-groups`) must be added to the Xcode project for Keychain operations to work on real devices in development mode. The Simulator does not enforce this restriction, which is why the bug only appears on physical devices.

**How to avoid:**
1. In Xcode, select Runner target → Signing & Capabilities → click `+` → add **Keychain Sharing**.
2. In the Keychain Groups list that appears, ensure at least one group exists (Xcode will create `$(AppIdentifierPrefix)com.yourcompany.commutetracker` automatically).
3. Do this for all build configurations (Debug, Profile, Release) — the capability must be present in each.
4. Verify by running on device and calling `FlutterSecureStorage().write(key: 'test', value: 'ok')` then `read`. No exception = entitlement is configured.

**Warning signs:**
- `PlatformException` with code `-34018` in the console during first Keychain write
- Auth token write succeeds in Simulator but fails on real device
- User is repeatedly asked to sign in after every app launch on device
- No `.entitlements` file in `ios/Runner/` after Xcode setup

**Phase to address:** iOS auth phase (immediately after scaffolding)

**Safe to defer?** No. Auth token storage is a prerequisite for the entire auth flow on device.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using `flutter_background_service` identically on iOS and Android | No platform branching | GPS stops on iOS the moment the phone is locked | Never — must branch by platform |
| Skipping `pausesLocationUpdatesAutomatically: false` | One fewer line | Trips silently truncate during stop-and-go traffic | Never |
| Not checking `LocationAccuracyStatus` on iOS 14+ | Simpler permission flow | Core traffic feature is broken for users who choose Approximate | Never |
| Hardcoding bundle ID in multiple places | Faster initial setup | Any rename requires finding and fixing 4+ locations | Avoid — use Xcode's managed bundle ID propagation |
| Testing auth only in Simulator | No device setup required | Keychain, URL scheme, and redirect bugs invisible | Early prototype only; all real tests must be on device |
| Deferring Sign In With Apple to "later" | Reduces v0.2 scope | Blocks App Store submission | Acceptable for this milestone only |
| Skipping Keychain Sharing entitlement | No Xcode capability step | Silent auth failure on every real device | Never |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| geolocator + iOS background | Assuming Android foreground service config works on iOS | Platform-branch `LocationSettings`: use `AppleSettings` on iOS with `allowsBackgroundLocationUpdates: true` and `pausesLocationUpdatesAutomatically: false` |
| google_sign_in 7.x iOS | Copying the `CLIENT_ID` instead of `REVERSED_CLIENT_ID` into `CFBundleURLSchemes` | The URL scheme must be the reversed version (read it from `GoogleService-Info.plist` → `REVERSED_CLIENT_ID`) |
| GoogleService-Info.plist placement | Dropping the file in `ios/` root instead of `ios/Runner/` | File must be at `ios/Runner/GoogleService-Info.plist` and added to the Xcode target (not just the filesystem) |
| CocoaPods deployment target | Updating `Podfile` but not Xcode's `IPHONEOS_DEPLOYMENT_TARGET` | Must update both; use the `post_install` hook to cover all transitive pods |
| flutter_local_notifications 21 iOS | Calling `initialize()` without calling `requestPermissions()` separately | Always call `requestPermissions()` explicitly; `initialize()` does not do it on iOS |
| flutter_secure_storage iOS | Testing only in Simulator | Keychain Sharing entitlement required for real-device Keychain access; configure in Xcode before first device run |
| Flutter SPM + CocoaPods | Letting `flutterfire configure` add Firebase to CocoaPods when Xcode 26+ uses SPM | Let `flutterfire configure` manage the migration; do not manually add Firebase pods to `Podfile` |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| High-accuracy GPS on iOS with screen on | Battery drains noticeably faster on iPhone than Android during tracking | Use `LocationAccuracy.high` (not `best`) and `distanceFilter: 0` only while actively recording; stop the stream when tracking ends | During every active trip |
| flutter_map tile caching on iOS | Map tiles re-download on every app launch; slower map loads | `flutter_map_tile_caching` 10.x has documented iOS stability issues (in-progress fix for v9/v10); test on device and verify cache persistence in `Documents/` sandbox | From first launch with slow network |
| Rebuilding position stream on every trip start | Memory leak from multiple uncancelled stream subscriptions | Cancel the previous stream subscription before starting a new one; maintain a single `StreamSubscription<Position>?` instance in the tracking service | After 2+ trips in one session |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing Firebase ID token in `UserDefaults` instead of Keychain | Token readable from iTunes backup, iCloud backup, or by other apps on jailbroken device | Use `flutter_secure_storage` (Keychain-backed) exclusively — already planned in CLAUDE.md |
| Requesting `NSLocationAlwaysAndWhenInUseUsageDescription` without genuinely needing "Always" | App Store rejection; user privacy concerns | Only request "Always" if background GPS tracking is the primary feature — it is for this app, so justify it clearly in the Info.plist string |
| Firebase ID token verification skipped on backend when iOS client is added | iOS client can forge requests if token is not verified server-side | Backend `verifyIdToken` call is platform-agnostic — no change needed, but verify it handles both Android and iOS-issued tokens (it does, as Firebase tokens are identical regardless of platform) |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing the location permission prompt without context | Users deny "Always" permission because they don't understand why it's needed | Show a full-screen onboarding card explaining background tracking before any system prompt appears |
| Not explaining the blue location indicator | Users think the app is "spying" even when not commuting | Show the indicator in a visual onboarding diagram: "This blue dot appears while your trip is recording — tap it to return to the app" |
| Dismissing the 7-day cert expiry silently | App stops launching mid-milestone with no explanation | Display a test build warning banner in debug builds reminding the developer of the reinstall cadence |
| Tracking notification identical to Android design | iOS notification design conventions differ (no expandable views by default, different action button placement) | Use iOS-specific notification content with `DarwinNotificationDetails`; test on device for layout |

## "Looks Done But Isn't" Checklist

- [ ] **Background GPS:** Works when app is foregrounded. Lock the phone for 10 minutes mid-commute — does the trip polyline continue, or does it stop at the lock moment?
- [ ] **pausesLocationUpdatesAutomatically:** Sit in a parked car for 3 minutes with tracking active. Do GPS updates continue? (Check by watching the elapsed distance counter stay at 0 but not flatline.)
- [ ] **"Always" authorization:** Grant "When In Use" during onboarding — does the app correctly detect this and prompt for escalation to "Always"?
- [ ] **Accurate location authorized:** Select "Approximate Location" during permission prompt — does the app block trip recording and explain why?
- [ ] **Google Sign-In redirect:** Complete sign-in on a real device — does Safari/SFSafariViewController redirect back to the app, or does it hang?
- [ ] **Keychain write on first launch:** Check console for `-34018` error on first real-device run after each Xcode clean install.
- [ ] **7-day expiry:** After 7 days, does the re-run from Xcode restore the app without data loss?
- [ ] **iOS Simulator tests not trusted for GPS:** All speed/traffic tests run on a real commute, not Simulator.
- [ ] **CocoaPods deployment target:** `flutter build ios --no-codesign` passes without any deployment target warning.
- [ ] **GoogleService-Info.plist in Xcode target:** File is listed under Runner target's "Copy Bundle Resources" build phase — not just present on disk.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| GPS stops on iOS background | HIGH | Add platform-specific `AppleSettings`; re-test on device (requires another 7-day install cycle) |
| pausesLocationUpdatesAutomatically silently pausing | MEDIUM | Add `pausesLocationUpdatesAutomatically: false`; re-test with stationary and slow-traffic scenarios |
| Google Sign-In redirect broken | LOW | Verify `REVERSED_CLIENT_ID` in `Info.plist`; re-run `pod install` if Info.plist changes affect CocoaPods-linked resources |
| Keychain entitlement missing | LOW | Add Keychain Sharing in Xcode (5-minute fix); re-run on device |
| Deployment target mismatch blocking build | LOW | Update Podfile + Xcode `IPHONEOS_DEPLOYMENT_TARGET` + add `post_install` hook; run `pod install` |
| 7-day provisioning expired mid-testing | LOW | Re-run from Xcode; 5-minute reinstall; no data loss |
| firebase_options.dart / GoogleService-Info.plist mismatch | MEDIUM | Re-run `flutterfire configure` for iOS; verify bundle IDs match across all three files |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| flutter_background_service wrong for iOS background GPS | iOS GPS porting | Lock phone for 10 min mid-trip; polyline must continue |
| pausesLocationUpdatesAutomatically default | iOS GPS porting | 3-minute stationary test; GPS stream must not pause |
| Blue location indicator UX | iOS onboarding | User sees explanation before first tracking start |
| "Always" auth two-step flow | iOS onboarding / permissions | Walk through denial + escalation + Settings deep-link paths |
| iOS 14+ Reduced Accuracy | iOS onboarding / permissions | Grant Approximate; app must block recording and explain |
| CocoaPods deployment target | iOS scaffolding (Phase 1) | `flutter build ios --no-codesign` passes clean |
| google_sign_in URL scheme | iOS auth phase | Real-device sign-in completes and redirects correctly |
| GoogleService-Info.plist mismatch | iOS scaffolding (Phase 1) | Firebase initializes without exception; auth returns valid user |
| 7-day provisioning + Developer Mode | iOS scaffolding (Phase 1) | First `flutter run` on device succeeds; reinstall after 7 days documented |
| Sign in with Apple (Guideline 4.8) | App Store submission milestone (future) | Not applicable this milestone — deferred |
| Simulator GPS unreliability | iOS GPS testing | Traffic stats validated only on real commute data |
| flutter_local_notifications permissions | iOS notifications phase | Permission prompt appears; denied-permission Settings link works |
| flutter_secure_storage Keychain entitlement | iOS auth phase | No `-34018` exception on first device write |

## Sources

- geolocator pub.dev changelog and GitHub issues (Baseflow/flutter-geolocator issues #485, #592, #889, #948, #1023, #1116, #1545) — MEDIUM confidence (live web verified)
- flutter_background_service pub.dev documentation on iOS Background Fetch limitations — HIGH confidence (official package docs)
- Apple Developer Documentation: CLAccuracyAuthorization, Enabling Developer Mode — HIGH confidence (official Apple docs)
- Apple App Store Review Guidelines 4.8 (Login Services) — HIGH confidence (live web verified, January 2024 revision noted)
- Firebase FlutterFire iOS Installation docs — HIGH confidence (official Firebase docs)
- google_sign_in_ios pub.dev documentation — HIGH confidence (official package page)
- flutter_secure_storage GitHub issue #804 (keychain entitlement) — MEDIUM confidence (live web verified)
- flutter_local_notifications GitHub issue #2235 (provisional permission bug) — MEDIUM confidence (live web verified)
- Shubham Pawar Medium: "Handling Background Services in Flutter: The Right Way Across Android 14 & iOS 17" — LOW confidence (community blog, used for corroboration only)
- Firebase CocoaPods deprecation timeline (October 2026) — HIGH confidence (official Firebase announcement)
- Flutter 3.44 SPM-as-default timeline — MEDIUM confidence (live web verified, community sources)
- Training data knowledge of CoreLocation behavior (pausesLocationUpdatesAutomatically, accuracy authorization, two-step "Always" flow) — MEDIUM confidence (verified against Apple Developer Documentation)

---
*Pitfalls research for: Commute Tracker v0.2 iOS port (Flutter, geolocator 14.x, flutter_background_service 5.x, google_sign_in 7.x, firebase_auth 6.x, flutter_local_notifications 21, flutter_secure_storage 10.3, Drift, flutter_map 8.x)*
*Researched: 2026-06-02*
