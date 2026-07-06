---
phase: 17-tracking-ui-fixes-quick-label
plan: 02
subsystem: ui
tags: [tracking, direction, segmented-button, riverpod, drift, flutter]

# Dependency graph
requires:
  - phase: 03-trip-history (DirectionLabelService auto-label rule)
    provides: time-of-day direction heuristic this plan overrides
  - phase: 04-trip-history (tripManagementProvider.editTrip DAO write path)
    provides: atomic updateTrip + enqueueUpdate reused by the trip-view toggle
  - phase: 08-ui-overhaul (HeroRecordCard active surface, Traevy tokens/fonts)
    provides: the production active-tracking surface and design system
provides:
  - DirectionSegmentedToggle — reusable controlled SegmentedButton<String> over the direction constants
  - TrackingNotifier manual direction override (resolvedDirection + setDirection)
  - persistFinalizedTrip optional directionOverride param (override wins at finalize, no migration)
  - live direction toggle on the active hero + 1-tap toggle on trip detail
affects: [tracking, trips, dashboard, any future plan touching direction labeling]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Manual override field on a Notifier (resolved getter = override ?? heuristic) consumed by every read site so one source of truth drives live + persisted values"
    - "Controlled (parent-owned) SegmentedButton<String> widget over string constants reused across two surfaces"

key-files:
  created:
    - lib/features/tracking/widgets/direction_segmented_toggle.dart
    - test/unit/features/tracking/tracking_notifier_direction_test.dart
    - test/widget/features/tracking/direction_segmented_toggle_test.dart
  modified:
    - lib/features/tracking/providers/tracking_providers.dart
    - lib/features/tracking/services/tracking_service_controller.dart
    - lib/features/dashboard/widgets/hero_record_card.dart
    - lib/features/trips/screens/trip_detail_screen.dart
    - lib/config/constants.dart

key-decisions:
  - "directionOverride param on persistFinalizedTrip is optional/nullable so existing callers compile unchanged and a null override reproduces byte-for-byte the prior auto-label behaviour (D-06, no Drift migration)"
  - "resolvedDirection (override ?? auto-label) centralises the direction logic previously inlined in _maybeRefreshNotification and HeroRecordCard._resolveDirection; both now read it (D-05)"
  - "_HeroActive became a StatefulWidget holding an optimistic local selection because setDirection mutates notifier-internal state without emitting a new TrackingState — the local mirror flips the header label/toggle on the same frame and reconciles against resolvedDirection on the next snapshot"
  - "Trip-view toggle reuses tripManagementProvider.editTrip (no new persistence path); the full EditTripSheet remains the comprehensive editor (D-07)"
  - "New widget is String-based over kDirectionToOffice/kDirectionToHome (not the edit-sheet's private TripDirection enum) so it can be shared across surfaces without leaking a private type"

patterns-established:
  - "Tamper guard (T-17-02): setDirection asserts the value is one of the two direction constants; the SegmentedButton only emits those two values"
  - "Timezone-independent direction tests: expected auto-label is computed from the same DirectionLabelService rule the production code uses, so tests pass under any host timezone (suite host is IST +0530)"

requirements-completed: [TRACK-12]

# Metrics
duration: ~35min
completed: 2026-06-06
---

# Phase 17 Plan 02: Quick Direction Selector (TRACK-12) Summary

**A 1-tap To office / To home segmented toggle now lets the user override the time-of-day direction heuristic live during an active trip and on saved trips — the override flows to the header label, the foreground notification, and the persisted `trips.direction` (at finalize via a new optional `directionOverride`, on the trip view via the existing `editTrip` DAO path) with no Drift schema change.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 2/2 complete
- **Files created:** 3 (1 widget, 2 test files)
- **Files modified:** 5
- **Commits:** 2 task commits + this docs commit

## Accomplishments

### Task 1 — Notifier override + persist threading (commit 39d5f35)
- Added nullable `_manualDirectionOverride` to `TrackingNotifier`.
- Added `resolvedDirection(startedAt)` = `override ?? DirectionLabelService auto-label` (prefs-driven, with `kDefaultDirectionCutoffHour` fallback).
- Added `setDirection(String)` — asserts the value is a valid direction constant, refreshes the notification immediately when a trip is active.
- Rewrote `_maybeRefreshNotification` to read `resolvedDirection` instead of inlining the labeler (D-05).
- Threaded `directionOverride: _manualDirectionOverride` into `persistFinalizedTrip` at finalize; reset the override in `stop()`.
- `persistFinalizedTrip` gained an optional `directionOverride` param; non-null wins over the auto-label into the existing `direction` column (D-06).
- Unit tests prove override-wins-at-finalize, null-preserves-auto-label, and the resolved getter behaviour.

### Task 2 — DirectionSegmentedToggle + wiring (commit 8dbf313)
- New `DirectionSegmentedToggle` (68 lines): controlled `SegmentedButton<String>`, Traevy-styled, both options visible, 1-tap, optional `enabled` flag.
- Wired into `_HeroActive` under `RecordingHeader` calling `setDirection`; header label flips on the same frame via an optimistic local selection.
- Removed the now-dead `HeroRecordCard._resolveDirection` helper and its unused imports (no dead code).
- Wired into the trip detail screen near the direction title; selection calls `editTrip` (existing DAO path) then reloads the trip (D-07).
- Widget tests prove tap → callback with the right constant, selection → highlighted segment, and disabled → inert.

## Verification

- `flutter test` (plan verification set): 29 passed — direction unit tests, persist tests, notifier tests, toggle widget tests, dashboard screen test all green.
- Full `flutter test`: 407 passed, 10 skipped, 0 failed (no regressions).
- `flutter analyze` on all five modified/created lib files: no issues. The only analyzer infos in the repo touching this plan's files (constants.dart lines 232/638/643) are pre-existing (present in HEAD~1, before this plan).
- No `cloud_firestore` import added; no Drift table/companion field added; `dart run build_runner build` not required.

## Deviations from Plan

### Auto-fixed / adapted

**1. [Rule 3 - Blocking] Timezone-dependent persist assertions**
- **Found during:** Task 1 (RED phase).
- **Issue:** The first draft asserted a fixed `08:00 UTC` start auto-labels `to_office`. The test host runs at IST +0530, so `08:00 UTC` = `13:30` local → the heuristic returns `to_home`, failing the assertion. The existing `persist_finalized_trip_test.dart` deliberately only asserts `isNot(kDirectionUnknown)` for exactly this reason.
- **Fix:** Rewrote both persist tests to compute the expected auto-label from the same `DirectionLabelService` rule the production code uses, then assert the override is the *opposite* of (and not equal to) that auto-label. Tests are now timezone-independent.
- **Files modified:** test/unit/features/tracking/tracking_notifier_direction_test.dart.
- **Commit:** 39d5f35.

**2. [Rule 3 - Blocking] resolvedDirection unit-test harness hung on a never-closing StreamProvider**
- **Found during:** Task 1 (RED phase).
- **Issue:** `await container.read(userPreferenceProvider.future)` on a `Stream.value(...)` override never completed and the container disposed mid-load, timing out at 30s.
- **Fix:** Switched to a kept-open broadcast `StreamController`, seeded a default value, and pumped a microtask so `.asData` populates synchronously — no `.future` await, no disposal-during-load.
- **Files modified:** test/unit/features/tracking/tracking_notifier_direction_test.dart.
- **Commit:** 39d5f35.

**3. [Plan discretion resolved] `_HeroActive` promoted to StatefulWidget**
- **Found during:** Task 2.
- **Issue:** The plan offered "make `_HeroActive` a ConsumerWidget OR pass the resolved string + callback — pick the smaller diff." Neither alone makes the header label flip *immediately* on tap, because `setDirection` does not emit a new `TrackingState`, so the dashboard does not rebuild on the tap.
- **Fix:** Kept the resolved-string + `onDirectionSelected`-callback wiring from the `ConsumerWidget` build, and made `_HeroActive` a small `StatefulWidget` that holds an optimistic local selection (seeded from the resolved direction, updated on tap, reconciled in `didUpdateWidget`). This flips the header and toggle on the same frame and reconciles against `resolvedDirection` on the next 1 Hz snapshot.
- **Files modified:** lib/features/dashboard/widgets/hero_record_card.dart.
- **Commit:** 8dbf313.

## Threat Model Compliance

- **T-17-02 (Tampering, mitigate):** `setDirection` asserts the value is exactly `kDirectionToOffice` or `kDirectionToHome`; `DirectionSegmentedToggle` only emits those two constants. No arbitrary string can reach `trips.direction` via either path.
- **T-17-03 / T-17-04 (accept):** The trip-view toggle reuses the existing `editTrip` DAO path (no new auth surface or query); the override only changes which of two non-sensitive labels shows in the existing notification. No new boundary introduced.

## Known Stubs

None — all surfaces are wired to live data/persistence.

## TDD Gate Compliance

Both tasks followed RED→GREEN. The plan's per-task commits combine the test and implementation for each logical task (one cohesive commit per task, as permitted by the execution protocol): commit 39d5f35 carries Task 1's tests + notifier/persist changes; commit 8dbf313 carries Task 2's tests + widget + wiring. Tests were written and observed failing (RED) before the implementation made them pass (GREEN) within each task.

## Self-Check: PASSED
