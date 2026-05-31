# Phase 11: Sync Engine (client-side) - Research

**Researched:** 2026-06-01
**Domain:** Offline-first one-way sync — Flutter `http` transport, `connectivity_plus`, Firebase ID-token auth, Riverpod 3.x long-lived service, Drift restore dedupe
**Confidence:** HIGH (all package versions/APIs verified against pub.dev + local install; codebase patterns read directly)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** New `lib/sync/` feature: `api_client.dart` (transport), `sync_engine.dart` (queue processor + triggers + status), small connectivity/lifecycle hook. **Manual Riverpod 3.x `Provider`/`Notifier`** (NO `@riverpod` codegen — analyzer conflict with drift_dev, project-wide). Providers: `apiClientProvider`, `syncEngineProvider`, `restoreControllerProvider`.
- **D-02:** `http` package. Base URL constant `kApiBaseUrl = 'https://api-rdj4i7kgmq-uc.a.run.app'` in `constants.dart`; paths `/trips/sync`, `/trips/restore`, `/trips/{tripId}`. `syncTrips(List<TripRow>)` → `POST /trips/sync`, `deleteTrip(String)` → `DELETE /trips/{tripId}`, `restoreTrips()` → `GET /trips/restore`.
- **D-03 (token):** `Authorization: Bearer <token>` from a **fresh** `FirebaseAuth.instance.currentUser?.getIdToken()` (auto-refresh). `currentUser == null` → skip sync (no-op, not error). On **401**, call `getIdToken(true)` (force refresh) + retry **once**; still 401 → failure for retry/backoff. Phase-9 secure-storage token is legacy/fallback; prefer live `getIdToken()`.
- **D-04 (serialization — MUST match backend zod `tripSchema` exactly):** camelCase keys `{ id, startTime, endTime, durationSeconds, distanceMeters, routePolyline, direction, timeMovingSeconds, timeStuckSeconds, isManualEntry, createdAt, updatedAt }`; timestamps via `dateTime.toUtc().toIso8601String()` (RFC3339 `Z`); `direction` = stored `'to_office'`/`'to_home'`; `routePolyline` nullable; **omit `userId`**; non-nullable numerics always numbers (0 for manual entries), never null.
- **D-05 (processing):** Pull pending oldest-first (`getPending()`). **Batch** create/update: collect tripIds, load live rows via `TripsDao.findById` (trip gone locally → mark that queue row synced + skip), serialize, send **one** `POST /trips/sync` (chunk at `kMaxSyncBatchTrips`=1000). Process **deletes** individually via `DELETE /trips/{tripId}`. Success → mark each row synced; failure → increment retry / mark failed.
- **D-06 (retry/backoff):** Reuse `kSyncQueueMaxRetries = 3`. Failed attempt → `incrementRetry`; `retryCount` reaches 3 → `markFailed` (new DAO method; `kSyncStatusFailed`) + surface in status. Exponential backoff: base `kSyncRetryBaseDelay` (2s) × 2^(retryCount) capped at `kSyncRetryMaxDelay` (60s), scheduled via `Timer`. Terminal `failed` rows not auto-retried; restore/resync can re-enqueue.
- **D-07 (triggers, never block UI):** SyncEngine mounted eagerly in `app.dart`. Nudge `processPending()` on: (a) **post-save** via `SyncQueueDao.watchPending()`; (b) **connectivity restored** via `Connectivity().onConnectivityChanged` → online; (c) **app resume** via lifecycle `resumed`. All async/fire-and-forget; failures caught + reflected in status, never thrown into widgets. UI reads Drift only.
- **D-08 (restore):** `restoreTrips()` → parse `body.data.trips` → map each to `TripsCompanion` (parse ISO → `DateTime`) → insert into Drift with **insert-or-ignore** on `id` PK (skip existing). Restore does **NOT** enqueue sync rows. Returns a count; Settings shows result. Manual-trigger only.
- **D-09 (Settings UI):** In `_AccountSection` **signed-in branch only**, after `AccountRow`: a **Cloud sync status row** (provider over `watchPending()` + `SyncStatus`) and a **Restore from cloud** `SettingsRow`. Guest branch unchanged. Reuse `SettingsRow`/`SettingsSection`/copy constants; add copy to `constants.dart`.
- **D-10 (status model):** A `sealed`/enum `SyncStatus` (`idle`/`syncing`/`synced`/`offline`/`failed(count)`) via provider — finite state, no raw strings.

### Claude's Discretion
- Exact internal file split inside `lib/sync/` (e.g. whether the lifecycle/connectivity hook is one file or two), the precise sealed-class variant set for `SyncStatus`, the names of the new backoff/base-URL constants, and the Settings status-row copy strings — all left to the planner within the D-01..D-10 envelope.

### Deferred Ideas (OUT OF SCOPE)
- Any `cloud_firestore` SDK in the Flutter client (forbidden — REST via `http` only).
- Server→client live sync / real-time listeners (one-way only, v0.1).
- Conflict-resolution/merge UI (client-authoritative — client always wins).
- Backend changes (Phase 10 deployed and frozen).
- Sign-out / account-deletion data handling.
- Cursor pagination for restore (returns all user trips; acceptable for reinstall scale).
- The `bug-manual-entry-missing-traffic-fields` todo — if it's a UI-display bug it stays a separate `trips` fix; Phase 11 only **verifies** manual-entry trips serialize 0 (not null) so they pass `tripSchema`.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SYNC-02 | One-way Drift→Firestore via queue + Cloud Functions | `api_client` transport (§Integration A) + `sync_engine` processPending (§Integration C); contract matched to `tripSchema` (§Integration B) |
| SYNC-03 | Restore from cloud | `restoreTrips()` + insert-or-ignore dedupe (§Integration E); Settings wiring (§Integration F) |
| ROADMAP Phase 11 SC 1 | Trips sync automatically in background | triggers via `watchPending` + connectivity + lifecycle (§Integration D) |
| ROADMAP Phase 11 SC 4 | Sync resumes on connectivity restore / app resume | connectivity transition detection + `AppLifecycleListener.onResume` (§Integration D) |
</phase_requirements>

## Summary

Phase 11 adds the **processor + transport + triggers + restore + Settings rows** on top of an already-complete persistence layer. The `sync_queue`/`trips` Drift tables, DAOs, and the trip-save transactions that enqueue create/update/delete rows are production-ready. Nothing in the backend changes — Phase 10 is deployed at `https://api-rdj4i7kgmq-uc.a.run.app` and the client must conform to the `tripSchema` zod contract byte-for-byte.

The work is concentrated in three new files under `lib/sync/`: a thin typed `ApiClient` over `package:http` that attaches a fresh Firebase ID token and does a single 401-force-refresh-retry; a `SyncEngine` `Notifier<SyncStatus>` that drains the pending queue (batched create/update via one `POST /trips/sync`, deletes individually via `DELETE`), applies exponential backoff with a 3-retry cap and an **in-flight guard**, and exposes a sealed `SyncStatus`; and the trigger wiring (a `watchPending` subscription, a `connectivity_plus` online-transition listener, and an `AppLifecycleListener.onResume`). Restore is a separate manual-only controller that downloads `/trips/restore` and inserts with `InsertMode.insertOrIgnore` on the UUID primary key. The Settings `_AccountSection` signed-in branch gains a live sync-status row and a restore action row.

All eight implementation files follow the **manual Riverpod 3.x `Provider`/`NotifierProvider`** idiom established project-wide (codegen is blocked by an analyzer-major conflict between `drift_dev` and `riverpod_generator`). Every dependency is `ref.watch`-injected so the entire engine is unit-testable with an in-memory Drift DB (`NativeDatabase.memory()`) and `package:http/testing.dart`'s `MockClient` — **no new test packages are required**; the repo already tests exclusively with in-memory Drift + Riverpod overrides and uses no mockito/mocktail.

**Primary recommendation:** Add `http: ^1.6.0` and `connectivity_plus: ^7.1.1`. Build `ApiClient` (http + token), a `TripJson` serializer matched to `tripSchema`, `SyncEngine` (`Notifier<SyncStatus>` with in-flight mutex + Timer backoff), trigger wiring via `AppLifecycleListener` + `onConnectivityChanged` (note: `List<ConnectivityResult>` in v7), and a `RestoreController` using `InsertMode.insertOrIgnore`. Test with `MockClient` + in-memory Drift — zero new dev-deps.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| HTTP transport to Cloud Functions | API/Backend client (`ApiClient`) | — | Single seam that owns base URL, headers, status-code → result mapping; never touched by UI |
| Fresh ID-token retrieval | Auth (FlutterFire `currentUser.getIdToken`) | `ApiClient` (consumer) | FlutterFire owns refresh; `ApiClient` only attaches and force-refreshes on 401 |
| Queue draining / retry / backoff | Sync engine (`SyncEngine` Notifier) | `SyncQueueDao` (persistence) | Business logic = ordering, batching, retry cap, in-flight guard; DAO only persists state transitions |
| Trigger detection (online / resume / post-save) | Sync engine triggers | `connectivity_plus`, `AppLifecycleListener`, Drift stream | Engine subscribes; platform/Drift report events. Engine decides whether to act |
| Restore download + dedupe | Restore controller (`RestoreController`) | `TripsDao` / Drift `insertOrIgnore` | Separate manual flow; not part of the outbound queue; dedupe is a DB-level concern |
| Sync status presentation | Riverpod provider → Settings widget | Drift `watchPending` stream | UI reads a derived sealed `SyncStatus`; never reads network |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| http | ^1.6.0 | REST transport to the 3 Cloud Functions endpoints | `[VERIFIED: pub.dev]` Official Dart team package. CLAUDE.md mandates `http` (not Dio) for "3 simple REST endpoints". Ships `package:http/testing.dart` `MockClient` for tests. |
| connectivity_plus | ^7.1.1 | Detect online/offline + offline→online transition | `[VERIFIED: pub.dev]` plus.fluttercommunity maintained. `onConnectivityChanged` fires on interface change. **v7 returns `List<ConnectivityResult>`** (multi-interface), not a single value. |
| firebase_auth | ^6.5.1 (already pinned) | Fresh ID token via `currentUser?.getIdToken([force])` | `[VERIFIED: pubspec.yaml + pub.dev]` Already a dependency. `getIdToken([bool forceRefresh = false])` → `Future<String?>`. |
| drift | ^2.32.1 (already pinned) | `InsertMode.insertOrIgnore` restore dedupe; in-memory test DB | `[VERIFIED: pubspec.yaml + pub.dev]` `InsertMode.insertOrIgnore` exists ("Like insert, but failures will be ignored"). `Batch.insertAll(table, rows, mode:)` for bulk restore. |
| flutter_riverpod | ^3.3.1 (already pinned) | Manual `Provider`/`NotifierProvider` for the long-lived engine | `[VERIFIED: pubspec.yaml]` Bare `Provider`/`NotifierProvider` = `keepAlive: true` semantics (established in `lib/database/providers.dart`). |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `package:http/testing.dart` (part of `http`) | n/a | `MockClient` for unit-testing `ApiClient` without a real backend | `[VERIFIED: pub.dev]` `MockClient((Request req) async => Response(body, statusCode))` |
| `dart:convert` (SDK) | n/a | `jsonEncode` / `jsonDecode` for body (de)serialization | Built-in; no dep |
| `dart:async` Timer (SDK) | n/a | Exponential-backoff scheduling | Built-in; matches `Timer` usage already in codebase |
| `package:flutter/widgets.dart` `AppLifecycleListener` | n/a (Flutter framework) | Modern app-resume callback (`onResume`) | `[VERIFIED: api.flutter.dev]` Implements `WidgetsBindingObserver`; has `onResume`/`onStateChange`; requires `dispose()` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `http` | `dio` | `[CITED: CLAUDE.md]` Dio's interceptors/retry are unnecessary for 3 JSON endpoints; CLAUDE.md explicitly says use `http`. |
| `AppLifecycleListener` | raw `WidgetsBindingObserver.didChangeAppLifecycleState` | Both work; `AppLifecycleListener` (Flutter 3.13+) is the modern, self-disposing wrapper with a typed `onResume`. CONTEXT permits either. `[ASSUMED]` codebase has no existing lifecycle observer to copy — see Assumptions A1. |
| `InsertMode.insertOrIgnore` | `into(trips).insert(c, onConflict: DoNothing())` | Equivalent for "skip if PK exists". `InsertMode.insertOrIgnore` is terser and matches D-08 "insert-or-ignore". |
| `MockClient` (http/testing) | `mockito`/`mocktail` | `[VERIFIED: pubspec.yaml]` Neither mockito nor mocktail is a dev-dep; the repo mocks nothing — it uses real in-memory Drift + Riverpod overrides + `MockClient`. Adding a mock framework would break convention. |

**Installation:**
```bash
flutter pub add http connectivity_plus
```
(No dev-dependency additions — `MockClient` ships inside `http`, in-memory Drift via the already-present `drift`.)

**Version verification (run before locking the plan):**
```bash
flutter pub add http connectivity_plus   # resolves to latest compatible
flutter pub deps | grep -E "http |connectivity_plus"
```
Verified values as of 2026-06-01: `http 1.6.0` (pub.dev, ~6 months old, MockClient confirmed), `connectivity_plus 7.1.1` (pub.dev, ~51 days old, requires Dart ≥3.3.0 — satisfied by SDK ^3.11.4). Both compatible with Flutter 3.41.6 / Dart 3.11.4.

## Architecture Patterns

### System Architecture Diagram

```
                    ┌──────────────── TRIGGERS (fire-and-forget) ─────────────────┐
                    │                                                              │
 trip-save tx ──────┤  SyncQueueDao.watchPending()  ──┐                            │
 (Phase 1-3, done)  │                                 │                            │
                    │  Connectivity().onConnectivity- ─┤                           │
 OS network change ─┤  Changed → online transition    │   nudge processPending()  │
                    │                                 │                            │
 app foregrounded ──┤  AppLifecycleListener.onResume ─┘                            │
                    └──────────────────────────────────────────────────────────────┘
                                            │
                                            ▼
                          ┌─────────────────────────────────┐
                          │  SyncEngine (Notifier<SyncStatus>)│
                          │  • in-flight guard (mutex bool)   │   state = SyncStatus
                          │  • getPending() oldest-first      │ ───────────────────► Settings
                          │  • split create/update vs delete  │   (idle/syncing/    sync-status row
                          └───────────────┬─────────────────┘    synced/offline/    (watchPending +
                                          │                       failed(n))         engine status)
              ┌───────────────────────────┼───────────────────────────┐
              ▼ (create/update batch)      ▼ (each delete)             │
    TripsDao.findById(id)            ApiClient.deleteTrip(id)          │
    → gone? markSynced+skip          → DELETE /trips/{id}              │
    → TripJson.toMap()                                                 │
    → ApiClient.syncTrips([...])                                       │
      → POST /trips/sync                                               │
              │                                                        │
              ▼                                                        ▼
    ┌──────────────────────────────────────────────────────────────────────┐
    │  ApiClient (http.Client)                                              │
    │  1. token = FirebaseAuth.instance.currentUser?.getIdToken()          │
    │     null → throw NotSignedIn → engine no-ops                         │
    │  2. send with Authorization: Bearer <token>, JSON body, timeout      │
    │  3. 401 → getIdToken(true) → retry ONCE → still 401 → failure        │
    │  4. 2xx → SyncResult.ok  |  4xx/5xx/timeout → SyncResult.failure     │
    └──────────────────────────────────────────────────────────────────────┘
              │ success                          │ failure
              ▼                                   ▼
    SyncQueueDao.markSynced(id)        incrementRetry(id) →
                                       retryCount==3 ? markFailed(id)
                                       : schedule Timer(backoff) → processPending()

  ──────────────── RESTORE (separate manual flow, download-only) ────────────────
   Settings "Restore from cloud" tap
     → RestoreController.restore()
       → ApiClient.restoreTrips()  → GET /trips/restore → body.data.trips[]
       → map each → TripsCompanion (ISO → DateTime.parse().toUtc())
       → batch.insertAll(trips, companions, mode: InsertMode.insertOrIgnore)  // dedupe by UUID PK
       → returns inserted count → snackbar "Restored N trips" / "Already up to date"
     (does NOT enqueue sync rows)
```

### Recommended Project Structure
```
lib/sync/
├── api_client.dart          # ApiClient (http) + SyncResult + NotSignedInException; apiClientProvider
├── trip_json.dart           # TripRow → Map<String,Object?> serializer (matches tripSchema); JSON → TripsCompanion
├── sync_status.dart         # sealed SyncStatus (idle/syncing/synced/offline/failed(count))
├── sync_engine.dart         # SyncEngine extends Notifier<SyncStatus>; triggers + processPending + backoff + in-flight guard; syncEngineProvider
└── restore_controller.dart  # RestoreController (download + insertOrIgnore); restoreControllerProvider + restore result type

lib/config/constants.dart    # + kApiBaseUrl, path segments, kSyncRetryBaseDelay, kSyncRetryMaxDelay, kSyncHttpTimeout, copy constants
lib/database/daos/sync_queue_dao.dart  # + markFailed(int id)
lib/features/settings/screens/settings_screen.dart  # _AccountSection signed-in branch: + sync-status row + restore row
lib/app.dart                 # eager-mount syncEngineProvider (ref.watch) like directionBackfillProvider
```

### Pattern 1: Manual long-lived `Notifier` that subscribes in `build()` and disposes in `ref.onDispose`
**What:** The engine owns a `watchPending` subscription, a connectivity subscription, an `AppLifecycleListener`, and a backoff `Timer`. All are created in `build()` and torn down in `ref.onDispose`. State is a sealed `SyncStatus`.
**When to use:** This is the exact pattern of `AuthStateNotifier` and `TrackingNotifier` already in the repo — subscribe in `build()`, `state = ...` on each event, `ref.onDispose(() => ...cancel())`.
**Example:**
```dart
// Source: codebase pattern — lib/features/auth/providers/auth_providers.dart
//         + lib/features/tracking/providers/tracking_providers.dart (verified)
final NotifierProvider<SyncEngine, SyncStatus> syncEngineProvider =
    NotifierProvider<SyncEngine, SyncStatus>(
  SyncEngine.new,
  name: 'syncEngineProvider',
); // bare NotifierProvider => keepAlive:true (do NOT use .autoDispose)
```

### Pattern 2: Eager mount in `app.dart`
**What:** `app.dart` already does `ref.watch(directionBackfillProvider)` to fire a one-shot startup job. Mount the engine the same way so its triggers attach at app start.
**Example:**
```dart
// Source: codebase — lib/app.dart line 37 (directionBackfillProvider) (verified)
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.watch(directionBackfillProvider); // existing
  ref.watch(syncEngineProvider);        // NEW: eager-mount the sync engine
  // ...
}
```

### Anti-Patterns to Avoid
- **`StateNotifier`:** `[CITED: auth_providers.dart]` `grep "StateNotifier" lib/` returns zero hits — repo uses Riverpod 3.x `Notifier<T>`. Never introduce `StateNotifier`.
- **`@riverpod` codegen:** `[CITED: lib/database/providers.dart]` Blocked — `riverpod_generator` pins `analyzer ^9`, `drift_dev 2.32.1` pins `analyzer ^10`. Use manual providers.
- **`.autoDispose`:** Would close the engine on widget disposal and drop the in-flight queue. Use bare `NotifierProvider`.
- **`cloud_firestore` in the client:** `[CITED: CLAUDE.md]` Forbidden. REST via `http` only.
- **Reading network from UI:** Settings reads `watchPending()` (Drift) + engine `SyncStatus`, never the network directly.
- **`DateTime.now()` (local) in payloads:** Must be `.toUtc().toIso8601String()` or zod `z.string().datetime()` rejects non-`Z` offsets — see Pitfall 1.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP request/response, encoding | Custom socket/HttpClient wrapper | `package:http` `Client.post/get/delete` | Handles headers, body encoding, status, redirects |
| Mocking HTTP in tests | Hand-rolled fake `Client` | `MockClient` from `package:http/testing.dart` | First-party; `MockClient((req) async => Response(...))` |
| Connectivity transitions | Polling / platform channel | `connectivity_plus` `onConnectivityChanged` | Cross-platform interface-change stream |
| Restore dedupe by PK | `SELECT` then conditional insert per row | `InsertMode.insertOrIgnore` / `Batch.insertAll(mode:)` | Atomic, single round-trip, no race |
| ID-token refresh | Manual JWT exp parsing / refresh | `currentUser.getIdToken()` (+ `(true)` on 401) | FlutterFire auto-refreshes; force-refresh on demand |
| App-resume detection | Manual `WidgetsBinding` plumbing | `AppLifecycleListener(onResume: ...)` | Self-disposing, typed callbacks |
| Test DB | Mocked DAOs | `AppDatabase(NativeDatabase.memory())` | Real schema, real queries, real streams |

**Key insight:** Every "hard" part of this phase already has a first-party solution that the codebase either already uses (in-memory Drift, Riverpod overrides) or that ships inside a dependency you're adding (MockClient inside http). The only genuinely custom logic is the **batching + retry/backoff + in-flight-guard orchestration** in `SyncEngine` — that is the real work; everything around it is glue.

## Runtime State Inventory

> Phase 11 is **additive** (new files + two small edits), not a rename/refactor. This section is included only to confirm no hidden runtime state is affected.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Drift `sync_queue` rows already enqueued by trip-save transactions (create/update/delete) are waiting to be drained. `trips` rows are the payload source. | None — engine consumes them; no migration. The new `markFailed` only writes the existing `status` column to `kSyncStatusFailed`. |
| Live service config | Cloud Functions deployed + frozen at `https://api-rdj4i7kgmq-uc.a.run.app` (Phase 10). | None — client conforms to the deployed contract; no backend change. |
| OS-registered state | None — no new background service, no new notification channel, no Task Scheduler/launchd. Triggers run in the UI isolate. | None — verified: triggers are `watchPending`/connectivity/lifecycle in-process. |
| Secrets/env vars | Firebase ID token retrieved live via `getIdToken()`; the legacy cached token under `kFirebaseIdTokenKey` (secure storage) is fallback only. `kGoogleServerClientId` unchanged. | None — no new secret. Do NOT log the token (Pitfall 6). |
| Build artifacts | `sync_queue_dao.g.dart` regenerates after adding `markFailed` (no schema change — `markFailed` is a method, not a column). New `lib/sync/*` files have no codegen. | Run `dart run build_runner build` after editing the DAO. No `schemaVersion` bump. |

**Nothing found requiring migration:** confirmed — Phase 11 adds no Drift columns and bumps no `schemaVersion`.

## Common Pitfalls

### Pitfall 1: ISO-8601 serialization that fails `z.string().datetime()`
**What goes wrong:** zod's `z.string().datetime()` (no `offset:true`) accepts only UTC `Z`-suffixed RFC3339 (`2026-06-01T08:30:00.000Z`). `DateTime.toIso8601String()` on a **local** `DateTime` emits an offset like `+05:30` (rejected) or, worse, no suffix.
**Why it happens:** Drift stores `DateTime` and may hand back local-kind values; calling `.toIso8601String()` directly serializes the offset.
**How to avoid:** Always `dateTime.toUtc().toIso8601String()` in the serializer (D-04). Drift columns are documented as stored in UTC (`trips_table.dart`), but `.toUtc()` is idempotent and a cheap guarantee. Unit-test that the emitted string ends with `Z` and `DateTime.parse()` round-trips.
**Warning signs:** Backend returns `400` with a zod validation error on `startTime`/`endTime`/`createdAt`/`updatedAt`.

### Pitfall 2: Double-processing the queue under concurrent triggers
**What goes wrong:** post-save, connectivity-restored, and app-resume can all fire within the same second, launching three overlapping `processPending()` runs that double-POST the same trips and double-increment retry counters.
**Why it happens:** All three triggers call the same async method; Dart's single-thread event loop interleaves the `await` points.
**How to avoid:** An **in-flight guard** — a `bool _running` (or a `Completer`/`Future?` mutex) checked at the top of `processPending()`. If already running, set a "re-run requested" flag and return; when the current run finishes, if the flag is set, run once more. This is the same defensive discipline as `TrackingNotifier.stop()`'s synchronous-before-await state flip.
**Warning signs:** Duplicate `POST /trips/sync` in logs; `retryCount` jumping by 2+; `markFailed` reached faster than 3 real failures.

### Pitfall 3: `connectivity_plus` v7 return type is a **List**
**What goes wrong:** Code written against older majors expects `ConnectivityResult` (single); v7 emits `List<ConnectivityResult>`. A `result == ConnectivityResult.none` check won't compile / is wrong.
**Why it happens:** v7 reports all active interfaces simultaneously.
**How to avoid:** `[VERIFIED: pub.dev]` Treat "online" as `results.any((r) => r != ConnectivityResult.none)` (equivalently `!results.contains(ConnectivityResult.none)` when the list is non-empty). Detect an **offline→online transition** by comparing the previous "online" bool to the new one and only nudging on `false→true`.
**Warning signs:** Compile error `List<ConnectivityResult> can't be ConnectivityResult`; sync never triggers on reconnect.

### Pitfall 4: `connectivity_plus` reports interface, not reachability (false positives)
**What goes wrong:** `onConnectivityChanged` says "wifi" the instant the interface attaches, but the gateway/DNS/Cloud Functions may not be reachable yet (captive portals, airplane-mode→wifi handoff).
**Why it happens:** The plugin reflects the OS network interface state, not end-to-end reachability — documented limitation.
**How to avoid:** Never treat connectivity as a guarantee. The engine should **attempt** the sync on an online transition; a failure (timeout/non-2xx) just flows into the normal retry/backoff path. Do not gate writes on connectivity being "true" — gate only the *trigger nudge*. The real source of truth is the HTTP result.
**Warning signs:** Sync "succeeds" trigger-wise but every request times out right after reconnect; works on retry.

### Pitfall 5: Token null when guest (or session not yet restored)
**What goes wrong:** `FirebaseAuth.instance.currentUser` is `null` for guests and momentarily during cold-start session restore. Calling `getIdToken()` on null throws.
**Why it happens:** Guests use the app fully offline (client-authoritative); auth is optional.
**How to avoid:** `currentUser == null` → the `ApiClient` throws a typed `NotSignedInException` (or returns a `SyncResult.notSignedIn`); the engine treats it as a **no-op**, sets `SyncStatus` to `idle`/`offline`-equivalent, and does NOT increment retry or mark failed (D-03). Pending rows simply wait for sign-in. Note `app.dart` shows `MainShell` for both `AuthGuest` and `AuthSignedIn`, so the engine mounts in both states — it must handle null gracefully.
**Warning signs:** Unhandled exception in the engine for guest users; retry counters climbing while signed out.

### Pitfall 6: Logging the token / PII
**What goes wrong:** Debugging the 401-retry path tempts logging the token or full request.
**Why it happens:** Natural debugging instinct.
**How to avoid:** `[CITED: auth_service.dart]` Security invariant already in the repo — the Firebase ID token is NEVER passed to `print`/`debugPrint`/`log` in any format. Mirror that in `ApiClient`. Log status codes and queue ids only, never headers/body containing the token or user PII.
**Warning signs:** `flutter analyze` / review flags `print` near token; token visible in logs.

### Pitfall 7: Manual-entry trips serializing null numerics
**What goes wrong:** `tripSchema` requires `distanceMeters`/`durationSeconds`/`timeMovingSeconds`/`timeStuckSeconds` as non-null numbers. A manual entry that left these null would 400.
**Why it happens:** The `bug-manual-entry-missing-traffic-fields` todo flags a possible UI/display gap.
**How to avoid:** `[VERIFIED: trips_table.dart]` All four columns are **non-nullable** `integer()`/`real()` — Drift guarantees a value (manual entries store 0). The serializer reads `TripRow` non-nullable fields, so it physically cannot emit null. Add a unit test inserting a manual-entry trip and asserting the serialized map has numeric (0) values. If a separate UI-display bug exists, it stays out of Phase 11 scope (Deferred).
**Warning signs:** 400 on `POST /trips/sync` only for manual-entry trips.

### Pitfall 8: Blocking the UI isolate
**What goes wrong:** Awaiting sync inside a widget build or a tap handler that the UI waits on.
**How to avoid:** `[CITED: CLAUDE.md]` All `processPending()`/`restore` calls are fire-and-forget from triggers (`unawaited(...)` like the existing `signOut`/notification calls). The engine writes `SyncStatus` which the UI passively observes. Restore is the one user-initiated await, but it shows a loading state and runs off the build path.

### Pitfall 9: `findById` returns the full polyline row
**What goes wrong:** `TripsDao.findById` returns the full `TripRow` including the 5–15 KB `routePolyline` — fine and *required* here (the polyline must be synced), but be aware this is the heavy path, unlike `watchAllSummaries`.
**How to avoid:** This is correct usage for sync (the contract needs `routePolyline`). Just don't accidentally batch thousands at once — chunk at `kMaxSyncBatchTrips` (1000) per D-05. No action beyond honoring the chunk cap.

## Code Examples

### A. `ApiClient` — token attach + single 401 force-refresh-retry
```dart
// Source: composed from http 1.6.0 API + D-02/D-03 + firebase_auth 6.x getIdToken
//         (signature VERIFIED: Future<String?> getIdToken([bool forceRefresh = false]))
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:traevy/config/constants.dart';

class NotSignedInException implements Exception {}

/// Coarse outcome the engine branches on. Keep it tiny — engine maps it
/// to SyncStatus + retry decisions.
sealed class SyncResult { const SyncResult(); }
final class SyncOk extends SyncResult { const SyncOk(); }
final class SyncFailure extends SyncResult {
  const SyncFailure(this.statusCode); // null = transport error/timeout
  final int? statusCode;
}

class ApiClient {
  ApiClient({http.Client? client, FirebaseAuth? auth})
      : _client = client ?? http.Client(),
        _authOverride = auth;

  final http.Client _client;
  final FirebaseAuth? _authOverride;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  Future<String> _freshToken({bool force = false}) async {
    final user = _auth.currentUser;
    if (user == null) throw NotSignedInException();
    final token = await user.getIdToken(force); // String? — auto-refresh unless force
    if (token == null) throw NotSignedInException();
    return token;
  }

  /// POST /trips/sync with a single 401 force-refresh-retry (D-03).
  Future<SyncResult> syncTrips(List<Map<String, Object?>> trips) =>
      _sendJson(
        () => Uri.parse('$kApiBaseUrl/trips/sync'),
        method: 'POST',
        body: {'trips': trips},
      );

  Future<SyncResult> deleteTrip(String tripId) => _sendJson(
        () => Uri.parse('$kApiBaseUrl/trips/$tripId'),
        method: 'DELETE',
      );

  Future<SyncResult> _sendJson(
    Uri Function() uri, {
    required String method,
    Map<String, Object?>? body,
  }) async {
    Future<http.Response> attempt(String token) {
      final req = http.Request(method, uri())
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Content-Type'] = 'application/json';
      if (body != null) req.body = jsonEncode(body);
      return _client
          .send(req)
          .then(http.Response.fromStream)
          .timeout(kSyncHttpTimeout);
    }

    try {
      var res = await attempt(await _freshToken());
      if (res.statusCode == 401) {
        res = await attempt(await _freshToken(force: true)); // D-03 retry ONCE
      }
      // NEVER log res.body / headers (token/PII). Status code only.
      return res.statusCode >= 200 && res.statusCode < 300
          ? const SyncOk()
          : SyncFailure(res.statusCode);
    } on NotSignedInException {
      rethrow; // engine no-ops (Pitfall 5)
    } on Object {
      return const SyncFailure(null); // timeout / socket / format
    }
  }

  /// GET /trips/restore → decoded trip JSON list (D-08).
  Future<List<Map<String, Object?>>> restoreTrips() async {
    final res = await _client.get(
      Uri.parse('$kApiBaseUrl/trips/restore'),
      headers: {'Authorization': 'Bearer ${await _freshToken()}'},
    ).timeout(kSyncHttpTimeout);
    if (res.statusCode != 200) {
      throw http.ClientException('restore ${res.statusCode}');
    }
    final decoded = jsonDecode(res.body) as Map<String, Object?>;
    final data = decoded['body'] as Map<String, Object?>; // {statusCode, body:{data:{trips}}}
    final inner = data['data'] as Map<String, Object?>;
    return (inner['trips'] as List).cast<Map<String, Object?>>();
  }
}
```
> NOTE for planner: the restore response envelope is `{ statusCode, body: { data: { trips } } }` per `restore-trips.ts`. Confirm at implementation whether Cloud Functions returns the **doubly-wrapped** body (the handler does `res.json({ statusCode, body: { data: { trips } } })`) — the parser above unwraps `decoded['body']['data']['trips']`. Verify against a live call or `10-DEPLOY.md` example; this is Open Question 1.

### B. `TripJson` — serializer matched to `tripSchema` (omit userId; UTC Z; numerics never null)
```dart
// Source: D-04 + backend validation.ts tripSchema (VERIFIED) + trips_table.dart (VERIFIED)
import 'package:drift/drift.dart' show Value;
import 'package:traevy/database/database.dart'; // TripRow, TripsCompanion

Map<String, Object?> tripRowToJson(TripRow t) => {
      'id': t.id,
      // userId intentionally OMITTED — server forces it from the token (D-04).
      'startTime': t.startTime.toUtc().toIso8601String(),     // ...Z (Pitfall 1)
      'endTime': t.endTime.toUtc().toIso8601String(),
      'durationSeconds': t.durationSeconds,                   // int, non-null
      'distanceMeters': t.distanceMeters,                     // double, non-null (0 for manual)
      'routePolyline': t.routePolyline,                       // nullable per schema
      'direction': t.direction,                               // 'to_office' | 'to_home'
      'timeMovingSeconds': t.timeMovingSeconds,               // int, non-null
      'timeStuckSeconds': t.timeStuckSeconds,                 // int, non-null
      'isManualEntry': t.isManualEntry,
      'createdAt': t.createdAt.toUtc().toIso8601String(),
      'updatedAt': t.updatedAt.toUtc().toIso8601String(),
    };

/// Restore: server trip JSON → TripsCompanion (D-08). userId comes back from
/// the server; parse ISO strings to UTC DateTime.
TripsCompanion tripJsonToCompanion(Map<String, Object?> j) => TripsCompanion(
      id: Value(j['id']! as String),
      userId: Value(j['userId']! as String),
      startTime: Value(DateTime.parse(j['startTime']! as String).toUtc()),
      endTime: Value(DateTime.parse(j['endTime']! as String).toUtc()),
      durationSeconds: Value((j['durationSeconds']! as num).toInt()),
      distanceMeters: Value((j['distanceMeters']! as num).toDouble()),
      routePolyline: Value(j['routePolyline'] as String?),
      direction: Value(j['direction']! as String),
      timeMovingSeconds: Value((j['timeMovingSeconds']! as num).toInt()),
      timeStuckSeconds: Value((j['timeStuckSeconds']! as num).toInt()),
      isManualEntry: Value(j['isManualEntry']! as bool),
      createdAt: Value(DateTime.parse(j['createdAt']! as String).toUtc()),
      updatedAt: Value(DateTime.parse(j['updatedAt']! as String).toUtc()),
    );
```

### C. `SyncEngine.processPending` — batch + deletes + backoff + in-flight guard (shape)
```dart
// Source: D-05/D-06 + codebase Notifier pattern (auth/tracking providers, VERIFIED)
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/sync/sync_status.dart';

class SyncEngine extends Notifier<SyncStatus> {
  bool _running = false;
  bool _rerunRequested = false;
  Timer? _backoffTimer;

  @override
  SyncStatus build() {
    ref.onDispose(() => _backoffTimer?.cancel());
    // ... attach watchPending sub, connectivity sub, AppLifecycleListener here;
    //     each calls nudge(); cancel all in ref.onDispose (see Pattern 1).
    return const SyncIdle();
  }

  void nudge() => unawaited(_processPending());

  Future<void> _processPending() async {
    if (_running) { _rerunRequested = true; return; } // Pitfall 2 in-flight guard
    _running = true;
    try {
      state = const SyncSyncing();
      final dao = ref.read(syncQueueDaoProvider);
      final tripsDao = ref.read(tripsDaoProvider);
      final api = ref.read(apiClientProvider);
      final pending = await dao.getPending(); // oldest-first

      final creates = pending.where((r) => r.action != kSyncActionDelete).toList();
      final deletes = pending.where((r) => r.action == kSyncActionDelete).toList();

      // CREATE/UPDATE — load live rows, skip-vanished, chunk, single POST per chunk.
      final rowsById = <int, Map<String, Object?>>{};
      final synced = <int>[];
      for (final q in creates) {
        final trip = await tripsDao.findById(q.tripId);
        if (trip == null) { synced.add(q.id); continue; } // gone → mark synced+skip (D-05)
        rowsById[q.id] = tripRowToJson(trip);
      }
      for (final id in synced) { await dao.markSynced(id); }

      for (final chunk in _chunk(rowsById.entries.toList(), kMaxSyncBatchTrips)) {
        final res = await api.syncTrips(chunk.map((e) => e.value).toList());
        await _applyResult(dao, res, chunk.map((e) => e.key).toList());
      }
      // DELETE — individually (D-05).
      for (final q in deletes) {
        final res = await api.deleteTrip(q.tripId);
        await _applyResult(dao, res, [q.id]);
      }
      _publishStatus(dao);
    } on NotSignedInException {
      state = const SyncOffline(); // guest / not signed in — no retry churn (Pitfall 5)
    } finally {
      _running = false;
      if (_rerunRequested) { _rerunRequested = false; nudge(); }
    }
  }

  Future<void> _applyResult(SyncQueueDao dao, SyncResult res, List<int> ids) async {
    if (res is SyncOk) {
      for (final id in ids) { await dao.markSynced(id); }
      return;
    }
    for (final id in ids) {
      final row = /* re-read row to get retryCount, or carry it */;
      await dao.incrementRetry(id);
      if (row.retryCount + 1 >= kSyncQueueMaxRetries) {
        await dao.markFailed(id);          // NEW DAO method
      } else {
        _scheduleBackoff(row.retryCount + 1); // 2s * 2^n capped 60s (D-06)
      }
    }
  }

  void _scheduleBackoff(int attempt) {
    final delay = Duration(
      milliseconds: (kSyncRetryBaseDelay.inMilliseconds * (1 << attempt))
          .clamp(0, kSyncRetryMaxDelay.inMilliseconds),
    );
    _backoffTimer?.cancel();
    _backoffTimer = Timer(delay, nudge);
  }
}
```
> The planner should refine `_applyResult`'s retryCount sourcing — either re-read the row or batch the increments — and decide whether to track retry per-queue-row (recommended; matches `incrementRetry(int id)`).

### D. Triggers — connectivity (v7 List) + AppLifecycleListener.onResume
```dart
// Source: connectivity_plus 7.1.1 (VERIFIED List<ConnectivityResult>) +
//         AppLifecycleListener (VERIFIED api.flutter.dev)
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

// inside SyncEngine.build():
var _online = false;
final connSub = Connectivity().onConnectivityChanged.listen((results) {
  final nowOnline = results.any((r) => r != ConnectivityResult.none); // Pitfall 3
  if (!_online && nowOnline) nudge();   // offline→online transition only (Pitfall 4: best-effort)
  _online = nowOnline;
});

final lifecycle = AppLifecycleListener(
  onResume: nudge,                       // app foregrounded (SC 4)
);

ref.onDispose(() {
  unawaited(connSub.cancel());
  lifecycle.dispose();                   // AppLifecycleListener must be disposed
});
// watchPending() subscription added the same way → nudge() on each emission (post-save).
```

### E. Restore — insert-or-ignore dedupe by UUID PK
```dart
// Source: D-08 + drift InsertMode.insertOrIgnore (VERIFIED) + Batch.insertAll
import 'package:drift/drift.dart';
import 'package:traevy/database/database.dart';

class RestoreController {
  RestoreController(this._db, this._api);
  final AppDatabase _db;
  final ApiClient _api;

  /// Returns the number of NEW trips written (existing UUIDs skipped).
  Future<int> restore() async {
    final jsonTrips = await _api.restoreTrips();
    final companions = jsonTrips.map(tripJsonToCompanion).toList();
    final before = await _countTrips();
    await _db.batch((b) {
      b.insertAll(_db.trips, companions, mode: InsertMode.insertOrIgnore); // dedupe by id PK
    });
    final after = await _countTrips();
    return after - before; // inserted count for "Restored N trips" snackbar (D-08)
  }

  Future<int> _countTrips() async {
    final c = _db.trips.id.count();
    final q = _db.selectOnly(_db.trips)..addColumns([c]);
    return (await q.getSingle()).read(c)!;
  }
}
```
> NOTE: restore does NOT enqueue sync rows (D-08) — it writes `trips` directly via `_db`, bypassing the trip-save transactions that would enqueue.

### F. Settings — sync-status row + restore row (signed-in branch only)
```dart
// Source: D-09 + existing settings_screen.dart _AccountSection (VERIFIED)
// Inside the AuthSignedIn(...) arm of the switch, AFTER AccountRow, ADD:
final syncStatus = ref.watch(syncEngineProvider);
SettingsRow(
  label: switch (syncStatus) {
    SyncSynced()        => kCopySyncAllSynced,     // "All synced"
    SyncSyncing()       => kCopySyncSyncing,       // "Syncing…"
    SyncOffline()       => kCopySyncOffline,       // (or "N pending" via watchPending)
    SyncFailed(:final count) => '$count ${kCopySyncFailedSuffix}', // "N failed — tap to retry"
    SyncIdle()          => kCopySyncAllSynced,
  },
  onTap: syncStatus is SyncFailed
      ? () => ref.read(syncEngineProvider.notifier).nudge() // tap to retry
      : null,
),
SettingsRow(
  label: kCopyRestoreFromCloud,                    // "Restore from cloud"
  onTap: () => unawaited(_runRestore(context, ref)),
),
```

### G. Sealed `SyncStatus`
```dart
// Source: D-10 + repo sealed-class convention (auth_state.dart VERIFIED)
import 'package:flutter/foundation.dart';

@immutable
sealed class SyncStatus { const SyncStatus(); }
final class SyncIdle    extends SyncStatus { const SyncIdle(); }
final class SyncSyncing extends SyncStatus { const SyncSyncing(); }
final class SyncSynced  extends SyncStatus { const SyncSynced(); }
final class SyncOffline extends SyncStatus { const SyncOffline(); }
final class SyncFailed  extends SyncStatus {
  const SyncFailed(this.count);
  final int count; // number of failed queue rows
}
```

### H. `markFailed` DAO method (new)
```dart
// Source: D-06 + existing SyncQueueDao.markSynced pattern (VERIFIED)
/// Promote a queue row to terminal `failed` after the retry budget is spent.
Future<void> markFailed(int id) {
  return (update(syncQueue)..where((q) => q.id.equals(id))).write(
    const SyncQueueCompanion(status: Value(kSyncStatusFailed)),
  );
}
```
> NOTE: `getPending()` is referenced in D-05 but the current DAO (read 2026-06-01) exposes `watchPending()`, `markSynced`, `incrementRetry`, `enqueue*`. The planner must add a `Future<List<SyncQueueRow>> getPending()` (one-shot, oldest-first by `id`) alongside `markFailed`, or have the engine take `watchPending().first`. Recommend adding `getPending()` for a clean one-shot read — see Open Question 2.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `connectivity_plus` `onConnectivityChanged` → `ConnectivityResult` (single) | → `List<ConnectivityResult>` (multi-interface) | v6.0.0 (2024) | Online check is `results.any(r => r != none)`, not `== none` |
| `WidgetsBindingObserver.didChangeAppLifecycleState` | `AppLifecycleListener(onResume:)` | Flutter 3.13 (2023) | Typed, self-disposing; preferred for resume callback |
| `into(t).insert(c, onConflict: DoNothing())` | `InsertMode.insertOrIgnore` (or `Batch.insertAll(mode:)`) | drift 2.x | Terser dedupe; both valid |
| `StateNotifier` / `ChangeNotifier` | Riverpod 3.x `Notifier` / `NotifierProvider` | Riverpod 3.0 | Repo-wide; never use StateNotifier here |

**Deprecated/outdated:**
- Treating `connectivity_plus` as a single `ConnectivityResult` — wrong in v7.
- `@riverpod` codegen — blocked in this repo by the analyzer-major conflict (drift_dev ^analyzer 10 vs riverpod_generator ^analyzer 9).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | No existing app-lifecycle observer exists in the codebase to copy; `AppLifecycleListener` is a fresh introduction. | Alternatives / Code D | LOW — if one exists, reuse it. Planner should `grep "AppLifecycleListener\|WidgetsBindingObserver\|didChangeAppLifecycleState" lib/`. |
| A2 | The `/trips/restore` HTTP response JSON is the doubly-wrapped `{ statusCode, body: { data: { trips } } }` envelope (the handler calls `res.json(...)` with that exact object). | Code A (restore parse) | MEDIUM — if a middleware unwraps it, the parser path `decoded['body']['data']['trips']` is wrong. Verify against a live call / `10-DEPLOY.md`. Open Q1. |
| A3 | `DELETE /trips/{tripId}` needs no request body (the stored delete payload `{id,user_id}` is unused; the id is in the path). | D-05 / Code A | LOW — CONTEXT D-05 states this explicitly; backend `tripIdParam` validates only the path. |
| A4 | Adding `markFailed` (a method) requires only `build_runner` regen of the DAO mixin, no `schemaVersion` bump. | Runtime State Inventory | LOW — confirmed: no column added. |
| A5 | `getPending()` does not yet exist on `SyncQueueDao` (only `watchPending()`); planner adds it. | Code H / Open Q2 | LOW — verified by reading the DAO; trivial to add. |

## Open Questions

1. **Restore response envelope shape (A2).**
   - What we know: `restore-trips.ts` calls `res.status(200).json({ statusCode: 200, body: { data: { trips } } })`.
   - What's unclear: whether the deployed Cloud Function returns that object verbatim as the HTTP body (so the client double-unwraps `body.data.trips`) or whether an Express wrapper flattens it.
   - Recommendation: confirm with one authenticated `curl`/integration call against the live URL (or check `10-DEPLOY.md` for a sample response) before finalizing the parser. Write the parser defensively (handle both `decoded['body']['data']['trips']` and `decoded['data']['trips']`).

2. **`getPending()` vs `watchPending().first`.**
   - What we know: D-05 says "pull pending oldest-first (`getPending()`)" but the DAO currently only has `watchPending()`.
   - Recommendation: add `Future<List<SyncQueueRow>> getPending()` ordered by `id` ASC (oldest-first) to the DAO. Cleaner than `watchPending().first` for a one-shot drain and avoids accidentally holding a stream.

3. **Where the `watchPending` post-save trigger lives vs. the status provider.**
   - What we know: D-07 uses `watchPending()` as a trigger; D-09 uses `watchPending()` to show "N pending".
   - Recommendation: one subscription in the engine that both `nudge()`s and updates `SyncStatus` (idle/synced/failed count). Settings reads the engine's `SyncStatus`, not a second `watchPending` subscription — single source of truth.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | build/test | ✓ | 3.41.6 (Dart 3.11.4) | — |
| http (pub) | ApiClient | ✓ (add) | 1.6.0 | — |
| connectivity_plus (pub) | triggers | ✓ (add) | 7.1.1 (needs Dart ≥3.3 — satisfied) | If add fails, `WidgetsBindingObserver`-only triggers degrade gracefully (lose connectivity trigger, keep resume + post-save) |
| firebase_auth | token | ✓ | 6.5.1 (pinned) | — |
| drift / drift native | restore + tests | ✓ | 2.32.1 (pinned) | — |
| Live Cloud Functions backend | end-to-end manual verification | ✓ | https://api-rdj4i7kgmq-uc.a.run.app | Emulator (`firebase emulators:start`) for local manual checks |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none required (both new pub packages resolve cleanly for Dart 3.11.4).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + `package:http/testing.dart` `MockClient` + in-memory Drift (`drift/native` `NativeDatabase.memory()`) |
| Config file | `test/flutter_test_config.dart` (exists) |
| Quick run command | `flutter test test/unit/features/sync/ -x` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Automated Command | File Exists? |
|-----|----------|-----------|-------------------|-------------|
| D-04 | `tripRowToJson` emits camelCase, UTC `Z` timestamps, omits userId, numerics non-null (incl. manual entry = 0) | unit | `flutter test test/unit/features/sync/trip_json_test.dart -x` | ❌ Wave 0 |
| D-04 | round-trip `tripJsonToCompanion` parses ISO → UTC DateTime | unit | same file | ❌ Wave 0 |
| D-03 | `ApiClient` attaches `Bearer`, retries ONCE on 401 with force-refresh, no-ops on null user | unit (MockClient + fake FirebaseAuth) | `flutter test test/unit/features/sync/api_client_test.dart -x` | ❌ Wave 0 |
| D-05/06 | `SyncEngine` batches create/update into one POST, deletes individually, marks synced on 2xx, increments retry on failure, `markFailed` at 3, in-flight guard prevents double-run | unit (in-memory Drift + MockClient) | `flutter test test/unit/features/sync/sync_engine_test.dart -x` | ❌ Wave 0 |
| D-06 | backoff delay = 2s·2^n capped 60s | unit (`FakeAsync` or compute pure delay fn) | same file | ❌ Wave 0 |
| D-05 | create/update whose trip is gone locally → that row marked synced + skipped | unit | same file | ❌ Wave 0 |
| D-08 | restore inserts new trips, **skips** existing UUIDs, returns correct count | unit (in-memory Drift + MockClient) | `flutter test test/unit/features/sync/restore_controller_test.dart -x` | ❌ Wave 0 |
| D-06 | `SyncQueueDao.markFailed` writes `kSyncStatusFailed` | unit (in-memory Drift) | extend `test/unit/database/sync_queue_dao_test.dart` | ✅ (extend existing) |
| D-09/10 | Settings signed-in branch renders sync-status row + restore row; guest branch unchanged | widget | `flutter test test/widget/features/settings/settings_screen_test.dart -x` | ✅ (extend existing) |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/features/sync/ -x` (+ touched widget test)
- **Per wave merge:** `flutter test` (full suite green)
- **Phase gate:** Full suite green + `flutter analyze` clean before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/unit/features/sync/trip_json_test.dart` — D-04 serialize/deserialize (incl. manual-entry 0s, UTC Z)
- [ ] `test/unit/features/sync/api_client_test.dart` — D-03 token + 401-retry + null-user no-op (MockClient + fake FirebaseAuth provider override)
- [ ] `test/unit/features/sync/sync_engine_test.dart` — D-05/06 batching, retry, backoff, in-flight guard, vanished-trip skip
- [ ] `test/unit/features/sync/restore_controller_test.dart` — D-08 insert-or-ignore dedupe + count
- [ ] Extend `test/unit/database/sync_queue_dao_test.dart` — `markFailed` + (if added) `getPending` ordering
- [ ] Extend `test/widget/features/settings/settings_screen_test.dart` — sync-status + restore rows in signed-in branch
- [ ] Framework install: none — `MockClient` ships in `http`; in-memory Drift already used. **No new dev_dependencies.**
- [ ] Test seam: expose `apiClientProvider`/`syncEngineProvider`/`restoreControllerProvider` with injectable `http.Client` + `FirebaseAuth` (mirror `firebaseAuthProvider` override pattern) so tests override without platform channels.

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Firebase ID token (`getIdToken`); server verifies via Admin SDK (Phase 10). Client attaches Bearer only. |
| V3 Session Management | yes | FlutterFire owns session/refresh; force-refresh on 401. No manual session handling. |
| V4 Access Control | yes (server-side) | Server forces `userId` from token; client omits `userId` (D-04) — cannot spoof ownership. |
| V5 Input Validation | yes (server-side) | Backend `tripSchema` (zod) validates every field; client must conform exactly. Client also parses restore JSON defensively (typed casts). |
| V6 Cryptography | no (client) | TLS via HTTPS (`api-rdj4i7kgmq-uc.a.run.app`). No client crypto. Token stored in Keystore (existing). |
| V7 Error/Logging | yes | **Never log the ID token or PII** (Pitfall 6) — mirror `auth_service.dart` invariant. Log status codes + queue ids only. |

### Known Threat Patterns for Flutter REST client + Firebase
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Token leakage via logs | Information Disclosure | Never `print`/`log` token/headers/body; status-code-only logging (Pitfall 6, existing repo rule) |
| `userId` spoofing in payload | Spoofing / Elevation | Omit `userId` client-side; server forces it from verified token (D-04, Phase 10) |
| Cleartext HTTP | Tampering / Info Disclosure | HTTPS endpoint only; no cleartext config needed on Android (base URL is `https://`) |
| Replay of stale token | Spoofing | Live `getIdToken()` (auto-refresh) + force-refresh on 401; no long-lived cached token in the hot path |
| Oversized payload DoS | DoS | Backend caps at `kMaxSyncBatchTrips=1000`; client chunks at the same cap (D-05) so it never trips the 400 |

## Sources

### Primary (HIGH confidence)
- Local Flutter install — `flutter --version` → 3.41.6 / Dart 3.11.4 (VERIFIED)
- `pubspec.yaml` — firebase_auth ^6.5.1, drift ^2.32.1, flutter_riverpod ^3.3.1 pinned; http/connectivity_plus ABSENT; mockito/mocktail ABSENT (VERIFIED)
- Codebase reads (VERIFIED): `sync_queue_dao.dart`, `trips_dao.dart`, `database/providers.dart`, `database.dart`, `trips_table.dart`, `sync_queue_table.dart`, `auth_service.dart`, `auth_providers.dart`, `auth_state.dart`, `tracking_providers.dart`, `settings_screen.dart`, `app.dart`, `constants.dart`, `test/unit/database/sync_queue_dao_test.dart`, `test/unit/features/trips/trip_management_notifier_test.dart`
- Backend contract (VERIFIED): `validation.ts` (`tripSchema`, `syncTripsBody`, `tripIdParam`, `kMaxSyncBatchTrips=1000`), `types/trip.ts`, `handlers/restore-trips.ts`
- pub.dev `http` — 1.6.0, MockClient in `package:http/testing.dart` (VERIFIED)
- pub.dev `connectivity_plus` — 7.1.1, `onConnectivityChanged` → `Stream<List<ConnectivityResult>>`, `checkConnectivity()` → `List<ConnectivityResult>`, Dart ≥3.3 (VERIFIED)
- pub.dev `firebase_auth` `User.getIdToken` — `Future<String?> getIdToken([bool forceRefresh = false])` (VERIFIED)
- api.flutter.dev `AppLifecycleListener` — `onResume`/`onStateChange`, requires `dispose()` (VERIFIED)
- pub.dev `drift` `InsertMode` — `insertOrIgnore` value exists; `Batch.insertAll(mode:)` (VERIFIED)

### Secondary (MEDIUM confidence)
- drift docs (simonbinder.eu) — `Batch.insertAll` / `onConflict` patterns (CITED)

### Tertiary (LOW confidence)
- None load-bearing. Restore-envelope shape (A2) flagged for live verification (Open Q1).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every version + key API verified against pub.dev / local install
- Architecture: HIGH — mirrors three existing in-repo Notifier patterns read directly
- Serialization contract: HIGH — matched field-by-field to the backend zod schema source
- Restore response parsing: MEDIUM — envelope shape needs one live confirmation (Open Q1)
- Pitfalls: HIGH — derived from verified API behavior + existing repo invariants

**Research date:** 2026-06-01
**Valid until:** 2026-07-01 (stable stack; re-verify `http`/`connectivity_plus` versions if planning slips a month)
