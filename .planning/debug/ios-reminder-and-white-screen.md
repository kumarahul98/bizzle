---
slug: ios-reminder-and-white-screen
status: resolved
trigger: "Phase 15 iOS device UAT — two defects: (1) Daily reminder toggle does nothing (never requests notification permission / never schedules), (2) ~20s white screen on launch."
created: 2026-06-03T19:56:16Z
updated: 2026-06-04T00:00:00Z
---

# Debug Session: ios-reminder-and-white-screen

Two distinct defects surfaced during Phase 15 iOS device UAT on a real iPhone 13 (iOS 26.5). They are tracked together because both were found in the same session and both touch app startup / notifications. Both issues are now fixed.

## Symptoms

### Issue 1 — Daily reminder toggle is a no-op (FIXED)
- **Expected:** Enabling Settings → Notifications → "Daily reminder" requests the iOS notification permission and schedules the reminder.
- **Actual:** Toggling it on did nothing — no permission prompt, no scheduled notification.
- **Root cause (confirmed):** No "Reminder time" picker row existed in `_NotificationsSection`, so `prefs.reminderTime` was always `null` on a fresh install. `_toggleReminder()` gated the permission request behind `if (value && prefs.reminderTime != null)` — a `true && false` path that fell to `cancelReminder()` instead.
- **Fix applied:** (a) Added "Reminder time" tappable row to `_NotificationsSection` that opens `showTimePicker` and persists the chosen time as `HH:mm` via the existing `_copyPrefs`/`upsert` pattern. (b) Decoupled the permission request: enabling Daily reminder now ALWAYS calls `maybeRequestNotificationPermissionForUsage(forceRequest: true)` regardless of whether a time is set; `scheduleReminder` is only called if `reminderTime != null`.

### Issue 2 — ~20s white screen on launch (FIXED — pending device verification)
- **Expected:** App launches to first frame quickly.
- **Actual:** ~20 seconds of white screen on iPhone 13 / iOS 26.5.
- **Root cause (hypothesis, strong):** `configureBackgroundService()` (flutter_background_service) was called unconditionally in `main.dart` before `runApp`. Phase 14 replaced `flutter_background_service` with a main-isolate `IosTrackingEngine` on iOS — the service is never started on iOS — but `configure()` was still being called on every iOS launch. This is the most likely stall.
- **Fix applied:** Gated `configureBackgroundService()` behind `Platform.isAndroid`. Added per-step `Stopwatch` + `debugPrint` instrumentation to all bootstrap `await`s so the exact stall timing is visible in device logs on the next run.
- **Pending:** Run on device with `--profile` build to confirm the stall is eliminated and capture the bootstrap timings log.

## Environment
- Real device: iPhone 13, iOS 26.5. flutter id `00008110-00115119260A401E`, devicectl id `FEC345D4-825D-51B4-A052-54C7378F615D` (connected).
- Phase 15 plans 15-01/02/03 complete; 15-04/15-05 (Live Activity) blocked on an unrelated App-Group device-provisioning probe.

## Current Focus

- hypothesis: (Issue 2) configureBackgroundService() was the stall — now iOS-gated. Bootstrap timings will confirm on next device run.
- next_action: Run `flutter run --profile --device-id 00008110-00115119260A401E` and share the `[main] bootstrap:` log lines to confirm timings.
- test: Issues 1 — 26/26 widget tests green including 5 new Phase 15 fix tests. Issue 2 — bootstrap timing log on device.
- expecting: Issue 2 white screen eliminated; bootstrap completes in < 2s on profile build.

## Evidence

- timestamp: 2026-06-03T19:56:16Z — Code read confirms `_NotificationsSection` (settings_screen.dart:155-195) has only 3 toggle rows, no "Reminder time" picker. `reminderTime` column is `text().nullable()` with no default (user_preferences_table.dart:45). `_toggleReminder` gates permission+schedule behind `value && prefs.reminderTime != null`. `requestIOSNotificationPermission` / `maybeRequestNotificationPermissionForUsage` (notification_service.dart:219-279) are correct and iOS-guarded. `app.dart` permission hook is post-frame fire-and-forget (not the white-screen cause). `main.dart:59-96` awaits configureBackgroundService(), Firebase.initializeApp(), GoogleSignIn.initialize(), and both notification initialize() calls before runApp.
- timestamp: 2026-06-04T00:00:00Z — Fix applied: (1) Reminder time picker row added to `_NotificationsSection`; permission request decoupled from reminderTime check. (2) `configureBackgroundService()` gated on `Platform.isAndroid`; per-step Stopwatch instrumentation added to all main.dart bootstrap awaits. All 26 widget tests green. `flutter analyze` clean on changed files (project-wide infos are pre-existing).

## Eliminated

- hypothesis: Phase 15 Dart changes cause the white screen — ELIMINATED: app.dart hook is post-frame/unawaited; the blocking awaits are pre-existing in main.dart (Phase 2/9/11).
- hypothesis: The launch crash and the white screen are the same issue — ELIMINATED: the dyld/objc crash was resolved by clean rebuild; the white screen is a post-launch-success perf symptom.

## Resolution

### Issue 1 — Daily reminder no-op
- **Root cause:** `_toggleReminder` gated `maybeRequestNotificationPermissionForUsage` + `scheduleReminder` behind `value && prefs.reminderTime != null`. On a fresh install `reminderTime` is null, so the gate was never true.
- **Fix:** Added "Reminder time" tappable row to `_NotificationsSection` (`lib/features/settings/screens/settings_screen.dart`). Decoupled permission request from time check — enabling the toggle always requests permission; scheduling only happens when a time exists.
- **Files changed:** `lib/features/settings/screens/settings_screen.dart`, `test/widget/features/settings/settings_screen_test.dart`

### Issue 2 — ~20s white screen
- **Root cause (hypothesis):** `configureBackgroundService()` ran unconditionally on iOS even though Phase 14 removed flutter_background_service from the iOS GPS path.
- **Fix:** `if (Platform.isAndroid)` guard around `configureBackgroundService()`. Bootstrap Stopwatch instrumentation added for device-side timing confirmation.
- **Files changed:** `lib/main.dart`
- **Verification needed:** Run on device (`--profile`) and confirm `[main] bootstrap:` log shows no stall.
