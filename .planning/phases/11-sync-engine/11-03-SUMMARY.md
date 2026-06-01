---
phase: 11-sync-engine
plan: 03
subsystem: sync
tags: [sync, restore, settings, drift, riverpod]
requires:
  - "lib/sync/api_client.dart (ApiClient.restoreTrips → Future<List<TripsCompanion>>) — Plan 01"
  - "lib/sync/trip_serializer.dart (TripSerializer.fromJson) — Plan 01"
  - "lib/sync/sync_status.dart (sealed SyncStatus, syncStatusProvider) — Plan 01"
  - "lib/sync/sync_engine.dart (syncEngineProvider Provider<SyncEngine>, SyncEngine.retryFailed()) — Plan 02"
  - "lib/database/daos/sync_queue_dao.dart (watchPending, countFailed)"
provides:
  - "RestoreController (Notifier<RestoreState>) + restoreControllerProvider + sealed RestoreState"
  - "TripsDao.insertOrIgnoreTrips — single-batch dedupe-by-UUID insert returning NEW-row count"
  - "pendingSyncCountProvider — StreamProvider<int> over SyncQueueDao.watchPending()"
  - "CloudSyncRow + RestoreRow Settings sub-widgets (signed-in Account section)"
affects:
  - "lib/features/settings/screens/settings_screen.dart (_AccountSection signed-in branch)"
tech-stack:
  added: []
  patterns:
    - "Manual Riverpod 3.x Notifier (no @riverpod codegen, project-wide analyzer pin)"
    - "Drift batch insertAll + InsertMode.insertOrIgnore for dedupe-by-UUID restore"
    - "Exhaustive switch on sealed SyncStatus for status-row copy"
key-files:
  created:
    - lib/sync/restore_controller.dart
    - lib/features/settings/widgets/cloud_sync_row.dart
    - lib/features/settings/widgets/restore_row.dart
    - test/unit/sync/restore_controller_test.dart
  modified:
    - lib/database/daos/trips_dao.dart
    - lib/config/constants.dart
    - lib/features/settings/providers/settings_providers.dart
    - lib/features/settings/screens/settings_screen.dart
    - test/widget/features/settings/settings_screen_test.dart
decisions:
  - "Plan 01 already added all cloud-sync/restore copy constants; Task 2 added only the trip-noun singular/plural constants for the 'Restored N trips' SnackBar"
  - "pendingSyncCountProvider lives in settings_providers.dart (DAO-derived, overridable in widget tests)"
  - "Widget test harness wraps SettingsScreen in a Scaffold so restore SnackBars have a host (mirrors production MainShell)"
metrics:
  duration: ~35m
  completed: 2026-06-01
  tasks: 3
  files: 9
---

# Phase 11 Plan 03: Restore-from-cloud + Settings UI wiring Summary

Manual restore-from-cloud flow (SYNC-03) with single-batch dedupe-by-UUID Drift
insert, plus the two deferred signed-in Settings rows (live cloud-sync status +
Restore from cloud) wired to the Plan 01/02 sync engine — completing Phase 11
success criterion 3.

## What shipped

- **`TripsDao.insertOrIgnoreTrips`** (lib/database/daos/trips_dao.dart): ONE Drift
  `batch((b) => b.insertAll(trips, companions, mode: InsertMode.insertOrIgnore))`
  over all restored companions, returning the NEW-row count via a pre/post
  `SELECT COUNT(*)` delta (MEDIUM-3). Existing UUIDs are skipped, never
  overwritten (client-authoritative). Empty list → 0, no statements.
- **`RestoreController` + `restoreControllerProvider`** (lib/sync/restore_controller.dart):
  manual `Notifier<RestoreState>`; `restore()` calls
  `ref.read(apiClientProvider).restoreTrips()` (List<TripsCompanion>, already
  mapped via `TripSerializer.fromJson` internally) → `insertOrIgnoreTrips` →
  `RestoreSuccess(count)`. Sealed `RestoreState`: `RestoreIdle` /
  `RestoreRestoring` / `RestoreSuccess(int count)` / `RestoreError`. Errors caught
  internally — never rethrows. Enqueues ZERO sync_queue rows (download-only, D-08).
- **`pendingSyncCountProvider`** (settings_providers.dart): `StreamProvider<int>`
  over `SyncQueueDao.watchPending()` for the live "$N pending" subtitle.
- **`CloudSyncRow`** (lib/features/settings/widgets/cloud_sync_row.dart): exhaustive
  switch on sealed `SyncStatus` → subtitle copy; on `SyncFailed` the row is tappable
  and calls `ref.read(syncEngineProvider).retryFailed()` (plain Provider instance,
  no `.notifier`, no separate reset/drain).
- **`RestoreRow`** (lib/features/settings/widgets/restore_row.dart): taps
  `restoreControllerProvider.notifier.restore()`, shows result SnackBar
  ("Restored N trips" / "Already up to date" / fixed error copy), double-tap +
  `context.mounted` guards.
- **`_AccountSection`** signed-in branch now renders AccountRow → CloudSyncRow →
  RestoreRow → Sign out. Guest branch unchanged.

## Bound Plan 01/02 frozen symbols (contract held)

| Symbol | Source | Bound as |
|--------|--------|----------|
| `apiClientProvider` | 11-01 api_client.dart | `ref.read(apiClientProvider)` |
| `ApiClient.restoreTrips()` | 11-01 | returns `Future<List<TripsCompanion>>` — consumed directly |
| `TripSerializer.fromJson` | 11-01 trip_serializer.dart | used in tests to build sample companions (HIGH-3) |
| `sealed SyncStatus` variants | 11-01 sync_status.dart | `SyncIdle` / `SyncSyncing` / `SyncSynced` / `SyncOffline` / `SyncFailed(count)` — exhaustive switch |
| `syncStatusProvider` | 11-01 | `ref.watch(syncStatusProvider)` |
| `syncEngineProvider` | 11-02 sync_engine.dart | plain `Provider<SyncEngine>`; `ref.read(syncEngineProvider).retryFailed()` |
| `SyncEngine.retryFailed()` | 11-02 | the single retry entrypoint (no `.notifier`) |
| copy constants `kSettingsSyncStatus*` / `kSettingsRestore*` | 11-01 constants.dart | reused; only trip-noun constants added by this plan |

## New batch DAO contract (for later replans)

`TripsDao.insertOrIgnoreTrips(List<TripsCompanion>) -> Future<int>` (MEDIUM-3):
one `batch(insertAll, InsertMode.insertOrIgnore)`, returns NEW-row COUNT(*) delta,
dedupe-by-UUID, never overwrites.

## Verification (real results)

- `dart run build_runner build --delete-conflicting-outputs`: **OK** — "Built with
  build_runner/jit in 10s; wrote 257 outputs." `trips_dao.g.dart` unchanged (added
  DAO methods reference the existing generated `trips` accessor — no codegen delta).
- `flutter analyze`: **96 issues before → 96 issues after** (87 info + 9 warning +
  0 error, identical baseline). **ZERO new issues.** All new/modified source files
  analyze clean; the only remaining items are pre-existing (e.g.
  constants.dart:232, unrelated test-file infos).
- `flutter test test/unit/sync/restore_controller_test.dart`: **9/9 GREEN** (DAO
  Tests A/B/B2; controller Tests C/D/E/F; zero-sync-rows; idle→success transition).
- `flutter test test/widget/features/settings/settings_screen_test.dart`: **20/20
  GREEN** (13 pre-existing Phase 8/9 + 7 new Phase 11).
- `flutter test` (FULL suite): **371 passed, 10 skipped, 0 failed.**

## Deviations from Plan

### Auto-added (within plan scope)

**1. [Rule 2 - Missing copy constants] trip-noun constants**
- **Found during:** Task 2 — Plan 01 added `kSettingsRestoreResultTemplate =
  'Restored'` and instructed callers to build `'Restored $n trips'`, but provided
  no singular/plural trip noun.
- **Fix:** Added `kRestoreTripNounSingular = 'trip'` / `kRestoreTripNounPlural =
  'trips'` (mirrors the `kDashboardTripCount*` pattern). No hardcoded strings.
- **Files:** lib/config/constants.dart — **Commit:** cc03bfb

**2. [Rule 3 - Test harness] Scaffold host for SnackBars**
- **Found during:** Task 3 — the existing harness pumps `MaterialApp(home:
  SettingsScreen())` with no Scaffold, so `ScaffoldMessenger.showSnackBar` had no
  descendant Scaffold to render the restore result feedback.
- **Fix:** Wrapped the screen in `Scaffold(body: SettingsScreen())` (mirrors the
  production MainShell). Existing AppBar-absence assertion still passes.
- **Files:** test/widget/features/settings/settings_screen_test.dart — **Commit:** 3601651

### Notable: constants pre-existing

Task 2 Part A planned to add cloud-sync/restore copy constants, but a grep showed
Plan 01 already added ALL of them (`kSettingsCloudSyncRowLabel`,
`kSettingsSyncStatus*`, `kSettingsRestore*`). Only the trip-noun constants were
missing — added per above. No duplicate definitions.

## Self-Check: PASSED

- Files: FOUND restore_controller.dart, cloud_sync_row.dart, restore_row.dart,
  restore_controller_test.dart.
- Commits: FOUND 16371d3, cc03bfb, 3601651.
