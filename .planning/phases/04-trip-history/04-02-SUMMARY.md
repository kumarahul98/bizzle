---
phase: 04-trip-history
plan: "02"
subsystem: ui
tags:
  - flutter-map
  - latlong2
  - table-calendar
  - history
  - wave-1
  - shared-infrastructure
  - streamprovider
  - delete-action-extraction
dependency_graph:
  requires:
    - "lib/database/daos/trips_dao.dart (TripSummary projection + watchAllSummaries stream)"
    - "lib/database/providers.dart (tripsDaoProvider — manual Riverpod 3.x pattern)"
    - "lib/features/trips/providers/trip_management_providers.dart (TripManagementSaved/Error states + tripManagementProvider)"
    - "lib/shared/utils/polyline_codec.dart (decodePolyline returning List<({double lat, double lng})>)"
    - "Phase 04 Plan 01 stub tests (history_grouping_test, formatters_test) — Wave 1 keeps them green"
  provides:
    - "flutter_map ^8.1.0, latlong2 ^0.9.1, table_calendar ^3.1.3 in pubspec.lock (Wave 2 ready)"
    - "Phase 4 constants block in lib/config/constants.dart (kHistoryDate*, kHistoryEmpty*, kHistoryCalendar*, kManualEntryBadge, kTripDetailNotFound, kTripDetailMapHeight)"
    - "kRouteHistory and kRouteTripDetail registered in kAppRoutes"
    - "lib/shared/utils/formatters.dart — formatDuration, formatDistance, decodedToLatLng (LatLng adapter)"
    - "lib/features/trips/providers/history_providers.dart — allTripSummariesProvider StreamProvider, groupTripsByDate, formatDateHeader"
    - "lib/features/trips/services/trip_actions.dart — top-level handleDeleteTrip extracted from HomeScreen verbatim"
    - "View history OutlinedButton on HomeScreen wired to Navigator.pushNamed(context, kRouteHistory)"
    - "Wave 1 placeholder HistoryScreen + TripDetailScreen so routes.dart compiles before Wave 2 lands"
  affects:
    - "Plan 04-03 (HistoryScreen) — overwrites placeholder, consumes allTripSummariesProvider + groupTripsByDate + formatDateHeader + trip_actions.handleDeleteTrip"
    - "Plan 04-04 (TripDetailScreen) — overwrites placeholder, consumes formatters (formatDuration, formatDistance, decodedToLatLng), trip_actions.handleDeleteTrip, kTripDetailMapHeight, kManualEntryBadge, kTripDetailNotFound"
    - "Phase 5 (Stats) — will reuse allTripSummariesProvider for chart aggregation"
tech_stack:
  added:
    - "flutter_map ^8.1.0 (resolved 8.4.0) — OSM tile rendering for trip detail map"
    - "latlong2 ^0.9.1 — LatLng type required by flutter_map PolylineLayer"
    - "table_calendar ^3.1.3 (resolved 3.2.0) — calendar widget for history calendar view"
  patterns:
    - "Dual-import pattern: Wave 1 owns extracted utilities + placeholder screens so Wave 2 plans get a real verify target without depending on each other's order"
    - "trip_actions top-level functions: cross-widget reusable async flows (delete, future bulk actions) live in services/, not as widget methods, so HistoryScreen and HomeScreen share the same delete dialog without duplication"
    - "Manual Riverpod 3.x StreamProvider with name: parameter — matches lib/database/providers.dart pattern for analyzer-10 compatibility"
    - "Pitfall 3 mitigation in groupTripsByDate: trip.startTime.toLocal() before stripping H/M/S so cross-midnight UTC trips group on the correct local date"
key_files:
  created:
    - lib/shared/utils/formatters.dart
    - lib/features/trips/providers/history_providers.dart
    - lib/features/trips/services/trip_actions.dart
    - lib/features/trips/screens/history_screen.dart
    - lib/features/trips/screens/trip_detail_screen.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - lib/config/constants.dart
    - lib/config/routes.dart
    - lib/features/tracking/screens/home_screen.dart
decisions:
  - "latlong2 import path is package:latlong2/latlong.dart — the published library file is named latlong.dart even though the package is latlong2 (Rule 1 fix, plan said latlong2.dart)"
  - "Created Wave 1 placeholder HistoryScreen + TripDetailScreen even though plan listed them as Wave 2 — required because routes.dart registration in Task 1 referenced them, and 3 existing tests (app_bootstrap_test, home_screen_test, app_test) transitively load routes.dart and would not compile without the screen classes existing"
  - "trip_actions.dart uses top-level function (not class method) so HistoryScreen and HomeScreen can both call it without depending on a shared base class or singleton"
  - "HomeScreen.handleDeleteTrip kept as a one-line delegate (vs. removing it entirely) so any external call sites that already reach for the public method continue to work"
requirements_completed:
  - HIST-01
  - HIST-02
  - HIST-03
metrics:
  duration_minutes: 7
  tasks_completed: 2
  tasks_total: 2
  files_created: 5
  files_modified: 5
  tests_added: 0
  tests_passing: 132
  tests_skipped: 24
  completed_date: "2026-04-26"
---

# Phase 4 Plan 02: Wave 1 Trip-History Shared Infrastructure Summary

**Three new packages (flutter_map, latlong2, table_calendar), nine Phase 4 constants, two new routes, three new shared library files (formatters, history_providers, trip_actions), and a 'View history' button on the home screen — all the contracts Wave 2 needs to build HistoryScreen and TripDetailScreen in parallel.**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-04-26T06:30:07Z
- **Completed:** 2026-04-26T06:37:20Z
- **Tasks:** 2 / 2
- **Files created:** 5
- **Files modified:** 5

## Accomplishments

- Added `flutter_map ^8.1.0`, `latlong2 ^0.9.1`, `table_calendar ^3.1.3` to pubspec; `flutter pub get` exits 0 with no version conflicts.
- Appended Phase 4 constants block to `lib/config/constants.dart` — nine new constants covering history list copy, calendar empty/no-selection states, manual-entry badge, detail-screen not-found error, and the 256dp map height (the only allowed off-grid spacing).
- Registered `kRouteHistory = '/history'` and `kRouteTripDetail = '/trip-detail'` in `kAppRoutes`; trip-detail entry reads `tripId` from `ModalRoute.of(context)!.settings.arguments! as String`.
- Created `lib/shared/utils/formatters.dart` exporting `formatDuration` (`N min` / `NhNNmin`), `formatDistance` (`N.N km`), and `decodedToLatLng` (LatLng adapter for flutter_map's PolylineLayer with empty-input guard for Pitfall 2).
- Created `lib/features/trips/providers/history_providers.dart` — `allTripSummariesProvider` StreamProvider watching `tripsDaoProvider.watchAllSummaries()`, `groupTripsByDate` (Pitfall 3 local-time grouping), `formatDateHeader` (Today/Yesterday/`EEE d MMM`).
- Created `lib/features/trips/services/trip_actions.dart` — top-level `handleDeleteTrip` extracted verbatim from HomeScreen (same dialog title/copy, same `colorScheme.error` styling, same `context.mounted` guards after each `await`, same `TripManagementSaved`/`TripManagementError` snackbar handling).
- Updated HomeScreen — added "View history" `OutlinedButton` below "Start commute" wired to `Navigator.pushNamed(context, kRouteHistory)`, and reduced `handleDeleteTrip` to a one-line delegate to `trip_actions.handleDeleteTrip`.
- Suite remains green: **132 passing / 24 skipped / 0 failing** after Wave 1 lands; 15 Wave 0 stub tests still green via `markTestSkipped`.

## Task Commits

1. **Task 1: Add Phase 4 packages, constants, and routes** — `d3195aa` (feat)
2. **Task 2: Wave 1 history infrastructure + View history button + placeholder screens** — `acc9f83` (feat)

_Plan-metadata commit (this SUMMARY) follows below._

## Files Created/Modified

- `pubspec.yaml` — added flutter_map, latlong2, table_calendar to dependencies (alphabetical insertion).
- `pubspec.lock` — refreshed by `flutter pub get`; pulls in proj4dart, simple_gesture_detector, simple_sparse_list, wkt_parser as transitive deps.
- `lib/config/constants.dart` — appended Phase 4 block of 9 constants after the Phase 2 block.
- `lib/config/routes.dart` — added 2 imports, 2 route constants, 2 entries in `kAppRoutes`.
- `lib/shared/utils/formatters.dart` (CREATED) — three pure top-level utility functions; latlong2 import uses `package:latlong2/latlong.dart` (the package's published library file is `latlong.dart`, NOT `latlong2.dart`).
- `lib/features/trips/providers/history_providers.dart` (CREATED) — manual StreamProvider declaration matching the `lib/database/providers.dart` pattern (no `@riverpod` codegen) plus two pure utility functions.
- `lib/features/trips/services/trip_actions.dart` (CREATED) — top-level async function with two `context.mounted` guards (one after `showDialog`, one after `deleteTrip`) and the full `TripManagementSaved`/`TripManagementError` consumption flow.
- `lib/features/trips/screens/history_screen.dart` (CREATED — Wave 1 placeholder) — minimal `ConsumerWidget` returning `Scaffold(appBar: ..., body: CircularProgressIndicator())`. Wave 2 (Plan 04-03) overwrites this.
- `lib/features/trips/screens/trip_detail_screen.dart` (CREATED — Wave 1 placeholder) — minimal `ConsumerWidget` taking `tripId` and returning `Scaffold(appBar: ..., body: CircularProgressIndicator())`. Wave 2 (Plan 04-04) overwrites this.
- `lib/features/tracking/screens/home_screen.dart` — replaced full `handleDeleteTrip` body (~45 lines) with one-line delegate to `trip_actions.handleDeleteTrip`; added 12dp gap + `OutlinedButton` for "View history"; switched import from `trip_management_providers.dart` to `trip_actions.dart` (aliased `as trip_actions` to avoid collision with the instance method name).

## Decisions Made

- **`latlong2/latlong.dart` import path** — the plan and PATTERNS.md both specified `package:latlong2/latlong2.dart`, but the actual published library inside `latlong2-0.9.1/lib/` is named `latlong.dart`. This is a known quirk of the `latlong2` package (it kept the original `latlong.dart` library name when forking from the abandoned `latlong` package). Using the documented path produced `uri_does_not_exist` errors; fixed inline as a Rule 1 bug.
- **Wave 1 placeholder screens** — created `HistoryScreen` and `TripDetailScreen` as minimal `Scaffold(... CircularProgressIndicator)` widgets even though the plan listed them as Wave 2 deliverables. The plan registers `kRouteHistory` and `kRouteTripDetail` in `kAppRoutes` (which references those classes), and three existing tests (`test/unit/app_bootstrap_test.dart`, `test/widget/features/tracking/home_screen_test.dart`, `test/widget/app_test.dart`) transitively load `lib/config/routes.dart` and would refuse to compile with `Error when reading 'lib/features/trips/screens/history_screen.dart': No such file or directory`. Without the placeholders the test suite would have gone from 132/0 failing to 132/3 failing on Wave 1 — a regression the plan intended to avoid (acceptance criteria: "Wave 0 unit stub tests still pass").
- **Top-level function in `trip_actions.dart`** — followed PATTERNS.md guidance; `handleDeleteTrip` is a free function (not a class method or notifier) so HistoryScreen trip cards can invoke it identically to HomeScreen without inheritance, mixins, or a shared service class.
- **Kept `HomeScreen.handleDeleteTrip` as one-line delegate** — rather than removing the public method, kept it so `Phase 3 Plan 04: handleDeleteTrip made public — very_good_analysis unused_element fires on private methods not referenced in the same file; Phase 4 trip cards invoke it across widget boundaries` (state.md decision) is preserved. Trip cards in Wave 2 will call `trip_actions.handleDeleteTrip` directly; HomeScreen's delegate stays as a thin compatibility shim.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `latlong2` package import path was wrong in PLAN.md**
- **Found during:** Task 2 (`flutter analyze lib/shared/utils/formatters.dart` after creation)
- **Issue:** Plan's PATTERNS.md and Task 2 action specified `import 'package:latlong2/latlong2.dart'`, but `latlong2-0.9.1/lib/` only contains `latlong.dart` (no `latlong2.dart`). Analyzer reported `uri_does_not_exist` and `LatLng` was undefined.
- **Fix:** Changed import to `package:latlong2/latlong.dart`. Re-ran `flutter analyze lib/shared/utils/formatters.dart` → `No issues found!`.
- **Files modified:** `lib/shared/utils/formatters.dart`
- **Verification:** `flutter analyze` clean on the file; `decodedToLatLng` test stub still skipped (Wave 2 will assert).
- **Committed in:** `acc9f83` (Task 2 commit, fix bundled with the file creation)

**2. [Rule 3 - Blocking] Wave 1 routes referenced non-existent screens, breaking 3 unrelated tests**
- **Found during:** End of Task 2 (`flutter test` after the four-file analyze passed)
- **Issue:** Task 1 added `kRouteHistory: (BuildContext context) => const HistoryScreen()` and `kRouteTripDetail: ... TripDetailScreen(tripId: tripId)` to `kAppRoutes`, but the screen classes don't exist until Wave 2. Tests that load `routes.dart` transitively (`app_bootstrap_test`, `home_screen_test`, `app_test`) failed compilation with `Error when reading 'lib/features/trips/screens/history_screen.dart': No such file or directory`. Suite went from 132/0 failing to 132/3 failing.
- **Fix:** Created minimal `ConsumerWidget` placeholders (~25 lines each) that satisfy the routes' constructor signatures and render `Scaffold + CircularProgressIndicator`. Documented in dartdoc that Wave 2 will overwrite both files. Re-ran `flutter test` → 132/24/0.
- **Files modified:** `lib/features/trips/screens/history_screen.dart` (CREATED), `lib/features/trips/screens/trip_detail_screen.dart` (CREATED)
- **Verification:** `flutter test` exits 0; `flutter analyze` on `lib/features/trips/screens/` reports `No issues found!`.
- **Committed in:** `acc9f83` (Task 2 commit, bundled with the new shared files)

**3. [Rule 1 - Lint] Two `comment_references` info-level warnings in formatters.dart and home_screen.dart**
- **Found during:** Task 2 first analyze pass after fixing the latlong import
- **Issue:** `very_good_analysis` flags `[Symbol]` in dartdoc comments when the symbol isn't visible in the file's import scope. `decodedToLatLng` doc referenced `[PolylineLayer]` (from flutter_map, not imported here — this is a pure utility), and `HomeScreen.handleDeleteTrip` doc still referenced `[TripManagementNotifier.deleteTrip]` from the now-removed `trip_management_providers.dart` import.
- **Fix:** Switched both to backtick-quoted prose (`` `PolylineLayer` ``, `` `TripManagementNotifier.deleteTrip` ``) — preserves the documentation intent without introducing fake imports just for dartdoc resolution.
- **Files modified:** `lib/shared/utils/formatters.dart`, `lib/features/tracking/screens/home_screen.dart`
- **Verification:** `flutter analyze` on all 6 Wave 1 files → `No issues found!`.
- **Committed in:** `acc9f83` (Task 2 commit, bundled with the file creation)

**4. [Rule 1 - Lint] `lines_longer_than_80_chars` info on Phase 4 dartdoc comment in constants.dart**
- **Found during:** Task 1 first analyze pass after constants.dart edit
- **Issue:** The dartdoc comment `/// Error message on the trip detail screen when findById returns null (HIST-03).` was 81 characters, tripping `very_good_analysis`'s 80-char hard limit on doc comments.
- **Fix:** Wrapped the doc to two lines, breaking after `null`.
- **Files modified:** `lib/config/constants.dart`
- **Verification:** `flutter analyze lib/config/constants.dart` → `No issues found!`.
- **Committed in:** `d3195aa` (Task 1 commit, bundled with the constants block addition)

---

**Total deviations:** 4 auto-fixed (1 import-path bug, 1 blocking test compilation, 2 lint clean-ups).
**Impact on plan:** All four fixes were necessary to satisfy the success criteria ("`flutter pub get` exits 0", "All 6 new/modified production files pass `flutter analyze` with no errors", "Wave 0 unit stub tests still pass"). The placeholder-screens deviation expanded the file count by 2 (5 created vs 3 listed), but the placeholder content is purely scaffolding — Wave 2 will overwrite both files in their entirety. No scope creep beyond what was needed to keep the suite green.

## Issues Encountered

- **`flutter pub get` printed `Reinstalled 202 packages` after `flutter pub cache repair`** — invoked once during the latlong2 investigation; the repair turned out to be unnecessary (the file was on disk, only the import path was wrong). No lasting impact; lockfile unchanged after repair.

## Threat Flags

No new security-relevant surface introduced. The threat model in PLAN.md (T-04-02-01 spoofing, T-04-02-02 DoS via cast, T-04-02-03 information disclosure) is unchanged:
- `trip_actions.handleDeleteTrip` preserves the two-step confirmation dialog and `context.mounted` guards verbatim from Phase 3 (T-04-02-01 mitigation intact).
- `kRouteTripDetail` argument cast `as String` is reachable only via `Navigator.pushNamed` from app code (T-04-02-02 — Wave 2 will add the planned `assert` in `TripDetailScreen`).
- `decodedToLatLng` operates on user-owned polyline strings, never transmitted (T-04-02-03 disposition stays `accept`).

## Next Phase Readiness

- Plan 04-03 (HistoryScreen) can begin immediately. All required contracts exist:
  - `allTripSummariesProvider` StreamProvider for the list
  - `groupTripsByDate` + `formatDateHeader` for sticky date sections
  - `formatDuration` + `formatDistance` for trip card subtitles
  - `trip_actions.handleDeleteTrip` for the trip options sheet's delete row
  - `kHistoryDateToday`, `kHistoryDateYesterday`, `kHistoryEmptyHeading`, `kHistoryEmptyBody`, `kHistoryCalendarEmptyDate`, `kHistoryCalendarNoSelection` constants
- Plan 04-04 (TripDetailScreen) can begin immediately. All required contracts exist:
  - `decodedToLatLng` for the polyline layer
  - `formatDuration`, `formatDistance` for the stats rows
  - `trip_actions.handleDeleteTrip` for the AppBar delete action
  - `kManualEntryBadge`, `kTripDetailNotFound`, `kTripDetailMapHeight` constants
- Both Wave 2 plans should overwrite the placeholder screen files entirely — they are clearly marked as Wave 1 placeholders in their dartdoc.
- No blockers detected for downstream plans.

## Self-Check

- [x] `lib/shared/utils/formatters.dart` exists in the worktree.
- [x] `lib/features/trips/providers/history_providers.dart` exists in the worktree.
- [x] `lib/features/trips/services/trip_actions.dart` exists in the worktree.
- [x] `lib/features/trips/screens/history_screen.dart` exists (Wave 1 placeholder).
- [x] `lib/features/trips/screens/trip_detail_screen.dart` exists (Wave 1 placeholder).
- [x] `lib/config/constants.dart` contains `kHistoryDateToday`, `kTripDetailMapHeight`, `kManualEntryBadge`.
- [x] `lib/config/routes.dart` contains `kRouteHistory`, `kRouteTripDetail`, and entries in `kAppRoutes`.
- [x] `lib/features/tracking/screens/home_screen.dart` contains `OutlinedButton` with `View history` and `Navigator.pushNamed(context, kRouteHistory)`.
- [x] `pubspec.yaml` contains `flutter_map: ^8.1.0`, `latlong2: ^0.9.1`, `table_calendar: ^3.1.3`.
- [x] Commit `d3195aa` present (Task 1 — packages, constants, routes).
- [x] Commit `acc9f83` present (Task 2 — Wave 1 infrastructure + placeholder screens).
- [x] `flutter pub get` exits 0.
- [x] `flutter analyze` on all 6 Wave 1 files: No issues found.
- [x] `flutter test` full suite: 132 passing / 24 skipped / 0 failing.
- [x] `flutter test test/unit/features/trips/history_grouping_test.dart test/unit/shared/formatters_test.dart`: 15 skipped, 0 failing.

## Self-Check: PASSED

---
*Phase: 04-trip-history*
*Plan: 02*
*Completed: 2026-04-26*
