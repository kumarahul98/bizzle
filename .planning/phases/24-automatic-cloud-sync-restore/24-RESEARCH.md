# Phase 24: Automatic Cloud Sync & Restore — Research

**Status:** Complete

## Technical Approach & Constraints

### 1. Auto-Restore Seam & Trigger
- **Seam**: The `authStateProvider` transitioning to `AuthSignedIn` is the perfect trigger. Since `RestoreController` handles its own errors and is fire-and-forget, the best pattern in Riverpod is a `ref.listen(authStateProvider)` inside a persistent UI shell (e.g., `MainShell` where `ScaffoldMessenger.of(context)` is available).
- **Idempotency Guard**: D-01 specifies "once per sign-in, not per launch". A local state variable in the listener (e.g., `_hasRunAutoRestoreForCurrentSession`) can track whether the restore has already fired for the currently signed-in user, preventing it from running on every hot reload or resume while still firing on fresh sign-ins.
- **Conflict with Upload**: Phase 20 handles backfilling in `AuthService.signIn()` transactionally. By triggering restore in response to `AuthSignedIn` (which occurs *after* `AuthService.signIn()` completes and `FirebaseAuth` broadcasts the new state), the local DB is already backfilled, ensuring correct sequencing (upload enqueues → auth state updates → download/reconcile starts).

### 2. Conflict Detection & Merge
- **Same-UUID differences**: This is straightforward exact matching. If a downloaded trip has the same UUID as a local trip but different fields (e.g., edited flag, direction, duration), it's a conflict.
- **Time-overlap heuristic**: To detect commutes recorded on two devices concurrently.
  - **Rule**: Overlap is defined as `max(start1, start2) < min(end1, end2)`.
  - **Threshold**: Given `kTrackingSampleInterval` and normal app usage, any overlap > 1 minute between a cloud trip and a local trip with a different UUID should be flagged.
- **Resolution mechanism**:
  - `TripsDao` already has `insertOrIgnoreTrips`.
  - For non-conflicts: continue using `insertOrIgnoreTrips`.
  - For conflicts: present the UI. If the user chooses "Use cloud" or "Merge", use `updateTrip()` which inherently re-enqueues the trip for sync. If the user chooses "Keep local", do nothing (local wins, no update).

### 3. Time-Gated Auto-Retry (SYNC-05b)
- **Mechanism**: The existing `SyncEngine` has a `retryFailed()` method that clears the backoff window, resets failed rows, and drains. We just need to wrap calls to this method with a time-gate.
- **Time-Gate Value**: Add `kFailedAutoRetryWindow = Duration(hours: 4)` to `lib/config/constants.dart`.
- **State Persistence**: Since the triggers are connectivity-restored and app-resume, the last-auto-retry timestamp can just be an in-memory `DateTime? _lastAutoRetry` in `SyncEngine`. If the app is killed and restarted, an immediate retry is acceptable (the process death acts as a natural long-term gate).

### 4. Stuck-Item Surfacing (SYNC-05b)
- **UI Location**: `DashboardScreen` body, rendering a `SyncStuckBanner` (patterned after `PermissionBanner`) when `ref.watch(syncStatusProvider)` is `SyncFailed` AND the auto-retry window is exhausted or the engine indicates rows are stuck.
- **Condition**: Add a `isStuck` getter to `SyncFailed` or compute it based on the retry limits.

## Architectural Verification

- **SYNC-05a (Immediate Sync)**: Verified. `SyncEngine.start()` sets up `watchPending()` which triggers `processPending()` on any rising edge of pending rows. `persistFinalizedTrip` creates a pending row. The path is completely wired and instantaneous.
- **Data Flow**: The backend `restoreTrips()` returns all active trips. Merges will call `updateTrip()`, bumping `modifiedAt` and enqueueing an update row, propagating the resolved state back to the cloud.

## Plan Recommendations
- **Plan 1: Time-Gated Auto-Retry & Stuck Surfacing**: Add `kFailedAutoRetryWindow`, implement the time-gate in `SyncEngine` for the resume/connectivity triggers, and build the `SyncStuckBanner`.
- **Plan 2: Auto-Restore Seam**: Implement the `ref.listen` in `MainShell` to trigger `RestoreController.restore()` and show the `AutoRestoreToast`.
- **Plan 3: Conflict Detection & Reconciliation (The Core)**: Refactor `RestoreController.restore()` to categorize downloaded trips into non-conflicting, same-UUID conflicts, and time-overlap conflicts. Build the bulk-resolution UI and wire the "Keep local" / "Use cloud" logic through `TripsDao.updateTrip()`.
