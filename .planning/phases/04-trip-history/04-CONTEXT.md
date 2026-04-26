# Phase 4: Trip History - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can browse and review all past commutes through three views: a scrollable daily list organized by date, a calendar view to jump to a specific day, and a trip detail screen with the route drawn on a map and full stats. Edit and delete actions (built in Phase 3) are accessible from the history list.

Requirements covered: HIST-01, HIST-02, HIST-03.

Out of scope: stats dashboard (Phase 5), real dashboard home screen (Phase 6), dark mode (Phase 7).

</domain>

<decisions>
## Implementation Decisions

### Map Package
- **D-01:** Use `flutter_map` (OpenStreetMap tiles) — NOT `google_maps_flutter`. No API key, no Google Cloud account, no SHA-1 fingerprint setup. Zero infrastructure cost. Adequate for rendering a commute route polyline. `decodePolyline()` in `lib/shared/utils/polyline_codec.dart` already handles the encoded polyline → LatLng conversion.

### Navigation to History
- **D-02:** Add a "View history" outlined/text button on the existing home screen, positioned below the "Start commute" CTA. No bottom NavigationBar, no AppBar icon. Phase 6 replaces this home screen with the real dashboard — the button is a temporary entry point that will be removed then.

### Daily List Layout
- **D-03:** Group trips under sticky date-section headers in the list view. Format: "Today", "Yesterday", "Mon 21 Apr" for older dates. Client-side grouping from the existing `watchAllSummaries()` stream — no new DAO query needed. Each trip is a card showing direction, departure time, and duration.
- **D-04:** No new DAO method required for the list view. The existing `watchAllSummaries()` reactive stream is the data source. Grouping logic lives in the widget or a plain Dart helper — not in the database layer.

### Manual Trip Detail Screen
- **D-05:** For manually-entered trips (`isManualEntry = true`, `routePolyline = ''`), hide the map widget entirely. Show a "Manually entered — no route recorded" label, then the stats section (duration, direction, date). The detail screen has two layout branches: map + stats (GPS trips) and stats-only (manual trips).

### Trip Detail Content
- **D-06:** GPS trip detail screen layout: map fills the top portion (route polyline drawn on flutter_map), scrollable stats below: duration, distance, direction, date, time moving vs time stuck breakdown.
- **D-07:** Full `TripRow` (including polyline) is fetched via the existing `TripsDao.findById(id)` method. Do not stream the full row — fetch once on screen init.

### Edit & Delete from History
- **D-08:** Trip cards in the history list expose edit and delete actions — reuse `EditTripSheet` (Phase 3) and `HomeScreen.handleDeleteTrip` (Phase 3) without duplication. How to surface these actions (swipe-to-reveal, trailing icon, long-press menu) is Claude's discretion.

### Calendar View
- **D-09:** Add `table_calendar` package (recommended in CLAUDE.md stack). Calendar shows event markers on days that have trips. Tapping a date filters the list to show only that day's trips.

### Claude's Discretion
- `flutter_map` version and tile provider configuration
- `table_calendar` version and marker styling
- Exact trip card layout (info density, icons, trailing actions)
- How edit/delete are triggered from list items (swipe, icon, long-press)
- Route name and file layout within `lib/features/trips/screens/`
- Whether history and detail are separate named routes or detail is pushed from the history screen directly
- Calendar and list view switching mechanism (SegmentedButton, tab, toggle icon)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project spec
- `CLAUDE.md` — Full project spec: folder structure, Riverpod conventions, no hardcoded values, feature-first layout
- `.planning/PROJECT.md` — Core value, offline-first constraint, Drift as single source of truth
- `.planning/REQUIREMENTS.md` — HIST-01, HIST-02, HIST-03 acceptance criteria

### Prior phase artifacts
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-01..D-13: schema, `kDefaultUserId`, Riverpod setup, `very_good_analysis`
- `.planning/phases/02-core-tracking/02-CONTEXT.md` — D-02: manual Riverpod providers (no codegen), D-11: `kDirectionUnknown`
- `.planning/phases/03-trip-management/03-CONTEXT.md` — D-01: modal bottom sheet pattern for edit, D-07: delete confirmation dialog, D-12/D-13: DAO extension methods

### Existing code this phase builds on
- `lib/database/daos/trips_dao.dart` — `watchAllSummaries()` (list data source), `findById(id)` (detail fetch), `TripSummary` class
- `lib/shared/utils/polyline_codec.dart` — `decodePolyline(String encoded)` → `List<({double lat, double lng})>` — already exists, use for map rendering
- `lib/features/trips/widgets/edit_trip_sheet.dart` — reuse from Phase 3, do not duplicate
- `lib/features/tracking/screens/home_screen.dart` — `handleDeleteTrip()` method to reuse, "View history" button added here
- `lib/config/routes.dart` — add history and detail routes here
- `lib/config/constants.dart` — any new labels or thresholds go here

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TripsDao.watchAllSummaries()` — reactive stream of all trips as `TripSummary`, ordered newest-first. Phase 4 groups client-side by date. No new DAO method needed.
- `TripsDao.findById(String id)` — returns full `TripRow` including `routePolyline`. Detail screen fetch point is already in place.
- `decodePolyline(String encoded)` in `lib/shared/utils/polyline_codec.dart` — pure Dart, no platform dependencies. Returns `List<({double lat, double lng})>` ready for flutter_map's `Polyline` widget.
- `EditTripSheet` in `lib/features/trips/widgets/edit_trip_sheet.dart` — invoke from trip cards in the history list (same as Phase 3's home screen usage).
- `HomeScreen.handleDeleteTrip(context, ref, tripId)` — public method already handles the confirmation dialog + DAO call + snackbar. Call from history list trip cards.
- `TripSummary.isManualEntry` — boolean flag that drives the D-05 layout branch in the detail screen.
- `kDirectionToOffice`, `kDirectionToHome` in `constants.dart` — use for direction display labels, never raw strings.

### Established Patterns
- **Manual Riverpod 3.x providers** — no `@riverpod` annotation; hand-written `Provider`, `StreamProvider`, `NotifierProvider`
- **Feature-first folder layout** — Phase 4 creates `lib/features/trips/screens/` (history screen, detail screen)
- **`very_good_analysis` strict linting** — doc comments on public members, `package:traevy/...` absolute imports, no `dynamic`
- **Constants in `lib/config/constants.dart`** — new labels or thresholds go here, not inline
- **Drift is the only data source for UI** — all reads from `watchAllSummaries()` or `findById()`, never from network

### Integration Points
- **Home screen** (`lib/features/tracking/screens/home_screen.dart`): Phase 4 adds a "View history" button that navigates to the history route.
- **Routes** (`lib/config/routes.dart`): Phase 4 adds at minimum `/history` and `/trip-detail` (or `/trip-detail/:id`) routes.
- **`pubspec.yaml`**: Phase 4 adds `flutter_map` and `table_calendar` packages.

</code_context>

<specifics>
## Specific Ideas

- Date headers: "Today", "Yesterday" for the two most recent days, then "Mon 21 Apr" format for older — familiar to users from messaging apps
- Detail screen: map top half, stats below in a scrollable column — clean split, map gives spatial context, stats give the numbers
- Manual trip detail: "Manually entered" chip/label at the top, then stats — honest and clear, no fake map

</specifics>

<deferred>
## Deferred Ideas

- **Undo delete from history list** — noted in Phase 3 deferred, still deferred to Phase 7 polish
- **Trip search or filtering by direction/date range** — new capability, belongs in a future phase
- **Export trips to CSV/JSON** — ANLYT-03 in v2 requirements, out of scope for v0.1

</deferred>

---

*Phase: 04-trip-history*
*Context gathered: 2026-04-25*
