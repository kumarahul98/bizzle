---
phase: 06-dashboard
reviewed: 2026-04-28T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - lib/app.dart
  - lib/config/constants.dart
  - lib/features/dashboard/providers/dashboard_providers.dart
  - lib/features/dashboard/screens/dashboard_screen.dart
  - lib/features/dashboard/widgets/in_progress_card.dart
  - lib/features/dashboard/widgets/today_trips_section.dart
  - lib/features/dashboard/widgets/weekly_summary_card.dart
  - lib/features/trips/services/trip_actions.dart
  - test/unit/features/dashboard/dashboard_providers_test.dart
  - test/widget/app_test.dart
  - test/unit/app_bootstrap_test.dart
  - test/widget/features/dashboard/dashboard_screen_test.dart
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-04-28
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

Phase 6 introduces `DashboardScreen` as the app root, three new widgets (`WeeklySummaryCard`, `TodayTripsSection`, `InProgressCard`), a derived `todaysTripSummariesProvider`, and a shared `handleDeleteTrip` helper. The architecture is sound: the screen owns all provider subscriptions and passes values down to stateless children, `context.mounted` guards are correctly placed on the critical async paths, and the test suite provides solid coverage of both the provider logic and the widget integration.

Three issues warrant attention before merge. The most significant is a conditional logic error in `TodayTripsSection` that renders an empty `ListView` when tracking is active but no trips have been completed yet — the dangling `else` binds to the wrong `if`. The other two warnings are a missing `context.mounted` guard in `_handleStart` (a secondary await that can reach `Navigator.pushNamed` with a potentially stale context) and a cluster of hardcoded UI strings in `dashboard_screen.dart` and `trip_actions.dart` that bypass `constants.dart`.

---

## Warnings

### WR-01: Dangling `else` renders empty `ListView` when tracking is active with no completed trips

**File:** `lib/features/dashboard/widgets/today_trips_section.dart:50-70`

**Issue:** The `if/else` pair on lines 50-70 reads:

```dart
if (trips.isEmpty && !isActive)
  Center(empty state)
else
  ListView(...)
```

The `else` branch fires whenever `trips.isEmpty && !isActive` is `false`. This includes the case where `trips.isEmpty == true` AND `isActive == true` — i.e., tracking has just started and no completed trips exist yet. In that case `InProgressCard` is shown (line 48-49) AND the `else` arm renders an empty `ListView` with zero children below it. The intent is clearly to show nothing in that state.

**Fix:**
```dart
if (isActive)
  InProgressCard(active: trackingState as TrackingActive),
if (trips.isEmpty && !isActive)
  Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        kDashboardEmptyStateLabel,
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    ),
  ),
if (trips.isNotEmpty)
  ListView(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: <Widget>[
      for (final trip in trips) TripCard(summary: trip),
    ],
  ),
```

Converting all three branches to independent `if` checks eliminates the dangling-else ambiguity entirely.

---

### WR-02: Missing `context.mounted` guard before `Navigator.pushNamed` in `_handleStart`

**File:** `lib/features/dashboard/screens/dashboard_screen.dart:145`

**Issue:** `_handleStart` guards `context.mounted` after the first `await service.currentStatus()` call (line 122), but the method can then enter either of two `await _showSettingsDialog(...)` branches and `return`, or fall through to `await Navigator.pushNamed(context, kRouteTracking)` at line 145. The `_showSettingsDialog` helper itself contains two `await` calls (`showDialog` and conditionally `service.openSystemSettings()`). By the time control returns from `_showSettingsDialog` to line 145, the widget could have been disposed without a mounted check.

The project's stated invariant (CLAUDE.md, `trip_actions.dart` doc comment: "context.mounted is checked after every await") is violated.

**Fix:**
```dart
    if (status == TrackingPermissionStatus.permanentlyDenied) {
      await _showSettingsDialog(context, service, ...);
      return; // already present — fine
    }
    if (status == TrackingPermissionStatus.notificationDenied) {
      await _showSettingsDialog(context, service, ...);
      return; // already present — fine
    }
    // Guard before the final async navigation:
    if (!context.mounted) return;
    await Navigator.pushNamed(context, kRouteTracking);
```

The two `return` statements after `_showSettingsDialog` mean those branches never reach line 145, so only one new guard is needed.

---

### WR-03: Hardcoded user-visible strings not routed through `constants.dart`

**Files:**
- `lib/features/dashboard/screens/dashboard_screen.dart:52,127,129-131,138,140-142,162,166`
- `lib/features/trips/services/trip_actions.dart:23,24,28,36,49,55`

**Issue:** CLAUDE.md rule: "No hardcoded strings for labels, thresholds, or config values. Use `constants.dart`." The following user-facing strings are inlined:

In `dashboard_screen.dart`:
- `'Add trip manually'` (tooltip, line 52)
- `'Location permission denied'` (dialog title, line 127)
- `'Location permission is permanently denied. Open system settings to enable it?'` (dialog body, lines 129-131)
- `'Notifications required'` (dialog title, line 138)
- `'Notifications are required to track commutes in the background. Open system settings to enable them?'` (dialog body, lines 140-142)
- `'Cancel'` (line 162)
- `'Open settings'` (line 166)

In `trip_actions.dart`:
- `'Delete trip?'` (dialog title, line 23)
- `'This trip will be permanently removed.'` (dialog body, line 24)
- `'Cancel'` (line 28)
- `'Delete'` (line 36)
- `'Trip deleted'` (snackbar, line 49)
- `"Couldn't delete the trip. Try again."` (snackbar error, line 55)

**Fix:** Add constants to `lib/config/constants.dart` under a Phase 6 section, e.g.:
```dart
// dashboard_screen.dart dialog strings
const String kDashboardAddTripTooltip = 'Add trip manually';
const String kDashboardPermDeniedTitle = 'Location permission denied';
const String kDashboardPermDeniedBody =
    'Location permission is permanently denied. Open system '
    'settings to enable it?';
const String kDashboardNotifDeniedTitle = 'Notifications required';
const String kDashboardNotifDeniedBody =
    'Notifications are required to track commutes in the '
    'background. Open system settings to enable them?';
const String kDialogCancel = 'Cancel';
const String kDialogOpenSettings = 'Open settings';

// trip_actions.dart dialog/snackbar strings
const String kTripDeleteDialogTitle = 'Delete trip?';
const String kTripDeleteDialogBody = 'This trip will be permanently removed.';
const String kTripDeleteConfirm = 'Delete';
const String kTripDeletedSnackbar = 'Trip deleted';
const String kTripDeleteErrorSnackbar = "Couldn't delete the trip. Try again.";
```

Then reference these constants at the call sites.

---

## Info

### IN-01: `WeeklySummaryCard` shows "0 trips" when today has no trips — inconsistent with empty-state pattern

**File:** `lib/features/dashboard/widgets/weekly_summary_card.dart:46-48`

**Issue:** The `countLabel` logic handles `todayTripCount == 1` (singular) and all other values (plural). When `todayTripCount == 0` the label renders as `"0 trips"`. The card already uses `kStatsEmptyPlaceholder` (`"—"`) for zero durations; the zero-count case is not given the same treatment, creating an inconsistency with the rest of the card's empty-state pattern.

**Fix:**
```dart
final countLabel = switch (todayTripCount) {
  0 => kStatsEmptyPlaceholder,
  1 => kDashboardTripCountSingular,
  _ => '$todayTripCount $kDashboardTripCountPlural',
};
```

---

### IN-02: `DashboardScreen` class exceeds 100-line widget budget

**File:** `lib/features/dashboard/screens/dashboard_screen.dart:19-175`

**Issue:** The `DashboardScreen` class is 148 lines. CLAUDE.md: "Keep widgets under 100 lines. Extract into separate files if a widget exceeds ~100 lines." Three async handler methods (`_handleAddManualTrip`, `_handleStart`, `_showSettingsDialog`) inflate the class alongside the 72-line `build` method.

**Fix:** Extract the permission/dialog logic into a standalone `DashboardPermissionHandler` class (or a free function in a `dashboard_actions.dart` file in the same feature directory). The screen class then delegates to it, keeping the widget file focused on layout.

---

### IN-03: Semantics label in `InProgressCard` uses runtime-computed string — consider `liveRegion`

**File:** `lib/features/dashboard/widgets/in_progress_card.dart:29`

**Issue:** The `Semantics` wrapper uses `label: 'Commute in progress, elapsed: $elapsed'`. Because `elapsed` updates every second (driven by `TrackingActive.elapsedSeconds` from the parent), screen readers will only announce the label when focus moves to the element, not on each update. If the accessibility intent is to announce elapsed time updates, `liveRegion: true` should be set. If not, the label is fine but the `Semantics` widget is wrapping an `InkWell` — the `InkWell` already exposes a tap target, so the outer `Semantics` primarily adds a label. Worth confirming the intended a11y behaviour.

**Fix (if live announcement is desired):**
```dart
Semantics(
  label: 'Commute in progress, elapsed: $elapsed',
  liveRegion: true,  // add this
  child: InkWell(...)
)
```

---

### IN-04: Test infrastructure duplication — `_IdleTrackingNotifier` defined in three test files

**Files:**
- `test/widget/app_test.dart:21-24`
- `test/unit/app_bootstrap_test.dart:22-25`
- `test/widget/features/dashboard/dashboard_screen_test.dart:36-39`

**Issue:** The `_IdleTrackingNotifier` stub class is copy-pasted verbatim in all three test files. This is dead duplication: a change to `TrackingNotifier`'s constructor or `build` signature requires three simultaneous updates.

**Fix:** Extract to a shared `test/helpers/tracking_test_helpers.dart` file and import it in each test:
```dart
// test/helpers/tracking_test_helpers.dart
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';

/// Stub notifier that bypasses flutter_background_service initialisation
/// for widget tests running on non-Android/iOS hosts.
class IdleTrackingNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
}
```

Note: This is a test-code issue only and does not affect production correctness.

---

_Reviewed: 2026-04-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
