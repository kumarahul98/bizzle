---
phase: 04-trip-history
plan: "03"
subsystem: ui
tags:
  - history-screen
  - trip-card
  - sliver-persistent-header
  - table-calendar
  - hist-01
  - hist-02
  - wave-2
dependency_graph:
  requires:
    - "lib/features/trips/providers/history_providers.dart (allTripSummariesProvider, groupTripsByDate, formatDateHeader from Wave 1)"
    - "lib/features/trips/services/trip_actions.dart (handleDeleteTrip from Wave 1)"
    - "lib/features/trips/widgets/edit_trip_sheet.dart (EditTripSheet from Phase 3)"
    - "lib/shared/utils/formatters.dart (formatDuration from Wave 1)"
    - "lib/config/constants.dart (Phase 4 history constants from Wave 1)"
    - "lib/config/routes.dart (kRouteTripDetail registered in Wave 1)"
    - "table_calendar ^3.1.3 (added in Wave 1)"
  provides:
    - "lib/features/trips/widgets/trip_card.dart — TripCard ConsumerWidget consumed by HistoryScreen list and calendar sub-list, with Edit/Delete options sheet"
    - "lib/features/trips/screens/history_screen.dart — HistoryScreen ConsumerStatefulWidget with list and calendar view modes, replacing the Wave 1 placeholder in full"
    - "Real assertions in test/unit/features/trips/history_grouping_test.dart (8 tests covering groupTripsByDate and formatDateHeader)"
    - "Real assertions in test/widget/features/trips/history_screen_test.dart (5 tests covering AppBar title, empty state, departure time render, calendar toggle, options sheet)"
  affects:
    - "Plan 04-04 (TripDetailScreen) — TripCard onTap navigates to kRouteTripDetail; the detail screen receives tripId via ModalRoute arguments and renders the route map and stats. HistoryScreen is the primary entry point to the detail screen."
    - "Phase 5 (Stats) — allTripSummariesProvider remains the canonical trip stream; Stats screens will subscribe in addition to HistoryScreen with no conflict (Riverpod auto-dedupes)"
tech_stack:
  added:
    - "(none — flutter_map, latlong2, table_calendar already added in Wave 1)"
  patterns:
    - "SliverPersistentHeader with fixed extent (40dp) + private SliverPersistentHeaderDelegate that compares label in shouldRebuild — Flutter-native sticky headers with no extra dependency (Pitfall 5 mitigation)"
    - "Single _groupedTrips Map computed once in the data branch and reused as both the list source and the TableCalendar.eventLoader backing store — keeps event lookup O(1) per day (T-04-03-03 acceptance, Pitfall 6 separation)"
    - "TableCalendar placed BEFORE the trip sub-list inside a Column (not inside the calendar widget) so the TripCard's InkWell.onTap and IconButton onPressed never compete with table_calendar's internal day-tap handler (Pitfall 6 mitigation)"
    - "Two-step delete via more_vert → options sheet → Delete row → handleDeleteTrip's confirmation dialog (T-04-03-01 mitigation: accidental single-tap cannot delete; context.mounted guard between sheet pop and the dialog)"
    - "Local UI-only state (view mode, selected day, focused day) kept in setState within ConsumerStatefulWidget — data state still flows through StreamProvider"
key_files:
  created:
    - lib/features/trips/widgets/trip_card.dart
  modified:
    - lib/features/trips/screens/history_screen.dart
    - test/unit/features/trips/history_grouping_test.dart
    - test/widget/features/trips/history_screen_test.dart
decisions:
  - "Removed `calendarFormat: CalendarFormat.month` from TableCalendar — analyzer reports it as redundant (matches the package default). Pitfall 4 mitigation is satisfied by `formatButtonVisible: false`, which is still present and prevents the user from switching to week/2-week format. The explicit constant was originally listed in the plan's implementation note for clarity, but very_good_analysis flags it under avoid_redundant_argument_values."
  - "The plan suggested `slivers.add(...)` calls in sequence; cleaned to a `..add(...)..add(...)` cascade after analyzer flagged cascade_invocations. Both forms are equivalent at runtime; the cascade is the project's preferred lint-clean form."
  - "Calendar's `focusedDay` is clamped to `lastDay` (today) on every build — TableCalendar throws if focusedDay > lastDay, which can happen after midnight if the focusedDay was set yesterday and never updated. Cheap guard, no UX impact."
  - "Widget test 'tapping a trip card opens the options sheet' verifies the more_vert path rather than the InkWell.onTap navigation path. Asserting Navigator.pushNamed on `kRouteTripDetail` would require mounting the full kAppRoutes map and a NavigatorObserver to confirm the route push — disproportionate scaffolding for a behavior whose contract is two lines of TripCard.build. The options-sheet assertion exercises the deeper code path (showModalBottomSheet → SafeArea → ListTile rendering) and confirms the T-04-03-01 two-step guard surface."
requirements_completed:
  - HIST-01
  - HIST-02
metrics:
  duration_minutes: 5
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 3
  tests_added: 13
  tests_passing: 145
  tests_skipped: 12
  completed_date: "2026-04-26"
---

# Phase 4 Plan 03: Wave 2 HistoryScreen + TripCard Summary

**TripCard widget and HistoryScreen (with list and calendar view modes) replace the Wave 1 placeholder, plus 13 real test assertions filling in the HIST-01/HIST-02 stubs from Wave 0.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-26T06:41:55Z
- **Completed:** 2026-04-26T06:46:55Z
- **Tasks:** 2 / 2
- **Files created:** 1
- **Files modified:** 3

## Accomplishments

- Created `lib/features/trips/widgets/trip_card.dart` — a `ConsumerWidget` (no providers read in build, but `ref` is passed to action callbacks) that renders a Material 3 `Card.filled` with the direction icon, departure time (`DateFormat.jm()`), duration (via `formatDuration`), a direction `Chip`, and a trailing `more_vert` `IconButton`. The card body navigates to `kRouteTripDetail` with the trip UUID as the route argument; the more_vert opens a `showModalBottomSheet` with `Edit trip` and `Delete trip` `ListTile` rows. Edit re-launches `EditTripSheet` (Phase 3); Delete delegates to `trip_actions.handleDeleteTrip` (Wave 1).
- Overwrote `lib/features/trips/screens/history_screen.dart` (Wave 1 placeholder) with the full implementation. `HistoryScreen` is a `ConsumerStatefulWidget` with three pieces of local UI state: `_viewMode`, `_selectedDay`, `_focusedDay`. The build watches `allTripSummariesProvider` and routes to one of two body widgets:
  - `_ListBody` — `CustomScrollView` with one `SliverPersistentHeader(pinned: true)` per date group (label resolved via `formatDateHeader`) followed by a `SliverList` of `TripCard` rows. Header is fixed at 40dp via the private `_DateHeaderDelegate` (Pitfall 5).
  - `_CalendarBody` — `TableCalendar<TripSummary>` on top with primary-color marker dots, `primaryContainer` today decoration, `markersMaxCount: 1`, `formatButtonVisible: false` (Pitfall 4), `eventLoader` doing an O(1) `Map` lookup against the same `_groupedTrips` map. Below the calendar: `Divider` + `Expanded(child: _CalendarSubList(...))` showing the selected day's trips. Empty/no-selection states use `kHistoryCalendarEmptyDate` and `kHistoryCalendarNoSelection`.
- Empty state for the list view shows `Icons.route_outlined` (64dp), `kHistoryEmptyHeading` (`titleMedium`), and `kHistoryEmptyBody` (`bodyMedium`, centered).
- AppBar trailing icon toggles between `Icons.calendar_month_outlined` (when in list view, tooltip "Switch to calendar") and `Icons.list_rounded` (when in calendar view, tooltip "Switch to list").
- Replaced 7 `markTestSkipped` stubs in `test/unit/features/trips/history_grouping_test.dart` with real assertions: `groupTripsByDate` empty input, same-day local grouping, different-day separation, date-only key (no H/M/S/MS), newest-first ordering preservation; `formatDateHeader` today, yesterday, and `EEE d MMM` regex match for older dates.
- Replaced 5 `markTestSkipped` stubs in `test/widget/features/trips/history_screen_test.dart` with real widget assertions: AppBar 'History' title rendered, empty state copy when trip list is empty, trip card departure time (`DateFormat.jm()`-derived), calendar toggle reveals `TableCalendar`, and trip card `more_vert` opens an options sheet exposing 'Edit trip' / 'Delete trip' rows.
- Suite result: **145 passing / 12 skipped / 0 failing** (the 12 still-skipped tests belong to plan 04-04 trip detail and unrelated Wave 0 stubs).

## Task Commits

1. **Task 1: Implement HistoryScreen and TripCard for HIST-01/HIST-02** — `7140c2e` (feat)
2. **Task 2: Fill HIST-01/HIST-02 unit and widget test stubs** — `7a908a1` (test)

_Plan-metadata commit (this SUMMARY) follows below._

## Files Created/Modified

- `lib/features/trips/widgets/trip_card.dart` (CREATED) — 156 lines, `ConsumerWidget` with private `_DirectionChip` sub-widget. Imports `kDirectionToOffice`, `kDirectionToHome` for the icon switch, `kRouteTripDetail` for navigation, `formatDuration` for the subtitle, `EditTripSheet` for the edit row, `trip_actions.handleDeleteTrip` (aliased) for the delete row.
- `lib/features/trips/screens/history_screen.dart` (MODIFIED — full rewrite) — 313 lines. `HistoryScreen` `ConsumerStatefulWidget` plus 5 private widgets: `_ListBody`, `_CalendarBody`, `_CalendarSubList`, `_EmptyState`, `_DateHeaderDelegate`. All sub-widgets kept in the same file (private to the screen, do not need to be reused) and each is well under 100 lines.
- `test/unit/features/trips/history_grouping_test.dart` (MODIFIED — full rewrite) — 8 tests, no skipped. Helper `_makeTrip` factory eliminates duplication. Tests are timezone-independent: same-day grouping verifies total count and key-set membership rather than exact key values, so the test passes regardless of where it runs.
- `test/widget/features/trips/history_screen_test.dart` (MODIFIED — full rewrite) — 5 tests, no skipped. `buildScreen` helper composes `ProviderScope` with all four required overrides (`appDatabaseProvider`, `tripsDaoProvider`, `syncQueueDaoProvider`, `allTripSummariesProvider`) plus a deterministic `Stream<List<TripSummary>>.value(trips)`. The DAO providers are still required because `handleDeleteTrip` and `EditTripSheet` (used by the more_vert options sheet) read from those providers; without overrides the test would crash on first `more_vert` tap.

## Decisions Made

- **Removed `calendarFormat: CalendarFormat.month` from TableCalendar** — `very_good_analysis` reports it as `avoid_redundant_argument_values` because `CalendarFormat.month` is the package default. Pitfall 4 mitigation is satisfied by `formatButtonVisible: false`, which is still present and is what actually prevents the user from switching format. The plan's implementation note listed it explicitly for clarity, but the lint disagrees; removed inline (Rule 1 lint clean-up).
- **Cascade for sliver list construction** — Initial draft used two separate `slivers.add(...)` calls per date group. Analyzer reported `cascade_invocations`; switched to `slivers..add(...)..add(...)` per the project's lint preference. Same runtime behavior, simpler diff.
- **focusedDay clamp to lastDay** — `TableCalendar` asserts `focusedDay <= lastDay`. Initial draft set `_focusedDay = DateTime.now()` once in field initialiser; if a user opens the screen at 23:59 and the system rolls over to the next day before they tap calendar, the assertion fires. Clamped at every build with `focusedDay.isAfter(lastDay) ? lastDay : focusedDay`. Cheap guard, no functional impact.
- **Widget test focuses on options sheet, not navigation** — Test 5 verifies the `more_vert` → options sheet path rather than asserting on `Navigator.pushNamed(kRouteTripDetail, ...)`. Asserting the route push would require mounting `kAppRoutes` in the test (which transitively loads `TripDetailScreen`, a Wave 1 placeholder soon to be overwritten by plan 04-04), plus a `NavigatorObserver` mock — disproportionate scaffolding for a behavior whose contract is two lines of TripCard.build. The options-sheet assertion exercises the deeper code path and confirms the T-04-03-01 two-step guard surface (Edit and Delete are both present and labelled correctly).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Lint] `cascade_invocations` info on consecutive `slivers.add(...)` calls**
- **Found during:** Task 1 first analyze pass after writing history_screen.dart
- **Issue:** `very_good_analysis` flags two consecutive method calls on the same receiver (`slivers.add(...); slivers.add(...);`) and prefers the cascade form.
- **Fix:** Switched to `slivers..add(...)..add(...)` cascade. Same runtime behavior; one fewer linter info.
- **Files modified:** `lib/features/trips/screens/history_screen.dart`
- **Verification:** `flutter analyze lib/features/trips/screens/history_screen.dart` → only the `avoid_redundant_argument_values` info remained (fixed in deviation 2).
- **Committed in:** `7140c2e` (Task 1 commit, bundled with the file creation)

**2. [Rule 1 - Lint] `avoid_redundant_argument_values` info on `calendarFormat: CalendarFormat.month`**
- **Found during:** Task 1 second analyze pass after the cascade fix
- **Issue:** `CalendarFormat.month` is the `TableCalendar` default. The plan listed it explicitly for clarity, but the linter reports it as redundant.
- **Fix:** Removed the line. Pitfall 4 mitigation (preventing the user from toggling to week format) is preserved by `formatButtonVisible: false`, which is still present.
- **Files modified:** `lib/features/trips/screens/history_screen.dart`
- **Verification:** `flutter analyze lib/features/trips/widgets/trip_card.dart lib/features/trips/screens/history_screen.dart` → `No issues found!`
- **Committed in:** `7140c2e` (Task 1 commit, bundled with the file creation)

**3. [Rule 1 - Bug] `Override` type identifier not exported by flutter_riverpod**
- **Found during:** Task 2 first widget-test run
- **Issue:** Used `<Override>[ ... ]` for the `ProviderScope.overrides` list. Compilation error: `'Override' isn't a type.` flutter_riverpod 3.x exposes the override builder methods (`overrideWithValue`, `overrideWith`) but not the `Override` class identifier.
- **Fix:** Removed the `<Override>` type annotation from the list literal — matches the existing `edit_trip_sheet_test.dart` pattern.
- **Files modified:** `test/widget/features/trips/history_screen_test.dart`
- **Verification:** `flutter test test/widget/features/trips/history_screen_test.dart` → 5 tests pass.
- **Committed in:** `7a908a1` (Task 2 commit, bundled with the test file rewrite)

---

**Total deviations:** 3 auto-fixed (1 import-shape bug, 2 lint clean-ups). All within the scope of the current task — no scope creep, no out-of-scope discoveries deferred.

## Issues Encountered

- None. The Wave 1 contracts (`allTripSummariesProvider`, `groupTripsByDate`, `formatDateHeader`, `handleDeleteTrip`, `formatDuration`) all worked exactly as documented, and no Wave 1 file required modification.

## Threat Flags

No new security-relevant surface introduced beyond what the plan's `<threat_model>` already enumerates:
- **T-04-03-01 (Spoofing on delete)** — mitigated as planned: more_vert → options sheet → Delete row → `handleDeleteTrip`'s confirmation dialog. Single-tap accidental delete is impossible. `context.mounted` guard sits between the options sheet `Navigator.pop()` and the call into `trip_actions.handleDeleteTrip`.
- **T-04-03-02 (Elevation via tripId argument)** — accepted as planned. UUIDs come from the user's own Drift rows; `kRouteTripDetail` only receives values produced by `TripCard.summary.id`.
- **T-04-03-03 (DoS via TableCalendar eventLoader)** — mitigated as planned: `_groupedTrips` is computed once in the `data` branch of the `AsyncValue.when` and shared between the list view and the calendar's `eventLoader`. The eventLoader is a single `Map` lookup per day, O(1).

## Next Phase Readiness

- Plan 04-04 (TripDetailScreen) can begin immediately. Its primary entry point (`Navigator.pushNamed(kRouteTripDetail, arguments: tripId)`) is now wired from every `TripCard` in the list and the calendar sub-list. The Wave 1 placeholder `TripDetailScreen` still satisfies the routes contract, so 04-04 will overwrite it without breaking anything.
- The HistoryScreen's calendar view is fully functional but its `_DateHeaderDelegate` private class is exclusive to the list view — TripDetailScreen has no shared dependency on history_screen.dart.
- Wave 2 sibling agent (plan 04-04 TripDetailScreen) and this agent share zero overlapping files; no merge conflict expected.

## Self-Check

- [x] `lib/features/trips/widgets/trip_card.dart` exists in the worktree.
- [x] `lib/features/trips/screens/history_screen.dart` exists (overwritten Wave 1 placeholder).
- [x] `class TripCard extends ConsumerWidget` present in trip_card.dart (line 24).
- [x] `class HistoryScreen extends ConsumerStatefulWidget` present in history_screen.dart (line 30).
- [x] `allTripSummariesProvider` referenced in history_screen.dart (line 66).
- [x] `SliverPersistentHeader` referenced in history_screen.dart.
- [x] `TableCalendar<TripSummary>` referenced in history_screen.dart.
- [x] `formatButtonVisible: false` referenced in history_screen.dart (Pitfall 4 mitigation).
- [x] `kHistoryEmptyHeading` referenced in history_screen.dart.
- [x] `trip_actions.handleDeleteTrip` referenced in trip_card.dart.
- [x] `EditTripSheet` referenced in trip_card.dart.
- [x] `kRouteTripDetail` referenced in trip_card.dart.
- [x] No relative imports — all imports use `package:traevy/...` prefix.
- [x] `flutter analyze lib/features/trips/widgets/trip_card.dart lib/features/trips/screens/history_screen.dart` exits 0 with `No issues found!`.
- [x] `flutter test test/unit/features/trips/history_grouping_test.dart` — 8 tests pass, 0 skipped.
- [x] `flutter test test/widget/features/trips/history_screen_test.dart` — 5 tests pass, 0 skipped.
- [x] `flutter test` (full suite) — 145 passing / 12 skipped / 0 failing.
- [x] No `markTestSkipped` calls remain in either of the two rewritten test files.
- [x] Commit `7140c2e` present (Task 1 — TripCard + HistoryScreen).
- [x] Commit `7a908a1` present (Task 2 — test stubs filled in).

## Self-Check: PASSED

---
*Phase: 04-trip-history*
*Plan: 03*
*Completed: 2026-04-26*
