---
phase: 12-ios-scaffolding-configuration
plan: "02"
subsystem: infra
tags: [ios, xcode, info-plist, entitlements, firebase, google-signin, app-icons, notifications, flutter-local-notifications]

# Dependency graph
requires:
  - phase: 12-01-ios-scaffold
    provides: ios/ project scaffold, Podfile iOS 15.0, pod install baseline, Simulator launch confirmed

provides:
  - Info.plist with both location usage strings, UIBackgroundModes location, reversed-client-ID URL scheme, bundle ID com.travey.app
  - DebugProfile.entitlements and Release.entitlements with keychain-access-groups (empty array)
  - GoogleService-Info.plist at ios/Runner/GoogleService-Info.plist, wired into Runner target via Copy Bundle Resources build phase in project.pbxproj
  - iOS app icons (22 files) in AppIcon.appiconset generated from assets/icons/logo.jpeg via flutter_launcher_icons
  - notification_service.dart cross-platform with DarwinInitializationSettings + DarwinNotificationDetails (Android path unchanged)
  - flutter build ios --simulator exit 0

affects: [13-auth-ios, 15-notifications-permissions, 16-device-parity]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GoogleService-Info.plist committed to repo (standard FlutterFire workflow — client config, not a secret; Firestore deny-all rules enforce real access boundary server-side)"
    - "Empty keychain-access-groups array = narrowest scope that satisfies flutter_secure_storage on real devices (no cross-app sharing)"
    - "DarwinInitializationSettings with all request*Permission flags false — permission deferred to Phase 15 iOS permission flow"

key-files:
  created:
    - ios/Runner/GoogleService-Info.plist
  modified:
    - ios/Runner/Info.plist
    - ios/Runner/DebugProfile.entitlements
    - ios/Runner/Release.entitlements
    - ios/Runner.xcodeproj/project.pbxproj
    - ios/Runner/Assets.xcassets/AppIcon.appiconset/ (22 files regenerated)
    - lib/notifications/notification_service.dart
    - pubspec.yaml

key-decisions:
  - "No NSAppTransportSecurity exception added — all endpoints are HTTPS (CARTO tiles, Google OAuth, Cloud Functions); default ATS posture (TLS-required) is kept. T-12-04 verified: grep -c NSAllowsArbitraryLoads returns 0."
  - "GoogleService-Info.plist committed to version control (T-12-06 accepted risk — client config designed to ship in app bundle; Firestore Security Rules deny-all enforce real access boundary)"
  - "REVERSED_CLIENT_ID in GoogleService-Info.plist matches Info.plist CFBundleURLSchemes exactly: com.googleusercontent.apps.1076279794226-6h24q245801r9pca45v2e2tpjiocde64"
  - "keychain-access-groups set to empty array (single-app group) — prevents silent -34018 on real devices without granting cross-app keychain sharing"
  - "DarwinInitializationSettings requestAlertPermission/requestSoundPermission/requestBadgePermission all false — permission requested at runtime in Phase 15 iOS flow"
  - "Bundle ID corrected traevy.traevy -> com.travey.app in all three configs (Debug/Profile/Release) in project.pbxproj"
  - "GoogleService-Info.plist target wiring done via xcodeproj Ruby gem by orchestrator (not Xcode UI) — pbxproj has 4 references: PBXFileReference, Runner group, and Copy Bundle Resources build phase"
  - "stray test/widget_test.dart (default counter test re-added by flutter create) removed (commit f4e9c8a) to prevent false test failures"

patterns-established:
  - "Darwin platform branch in notification_service.dart: additive iOS arms alongside unchanged Android path — no platform guards on the Android side"

requirements-completed: [IOS-03]

# Metrics
duration: 45min
completed: 2026-06-02
---

# Phase 12 Plan 02: iOS Configuration (Info.plist, Entitlements, GoogleService-Info.plist, Icons, Notification Darwin Init) Summary

**Full iOS platform configuration delivering IOS-03: Info.plist location keys + reversed-client-ID URL scheme, keychain entitlements, GoogleService-Info.plist wired into Runner target, 22 app icons generated, DarwinInitializationSettings cross-platform notification init — verified with flutter build ios --simulator exit 0 in 16.4s**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-06-02T14:00:00Z
- **Completed:** 2026-06-02T14:45:00Z
- **Tasks:** 4 (Tasks 1-2 auto, Task 3 human-action checkpoint, Task 4 simulator build verification)
- **Files modified:** 9 (including 22-file AppIcon.appiconset)

## Accomplishments

- Info.plist configured with NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription, UIBackgroundModes location, CFBundleURLTypes with reversed-client-ID URL scheme, and bundle ID corrected to com.travey.app
- Both entitlements files (DebugProfile.entitlements, Release.entitlements) updated with keychain-access-groups empty array — prevents silent -34018 Keychain error on real devices
- GoogleService-Info.plist downloaded from Firebase Console and wired into Runner target via project.pbxproj (PBXFileReference + Runner group + Copy Bundle Resources); REVERSED_CLIENT_ID verified to match Info.plist URL scheme
- 22 iOS app icon files generated into AppIcon.appiconset via flutter_launcher_icons from assets/icons/logo.jpeg
- notification_service.dart extended cross-platform: DarwinInitializationSettings + DarwinNotificationDetails on both notification paths, Android path byte-for-byte unchanged
- flutter analyze clean, flutter test test/unit/ green, flutter build ios --simulator exits 0 (16.4s)
- No NSAppTransportSecurity exception required — all endpoints HTTPS, default ATS posture retained (T-12-04 mitigated)

## Task Commits

Each task was committed atomically:

1. **Task 1: Configure Info.plist and both entitlements files** - `f57c414` (feat)
2. **Task 2: Generate iOS app icons and add Darwin notification init** - `190b4d2` (feat)
3. **[deviation] Remove stale widget_test.dart** - `f4e9c8a` (chore)
4. **Task 3: Add GoogleService-Info.plist to Runner target** - `58735da` (feat)
5. **Task 4: Simulator build (verification only — no code change)** - no commit needed (exit 0)

**Plan metadata:** TBD (committed below)

## Files Created/Modified

- `ios/Runner/GoogleService-Info.plist` - Firebase iOS configuration with REVERSED_CLIENT_ID, CLIENT_ID, PROJECT_ID=travey-298a7; wired into Runner target as bundle resource
- `ios/Runner/Info.plist` - Location usage strings, UIBackgroundModes location, reversed-client-ID URL scheme (CFBundleURLTypes), bundle ID com.travey.app
- `ios/Runner/DebugProfile.entitlements` - Added keychain-access-groups (empty array) alongside existing keys
- `ios/Runner/Release.entitlements` - Added keychain-access-groups (empty array) alongside existing keys
- `ios/Runner.xcodeproj/project.pbxproj` - Bundle ID corrected to com.travey.app for all 3 configs; GoogleService-Info.plist added as PBXFileReference, in Runner group, and in Copy Bundle Resources build phase
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` - 22 iOS app icon files (all required sizes + Contents.json) generated from logo.jpeg
- `lib/notifications/notification_service.dart` - Added DarwinInitializationSettings to initialize(), DarwinNotificationDetails to scheduleWeeklySummary() and _reminderDetails()
- `pubspec.yaml` - flutter_launcher_icons.ios set to true

## Decisions Made

1. **No ATS exception added** — all endpoints (CARTO tiles, Google OAuth, Cloud Functions) are HTTPS. Default ATS posture (TLS-required) is kept. T-12-04 threat mitigated. Verified: `grep -c NSAllowsArbitraryLoads ios/Runner/Info.plist` returns 0.

2. **GoogleService-Info.plist committed to git** — standard FlutterFire workflow; plist is client configuration (API keys are client identifiers, not secrets) designed to ship inside the app bundle. Firestore Security Rules (deny-all to clients) enforce the real access boundary server-side. T-12-06 accepted risk.

3. **REVERSED_CLIENT_ID match confirmed** — GoogleService-Info.plist REVERSED_CLIENT_ID equals the Info.plist CFBundleURLSchemes value exactly: `com.googleusercontent.apps.1076279794226-6h24q245801r9pca45v2e2tpjiocde64`. T-12-07 accepted risk (scheme is public client identifier; OAuth exchange validated server-side).

4. **DarwinInitializationSettings with all request*Permission false** — notification permission deferred to Phase 15 iOS-specific permission flow. requestAlertPermission, requestSoundPermission, requestBadgePermission are all false in initialize().

5. **GoogleService-Info.plist wired via xcodeproj Ruby gem** — orchestrator used the xcodeproj gem (not Xcode UI) to add the file as PBXFileReference, place it in the Runner group, and add it to the Copy Bundle Resources build phase. Verified with `grep -c GoogleService-Info.plist ios/Runner.xcodeproj/project.pbxproj` returning 4.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed stray test/widget_test.dart re-added by flutter create**
- **Found during:** Task 2 (after code generation)
- **Issue:** flutter create re-added the default counter widget test, which tests `MyApp` (nonexistent in this project) and would fail `flutter test` for the wrong reasons
- **Fix:** Removed test/widget_test.dart
- **Files modified:** test/widget_test.dart (deleted)
- **Verification:** flutter test test/unit/ passes green
- **Committed in:** f4e9c8a (chore: remove stale widget_test.dart)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug/stale file)
**Impact on plan:** Necessary cleanup to keep test suite green. No scope creep.

## Issues Encountered

- Task 3 required a human-action checkpoint: GoogleService-Info.plist must be downloaded from Firebase Console (agents cannot log in to Firebase Console), and Xcode target wiring was done via xcodeproj Ruby gem by the orchestrator instead of Xcode UI. Both capabilities (Background Modes/Location and Keychain Sharing) were already satisfied via Info.plist UIBackgroundModes and entitlements from Task 1 — no additional Xcode capability toggle was required for the simulator build.

## Threat Surface Scan

All threats were addressed per the plan's threat model. No new network endpoints, auth paths, or schema changes introduced beyond what was planned.

| Status | Threat | Disposition |
|--------|--------|-------------|
| Mitigated | T-12-04: NSAllowsArbitraryLoads | grep -c returns 0; default HTTPS-only ATS retained |
| Mitigated | T-12-05: keychain-access-groups scope | Empty array = single-app group, narrowest valid scope |
| Accepted | T-12-06: GoogleService-Info.plist in repo | Client config by design; Firestore deny-all rules are the real boundary |
| Accepted | T-12-07: reversed-client-ID URL scheme | Public identifier; OAuth validated server-side |

## Known Stubs

None — all configuration is complete and wired. GoogleService-Info.plist contains live Firebase credentials for travey-298a7.

## Next Phase Readiness

- 12-03 (real-device signing) is unblocked: all configuration prerequisites are in place
- Phase 13 (Auth on iOS) prerequisites are met: GoogleService-Info.plist with REVERSED_CLIENT_ID, keychain entitlements, reversed-client-ID URL scheme in Info.plist
- `flutter build ios --simulator` exits 0 — configuration is build-clean

---
*Phase: 12-ios-scaffolding-configuration*
*Completed: 2026-06-02*
