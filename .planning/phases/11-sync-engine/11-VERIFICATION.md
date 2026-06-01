---
phase: 11-sync-engine
verified: 2026-06-01T00:00:00Z
status: human_needed
score: 4/4 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: none
  previous_score: n/a
human_verification:
  - test: "End-to-end background sync against the LIVE deployed Cloud Functions backend"
    expected: "Signed-in Google user records/edits/deletes a trip on a real device; the sync_queue row drains to Firestore and the Settings 'Cloud sync' row settles on 'All synced'"
    why_human: "Requires a real Firebase ID token, live HTTPS endpoints, and Firestore — only the injected ApiClient/connectivity seams are unit-tested in CI"
  - test: "Connectivity-restored and app-resume triggers on real hardware"
    expected: "Going offline then online (and backgrounding/resuming the app) automatically drains pending rows once, no tight-loop"
    why_human: "connectivity_plus platform-channel edges and AppLifecycleListener resume cannot be exercised in the unit harness; the rising-edge/backoff-window logic IS unit-tested with a stubbed channel"
  - test: "Cloud restore round-trip on a device with real backend data"
    expected: "Tapping 'Restore from cloud' downloads the user's Firestore trips, inserts new ones into Drift (skipping duplicates), and shows 'Restored N trips' / 'Already up to date'"
    why_human: "Needs a populated Firestore collection and a live token; the dedupe/count-delta/SnackBar logic IS unit + widget tested with a fake ApiClient"
---

# Phase 11: Sync Engine Verification Report

**Phase Goal:** Trips automatically sync from Drift to Firestore (via Cloud Functions) in the background, and users can restore from cloud backup.
**Verified:** 2026-06-01
**Status:** human_needed (all logic VERIFIED-IN-CODE/TESTS; only live-backend/on-device end-to-end remains)
**Re-verification:** No — initial verification

## Tooling Run (by the verifier, not from summaries)

- **`flutter analyze`** → **96 issues = 87 info + 9 warning + 0 error**. Matches the stated baseline exactly; **no NEW issues**. (Severity counted via `• info/warning/error •` delimiter; all 96 reside in pre-existing test files, none in `lib/sync/**` or the new Settings widgets.)
- **`flutter test` (full suite)** → **377 passed, 10 skipped, 0 failed** ("All tests passed!"). Matches expectation.
- **Phase-11 files in isolation** (`test/unit/sync/`, `sync_queue_dao_test.dart`, `settings_screen_test.dart`) → **89 passed, 0 skipped, 0 failed**.
- **The 10 suite skips are confined to Phase-9 auth tests** (`auth_state_notifier_test.dart`, `auth_service_test.dart`) — confirmed via `grep -rln "skip:"`. **Zero skips in any Phase 11 test file. No NEW skips introduced.**
- **REST-only confirmed:** `grep -rn "cloud_firestore" lib/` → no matches (exit 1). The client talks to the backend only over `package:http`.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | After saving a trip, a sync queue entry is created and processed in the background when online | ✓ VERIFIED | Enqueue is transactional on every write path: tracking save `tracking_service_controller.dart:157-172` (`db.transaction` → `insertTrip` + `enqueueCreate`), edit `trip_management_providers.dart:68-82`, delete `:100-108`, manual entry `:146-162`, backfill `backfill_provider.dart:50`. Engine eager-mounted in `app.dart:46` (`..watch(syncEngineProvider)`) → `SyncEngine.start()` attaches `watchPending()` with a **rising-edge guard** (`sync_engine.dart:315-319`). Tests: `sync_engine_test.dart:538` "a new enqueue drains once; a markSynced shrink does NOT re-fire" (drives real `start()` with stubbed connectivity channel, asserts exactly 1 `syncTrips` call + 1 `SyncSynced`); `:235` success→markSynced+syncedAt; collapse `:131` (create+update→one entry), `:146` (create+delete→no create). |
| 2 | Sync retries up to 3 times with exponential backoff on failure | ✓ VERIFIED | `_handleFailure` (`sync_engine.dart:247-269`): retryable → `incrementRetry`, `markFailed` at `kSyncQueueMaxRetries` (=3, `constants.dart:36`), else `_scheduleBackoff`. `backoffDelay` = `base × 2^n` capped at `kSyncRetryMaxDelay` (`:98-103`; base 2s, cap 60s). Non-retryable 400 → `markFailed` immediately, retry budget untouched (`:252-257`). Classification in `ApiClient` (`api_client.dart:33-37`: 5xx/401 retryable, other 4xx not). Tests: `sync_engine_test.dart:254` (503→incrementRetry, stays pending), `:271` (retryCount 2→3 + markFailed), `:289` (400→markFailed immediately, retryCount 0, no backoff), `:337` (backoffDelay curve incl. cap), `:347` (trigger during window = 0 new calls). DAO: `sync_queue_dao_test.dart:94/105/120` (markFailed/resetFailed/countFailed). |
| 3 | User can trigger cloud restore from settings, which downloads all trips and inserts them into Drift (skipping duplicates) | ✓ VERIFIED | `RestoreController.restore()` (`restore_controller.dart:70-85`): `ApiClient.restoreTrips()` → `TripsDao.insertOrIgnoreTrips()` (single Drift `batch` with `InsertMode.insertOrIgnore`, pre/post `COUNT(*)` delta — `trips_dao.dart:121-133`). Settings "Restore from cloud" row wired in the **signed-in** `AccountRow` branch only (`settings_screen.dart:91-100`), renders restored count via `RestoreSuccess(count)` SnackBar (`restore_row.dart:46-53`, copy constants). Restore enqueues **zero** sync rows. Tests: `restore_controller_test.dart:108` (existing UUIDs skipped, not overwritten, only new counted), `:192/207` (count delta), `:228` (error→RestoreError, DB unchanged, no rethrow), `:244` ("restore enqueues ZERO sync_queue rows"); widget `settings_screen_test.dart:578` (tapping Restore → "Restored 1 trip" SnackBar), `:604` (error SnackBar). |
| 4 | Sync never blocks the UI — all network operations are background-only | ✓ VERIFIED | Engine off the UI path: eager-mount is a keepAlive `Provider` whose `start()` is `unawaited` (`sync_engine.dart:384`); all three triggers fire-and-forget via `unawaited(processPending())` (`:317,325,332`). **In-flight mutex claimed synchronously before any await** (`:111,119`) + backoff-window guard (`:115`). `processPending` catch-all never rethrows into UI (`:127-133`); `restore()` catches internally, never rethrows (`restore_controller.dart:80-84`). UI reads Drift only (CloudSyncRow reads `syncStatusProvider` + `pendingSyncCountProvider` derived from `watchPending`; no `await` in `build`). RestoreRow guards double-tap while `RestoreRestoring` (`restore_row.dart:31`). PII guard: failures map to sealed status, never `error.toString()`. Tests: `sync_engine_test.dart:321` (concurrent processPending runs queue exactly once), `:401` (offline→0 calls), `:416` (guest→0 calls/0 mutations), `:462` (never rethrows). |

**Score:** 4/4 truths verified in code + tests.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/sync/api_client.dart` | REST transport + error classification + restore envelope unwrap | ✓ VERIFIED | 401 refresh-retry (`:112-115`), 404 idempotent delete (`:153`), full `body.data.trips` unwrap with try-guard re-mapping all parse failures to `transport` (HR-01, `:175-192`). No token/PII in `toString`. |
| `lib/sync/sync_engine.dart` | Queue processor: collapse-per-tripId, batch, backoff, mutex, triggers | ✓ VERIFIED | Collapse `:147-180`, chunk at `kMaxSyncBatchTrips=1000` `:198`, failure branching `:247-269`, backoff window `:273-288`, 3 triggers + rising-edge guard `:303-334`, disposal `:337-342`. |
| `lib/sync/sync_status.dart` | Sealed SyncStatus + notifier | ✓ VERIFIED | 5 variants (Idle/Syncing/Synced/Offline/Failed(count)), `set()` writer. |
| `lib/sync/trip_serializer.dart` | Wire (de)serialization matching backend zod | ✓ VERIFIED | 12 keys, userId omitted, Z-suffixed UTC ISO, nullable routePolyline, direction enum — **byte-matches `validation.ts` tripSchema** (`:25-39`). |
| `lib/sync/restore_controller.dart` | Sealed restore flow, batch insert, count delta, no rethrow | ✓ VERIFIED | `restore()` `:70-85`, sealed RestoreState `:11-39`. |
| `lib/database/daos/sync_queue_dao.dart` | enqueue/markFailed/resetFailed/incrementRetry/countFailed | ✓ VERIFIED | All present `:28-144`; `countFailed` uses `COUNT(*)` aggregate (LR-02 fix). |
| `lib/database/daos/trips_dao.dart` | insertOrIgnoreTrips dedupe + count delta | ✓ VERIFIED | `:121-133` batch insertOrIgnore + COUNT delta. |
| `lib/app.dart` | Eager-mount engine | ✓ VERIFIED | `..watch(syncEngineProvider)` `:46`. |
| `lib/features/settings/.../cloud_sync_row.dart` | Live status + tap-to-retry | ✓ VERIFIED | Exhaustive switch, retryFailed on tap, copy constants `:33-52`. |
| `lib/features/settings/.../restore_row.dart` | Restore trigger + result SnackBar | ✓ VERIFIED | `:35-57`, copy constants, double-tap guard. |
| `lib/config/constants.dart` | Phase 11 constants | ✓ VERIFIED | Retry/backoff/path/copy constants `:36,716-788`; no hardcoded strings in new rows. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| Trip save (all paths) | sync_queue | `db.transaction` → enqueueCreate/Update/Delete | WIRED | Atomic with the trip write on every path. |
| app.dart | SyncEngine | `..watch(syncEngineProvider)` → `start()` | WIRED | watchPending subscription live from startup. |
| SyncEngine | ApiClient | `syncTrips`/`deleteTrip` | WIRED | Batched upserts + individual deletes. |
| ApiClient | Cloud Functions | `http` POST/DELETE/GET + Bearer token | WIRED | REST-only; token seam = live `currentUser.getIdToken`. |
| RestoreController | ApiClient → TripsDao | `restoreTrips` → `insertOrIgnoreTrips` | WIRED | Single batch, dedupe-by-UUID, no sync rows enqueued. |
| Settings rows | SyncEngine / RestoreController | `retryFailed()` / `restore()` | WIRED | Signed-in branch only. |
| TripSerializer.toJson | backend zod tripSchema | camelCase key set | WIRED | Exact match incl. userId-omitted. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full suite green | `flutter test` | 377 passed / 10 skipped / 0 failed | ✓ PASS |
| Static analysis clean | `flutter analyze` | 96 (87 info + 9 warning + 0 error), no new | ✓ PASS |
| Phase 11 tests in isolation | `flutter test test/unit/sync/ ...settings...` | 89 passed / 0 skipped / 0 failed | ✓ PASS |
| No cloud_firestore in client | `grep -rn cloud_firestore lib/` | no matches | ✓ PASS |
| Live end-to-end sync/restore | (requires device + backend) | — | ? SKIP → human |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SYNC-02 | 11-01, 11-02 | One-way background sync queue → Cloud Functions | ✓ SATISFIED | C1, C2, C4 evidence above. |
| SYNC-03 | 11-03 | Manual cloud restore with dedupe | ✓ SATISFIED | C3 evidence above. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none in `lib/sync/**` or new Settings widgets) | — | — | — | No TODO/FIXME/placeholder/empty-return stubs. Empty-array/null matches are sealed-state defaults or test fakes, not user-facing stubs. |

### Human Verification Required

These are **wake-up / device items**, NOT phase gaps — the corresponding logic is fully unit/widget-tested behind injected seams (MockClient, fake ApiClient, stubbed connectivity channel, in-memory Drift). They cannot be exercised in CI because they need a live token + deployed backend + real platform channels.

1. **End-to-end background sync against the LIVE backend** — signed-in user records/edits/deletes a trip on a device; confirm the row reaches Firestore and Settings settles on "All synced".
2. **Connectivity-restored + app-resume triggers on hardware** — offline→online and background→resume each drain pending rows once with no tight-loop.
3. **Cloud restore round-trip with real Firestore data** — "Restore from cloud" downloads + dedupes + shows "Restored N trips" / "Already up to date".

### Known Accepted Deviation (not a gap)

- **LR-03:** `SyncQueueDao.markSynced` stamps `syncedAt` with wall-clock `DateTime.now()` rather than the engine's injected clock. Documented and accepted as-is for v0.1 in `11-REVIEW-FIX.md` (threading a clock seam would change the frozen DAO public contract). Does not affect any success criterion.

### Gaps Summary

**No gaps.** All four ROADMAP success criteria are met with substantive, wired, data-flowing implementations and genuine assertions (no NEW skips, no weakened tests, no stubs). The serializer matches the deployed backend zod schema byte-for-byte; the client is strictly REST (no `cloud_firestore`); HR-01 restore-parse hardening is implemented and tested; the new Settings rows use copy constants exclusively. The only remaining work is on-device/live-backend confirmation, which is inherently outside the automated harness — recorded as human/device wake-up items rather than failures.

---

_Verified: 2026-06-01_
_Verifier: Claude (gsd-verifier)_
