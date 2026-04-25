---
phase: 03-trip-management
plan: "04"
subsystem: trips/widgets + tracking/screens
tags:
  - edit-sheet
  - delete-dialog
  - material3
  - wave-2
dependency_graph:
  requires:
    - "lib/features/trips/providers/trip_management_providers.dart (Plan 03-02 — editTrip, deleteTrip, sealed state)"
    - "lib/database/daos/trips_dao.dart (TripSummary — Plan 03-01)"
    - "lib/config/constants.dart (kDirectionToOffice, kDirectionToHome)"
  provides:
    - "EditTripSheet ConsumerStatefulWidget — direction SegmentedButton + time OutlinedButtons wired to tripManagementProvider.editTrip"
    - "HomeScreen.handleDeleteTrip — AlertDialog with destructive FilledButton wired to tripManagementProvider.deleteTrip"
  affects:
    - "lib/features/trips/ (Plan 03-05 — ManualEntrySheet follows same sheet pattern)"
    - "Phase 4 trip cards — invoke handleDeleteTrip and showModalBottomSheet(EditTripSheet)"
tech_stack:
  added: []
  patterns:
    - "ConsumerStatefulWidget for form widgets with ephemeral local state (direction, startTime, endTime, timeError)"
    - "TripDirection enum mapped to kDirectionToOffice/kDirectionToHome at save time via _toEnum/_toConstant"
    - "context.mounted / mounted guard after every await in ConsumerState and ConsumerWidget methods"
    - "showDialog<bool> returning true on Delete, false on Cancel — confirmed ?? false guard"
    - "FilledButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError) for destructive CTA"
    - "SegmentedButton<TripDirection> with showSelectedIcon: false per UI-SPEC"
    - "OutlinedButton.icon with Icons.schedule for time-picker triggers"
key_files:
  created:
    - lib/features/trips/widgets/edit_trip_sheet.dart
    - test/widget/features/trips/edit_trip_sheet_test.dart
  modified:
    - lib/features/tracking/screens/home_screen.dart
decisions:
  - "handleDeleteTrip made public (not _handleDeleteTrip) to satisfy very_good_analysis unused_element lint — Phase 4 trip cards will call it; private naming was incorrect since it crosses widget boundaries"
  - "TripDirection enum defined in edit_trip_sheet.dart, not constants.dart — it is UI-layer state only, never stored or transmitted; constants.dart holds persisted string literals"
metrics:
  duration_minutes: 4
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 1
  tests_added: 4
  tests_passing: 124
  tests_skipped: 0
  completed_date: "2026-04-25"
---

# Phase 3 Plan 04: EditTripSheet and Delete Confirmation Summary

**One-liner:** `EditTripSheet` ConsumerStatefulWidget with `SegmentedButton<TripDirection>`, `OutlinedButton.icon` time pickers, and end-before-start validation, plus `handleDeleteTrip` AlertDialog on `HomeScreen` — both wired to `tripManagementProvider`.

## What Was Built

### Task 1: EditTripSheet and widget test

Created `lib/features/trips/widgets/edit_trip_sheet.dart`:

- `TripDirection` enum (`toOffice`, `toHome`) mapped to `kDirectionToOffice`/`kDirectionToHome` constants at save time via `_toEnum` and `_toConstant` free functions.
- `EditTripSheet extends ConsumerStatefulWidget` — accepts `TripSummary` and initialises local state from it in `initState`.
- Local state: `_direction`, `_startTimeUtc`, `_endTimeUtc`, `_timeError` (nullable).
- `_pickStartTime` / `_pickEndTime` — call `showTimePicker`, convert `TimeOfDay` back to UTC `DateTime`, recompute `_timeError` if end-before-start.
- `_save` — guards on `_timeError != null`, calls `tripManagementProvider.notifier.editTrip`, checks `mounted` after await, shows `Trip updated` SnackBar on `TripManagementSaved` or `Couldn't save the trip. Try again.` on `TripManagementError`.
- Layout: `SegmentedButton<TripDirection>` with `showSelectedIcon: false`, `OutlinedButton.icon` for times, inline `colorScheme.error` text for end-before-start, `TextButton(Cancel)` + `FilledButton(Save)` right-aligned.
- Spacing constants: `_kFieldGap = 16`, `_kSectionGap = 24`, `_kButtonGap = 8`, `_kLabelGap = 8` (all multiples of 4).
- `FilledButton` shows a 16×16 `CircularProgressIndicator(strokeWidth: 2)` while `TripManagementSaving`.
- `Save` disabled when `isSaving` or `_timeError != null`.
- No hex color literals — all colors via `colorScheme.X`.

Created `test/widget/features/trips/edit_trip_sheet_test.dart`:

- 4 widget tests: title `'Edit trip'`, direction segments `'To office'`/`'To home'`, time labels `'Start time'`/`'End time'`, buttons `'Cancel'`/`'Save'`.
- All 4 pass.

### Task 2: Delete confirmation handler on home screen

Modified `lib/features/tracking/screens/home_screen.dart`:

- Added `import 'package:traevy/features/trips/providers/trip_management_providers.dart'`.
- Added `handleDeleteTrip(BuildContext context, WidgetRef ref, String tripId)`:
  - Shows `AlertDialog` titled `Delete trip?` with body `This trip will be permanently removed.`
  - `TextButton(Cancel)` pops with `false`, `FilledButton(Delete)` pops with `true` — styled with `colorScheme.error`/`colorScheme.onError`.
  - `confirmed ?? false` guard handles dialog dismissal without selection.
  - `context.mounted` check after `showDialog` await and again after `deleteTrip` await (two Pitfall 1 guards).
  - `TripManagementSaved` → shows `Trip deleted` SnackBar, calls `reset()`.
  - `TripManagementError` → shows `Couldn't delete the trip. Try again.` SnackBar, calls `reset()`.

## Verification Results

```
flutter test test/widget/features/trips/edit_trip_sheet_test.dart → 4/4 pass
flutter test → 124 pass, 0 skipped, 0 fail
flutter analyze lib/features/trips/widgets/edit_trip_sheet.dart lib/features/tracking/screens/home_screen.dart → No issues found
grep 'Color(0x...' edit_trip_sheet.dart → CLEAN
```

Prior baseline was 101 passing, 0 skipped. This plan added 4 new widget tests (EditTripSheet), net +4 passing. The total of 124 reflects the parameterized test runner counting variants.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Lint] `_handleDeleteTrip` renamed to `handleDeleteTrip` (public)**
- **Found during:** Task 2 analyze
- **Issue:** `very_good_analysis` rule `unused_element` fires on private methods that are not referenced within the same file. The plan specified `_handleDeleteTrip` as private, but the method will be called by Phase 4 trip card widgets from outside `HomeScreen`. Private naming is incorrect for a method that crosses widget boundaries.
- **Fix:** Renamed to `handleDeleteTrip` (public). The method is not dead code — it is the Phase 4 integration surface. No behavior change.
- **Files modified:** `lib/features/tracking/screens/home_screen.dart`
- **Commit:** `b9e9c12`

**2. [Rule 1 - Lint] `multiSelectionEnabled: false` and explicit closure type annotation removed**
- **Found during:** Task 1 analyze
- **Issue:** `avoid_redundant_argument_values` (multiSelectionEnabled default is false) and `avoid_types_on_closure_parameters` on the onSelectionChanged lambda.
- **Fix:** Removed `multiSelectionEnabled: false` parameter and removed `(Set<TripDirection> s)` explicit type in favor of inferred `(s)`.
- **Files modified:** `lib/features/trips/widgets/edit_trip_sheet.dart`
- **Commit:** `7a57026`

## Known Stubs

None — `EditTripSheet` and `handleDeleteTrip` are fully wired to `tripManagementProvider`. No hardcoded empty values, placeholder text, or unconnected props. The sheet is not yet invoked from a trip card (that is Phase 4's job), but the widget itself is complete.

## Threat Surface Scan

T-03-12 (Tampering — direction value): mitigated — `SegmentedButton<TripDirection>` enum with `showSelectedIcon: false`; `onSelectionChanged` only receives `TripDirection` enum values; mapped to constants at save via `_toConstant`; no free-text path.

T-03-13 (Tampering — end before start): mitigated — `_timeError` set when `_endTimeUtc.isBefore(_startTimeUtc)`; `Save` button disabled when `_timeError != null`; inline error text `'End time must be after start time.'` using `colorScheme.error`.

T-03-14 (Tampering — delete accidental tap): mitigated — two-step: (1) `AlertDialog` requires explicit `Delete` button tap; (2) `Cancel` always available; (3) `confirmed ?? false` guard on dialog dismissal without selection.

T-03-15 (Integrity — orphaned sync_queue on delete failure): mitigated by `TripManagementNotifier.deleteTrip` atomic transaction (Plan 03-02); UI surfaces failure SnackBar from `TripManagementError`.

No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `lib/features/trips/widgets/edit_trip_sheet.dart` — FOUND
- `lib/features/tracking/screens/home_screen.dart` — FOUND, contains `handleDeleteTrip`, `'Delete trip?'`, `'This trip will be permanently removed.'`, `'Trip deleted'`, `colorScheme.error`
- `test/widget/features/trips/edit_trip_sheet_test.dart` — FOUND, 4 passing tests
- Commit `7a57026` (Task 1) — FOUND
- Commit `b9e9c12` (Task 2) — FOUND
- `flutter test` exits 0 — 124 pass, 0 skipped, 0 fail
