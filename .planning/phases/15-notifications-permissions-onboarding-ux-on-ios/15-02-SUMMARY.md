---
phase: 15-notifications-permissions-onboarding-ux-on-ios
plan: "02"
subsystem: ios-permissions-formatters-onboarding
tags: [tdd, green, ios-branch, permissions, formatters, onboarding, dashboard]
dependency_graph:
  requires:
    - test/unit/shared/utils/formatters_test.dart (RED scaffold — Plan 01)
    - test/unit/features/tracking/tracking_permission_service_test.dart (iOS RED groups — Plan 01)
  provides:
    - lib/shared/utils/formatters.dart (formatElapsed + formatStuck)
    - lib/features/tracking/services/tracking_permission_service.dart (iOS branch)
    - lib/features/onboarding/screens/onboarding_location_priming_screen.dart
    - lib/features/tracking/widgets/permission_banner.dart (optional body param)
    - lib/config/constants.dart (Phase 15 block)
    - lib/config/routes.dart (kRouteLocationPriming registered)
    - lib/features/dashboard/screens/dashboard_screen.dart (iOS priming gate)
  affects:
    - Plans 03, 05 (consume formatElapsed + formatStuck)
    - Plan 03 (consumes kTrackingNotificationBodyLine1/2Template from constants)
tech_stack:
  added: []
  patterns:
    - defaultTargetPlatform iOS branch in services (not dart:io Platform)
    - debugDefaultTargetPlatformOverride in tests for iOS code path
    - Sticky-footer layout: Scaffold→SafeArea→LayoutBuilder→SingleChildScrollView→ConstrainedBox→IntrinsicHeight
    - Optional body param pattern for platform-specific widget copy
    - iOS Start gate: currentStatus() probe (never prompts) to detect undetermined state
key_files:
  created:
    - lib/features/onboarding/screens/onboarding_location_priming_screen.dart
  modified:
    - lib/shared/utils/formatters.dart
    - lib/features/tracking/services/tracking_notification_service.dart
    - lib/features/tracking/services/tracking_permission_service.dart
    - lib/config/constants.dart
    - lib/config/routes.dart
    - lib/features/tracking/widgets/permission_banner.dart
    - lib/features/dashboard/screens/dashboard_screen.dart
decisions:
  - "Priming screen is StatelessWidget (not ConsumerWidget) — uses Permission.locationWhenInUse.request() directly rather than via TrackingPermissionService, simpler and no ref needed in build"
  - "iOS Start gate uses currentStatus() probe returning denied as the undetermined signal; no persisted 'shown' flag needed since once granted it returns foregroundOnly/fullyGranted"
  - "PermissionBanner call site not yet present in production (tracking screen has no active rendering of foregroundOnly banner) — banner updated with optional body param, ready for future wiring"
metrics:
  duration: "~7min"
  completed: "2026-06-03"
  tasks: 3
  files: 8
---

# Phase 15 Plan 02: iOS Permission Correctness + Shared Formatters Summary

**One-liner:** iOS platform branch in TrackingPermissionService (never probes notification), shared formatElapsed/formatStuck formatters, iOS location priming screen with dashboard Start gate — all RED scaffolds from Plan 01 now GREEN.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add shared formatters (formatElapsed, formatStuck) | 4a7bfb7 | lib/shared/utils/formatters.dart, lib/features/tracking/services/tracking_notification_service.dart |
| 2 | iOS branch in TrackingPermissionService (preflight + currentStatus) | 8b85016 | lib/features/tracking/services/tracking_permission_service.dart |
| 3 | Location priming screen + route + dashboard Start gate + degraded banner copy | 7897a52 | lib/config/constants.dart, lib/config/routes.dart, lib/features/onboarding/screens/onboarding_location_priming_screen.dart, lib/features/tracking/widgets/permission_banner.dart, lib/features/dashboard/screens/dashboard_screen.dart |

## Test Results

| Test File | Before | After |
|-----------|--------|-------|
| `test/unit/shared/utils/formatters_test.dart` | RED (formatElapsed/formatStuck undefined) | GREEN (15/15) |
| `test/unit/features/tracking/tracking_permission_service_test.dart` | RED (iOS tests failed — probed notification on iOS) | GREEN (23/23 — 18 Android + 5 iOS) |
| Full suite | 405 passing, 3 failing (Wave 0 RED scaffolds) | 405 passing, 3 failing (same Wave 0 RED scaffolds — unchanged, Plans 03/05 scope) |

The 3 remaining failures are pre-existing RED scaffolds for Plans 03/05:
- `live_activity_service_test.dart` — LiveActivityService undefined (Plan 05)
- `tracking_notification_service_test.dart` — forTesting + template constants undefined (Plan 03)
- `notification_service_test.dart` — requestIOSNotificationPermission undefined (Plan 03)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing functionality] Simplified priming screen to StatelessWidget**
- **Found during:** Task 3
- **Issue:** The plan specified ConsumerWidget + ref for TrackingPermissionService access, but the CTA only needs `Permission.locationWhenInUse.request()` directly (which is what the service wraps). Using ConsumerWidget added an unused `ref` and an unused `tracking_providers` import, triggering `unused_import` warning that would fail analyze.
- **Fix:** Changed to `StatelessWidget`, used `Permission.locationWhenInUse.request()` directly. The screen does not need a service instance — it only fires the one-shot system dialog.
- **Files modified:** lib/features/onboarding/screens/onboarding_location_priming_screen.dart
- **Commit:** 7897a52

## Known Stubs

None — all formatter functions are fully implemented and tested. The priming screen renders real copy from constants. The dashboard gate uses real permission probing. No placeholders remain.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| T-15-03 mitigated | lib/features/tracking/services/tracking_permission_service.dart | iOS branch only returns location-derived statuses; never returns notificationDenied on iOS — confirmed by 5 new iOS tests |

No new threat surface introduced. The priming screen is informational only (T-15-04 accepted per plan).

## Self-Check: PASSED

| Item | Result |
|------|--------|
| lib/shared/utils/formatters.dart (formatElapsed + formatStuck) | FOUND |
| lib/features/tracking/services/tracking_permission_service.dart (iOS branch) | FOUND |
| lib/features/onboarding/screens/onboarding_location_priming_screen.dart | FOUND |
| lib/config/constants.dart (kRouteLocationPriming present) | FOUND |
| lib/config/routes.dart (kRouteLocationPriming registered) | FOUND |
| lib/features/tracking/widgets/permission_banner.dart (body param) | FOUND |
| lib/features/dashboard/screens/dashboard_screen.dart (kRouteLocationPriming gate) | FOUND |
| Commit 4a7bfb7 (Task 1) | FOUND |
| Commit 8b85016 (Task 2) | FOUND |
| Commit 7897a52 (Task 3) | FOUND |
