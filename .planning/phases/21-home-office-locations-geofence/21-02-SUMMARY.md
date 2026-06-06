---
phase: 21-home-office-locations-geofence
plan: 02
subsystem: settings-ui
tags: [flutter_map, location-picker, settings, user-preferences, LOC-01]

# Dependency graph
requires:
  - phase: 21-01
    provides: Drift schema v6 Home/Office coord columns + UserPreferencesValue threading
provides:
  - "LocationPickerScreen: full-screen flutter_map picker with fixed centre crosshair (D-12) and read-on-confirm"
  - "SavedLocationTile: settings row showing coord/'Not set' from userPreferenceProvider"
  - "setHomeLocation/setOfficeLocation prefs setters (single-row upsert)"
  - "mostRecentGpsTrip() DAO query for D-13 init fallback"
  - "Commute section wired into SettingsScreen with Home/Office tiles"
affects: [21-03-geofence-backfill]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CurrentLocationResolver typedef injection seam — tests override the geolocator platform channel without touching production code"
    - "D-13 init cascade: saved coord ?? device location (no prompt) ?? most recent trip end ?? sane default (Bengaluru)"
    - "D-12 read-on-confirm: map centre read ONLY on confirm tap, never mid-pan"
    - "Extracted crosshair + confirm bar as focused single-responsibility widgets"

key-files:
  created:
    - lib/features/settings/screens/location_picker_screen.dart
    - lib/features/settings/widgets/location_picker_confirm_bar.dart
    - lib/features/settings/widgets/location_picker_crosshair.dart
    - lib/features/settings/widgets/saved_location_tile.dart
    - test/widget/features/settings/saved_location_tile_test.dart
  modified:
    - lib/config/constants.dart
    - lib/database/daos/trips_dao.dart
    - lib/database/daos/user_preferences_dao.dart
    - lib/features/settings/screens/settings_screen.dart
    - test/widget/features/settings/settings_screen_test.dart

key-decisions:
  - "kMapDefaultCenterLat/Lng = 12.9716/77.5946 (Bengaluru) — sane non-(0,0) default matching the project's primary locale"
  - "LocationPickerCrosshair wrapped in IgnorePointer — every gesture passes through to map; pin never moves"
  - "CurrentLocationResolver typedef as injection seam — tests inject a fake resolver without mocking Geolocator platform channel"
  - "mostRecentGpsTrip filtered to is_manual_entry=false so the fallback always has a recorded polyline"

patterns-established:
  - "Pan-under-pin picker pattern (fixed crosshair + read-on-confirm) reusable for any future map picker"
  - "Injection seam via typedef for platform-channel-dependent callbacks in ConsumerStatefulWidget"

requirements-completed: [LOC-01]

# Metrics
duration: ~15min
completed: 2026-06-06
---

# Phase 21 Plan 02: Location Picker UI Summary

**Full-screen flutter_map picker for Home/Office anchors with fixed centre crosshair (D-12), D-13 init cascade, SavedLocationTile settings rows, and prefs setters — wired into SettingsScreen as a new Commute section.**

## Performance

- **Duration:** ~15 min
- **Tasks:** 3 (prefs setters + tile, picker screen, settings wiring)
- **Files modified:** 5 modified, 5 created
- **Test suite:** 541 passing / 10 skipped (up from 536; +5 new)

## Accomplishments

- **Task 1 — Prefs setters + SavedLocationTile (TDD):** Added `setHomeLocation(lat, lng)` and `setOfficeLocation(lat, lng)` to `UserPreferencesDao` as single-row upserts mirroring `setHasSeenOnboarding`. Added `mostRecentGpsTrip()` to `TripsDao` for the D-13 fallback. Built `SavedLocationTile` (ConsumerWidget) reading `userPreferenceProvider` and showing either formatted `lat, lng` or "Not set". 5 widget tests covering null/set/independent-slot/tap.

- **Task 2 — LocationPickerScreen (TDD):** Built the full-screen picker as `ConsumerStatefulWidget` with `FlutterMap` + `MapController`, a `CurrentLocationResolver` typedef injection seam for testability, D-13 init cascade (saved → device → last trip → Bengaluru default), extracted `LocationPickerCrosshair` (`IgnorePointer` + `Icons.place_rounded`) and `LocationPickerConfirmBar` (`FilledButton`). Confirm reads `mapController.camera.center` ONLY on tap (D-12). Locate-me FAB animates to device location.

- **Task 3 — Settings wiring:** Added `_LocationsSection` to `SettingsScreen` with two `SavedLocationTile` entries (Home, Office), each opening the picker via `Navigator.push`. Updated settings test: 5 → 5 sections, added COMMUTE label assertion.

## Task Commits

1. **All tasks:** `bc005db` (`feat(21-02)`) — single atomic commit covering all 3 tasks (code was already partially written from a previous interrupted session; verified, completed, and committed in one pass)

## Files Created/Modified

- `lib/features/settings/screens/location_picker_screen.dart` — Full picker (221 lines): FlutterMap, D-13 cascade, D-12 read-on-confirm, CurrentLocationResolver seam
- `lib/features/settings/widgets/location_picker_crosshair.dart` — IgnorePointer + place icon with shadow (33 lines)
- `lib/features/settings/widgets/location_picker_confirm_bar.dart` — SafeArea + FilledButton bottom bar (41 lines)
- `lib/features/settings/widgets/saved_location_tile.dart` — ConsumerWidget reading prefs, formatting coord (68 lines)
- `test/widget/features/settings/saved_location_tile_test.dart` — 5 tests (134 lines)
- `lib/config/constants.dart` — +48 lines: LOC-01 picker constants (labels, titles, snack copy, default center, zoom, crosshair size)
- `lib/database/daos/trips_dao.dart` — +`mostRecentGpsTrip()` query (20 lines)
- `lib/database/daos/user_preferences_dao.dart` — +`setHomeLocation`/`setOfficeLocation` setters (35 lines)
- `lib/features/settings/screens/settings_screen.dart` — +`_LocationsSection` with 2 tiles + navigator push (38 lines)
- `test/widget/features/settings/settings_screen_test.dart` — Updated section count 4→5, added COMMUTE label assertion

## Decisions Made

- The picker's D-13 default centre is Bengaluru (12.9716, 77.5946) — the project's primary locale, not Null Island.
- `CurrentLocationResolver` typedef decouples the picker from Geolocator's platform channel, making widget tests trivial without mock package plugins.
- `mostRecentGpsTrip` filters `is_manual_entry = false` so the fallback always has a recorded polyline to decode an end point from.

## Deviations from Plan

None — plan executed exactly as written. All code was found partially complete from an interrupted prior session and was verified, completed, and committed.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 03 (geofence backfill) can now proceed — all Home/Office setters, the picker UI, and the settings wiring are complete. The user can set coordinates, and Plan 01's `GeofenceDirectionResolver` plus `direction_source` provenance column are in place for the backfill to re-label historical trips.

---
*Phase: 21-home-office-locations-geofence*
*Completed: 2026-06-06*

## Self-Check: PASSED

All 5 created files exist on disk; commit `bc005db` present in git log. Full suite: 541 passing / 10 skipped / 0 failing. `flutter analyze` clean (no new warnings/errors).
