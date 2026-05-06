---
phase: 07-polish-notifications
verified: 2026-05-05T16:00:00Z
status: human_needed
score: 4/4 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Toggle Dark radio row in Settings screen on a real Android device"
    expected: "App theme changes instantly across all screens (Dashboard, Settings) with no restart required"
    why_human: "Dynamic themeMode wiring via Riverpod stream is verified programmatically but instant visual propagation across all MaterialApp routes requires device observation"
  - test: "Toggle Weekly summary ON, kill app, relaunch"
    expected: "Theme persists (reads from Drift). Weekly summary notification appears on Sunday 6 PM (or simulated next Sunday)"
    why_human: "zonedSchedule with exactAllowWhileIdle targets a real Android alarm manager; cannot verify scheduled alarm fires without a device and calendar advance"
  - test: "Toggle Daily reminder ON, set a time 1 minute in the future, wait"
    expected: "Notification fires at the scheduled time; weekend-only vs weekday-only behavior is correct"
    why_human: "Real-time notification delivery requires live Android alarm scheduling; cannot verify in unit/widget tests"
  - test: "Submit a manual trip entry with Time in traffic = 0:30 and Distance = 15.5 km"
    expected: "Trip saves without error; Stats screen shows the traffic time as part of the weekly traffic total (not excluded)"
    why_human: "End-to-end data flow from ManualEntrySheet through TripManagementNotifier into Drift and back to the stats provider requires live Drift + device"
---

# Phase 7: Polish & Notifications — Verification Report

**Phase Goal:** App feels complete with dark mode support and proactive notifications for summaries and reminders
**Verified:** 2026-05-05T16:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                             | Status     | Evidence                                                                                                                                  |
| --- | --------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | User can toggle between light mode, dark mode, and system default in settings     | ✓ VERIFIED | `_AppearanceSection` with `RadioGroup<String>` wrapping 3 `RadioListTile` rows using `kDarkModeSystem`/`kDarkModeLight`/`kDarkModeDark`; tapping calls `dao.upsert()` via `userPreferencesDaoProvider`; `_toThemeMode()` maps to `ThemeMode.light/dark/system` in `app.dart` |
| 2   | User receives a weekly push notification summarizing their commute totals         | ✓ VERIFIED | `NotificationService.scheduleWeeklySummary()` uses `zonedSchedule` with `DateTimeComponents.dayOfWeekAndTime` targeting `_nextSunday6pm()` (18:00 local); `_buildWeeklyBody()` queries Drift TripsDao for real trip totals; toggle in `_NotificationsSection` calls `scheduleWeeklySummary`/`cancelWeeklySummary` |
| 3   | User can enable a tracking reminder notification at their usual departure time    | ✓ VERIFIED | `scheduleReminder(hhMm, includeWeekends)` implemented: weekdays-only schedules IDs 20–24 with `dayOfWeekAndTime`; daily schedules ID 20 with `DateTimeComponents.time`; time picker in `_ReminderRows` uses `showTimePicker` and stores HH:mm to Drift; rescheduled on app start via `NotificationService.initialize()` |
| 4   | Theme preference persists across app restarts via user_preferences table          | ✓ VERIFIED | `UserPreferencesDao.upsert()` calls `insertOnConflictUpdate` — writes to Drift; `userPreferenceProvider` is a `StreamProvider` backed by `watchSingleOrNull()` on the Drift table; `TraevyApp.build()` reads `ref.watch(userPreferenceProvider)` — theme resolves from DB on next launch |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact                                                   | Expected                                                                 | Status     | Details                                                                    |
| ---------------------------------------------------------- | ------------------------------------------------------------------------ | ---------- | -------------------------------------------------------------------------- |
| `lib/config/constants.dart`                                | kDarkModeLight, kDarkModeDark, all notification channel/ID/content constants | ✓ VERIFIED | Lines 392, 397: `kDarkModeLight='light'`, `kDarkModeDark='dark'`; lines 455–488: all channel IDs, notification IDs, labels present (28+ constants) |
| `lib/config/routes.dart`                                   | kRouteSettings = '/settings'; wired in kAppRoutes                        | ✓ VERIFIED | Line 26: `kRouteSettings='/settings'`; line 37: `kRouteSettings: (ctx) => const SettingsScreen()` in `kAppRoutes` |
| `lib/database/tables/user_preferences_table.dart`          | weeklyNotificationEnabled BoolColumn withDefault(false)                  | ✓ VERIFIED | Line 55: `BoolColumn get weeklyNotificationEnabled => boolean().withDefault(const Constant(false))()` |
| `lib/database/daos/user_preferences_dao.dart`              | weeklyNotificationEnabled in all methods; watch() via watchSingleOrNull  | ✓ VERIFIED | Lines 32, 45, 69, 105, 153: field in constructor/defaults/getOrDefault/upsert; lines 118–128: `watch()` using `watchSingleOrNull().map()` |
| `lib/database/database.dart`                               | schemaVersion=2 + onUpgrade migration for v2                             | ✓ VERIFIED | Line 39: `schemaVersion => 2`; lines 50–58: `if (from < 2) await m.addColumn(userPreferences, userPreferences.weeklyNotificationEnabled)` |
| `drift_schemas/drift_schema_v2.json`                       | Drift schema snapshot for migration test verification                    | ✓ VERIFIED | File exists, 15,452 bytes                                                  |
| `android/app/src/main/AndroidManifest.xml`                 | USE_EXACT_ALARM permission for zonedSchedule                             | ✓ VERIFIED | Line 65: `<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>` |
| `lib/features/settings/providers/settings_providers.dart`  | userPreferenceProvider StreamProvider<UserPreferencesValue>              | ✓ VERIFIED | Lines 16–19: manual `StreamProvider<UserPreferencesValue>`; wired to `userPreferencesDaoProvider.watch()`; `name: 'userPreferenceProvider'` |
| `lib/notifications/notification_service.dart`              | NotificationService with initialize, scheduleWeeklySummary, scheduleReminder, cancelWeeklySummary, cancelReminder | ✓ VERIFIED | All 5 methods present; `_createChannels()` creates `kWeeklySummaryChannelId` and `kReminderChannelId`; `initialize()` reschedules on app start from DB |
| `lib/app.dart`                                             | Dynamic MaterialApp.themeMode via _toThemeMode                           | ✓ VERIFIED | Lines 32–34: `ref.watch(userPreferenceProvider).when(data: _toThemeMode, ...)` replaces hardcoded `ThemeMode.system` |
| `lib/main.dart`                                            | tz.initializeTimeZones() + NotificationService().initialize() in bootstrap | ✓ VERIFIED | Line 43: `tz.initializeTimeZones()` first; lines 44–46: `TrackingNotificationService` then `NotificationService` |
| `lib/features/settings/screens/settings_screen.dart`       | SettingsScreen with _AppearanceSection, _NotificationsSection, _ReminderRows; all under 100 lines | ✓ VERIFIED | 4 private classes: `SettingsScreen` (~26 lines), `_AppearanceSection` (~42 lines), `_NotificationsSection` (~33 lines), `_ReminderRows` (~46 lines) |
| `lib/features/dashboard/screens/dashboard_screen.dart`     | 4th trailing gear IconButton navigating to kRouteSettings                | ✓ VERIFIED | Lines 66–68: `IconButton(icon: Icon(Icons.settings), tooltip: kSettingsTooltip, onPressed: () => Navigator.pushNamed(context, kRouteSettings))` |
| `lib/features/trips/widgets/manual_entry_sheet.dart`       | Optional traffic (HH:MM) and distance (km) fields                        | ✓ VERIFIED | Lines 48–49, 72–73: `_trafficController`/`_distanceController`; lines 122–134: parsing in `_save()`; fields rendered with `FilteringTextInputFormatter` |
| `lib/features/stats/services/stats_service.dart`           | Refined manual trip exclusion: exclude only when timeStuckSeconds==0 AND distanceMeters==0 | ✓ VERIFIED | Lines 127–130: `isBlankManualEntry = trip.isManualEntry && trip.timeStuckSeconds == 0 && trip.distanceMeters == 0` |
| `test/widget/features/settings/settings_screen_test.dart`  | Wave 0 test scaffold with SettingsScreen and DashboardScreen gear icon groups | ✓ VERIFIED | Lines 121, 223: both test groups present; 10/10 tests reported GREEN in 07-04-SUMMARY.md |
| `test/generated_migrations/schema_v2.dart`                 | Drift migration test helper for v2                                       | ✓ VERIFIED | File exists                                                                |

### Key Link Verification

| From                                              | To                                        | Via                                                  | Status     | Details                                          |
| ------------------------------------------------- | ----------------------------------------- | ---------------------------------------------------- | ---------- | ------------------------------------------------ |
| `lib/config/constants.dart`                       | `lib/features/settings/screens/settings_screen.dart` | Import + kDarkModeLight/kDarkModeDark/kSettings* constants | ✓ WIRED | Line 9: `import 'package:traevy/config/constants.dart'`; constants used throughout |
| `lib/database/daos/user_preferences_dao.dart`     | `lib/features/settings/providers/settings_providers.dart` | `userPreferencesDaoProvider.watch()` | ✓ WIRED | Line 18: `(ref) => ref.watch(userPreferencesDaoProvider).watch()` |
| `lib/features/settings/providers/settings_providers.dart` | `lib/app.dart`                   | `ref.watch(userPreferenceProvider)` in `TraevyApp.build()` | ✓ WIRED | Line 32: `ref.watch(userPreferenceProvider).when(data: _toThemeMode, ...)` |
| `lib/features/settings/screens/settings_screen.dart` | `lib/features/settings/providers/settings_providers.dart` | `ref.watch(userPreferenceProvider)` | ✓ WIRED | Lines 9, 33: imported and watched |
| `lib/features/settings/screens/settings_screen.dart` | `lib/notifications/notification_service.dart` | `NotificationService().scheduleWeeklySummary/scheduleReminder` | ✓ WIRED | Lines 10, 282, 286, 288, 302, 307, 333, 348: imported and called on toggles |
| `lib/features/dashboard/screens/dashboard_screen.dart` | `lib/config/routes.dart`            | `Navigator.pushNamed(context, kRouteSettings)`        | ✓ WIRED | Lines 66–68: `onPressed: () => Navigator.pushNamed(context, kRouteSettings)` |
| `lib/notifications/notification_service.dart`     | `lib/main.dart`                           | `NotificationService().initialize()` in bootstrap    | ✓ WIRED | Line 46: `await NotificationService().initialize()` after `tz.initializeTimeZones()` |

### Data-Flow Trace (Level 4)

| Artifact                                   | Data Variable | Source                               | Produces Real Data | Status     |
| ------------------------------------------ | ------------- | ------------------------------------ | ------------------ | ---------- |
| `lib/app.dart` (MaterialApp.themeMode)     | `themeMode`   | `userPreferenceProvider.when(data: _toThemeMode, ...)` → Drift `userPreferences` table | Yes — `watchSingleOrNull().map()` on real SQLite table via `appDatabaseProvider` | ✓ FLOWING |
| `lib/features/settings/screens/settings_screen.dart` (RadioGroup groupValue) | `asyncPrefs.data.darkMode` | `userPreferenceProvider` stream → Drift watch | Yes — same Drift stream; emits `UserPreferencesValue.defaults()` on first launch (no seed row), real row thereafter | ✓ FLOWING |
| `lib/notifications/notification_service.dart` (_buildWeeklyBody) | `trips` | `db.tripsDao.getAllTrips()` / `watchAllSummaries().first` | Yes — direct DAO query on AppDatabase; filtered for current Mon–Sun week | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior                                         | Command / Check                                                                                    | Result                             | Status  |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------- | ---------------------------------- | ------- |
| `_toThemeMode` maps all 3 values correctly       | `theme_mode_test.dart` (4 tests): `kDarkModeLight` → `ThemeMode.light`, `kDarkModeDark` → `ThemeMode.dark`, `kDarkModeSystem` → `ThemeMode.system`, unknown → `ThemeMode.system` | Reported 4/4 GREEN in 07-03-SUMMARY.md | ✓ PASS |
| NotificationService channel IDs are distinct     | `notification_service_test.dart`: `kWeeklySummaryChannelId != kReminderChannelId != kTrackingNotificationChannelId` | 9/9 GREEN in 07-03-SUMMARY.md | ✓ PASS |
| Reminder ID range covers Mon–Fri (20–24)         | `notification_service_test.dart`: IDs 20–24 are distinct from weekly summary ID 10 | 9/9 GREEN in 07-03-SUMMARY.md | ✓ PASS |
| SettingsScreen renders all expected widgets      | `settings_screen_test.dart` (10 tests): 3 RadioListTile rows, gear icon navigation, reminder opacity | Reported 10/10 GREEN in 07-04-SUMMARY.md | ✓ PASS |
| stats_service exclusion logic updated            | `stats_service_test.dart` (15 tests): blank manual trips excluded, data-filled manual trips included | 15/15 GREEN in 07-04-SUMMARY.md | ✓ PASS |
| Notification fires at scheduled time (live)      | Requires Android device + time advance — cannot automate                                            | —                                  | ? SKIP  |
| Theme persists across app restart (live)         | Requires Android device relaunch — cannot automate                                                  | —                                  | ? SKIP  |

### Requirements Coverage

| Requirement | Source Plan   | Description                                              | Status        | Evidence                                                                                     |
| ----------- | ------------- | -------------------------------------------------------- | ------------- | -------------------------------------------------------------------------------------------- |
| UX-02       | 07-01, 07-03, 07-04 | Dark mode support (system default + manual toggle in settings) | ✓ SATISFIED | `kDarkModeLight`/`kDarkModeDark` constants; `_AppearanceSection` RadioGroup; `_toThemeMode()` in `app.dart`; upsert persists to Drift |
| UX-04       | 07-01, 07-03, 07-04 | Weekly summary push notification with commute totals     | ✓ SATISFIED | `NotificationService.scheduleWeeklySummary()`; `_buildWeeklyBody()` queries real trip totals; weekly summary `SwitchListTile` toggle wired |
| UX-05       | 07-01, 07-03, 07-04 | Tracking reminder notification at user's usual departure time | ✓ SATISFIED | `NotificationService.scheduleReminder(hhMm, includeWeekends)`; time picker in `_ReminderRows`; `initialize()` reschedules on app start |

**Orphaned requirements:** None. All 3 Phase 7 requirements (UX-02, UX-04, UX-05) are claimed in plans and verified above.

### Anti-Patterns Found

| File                                                          | Line    | Pattern                                          | Severity | Impact                                                                                  |
| ------------------------------------------------------------- | ------- | ------------------------------------------------ | -------- | --------------------------------------------------------------------------------------- |
| `lib/features/settings/screens/settings_screen.dart`          | 232–233 | Hardcoded accessibility label strings in `Semantics` | ℹ️ Info | Not user-visible display text; Semantics labels for screen readers. CLAUDE.md "no hardcoded strings" rule targets display labels. Non-blocking. |

No stub patterns, empty returns, or placeholder code found in any Phase 7 files.

### Human Verification Required

#### 1. Instant theme switching on device

**Test:** Launch the app on an Android device. Open Settings via the gear icon in the Dashboard AppBar. Tap "Dark" radio row.
**Expected:** The entire app (including Dashboard, which is visible in the navigation stack) switches to dark theme immediately — no restart required.
**Why human:** `ref.watch(userPreferenceProvider)` reactive stream wiring is confirmed in code, but the actual visual propagation through `MaterialApp.themeMode` to all routes requires a running device to observe.

#### 2. Theme persistence across restarts

**Test:** With "Dark" mode selected, force-close the app and relaunch.
**Expected:** App opens in dark mode. The `userPreferenceProvider` stream reads from Drift on startup and `_toThemeMode()` returns `ThemeMode.dark`.
**Why human:** Drift persistence is verified at code level (upsert uses `insertOnConflictUpdate`), but reading back on next launch requires a live app session.

#### 3. Weekly summary notification fires

**Test:** Toggle "Weekly summary" ON in Settings. Advance device clock to next Sunday 6:00 PM local time (or use developer settings to trigger the scheduled alarm).
**Expected:** Notification appears with title "Your week in commute" and body showing either the week's totals or "No commutes recorded this week".
**Why human:** `zonedSchedule` with `exactAllowWhileIdle` targets the Android alarm manager. Cannot verify scheduling actually fires without a device + clock manipulation.

#### 4. Daily reminder fires and respects weekday-only setting

**Test:** Toggle "Daily reminder" ON. Set a time 2 minutes in the future. Leave "Include weekends" OFF. Wait for the notification. Then toggle "Include weekends" ON and verify only one alarm fires on weekends.
**Expected:** Notification fires at the set time on weekdays only. When weekends are included, fires every day.
**Why human:** Real-time delivery and day-of-week filtering require live Android alarm behavior across different days.

### Gaps Summary

No gaps found. All 4 roadmap success criteria are verified against the codebase:
1. SC-1 (light/dark/system toggle) — `_AppearanceSection` with `RadioGroup`, `_toThemeMode()`, upsert to Drift.
2. SC-2 (weekly push notification) — `NotificationService.scheduleWeeklySummary()` with `zonedSchedule` + `_buildWeeklyBody()` querying real trip data.
3. SC-3 (reminder notification at departure time) — `scheduleReminder()` with HH:mm from time picker; weekday vs. daily modes; rescheduled on app start.
4. SC-4 (theme persists via user_preferences) — `upsert()` → `insertOnConflictUpdate`; `watch()` via `watchSingleOrNull()`; `TraevyApp` reads from `userPreferenceProvider` stream on every launch.

All artifacts exist, are substantive, are wired, and data flows from real Drift queries. The 4 items in human verification are standard device-behavior checks that cannot be automated; they do not indicate code defects.

---

_Verified: 2026-05-05T16:00:00Z_
_Verifier: Claude (gsd-verifier)_
