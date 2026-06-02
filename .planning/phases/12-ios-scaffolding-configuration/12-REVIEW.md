---
phase: 12-ios-scaffolding-configuration
reviewed: 2026-06-02T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/notifications/notification_service.dart
  - ios/Runner/Info.plist
  - ios/Runner/DebugProfile.entitlements
  - ios/Runner/Release.entitlements
  - ios/Podfile
  - ios/Runner.xcodeproj/project.pbxproj
findings:
  critical: 0
  warning: 0
  info: 2
  total: 2
status: clean
---

# Phase 12: Code Review Report

**Reviewed:** 2026-06-02
**Depth:** standard
**Files Reviewed:** 6
**Status:** clean

## Summary

Phase 12 adds the iOS platform: a Flutter `ios/` scaffold, CocoaPods configuration, native Info.plist / entitlements / signing config, GoogleService-Info.plist wiring, and a single additive cross-platform change to `notification_service.dart`. The review focused on the only behavioral source change (the Dart file) plus the security-relevant native config.

No Critical or Warning findings. The iOS arms in the notification service are additive, `const`, free of `dynamic`, and the Android path is byte-for-byte unchanged (verified against the diff). Security posture is sound: Application Transport Security keeps its default TLS-required stance (no `NSAllowsArbitraryLoads`, no `NSAppTransportSecurity` block at all), `keychain-access-groups` is an empty array (single-app, narrowest scope), `aps-environment` is correctly absent, location usage strings are present and accurate, and `UIBackgroundModes` is scoped to `location` only. The `GoogleService-Info.plist` bundle ID, `REVERSED_CLIENT_ID`, and the Info.plist `CFBundleURLSchemes` value are mutually consistent.

Two Info-level observations are recorded below. Neither is a defect; both are consistency notes for future awareness. Per the review scope, the iOS 14→15 deployment-target raise, the `aps-environment` removal, and the committed `GoogleService-Info.plist` were excluded from findings.

## Verification of scope items (no findings)

- **Android path intact:** `initialize()` still calls `_createChannels()` and the DB reschedule logic unchanged; `AndroidNotificationDetails`, `androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle`, and channel creation in `_createChannels()` are untouched. The diff is purely additive (Darwin init + two `iOS:` arms).
- **iOS arms correct:** `DarwinInitializationSettings` has all three `request*Permission` flags `false` (permission deferred to Phase 15, matching the inline comment). `DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: false)` is consistent across both `scheduleWeeklySummary()` and `_reminderDetails()`. All new objects are `const`; no `dynamic`.
- **ATS:** `grep` for `NSAllowsArbitraryLoads` / `NSAppTransportSecurity` returns nothing — default secure posture retained.
- **Entitlements:** `keychain-access-groups` is `<array/>` (empty) in both files; `get-task-allow` present only in DebugProfile (correct — debug-only). No `aps-environment`.
- **Podfile:** `platform :ios, '15.0'`, `post_install` sets `IPHONEOS_DEPLOYMENT_TARGET = '15.0'` and `GCC_PREPROCESSOR_DEFINITIONS` with only `PERMISSION_LOCATION=1` + `PERMISSION_NOTIFICATIONS=1` — no over-permissioning.
- **pbxproj:** `PRODUCT_BUNDLE_IDENTIFIER = com.travey.app` in all 3 Runner configs; `DEVELOPMENT_TEAM = 2DG5SFXZ5Z` in all 3; `GoogleService-Info.plist` present as PBXFileReference, in the Runner group, and in Copy Bundle Resources (4 references).

## Info

### IN-01: Bundle identifier `com.travey.app` differs from the project/brand name "Traevy"

**File:** `ios/Runner.xcodeproj/project.pbxproj:507,691,715` (also `ios/Runner/GoogleService-Info.plist:18`, `ios/Runner/Info.plist:18` `CFBundleName=traevy`)
**Issue:** The app, display name, and Firebase project are all spelled "traevy"/"Traevy" (`CFBundleDisplayName = Traevy`, `PROJECT_ID = travey-298a7`, `CFBundleName = traevy`), but the bundle identifier is `com.travey.app` — "travey" with the letters transposed relative to "traevy". This is internally consistent across `project.pbxproj`, `GoogleService-Info.plist` (`BUNDLE_ID` and `GOOGLE_APP_ID`), and the Firebase-registered app, so it is not a runtime defect and Google Sign-In / Firestore will work. It is flagged only because the spelling discrepancy looks like a typo and a bundle ID is effectively immutable once an app is published to the App Store. Confirm `com.travey.app` is the intended permanent identifier before any TestFlight/App Store submission.
**Fix:** No code change required if intentional. If the intent was `com.traevy.app`, change it now (before publication) in all three Runner configs in `project.pbxproj` and re-register the iOS app in the Firebase Console so `GoogleService-Info.plist` regenerates with a matching `BUNDLE_ID`/`GOOGLE_APP_ID`.

### IN-02: RunnerTests bundle ID retains the old `traevy.traevy` prefix

**File:** `ios/Runner.xcodeproj/project.pbxproj:524,542,558`
**Issue:** While the Runner target bundle ID was corrected to `com.travey.app`, the `RunnerTests` target still uses `PRODUCT_BUNDLE_IDENTIFIER = traevy.traevy.RunnerTests` in all three configs. Test bundle IDs are conventionally derived from the host app's bundle ID (e.g. `com.travey.app.RunnerTests`). This is harmless today (the project ships no RunnerTests and the simulator/device builds succeeded) but is an inconsistency that can surface if a unit-test target host is later configured.
**Fix:** For consistency, align the test bundle ID with the host app when/if RunnerTests is used: `PRODUCT_BUNDLE_IDENTIFIER = com.travey.app.RunnerTests`. Not required for v0.1 since no Swift tests run.

---

_Reviewed: 2026-06-02_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
