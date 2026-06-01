---
phase: 11-sync-engine
plan: 01
subsystem: sync
tags: [sync, transport, serialization, http, drift]
requires:
  - "Phase 10 deployed Cloud Functions (zod tripSchema + restore envelope) — frozen contract"
  - "lib/database (TripRow, TripsCompanion, SyncQueueDao) + auth_providers (firebaseAuthProvider)"
provides:
  - "lib/sync/sync_status.dart — SyncStatus sealed model + SyncStatusNotifier + syncStatusProvider"
  - "lib/sync/trip_serializer.dart — TripSerializer.toJson/fromJson (wire contract)"
  - "lib/sync/api_client.dart — ApiClient (syncTrips/deleteTrip/restoreTrips) + SyncException + apiClientProvider"
  - "SyncQueueDao.getPending/markFailed/resetFailed"
  - "constants: kApiBaseUrl, endpoint paths, backoff, Settings copy"
affects:
  - "Plan 02 (SyncEngine) imports these exact names; Plan 03 (restore + Settings) imports Settings copy + restoreTrips + SyncStatus"
tech-stack:
  added:
    - "http ^1.6.0 (resolved 1.6.0)"
    - "connectivity_plus ^7.1.1 (resolved 7.1.1)"
  patterns:
    - "Manual Riverpod 3.x Provider/NotifierProvider (no @riverpod codegen)"
    - "Injectable seams (http.Client + token-getter + baseUrl) for MockClient tests"
    - "package:http/testing.dart MockClient + in-memory Drift (no mockito/mocktail)"
key-files:
  created:
    - lib/sync/sync_status.dart
    - lib/sync/trip_serializer.dart
    - lib/sync/api_client.dart
    - test/unit/sync/trip_serializer_test.dart
    - test/unit/sync/api_client_test.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - lib/config/constants.dart
    - lib/database/daos/sync_queue_dao.dart
    - lib/database/daos/sync_queue_dao.g.dart
    - test/unit/database/sync_queue_dao_test.dart
decisions:
  - "deleteTrip HTTP 404 -> success (idempotent delete, cross-AI amendment)"
  - "SyncException.toString is PII-free (statusCode/retryable/message only) — T-11-01"
  - "restoreTrips throws on malformed envelope instead of silent [] — MEDIUM-1"
metrics:
  duration: ~35m
  completed: 2026-06-01
---

# Phase 11 Plan 01: Sync Foundation (transport, serializer, status, DAO additions) Summary

JWT-authenticated REST transport, exact-match wire serializer, finite sync-status
model, and three new sync-queue DAO methods — the frozen contracts Plans 02 and 03
bind to, built and unit-tested green on their own.

## What Was Built

Three new files under `lib/sync/`, plus constants, two DAO methods (+ one one-shot
read), and three unit-test files. Everything follows the project's manual Riverpod
3.x idiom (no `@riverpod` codegen) and uses injectable seams so the transport is
testable with `MockClient` + in-memory Drift — no new test packages.

## Exact Public Names (Plans 02 & 03 bind to these — DO NOT RENAME)

### `lib/sync/sync_status.dart`
- `sealed class SyncStatus` with variants `SyncIdle`, `SyncSyncing`, `SyncSynced`,
  `SyncOffline`, `SyncFailed(int count)` (all `const`).
- `class SyncStatusNotifier extends Notifier<SyncStatus>` with
  `SyncStatus build() => const SyncIdle();` and `void set(SyncStatus status)`
  (engine is sole writer; kept a method — not a setter — to keep the bound name).
- `final NotifierProvider<SyncStatusNotifier, SyncStatus> syncStatusProvider`
  (keepAlive, `name: 'syncStatusProvider'`).
- Settings reads via an exhaustive `switch` on `SyncStatus` (never `.when()`).

### `lib/sync/trip_serializer.dart`
- `class TripSerializer` (private const ctor; static methods):
  - `static Map<String, dynamic> toJson(TripRow t)` — camelCase keys, `userId`
    OMITTED, timestamps `toUtc().toIso8601String()` (end with `Z`), numerics
    always numbers (0 for manual entries, never null), `routePolyline` nullable,
    `direction` pass-through. Matches the backend zod `tripSchema` exactly.
  - `static TripsCompanion fromJson(Map<String, dynamic> json)` — `TripsCompanion.insert(...)`,
    ISO → `DateTime.parse(...).toUtc()`, `userId` NOT set (local auth backfill owns it).

### `lib/sync/api_client.dart`
- `class SyncException implements Exception`:
  - fields `int? statusCode`, `bool notSignedIn`, `bool retryable`, `String message`.
  - `const SyncException.notSignedIn()` → `notSignedIn=true, statusCode=null, retryable=false`.
  - `const SyncException.http(int code)` → `retryable = code >= 500 || code == 401`
    (HIGH-2: 5xx/401 retryable; all other 4xx incl. 400 NON-retryable).
  - `const SyncException.transport()` → `statusCode=null, retryable=true`.
  - `toString()` PII-free (no token/uid/email) — T-11-01.
- `class ApiClient`:
  - ctor `ApiClient({required http.Client client, required Future<String?> Function({bool forceRefresh}) getToken, String baseUrl = kApiBaseUrl})`.
  - `Future<void> syncTrips(List<TripRow> trips)` → POST `/trips/sync`, body
    `{ "trips": [ <serialized> ] }`.
  - `Future<void> deleteTrip(String tripId)` → DELETE `/trips/{tripId}`;
    **HTTP 404 = success** (idempotent, amendment); other 4xx → non-retryable throw.
  - `Future<List<TripsCompanion>> restoreTrips()` → GET `/trips/restore`; unwraps
    the FULL envelope `decoded['body']['data']['trips']` (MEDIUM-1); throws
    `SyncException` on a malformed/missing-wrapper envelope (never silent `[]`).
  - 401 handling: refresh via `getToken(forceRefresh: true)` and retry ONCE; a
    null refresh → `notSignedIn`; any thrown network/refresh/decode error →
    `SyncException.transport()` (retryable, no token leak).
- `final Provider<ApiClient> apiClientProvider` — keepAlive; PRODUCTION token seam
  wires the REAL `ref.read(firebaseAuthProvider).currentUser?.getIdToken(forceRefresh)`
  (M4, not a stub); `ref.onDispose(client.close)`. Tests construct `ApiClient`
  directly (or override the provider) with a `MockClient` + fake token-getter + test `baseUrl`.

### `lib/database/daos/sync_queue_dao.dart`
- `Future<List<SyncQueueRow>> getPending()` — pending rows, oldest-first (id ASC) (D-05).
- `Future<void> markFailed(int id)` — status → `kSyncStatusFailed` (D-06 / HIGH-2).
- `Future<void> resetFailed()` — failed → pending, `retryCount` → 0 (manual retry, D-06).

## Constants Added (lib/config/constants.dart, Phase 11 section)
- `kApiBaseUrl = 'https://us-central1-travey-298a7.cloudfunctions.net/api'`
  (D-02 verified stable v2 alias; INJECTABLE default — NOT the older run.app host).
- `kSyncTripsPath = '/trips/sync'`, `kRestoreTripsPath = '/trips/restore'`,
  `kDeleteTripPathPrefix = '/trips/'`.
- `kSyncRetryBaseDelay = Duration(seconds: 2)`, `kSyncRetryMaxDelay = Duration(seconds: 60)` (D-06).
- Settings copy (D-09): `kSettingsAccountSectionTitle`, `kSettingsCloudSyncRowLabel`,
  `kSettingsSyncStatusAllSynced`, `kSettingsSyncStatusSyncing`,
  `kSettingsSyncStatusPendingTemplate`, `kSettingsSyncStatusFailed`,
  `kSettingsSyncStatusOffline`, `kSettingsRestoreRowLabel`,
  `kSettingsRestoreInProgress`, `kSettingsRestoreResultTemplate`,
  `kSettingsRestoreUpToDate`, `kSettingsRestoreError`.

## Pinned Versions
- `http: ^1.6.0` → resolved **1.6.0**
- `connectivity_plus: ^7.1.1` → resolved **7.1.1**
- (connectivity_plus added now for Plan 02; v7 returns `List<ConnectivityResult>`.)

## Verification (REAL results)

| Step | Command | Result |
|------|---------|--------|
| Deps | `flutter pub get` | Got dependencies! (http 1.6.0, connectivity_plus 7.1.1) |
| Codegen | `dart run build_runner build --delete-conflicting-outputs` | Built; wrote outputs, no errors |
| Analyze (baseline) | `flutter analyze` | 96 issues (87 info + 9 warning + 0 error) |
| Analyze (after) | `flutter analyze` | **96 issues (87 info + 9 warning + 0 error)** — identical; ZERO attributable to Phase 11 files |
| Unit tests | `flutter test test/unit/` | **+246 ~10: All tests passed!** (10 pre-existing skips, 0 failures) |
| New tests | `flutter test test/unit/sync/ test/unit/database/sync_queue_dao_test.dart` | +31: All tests passed! (8 serializer + 15 api_client + 8 DAO) |

Confirmed: no new analyze errors/warnings/infos are attributable to any new Phase 11
file (`flutter analyze 2>&1 | grep -E "lib/sync|test/unit/sync|sync_queue_dao"` → none).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — lint] Removed unused `firebase_auth` import in api_client.dart**
- **Found during:** Task 3
- **Issue:** The provider reaches `getIdToken` through `firebaseAuthProvider` (typed
  via auth_providers), so directly importing `firebase_auth` was flagged
  `unused_import` (a warning — would have added a NEW analyze issue).
- **Fix:** Removed the direct import; the token seam resolves through
  `firebaseAuthProvider`. Behavior unchanged (M4 production wiring intact).
- **Files modified:** lib/sync/api_client.dart
- **Commit:** Task 3 commit

**2. [Rule 1 — lint] Doc-comment + style fixes to keep ZERO new analyze issues**
- **Found during:** Tasks 1–3
- **Issue:** `comment_references` (bracket links to symbols not in constants.dart /
  class-doc scope), `lines_longer_than_80_chars`, `avoid_redundant_argument_values`,
  `avoid_types_on_closure_parameters`, `prefer_const_constructors`,
  `directives_ordering`, `use_setters_to_change_properties` — all introduced by new
  code under the `very_good_analysis` lint set.
- **Fix:** Converted `[Symbol]` refs to backticks/plain text where out of scope;
  wrapped long lines; dropped redundant `routePolyline: null` / `baseUrl: kApiBaseUrl`
  default args; removed closure param type annotations; `const` on a test ctor;
  alphabetized imports; added a scoped `// ignore: use_setters_to_change_properties`
  on `SyncStatusNotifier.set` (kept as a method because Plans 02/03 bind to `set(...)`).
- **Result:** Net analyze delta = 0.

### Contract notes (not deviations)
- `kSettingsAccountSectionTitle = 'Account'` was ADDED (no prior constant existed;
  the current settings_screen.dart hardcodes `'Account'` at line 116 — a pre-existing
  string left untouched here, to be wired by Plan 03).
- Amendment applied: `deleteTrip` 404 → success (idempotent), with a dedicated test.

## Known Stubs
None. All transport/serializer/DAO surfaces are fully implemented; the production
`apiClientProvider` wires the real FirebaseAuth token seam (M4), not a stub.

## Self-Check: PASSED
- Files created exist: lib/sync/sync_status.dart, lib/sync/trip_serializer.dart,
  lib/sync/api_client.dart, test/unit/sync/trip_serializer_test.dart,
  test/unit/sync/api_client_test.dart — all present.
- Commits exist: 8574c7d (Task 1), Task 2, Task 3 — all in git log.
- Verification commands re-run with real output above.
