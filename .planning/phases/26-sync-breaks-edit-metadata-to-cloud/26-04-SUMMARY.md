---
phase: 26-sync-breaks-edit-metadata-to-cloud
plan: 04
subsystem: sync
tags: [backfill, sync-queue, drift, riverpod, auth-seam]

# Dependency graph
requires:
  - phase: 26-02
    provides: getBackfillMarkerVersion/setBackfillMarkerVersion marker DAO, kBackfillMarkerVersion constant, schema v7 marker column
  - phase: 26-03
    provides: Breaks-aware TripSerializer/SyncEngine — enqueued trips upload WITH the new metadata when the queue drains
provides:
  - TripsDao.tripIdsWithNonDefaultMetadata — single D-01 query (breaks EXISTS OR isEdited OR directionSource != time), duplicate-free plain id list
  - MainShell._runBackfillIfNeeded — marker-guarded exactly-once backfill enqueue, silent (no UI)
  - MainShell._runAutoRestoreThenBackfill — sign-in sequencing: auto-restore fully completes BEFORE backfill (T-26-12)
affects: [26-05, 26-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Correlated EXISTS subquery in a Drift where clause: existsQuery(attachedDatabase.selectOnly(childTable)..addColumns([childTable.id])..where(childTable.fk.equalsExp(t.id))) — no join, no duplicate parent rows"

key-files:
  created: []
  modified:
    - lib/database/daos/trips_dao.dart
    - test/unit/database/trips_dao_test.dart
    - lib/features/shell/main_shell.dart
    - test/widget/features/shell/main_shell_test.dart

key-decisions:
  - "Marker stamped AFTER the enqueue loop completes (enqueue-time = done, per CONTEXT.md Claude's Discretion) — the sync queue is persistent with retries, so a crash mid-loop re-runs the backfill next sign-in and enqueueUpdate duplicates are harmless (payload re-read fresh at sync time)"
  - "Backfill is fully silent — no snackbar/dialog (CONTEXT.md records no UI decision for backfill, unlike auto-restore's toasts)"
  - "Widget tests override appDatabaseProvider with a real in-memory AppDatabase (covers all three DAO providers at once) plus fakes for restoreControllerProvider/syncEngineProvider so the sign-in sequence is deterministic and network-free"
  - "mounted guards added before each ref.read in _runBackfillIfNeeded — the method runs across awaits after a fire-and-forget listener call, and ref use after dispose throws"

patterns-established:
  - "Sign-in-seam composition: new post-sign-in work sequences inside _runAutoRestoreThenBackfill (one unawaited call, internally awaited steps) instead of adding a second independent ref.listen callback that could race"

requirements-completed: []

duration: ~20min
completed: 2026-07-13
---

# Phase 26 Plan 04: One-Time Metadata Backfill Summary

**Every local trip with non-default v0.3 metadata (breaks / edited / non-time directionSource) is re-enqueued for upload exactly once per install, marker-guarded, sequenced strictly after auto-restore on the AuthSignedIn transition — executed INLINE by the orchestrator after three executor-infrastructure failures (two connection drops, one stall), zero rework.**

## Performance

- **Duration:** ~20 min active work
- **Completed:** 2026-07-13
- **Tasks:** 2 completed

## Task Commits

1. `fb3c141` feat(26-04): tripIdsWithNonDefaultMetadata D-01 backfill candidate query
2. `6f9cd0c` feat(26-04): marker-guarded one-time backfill on sign-in seam after auto-restore

## What Was Built

- **Task 1 — D-01 candidate query.** `TripsDao.tripIdsWithNonDefaultMetadata()` selects trip ids where `isEdited = true` OR `directionSource != 'time'` OR a correlated `EXISTS` subquery finds `trip_breaks` rows. One row per trip (OR conditions on a single select, no join), projected to plain `List<String>` for direct `enqueueUpdate` feeding. 5 new unit tests cover each inclusion condition, the all-default exclusion, and the multi-condition no-duplicates case (11/11 file total green).

- **Task 2 — marker-guarded sign-in backfill.** `MainShell._runBackfillIfNeeded()` reads the Plan 02 marker, no-ops at `>= kBackfillMarkerVersion`, otherwise enqueues every candidate id and stamps the marker after the loop. The existing `ref.listen<AuthState>` callback now calls `_runAutoRestoreThenBackfill()` which awaits `_runAutoRestore()` THEN the backfill — same fire-and-forget shape from the listener, restore/backfill ordering guaranteed internally (T-26-12). 2 new widget tests (real in-memory Drift + fake auth/restore/sync-engine) prove: candidate enqueued once + marker stamped, and a marker-stamped sign-in enqueues nothing. All 5 pre-existing MainShell tests unchanged and green.

## Verification

- `flutter test test/unit/database/trips_dao_test.dart` — 11/11 green
- `flutter test test/widget/features/shell/main_shell_test.dart` — 7/7 green (5 pre-existing + 2 new)
- `flutter analyze` on all touched files — no new issues vs pre-change baseline (info-count went 23 → 17 after dart format)

## Deviations

- None functional. Executed inline by the orchestrator (documented recovery path) after three subagent infrastructure failures; plan followed as written.

## Self-Check: PASSED
