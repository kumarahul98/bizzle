# Phase 25: Interrupted-Trip Recovery

## Goal
A commute that is interrupted by a force-quit, app-clear, or OS-level kill is never silently lost — its state is persisted continuously, and on next launch the user is told about the interrupted trip and can resume or discard it.

## Context & Decisions

**D-01 (Persistence Mechanism):** 
To survive an OS kill, the active trip state must be persisted continuously. Given that a `TripSnapshot` contains a potentially large list of GPS points (`route`), we will persist it to a temporary JSON file (`active_trip.json`) in the app's documents directory on every location tick or significant state change (pause/resume).
- The file is overwritten on each update.
- On a clean stop, the file is deleted.

**D-02 (Detection & Bootstrapping):**
On app launch, `TrackingNotifier` (or a dedicated `RecoveryController`) checks for the existence of `active_trip.json`. 
- If found, it parses the snapshot and emits a special `TrackingState.interrupted(snapshot)` state.
- The `DashboardScreen` (or `MainShell`) listens for this state and presents a modal dialog offering to "Resume" or "Discard".

**D-03 (Resume Behavior):**
If the user selects "Resume", the `TrackingNotifier` takes the snapshot and reconstructs the `TripAccumulator` with the historic data, then immediately starts the background GPS service to continue appending new points. The timer and metrics continue from where they left off.

**D-04 (Discard Behavior):**
If the user selects "Discard", the `active_trip.json` file is deleted and the state resets to `TrackingIdle`.

## Requirements Addressed
- TRACK-13: Detect and recover from OS-level interruptions.

## Scope
- Write `TripSnapshot` serialization logic (toJson/fromJson).
- Write `TripStatePersister` service to handle saving/loading/deleting the file.
- Update `TrackingNotifier` to hook into the persister and expose the `interrupted` state.
- Create `RecoveryPromptDialog` UI component.
- Wire the recovery prompt into `MainShell`.
