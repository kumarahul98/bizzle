---
phase: quick-260802-dgp
plan: 01
subsystem: settings, tracking
tags: [location-picker, permissions, gps, tracking-permission-service, snackbar-feedback]

# Dependency graph
requires: []
provides:
  - "TrackingPermissionService.requestWhenInUse() — narrow locationWhenInUse-only request + LocationWhenInUseStatus enum"
  - "Location picker prompt-on-open (no saved coord) and non-silent Locate me FAB"
affects: [settings/location_picker_screen.dart, tracking_permission_service.dart, main_shell.dart's shared Open-settings pattern (reused, not modified)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "LocationWhenInUseStatus (granted/denied/permanentlyDenied) — deliberately separate from TrackingPermissionStatus, whose granted variants encode background+notification state a when-in-use-only caller cannot honestly interpret"
    - "Exhaustive switch (no default) over LocationWhenInUseStatus in _locateMe — a future variant is a compile error, not a silent no-op, which is the exact bug class being fixed"
    - "Widget-test permission fakes seed ONLY Permission.locationWhenInUse and throw StateError on any other Permission, so a stray locationAlways/notification call fails loudly"

key-files:
  created: []
  modified:
    - lib/features/tracking/services/tracking_permission_service.dart
    - lib/config/constants.dart
    - lib/features/settings/screens/location_picker_screen.dart
    - test/unit/features/tracking/tracking_permission_service_test.dart
    - test/widget/features/settings/location_picker_screen_test.dart

key-decisions:
  - "New LocationWhenInUseStatus 3-way enum, not a reuse of TrackingPermissionStatus — that enum's granted variants (fullyGranted/foregroundOnly) encode background+notification state that a when-in-use-only caller can neither produce nor honestly interpret"
  - "Permission goes through TrackingPermissionService (permission_handler), never geolocator's own permission API — one permission source of truth, per D-5. Geolocator.getCurrentPosition() stays for the position read only"
  - "_defaultCurrentLocation is now a pure position read with no permission check — permission is entirely the caller's concern (picker's _resolveInitialCenter / _locateMe), not this seam's job"
  - "D-1 explicitly supersedes the old D-13 'never prompt from the picker' rule for this screen only; every dartdoc asserting the old behavior was rewritten, not left standing"

patterns-established: []

requirements-completed: [LOC-01]

# Metrics
duration: ~35min
completed: 2026-08-02
---

# Quick Task 260802-dgp: Location Picker Requests GPS Permission on Open Summary

**The Home/Office location picker now requests `locationWhenInUse` (and only that) when opened on a slot with no saved coordinate, and the "Locate me" FAB always produces an outcome — map move, or one of three distinct SnackBars — instead of silently doing nothing.**

## Performance

- **Duration:** ~35 min
- **Started / Completed:** 2026-08-02
- **Tasks:** 3 completed (TDD-flavored: tests added alongside each behavior change)
- **Files modified:** 5 (0 new)

## Accomplishments

- Added `LocationWhenInUseStatus` (`granted` / `denied` / `permanentlyDenied`) and `TrackingPermissionService.requestWhenInUse()` — probes `Permission.locationWhenInUse` first, only requests when not already granted, and never touches `locationAlways` or `notification`. Reuses the class's existing injected probe/requester seams, so it's unit-testable with no platform channel.
- `preflight()` and `currentStatus()` are byte-for-byte unchanged; their existing test groups pass unmodified.
- Added three picker-specific SnackBar copy constants to `constants.dart`: `kLocationPickerPermissionDeniedMessage`, `kLocationPickerPermissionBlockedMessage`, `kLocationPickerLocationUnavailableMessage`. The existing `kOpenPermissionSettingsLabel` is reused for the settings-deep-link action (matching `main_shell.dart`'s established pattern); the existing `kPermissionsRequiredMessage` is deliberately NOT reused (it names notifications and "recording a commute," neither of which applies here).
- `LocationPickerScreen._resolveInitialCenter` now requests `locationWhenInUse` on the no-saved-coord branch only; a saved coord still skips the request entirely. Declining is a legitimate answer — the chain falls through silently to recent-trip-end, then the default constant, with no error UI (D-3).
- `LocationPickerScreen._locateMe` is rewritten as an exhaustive `switch` (no `default`) over `LocationWhenInUseStatus`: denied → SnackBar, permanently denied → SnackBar + "Open settings" action (wired to `openSystemSettings()`), granted-but-no-fix → SnackBar, granted-with-fix → map move. No path returns silently.
- `_defaultCurrentLocation` is now a pure position read (the `Geolocator.checkPermission()` block and now-unused `LocationPermission` import reference were removed); permission is entirely the caller's concern.
- Every dartdoc asserting the old "never prompt from the picker" (D-13) behavior was rewritten to state the D-1 supersession explicitly, per the plan's requirement that no stale doc be left standing.
- Extended (not replaced) the existing widget test file: the pre-existing LOC-02 backfill regression test survives with its assertions unchanged, now driven through a default always-granted permission fake via an updated `pumpAndOpenPicker` helper. Six new widget tests cover prompt-on-open (exactly once), no-prompt-when-saved, silent decline-on-open (position resolver never invoked), and all three Locate-me feedback SnackBars.

## Task Commits

1. **Task 1: `requestWhenInUse()` + picker copy** — `412a3bc`
   `[tracking] Add when-in-use-only permission request for the location picker`
2. **Task 2: Prompt on open and make Locate me speak up** — `5b3faf0`
   `[settings] Location picker requests GPS on open and Locate me no longer no-ops`
3. **Task 3: Widget tests for prompt-on-open and Locate-me feedback** — `362e682`
   `[settings] Widget tests for picker permission prompt and Locate-me feedback`

## Files Modified

- `lib/features/tracking/services/tracking_permission_service.dart` — added `LocationWhenInUseStatus` enum, `requestWhenInUse()` method, class-dartdoc updates (contract list + ordering invariant 3). `preflight()`/`currentStatus()` bodies untouched.
- `lib/config/constants.dart` — added three `kLocationPicker*` SnackBar copy constants in a new `// --- Location picker permission feedback (quick 260802-dgp) ---` section.
- `lib/features/settings/screens/location_picker_screen.dart` — `_resolveInitialCenter` requests permission on the no-saved-coord branch; `_locateMe` rewritten as an exhaustive switch with a new `_showSnack` helper; `_defaultCurrentLocation` stripped of its permission check; class/typedef dartdocs rewritten to state the D-1 supersession of D-13.
- `test/unit/features/tracking/tracking_permission_service_test.dart` — new `TrackingPermissionService.requestWhenInUse` group: five outcome tests (already-granted, denied→granted, denied→denied, permanentlyDenied-on-probe, denied→permanentlyDenied), each asserting `locationAlways`/`notification` are never touched.
- `test/widget/features/settings/location_picker_screen_test.dart` — `pumpAndOpenPicker` gained optional `permissionService`/`currentLocation`/`seedSavedCoord` parameters (default: always-granted fake); added a `_PermissionLog`/`_fakePermissionService` helper pair; six new `testWidgets` cases; header comment extended with a 260802-dgp section describing the bug.

## Deviations from Plan

None — plan executed exactly as written. All five `must_haves.artifacts` are present, all five `key_links` are wired as specified, and the plan's exact code blocks for `requestWhenInUse()`, `_resolveInitialCenter`, `_locateMe`, and `_showSnack` were used verbatim (only whitespace reflowed by `dart format`).

## Issues Encountered

- `flutter analyze` on the new widget test file flagged one new lint (`always_put_required_named_parameters_first`) on the `_fakePermissionService` helper's parameter order. Reordered `required PermissionStatus probeStatus, required _PermissionLog log, PermissionStatus? requestStatus` (optional last) — zero-issue fix, no behavior change, not counted as a deviation since it's tooling-driven cleanup within the same task's new code.

## User Setup Required

None — no new dependencies, no config, no schema changes, no backend touched.

## Verification

```
dart format .                     # clean, 0 changed on final pass
flutter analyze                   # 295 issues (matches stated baseline exactly — 0 new errors/warnings)
flutter test                      # 1000 tests, 0 failures (10 pre-existing skips)
```

Static greps against `lib/features/settings/screens/location_picker_screen.dart` (all clean, per plan):
- `grep -n "checkPermission" ...` → no match
- `grep -n "preflight" ...` → no match
- `grep -n "locationAlways\|Permission.notification" ...` → no match

### Fresh-install real-device verification checklist (NOT YET PERFORMED)

CLAUDE.md rules out emulator GPS confirmation ("Test on real Android devices for GPS and background service behavior. Emulator GPS simulation is unreliable for traffic calculations") and the plan's own `<verification>` section states this step "cannot be done in CI or reliably in an emulator." This automated execution run did NOT install the app on a physical device, so the checklist below is **outstanding** and must be run manually before this fix is considered fully verified in production conditions:

On a FRESH INSTALL (or after clearing app data + revoking location permission in **Settings → Apps → Traevy → Permissions**):

1. Settings → Commute → Home location. **Expected:** the system location permission dialog appears immediately.
2. Tap **Allow**. **Expected:** the map opens centred on your actual current location, not the Bengaluru default (12.9716, 77.5946).
3. Clear app data again, reopen the picker, tap **Deny**. **Expected:** the map opens on the fallback (most recent trip's end point, or the Bengaluru default if no trips exist) with NO error toast or SnackBar.
4. Tap **Locate me**. **Expected:** a SnackBar appears (previously this button did nothing).
5. Deny the permission repeatedly ("Don't allow" a second time, or use the OS's permanent-deny path) until it is permanently denied, then tap **Locate me**. **Expected:** a SnackBar reading "Location permission is blocked..." with an **Open settings** action; tapping that action must land on the app's PERMISSION list screen specifically, not the generic App Info page (this app-specific deep-link behavior predates this change and is reused, not modified, here).
6. Grant the permission, then turn the device's Location Services OFF entirely (Settings → Location), and tap **Locate me**. **Expected:** the "Couldn't get your location. Check that location services are on." SnackBar appears.

Record the outcome of this checklist (pass/fail per step, with device model + Android version) before treating LOC-01 as closed.

## Next Phase Readiness

- No blockers for further picker or permission work. `TrackingPermissionService.requestWhenInUse()` is now a general-purpose narrow permission seam any future non-tracking screen can reuse without pulling in the four-step `preflight()` dance.
- The real-device verification checklist above is the only remaining open item from this task.

---
*Phase: quick-260802-dgp*
*Completed: 2026-08-02*

## Self-Check: PASSED

- FOUND: lib/features/tracking/services/tracking_permission_service.dart
- FOUND: lib/config/constants.dart
- FOUND: lib/features/settings/screens/location_picker_screen.dart
- FOUND: test/unit/features/tracking/tracking_permission_service_test.dart
- FOUND: test/widget/features/settings/location_picker_screen_test.dart
- FOUND: 412a3bc (Task 1 commit)
- FOUND: 5b3faf0 (Task 2 commit)
- FOUND: 362e682 (Task 3 commit)
