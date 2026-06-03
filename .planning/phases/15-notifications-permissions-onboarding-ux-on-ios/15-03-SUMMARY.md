---
phase: 15-notifications-permissions-onboarding-ux-on-ios
plan: "03"
subsystem: ios-notifications-permissions
tags: [tdd, green, ios-branch, notifications, permissions, platform-gate]
dependency_graph:
  requires:
    - phase: 15-02
      provides: "formatElapsed + formatStuck formatters in lib/shared/utils/formatters.dart; kTrackingNotificationBodyLine1/2Template in lib/config/constants.dart"
    - phase: 15-01
      provides: "RED scaffolds: notification_service_test.dart + tracking_notification_service_test.dart"
  provides:
    - lib/notifications/notification_service.dart (requestIOSNotificationPermission + maybeRequestNotificationPermissionForUsage)
    - lib/features/tracking/services/tracking_notification_service.dart (forTesting constructor + Platform.isAndroid gate + two-line body)
    - lib/app.dart (post-frame contextual permission hook)
    - lib/features/settings/screens/settings_screen.dart (forceRequest on reminder enable)
    - lib/config/constants.dart (kNotificationPermissionAnchorDays = 7)
  affects:
    - Plan 04 (Live Activity — no phantom notification on iOS now confirmed)
    - Plan 05 (LiveActivityService — shares formatElapsed/formatStuck through same formatter path)
tech_stack:
  added: []
  patterns:
    - "requestIOSNotificationPermission(iosPlugin:) test-seam: pass IOSFlutterLocalNotificationsPlugin directly to bypass defaultTargetPlatform guard in unit tests"
    - "forTesting(platformIsAndroid:) named constructor on service for dart:io Platform gate without dart:io in tests (RESEARCH Pitfall 2)"
    - "Contextual permission via post-frame callback in app.dart (mirrors syncEngineProvider pattern)"
    - "One-time sentinel file in getApplicationSupportDirectory() for deduplicating permission requests"
    - "showRecording() swallows plugin exceptions internally (defence-in-depth; controller swallows too)"
key_files:
  created: []
  modified:
    - lib/notifications/notification_service.dart
    - lib/features/tracking/services/tracking_notification_service.dart
    - lib/features/tracking/providers/tracking_providers.dart
    - lib/app.dart
    - lib/features/settings/screens/settings_screen.dart
    - lib/config/constants.dart
    - test/unit/features/tracking/persist_finalized_trip_test.dart
    - test/unit/features/tracking/tracking_notifier_test.dart
key_decisions:
  - "requestIOSNotificationPermission test seam: injecting iosPlugin bypasses the defaultTargetPlatform guard so the fake is always exercised — aligns with the existing constructor-injection pattern on both services"
  - "One-time sentinel is a file in getApplicationSupportDirectory() (path_provider already a dep); avoids schema migration vs. adding a column to user_preferences"
  - "showRecording() wraps _plugin.show() in try/catch so the service never propagates plugin exceptions to callers — previously relied solely on controller catch block"
  - "forceRequest=true in _toggleReminder on enable path: user explicitly opting into reminders is a D-07 contextual signal regardless of trip age"
  - "timeMovingSeconds added to showRecording() with default=0; existing callers at controller (placeholder show) are backward compatible; tracking_providers.dart call site updated with live value"
requirements-completed: [IOS-10, IOS-11, IOS-14]
duration: 10min
completed: "2026-06-03"
---

# Phase 15 Plan 03: iOS Notification Decoupling + Android Enriched Body Summary

**Contextual iOS notification permission (7-day anchor + reminder-enable path), iOS showRecording() no-op gate, and Android two-line BigText body (formatElapsed/formatStuck via templates) — all RED scaffolds from Plan 01 now GREEN.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-06-03T17:39:05Z
- **Completed:** 2026-06-03T17:49:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- IOS-10: `requestIOSNotificationPermission(iosPlugin:)` + `maybeRequestNotificationPermissionForUsage(forceRequest:)` added to NotificationService; contextual trigger wired at app.dart root (post-frame) and settings reminder-enable path
- IOS-11: `TrackingNotificationService.forTesting(platformIsAndroid:)` named constructor + `if (!_platformIsAndroid) return;` at top of `showRecording()` — no phantom notification posts on iOS
- IOS-14: `_renderBody` rewritten to two-line template: `kTrackingNotificationBodyLine1Template` (formatElapsed + km) + `kTrackingNotificationBodyLine2Template` (formatStuck moving + stuck) joined by `\n`; BigTextStyleInformation summary set to "{km} km · {elapsed}" per UI-SPEC Surface E
- D-14 invariants preserved: kTrackingNotificationId = 1001, channel id = traevy_active_commute, ongoing/autoCancel/onlyAlertOnce unchanged, foregroundServiceNotificationId untouched

## Task Commits

1. **Task 1: Contextual iOS notification permission (IOS-10)** - `e7a7ee7` (feat)
2. **Task 2: Platform.isAndroid gate + two-line enriched body (IOS-11, IOS-14)** - `cbe9dd7` (feat)

## Files Created/Modified

- `lib/notifications/notification_service.dart` — added requestIOSNotificationPermission + maybeRequestNotificationPermissionForUsage + sentinel helpers
- `lib/features/tracking/services/tracking_notification_service.dart` — forTesting constructor, _platformIsAndroid field, Platform.isAndroid guard, two-line _renderBody, showRecording try/catch, timeMovingSeconds param
- `lib/features/tracking/providers/tracking_providers.dart` — pass timeMovingSeconds to showRecording call site
- `lib/app.dart` — post-frame contextual permission hook via notificationServiceProvider
- `lib/features/settings/screens/settings_screen.dart` — forceRequest call on reminder enable in _toggleReminder
- `lib/config/constants.dart` — kNotificationPermissionAnchorDays = 7
- `test/unit/features/tracking/persist_finalized_trip_test.dart` — add timeMovingSeconds to _RecordingNotifications fake
- `test/unit/features/tracking/tracking_notifier_test.dart` — add timeMovingSeconds to _NoopNotifications fake

## Decisions Made

- Test seam for `requestIOSNotificationPermission`: when `iosPlugin` is injected directly, the `defaultTargetPlatform` guard is skipped — the injection is the signal that this is a test/iOS context. This avoids `debugDefaultTargetPlatformOverride` in the notification_service_test (which doesn't use flutter_test properly for that pattern).
- Sentinel file in `getApplicationSupportDirectory()` (path_provider) for the one-time permission flag — avoids a Drift schema migration for a single boolean.
- `showRecording()` now catches plugin exceptions internally. Previously only the controller caught them. Belt-and-suspenders, and makes the service self-testable (test with `returnsNormally`).
- `timeMovingSeconds` added to `showRecording()` with `= 0` default — backward compatible with the placeholder show in the controller and any other callers.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test fakes in persist_finalized_trip_test + tracking_notifier_test missing timeMovingSeconds**
- **Found during:** Task 2 full-suite run
- **Issue:** Adding `timeMovingSeconds` to `showRecording()` broke two test fakes that override the method without the new param — compile error.
- **Fix:** Added `int timeMovingSeconds = 0,` to both `_RecordingNotifications.showRecording` and `_NoopNotifications.showRecording`.
- **Files modified:** test/unit/features/tracking/persist_finalized_trip_test.dart, test/unit/features/tracking/tracking_notifier_test.dart
- **Verification:** Full suite 425 passing, 1 failing (pre-existing Plan 05 RED scaffold only).
- **Committed in:** cbe9dd7 (Task 2 commit)

**2. [Rule 1 - Bug] showRecording() needed internal exception swallowing for test host**
- **Found during:** Task 2 test run
- **Issue:** Test uses `returnsNormally` for `platformIsAndroid=true` path, but the uninitialized plugin throws `MissingPluginException`. Previously the controller swallowed this, but the test calls the service directly.
- **Fix:** Wrapped `_plugin.show()` in `try { } on Object { }` inside `showRecording()`. Same pattern as the controller.
- **Files modified:** lib/features/tracking/services/tracking_notification_service.dart
- **Verification:** IOS-11 Android-path test passes with `returnsNormally`.
- **Committed in:** cbe9dd7 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 × Rule 1 bugs — cascade from new param + test host compat)
**Impact on plan:** Both auto-fixes necessary for correctness. No scope creep. D-14 invariants confirmed unaffected.

## Issues Encountered

None — standard implementation. The Wave 0 RED scaffold structure matched the implementation exactly once the `iosPlugin` test-seam semantics were clarified (inject = bypass platform guard).

## Test Results

| Test File | Before | After |
|-----------|--------|-------|
| `test/unit/notifications/notification_service_test.dart` | RED (requestIOSNotificationPermission undefined) | GREEN (10/10) |
| `test/unit/features/tracking/tracking_notification_service_test.dart` | RED (forTesting + template constants undefined) | GREEN (7/7) |
| Full suite | 405 passing, 3 failing (Wave 0 RED scaffolds) | 425 passing, 1 failing (live_activity_service_test — Plan 05 RED scaffold) |

The 1 remaining failure is the pre-existing Plan 05 RED scaffold (`live_activity_service_test.dart` — LiveActivityService undefined). Plans 01 and 03 both turned GREEN, reducing the RED count from 3 to 1.

## Known Stubs

None — all implemented paths are fully wired. The `maybeRequestNotificationPermissionForUsage` 7-day anchor uses live Drift data (not mocked). The sentinel file is real fs I/O via path_provider.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| T-15-05 mitigated | lib/notifications/notification_service.dart | Permission requested only via contextual path (7-day anchor or reminder-enable); never on cold start; never gates tracking Start |
| T-15-06 mitigated | lib/features/tracking/services/tracking_notification_service.dart | Body renders only formatElapsed/formatStuck aggregate stats — never raw lat/lng (PII guard T-02-07 preserved) |
| T-15-07 accepted | lib/features/tracking/services/tracking_notification_service.dart | Enrichment is body-content only; channel id, notification id, foregroundServiceNotificationId unchanged — single-shade-entry contract intact |

## Next Phase Readiness

- Plan 04 (Live Activity bridge): iOS phantom notification suppression confirmed (IOS-11 service + controller gates both in place); shared formatters available for the Swift/Dart bridge
- Plan 05 (LiveActivityService Dart): formatElapsed + formatStuck formatters ready; the single remaining RED scaffold is Plan 05's own file

## Self-Check: PASSED

| Item | Result |
|------|--------|
| lib/notifications/notification_service.dart (requestIOSNotificationPermission) | FOUND |
| lib/notifications/notification_service.dart (maybeRequestNotificationPermissionForUsage) | FOUND |
| lib/features/tracking/services/tracking_notification_service.dart (forTesting) | FOUND |
| lib/features/tracking/services/tracking_notification_service.dart (Platform.isAndroid) | FOUND |
| lib/app.dart (maybeRequestNotificationPermissionForUsage) | FOUND |
| lib/config/constants.dart (kNotificationPermissionAnchorDays) | FOUND |
| Commit e7a7ee7 (Task 1) | FOUND |
| Commit cbe9dd7 (Task 2) | FOUND |

---
*Phase: 15-notifications-permissions-onboarding-ux-on-ios*
*Completed: 2026-06-03*
