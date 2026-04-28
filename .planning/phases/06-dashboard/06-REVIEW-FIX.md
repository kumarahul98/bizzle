---
phase: 06-dashboard
fixed_at: 2026-04-28T00:00:00Z
review_path: .planning/phases/06-dashboard/06-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 06: Code Review Fix Report

**Fixed at:** 2026-04-28
**Source review:** .planning/phases/06-dashboard/06-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed Issues

### WR-01: Dangling `else` renders empty `ListView` when tracking is active with no completed trips

**Files modified:** `lib/features/dashboard/widgets/today_trips_section.dart`
**Commit:** 11ee1bc
**Applied fix:** Replaced the `if/else` pair (where `else` fired whenever `trips.isEmpty && !isActive` was false, including the active-with-no-trips case) with two independent `if` checks: `if (trips.isEmpty && !isActive)` for the empty state and `if (trips.isNotEmpty)` for the ListView. The `InProgressCard` `if (isActive)` branch on line 48 was already an independent check and required no change.

---

### WR-02: Missing `context.mounted` guard before `Navigator.pushNamed` in `_handleStart`

**Files modified:** `lib/features/dashboard/screens/dashboard_screen.dart`
**Commit:** 10347cf
**Applied fix:** Added `if (!context.mounted) return;` immediately before `await Navigator.pushNamed(context, kRouteTracking)` at line 145. The two `_showSettingsDialog` branches already `return` early so only this single guard was needed to satisfy the project invariant that `context.mounted` is checked after every await.

---

### WR-03: Hardcoded user-visible strings not routed through `constants.dart`

**Files modified:** `lib/config/constants.dart`, `lib/features/dashboard/screens/dashboard_screen.dart`, `lib/features/trips/services/trip_actions.dart`
**Commit:** 73241f8
**Applied fix:** Added 11 new string constants to `lib/config/constants.dart` under the Phase 6 section: `kDashboardAddTripTooltip`, `kDashboardPermDeniedTitle`, `kDashboardPermDeniedBody`, `kDashboardNotifDeniedTitle`, `kDashboardNotifDeniedBody`, `kDialogCancel`, `kDialogOpenSettings`, `kTripDeleteDialogTitle`, `kTripDeleteDialogBody`, `kTripDeleteConfirm`, `kTripDeletedSnackbar`, and `kTripDeleteErrorSnackbar`. Added the `constants.dart` import to `trip_actions.dart`. Replaced all 13 inline string literals across both call-site files with the corresponding constants.

---

_Fixed: 2026-04-28_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
