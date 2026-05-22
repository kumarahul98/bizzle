---
phase: "08"
plan: "04"
subsystem: dashboard-shell
tags: [flutter, riverpod, navigation, ui-overhaul, indexed-stack]
dependency_graph:
  requires: [08-02-theme, 08-03-primitives]
  provides: [main-shell, dashboard-restyle]
  affects: [app.dart, dashboard_screen, all-tab-screens]
tech_stack:
  added: []
  patterns:
    - IndexedStack 4-tab shell preserving provider state across tab switches
    - mainShellIndexProvider (NotifierProvider<int>) for programmatic tab switching
    - buildLightTheme() in widget tests to supply TraevyTokensExt
key_files:
  created:
    - lib/features/shell/main_shell.dart
    - lib/features/shell/providers/main_shell_provider.dart
    - lib/features/dashboard/widgets/home_header.dart
    - lib/features/dashboard/widgets/hero_record_card.dart
    - lib/features/dashboard/widgets/today_section.dart
    - lib/features/dashboard/widgets/empty_slot_row.dart
    - lib/features/dashboard/widgets/week_loss_card.dart
    - .planning/phases/08-ui-overhaul/08-04-PROVIDER-AUDIT.md
  modified:
    - lib/app.dart
    - lib/config/routes.dart
    - lib/features/dashboard/screens/dashboard_screen.dart
    - lib/features/dashboard/widgets/in_progress_card.dart
    - lib/features/dashboard/providers/dashboard_providers.dart
    - test/widget/app_test.dart
    - test/widget/features/shell/main_shell_test.dart
    - test/widget/features/dashboard/dashboard_screen_test.dart
  deleted:
    - lib/features/dashboard/widgets/today_trips_section.dart
    - lib/features/dashboard/widgets/weekly_summary_card.dart
decisions:
  - IndexedStack (not Navigator) for tab shell — preserves provider subscriptions on tab switch; avoids stream reconnection (Review HIGH #1)
  - No PopScope/WillPopScope on MainShell — default back exits app from any tab (Review MEDIUM #4)
  - mainShellIndexProvider wired into WeekLossCard "See stats →" for programmatic tab switch without route push
  - buildLightTheme() used in dashboard test to inject TraevyTokensExt; avoids null-check crash on extension access
metrics:
  duration: "~4 hours"
  completed: "2026-05-14T17:07:17Z"
  tasks_completed: 4
  files_changed: 18
---

# Phase 08 Plan 04: Dashboard + Shell Restyle Summary

MainShell IndexedStack shell with 4-tab NavigationBar, plus full Dashboard restyle replacing AppBar/FAB/WeeklySummaryCard with HomeHeader/HeroRecordCard/TodaySection/WeekLossCard; 11/11 dashboard tests GREEN, analyzer clean.

## Tasks Completed

| Task | Name | Commit | Key Output |
|------|------|--------|-----------|
| 0 | Provider disposal audit | ffb4f4c | 08-04-PROVIDER-AUDIT.md — all 10 providers non-autoDispose, no code changes |
| 1 | MainShell + provider + app.dart + tests | f020e80 | main_shell.dart, main_shell_provider.dart, main_shell_test.dart (5 tests GREEN) |
| 2 | Dashboard restyle | 26c2341 | 5 new widgets, 2 deleted, InProgressCard fixed, DashboardScreen refactored |
| 3 | Test updates | 12488b6 | dashboard_screen_test.dart — 11 tests GREEN, obsolete FAB/AppBar assertions removed |

## Decisions Made

1. **IndexedStack for tab shell** — mounts all 4 tabs simultaneously so Riverpod providers stay alive across tab switches. Alternative (Navigator-based tabs) would dispose/reconnect streams on every switch, triggering unexpected rebuilds.

2. **No PopScope on MainShell** — Review MEDIUM #4 verified: back button from any tab exits the app (the expected Android behavior). No override needed because tab switches are state updates, not route pushes.

3. **mainShellIndexProvider for WeekLossCard "See stats →"** — WeekLossCard calls `ref.read(mainShellIndexProvider.notifier).setIndex(2)` instead of `Navigator.pushNamed`. This keeps the shell's index in sync and avoids duplicate route stack entries.

4. **buildLightTheme() in tests** — All new dashboard widgets call `Theme.of(context).extension<TraevyTokensExt>()!`. Plain `MaterialApp()` without a theme containing that extension caused null-check crashes. Fix: supply `theme: buildLightTheme()` in all pumped tests.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] crossAxisAlignment: CrossAxisAlignment.center redundant default in HeroRecordCard**
- **Found during:** Task 2 verify (flutter analyze)
- **Issue:** `avoid_redundant_argument_values` — Column default is `.center`
- **Fix:** Removed the explicit `crossAxisAlignment` argument
- **Files modified:** `lib/features/dashboard/widgets/hero_record_card.dart`
- **Commit:** 26c2341

**2. [Rule 1 - Bug] Redundant `.clamp()` calls and default `height: 14` in WeekLossCard**
- **Found during:** Task 2 verify (flutter analyze)
- **Issue:** `movingMins.clamp(0, movingMins)` and `stuckMins.clamp(0, stuckMins)` are tautological; `height: 14` is StuckBar's default
- **Fix:** Removed clamp calls and default height argument
- **Files modified:** `lib/features/dashboard/widgets/week_loss_card.dart`
- **Commit:** 26c2341

**3. [Rule 1 - Bug] TripCard → TripRowCard in dashboard test**
- **Found during:** Task 3 test run
- **Issue:** Test imported `TripCard` (trips/widgets) but `TodaySection` uses `TripRowCard` (shared/widgets)
- **Fix:** Updated import and assertion to `TripRowCard`
- **Files modified:** `test/widget/features/dashboard/dashboard_screen_test.dart`
- **Commit:** 12488b6

**4. [Rule 1 - Bug] TraevyTokensExt null crash in dashboard tests**
- **Found during:** Task 3 test run (first attempt)
- **Issue:** `_pumpDashboardScreen` used plain `MaterialApp()` without `TraevyTokensExt`; `HomeHeader.build` crashed on `extension<TraevyTokensExt>()!`
- **Fix:** Added `theme: buildLightTheme()` to `MaterialApp` in `_pumpDashboardScreen`
- **Files modified:** `test/widget/features/dashboard/dashboard_screen_test.dart`
- **Commit:** 12488b6

## Out-of-Scope Failures (Deferred)

`test/widget/features/stats/stats_screen_test.dart` — 3 pre-existing failures related to `"—"` text found twice. These failures existed before Plan 04 (stats_screen_test touches no files modified here). Plans 08-05 and 08-06 (Stats restyle, currently running as background agents) are responsible for fixing these tests.

## Known Stubs

- `HomeHeader` shows `kPlaceholderUserName = 'Traveller'` and `kPlaceholderUserInitial = 'T'` — real user name/avatar wired in Plan 09 (auth integration).
- `EmptySlotRow` shows hardcoded "Evening commute" direction label — the UI-SPEC calls for this as a design placeholder; no future plan is currently assigned to vary it by time-of-day.
- `HeroRecordCard` `autoLabelDirection` defaults to `'To office'` when null — auto-label logic not yet implemented; planned for post-MVP.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

Files confirmed present:
- lib/features/shell/main_shell.dart: FOUND
- lib/features/shell/providers/main_shell_provider.dart: FOUND
- lib/features/dashboard/widgets/home_header.dart: FOUND
- lib/features/dashboard/widgets/hero_record_card.dart: FOUND
- lib/features/dashboard/widgets/today_section.dart: FOUND
- lib/features/dashboard/widgets/empty_slot_row.dart: FOUND
- lib/features/dashboard/widgets/week_loss_card.dart: FOUND
- .planning/phases/08-ui-overhaul/08-04-PROVIDER-AUDIT.md: FOUND

Commits confirmed:
- ffb4f4c: FOUND (provider audit)
- f020e80: FOUND (MainShell)
- 26c2341: FOUND (Dashboard restyle)
- 12488b6: FOUND (test updates)

Deleted files confirmed gone:
- lib/features/dashboard/widgets/today_trips_section.dart: DELETED (intentional)
- lib/features/dashboard/widgets/weekly_summary_card.dart: DELETED (intentional)

Test results: 11/11 dashboard_screen_test GREEN, 5/5 main_shell_test GREEN, lib/ analyze: No issues found.
