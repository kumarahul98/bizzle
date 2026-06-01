---
phase: 11-sync-engine
plan: 02
subsystem: sync
tags: [sync, riverpod, drift, connectivity, backoff, client-authoritative]
requires:
  - "11-01: ApiClient + SyncException.retryable, SyncStatus/syncStatusProvider, TripSerializer.toJson, SyncQueueDao.markFailed/resetFailed/getPending"
  - "auth: authStateProvider / AuthSignedIn (signed-in gate, M4)"
  - "database: TripsDao.findById, providers.dart DAO providers"
provides:
  - "lib/sync/sync_engine.dart: SyncEngine + syncEngineProvider (processPending, retryFailed, backoffDelay)"
  - "SyncQueueDao.countFailed() for SyncFailed(count)"
  - "kMaxSyncBatchTrips constant"
affects:
  - "lib/app.dart (eager mount)"
tech-stack:
  added: ["connectivity_plus ^7.1.1 (already pinned by Plan 01)"]
  patterns: ["manual Riverpod Provider holding a service", "injected seams (isSignedIn/isOnline/now) for testability", "in-flight mutex + backoff-window guard", "sealed SyncStatus transitions"]
key-files:
  created:
    - "lib/sync/sync_engine.dart"
    - "test/unit/sync/sync_engine_test.dart"
  modified:
    - "lib/config/constants.dart (kMaxSyncBatchTrips)"
    - "lib/database/daos/sync_queue_dao.dart (countFailed)"
    - "lib/app.dart (ref.watch(syncEngineProvider))"
decisions:
  - "Claim the _inFlight mutex synchronously (before the offline await) so interleaved triggers cannot both drain"
  - "Capture the driver row's retryCount during the pending read (in _Effective) instead of re-querying in _handleFailure"
  - "Added SyncQueueDao.countFailed() (additive to the frozen Plan-01 DAO) to populate SyncFailed(count) without holding a stream"
metrics:
  completed: 2026-06-01
  tasks: 3
  files: 5
---

# Phase 11 Plan 02: Sync engine — queue processor + triggers Summary

One-liner: A background `SyncEngine` that collapses the Drift sync queue to one effective op per tripId, batches upserts into a single `POST /trips/sync`, branches failures on `SyncException.retryable` (retry+backoff vs immediate fail), coalesces triggers behind a backoff window, and is eager-mounted at app root without blocking the UI.

## Public surface (bound by Plan 03)

- `final Provider<SyncEngine> syncEngineProvider` — plain keepAlive `Provider` (NO `.notifier`).
- `Future<void> SyncEngine.processPending()` — the queue drain (collapse → batch → branch).
- `Future<void> SyncEngine.retryFailed()` — clears the backoff window, `resetFailed()`, then `processPending()`. The single entry point for Plan 03's "Sync failed — tap to retry" row.
- `Duration SyncEngine.backoffDelay(int retryCount)` — pure, public.
- `bool SyncEngine.backoffActive()` — diagnostic predicate (used by tests + MEDIUM-2 guard).
- `void SyncEngine.start()` / `void SyncEngine.dispose()` — provider-owned lifecycle.

## HIGH-1 — per-tripId queue collapse

Walks `getPending()` (oldest-first) building two maps keyed by tripId:
- Any pending DELETE for a tripId ⇒ effective op DELETE; superseded create/update rows are collected and `markSynced` **without sending**.
- Otherwise create/update collapse to ONE upsert (a representative driver row sends; the rest are `markSynced` on success).

Result: create+update → 1 `syncTrips` entry; create-then-delete → 0 creates sent + 1 `deleteTrip`; delete-only → 1 `deleteTrip`; distinct trips stay independent.

## Batching + missing-trip skip

Effective upserts load live rows via `TripsDao.findById`; a null result `markSynced`s all of that trip's rows and drops it from the payload. Live rows are chunked at `kMaxSyncBatchTrips` (1000) into successive `ApiClient.syncTrips(chunk)` calls (the engine passes live `TripRow`s; `ApiClient` serializes via `TripSerializer.toJson`). Deletes go individually via `ApiClient.deleteTrip` (404 already mapped to success in Plan 01 → a normal return ⇒ `markSynced`).

## HIGH-2 — retryable-aware failure branching (`_handleFailure`)

Branches on `SyncException.retryable`, NOT raw status codes:
- `!retryable` (e.g. a 400 poison pill) → `markFailed` IMMEDIATELY, no `incrementRetry`, no backoff (retry budget preserved).
- `retryable` (5xx / network / final-401) → `incrementRetry`; if `driverRetryCount + 1 >= kSyncQueueMaxRetries` (3) → `markFailed` (terminal); else `_scheduleBackoff`.
- `notSignedIn` → no-op (defensive; step (c) already gates guests).

## MEDIUM-2 — backoff window trigger guard

`_scheduleBackoff` sets `_backoffUntil = now().add(backoffDelay(n))` and arms `_backoffTimer`. `processPending()` returns early while `backoffActive()` — so connectivity/resume/post-save triggers coalesce and never bypass the timer. The timer firing is the only path that re-attempts during the window (it clears `_backoffUntil` then re-drains). A successful drain and `retryFailed()` both clear the window.

## Triggers (start) + connectivity edge seeding (M3)

`start()` first seeds `_wasOnline` from `(await Connectivity().checkConnectivity()).any((r) => r != ConnectivityResult.none)` (connectivity_plus 7.x returns `List<ConnectivityResult>`) BEFORE attaching listeners, so the first offline→online edge is not missed. Then attaches: `watchPending()` (post-save, M1), `onConnectivityChanged` (rising-edge only), and `AppLifecycleListener(onResume:)`. All handlers are `unawaited(processPending())`. `dispose()` cancels all four resources.

## Production wiring confirmed (M4)

`syncEngineProvider.isSignedIn = () => ref.read(authStateProvider) is AuthSignedIn` (real live FirebaseAuth session, not a stub). `isOnline` uses the real connectivity_plus v7 List check. The token attach is the real `getIdToken` seam inside Plan 01's `apiClientProvider`.

## Imported 11-01 contract names actually used

- `ApiClient.syncTrips / deleteTrip` and `apiClientProvider` — bound as-built.
- `SyncException.retryable` / `.notSignedIn` / `.statusCode` — engine branches on `retryable`. (Note: the as-built `SyncException` uses named constructors `SyncException.http(code)` / `.transport()` / `.notSignedIn()`; the `retryable` flag is derived inside those — the engine and tests use those constructors.)
- `TripSerializer.toJson` — confirmed used (by `ApiClient` internally; the engine passes live `TripRow`s, as the contract specifies).
- `SyncStatus` variants (`SyncIdle/SyncSyncing/SyncSynced/SyncOffline/SyncFailed`) + `SyncStatusNotifier.set(...)` + `syncStatusProvider` — bound as-built.
- `SyncQueueDao.getPending / watchPending / markSynced / incrementRetry / markFailed / resetFailed` — bound as-built; **added** `countFailed()`.

## New constant

`const int kMaxSyncBatchTrips = 1000;` in `constants.dart` (beside the existing backoff constants, which Plan 01 already added). `connectivity_plus ^7.1.1` and `http ^1.6.0` were already pinned by Plan 01.

## Unit-test coverage map (test/unit/sync/sync_engine_test.dart — 23 tests, all green)

- HIGH-1: create+update→1 entry (both synced); create-then-delete→no create + 1 delete (create synced w/o send); delete-only→delete; distinct trips independent.
- Batching: 2 creates + 1 update → one `syncTrips`; deletes-only → zero `syncTrips`.
- Missing-trip skip → markSynced + excluded.
- Success → markSynced + syncedAt + SyncSynced.
- HIGH-2: 503 → incrementRetry (stays pending); retryCount 2 + 503 → 3 + failed; 400 → markFailed immediately, retryCount 0, no backoff; notSignedIn mid-drain → no-op.
- In-flight guard: concurrent processPending → exactly one `syncTrips`.
- backoffDelay math: 0→2s, 1→4s, 2→8s, 100→60s cap.
- MEDIUM-2: trigger during active window → zero new calls; retryFailed clears window + not blocked.
- Status transitions: idle→syncing→synced.
- Offline → SyncOffline + zero calls + retry untouched; guest → zero calls + zero DB writes.
- delete-404 idempotent → synced; retryFailed re-enqueues failed → synced; never rethrows; empty queue → SyncSynced.

No real network, no real connectivity_plus, no Firebase platform channels (engine constructed directly with injected seams; `start()` is not called in unit tests).

## Verification (real results)

- Baseline `flutter analyze`: **96 issues** (87 info + 9 warning + 0 error).
- After this plan `flutter analyze`: **96 issues** — ZERO new (my new/changed files: `lib/sync/`, `lib/app.dart`, `lib/config/constants.dart`, `lib/database/daos/sync_queue_dao.dart`, `test/unit/sync/` all report "No issues found").
- `flutter test test/unit/`: **+269 ~10, All tests passed** (baseline was +246 ~10 → +23 new engine tests).
- `flutter test test/unit/sync/sync_engine_test.dart`: **+23 All tests passed**.
- No `cloud_firestore` import in `lib/sync/`; `app.dart` adds no await/FutureBuilder/sync-state gating.

## Deviations from Plan

**1. [Rule 3 - Blocking] Added `SyncQueueDao.countFailed()`**
- Found during: Task 2.
- Issue: The engine needs the count of terminal-`failed` rows to emit `SyncFailed(count)`, but the frozen Plan-01 DAO exposes only `getPending()`/`watchPending()` (which return pending rows only — failed rows are invisible). The originally-drafted `_failedCount()` via `watchPending().first` would always count zero failed rows.
- Fix: Added an additive `countFailed()` query to `SyncQueueDao` (does not change any Plan-01 method signature). Engine uses it for both the per-drain `SyncFailed` count and the catch-all path.
- Files: `lib/database/daos/sync_queue_dao.dart`.
- Commit: 49fdfc8.

**2. [Rule 1 - Bug] In-flight mutex claimed synchronously**
- Found during: Task 2 (in-flight guard test initially failed — `syncTrips` ran twice).
- Issue: The mutex was set after `await _isOnline()`, so two interleaved triggers both passed the guards before either claimed it.
- Fix: Claim `_inFlight = true` before the first `await`; moved the offline check inside the guarded `try`.
- Commit: 49fdfc8.

No architectural changes; no auth gates. The plan's Task-1 constants/dependency were largely pre-satisfied by Plan 01 (only `kMaxSyncBatchTrips` was new).

## Flag for Plan 03 (restore + Settings)

`ApiClient.restoreTrips()`, `SyncEngine.retryFailed()` (call as `ref.read(syncEngineProvider).retryFailed()` — NO `.notifier`), and the `syncStatusProvider` Settings row remain to be wired.

## Self-Check: PASSED

All 5 key files exist on disk; all 4 commits (7196e64, c662c49, 49fdfc8, 689fc6d) are present in git log.
