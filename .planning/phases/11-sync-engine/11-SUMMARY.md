# Phase 11: Sync Engine — Execution Summary

**Status:** ✅ COMPLETE (verified PASS, 4/4 criteria — code+tests; live device E2E pending)
**Branch:** gsd/phase-10-11-backend-sync
**Date:** 2026-06-01

> Note: an earlier session mistakenly reported this phase complete before it was executed (its subagents hit a session limit). That was corrected (commit `08e0207`); the phase was then **genuinely executed** in a later session. This file reflects the real, verified state.

## What was built (`lib/sync/` + Settings)
- **`api_client.dart`** — `http` `ApiClient` → deployed backend (`kApiBaseUrl` = `https://us-central1-travey-298a7.cloudfunctions.net/api`, injectable for tests). Bearer from `currentUser.getIdToken()`; 401→`getIdToken(true)`→retry once (refresh/network mapped to retryable; token never logged). `SyncException` named ctors `.http(code)`/`.transport()`/`.notSignedIn()` deriving `retryable` (5xx/network→retryable, 4xx→non-retryable). DELETE 404→success (idempotent). `restoreTrips()` unwraps full `body.data.trips` and re-maps JSON parse/shape errors to `SyncException.transport` (HR-01 fix).
- **`trip_serializer.dart`** — `TripSerializer.toJson/fromJson` byte-matching the backend zod `tripSchema` (camelCase, ISO-8601 `Z`, 0-not-null numerics, `userId` omitted).
- **`sync_status.dart`** — sealed `SyncStatus` (SyncIdle/Syncing/Synced/Offline/Failed(count)) + `SyncStatusNotifier` + `syncStatusProvider`.
- **`sync_engine.dart`** — `SyncEngine` (plain `Provider`, eager-mounted in `app.dart`): collapse-per-tripId batching (create+update→one upsert; create-then-delete→no orphan; delete-only), batched `syncTrips` (≤1000), individual deletes; retryable→incrementRetry+exp backoff (`base×2^n` cap, `markFailed` at 3), non-retryable→immediate `markFailed`; in-flight mutex (claimed synchronously) + `_backoffUntil` guard; triggers: rising-edge `watchPending()` (post-save, no self-loop), connectivity rising-edge (seeded), `AppLifecycleListener.onResume`; gated online && signed-in; fire-and-forget; `retryFailed()`; full `dispose`.
- **`restore_controller.dart`** — `ApiClient.restoreTrips()` → single Drift `batch(insertAll, insertOrIgnore)` dedupe-by-UUID, COUNT-delta restored count; sealed `RestoreState`; enqueues no sync rows.
- **DAOs** — `SyncQueueDao` +`getPending/markFailed/resetFailed/countFailed`; `TripsDao` +`insertOrIgnoreTrips` (batch) +`count`.
- **Settings** `_AccountSection` (signed-in only) — `cloud_sync_row.dart` (All synced / Syncing… / N pending / Sync failed→`retryFailed()`) + `restore_row.dart` (Restore from cloud → SnackBar result, `mounted`-guarded). Guest branch unchanged. Copy in constants.
- **deps:** `http: ^1.6.0`, `connectivity_plus: ^7.1.1`.

## Success criteria → proof (verified PASS)
1. Save → queue entry → background processing when online — ✅ (existing trip-save txns enqueue; eager-mount + rising-edge watchPending; `sync_engine_test.dart`)
2. Retry ≤3 with exponential backoff — ✅ (backoff math + 3-strike + 400 fast-fail tests)
3. Restore from settings, dedupe by UUID — ✅ (`restore_controller` + `insertOrIgnoreTrips` + COUNT-delta + "no sync rows enqueued" test + Settings row)
4. Never blocks UI — ✅ (async fire-and-forget, no await in build, sync mutex + backoff guard, Drift-only reads)

## Quality gates
- Gemini cross-AI plan convergence: 3 HIGH → 0 HIGH over 2 iterations (queue-collapse, poison-pill error classification, symbol drift). See `11-CONVERGENCE`/`11-REVIEWS`.
- Code review: 0 Critical / 1 High (restore parse-error escape) fixed + mediums (hardcoded 'Account', watchPending redundant-drain guard, COUNT(*)). See `11-REVIEW`/`11-REVIEW-FIX`.
- `flutter analyze`: clean (96 baseline, **0 new**). `flutter test`: **377 passed / 0 failed / 10 pre-existing skips (0 new)**. `grep cloud_firestore lib/`: none (REST-only). Independently re-run by the verifier.

## Human/device verification (wake-up items)
- Live end-to-end against the deployed backend with a signed-in Google user on a device: sign in → record/edit/delete a trip → confirm Firestore `trips` docs; airplane-mode → reconnect/resume → confirm drain; fresh-install → Restore from cloud → trips reappear (dedupe on 2nd restore). Logic is fully unit/widget-tested with injected seams; backend deployed + emulator-proven; contract matches.
- Accepted deviation (LR-03): `syncedAt` uses wall-clock in the DAO (no clock seam on `markSynced`); does not affect any criterion.
</content>
