---
phase: 24-automatic-cloud-sync-restore
verified: 2026-06-16T04:24:47Z
status: gaps_found
score: 4/6 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Failed sync items are automatically re-attempted without user action but without spamming the server."
    status: failed
    reason: "_lastAutoRetry is never updated, meaning the time gate never closes and the server can be spammed by triggers."
    artifacts:
      - path: "lib/sync/sync_engine.dart"
        issue: "_lastAutoRetry is declared but never assigned when a retry occurs."
    missing:
      - "Assign _lastAutoRetry = _now() inside retryFailed() or processPending() so the kFailedAutoRetryWindow is enforced."
  - truth: "Users can choose to keep local, use cloud, or merge, with cloud values correctly overwriting local via DAO."
    status: failed
    reason: "The 'Merge' resolution option is a stub that behaves identically to 'Use Cloud' without offering field-by-field merge UI."
    artifacts:
      - path: "lib/features/settings/widgets/conflict_resolution_sheet.dart"
        issue: "No field-by-field merge UI implemented. kConflictMerge radio simply passes the raw cloud companion to updateTrip."
    missing:
      - "Implement field-by-field UI expansion for conflicting trips and actual merge logic combining local and cloud fields before updating."
human_verification:
  - test: "Auto-Restore Notification & Transition"
    expected: "During sign-in, the auto-restore toast and state transitions happen smoothly without blocking UI or leaving persistent dialogs."
    why_human: "Real-time UI transition and feel cannot be reliably checked via static tests."
  - test: "Sync Stuck Banner Appearance"
    expected: "The dashboard banner appears with correct styling when sync is failed and auto-retry is exhausted, and dismissing it removes it cleanly without layout shifts."
    why_human: "Visual appearance and layout shifts require a human check."
  - test: "Conflict Resolution Bottom Sheet"
    expected: "The bottom sheet clearly presents conflict details (same UUID vs overlap) and is readable without text overflow."
    why_human: "Text truncation, scrolling behavior, and general readability of trip details."
---

# Phase 24: Automatic Cloud Sync & Restore Verification Report

**Phase Goal:** Cloud sync and restore become hands-off — signing in restores cloud trips automatically, finished trips sync immediately, and sync items that previously failed are retried automatically instead of getting stuck
**Verified:** 2026-06-16T04:24:47Z
**Status:** gaps_found
**Re-verification:** No

## Goal Achievement

### Observable Truths

| #   | Truth   | Status     | Evidence       |
| --- | ------- | ---------- | -------------- |
| 1   | Failed sync items are automatically re-attempted without user action but without spamming the server. | ✗ FAILED | `_lastAutoRetry` is never set in `SyncEngine`, breaking the time-gate |
| 2   | The user sees a visible banner when sync items are genuinely stuck. | ✓ VERIFIED | `SyncStuckBanner` is wired to Dashboard via `_StuckBannerGate` |
| 3   | Upon signing in, the app automatically triggers a cloud restore exactly once per session. | ✓ VERIFIED | `MainShell` triggers restore correctly using a session flag |
| 4   | A toast notification informs the user about the restore progress and outcome. | ✓ VERIFIED | ScaffoldMessenger shows SnackBar with `kAutoRestore` constants |
| 5   | Cloud trips that conflict with local trips prompt the user for resolution instead of silent deduplication. | ✓ VERIFIED | `RestoreController` emits conflict state and sheet is shown |
| 6   | Users can choose to keep local, use cloud, or merge, with cloud values correctly overwriting local via DAO. | ✗ FAILED | Merge is a stub. It behaves identical to Use Cloud with no field selection |

**Score:** 4/6 truths verified

### Required Artifacts

| Artifact | Expected    | Status | Details |
| -------- | ----------- | ------ | ------- |
| `lib/features/dashboard/widgets/sync_stuck_banner.dart` | Stuck item visual notification | ✓ VERIFIED | Exists and is used correctly |
| `lib/features/main/screens/main_shell.dart` | Auto-restore trigger via auth listener | ✓ VERIFIED | Contains sign-in listener and toast logic |
| `lib/sync/restore_controller.dart` | Conflict detection heuristic | ✓ VERIFIED | Detects same-UUID and overlapping conflicts |
| `lib/features/settings/widgets/conflict_resolution_sheet.dart` | UI for resolving restore conflicts | ✗ STUB | Exists but field-by-field merge is entirely missing |

### Key Link Verification

| From | To  | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `dashboard_screen.dart` | `sync_stuck_banner.dart` | SyncStatus check | ✓ WIRED | Connected via `_StuckBannerGate` |
| `main_shell.dart` | `restore_controller.dart` | `restore()` | ✓ WIRED | Called in auth state listener |
| `restore_controller.dart` | `trips_dao.dart` | `updateTrip()` | ⚠️ PARTIAL | Sheet calls `updateTrip`, but merge logic is incomplete |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `conflict_resolution_sheet.dart` | `conflicts` | `restoreControllerProvider` | Yes (from `apiClient`) | ✓ FLOWING |

### Human Verification Required

### 1. Auto-Restore Notification & Transition

**Test:** Sign in with Google (fresh or later).
**Expected:** During sign-in, the auto-restore toast and state transitions happen smoothly without blocking UI or leaving persistent dialogs.
**Why human:** Real-time UI transition and feel cannot be reliably checked via static tests.

### 2. Sync Stuck Banner Appearance

**Test:** Force a sync failure so the banner appears on the Dashboard.
**Expected:** The dashboard banner appears with correct styling when sync is failed and auto-retry is exhausted, and dismissing it removes it cleanly without layout shifts.
**Why human:** Visual appearance and layout shifts require a human check.

### 3. Conflict Resolution Bottom Sheet

**Test:** Trigger a restore that has conflicts.
**Expected:** The bottom sheet clearly presents conflict details (same UUID vs overlap) and is readable without text overflow.
**Why human:** Text truncation, scrolling behavior, and general readability of trip details.

### Gaps Summary

Two implementation gaps prevent this phase from passing:
1. **Broken Auto-Retry Time Gate:** In `SyncEngine`, the `_lastAutoRetry` variable is never assigned a value. Because it remains `null`, the `isAutoRetryExhausted` check is always true, meaning the 4-hour `kFailedAutoRetryWindow` time gate is completely broken. Any connectivity or resume trigger will immediately fire a retry without throttling, risking server spam.
2. **Merge Resolution is a Stub:** In `ConflictResolutionSheet`, the `kConflictMerge` option provides no UI for users to perform a field-by-field merge. Instead, selecting "Merge" executes the exact same logic as "Use Cloud" (`await tripsDao.updateTrip(companion);`). The required per-trip override UI (keep-local / use-cloud / field-by-field merge) is incomplete.

---

_Verified: 2026-06-16T04:24:47Z_
_Verifier: the agent (gsd-verifier)_
