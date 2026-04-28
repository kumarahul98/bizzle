# Phase 7: Polish & Notifications - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can personalize their app experience through a Settings screen — choosing between System/Light/Dark theme (persisted and instantly applied) and configuring two notification types: a weekly commute summary (Sunday 6pm, user-toggleable) and a daily tracking reminder (user-set time, existing schema).

Requirements covered: UX-02, UX-04, UX-05.

Out of scope: auth/onboarding (Phase 8), sync (Phases 9–10), any new stats views, any changes to tracking behavior.

</domain>

<decisions>
## Implementation Decisions

### Settings Screen Entry Point
- **D-01:** Add a 4th trailing `IconButton` (settings/gear icon) to the Dashboard AppBar, alongside the existing history, stats, and add icons. New route `kRouteSettings` → `SettingsScreen` at `lib/features/settings/screens/settings_screen.dart`. New `lib/features/settings/` feature folder with `screens/` and `providers/` subdirectories.

### Settings Screen Layout
- **D-02:** Two sections on a single scrollable screen:
  - **Appearance** section header → dark mode control (3 RadioListTile rows)
  - **Notifications** section header → weekly summary toggle + tracking reminder subsection (toggle + time row + weekend toggle)
  - Material 3 `ListTile` / `SwitchListTile` pattern; section headers use `Text` with `labelLarge` or similar style

### Dark Mode Toggle
- **D-03:** Three `RadioListTile` rows in the Appearance section: "System default" / "Light" / "Dark". Maps to `darkMode` column values `kDarkModeSystem` / `kDarkModeLight` / `kDarkModeDark` in `user_preferences`.
- **D-04:** Theme change is **instant** — no restart needed. `app.dart` (`TraevyApp`) watches a `userPreferenceProvider` (manual `StreamProvider<UserPreferencesValue>`) and maps `darkMode` string to `ThemeMode` in `build()`. `MaterialApp.themeMode:` becomes dynamic instead of the current hardcoded `ThemeMode.system`.

### Weekly Summary Notification
- **D-05:** Fires **Sunday at 6pm** (local time) every week. Uses `flutter_local_notifications` `zonedSchedule` with `DateTimeComponents.dayOfWeekAndTime` repeat.
- **D-06:** Notification content: Title = `kWeeklySummaryNotificationTitle` (e.g., "Your week in commute"); Body = `kWeeklySummaryNotificationBody` template formatted with `formatDuration(weekTotalSeconds)` and `formatDuration(weekStuckSeconds)` from `statsSummaryProvider`. If no trips that week, body = "No commutes recorded this week" (Claude's discretion for exact text).
- **D-07:** User-toggleable in the Notifications section via a `SwitchListTile`. Requires a new **`weeklyNotificationEnabled` boolean column** added to the `UserPreferences` Drift table (default `false`). This is a **schema migration** — must increment the Drift database version and add a migration step.
- **D-08:** Notification scheduling: schedule on app start (in `main.dart` or an app-startup provider) if enabled; cancel when disabled. Re-schedule on time-zone change is Claude's discretion.

### Tracking Reminder Notification
- **D-09:** Uses existing schema fields: `reminderEnabled` (bool), `reminderTime` (HH:mm string), `weekendReminder` (bool) — no schema changes needed for the reminder itself.
- **D-10:** Settings UI: `SwitchListTile` for enable/disable. When enabled, a `ListTile` row appears below showing the current time (e.g., "8:00 AM") — tapping opens Flutter's `showTimePicker()`. Below that, a `SwitchListTile` for "Include weekends". The time row and weekend toggle are hidden (or disabled) when the reminder is off.
- **D-11:** Notification content: Title = `kReminderNotificationTitle` (e.g., "Time to track your commute"); Body = `kReminderNotificationBody` (e.g., "Tap to start recording your commute"). Fixed text, no dynamic data. Tapping opens app.
- **D-12:** Scheduling: daily scheduled notification using `flutter_local_notifications` `zonedSchedule` with `DateTimeComponents.time` (daily) or `DateTimeComponents.dayOfWeekAndTime` (weekdays only when `weekendReminder = false`). Cancel + reschedule whenever `reminderEnabled`, `reminderTime`, or `weekendReminder` changes in settings.

### Schema Migration
- **D-13:** Drift database version bumped from current to `+1`. New migration step adds `weeklyNotificationEnabled` boolean column to `UserPreferences` table with default `false`. Migration must use `m.addColumn(userPreferences, userPreferences.weeklyNotificationEnabled)`.

### Notification Channels
- **D-14:** Two new `flutter_local_notifications` Android channels (separate from the existing tracking channel `kTrackingNotificationChannelId`):
  - Weekly summary channel: `kWeeklySummaryChannelId` (Claude's discretion for exact id/name)
  - Reminder channel: `kReminderChannelId` (Claude's discretion for exact id/name)
  - Initialize both channels in the existing `TrackingNotificationService.initialize()` call or in a new `NotificationService.initialize()` call from `main.dart`.

### Claude's Discretion
- Exact channel IDs, channel names, channel descriptions for the two new channels
- Whether to create a new `NotificationService` or extend `TrackingNotificationService`
- Settings screen AppBar title
- Section header styling (color, weight, padding)
- Exact empty-week text in weekly notification body
- How the time picker result formats in the ListTile subtitle (e.g., `DateFormat.jm()`)
- Whether weekend toggle uses `enabled:` property or `Visibility` widget to hide when reminder is off
- File naming within `lib/features/settings/`
- Provider naming for user preferences stream

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project spec
- `CLAUDE.md` — Full project spec: manual Riverpod 3.x providers, very_good_analysis, feature-first layout, no hardcoded strings, widgets under 100 lines
- `.planning/PROJECT.md` — Core value, offline-first constraint, Drift as source of truth
- `.planning/REQUIREMENTS.md` — UX-02, UX-04, UX-05 acceptance criteria

### Prior phase artifacts
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-04: `getOrDefault()` pattern for user_preferences, `kDarkModeSystem`/`kDarkModeLight`/`kDarkModeDark` constants, Drift migration conventions
- `.planning/phases/02-core-tracking/02-CONTEXT.md` — D-02: manual Riverpod providers; `flutter_local_notifications` initialization pattern, channel setup
- `.planning/phases/06-dashboard/06-CONTEXT.md` — D-07: AppBar trailing icons pattern; D-01: DashboardScreen as app root

### Existing code this phase builds on
- `lib/config/theme.dart` — `lightTheme`, `darkTheme` already defined; Phase 7 wires them dynamically
- `lib/app.dart` — `MaterialApp.themeMode: ThemeMode.system` (hardcoded) → Phase 7 makes it dynamic via `userPreferenceProvider`
- `lib/database/tables/user_preferences_table.dart` — Schema: `darkMode`, `reminderEnabled`, `reminderTime`, `weekendReminder` all exist; Phase 7 adds `weeklyNotificationEnabled`
- `lib/database/daos/user_preferences_dao.dart` — `getOrDefault()`, `upsert()` methods; `UserPreferencesValue` class
- `lib/database/providers.dart` — Existing Drift DB provider; Phase 7 adds `userPreferenceProvider` watching `UserPreferencesDao.watch()`
- `lib/features/tracking/services/tracking_notification_service.dart` — D-14 UNIFICATION CONTRACT: do NOT reuse `kTrackingNotificationChannelId` for new channels; initialize new channels alongside the tracking channel
- `lib/config/constants.dart` — `kDarkModeSystem`, `kDarkModeLight`, `kDarkModeDark`; Phase 7 adds notification title/body constants and new channel IDs
- `lib/database/database.dart` — Drift `AppDatabase` class; Phase 7 bumps `schemaVersion` and adds migration step
- `lib/shared/utils/formatters.dart` — `formatDuration(int seconds)` for weekly notification body

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lightTheme` / `darkTheme` in `lib/config/theme.dart` — already defined, just need dynamic wiring
- `UserPreferencesDao.getOrDefault()` / `upsert()` — read and write preferences without boilerplate
- `formatDuration(int seconds)` in `lib/shared/utils/formatters.dart` — use for weekly notification body
- `statsSummaryProvider` (Phase 5) — provides `weekTotalSeconds` and `weekStuckSeconds` for weekly notification content
- `FlutterLocalNotificationsPlugin` — already initialized in `tracking_notification_service.dart`; new channels use the same plugin instance

### Established Patterns
- **Manual Riverpod 3.x** — `StreamProvider<UserPreferencesValue>` watching `UserPreferencesDao.watch()` for reactive theme + notification state
- **Feature-first** — `lib/features/settings/screens/`, `lib/features/settings/providers/`
- **Drift upsert pattern** — `UserPreferencesDao.upsert(UserPreferencesValue(...))` after each settings change
- **very_good_analysis** — doc comments on all public members, alphabetical imports, no dynamic

### Integration Points
- `lib/app.dart` (`TraevyApp`): `themeMode:` changes from `ThemeMode.system` to `ref.watch(userPreferenceProvider).when(data: (prefs) => prefs.themeMode, ...)` — the single reactive wiring point for dark mode
- `lib/database/database.dart`: bump `schemaVersion`, add `MigrationStrategy` step for `weeklyNotificationEnabled` column
- `lib/features/dashboard/screens/dashboard_screen.dart`: add 4th gear `IconButton` to AppBar (alongside existing history, stats, add icons)
- `main.dart`: initialize new notification channels; schedule weekly/reminder notifications on app start based on current preferences

</code_context>

<specifics>
## Specific Ideas

- Settings entry: gear icon (4th) in Dashboard AppBar → same pattern as history/stats/add icons already there
- Dark mode: 3 RadioListTile rows ("System default", "Light", "Dark") — no SegmentedButton
- Weekly notification: Sunday 6pm, "Your week in commute" / "X total, Y in traffic"
- Reminder: tap row → `showTimePicker()` → save HH:mm to `reminderTime`; weekend toggle visible when reminder enabled

</specifics>

<deferred>
## Deferred Ideas

- **Weekly notification user-configurable time** — the user considered letting users pick the notification day/time, deferred to keep scope tight (always Sunday 6pm in v0.1)
- **Notification deep-link to Stats screen** — tapping weekly notification could open Stats screen directly; deferred (requires notification action wiring)

</deferred>

---

*Phase: 07-polish-notifications*
*Context gathered: 2026-04-28*
