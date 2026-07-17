---
phase: 21-home-office-locations-geofence
verified: 2026-07-14T17:14:41Z
status: gaps_found
score: 5/6 must-haves verified
overrides_applied: 0
gaps:
  - truth: "When the user sets or changes Home/Office, a one-shot background task re-labels historical (non-manual) trips by proximity."
    status: failed
    reason: "The backfill service is fully implemented and unit-tested in isolation, but its trigger is a no-op at runtime. LocationPickerScreen only calls `ref.invalidate(geofenceBackfillProvider)` and nothing anywhere `watch`/`read`/`listen`s the provider. Empirically verified in this codebase's Riverpod: invalidating a never-listened keepAlive FutureProvider does NOT run its body (RAN_AFTER_INVALIDATE_ONLY=0). Contrast the working sibling `directionBackfillProvider`, which is `ref.watch`'d at app.dart:50. Result: saving a location never re-labels existing trips."
    artifacts:
      - path: "lib/features/settings/screens/location_picker_screen.dart"
        issue: "Line 119 `ref.invalidate(geofenceBackfillProvider)` is the ONLY interaction with the provider; there is no read/watch/listen, so the invalidate never initializes or runs it."
      - path: "lib/features/trips/providers/geofence_backfill_provider.dart"
        issue: "Bare keepAlive FutureProvider is never consumed anywhere in lib/, so its `run()` body never executes via the app."
    missing:
      - "Actually consume the provider so the invalidate takes effect: e.g. `await ref.read(geofenceBackfillProvider.future)` on the picker confirm path after saving (deterministic), or `ref.watch(geofenceBackfillProvider)` in a mounted scope, mirroring how directionBackfillProvider is `ref.watch`'d at startup in app.dart."
      - "Add a provider/integration test that proves saving a Home/Office location actually runs GeofenceBackfillService.run() (current backfill_service_test only exercises the service directly, so the dead trigger is invisible to CI)."
human_verification:
  - test: "Set Home/Office in Settings (map picker UX)"
    expected: "Settings → Commute → Home/Office opens the full-screen map. Map defaults to a sensible non-(0,0) location (saved coord, current GPS, last trip end, or Bengaluru). Panning moves the map under a fixed centre crosshair; the crosshair never moves. Locate-me recentres to current GPS. Tapping 'Set Home/Office here' saves the map-centre coord (read only on confirm) and the tile updates from 'Not set' to the coord."
    why_human: "Map pan gestures, fixed-crosshair alignment, locate-me camera animation, and read-on-confirm feel cannot be verified statically; requires an on-device Android run (UAT test 2, currently pending)."
  - test: "Geofence applied on commute finalize (on-device)"
    expected: "Tracking a commute and stopping within 250m of a saved Home/Office auto-labels the trip's direction by proximity without prompting, and this beats the time-of-day heuristic. Stopping far from both falls back to the time label."
    why_human: "Requires real GPS capture, a real polyline, and the finalize pipeline on a device (UAT test 3, currently pending). The resolver + finalize wiring are unit-proven, but end-to-end GPS behaviour needs a device."
---

# Phase 21: Home & Office Locations + Geofence Auto-Label Verification Report

**Phase Goal:** Users can save their Home and Office locations and have trip direction auto-labeled by proximity of trip start/end to those locations, taking precedence over the time-of-day heuristic when there is a confident match.
**Verified:** 2026-07-14T17:14:41Z
**Status:** gaps_found
**Re-verification:** No — initial verification (traceability/verification-debt closure from the v0.3 milestone audit; phase was executed + merged in PR #2 without a VERIFICATION.md).

## Goal Achievement

### Observable Truths

| #   | Truth   | Status     | Evidence       |
| --- | ------- | ---------- | -------------- |
| 1   | LOC-01: From settings the user can set/change Home & Office via a map picker and the coords persist in preferences across restarts. | ✓ VERIFIED | `LocationPickerScreen` (FlutterMap + fixed crosshair + read-on-confirm) → `setHomeLocation`/`setOfficeLocation` writing the v6 `user_preferences` coord columns; `SavedLocationTile` reads them back from `userPreferenceProvider`; two tiles wired into `SettingsScreen._LocationsSection`. Map-picker UX itself deferred to human check. |
| 2   | LOC-02 (new trips): at finalize a trip's decoded end coord within 250m of Office/Home labels it to_office/to_home. | ✓ VERIFIED | `tracking_service_controller.dart:236` decodes polyline endpoints and runs `GeofenceDirectionResolver`; writes `direction` + `direction_source` (line 261). `persistFinalizedTrip` is invoked in the real stop flow (`tracking_providers.dart:314`). Proven by `persist_geofence_direction_test`. |
| 3   | Precedence is `override ?? geofence ?? time`, recorded durably in `direction_source`; no confident match → time fallback. | ✓ VERIFIED | `tracking_service_controller.dart:245` `directionOverride ?? geofenceLabel ?? autoLabel`; `direction_source` derived at 247-251. Resolver returns null outside 250m (strict `<`). Exhaustively tested in `geofence_direction_resolver_test`. |
| 4   | SC#4: a manual override sticks and is backfill-proof. | ✓ VERIFIED | `editTrip` (single manual write path for the Phase 17 quick toggle + Phase 19 edit sheet) stamps `directionSource: const Value(kDirectionSourceManual)` (`trip_management_providers.dart:111`); the backfill query excludes `direction_source = manual`. |
| 5   | SC#5: with no Home/Office set behaviour is byte-for-byte the pre-Phase-21 time heuristic, and the v6 migration preserves all history. | ✓ VERIFIED | Resolver returns null when both anchors unset (`geofence_direction_resolver.dart:62`); additive v5→v6 migration (coords null, `direction_source` defaults 'time') proven by `migration_v6_test`. |
| 6   | LOC-02 (history): setting/changing Home/Office re-labels historical non-manual trips by proximity. | ✗ FAILED | `GeofenceBackfillService` is correct and unit-tested, but its trigger is dead: `LocationPickerScreen` only `ref.invalidate(geofenceBackfillProvider)` and nothing watches/reads the provider, so the backfill body never runs at runtime (empirically confirmed — see Gaps). |

**Score:** 5/6 truths verified

### Required Artifacts

| Artifact | Expected    | Status | Details |
| -------- | ----------- | ------ | ------- |
| `lib/features/trips/services/geofence_direction_resolver.dart` | Pure D-04..D-09 proximity policy | ✓ VERIFIED | 104 lines, const service, no Drift/Riverpod/plugin, only static `Geolocator.distanceBetween`; used by both finalize and backfill. |
| `lib/database/tables/user_preferences_table.dart` | 4 nullable Home/Office coord doubles | ✓ VERIFIED | `homeLat/homeLng/officeLat/officeLng` present (lines 84-96). |
| `lib/database/tables/trips_table.dart` | `direction_source` text column default 'time' | ✓ VERIFIED | Present; migration bumps to v6 (schema now at v7 from a later phase; `from<6` branch intact). |
| `lib/features/settings/screens/location_picker_screen.dart` | FlutterMap picker, fixed crosshair, read-on-confirm, D-13 init | ✓ VERIFIED | 226 lines; centre read only in `_confirm()`; D-13 init cascade; setters wired. |
| `lib/features/settings/widgets/saved_location_tile.dart` | Settings row showing coord/'Not set' | ✓ VERIFIED | Reads `userPreferenceProvider`; formats coord or `kCopyLocationNotSet`. |
| `lib/features/trips/services/geofence_backfill_service.dart` | Re-label non-manual trips via resolver | ✓ VERIFIED (code) | 104 lines; correct no-op guard, manual exclusion, idempotent write-only-on-change. Correct but unreachable (see trigger below). |
| `lib/features/trips/providers/geofence_backfill_provider.dart` | One-shot trigger on location change | ⚠️ ORPHANED | Provider defined but never consumed (no watch/read/listen anywhere in lib/); the only interaction is a no-op invalidate. |

### Key Link Verification

| From | To  | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `tracking_service_controller.persistFinalizedTrip` | `GeofenceDirectionResolver` + `decodePolyline` | decode endpoints → resolve → write direction + source | ✓ WIRED | Live in the stop flow; tested. |
| `tracking_providers` stop flow | `persistFinalizedTrip` | direction override passthrough | ✓ WIRED | Called at `tracking_providers.dart:314`. |
| `trip_management_providers.editTrip` | `trips.directionSource = manual` | TripsCompanion on updateTrip | ✓ WIRED | Line 111. |
| `location_picker_screen._confirm` | `UserPreferencesDao.setHome/OfficeLocation` | on confirm | ✓ WIRED | Lines 114/116; persists to v6 columns. |
| `settings_screen` | `SavedLocationTile` → `LocationPickerScreen` | two tiles + Navigator.push | ✓ WIRED | Lines 142-158. |
| `location_picker_screen._confirm` | `geofenceBackfillProvider` → `GeofenceBackfillService.run()` | `ref.invalidate` after save | ✗ NOT_WIRED | Invalidate on a never-listened keepAlive FutureProvider is a no-op; `run()` never executes. Empirically confirmed. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `saved_location_tile.dart` | `value.homeLat/officeLat` | `userPreferenceProvider` → v6 `user_preferences` row | Yes (real DAO read; 'Not set' when null) | ✓ FLOWING |
| `tracking_service_controller` finalize | `geofenceLabel` | `GeofenceDirectionResolver.resolve` over decoded polyline + prefs coords | Yes (real endpoints + saved coords) | ✓ FLOWING |
| `geofence_backfill_service` | candidate trips | `tripsDao.geofenceBackfillCandidates()` | Yes, but never reached — trigger dead | ✗ DISCONNECTED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Resolver + finalize + backfill-service + migration + settings widget tests | `flutter test` (phase-21 files) | 69 passing, 0 failing | ✓ PASS |
| Riverpod invalidate-without-listener runs provider? | ProviderContainer invalidate-only vs read probe | RAN_AFTER_INVALIDATE_ONLY=0; RAN_AFTER_READ=1 | ✗ FAIL (confirms dead trigger) |
| On-device map picker / GPS finalize | (requires device) | — | ? SKIP → human verification |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| LOC-01 | 21-01, 21-02 | Set Home/Office (map/coord picker) and persist in preferences | ✓ SATISFIED | Picker + setters + v6 columns + tiles + settings wiring all present and data-flowing; only the map-picker UX awaits on-device human confirmation (not a code gap). |
| LOC-02 | 21-01, 21-03 | Trips auto-labeled by proximity, precedence over time-of-day when confident | ✓ SATISFIED (with a deliverable defect) | The requirement statement (auto-label NEW trips by proximity + `override ?? geofence ?? time` precedence + additive fallback) is fully wired and tested at finalize. The phase's additional historical-backfill deliverable (Plan 03 / CONTEXT in-scope) is implemented but not reachable at runtime — see the gap. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `geofence_backfill_provider.dart` | 21 | Orphaned provider — defined, never consumed | 🛑 Blocker (for the backfill deliverable) | Historical re-label never runs; the only invalidate call cannot initialize it. |
| `location_picker_screen.dart` | 119 | `ref.invalidate` used as a fire-and-forget trigger with no reader | 🛑 Blocker | No-op; needs `ref.read(...future)` or a watching scope. |

### Human Verification Required

### 1. Set Home/Office in Settings (map picker UX)

**Test:** Settings → Commute → tap Home, then Office. Pan the map, use Locate-me, tap "Set … here".
**Expected:** Full-screen map, sensible non-(0,0) default, fixed centre crosshair the map pans under, locate-me recentres to GPS, confirm saves the map-centre coord, and the tile flips from "Not set" to the saved coordinate (persists across restart).
**Why human:** Map gestures, crosshair alignment, camera animation, and read-on-confirm feel cannot be checked statically. Corresponds to UAT test 2 (currently pending).

### 2. Geofence applied on commute finalize (on-device)

**Test:** Track a commute and stop within 250m of a saved Home/Office.
**Expected:** The trip is auto-labeled by proximity without prompting, beating the time-of-day heuristic; stopping far from both falls back to the time label.
**Why human:** Requires real GPS capture and a real polyline through the finalize pipeline on a device. Resolver + finalize wiring are unit-proven; end-to-end GPS behaviour needs a device (UAT test 3, pending).

### Gaps Summary

Five of six goal truths are fully delivered in code and proven by the automated suite (69 phase-21 tests green): the LOC-01 picker + persistence, the LOC-02 finalize auto-labeling of new trips, the `override ?? geofence ?? time` precedence, the manual-override stamp, and the additive v6 migration.

The single gap is a wiring defect in the **historical geofence backfill** (Plan 03, LOC-02's "re-label existing trips" half): `GeofenceBackfillService` is correct and unit-tested, but it is never actually run. `LocationPickerScreen` triggers it only via `ref.invalidate(geofenceBackfillProvider)`, and nothing in the app ever `watch`/`read`/`listen`s that provider. This was confirmed empirically against the project's own Riverpod — invalidating a never-listened keepAlive `FutureProvider` does not execute its body. The correct sibling pattern, `directionBackfillProvider`, is `ref.watch`'d at `app.dart:50`; the geofence provider lacks any such consumer. The fix is small (consume the provider on the confirm path, e.g. `await ref.read(geofenceBackfillProvider.future)`, plus a test that proves saving a location runs the service). Note this defect is exactly the scenario Phase 21 UAT test 5 would exercise — that UAT is stalled/pending, which is why the dead trigger was never observed. It is a real code gap, not deferred work, so it is reported here rather than filtered to a later phase.

**Requirement-reconciliation note (for the central traceability table — do not edited here):**
- **LOC-01** → recommend **Complete**. The picker, setters, v6 columns, tiles, and settings wiring are all present and data-flowing; the outstanding item is on-device map-picker UX confirmation (a human-verification item, not a code gap).
- **LOC-02** → the requirement as written (auto-label trips by proximity with precedence over time-of-day) is genuinely delivered at finalize, so keeping it **Complete** is defensible; however the phase's historical-backfill deliverable has a live wiring bug. Recommend keeping LOC-02 Complete only if the backfill trigger gap is tracked as a follow-up (or annotate LOC-02 with the caveat) — the new-trip path is Complete, the historical re-label path is not yet functional.

---

_Verified: 2026-07-14T17:14:41Z_
_Verifier: Claude (gsd-verifier)_
