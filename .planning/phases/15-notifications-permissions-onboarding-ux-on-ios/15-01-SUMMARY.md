---
phase: 15-notifications-permissions-onboarding-ux-on-ios
plan: "01"
subsystem: ios-notifications
tags: [tdd, red-scaffolds, wave-0, device-probe, live-activity, permissions]
dependency_graph:
  requires: []
  provides:
    - test/unit/shared/utils/formatters_test.dart (RED scaffold — Plan 02)
    - test/unit/features/tracking/live_activity_service_test.dart (RED scaffold — Plan 05)
    - test/unit/features/tracking/tracking_permission_service_test.dart (iOS groups added — Plan 02)
    - test/unit/notifications/notification_service_test.dart (IOS-10 group added — Plan 03)
    - test/unit/features/tracking/tracking_notification_service_test.dart (RED scaffold — Plan 03)
  affects:
    - Plans 02, 03, 04, 05 (all have RED scaffolds to go GREEN)
    - Plan 04 BLOCKED on App-Group device-provisioning checkpoint
tech_stack:
  added: []
  patterns:
    - TDD Wave 0 RED scaffolds — test files created before production code
    - debugDefaultTargetPlatformOverride for iOS branch tests (RESEARCH.md Pitfall 2)
    - Injected constructor seam for testable platform gate (forTesting pattern, Plan 03)
key_files:
  created:
    - test/unit/features/tracking/tracking_notification_service_test.dart
  modified:
    - test/unit/features/tracking/tracking_permission_service_test.dart
    - test/unit/notifications/notification_service_test.dart
decisions:
  - "Wave 0 RED scaffolds committed for all 5 test files before any Plan 02-05 implementation begins"
  - "App-Group device-provisioning probe surfaced as a BLOCKING checkpoint — Plan 04 cannot proceed until PASS/FAIL reported"
  - "IOS-11 test seam: forTesting(platformIsAndroid:) pattern chosen over dart:io Platform (RESEARCH.md Pitfall 2 avoidance)"
  - "FlutterLocalNotificationsPlugin cannot be subclassed (factory constructor) — IOS-11 gate test uses forTesting seam rather than spy subclass"
metrics:
  duration: "~25min"
  completed: "2026-06-03"
  tasks: 2
  files: 3
---

# Phase 15 Plan 01: Wave 0 De-risk — Test Scaffolds + App-Group Probe Summary

**One-liner:** Five RED test scaffolds for iOS permission/notification/Live-Activity behaviors plus a BLOCKING on-device App-Group provisioning checkpoint before any Swift is written.

## Status: CHECKPOINT REACHED (autonomous: false, blocking gate)

Plan execution is paused at the BLOCKING device-provisioning checkpoint. Tasks 1 and 2 are complete; Task 3 (checkpoint:human-verify) requires a physical iPhone.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Scaffold formatter + Live Activity unit tests (RED) | 2332d9c | test/unit/shared/utils/formatters_test.dart, test/unit/features/tracking/live_activity_service_test.dart |
| 2 (partial) | Fix notification fake override + iOS permission RED scaffolds | 401ae05 | test/unit/notifications/notification_service_test.dart, test/unit/features/tracking/tracking_permission_service_test.dart |
| 2 (remainder) | Add tracking_notification_service_test RED scaffold | 4384b58 | test/unit/features/tracking/tracking_notification_service_test.dart |

## RED State Verification

All five test files are in the correct RED state — failures are from missing production symbols only, NOT from malformed test infrastructure:

| Test File | RED Cause | Existing Tests |
|-----------|-----------|----------------|
| `test/unit/shared/utils/formatters_test.dart` | `formatElapsed`/`formatStuck` undefined (Plan 02 adds them) | — (new file) |
| `test/unit/features/tracking/live_activity_service_test.dart` | `LiveActivityService` undefined (Plan 05 adds it) | — (new file) |
| `test/unit/features/tracking/tracking_permission_service_test.dart` | iOS branch tests: production code probes `Permission.notification` on iOS (Plan 02 adds the guard) | 18 existing tests GREEN |
| `test/unit/notifications/notification_service_test.dart` | `requestIOSNotificationPermission` undefined (Plan 03 adds it) | 11 existing tests GREEN |
| `test/unit/features/tracking/tracking_notification_service_test.dart` | `TrackingNotificationService.forTesting` undefined; `kTrackingNotificationBodyLine1/2Template` undefined (Plan 03 adds both); D-14 invariant tests GREEN | 2 D-14 tests GREEN |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed _FakeIosPlugin invalid_override in notification_service_test.dart**
- **Found during:** Task 2 (verifying uncommitted scaffold)
- **Issue:** `_FakeIosPlugin.requestPermissions` used `bool?` (nullable) params instead of non-nullable `bool` with defaults, plus was missing `carPlay` and `providesAppNotificationSettings` params from the real `IOSFlutterLocalNotificationsPlugin` interface (version 21.0.0)
- **Fix:** Changed signature to match the real interface: `bool sound = false, bool alert = false, bool badge = false, bool provisional = false, bool critical = false, bool carPlay = false, bool providesAppNotificationSettings = false`
- **Files modified:** test/unit/notifications/notification_service_test.dart
- **Commit:** 401ae05

**2. [Rule 2 - Missing functionality] Added IOS-10 test body to notification_service_test.dart**
- **Found during:** Task 2
- **Issue:** The previous executor added `_FakeIosPlugin` and the import but left them unused (no test calling `requestIOSNotificationPermission`) — causing `unused_element` and `unused_import` warnings. A scaffold without a test that documents the intended API is an incomplete scaffold.
- **Fix:** Added the `NotificationService.requestIOSNotificationPermission (IOS-10)` test group that references the expected `service.requestIOSNotificationPermission(iosPlugin: fakeIos)` call surface — causing a single clean RED error (`undefined_method`) instead of spurious warnings.
- **Files modified:** test/unit/notifications/notification_service_test.dart
- **Commit:** 401ae05

**3. [Rule 1 - Bug] Replaced FlutterLocalNotificationsPlugin subclass spy with forTesting seam in tracking_notification_service_test.dart**
- **Found during:** Task 2 (creating tracking_notification_service_test.dart)
- **Issue:** Initial attempt to create a `_SpyPlugin extends FlutterLocalNotificationsPlugin` failed — the plugin uses a factory constructor and cannot be subclassed. This would have produced `non_generative_implicit_constructor` and `invalid_override` errors unrelated to the intended RED state.
- **Fix:** Rewrote the test to reference `TrackingNotificationService.forTesting(platformIsAndroid:)` as the testable seam (Plan 03 will add this). RED errors are now only `undefined_method` for `forTesting` and `undefined_identifier` for the two template constants — all correctly attributable to missing Plan 03 symbols.
- **Files modified:** test/unit/features/tracking/tracking_notification_service_test.dart
- **Commit:** 4384b58

## BLOCKING CHECKPOINT: App-Group Device-Provisioning Probe

This plan has `autonomous: false`. Plan 04 (native Swift Widget Extension) is BLOCKED until this checkpoint resolves.

### What was built
All five RED test scaffolds are in place covering:
- `formatElapsed` / `formatStuck` formatters (Plan 02)
- `LiveActivityService` lifecycle and iOS 17 gate (Plan 05)
- `TrackingPermissionService` iOS branch: never probes notification, never returns `notificationDenied` on iOS (Plan 02)
- `NotificationService.requestIOSNotificationPermission()` call surface (Plan 03)
- `TrackingNotificationService` IOS-11 gate + IOS-14 enriched body templates (Plan 03)

### What you need to do on-device

On a **physical iPhone running iOS 17+** (your device under personal-team free provisioning):

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File → New → Target → Widget Extension.** Product name: `TraevyLiveActivity`. Embed in Application: `Runner`. Activate when prompted.
3. For **BOTH** the `Runner` target and the `TraevyLiveActivity` target:
   - Signing & Capabilities → **+ Capability → App Groups**
   - Add `group.com.travey.app`
   - Ensure "Automatically manage signing" is ON and your personal team (Rahul kumar / 2DG5SFXZ5Z) is selected
4. Build and install to the device: **Cmd+R** from Xcode (or `flutter run` with the device connected).
5. Observe whether code signing succeeds **for BOTH targets** with the App Group entitlement.

### Report ONE of:

**PASS:** "PASS — App Group provisioned, app installed on device, no signing error"
→ Plan 04 proceeds as planned (live_activities plugin + App Group bridge).

**FAIL:** "FAIL — signing error: \<exact error message\>"
→ Plans 04/05 switch to the no-App-Group fallback (custom method channel + ActivityKit in AppDelegate, ContentState baked at Activity.request() time — see RESEARCH.md Pitfall 1 mitigation). This phase returns to replanning Plans 04/05 before continuing.

**Important:** The throwaway Xcode target created for this probe may be deleted after the test. Plan 04 creates the real target with its Swift sources. If provisioning is clean you may keep it.

**Risk context (from RESEARCH.md Assumption A3):** Free / personal-team Apple ID provisioning may reject App Group entitlements because App Groups require an explicit capability that Apple's servers must approve in the provisioning profile. This is the single highest-risk dependency of Phase 15 — it cannot be validated by the executor (no device access). This is why it is a BLOCKING gate.

## Known Stubs

None — no production code was written in this plan.

## Threat Flags

None — only test files were created/modified. No new network endpoints, auth paths, or schema changes.

## Self-Check: PASSED

| Item | Result |
|------|--------|
| test/unit/shared/utils/formatters_test.dart | FOUND |
| test/unit/features/tracking/live_activity_service_test.dart | FOUND |
| test/unit/features/tracking/tracking_permission_service_test.dart | FOUND |
| test/unit/notifications/notification_service_test.dart | FOUND |
| test/unit/features/tracking/tracking_notification_service_test.dart | FOUND |
| Commit 2332d9c (Task 1 scaffolds) | FOUND |
| Commit 401ae05 (Task 2 fix + iOS permission tests) | FOUND |
| Commit 4384b58 (tracking_notification_service_test) | FOUND |
