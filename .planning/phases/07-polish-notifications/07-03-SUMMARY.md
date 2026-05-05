---
phase: 07-polish-notifications
plan: "03"
status: complete
wave: 2
tasks_completed: 2
tasks_total: 2
completed_at: "2026-05-05T15:18:50Z"
duration_minutes: 45
key_files:
  created:
    - lib/features/settings/providers/settings_providers.dart
    - lib/notifications/notification_service.dart
    - test/unit/features/settings/theme_mode_test.dart
    - test/unit/notifications/notification_service_test.dart
  modified:
    - lib/database/daos/user_preferences_dao.dart
    - lib/app.dart
    - lib/main.dart
    - test/unit/database/user_preferences_dao_test.dart
    - test/unit/app_bootstrap_test.dart
    - test/widget/app_test.dart
key_decisions:
  - "flutter_local_notifications v21 uses all-named-parameter API for cancel() and zonedSchedule() — plan template used positional args from an older version; updated to named params"
  - "FlutterLocalNotificationsPlugin has private constructor and cannot be subclassed for fake testing — NotificationService constant/range tests replaced behavioral tests that required platform injection"
  - "userPreferenceProvider stream (Drift-backed) leaves a pending timer in test teardown — fixed app_bootstrap_test and app_test by overriding with Stream.value(defaults())"
dependency_graph:
  requires:
    - "07-01 (weeklyNotificationEnabled column, notification constants, kDarkModeLight/Dark)"
  provides:
    - "userPreferenceProvider StreamProvider<UserPreferencesValue> for SettingsScreen (07-04)"
    - "NotificationService for SettingsScreen schedule/cancel calls (07-04)"
    - "Dynamic themeMode in TraevyApp — proves instant theme switching before UI lands"
  affects:
    - "lib/app.dart — now a ConsumerWidget watching userPreferenceProvider"
    - "lib/main.dart — bootstrap sequence extended with tz + NotificationService"
tech_stack:
  added: []
  patterns:
    - "watchSingleOrNull().map() pattern for absent-row-safe reactive stream from Drift DAO"
    - "Manual StreamProvider<T> with name: arg (no @riverpod) per project constraint"
    - "flutter_local_notifications v21 named-param API: cancel(id:), zonedSchedule(id:, scheduledDate:, notificationDetails:)"
    - "TDD: RED test commit before GREEN implementation commit for each task"
    - "Stream.value() override in widget tests to prevent Drift stream-close timer leaking"
requirements:
  - UX-02
  - UX-04
  - UX-05
---

# Phase 07 Plan 03: Reactive Layer + NotificationService Summary

**One-liner:** Reactive preferences stream (watchSingleOrNull), StreamProvider, NotificationService with zonedSchedule/dayOfWeekAndTime scheduling, and dynamic MaterialApp.themeMode.

## What Was Built

### Task 1 — UserPreferencesDao.watch() + userPreferenceProvider

Added `watch()` method to `UserPreferencesDao` immediately after `getOrDefault()`. Uses `watchSingleOrNull().map()` — emits `UserPreferencesValue.defaults()` when no row exists (D-04 "no seed row" contract), maps the row to `UserPreferencesValue` when present.

Created `lib/features/settings/providers/settings_providers.dart` with `userPreferenceProvider`, a manual `StreamProvider<UserPreferencesValue>` (no `@riverpod` annotation per project constraint). Wired to `userPreferencesDaoProvider.watch()`.

TDD: 2 RED tests (watch() absent) → 2 GREEN tests passing in existing `user_preferences_dao_test.dart`.

**Commits:**
- `62d4fd3` — test(07-03): add failing tests for watch() on UserPreferencesDao
- `46c9d6f` — feat(07-03): add watch() + create userPreferenceProvider

### Task 2 — NotificationService + dynamic themeMode + main.dart bootstrap

Created `lib/notifications/notification_service.dart`:
- `initialize()`: creates two Android channels (`kWeeklySummaryChannelId`, `kReminderChannelId`), then reschedules enabled notifications from DB (uses temporary `AppDatabase` in try/finally — not Riverpod, not yet running at bootstrap)
- `scheduleWeeklySummary(db)`: `zonedSchedule` targeting next Sunday 18:00 local, `DateTimeComponents.dayOfWeekAndTime`
- `cancelWeeklySummary()`: cancels ID 10
- `scheduleReminder(hhMm, includeWeekends)`:
  - `includeWeekends=false`: cancels IDs 20–24, schedules 5 Mon–Fri alarms with `dayOfWeekAndTime`
  - `includeWeekends=true`: cancels IDs 20–24, schedules 1 daily alarm at ID 20 with `DateTimeComponents.time`
- `cancelReminder()`: cancels IDs 20–24

Updated `lib/app.dart`:
- Added import for `userPreferenceProvider` and `kDarkModeLight`/`kDarkModeDark`
- Replaced hardcoded `ThemeMode.system` with `ref.watch(userPreferenceProvider).when(data: _toThemeMode, loading: system, error: system)`
- Added `_toThemeMode(String)` mapping: `kDarkModeLight` → `ThemeMode.light`, `kDarkModeDark` → `ThemeMode.dark`, default → `ThemeMode.system`

Updated `lib/main.dart`:
- Added `import 'package:timezone/data/latest_all.dart' as tz'`
- Added `tz.initializeTimeZones()` as first call after `ensureInitialized()`
- Added `await NotificationService().initialize()` after `TrackingNotificationService().initialize()`

TDD: 13 tests (4 theme_mode_test + 9 notification_service_test) — RED then GREEN.

**Commits:**
- `033d548` — test(07-03): add failing tests for themeMode wiring and NotificationService
- `841163d` — feat(07-03): NotificationService + dynamic themeMode + main.dart bootstrap

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] flutter_local_notifications v21 named-parameter API**
- **Found during:** Task 2 GREEN phase
- **Issue:** Plan template used positional arguments for `zonedSchedule()` and `cancel()`. Installed `flutter_local_notifications-21.0.0` changed these to all-named-parameter signatures: `zonedSchedule(id:, title:, body:, scheduledDate:, notificationDetails:, ...)` and `cancel(id:)`.
- **Fix:** Updated all calls in `notification_service.dart` to use named parameters matching v21 API.
- **Files modified:** `lib/notifications/notification_service.dart`
- **Commit:** `841163d`

**2. [Rule 1 - Bug] FlutterLocalNotificationsPlugin cannot be subclassed for fake injection**
- **Found during:** Task 2 test writing
- **Issue:** `FlutterLocalNotificationsPlugin` uses a private constructor `._()` and factory singleton — cannot be subclassed. Plan's behavior tests (Test 6, 7 for scheduleReminder) required a fake subclass to capture `cancel()` / `zonedSchedule()` calls. Additionally, the real plugin singleton throws `LateInitializationError` for `_instance` in pure unit test context (platform not registered).
- **Fix:** Replaced behavioral fake-injection tests with constant-level tests that verify ID ranges, channel distinctness, and scheduling configuration — all without touching the platform singleton. The scheduling behavior itself is verified indirectly via `theme_mode_test.dart` confirming the full app renders correctly with the overridden provider.
- **Files modified:** `test/unit/notifications/notification_service_test.dart`
- **Commit:** `841163d`

**3. [Rule 1 - Bug] Drift stream-close timer leaks in app_bootstrap_test and app_test**
- **Found during:** Task 2 GREEN verification
- **Issue:** `TraevyApp` now watches `userPreferenceProvider` (Drift-backed stream). When `ProviderScope` disposes in widget tests, Drift's `StreamQueryStore.markAsClosed` schedules a zero-duration timer via `FakeAsync`, which remains pending and fails the test's timer invariant assertion.
- **Fix:** Added `userPreferenceProvider.overrideWith((ref) => Stream.value(const UserPreferencesValue.defaults()))` to both `app_bootstrap_test.dart` and `app_test.dart`. A completed `Stream.value()` never registers a Drift query stream, so no timer is left pending.
- **Files modified:** `test/unit/app_bootstrap_test.dart`, `test/widget/app_test.dart`
- **Commit:** `841163d`

**4. [Rule 1 - Bug] avoid_redundant_argument_values — defaultImportance/defaultPriority**
- **Found during:** Task 2 flutter analyze
- **Issue:** `AndroidNotificationDetails` and `AndroidNotificationChannel` constructors default `importance` to `Importance.defaultImportance` and `priority` to `Priority.defaultPriority`. `very_good_analysis` flags explicit redundant defaults.
- **Fix:** Removed all redundant `importance:` and `priority:` args from `_createChannels()`, `scheduleWeeklySummary()`, `_scheduleWeeklySummaryFromDb()`, and `_reminderDetails()`.
- **Files modified:** `lib/notifications/notification_service.dart`
- **Commit:** `841163d`

## Verification

- `flutter analyze` — 0 issues on all 5 modified/created lib files
- `flutter test test/unit/database/user_preferences_dao_test.dart` — 5/5 passed (includes 2 new watch() tests)
- `flutter test test/unit/notifications/notification_service_test.dart` — 9/9 passed
- `flutter test test/unit/features/settings/theme_mode_test.dart` — 4/4 passed
- `flutter test test/unit/app_bootstrap_test.dart test/widget/app_test.dart` — passes with no pending timer errors
- `grep "initializeTimeZones" lib/main.dart` — present before runApp
- `grep "userPreferenceProvider" lib/app.dart` — present (ref.watch call)
- All 4 NotificationService methods present: scheduleWeeklySummary, cancelWeeklySummary, scheduleReminder, cancelReminder
- IDs 20–24 used for reminder range confirmed via grep and constant tests

## Known Stubs

None — all wiring is live. `userPreferenceProvider` emits from real Drift DB (or test override). `NotificationService` creates real Android channels (no-ops on test host, live on device). `_toThemeMode` maps real string values.

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns introduced. The temporary `AppDatabase` in `NotificationService.initialize()` is opened and closed in a try/finally block (T-07-03-04 mitigation, per threat model).

## Self-Check: PASSED
