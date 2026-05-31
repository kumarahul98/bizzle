# Phase 11: Sync Engine - Context

**Gathered:** 2026-06-01
**Status:** Ready for planning
**Mode:** `--auto` (gray areas auto-resolved to recommended/safe defaults; no interactive prompts)

<domain>
## Phase Boundary

Build the client-side sync engine that pushes Drift trips one-way to the Phase 10
Cloud Functions backend in the background, and a manual restore-from-cloud flow.
Drift stays the single source of truth; the network never blocks the UI.

**In scope:**
- `lib/sync/api_client.dart` — `http` client to the deployed endpoints, attaches a fresh Firebase ID token, 401-refresh-and-retry.
- `lib/sync/sync_engine.dart` — processes `sync_queue`; one-way client→server push; max-3 retries with exponential backoff; marks rows synced/failed; never throws into UI.
- Trigger wiring: post-save (queue already populated by trip-save transactions), connectivity-restored (`connectivity_plus`), app-resume (`WidgetsBindingObserver`/`AppLifecycleState`).
- Manual restore: `GET /trips/restore` → parse → insert into Drift, dedupe by trip UUID.
- Settings `_AccountSection` (signed-in branch): wire the deferred **Cloud sync status** row + **Restore from cloud** action row.
- New deps: `http`, `connectivity_plus`. New constants (base URL, backoff).
- `markFailed` on `SyncQueueDao`; unit tests for sync state transitions, backoff, serialization, restore dedupe.

**Out of scope:**
- Any `cloud_firestore` SDK in the Flutter client (forbidden — REST via `http` only).
- Server→client live sync / real-time listeners (one-way only; v0.1).
- Conflict-resolution/merge UI (client-authoritative — client always wins).
- Backend changes (Phase 10 is deployed and frozen).
- Sign-out/account-deletion data handling.
</domain>

<decisions>
## Implementation Decisions (auto-selected — recommended/safe defaults)

### Architecture & Riverpod
- **D-01:** New `lib/sync/` feature: `api_client.dart` (transport), `sync_engine.dart` (queue processor + triggers + status), and a small connectivity/lifecycle hook. Follow the codebase's **manual Riverpod 3.x `Provider`/`Notifier`** pattern (NO `@riverpod` codegen — analyzer conflict with drift_dev, as established project-wide). Providers: `apiClientProvider`, `syncEngineProvider` (a `Notifier<SyncStatus>` or a service held in a `Provider` that owns triggers), `restoreControllerProvider`.

### Transport / api_client (the Phase 10 contract)
- **D-02:** `http` package. Base URL constant `kApiBaseUrl = 'https://us-central1-travey-298a7.cloudfunctions.net/api'` in `lib/config/constants.dart`; endpoint paths `/trips/sync`, `/trips/restore`, `/trips/{tripId}`. Methods: `syncTrips(List<TripRow>)` → `POST /trips/sync`, `deleteTrip(String tripId)` → `DELETE /trips/{tripId}`, `restoreTrips()` → `GET /trips/restore`.
- **D-03 (token):** Attach `Authorization: Bearer <token>` using a **fresh** token from `FirebaseAuth.instance.currentUser?.getIdToken()` (FlutterFire auto-refreshes; this avoids the stale 1-hour cached token). If `currentUser` is null → not signed in → skip sync (no-op, not an error). On a **401** response, call `getIdToken(true)` (force refresh) and retry the request **once**; if still 401, treat as a failure for retry/backoff. (The Phase-9 secure-storage cached token under `kFirebaseIdTokenKey` is legacy/fallback; prefer live `getIdToken()`.)
- **D-04 (serialization contract — MUST match backend zod `tripSchema` exactly):** camelCase keys `{ id, startTime, endTime, durationSeconds, distanceMeters, routePolyline, direction, timeMovingSeconds, timeStuckSeconds, isManualEntry, createdAt, updatedAt }`; timestamps as **ISO-8601 UTC** via `dateTime.toUtc().toIso8601String()` (RFC3339 with `Z` — satisfies `z.string().datetime()`); `direction` is the stored `'to_office'`/`'to_home'` string; `routePolyline` nullable; **omit `userId`** (server forces it from the token). Non-nullable numeric fields (distanceMeters, durationSeconds, timeMoving/Stuck) always serialize as numbers (0 for manual entries) — never null.

### Sync engine behavior
- **D-05 (processing):** Pull pending rows oldest-first (`SyncQueueDao.getPending()`). **Batch** create/update: collect their tripIds, load live rows via `TripsDao.findById` (a create/update whose trip no longer exists locally → mark that queue row synced and skip), serialize, send as **one** `POST /trips/sync` (chunk at `kMaxSyncBatchTrips`=1000 if needed). Process **deletes** individually via `DELETE /trips/{tripId}` (the deployed endpoint takes the id in the path; the stored delete payload body is not needed). On success mark each processed row synced; on failure increment retry / mark failed (D-06).
- **D-06 (retry/backoff):** Reuse `kSyncQueueMaxRetries = 3`. On a failed attempt, `incrementRetry`; if `retryCount` reaches 3, `markFailed` (new DAO method; status `kSyncStatusFailed`) and surface via sync status. Between automatic retries use **exponential backoff** — base `kSyncRetryBaseDelay` (2s) × 2^(retryCount) capped at `kSyncRetryMaxDelay` (e.g. 60s) — scheduled with a `Timer`; the next connectivity/resume/post-save trigger may also re-attempt. Failed rows are retried again on a later successful trigger only if under the cap (terminal `failed` rows are not auto-retried; restore/resync can re-enqueue).
- **D-07 (triggers, never block UI):** SyncEngine is mounted eagerly in `app.dart`. It nudges `processPending()` on: (a) **post-save** — by listening to `SyncQueueDao.watchPending()` (trip-save transactions already enqueue); (b) **connectivity restored** — `Connectivity().onConnectivityChanged` transitioning to online; (c) **app resume** — `WidgetsBindingObserver.didChangeAppLifecycleState == resumed`. All processing is `async`/fire-and-forget; failures are caught and reflected in status, never thrown into widgets. UI reads Drift only.

### Restore flow
- **D-08:** `restoreTrips()` → parse `body.data.trips` (array of the client Trip JSON) → map each to `TripsCompanion` (parse ISO strings to `DateTime`) → insert into Drift with **dedupe by UUID** using `insertOnConflictUpdate`-free **insert-or-ignore** on the `id` primary key (skip existing). Restore does **NOT** enqueue sync rows (it's a download). Returns a count; the Settings action shows a result (e.g. snackbar "Restored N trips" / "Already up to date" / error). Manual-trigger only.

### Settings UI (wire the deferred rows)
- **D-09:** In `_AccountSection` **signed-in branch only** (`lib/features/settings/screens/settings_screen.dart`), add after `AccountRow`: a **Cloud sync status row** (driven by a provider over `SyncQueueDao.watchPending()` + engine `SyncStatus`: "All synced" / "Syncing…" / "N pending" / "Sync failed — tap to retry") and a **Restore from cloud** `SettingsRow` (onTap → restore with loading + result feedback). Guest branch unchanged. Reuse existing `SettingsRow`/`SettingsSection`/copy-constant patterns; add copy constants to `constants.dart` (no hardcoded labels).
- **D-10 (status model):** A `sealed`/enum `SyncStatus` (e.g. `idle`/`syncing`/`synced`/`offline`/`failed(count)`) exposed via provider — finite state per CLAUDE.md (no raw strings).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & goal
- `.planning/REQUIREMENTS.md` — SYNC-02 (one-way Drift→Firestore via queue + Cloud Functions), SYNC-03 (restore from cloud)
- `.planning/ROADMAP.md` — Phase 11 goal + 4 success criteria

### The Phase 10 ↔ 11 contract (MUST match exactly)
- `backend/functions/src/utils/validation.ts` — `tripSchema` / `syncTripsBody` (camelCase keys, ISO datetimes, direction enum, `routePolyline` max 100000 nullable, `userId` optional, `kMaxSyncBatchTrips=1000`)
- `backend/functions/src/types/trip.ts` — `Trip` type
- `backend/functions/src/handlers/restore-trips.ts` — response shape `{ statusCode, body: { data: { trips: Trip[] } } }`
- `.planning/phases/10-backend-infrastructure/10-DEPLOY.md` — live base URL `https://us-central1-travey-298a7.cloudfunctions.net/api`, endpoint paths, auth gate

### Existing client foundations to build on
- `lib/database/daos/sync_queue_dao.dart` — `enqueueCreate/Update/Delete`, `getPending`, `watchPending`, `markSynced`, `incrementRetry` (needs new `markFailed`)
- `lib/database/daos/trips_dao.dart` — `findById`, `insertTrip`, `watchAllSummaries`
- `lib/features/trips/providers/trip_management_providers.dart` — trip-save transactions that already enqueue sync rows
- `lib/features/auth/services/auth_service.dart` / `providers/auth_providers.dart` — `authStateProvider` (`AuthSignedIn`), Firebase token; `kFirebaseIdTokenKey`
- `lib/features/settings/screens/settings_screen.dart` — `_AccountSection` deferred rows (lines ~74-106)
- `lib/config/constants.dart` — `kSyncQueueMaxRetries=3`, `kSyncStatus*`, `kSyncAction*`, `kFirebaseIdTokenKey`, `kDefaultUserId`
- `CLAUDE.md` — Sync Strategy (client-authoritative one-way), Offline-First, Frontend rules (Drift-only UI reads, Riverpod, sealed state, no hardcoded values), Important Notes (never block UI, retries max 3 + backoff, no cloud_firestore in client)
- `.planning/phases/09-authentication/09-CONTEXT.md` — D-10/D-11 token + userId backfill
</canonical_refs>

<code_context>
## Reusable Assets & Integration Points
- `sync_queue` + `trips` Drift tables and DAOs are production-ready; the trip-save flow already enqueues create/update/delete in transactions — Phase 11 only adds the **processor + transport + triggers + restore + Settings rows**.
- Token: `FirebaseAuth.instance.currentUser?.getIdToken()` for a always-fresh bearer (auto-refresh); `getIdToken(true)` to force-refresh on 401.
- Riverpod: manual `Provider`/`Notifier` (see `lib/database/providers.dart`, `lib/features/auth/providers/auth_providers.dart`).
- Deps present: `flutter_riverpod`, `drift`, `firebase_auth`, `flutter_secure_storage`, `uuid`. **Add:** `http`, `connectivity_plus`.
</code_context>

<deferred>
## Reviewed / Considered
- **Todo `bug-manual-entry-missing-traffic-fields`** — surfaces here legitimately: the sync payload requires non-null numeric fields (`distanceMeters`, `timeMovingSeconds`, `timeStuckSeconds`, `durationSeconds`) per the backend zod schema. The Drift `trips` columns are non-nullable (default 0 for manual entries), so serialization is safe. **Planning must verify** manual-entry trips serialize 0 (not null) for these so they pass `tripSchema`; if the underlying todo is a UI-display bug it remains a separate `trips` fix (not folded into Phase 11 sync scope).
- **Cursor pagination for restore** — deferred (v0.1 restore returns all user trips; acceptable for reinstall scale; noted in Phase 10).

## Auto-Selected Gray Areas (audit log)
`[--auto] Selected all gray areas: token strategy, serialization contract, batching, retry/backoff, triggers, restore dedupe, Settings status UX.`
- `[auto] Token — Q: "Cached secure-storage token vs live getIdToken()?" → Selected: "live currentUser.getIdToken() + getIdToken(true) on 401" (safe default; avoids stale-token failures)`
- `[auto] Batching — Q: "Per-row POST vs one batched /trips/sync?" → Selected: "batch create/update into one POST (chunk ≤1000), deletes individually" (recommended; matches batch endpoint)`
- `[auto] Backoff — Q: "Fixed vs exponential?" → Selected: "exponential 2s×2^n capped 60s, max 3 retries then failed" (matches CLAUDE.md)`
- `[auto] Triggers — Q: "Which?" → Selected: "watchPending(post-save) + connectivity-restored + app-resume, fire-and-forget" (matches success criteria 1 & 4)`
- `[auto] Restore dedupe — Q: "How dedupe?" → Selected: "insert-or-ignore on UUID PK" (recommended; simplest correct)`
- `[auto] Status UX — Q: "Sync row content?" → Selected: "sealed SyncStatus → All synced / Syncing / N pending / Failed-tap-retry" (recommended)`
</deferred>
</content>
