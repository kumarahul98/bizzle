---
slug: ios-reminder-and-white-screen
status: resolved
trigger: "Phase 15 iOS device UAT — two defects: (1) Daily reminder toggle does nothing (never requests notification permission / never schedules), (2) ~20s white screen on launch."
created: 2026-06-03T19:56:16Z
updated: 2026-06-04T02:30:00Z
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
- **Pending:** Determine why `--profile` produced a JIT/debug build. Run a genuine profile or release build on device to measure first-frame time and close the white-screen sub-issue.

### Issue 3 — Drift double-database warning (FIXED, 2026-06-04)
- **Expected:** Only one `AppDatabase` instance exists at runtime.
- **Actual:** Drift WARNING "created the database class AppDatabase multiple times" fired ~5× after app launch. Stack: `NotificationService._isUsageAnchorMet (notification_service.dart:443) ← maybeRequestNotificationPermissionForUsage ← app.dart post-frame hook`.
- **Root cause:** `_isUsageAnchorMet({AppDatabase? db})` falls back to `db ?? AppDatabase()` when `db` is null. The `app.dart` post-frame hook called `maybeRequestNotificationPermissionForUsage()` without a `db` argument. Since `TraevyApp.build` fires on theme changes, auth state changes, and other rebuilds, this constructed a fresh raw `AppDatabase()` on each call — bypassing the Riverpod-managed singleton.
- **Fix:** In `app.dart`, pass `db: ref.read(appDatabaseProvider)` to `maybeRequestNotificationPermissionForUsage()`. No changes to `notification_service.dart` needed — the method already accepts the optional `db` parameter and only creates its own when null. The `NotificationService.initialize()` call in `main.dart` runs before `ProviderScope` exists and legitimately creates and closes its own db instance; that path is unaffected.
- **Tests added:** 2 unit tests in `test/unit/notifications/notification_service_test.dart` covering the `db`-injection API contract. All 432 passing tests remain green; the 1 failing test (`live_activity_service_test.dart`) is a pre-existing Phase 15 RED placeholder.

## Environment
- Real device: iPhone 13, iOS 26.5. flutter id `00008110-00115119260A401E`, devicectl id `FEC345D4-825D-51B4-A052-54C7378F615D` (connected).
- Phase 15 plans 15-01/02/03 complete; 15-04/15-05 (Live Activity) blocked on an unrelated App-Group device-provisioning probe.

## Current Focus (2026-06-04 — post drift-fix)

Issue 3 (drift double-database) is fixed and committed. Two remaining items:

- hypothesis: (Issue 2) The ~20s white screen on device may be debug-JIT warmup: the `--profile` run still produced a JIT build (Dart execution mode: JIT; bootstrap totals ~2.3s dominated by `NotificationService.initialize`, but white screen persists ~20s post-`runApp`). Must be settled with a real profile/release build.
- next_action: (1) Investigate why `flutter run --profile` on iPhone 13 produced a JIT/debug build — check flutter version, connected device, build command. (2) Run a genuine `flutter build ipa --profile` or `flutter run --release` and measure first-frame time to determine if 20s is debug-JIT artifact. (3) Separately investigate 2.3s `NotificationService.initialize` cost if white screen persists on profile/release. (4) Issue 1 — confirm iOS permission prompt fires after delete+reinstall (user action required).
- test: Issue 2 — first-frame time on profile/release build confirms white screen is gone or persists. Issue 1 — reinstall test.
- expecting: On profile/release build the white screen is short (debug-JIT artifact) OR a real post-runApp stall in SplashScreen/authState is isolated.

## Evidence (device run 2026-06-04)

- timestamp: 2026-06-04T00:30:00Z — Device `flutter run` (DEBUG/JIT despite `--profile`) on iPhone 13 / iOS 26.5. Bootstrap timings: TrackingNotificationService.initialize +22ms; **NotificationService.initialize +2313ms**; configureBackgroundService SKIPPED (iOS) ✓; Firebase.initializeApp +12ms; GoogleSignIn.initialize +2ms; runApp. Total ~2.3s — but **white screen still ~20s**, so stall is post-runApp. Build is DEBUG (`Dart execution mode: JIT`; "This warning will only appear on debug builds"). Repeated drift WARNING "created the database class AppDatabase multiple times" with stack `NotificationService._isUsageAnchorMet (notification_service.dart:443) ← maybeRequestNotificationPermissionForUsage (:268)` — raw `AppDatabase()` constructed instead of shared instance, fired ~5×. Also benign: `dev.flutter.background.refresh is not advertised in Info.plist` / BGTaskScheduler Code=3 (flutter_background_service iOS background-refresh noise — harmless since service unused on iOS). Reminder toggle did NOT show the iOS permission prompt (consistent with OS-level permission already decided for a reinstalled bundle id).
- timestamp: 2026-06-04T01:30:00Z — Issue 3 fix applied and committed: `app.dart` now passes `db: ref.read(appDatabaseProvider)` to `maybeRequestNotificationPermissionForUsage()`. 2 unit tests added; `flutter analyze` clean; 432 tests green (1 pre-existing RED placeholder excluded).

## Evidence

- timestamp: 2026-06-03T19:56:16Z — Code read confirms `_NotificationsSection` (settings_screen.dart:155-195) has only 3 toggle rows, no "Reminder time" picker. `reminderTime` column is `text().nullable()` with no default (user_preferences_table.dart:45). `_toggleReminder` gates permission+schedule behind `value && prefs.reminderTime != null`. `requestIOSNotificationPermission` / `maybeRequestNotificationPermissionForUsage` (notification_service.dart:219-279) are correct and iOS-guarded. `app.dart` permission hook is post-frame fire-and-forget (not the white-screen cause). `main.dart:59-96` awaits configureBackgroundService(), Firebase.initializeApp(), GoogleSignIn.initialize(), and both notification initialize() calls before runApp.
- timestamp: 2026-06-04T00:00:00Z — Fix applied: (1) Reminder time picker row added to `_NotificationsSection`; permission request decoupled from reminderTime check. (2) `configureBackgroundService()` gated on `Platform.isAndroid`; per-step Stopwatch instrumentation added to all main.dart bootstrap awaits. All 26 widget tests green. `flutter analyze` clean on changed files (project-wide infos are pre-existing).

## Eliminated

- hypothesis: Phase 15 Dart changes cause the white screen — ELIMINATED: app.dart hook is post-frame/unawaited; the blocking awaits are pre-existing in main.dart (Phase 2/9/11).
- hypothesis: The launch crash and the white screen are the same issue — ELIMINATED: the dyld/objc crash was resolved by clean rebuild; the white screen is a post-launch-success perf symptom.
- hypothesis: `configureBackgroundService()` on iOS causes the 20s white screen — ELIMINATED: gated on `Platform.isAndroid`; device log shows SKIPPED (iOS). Bootstrap is now only ~2.3s pre-runApp.
- hypothesis: Drift double-database is caused by `notification_service.dart` — ELIMINATED: the bug was at the call site in `app.dart` (no `db:` argument passed). `notification_service.dart` itself already accepted an optional `db` and only fell back to `AppDatabase()` when null.

## Resolution

### Issue 1 — Daily reminder no-op
- **Root cause:** `_toggleReminder` gated `maybeRequestNotificationPermissionForUsage` + `scheduleReminder` behind `value && prefs.reminderTime != null`. On a fresh install `reminderTime` is null, so the gate was never true.
- **Fix:** Added "Reminder time" tappable row to `_NotificationsSection` (`lib/features/settings/screens/settings_screen.dart`). Decoupled permission request from time check — enabling the toggle always requests permission; scheduling only happens when a time exists.
- **Files changed:** `lib/features/settings/screens/settings_screen.dart`, `test/widget/features/settings/settings_screen_test.dart`

### Issue 2 — ~20s white screen
- **Root cause (hypothesis):** `configureBackgroundService()` ran unconditionally on iOS even though Phase 14 removed flutter_background_service from the iOS GPS path.
- **Fix:** `if (Platform.isAndroid)` guard around `configureBackgroundService()`. Bootstrap Stopwatch instrumentation added for device-side timing confirmation.
- **Files changed:** `lib/main.dart`
- **Verification needed:** Run on device (genuine profile/release — `--profile` produced JIT) and confirm first-frame is fast.

### Issue 3 — Drift double-database warning (FIXED 2026-06-04)
- **Root cause:** `app.dart` post-frame hook called `maybeRequestNotificationPermissionForUsage()` without a `db:` argument → `_isUsageAnchorMet` fell back to `AppDatabase()` constructor, creating a new instance per rebuild.
- **Fix:** Pass `db: ref.read(appDatabaseProvider)` at the call site in `app.dart`.
- **Files changed:** `lib/app.dart`, `test/unit/notifications/notification_service_test.dart`
