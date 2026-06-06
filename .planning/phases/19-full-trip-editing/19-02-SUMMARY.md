---
phase: 19-full-trip-editing
plan: 02
subsystem: trips-ui
tags: [flutter, riverpod, edit-sheet, date-time-picker, breaks, validation, recompute, widget-tests]

# Dependency graph
requires:
  - phase: 19-full-trip-editing
    plan: 01
    provides: "is_edited column (schema v4), pure TripEditRecompute service, atomic full-edit editTrip path, EditBreakSegment/EditValidationResult, Phase 19 UI-copy constants"
provides:
  - "Full trip-edit sheet UI: date+time pickers for start/end (UTC stored, local shown), add/edit/remove break editor, live in-memory recompute preview, service-driven inline validation gating Save, clamp/drop snackbar"
  - "Reusable EstimatedHint widget + '~ estimated' affordance on trip detail legend and history/dashboard rows when a trip is_edited"
  - "isEdited threaded through TripSummary -> TripRowCard -> TripRowInfo (additive, default false)"
affects: [stats, sync]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure recompute/validation service read live in the widget (in-memory, no Drift writes while editing); Save hands the SAME computed numbers to the I/O-only notifier"
    - "Shared pickLocalDateTimeAsUtc helper (showDatePicker -> showTimePicker -> compose local -> toUtc) reused by the sheet's start/end pickers and each BreakRow"
    - "Sub-widget extraction (_DirectionField/_DateTimeField/_ActionRow + break_row/break_editor_list/edit_recompute_preview/estimated_hint) keeps each widget small and the sheet scrollable"

key-files:
  created:
    - lib/features/trips/widgets/break_row.dart
    - lib/features/trips/widgets/break_editor_list.dart
    - lib/features/trips/widgets/edit_recompute_preview.dart
    - lib/features/trips/widgets/estimated_hint.dart
    - test/widget/features/trips/break_editor_list_test.dart
    - test/widget/features/trips/estimated_hint_test.dart
  modified:
    - lib/features/trips/widgets/edit_trip_sheet.dart
    - lib/features/trips/screens/trip_detail_screen.dart
    - lib/shared/widgets/trip_row_card.dart
    - lib/shared/widgets/trip_row_info.dart
    - lib/features/trips/screens/history_screen.dart
    - lib/features/dashboard/widgets/today_section.dart
    - lib/features/trips/widgets/trip_section_card.dart
    - test/widget/features/trips/edit_trip_sheet_test.dart

key-decisions:
  - "TripRowInfo lives at lib/shared/widgets/ (not lib/features/trips/widgets/ as the plan's files_modified listed); the estimated hint was threaded there. Plan path corrected."
  - "TripSummary.isEdited + _toSummary mapping already existed (added by Plan 01's deviation #3), so no trips_dao change was needed this plan."
  - "The picker-drive widget test edits the END date forward one day (deterministic in the visible month grid) rather than fighting the Material time-picker's two text-field input layout; the full pickLocalDateTimeAsUtc path (date -> time -> compose) is still exercised."

patterns-established:
  - "pickLocalDateTimeAsUtc as the single date+time selection helper across the edit surface"
  - "Live recompute preview computed from the exact same TripEditRecompute calls Save uses (T-19-07: preview never diverges from persisted values)"

requirements-completed: [TRACK-11]

# Metrics
duration: ~55min
completed: 2026-06-06
---

# Phase 19 Plan 02: Full Trip Editing — Edit Sheet UI + Estimated Hint Summary

**Wired Plan 01's pure recompute/validation logic to the user: the trip-edit sheet now has date+time pickers for start/end, an add/edit/remove break editor, a live in-memory recompute preview, service-driven inline validation that disables Save until valid, a "breaks adjusted" clamp/drop snackbar, and a "~ estimated" hint on edited trips' moving/stuck figures across detail + history.**

## Performance

- **Duration:** ~55 min
- **Completed:** 2026-06-06
- **Tasks:** 3
- **Files:** 6 created, 8 modified

## Accomplishments
- **Edit sheet (D-08/D-09/D-10/D-11/D-12):** replaced the time-only pickers with full date+time pickers (UTC stored, local shown via `DateFormat('EEE, d MMM · HH:mm')`); embedded a break-list editor; shows a live recompute preview (active duration + rescaled moving/stuck) that updates on every change with NO Drift writes; runs `TripEditRecompute.validate` on every change and disables Save + shows the specific `kEditValidation*` message when invalid; clamps breaks into a shrunk window and surfaces `kEditBreaksAdjustedSnackbar`; on Save computes active + rescaled traffic once and calls the extended `editTrip(..., breaks:, totalPausedSeconds:, timeMovingSeconds:, timeStuckSeconds:, durationSecondsOverride:, markEdited: true)`.
- **Original-ratio anchoring (D-01):** `_origMoving`/`_origStuck` are captured once in `initState` so repeated edits rescale from the original ratio, not a previously-rescaled value.
- **Seeded breaks:** `trip_detail_screen._handleEdit` reads `tripBreaksDao.breaksForTrip` (closed segments only) and passes them as `initialBreaks` so the editor opens with the trip's existing breaks.
- **Estimated hint (D-04):** new `EstimatedHint` widget (dim mono label + tooltip) renders on the trip-detail moving/stuck legend and on each history/dashboard row when `isEdited` is true; `isEdited` threaded through `TripRowCard` -> `TripRowInfo` (additive, default false) and passed from all three list call sites.
- **Widget extraction:** every new widget is callback-only presentation; the sheet body scrolls (`SingleChildScrollView`) and is broken into small sub-widgets.
- **Tests:** 7 net-new widget tests, all green; full suite 495 passing / 10 skipped / 0 failing (baseline 488 → +7, no regression).

## Task Commits

1. **Task 1+2: Full edit-sheet UI (widgets + extended sheet + seed breaks)** — `3081173` (trips)
2. **Estimated-hint widget + detail/history wiring** — `cf127d2` (trips)
3. **Task 3: Widget tests (edit sheet, break editor, estimated hint)** — `24f9d2e` (trips)

## Files Created/Modified
- `lib/features/trips/widgets/break_row.dart` — single editable break row + shared `pickLocalDateTimeAsUtc` helper.
- `lib/features/trips/widgets/break_editor_list.dart` — header + BreakRow list + Add break (immutable list updates).
- `lib/features/trips/widgets/edit_recompute_preview.dart` — read-only live duration/moving/stuck preview.
- `lib/features/trips/widgets/estimated_hint.dart` — reusable "~ estimated" label + tooltip.
- `lib/features/trips/widgets/edit_trip_sheet.dart` — extended into the full-edit sheet (pickers, break editor, preview, validation, clamp snackbar, full-edit save).
- `lib/features/trips/screens/trip_detail_screen.dart` — seed breaks into the sheet; EstimatedHint in the legend when edited; `_summaryFromRow` now carries `isEdited`.
- `lib/shared/widgets/trip_row_card.dart`, `lib/shared/widgets/trip_row_info.dart` — additive `isEdited` + hint render.
- `lib/features/trips/screens/history_screen.dart`, `lib/features/dashboard/widgets/today_section.dart`, `lib/features/trips/widgets/trip_section_card.dart` — pass `isEdited: summary.isEdited`.
- Tests: `edit_trip_sheet_test.dart` (extended), `break_editor_list_test.dart`, `estimated_hint_test.dart` (new).

## Decisions Made
- **TripRowInfo path corrected.** The plan's `files_modified` listed `lib/features/trips/widgets/trip_row_info.dart`, but the widget actually lives at `lib/shared/widgets/trip_row_info.dart` (alongside `trip_row_card.dart`). The estimated-hint threading was applied there.
- **No trips_dao change.** `TripSummary.isEdited` and the `_toSummary` mapping were already added by Plan 01's deviation #3, so the list views already carried `isEdited`.
- **Picker-drive test edits the END date forward one day** (deterministic within the visible month grid) instead of driving the Material time picker's two-field input layout, which is brittle across Flutter versions. The full `pickLocalDateTimeAsUtc` flow (date -> time -> compose -> toUtc) is still exercised; the time-picker dialog is laid out on an enlarged test surface.

## Deviations from Plan

### Adaptations (no behaviour change vs. plan intent)

**1. [Adaptation] TripRowInfo file location**
- **Plan said:** modify `lib/features/trips/widgets/trip_row_info.dart`.
- **Reality:** the file is `lib/shared/widgets/trip_row_info.dart`.
- **Action:** threaded `isEdited` + the hint there. No functional difference.

**2. [Adaptation] trips_dao already extended**
- **Plan Task 2 said:** add `isEdited` to `TripSummary` + `_toSummary`.
- **Reality:** Plan 01 already did this. Skipped to avoid a no-op edit.

### Auto-fixed Issues

**3. [Rule 1 - Bug] dart format produced brace-less `if` violating lint**
- **Found during:** Task 1 (break_row formatting).
- **Issue:** `dart format` reflowed `if (picked != null) onChanged(...)` onto two lines without braces, which the project lint rejects.
- **Fix:** wrapped both picker callbacks in `{ }` blocks.
- **Files modified:** lib/features/trips/widgets/break_row.dart
- **Committed in:** `3081173`

No architectural deviations. No CLAUDE.md violations: production-ready (no TODOs/stubs), Riverpod for persistence (local transient form state in the existing ConsumerStatefulWidget), every new widget is small and callback-only, all copy from `constants.dart`, UTC stored / local shown, Traevy tokens used throughout.

## Issues Encountered
- The Material time picker's text-input mode is fragile to drive deterministically in a widget test; resolved by exercising the date-picker leg for the displayed-label assertion (see Decisions). The persist/validation tests use seeded `initialBreaks` to drive recompute deterministically without pickers.
- Pre-existing `lines_longer_than_80_chars` infos in `test/widget/features/trips/trip_detail_screen_test.dart` are out of scope (not modified this plan) and were left as-is.

## User Setup Required
None.

## Next Phase Readiness
- The full trip-editing UI is complete and wired to the atomic write path; edited trips re-enter the one-way sync queue and display the "~ estimated" affordance. No blockers.

---
*Phase: 19-full-trip-editing*
*Completed: 2026-06-06*

## Self-Check: PASSED

All 6 created files exist on disk; all 3 task commits (`3081173`, `cf127d2`, `24f9d2e`) are present in git history; full suite green (495 passing / 0 failing).
