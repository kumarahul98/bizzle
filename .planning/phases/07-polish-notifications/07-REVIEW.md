---
phase: 07-polish-notifications
reviewed: 2026-05-05T00:00:00Z
depth: standard
files_reviewed: 15
files_reviewed_list:
  - lib/app.dart
  - lib/config/constants.dart
  - lib/config/routes.dart
  - lib/database/daos/user_preferences_dao.dart
  - lib/database/database.dart
  - lib/database/tables/user_preferences_table.dart
  - lib/features/dashboard/screens/dashboard_screen.dart
  - lib/features/settings/providers/settings_providers.dart
  - lib/features/settings/screens/settings_screen.dart
  - lib/features/stats/services/stats_service.dart
  - lib/features/trips/providers/trip_management_providers.dart
  - lib/features/trips/widgets/manual_entry_sheet.dart
  - lib/main.dart
  - lib/notifications/notification_service.dart
  - android/app/src/main/AndroidManifest.xml
findings:
  critical: 1
  warning: 5
  info: 4
  total: 10
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-05-05T00:00:00Z
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

This review covers the Phase 7 Polish & Notifications feature set: settings screen, dark-mode switching, `NotificationService` with weekly summary and daily reminder scheduling, Drift schema migration v1→v2, and the `UserPreferencesDao`. The foundation is solid — schema migration is safe (addColumn with default, no data loss), Riverpod stream lifecycle is correct, `context.mounted` guards are in place, and AndroidManifest permissions are correct for exact alarms on minSdk 34.

One critical bug was found: `int.parse` without a guard in `NotificationService.scheduleReminder` can crash the app at startup if the `reminderTime` DB value is malformed. Five warnings cover: a stale weekly-summary notification body (always reflects enable-time data, never the actual current week), an out-of-band `AppDatabase()` constructor call that bypasses the Riverpod-managed connection, an uncatchable error path in `initialize()`, missing `context.mounted` guard after `showTimePicker`, and code duplication between `scheduleWeeklySummary` and `_scheduleWeeklySummaryFromDb`. Four info items flag hardcoded UI strings and a widget build method that exceeds the 100-line budget.

---

## Critical Issues

### CR-01: `int.parse` in `scheduleReminder` throws on malformed DB data, crashing the app at startup

**File:** `lib/notifications/notification_service.dart:121-123`

**Issue:** `scheduleReminder` calls `int.parse(parts[0])` and `int.parse(parts[1])` directly on the raw `hhMm` string split. If `reminderTime` stored in the database is ever malformed (corrupt row, future migration mistake, or a developer testing with a direct DB edit), this throws a `FormatException`. The call site in `initialize()` is wrapped in `try { ... } finally { db.close() }` — the `finally` only closes the DB, there is no `catch`. The exception propagates all the way to `main()` which has no error handling, crashing the app on every subsequent launch until the user clears app data.

**Fix:** Use `int.tryParse` with fallback validation, and add a `catch` in `initialize()` so a bad preferences row never prevents the app from starting:

```dart
// notification_service.dart — scheduleReminder
Future<void> scheduleReminder({
  required String hhMm,
  required bool includeWeekends,
}) async {
  final parts = hhMm.split(':');
  if (parts.length != 2) return; // guard malformed input
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null ||
      hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return; // silently skip rather than crash
  }
  // ... rest of method unchanged
}

// notification_service.dart — initialize()
try {
  final prefs = await db.userPreferencesDao.getOrDefault();
  if (prefs.weeklyNotificationEnabled) {
    await _scheduleWeeklySummaryFromDb(db);
  }
  if (prefs.reminderEnabled && prefs.reminderTime != null) {
    await scheduleReminder(
      hhMm: prefs.reminderTime!,
      includeWeekends: prefs.weekendReminder,
    );
  }
} on Exception catch (e, s) {
  // Log and continue — a bad preferences row must never crash startup.
  debugPrint('NotificationService.initialize: $e\n$s');
} finally {
  await db.close();
}
```

---

## Warnings

### WR-01: Weekly summary notification body is stale — reflects enable-time data, not the actual week it fires for

**File:** `lib/notifications/notification_service.dart:67-85`

**Issue:** `scheduleWeeklySummary` builds the notification body by querying the current week's trips at the moment the user enables the toggle. The body string (e.g., `"1h 23m total, 14m in traffic"`) is then fixed in the `zonedSchedule` call. Because `matchDateTimeComponents.dayOfWeekAndTime` repeats the alarm weekly, every Sunday the user receives the same static body reflecting data from the week the toggle was first enabled — not the actual week that just ended. For a stats-based notification, this is a logic error: the displayed numbers will be wrong (and increasingly wrong over time).

**Fix:** The notification body must be computed at fire time, not at schedule time. The standard approach with `flutter_local_notifications` is to use a foreground-service or `AlarmManager`-style callback that queries the DB at delivery time, or to reschedule the notification on each app launch with a fresh body. The simplest correct implementation is to reschedule weekly in `initialize()` every time the app starts (which already happens), and also reschedule when the user opens the app on/after Sunday evening. Remove the body-building from `scheduleWeeklySummary`; compute `scheduledDate` only:

```dart
// Reschedule with fresh body every app launch (already done in initialize).
// In scheduleWeeklySummary, pass a pre-built body from the caller so the
// caller controls when the data is fresh, OR move body-building out:
Future<void> scheduleWeeklySummary(AppDatabase db) async {
  await cancelWeeklySummary();
  final body = await _buildWeeklyBody(db); // Always uses current week data
  await _plugin.zonedSchedule(
    id: kWeeklySummaryNotificationId,
    // ... same as before
  );
}
```

Since `initialize()` already calls `_scheduleWeeklySummaryFromDb` on every app start, the body will be refreshed each time the user opens the app — ensuring it reflects at minimum the prior week's data by the time Sunday evening arrives. Document this behavior in the code. The duplicate `_scheduleWeeklySummaryFromDb` method (see WR-05) should be collapsed so there is one canonical scheduling path that is always called.

---

### WR-02: `_toggleWeeklySummary` creates a second `AppDatabase()` instance, bypassing the Riverpod-managed connection

**File:** `lib/features/settings/screens/settings_screen.dart:270`

**Issue:** When the user enables the weekly summary, `_toggleWeeklySummary` calls `AppDatabase()` directly to open a second connection to the SQLite file. The project's `appDatabaseProvider` Riverpod provider is the canonical, lifecycle-managed database connection. Opening a second `AppDatabase` instance runs a second Drift connection that opens its own write statements against the same on-disk file. SQLite WAL mode handles concurrent reads safely, but this bypasses the Riverpod connection pool, means the extra connection is not managed by the framework's disposal lifecycle, and violates the "follow existing patterns" rule from CLAUDE.md. The `try/finally` does close it, but the pattern is architecturally incorrect and error-prone.

**Fix:** Pass the `AppDatabase` from the Riverpod provider into `scheduleWeeklySummary` instead of constructing a new one:

```dart
// settings_screen.dart
Future<void> _toggleWeeklySummary(
  WidgetRef ref,
  UserPreferencesValue prefs,
  bool value,
) async {
  await ref
      .read(userPreferencesDaoProvider)
      .upsert(_copyPrefs(prefs, weeklyNotificationEnabled: value));
  final service = NotificationService();
  if (value) {
    // Use the Riverpod-managed DB instance — no second connection opened.
    final db = ref.read(appDatabaseProvider);
    await service.scheduleWeeklySummary(db);
  } else {
    await service.cancelWeeklySummary();
  }
}
```

---

### WR-03: `context.mounted` guard in `_pickTime` fires before the async gap, not after `showTimePicker`

**File:** `lib/features/settings/screens/settings_screen.dart:310-314`

**Issue:** The guard `if (!context.mounted) return;` at line 310 runs synchronously before the first `await` (`showTimePicker`) — at that point no async gap has occurred so the check is vacuous. The actual async gap is the `await showTimePicker(...)` call at line 311. After `showTimePicker` returns, `context` could point to a disposed widget, yet no guard appears before the subsequent `await ref.read(...).upsert(...)`. Although the `upsert` itself does not use `context`, the missing guard is a correctness hazard: if future maintainers add a `ScaffoldMessenger` call after the `upsert` (a natural refactor), the missing guard will produce a `use after dispose` error. The guard should be repositioned to after the await.

**Fix:**

```dart
Future<void> _pickTime(
  BuildContext context,
  WidgetRef ref,
  UserPreferencesValue prefs,
) async {
  final parts = (prefs.reminderTime ?? '08:00').split(':');
  final initial = TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 8,
    minute: int.tryParse(parts[1]) ?? 0,
  );
  // Remove the pre-await guard here; add it after the await below.
  final picked = await showTimePicker(
    context: context,
    initialTime: initial,
  );
  if (!context.mounted) return; // Guard AFTER the async gap.
  if (picked == null) return;
  // ... rest unchanged
}
```

---

### WR-04: `_copyPrefs` cannot clear `reminderTime` to null — silent data-retention bug

**File:** `lib/features/settings/screens/settings_screen.dart:87-101`

**Issue:** The `_copyPrefs` helper uses `reminderTime: reminderTime ?? prefs.reminderTime`. Because Dart's `??` operator treats an explicitly passed `null` as "no value", calling `_copyPrefs(prefs, reminderTime: null)` silently retains the existing `prefs.reminderTime` instead of clearing it. No current call site passes `null` for `reminderTime`, but the function signature accepts `String? reminderTime` which implies it should be nullable-clearable. If any future code path tries to reset the reminder time to null (e.g., when disabling reminders), the field will not be cleared and stale `reminderTime` data will persist in the DB, causing the app to reschedule a reminder the user thought they deleted.

**Fix:** Use an `Option`/sentinel pattern or explicit boolean parameter to distinguish "not set" from "clear to null". The safest minimal fix is to make the pattern explicit:

```dart
UserPreferencesValue _copyPrefs(
  UserPreferencesValue prefs, {
  String? darkMode,
  bool? reminderEnabled,
  Object? reminderTime = _kUnset, // sentinel
  bool? weekendReminder,
  bool? weeklyNotificationEnabled,
}) {
  const _kUnset = Object();
  return UserPreferencesValue(
    userId: prefs.userId,
    darkMode: darkMode ?? prefs.darkMode,
    morningCutoffHour: prefs.morningCutoffHour,
    eveningCutoffHour: prefs.eveningCutoffHour,
    reminderEnabled: reminderEnabled ?? prefs.reminderEnabled,
    reminderTime: identical(reminderTime, _kUnset)
        ? prefs.reminderTime
        : reminderTime as String?,
    weekendReminder: weekendReminder ?? prefs.weekendReminder,
    weeklyNotificationEnabled:
        weeklyNotificationEnabled ?? prefs.weeklyNotificationEnabled,
  );
}
```

---

### WR-05: `scheduleWeeklySummary` and `_scheduleWeeklySummaryFromDb` are identical — dead duplication

**File:** `lib/notifications/notification_service.dart:67-85` and `222-240`

**Issue:** The two methods are byte-for-byte identical in body: both call `cancelWeeklySummary()`, `_buildWeeklyBody(db)`, and `_plugin.zonedSchedule` with the same parameters. The only difference is that one is `public` and one is `private`. The private variant was introduced to allow `initialize()` to call scheduling without going through the public API, but since both accept the same `AppDatabase db` parameter, the private method serves no purpose. This duplication means any future change to scheduling parameters (e.g., a different `AndroidScheduleMode`) must be made in two places, and the risk of divergence is real.

**Fix:** Delete `_scheduleWeeklySummaryFromDb` and call `scheduleWeeklySummary` directly from `initialize()`:

```dart
// notification_service.dart — initialize()
if (prefs.weeklyNotificationEnabled) {
  await scheduleWeeklySummary(db); // was _scheduleWeeklySummaryFromDb(db)
}
```

---

## Info

### IN-01: Hardcoded UI strings in `ManualEntrySheet` should be in `constants.dart`

**File:** `lib/features/trips/widgets/manual_entry_sheet.dart:158,163,190,193,202,223,245,263,269,273,288,302`

**Issue:** Multiple user-visible strings are hardcoded directly in the widget: `'Add missed commute'`, `'Date'`, `'Duration (HH:MM)'`, `'Time in traffic (optional, HH:MM)'`, `'Distance (optional, km)'`, `'Direction'`, `'To office'`, `'To home'`, `'Cancel'`, `'Save'`, `'Trip added'`, and `"Couldn't save the trip. Try again."`. CLAUDE.md states: "No hardcoded strings for labels, thresholds, or config values. Use `constants.dart`."

**Fix:** Move all these literals to `lib/config/constants.dart` under a `// Phase 7: Manual Entry Sheet` section header and reference the constants in the widget.

---

### IN-02: `DashboardScreen` AppBar `'History'` and `'Stats'` tooltips are hardcoded

**File:** `lib/features/dashboard/screens/dashboard_screen.dart:57,62`

**Issue:** The `tooltip` values for the History and Stats `IconButton`s are raw string literals `'History'` and `'Stats'` rather than named constants from `constants.dart`. This is inconsistent with adjacent buttons which correctly use `kDashboardAddTripTooltip` and `kSettingsTooltip`.

**Fix:** Add `kDashboardHistoryTooltip = 'History'` and `kDashboardStatsTooltip = 'Stats'` to `constants.dart` and use them in `DashboardScreen`.

---

### IN-03: `ManualEntrySheet` `build()` method exceeds the 100-line widget budget

**File:** `lib/features/trips/widgets/manual_entry_sheet.dart:169-311`

**Issue:** The `build()` method on `_ManualEntrySheetState` spans approximately 142 lines, exceeding the CLAUDE.md limit of ~100 lines per widget. The method contains six distinct UI sections (date, duration, traffic, distance, direction, action buttons) each of which could be extracted as a private helper method or a separate private `StatelessWidget`.

**Fix:** Extract the six field sections into private builder methods (e.g., `_buildDateField`, `_buildDurationField`, `_buildTrafficField`, `_buildDistanceField`, `_buildDirectionField`, `_buildActionRow`) to bring `build()` under the 100-line limit.

---

### IN-04: `_buildWeeklyBody` in `NotificationService` duplicates the week-boundary logic from `stats_service.dart`

**File:** `lib/notifications/notification_service.dart:194-218`

**Issue:** The week-start calculation (`today.weekday - DateTime.monday`, `weekStart`, `weekEnd`) and the trip-filter loop are duplicated from `computeStatsSummary` in `lib/features/stats/services/stats_service.dart`. Two independent implementations of the same business rule (Mon–Sun week boundary) can drift out of sync. For example, if the week definition changes (ISO week, locale-aware, etc.) only one site may be updated.

**Fix:** Extract the week-range calculation into a shared utility in `lib/shared/utils/` (e.g., `date_utils.dart`) and call it from both `stats_service.dart` and `notification_service.dart`. The trip-filtering loop itself is minimal enough to remain local to each caller.

---

_Reviewed: 2026-05-05T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
