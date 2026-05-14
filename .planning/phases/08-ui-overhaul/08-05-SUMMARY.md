---
phase: "08"
plan: "05"
subsystem: "tracking-ui, trips-ui"
tags: [flutter, ui, tracking, history, restyle, variant-a, tdd]
dependency_graph:
  requires: ["08-03"]
  provides: ["restyled-tracking-screen", "restyled-history-screen"]
  affects: ["08-04", "08-06"]
tech_stack:
  added: []
  patterns:
    - StatMiniCard adapters for live metric tiles (thin wrapper pattern)
    - IntrinsicHeight for equal-height cross-stretch tiles inside Column
    - unawaited() for fire-and-forget AnimationController.repeat()
    - Token-mapped colors via colorScheme/scaffoldBackgroundColor when TraevyTokensExt omits direct field
    - Pitfall 10 mitigation: table_calendar uses tokens not colorScheme.primary
key_files:
  created:
    - lib/features/tracking/widgets/recording_header.dart
    - lib/features/tracking/widgets/elapsed_display.dart
    - lib/features/tracking/widgets/stop_button.dart
    - lib/features/tracking/widgets/faux_map_card.dart
    - lib/features/trips/widgets/history_view_toggle.dart
    - lib/features/trips/widgets/trip_section_card.dart
  modified:
    - lib/features/tracking/widgets/duration_tile.dart
    - lib/features/tracking/widgets/distance_tile.dart
    - lib/features/tracking/widgets/current_speed_tile.dart
    - lib/features/tracking/widgets/tracking_tiles_row.dart
    - lib/features/tracking/widgets/tracking_active_layout.dart
    - lib/features/tracking/widgets/tracking_idle_layout.dart
    - lib/features/tracking/screens/tracking_screen.dart
    - lib/features/trips/screens/history_screen.dart
    - lib/features/dashboard/widgets/today_trips_section.dart
    - test/widget/features/tracking/tracking_screen_test.dart
    - test/widget/features/trips/history_screen_test.dart
    - test/widget/features/dashboard/dashboard_screen_test.dart
  deleted:
    - lib/features/trips/widgets/trip_card.dart
decisions:
  - "IntrinsicHeight wraps TrackingTilesRow Row to bound height when inside Column+Spacer with CrossAxisAlignment.stretch"
  - "TraevyTokensExt omits bg/surface/text — must use scaffoldBackgroundColor and colorScheme.onSurface instead"
  - "DurationTile repurposed as stuck-time adapter (label STUCK, passes timeStuckSeconds not elapsedSeconds)"
  - "trip_card.dart deleted after migrating all callers (dashboard + history) to TripRowCard"
  - "dashboard_screen_test.dart patched with buildLightTheme() and setUpAll (Rule 1 fix — tests were missing theme)"
metrics:
  duration: "~4 hours"
  completed: "2026-05-14T17:04:57Z"
  tasks_completed: 2
  files_created: 6
  files_modified: 12
  files_deleted: 1
---

# Phase 08 Plan 05: Tracking Screen + Trip History Restyle Summary

**One-liner:** Tracking active layout rebuilt with RecordingHeader/ElapsedDisplay/StopButton/FauxMapCard sub-widgets; trip history rebuilt with HistoryViewToggle pill, TripSectionCard date groups, and legacy TripCard deleted.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Tracking screen Variant A restyle | 6f4cdbd | 8 created/modified |
| 2 | Trip History screen restyle + TripCard deletion | e12acfc | 9 created/modified/deleted |

## What Was Built

### Task 1 — Active Recording Screen (Variant A)

Four new sub-widgets compose `TrackingActiveLayout`:

- **RecordingHeader** — pulsing 8dp dot (1.5s AnimationController, opacity 0.5→1, `tokens.record` color) + direction label in `tokens.textMuted`
- **ElapsedDisplay** — `SectionLabel('ELAPSED')` + 76sp mono timer in HH:MM:SS format (always 3-segment)
- **StopButton** — full-width `onSurface`-background InkWell with stop icon + 'Stop and save trip' in `scaffoldBackgroundColor`
- **FauxMapCard** — 180dp container with `tokens.mapBg` background, `CustomPaint(_GridPainter)` drawing 24dp-spaced grid lines in `tokens.surface2`

Three tile widgets converted to thin `StatMiniCard` adapters:

- **DurationTile** → `StatMiniCard(label: 'STUCK', ...)` with `StatMiniCardTone.stuck`, receives `timeStuckSeconds`
- **DistanceTile** → `StatMiniCard(label: 'DISTANCE', ...)` with split `(value, unit)` record
- **CurrentSpeedTile** → `StatMiniCard(label: 'SPEED', ...)` with `tone: moving/stuck` based on speed threshold

`TrackingTilesRow` wrapped in `IntrinsicHeight` (required for `CrossAxisAlignment.stretch` inside Column+Spacer). AppBar hidden during active recording.

### Task 2 — Trip History Screen Restyle

- **HistoryView enum** + **HistoryViewToggle** — pill segmented control: `onSurface` selected bg, transparent unselected, `AnimatedContainer(150ms)`
- **TripSectionCard** — header row (date + subtitle + total) above full-width `bgElev` card with top+bottom `tokens.border`, `TripRowCard` rows
- **HistoryScreen** — no AppBar, title row ('Trips' + calendar icon button + add button), toggle pill, `_ListBody`/`_CalendarBody` split
- **Pitfall 10 fix** — `markerDecoration: tokens.accent`, `selectedDecoration: colorScheme.onSurface`, `todayDecoration: tokens.accentBg`
- **trip_card.dart deleted** — all callers migrated to `TripRowCard` fields

## Test Results

| Suite | Tests | Result |
|-------|-------|--------|
| tracking_screen_test.dart | 12 | PASS |
| history_screen_test.dart | 7 | PASS |
| dashboard_screen_test.dart | 19 | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] IntrinsicHeight required for TrackingTilesRow**
- **Found during:** Task 1 test run
- **Issue:** `CrossAxisAlignment.stretch` inside `Column` with `Spacer` propagates infinite height — widget tests crashed with BoxConstraints error
- **Fix:** Wrapped `Row` in `IntrinsicHeight` in `tracking_tiles_row.dart`
- **Files modified:** `lib/features/tracking/widgets/tracking_tiles_row.dart`
- **Commit:** 6f4cdbd

**2. [Rule 2 - Missing] TraevyTokensExt null in all widget tests**
- **Found during:** Task 1 and Task 2 test runs
- **Issue:** `MaterialApp()` without theme causes `Theme.of(context).extension<TraevyTokensExt>()!` to throw NPE; tracking, history, and dashboard tests all affected
- **Fix:** Added `theme: buildLightTheme(), darkTheme: buildDarkTheme()` and `setUpAll(TestWidgetsFlutterBinding.ensureInitialized)` to all three test files
- **Files modified:** `test/widget/features/tracking/tracking_screen_test.dart`, `test/widget/features/trips/history_screen_test.dart`, `test/widget/features/dashboard/dashboard_screen_test.dart`
- **Commit:** 6f4cdbd, e12acfc

**3. [Rule 1 - Bug] tokens.bg / tokens.surface / tokens.text not on TraevyTokensExt**
- **Found during:** Task 1 and Task 2 implementation
- **Issue:** `TraevyTokensExt` only has 14 fields — `bg`, `surface`, `text` are Material-mapped and must be accessed via `scaffoldBackgroundColor` / `colorScheme.surfaceContainer` / `colorScheme.onSurface`
- **Fix:** Used correct Material theme accessors throughout
- **Files modified:** Multiple widget files
- **Commit:** 6f4cdbd, e12acfc

**4. [Rule 1 - Bug] discarded_futures lint in RecordingHeader**
- **Found during:** Task 1 analysis
- **Issue:** `_controller.repeat(reverse: true)` returns a `Future` — lint flags unawaited fire-and-forget
- **Fix:** Added `import 'dart:async'` and wrapped with `unawaited()`
- **Files modified:** `lib/features/tracking/widgets/recording_header.dart`
- **Commit:** 6f4cdbd

**5. [Rule 2 - Missing] dashboard_screen_test.dart missing theme for TripRowCard**
- **Found during:** Task 2 — migrating dashboard to TripRowCard triggered StatMiniCard NPE
- **Issue:** Dashboard test had no Traevy theme — `StatMiniCard` (used by `InProgressCard`'s metrics) crashed
- **Fix:** Added `buildLightTheme()`/`buildDarkTheme()` + `setUpAll`
- **Files modified:** `test/widget/features/dashboard/dashboard_screen_test.dart`
- **Commit:** e12acfc

## Known Stubs

None — all widgets render real data from providers/props. No hardcoded placeholders.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundary changes introduced.

## Self-Check: PASSED

Files created:
- lib/features/tracking/widgets/recording_header.dart — FOUND
- lib/features/tracking/widgets/elapsed_display.dart — FOUND
- lib/features/tracking/widgets/stop_button.dart — FOUND
- lib/features/tracking/widgets/faux_map_card.dart — FOUND
- lib/features/trips/widgets/history_view_toggle.dart — FOUND
- lib/features/trips/widgets/trip_section_card.dart — FOUND

Files deleted:
- lib/features/trips/widgets/trip_card.dart — CONFIRMED DELETED

Commits verified:
- 6f4cdbd (Task 1 — Tracking restyle) — FOUND
- e12acfc (Task 2 — History restyle) — FOUND
