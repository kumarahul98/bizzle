# Phase 21: Home & Office Locations + Geofence Auto-Label - Context

**Gathered:** 2026-06-06 (--auto; geofence policy reviewed with Gemini)
**Status:** Ready for planning

<domain>
## Phase Boundary

Let the user save Home & Office locations and auto-label trip direction by proximity of the trip's endpoints to those locations — taking precedence over the time-of-day heuristic when there's a confident match, purely additive (nothing set → unchanged behavior), and never clobbering a manual label.

**In scope:**
- Settings map picker to set/change Home & Office; persist in preferences (LOC-01, SC#1)
- Geofence direction labeling at finalize: end-near-Office → to_office, end-near-Home → to_home (LOC-02, SC#2)
- Precedence: Manual override > Geofence > Time-of-day fallback (LOC-02, SC#3)
- Manual override via the Phase 17 quick selector still wins and sticks (SC#4)
- Backfill existing auto-labeled trips when Home/Office is set/changed — without clobbering manual labels (LOC-02)
- Purely additive: with no Home/Office set, labeling is exactly the old time-of-day behavior (SC#5)

**Out of scope:**
- Geofence-triggered auto START/STOP of trips (AUTO-02 full automation stays deferred — this is labeling only)
- Address search/geocoding (tap/pan a map + current-location only; no text geocoder)
- The home-screen widget (Phase 22)
- Changing distance/polyline; only direction labeling changes

</domain>

<decisions>
## Implementation Decisions

### Schema (LOC-01 + safe backfill)
- **D-01:** Add nullable doubles to `user_preferences`: `home_lat`, `home_lng`, `office_lat`, `office_lng` (null = not set). Single-row table.
- **D-02:** Add a **`direction_source`** text column to `trips` (default `kDirectionSourceTime`) with values `kDirectionSourceManual` / `kDirectionSourceGeofence` / `kDirectionSourceTime`. This is what lets backfill update ONLY non-manual trips and is the durable record of "the user set this." Schema bump **v5 → v6** (one createColumn set on user_preferences + one addColumn on trips; v6 snapshot + migration test per convention). Existing rows: coords null, direction_source defaults to 'time' (they were time-labeled) — additive, safe.
- **D-03:** Wire `direction_source` into the EXISTING write paths from Phase 17/19: the quick-label toggle + edit sheet must set `direction_source = manual` whenever the user sets direction (so backfill never clobbers it). The live finalize sets `manual` only if the user used the in-trip override, else `geofence` or `time`.

### Geofence policy (LOC-02) — Gemini-reviewed
- **D-04:** **END coordinate is primary** (last polyline point) — users often start tracking late but end exactly at the destination. Rule: end within radius of Office → `to_office`; end within radius of Home → `to_home`.
- **D-05:** Radius = a hardcoded constant **`kGeofenceRadiusMeters = 250`** (absorbs GPS drift, parking a block away, office campuses; not user-adjustable). Distance via `Geolocator.distanceBetween` (already used in the accumulator).
- **D-06:** **Confident match** = the END coord falls strictly within 250m of exactly ONE of Home/Office. Then label by it. If END is outside BOTH → geofence aborts, fall back to time-of-day.
- **D-07:** **Overlap tie-breaker** (Home & Office <500m apart, END inside both): use the START coord — start nearer Home → `to_office`; start nearer Office → `to_home`; still ambiguous → time-of-day fallback.
- **D-08:** **Only-one-set:** if only Home is set (Office null) and END is near Home → `to_home`; otherwise (END not near Home) → time-of-day fallback (don't guess to_office without an Office anchor). Symmetric if only Office set.
- **D-09:** **Precedence (all paths):** resolvedDirection = manualOverride ?? geofenceLabel(start,end,prefs) ?? timeLabel(start,cutoffs). Extend the Phase 17 resolution (which was `override ?? timeLabel`) to slot geofence in the middle. The geofence resolver is a pure, unit-testable function/service (mirror DirectionLabelService style) taking start/end LatLng? + the four coords + radius.

### Where it runs
- **D-10:** **At finalize** — compute geofence label before persisting (decode first/last polyline points for start/end coords; prefs read where the resolution happens). Set `direction_source` accordingly (geofence if matched, else time).
- **D-11:** **Backfill on set/change** — when the user saves Home/Office in settings, fire a one-shot background task (Riverpod, like the existing `directionBackfillProvider` pattern) that re-labels trips **WHERE direction_source != manual**, decoding each trip's polyline endpoints and applying D-04..D-08; trips that newly match get direction + direction_source='geofence'; non-matches keep their existing (time) label. NEVER touch manual rows. Manual entries with no polyline (no GPS) can't geofence — leave as-is.

### Picker UX (LOC-01) — Gemini-reviewed
- **D-12:** **Fixed center crosshair** map (flutter_map/OSM, already a dependency): user pans the map under a fixed pin; a "Locate me" control jumps to current GPS; a prominent "Set Home here" / "Set Office here" confirm button reads the map center ONLY on confirm (debounce — don't read center mid-pan). Two entries in settings (Home, Office), each showing the current value or "Not set", opening the picker.
- **D-13:** **Avoid Null Island** — initialize the map at: the existing saved coord if set, else current device location (if permission granted), else the most recent trip's end point, else a sensible default; never (0,0).

### Claude's Discretion (resolve in planning)
- Whether the picker is one screen parameterized by Home/Office vs two; prefer one parameterized screen.
- Exact background-backfill trigger (on save vs a provider watching prefs) — reuse the directionBackfillProvider pattern.
- Whether to also expose Home/Office on the trip map for context (nice-to-have; skip if it grows scope).
- Decode-endpoints helper location (reuse `polyline_codec` / formatters).

</decisions>

<canonical_refs>
## Canonical References

- Labeling: `lib/features/trips/services/direction_label_service.dart` (time heuristic; add a sibling geofence resolver), the Phase 17 resolution in `lib/features/tracking/providers/tracking_providers.dart` (`resolvedDirection` = override ?? time → extend to insert geofence)
- Finalize/persist + direction write: `lib/features/tracking/services/tracking_service_controller.dart`, `lib/features/tracking/state/finalized_trip.dart`
- Manual-label write paths to tag direction_source=manual: Phase 17 `DirectionSegmentedToggle` wiring + `lib/features/trips/widgets/edit_trip_sheet.dart` + `lib/features/trips/providers/trip_management_providers.dart` (`editTrip`)
- Existing one-shot backfill pattern: `lib/features/tracking/providers/backfill_provider.dart` (`directionBackfillProvider`)
- Prefs: `lib/database/tables/user_preferences_table.dart`, `lib/database/daos/user_preferences_dao.dart`, `lib/features/settings/providers/settings_providers.dart`, `lib/features/settings/screens/settings_screen.dart`
- Trips table + migration: `lib/database/tables/trips_table.dart` (direction, isManualEntry, route_polyline), `lib/database/database.dart` (schemaVersion 5 → 6), `drift_schemas/`, `test/generated_migrations/`
- Maps: `lib/features/trips/screens/trip_detail_screen.dart` (flutter_map usage to mirror), `lib/shared/utils/polyline_codec.dart` (decode endpoints), `lib/shared/utils/formatters.dart`
- Geo distance: `Geolocator.distanceBetween` (used in `trip_accumulator.dart`)
- Constants: `lib/config/constants.dart` (kDirectionTo*, add kGeofenceRadiusMeters + kDirectionSource*)
- Requirements: LOC-01, LOC-02. ROADMAP Phase 21 SC#1–5.

