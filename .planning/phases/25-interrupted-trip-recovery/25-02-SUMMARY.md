---
phase: 25
plan: 02
subsystem: tracking
tags:
  - tracking-service
  - isolate-recovery
requires:
  - 25-01
provides:
  - engine-recovery
affects:
  - TrackingEventSource
  - MainIsolateTrackingEngine
  - FbsTrackingEventSource
  - TrackingServiceController
tech-stack:
  added: []
  patterns:
    - isolate-communication
key-files:
  created: []
  modified:
    - lib/features/tracking/services/tracking_event_source.dart
    - lib/features/tracking/services/main_isolate_tracking_engine.dart
    - lib/features/tracking/services/tracking_service_events.dart
    - lib/features/tracking/services/tracking_service.dart
    - lib/features/tracking/services/tracking_service_controller.dart
decisions:
  - "[Phase 25-02]: Passed initial state to background isolate via new kSetInitialStateCommand channel, avoiding modifications to the flutter_background_service start process."
metrics:
  duration: 15min
  completed_date: "2026-06-16T04:54:40Z"
---

# Phase 25 Plan 02: Tracking Engine Recovery Plumbed Summary

## Goal
Update the tracking service layers to accept an interrupted trip's state on `start()` so the `TripAccumulator` can be restored seamlessly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Functionality] Added kSetInitialStateCommand**
- **Found during:** Task 3 (Background Isolate Recovery)
- **Issue:** No event existed to pass the initial state map from the UI isolate to the service isolate cleanly without polluting the startup parameters.
- **Fix:** Added `kSetInitialStateCommand` to `tracking_service_events.dart` and implemented its listener inside `tracking_service.dart`.
- **Files modified:** `lib/features/tracking/services/tracking_service_events.dart`, `lib/features/tracking/services/tracking_service.dart`
- **Commit:** c45557d

## Self-Check: PASSED
