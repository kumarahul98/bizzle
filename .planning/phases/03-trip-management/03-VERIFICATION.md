---
phase: 03-trip-management
verified: 2026-04-25T12:00:00Z
status: human_needed
score: 4/4 must-haves verified
overrides_applied: 0
human_verification:
  - test: "EditTripSheet — edit and save a trip"
    expected: "After changing direction and/or times and tapping Save, the sheet dismisses and a 'Trip updated' SnackBar appears. The trip record in the list reflects the new values."
    why_human: "Requires interactive UI: showTimePicker dialog interaction, SegmentedButton state change, and sheet dismissal cannot be reliably driven in widget tests without a full trip card wired in Phase 4. The sheet widget exists and is wired to tripManagementProvider.editTrip — the integration point needs end-to-end confirmation."
  - test: "EditTripSheet — end-before-start validation blocks save"
    expected: "After setting end time earlier than start time, the inline error 'End time must be after start time.' appears in colorScheme.error color, and the Save button is disabled."
    why_human: "Requires showTimePicker interaction in a live widget environment to trigger the time-change path. The production code at lines 71 and 95 of edit_trip_sheet.dart implements this correctly, but no automated widget test exercises the time-picker interaction."
  - test: "ManualEntrySheet — Save button disabled until valid HH:MM entered"
    expected: "On initial render, Save button is disabled. After typing '0:45' in the duration field, Save button becomes enabled. After typing '25:00', inline error 'Use HH:MM format between 0:00 and 23:59.' appears and Save remains disabled."
    why_human: "The 5 widget tests in manual_entry_sheet_test.dart only verify rendering. The SUMMARY claimed these behaviors were tested but the actual test file does not contain them. The production code implements the logic correctly (line 207: (isSaving || !isFormValid) ? null : _save), but automated coverage is absent. Human must confirm the interactive behavior."
  - test: "FAB shows ManualEntrySheet on tap and hides during active tracking"
    expected: "Tapping the FAB opens the ManualEntrySheet bottom sheet with drag handle. Starting a commute track hides the FAB. Stopping tracking makes the FAB reappear."
    why_human: "FAB visibility depends on TrackingActive state from a background service. The wiring in home_screen.dart (isTracking ? null : FloatingActionButton) is correct, but the behavior requires a device or full integration test with the background service running to confirm the state-driven FAB toggle."
  - test: "Delete confirmation dialog — confirm deletes trip, cancel does not"
    expected: "Tapping Delete in the AlertDialog removes the trip and shows 'Trip deleted' SnackBar. Tapping Cancel or dismissing the dialog leaves the trip intact."
    why_human: "handleDeleteTrip is wired and correct in home_screen.dart, but it is not yet callable from a trip card (Phase 4 owns trip cards). Cannot trigger the flow from the current home screen UI without Phase 4 integration."
  - test: "DirectionBackfillProvider — Phase 2 trips labeled on first launch"
    expected: "Installing the Phase 3 build over a Phase 2 installation with kDirectionUnknown trips: on first launch, all unknown-direction trips are updated to to_office or to_home in the Drift database. Sync queue shows kSyncActionUpdate entries for each backfilled trip."
    why_human: "Requires a real device with Phase 2 trip data and an upgrade to Phase 3 build. The backfill logic is fully tested in backfill_provider_test.dart (4/4 passing), but the app-startup wiring (ref.watch in TraevyApp.build) needs a real launch to confirm it fires before the UI renders."
---

# Phase 3: Trip Management Verification Report

**Phase Goal:** Users can manage their trips — edit direction/times, delete with confirmation, and manually add a missed commute. All historical trips from Phase 2 receive correct direction labels on first app launch.
**Verified:** 2026-04-25T12:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Trips are auto-labeled as "to_office" or "to_home" based on start time and configurable cutoff | VERIFIED | `DirectionLabelService.label()` in `direction_label_service.dart` implements the cutoff rule (7 passing unit tests). `backfill_provider.dart` labels all `kDirectionUnknown` rows at startup (4/4 passing tests). `tracking_service_controller.dart` replaces `kDirectionUnknown` with a real label at save time — `grep -n "kDirectionUnknown"` returns zero hits in the controller. |
| 2 | User can edit a trip's direction label and adjust start/end times | VERIFIED | `EditTripSheet` exists as a `ConsumerStatefulWidget` with `SegmentedButton<TripDirection>`, `OutlinedButton.icon` time pickers, end-before-start validation, and `_save()` calling `tripManagementProvider.notifier.editTrip(...)`. 4 widget rendering tests pass. Full interaction needs human confirmation (see Human Verification). |
| 3 | User can delete a trip after confirming via dialog | VERIFIED | `handleDeleteTrip` in `home_screen.dart` shows an `AlertDialog` titled 'Delete trip?' with a destructive `FilledButton.styleFrom(backgroundColor: colorScheme.error)` Delete button. Confirmation calls `tripManagementProvider.notifier.deleteTrip(tripId)` inside a transaction. 4 unit tests in `trip_management_notifier_test.dart` verify the transactional atomicity (trip removed, sync queue has `kSyncActionDelete`). Full dialog interaction from a trip card needs human confirmation (trip cards are Phase 4). |
| 4 | User can manually enter a forgotten trip with date, duration, and direction (no GPS data) | VERIFIED | `ManualEntrySheet` exists as a `ConsumerStatefulWidget` with date picker, HH:MM `TextField`, `SegmentedButton<_TripDirection>`, and `_save()` calling `insertManualTrip(startTimeUtc:, endTimeUtc:, direction:)`. `parseHhMm` validates 0:00–23:59. `insertManualTrip` saves with `isManualEntry=true`, `distanceMeters=0.0`, `routePolyline=''` (8 unit tests in `manual_entry_notifier_test.dart`). FAB on `HomeScreen` opens the sheet via `showModalBottomSheet`. 5 rendering widget tests pass. Save-disabled and error-message behaviors need human confirmation. |

**Score:** 4/4 truths verified (automated evidence supports all truths; human confirmation needed for interactive UI behaviors)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/database/daos/trips_dao.dart` | `updateTrip(TripsCompanion)` and `deleteTrip(String id)` | VERIFIED | Both methods present with explicit WHERE clause (Pitfall 4 safe). Lines 115 and 128. |
| `lib/features/trips/services/direction_label_service.dart` | Pure stateless direction labeler | VERIFIED | `const DirectionLabelService` with `label(DateTime, int)` method. No async, no Riverpod. |
| `lib/features/trips/providers/trip_management_providers.dart` | `TripManagementState` sealed class + `TripManagementNotifier` + `tripManagementProvider` + `parseHhMm` | VERIFIED | Sealed class with 4 variants (Idle/Saving/Saved/Error). `editTrip`, `deleteTrip`, `insertManualTrip` methods present. `parseHhMm` free function exported. |
| `lib/features/tracking/providers/backfill_provider.dart` | `directionBackfillProvider FutureProvider<void>` | VERIFIED | Bare `FutureProvider` (keepAlive=true, no autoDispose). Queries `db.trips WHERE direction = kDirectionUnknown`. Single `db.transaction()` wrapping all updates. |
| `lib/features/trips/widgets/edit_trip_sheet.dart` | `EditTripSheet ConsumerStatefulWidget` | VERIFIED | Full implementation with `SegmentedButton<TripDirection>`, `OutlinedButton.icon` time pickers, end-before-start validation, `_save()` wired to `editTrip`. |
| `lib/features/trips/widgets/manual_entry_sheet.dart` | `ManualEntrySheet ConsumerStatefulWidget` | VERIFIED | Full implementation with date picker, `TextField` (HH:MM), `SegmentedButton`, `parseHhMm` validation, `_save()` wired to `insertManualTrip`. |
| `lib/features/tracking/screens/home_screen.dart` | FAB + `handleDeleteTrip` + `_handleAddManualTrip` | VERIFIED | FAB present with `isTracking ? null` guard. `handleDeleteTrip` with AlertDialog and colorScheme.error. `_handleAddManualTrip` with `showModalBottomSheet`. |
| `lib/app.dart` | `TraevyApp extends ConsumerWidget` with `ref.watch(directionBackfillProvider)` | VERIFIED | Changed from `StatelessWidget` to `ConsumerWidget`. `ref.watch(directionBackfillProvider)` on line 28. |
| `lib/features/tracking/services/tracking_service_controller.dart` | `DirectionLabelService` wired; no `kDirectionUnknown` in direction assignment | VERIFIED | `DirectionLabelService` imported and used in `persistFinalizedTrip`. `kDirectionUnknown` not present as a direction assignment (grep returns zero hits). `UserPreferencesDao` added as 6th constructor parameter. |
| `lib/features/tracking/providers/tracking_providers.dart` | `userPreferencesDaoProvider` injected | VERIFIED | Line 83: `userPreferencesDao: ref.watch(userPreferencesDaoProvider)`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `trip_management_providers.dart` | `appDatabase.transaction()` | `editTrip`, `deleteTrip`, `insertManualTrip` all wrap DAO calls in `db.transaction()` | WIRED | Lines 68, 100, 137 — all three operations use `await db.transaction(...)` |
| `trip_management_providers.dart` | `TripsDao.deleteTrip` + `SyncQueueDao.enqueueDelete` | deleteTrip builds payload first (Pitfall 3), then calls both inside one transaction | WIRED | Lines 101–108: payload built before delete call, both inside `db.transaction()` |
| `backfill_provider.dart` | `TripsDao.updateTrip + SyncQueueDao.enqueueUpdate` | Single `db.transaction()` in provider body | WIRED | Lines 36–50: both calls inside `db.transaction()`, `toLocal()` before label (Pitfall 2) |
| `app.dart` | `directionBackfillProvider` | `ref.watch(directionBackfillProvider)` in `TraevyApp.build` | WIRED | Line 28 of app.dart — fires once on startup, non-blocking |
| `tracking_service_controller.dart` | `DirectionLabelService.label` | `persistFinalizedTrip` calls `label(trip.startTime.toLocal(), prefs.morningCutoffHour)` before transaction | WIRED | Confirmed via grep — `DirectionLabelService` used in controller, `kDirectionUnknown` absent from direction assignment |
| `edit_trip_sheet.dart` | `tripManagementProvider.notifier.editTrip` | `_save()` calls `ref.read(tripManagementProvider.notifier).editTrip(...)` | WIRED | Lines 104–111 |
| `home_screen.dart` | `tripManagementProvider.notifier.deleteTrip` | `handleDeleteTrip` calls `ref.read(tripManagementProvider.notifier).deleteTrip(tripId)` after AlertDialog confirmation | WIRED | Line 179 |
| `manual_entry_sheet.dart` | `tripManagementProvider.notifier.insertManualTrip` | `_save()` calls `ref.read(tripManagementProvider.notifier).insertManualTrip(...)` | WIRED | Lines 105–111 |
| `home_screen.dart` | `ManualEntrySheet` | `_handleAddManualTrip` calls `showModalBottomSheet(builder: (_) => const ManualEntrySheet())` | WIRED | Lines 75–83 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `backfill_provider.dart` | `unknownTrips` | `db.select(db.trips)..where((t) => t.direction.equals(kDirectionUnknown)).get()` | Yes — live Drift query | FLOWING |
| `trip_management_providers.dart editTrip` | `state` transitions | `db.transaction` → `TripsDao.updateTrip` + `SyncQueueDao.enqueueUpdate` | Yes — real DB writes | FLOWING |
| `trip_management_providers.dart deleteTrip` | `state` transitions | `db.transaction` → `TripsDao.deleteTrip` + `SyncQueueDao.enqueueDelete` | Yes — real DB deletes | FLOWING |
| `trip_management_providers.dart insertManualTrip` | `tripId` | `const Uuid().v4()` (line 136), then `TripsDao.insertTrip` + `SyncQueueDao.enqueueCreate` | Yes — real DB insert | FLOWING |
| `manual_entry_sheet.dart` | `isFormValid` | `parseHhMm(_durationController.text) != null` — live controller text evaluation | Yes — real-time validation | FLOWING |
| `edit_trip_sheet.dart` | `_startTimeUtc`, `_endTimeUtc` | Initialized from `widget.summary.startTime/endTime`, updated via `showTimePicker` | Yes — live trip data from TripSummary | FLOWING |

### Behavioral Spot-Checks

Step 7b: The project has runnable code. Spot-checks limited to non-interactive static checks (interactive UI behaviors are routed to human verification).

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `flutter test` exits 0 | `flutter test` | 129/129 pass, 0 skipped | PASS |
| `kDirectionUnknown` not used as direction in tracking controller | `grep "direction: kDirectionUnknown" tracking_service_controller.dart` | No output | PASS |
| `directionBackfillProvider` is bare FutureProvider (no autoDispose) | `grep "autoDispose" backfill_provider.dart` | No output | PASS |
| No hex color literals in UI files | `grep "Color(0x" edit_trip_sheet.dart manual_entry_sheet.dart home_screen.dart` | No output — CLEAN | PASS |
| No TODO/FIXME stubs in production files | grep for placeholders across 8 production files | No output — CLEAN | PASS |
| `parseHhMm` exported from `trip_management_providers.dart` | `grep "Duration? parseHhMm" trip_management_providers.dart` | Found at line 183 | PASS |
| `routePolyline: const Value('')` in insertManualTrip | `grep "routePolyline" trip_management_providers.dart` | Found at line 145 | PASS |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|---------------|-------------|--------|---------|
| TRACK-03 | 03-01, 03-02, 03-03 | Trip direction auto-labeled (morning = to_office, evening = to_home) with editable override | SATISFIED | `DirectionLabelService` (7 tests), backfill provider (4 tests), `persistFinalizedTrip` wired — no `kDirectionUnknown` in new trip flow |
| TRACK-06 | 03-02, 03-04 | User can edit trip details (direction label, adjust times) | SATISFIED | `TripManagementNotifier.editTrip` with atomic transaction (4 unit tests), `EditTripSheet` with full UI (4 widget tests) |
| TRACK-07 | 03-02, 03-04 | User can delete a trip with confirmation dialog | SATISFIED | `TripManagementNotifier.deleteTrip` with atomic transaction (4 unit tests), `handleDeleteTrip` AlertDialog in `HomeScreen` |
| TRACK-08 | 03-01, 03-03, 03-05 | User can manually enter a forgotten trip (date, duration, direction — no GPS data) | SATISFIED | `insertManualTrip` with D-10 fields (8 unit tests), `parseHhMm` validation (6 unit tests), `ManualEntrySheet` with FAB (5 widget tests) |

No orphaned requirements — all 4 requirements declared in plan frontmatter match the REQUIREMENTS.md traceability table for Phase 3 exactly.

### Anti-Patterns Found

No blockers or warnings found.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | — |

All production files are free of: TODO/FIXME/PLACEHOLDER comments, empty implementations, hardcoded empty data, hex color literals, `return null` stubs, and unused handler patterns.

Note: `manual_entry_sheet_test.dart` does not cover the Save-disabled behavior or inline validation error messages despite the SUMMARY claiming it did. The production code implements these correctly. This is a test coverage gap, not a production code defect. Not flagged as a blocker because: (a) the production logic is verifiably correct at the code level, (b) the behavior is routed to human verification item #3.

### Human Verification Required

#### 1. EditTripSheet — Full Edit Flow

**Test:** Open any trip's edit sheet (requires Phase 4 trip card, or directly mount `EditTripSheet` in a debug harness). Change the direction SegmentedButton from 'To office' to 'To home'. Tap 'Save'.
**Expected:** Sheet dismisses. 'Trip updated' SnackBar appears at the bottom. If you navigate to the trip, its direction reflects 'to_home'.
**Why human:** `showTimePicker` interaction and `NavigatorPop` cannot be fully driven by the existing widget tests. The wiring is verified at the code level; the interactive flow needs confirmation.

#### 2. EditTripSheet — End-Before-Start Validation

**Test:** Open an edit sheet. Tap the 'End time' button and select a time earlier than the Start time.
**Expected:** 'End time must be after start time.' appears below the End time button in red (colorScheme.error). The Save button is disabled (grayed out, does not respond to taps).
**Why human:** Requires showTimePicker interaction to trigger the validation path. The production code at lines 71 and 95 of `edit_trip_sheet.dart` implements this; no automated test exercises it.

#### 3. ManualEntrySheet — Save Button State and Inline Validation

**Test:** Open the ManualEntrySheet (via FAB). Observe Save button state. Type '25:00' in the Duration field. Observe error message. Clear field and type '0:45'. Observe Save button state.
**Expected:** (a) On initial render, Save is disabled. (b) After '25:00', error 'Use HH:MM format between 0:00 and 23:59.' appears, Save remains disabled. (c) After '0:45', error clears, Save is enabled.
**Why human:** The `manual_entry_sheet_test.dart` does not contain tests for these behaviors despite the SUMMARY claiming it does. The production code at lines 81–88 and line 207 implements this correctly; human must confirm.

#### 4. FAB Visibility Toggle During Tracking

**Test:** Open the home screen. Observe FAB (Add missed commute). Start a commute (navigate to tracking screen and tap Start). Return to home screen.
**Expected:** FAB disappears when tracking is active (because `isTracking ? null : FloatingActionButton(...)`). After stopping the commute, FAB reappears.
**Why human:** Requires the background tracking service to actually start. The state-driven logic is correct in `home_screen.dart` line 37, but FAB toggle needs a live device with the background service active.

#### 5. Delete Confirmation Flow (When Trip Cards Exist)

**Test:** Navigate to a trip card (Phase 4 or test harness with trip data). Trigger the delete handler. In the dialog, tap 'Delete'.
**Expected:** Dialog dismisses. 'Trip deleted' SnackBar appears. Trip no longer appears in the list.
**Why human:** `handleDeleteTrip` is a public method on `HomeScreen` ready for Phase 4 trip cards to call, but no UI surface currently triggers it. Cannot test the flow until Phase 4 wires the trip card's delete button.

#### 6. Phase 2 Trip Backfill on Upgrade

**Test:** Install a Phase 2 build, create 3 trips via GPS tracking (they will have `kDirectionUnknown`). Upgrade to Phase 3 build. Launch the app.
**Expected:** On first launch, all 3 trips' directions are updated (e.g., morning trips become 'to_office', evening trips become 'to_home'). The Drift database reflects the changes. Sync queue has `kSyncActionUpdate` entries for all 3 trips.
**Why human:** Requires a real device upgrade scenario. The logic is fully unit-tested (4/4 backfill tests), but the app-startup trigger (`ref.watch(directionBackfillProvider)` in `TraevyApp.build`) needs confirmation against a real Phase 2 dataset.

### Gaps Summary

No gaps found. All 4 ROADMAP Success Criteria are met by the implementation. All 4 requirement IDs (TRACK-03, TRACK-06, TRACK-07, TRACK-08) are satisfied.

The `human_needed` status reflects 6 interactive UI behaviors that cannot be verified programmatically without either Phase 4 trip cards (items 1, 5) or live device testing (items 4, 6). Items 2, 3 can be verified by directly mounting the widgets in a test harness with user interaction. None of these represent code defects — the production logic is substantive and wired end-to-end.

---

_Verified: 2026-04-25T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
