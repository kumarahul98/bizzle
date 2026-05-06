---
phase: 07-polish-notifications
plan: "04"
subsystem: settings-ui
tags: [flutter, settings, notifications, manual-entry, stats, ui]
dependency_graph:
  requires:
    - 07-01 (constants, schema v2, migration)
    - 07-03 (userPreferenceProvider, NotificationService, dynamic themeMode)
  provides:
    - SettingsScreen ConsumerWidget with Appearance + Notifications sections
    - Gear icon navigation from DashboardScreen to SettingsScreen
    - kRouteSettings wired in kAppRoutes
    - ManualEntrySheet with optional traffic and distance fields
    - Refined manual trip exclusion in stats_service
  affects:
    - lib/config/routes.dart
    - lib/features/dashboard/screens/dashboard_screen.dart
    - lib/features/trips/widgets/manual_entry_sheet.dart
    - lib/features/trips/providers/trip_management_providers.dart
    - lib/features/stats/services/stats_service.dart
tech_stack:
  added: []
  patterns:
    - RadioGroup ancestor for RadioListTile (Flutter 3.41.6 API — groupValue/onChanged deprecated)
    - Top-level action functions shared across private widgets to meet 100-line class limit
    - _copyPrefs helper pattern for explicit UserPreferencesValue upsert construction
key_files:
  created:
    - lib/features/settings/screens/settings_screen.dart
  modified:
    - lib/config/routes.dart
    - lib/features/dashboard/screens/dashboard_screen.dart
    - lib/features/trips/widgets/manual_entry_sheet.dart
    - lib/features/trips/providers/trip_management_providers.dart
    - lib/features/stats/services/stats_service.dart
    - test/widget/features/settings/settings_screen_test.dart
    - test/unit/features/stats/stats_service_test.dart
decisions:
  - RadioGroup ancestor wraps RadioListTile rows instead of per-tile groupValue/onChanged (Flutter 3.41.6 deprecation)
  - _ReminderRows extracted as 4th private widget to keep all classes under 100 lines
  - Action callbacks moved to top-level functions (not class methods) to share logic across _NotificationsSection and _ReminderRows
  - ref.read(dao) deferred to callback invocation time (not build time) to avoid real DB access in widget tests
metrics:
  duration: ~45 minutes
  completed: 2026-05-06
  tasks: 2
  files: 7
---

# Phase 07 Plan 04: Settings Screen + Manual Entry Fix Summary

SettingsScreen with Appearance/Notifications sections, gear icon navigation, ManualEntrySheet traffic/distance fields, and refined stats exclusion logic.

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | SettingsScreen + Dashboard gear icon + routes wiring | 1639944, 4926cd5 | settings_screen.dart, routes.dart, dashboard_screen.dart |
| 2 | ManualEntrySheet traffic/distance bug fix + stats exclusion update | 0b225a2 | manual_entry_sheet.dart, stats_service.dart, trip_management_providers.dart |

## What Was Built

**SettingsScreen** (`lib/features/settings/screens/settings_screen.dart`):
- `SettingsScreen` ConsumerWidget — watches `userPreferenceProvider`, dispatches `AsyncValue.when`
- `_AppearanceSection` — `RadioGroup` ancestor wrapping 3 `RadioListTile<String>` rows (System/Light/Dark)
- `_NotificationsSection` — weekly summary `SwitchListTile` + delegates reminder UI to `_ReminderRows`
- `_ReminderRows` — reminder time `ListTile` (opens `showTimePicker`) + weekend `SwitchListTile`, both with `AnimatedOpacity` (0.38 disabled, 1.0 enabled, 200ms)
- `_copyPrefs` top-level helper for explicit `UserPreferencesValue` construction (T-07-04-01 mitigation)
- All four classes under 100 lines each

**Routes & Navigation**:
- `kRouteSettings` wired in `kAppRoutes` → `SettingsScreen` in `lib/config/routes.dart`
- 4th gear `IconButton` with `kSettingsTooltip` appended to `DashboardScreen` AppBar actions

**ManualEntrySheet**:
- Added optional "Time in traffic (HH:MM)" `TextField` with HH:MM validation
- Added optional "Distance (km)" `TextField` with decimal numeric input
- `_save()` parses both fields and passes `timeStuckSeconds` and `distanceMeters` to `insertManualTrip`

**TripManagementNotifier.insertManualTrip**:
- Added optional `int timeStuckSeconds = 0` and `double distanceMeters = 0` parameters
- Values clamped to valid ranges before writing `TripsCompanion`

**stats_service.dart**:
- Refined manual trip exclusion: `isBlankManualEntry = trip.isManualEntry && trip.timeStuckSeconds == 0 && trip.distanceMeters == 0`
- Manual trips where user entered traffic or distance data are now included in `weekStuckSeconds`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] RadioListTile.groupValue/onChanged deprecated in Flutter 3.41.6**
- **Found during:** Task 1 — flutter analyze on settings_screen.dart
- **Issue:** `RadioListTile.groupValue` and `onChanged` deprecated after Flutter 3.32.0; replaced by `RadioGroup` ancestor widget
- **Fix:** Wrapped 3 `RadioListTile` rows in a `RadioGroup<String>` ancestor; removed per-tile `groupValue`/`onChanged` props
- **Files modified:** lib/features/settings/screens/settings_screen.dart
- **Commit:** 1639944

**2. [Rule 1 - Bug] Test helper missing provider overrides for DashboardScreen**
- **Found during:** Task 1 — test run of `_pumpDashboardWithRoutes`
- **Issue:** `trackingStateProvider` (uses `FlutterBackgroundService`) and `allTripSummariesProvider`/`statsSummaryProvider` (use real Drift) crashed on test host without overrides
- **Fix:** Added `_IdleTrackingNotifier`, `allTripSummariesProvider.overrideWith(...)`, `statsSummaryProvider.overrideWith(...)` to `_pumpDashboardWithRoutes`; removed unresolvable `<Override>[]` typed list annotation
- **Files modified:** test/widget/features/settings/settings_screen_test.dart
- **Commit:** 1639944

**3. [Rule 1 - Bug] ref.read(userPreferencesDaoProvider) at build() time caused pending timers in tests**
- **Found during:** Task 1 — first test run showed "Pending timers" from AppDatabase being opened
- **Issue:** Resolving `userPreferencesDaoProvider` at widget build time triggered `appDatabaseProvider` → real SQLite timer even with `userPreferenceProvider` overridden
- **Fix:** Moved `ref.read(userPreferencesDaoProvider)` into each callback closure so it only executes when the user actually taps a control
- **Files modified:** lib/features/settings/screens/settings_screen.dart
- **Commit:** 1639944

**4. [Rule 2 - Missing critical functionality] _NotificationsSection exceeded 100-line CLAUDE.md limit**
- **Found during:** Task 1 post-commit verification — class was 187 lines
- **Issue:** CLAUDE.md mandates widgets under 100 lines; plan explicitly states each class must be under 100 lines
- **Fix:** Extracted `_ReminderRows` as 4th private widget; moved 4 async action callbacks to top-level functions; added `_copyPrefs` helper to reduce repetition
- **Files modified:** lib/features/settings/screens/settings_screen.dart
- **Commit:** 4926cd5

## Known Stubs

None — all fields wire to real Drift reads/writes and notification scheduling.

## Threat Flags

None — all threat model mitigations from `<threat_model>` are implemented:
- T-07-04-01: `_copyPrefs` helper ensures every `upsert` call passes all fields explicitly
- T-07-04-02: `if (picked == null) return;` guard in `_pickTime`
- T-07-04-03: `FilteringTextInputFormatter` on distance field; `double.tryParse` defaults to 0.0
- T-07-04-04: `FilteringTextInputFormatter` on traffic field; `parseHhMm` validates before save
- T-07-04-05: NotificationService calls are fire-and-forget (`unawaited`) — errors don't block UI

## Self-Check: PASSED

Files created/exist:
- lib/features/settings/screens/settings_screen.dart: FOUND
- lib/config/routes.dart (kRouteSettings + SettingsScreen): FOUND
- lib/features/dashboard/screens/dashboard_screen.dart (gear icon): FOUND
- lib/features/trips/widgets/manual_entry_sheet.dart (traffic + distance fields): FOUND
- lib/features/stats/services/stats_service.dart (refined exclusion): FOUND

Commits verified:
- 1639944 feat(07-04): SettingsScreen + Dashboard gear icon + routes wiring
- 0b225a2 fix(07-04): ManualEntrySheet traffic/distance fields + stats exclusion fix
- 4926cd5 refactor(07-04): split _NotificationsSection to meet 100-line limit

Test results:
- test/widget/features/settings/settings_screen_test.dart: 10/10 GREEN
- test/unit/features/stats/stats_service_test.dart: 15/15 GREEN
- flutter analyze: zero issues on all modified files
