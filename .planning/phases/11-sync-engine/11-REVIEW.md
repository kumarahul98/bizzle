---
phase: 11-sync-engine
reviewed: 2026-06-01T00:00:00Z
depth: deep
files_reviewed: 19
files_reviewed_list:
  - lib/app.dart
  - lib/config/constants.dart
  - lib/database/daos/sync_queue_dao.dart
  - lib/database/daos/trips_dao.dart
  - lib/features/settings/providers/settings_providers.dart
  - lib/features/settings/screens/settings_screen.dart
  - lib/features/settings/widgets/cloud_sync_row.dart
  - lib/features/settings/widgets/restore_row.dart
  - lib/sync/api_client.dart
  - lib/sync/restore_controller.dart
  - lib/sync/sync_engine.dart
  - lib/sync/sync_status.dart
  - lib/sync/trip_serializer.dart
  - test/unit/database/sync_queue_dao_test.dart
  - test/unit/sync/api_client_test.dart
  - test/unit/sync/restore_controller_test.dart
  - test/unit/sync/sync_engine_test.dart
  - test/unit/sync/trip_serializer_test.dart
  - test/widget/features/settings/settings_screen_test.dart
findings:
  critical: 0
  high: 1
  medium: 4
  low: 5
  total: 10
status: issues_found
---

# Phase 11: Code Review Report — Sync Engine

**Reviewed:** 2026-06-01
**Depth:** deep (cross-file: engine ↔ api_client ↔ DAOs ↔ backend zod contract ↔ Settings)
**Files Reviewed:** 19
**Status:** issues_found

## Summary

The Phase 11 client sync engine is well-built and faithful to the CONTEXT decisions
(D-01..D-10). Queue collapse, batch chunking, retry/backoff math, the in-flight
mutex (claimed synchronously), the backoff-window guard, error classification on
`SyncException.retryable`, delete-404→success, restore dedupe via a real
`COUNT(*)` delta, and the PII guards (token never logged, no `error.toString()`
surfaced) are all correct and well-tested. The serializer matches the backend
`tripSchema` exactly. Dispose releases all four resources. No `cloud_firestore`
usage; Drift remains the only UI data source; no `await` blocks any widget build.

The findings below are real but mostly contained. The one **High** is a contract
gap in `ApiClient.restoreTrips`: JSON/parse errors escape as raw, un-mapped
exceptions instead of the documented `SyncException`, so the type contract the
controller and tests assume is not actually upheld for the most common failure
modes (truncated/invalid response, malformed trip element). The blast radius is
limited because `RestoreController` catches `on Object`, but it should be fixed.

No critical security or data-loss issues. No skipped tests added. No dead code in
the engine itself; one unused constant and minor duplication noted as Low.

## High

### HR-01: `ApiClient.restoreTrips` leaks raw FormatException/TypeError instead of SyncException

**File:** `lib/sync/api_client.dart:170-178`
**Issue:** `jsonDecode` and the trip-by-trip `TripSerializer.fromJson` mapping run
*outside* the `_send` try/catch (which is the only place that maps unexpected
errors to `SyncException.transport`). As a result:
- An invalid/truncated JSON body → `jsonDecode` throws `FormatException`.
- A top-level JSON that is not an object (e.g. an array, or `null`) → `as Map<String, dynamic>` throws `TypeError`.
- A malformed trip element (missing key, wrong type) → `TripSerializer.fromJson` throws `TypeError`/`CastError`.

None of these are caught here, so a raw `FormatException`/`TypeError` escapes —
directly contradicting the method's own doc ("Throws `SyncException.transport` on
a malformed envelope") and the `SyncException`-typed contract that callers rely on.
The existing test "a body missing the outer wrapper throws" only passes because it
hits the `trips == null` guard (line 174), not the JSON-parse path — so the gap is
untested. (Today the only caller, `RestoreController.restore`, catches `on Object`,
so it degrades to `RestoreError` rather than crashing — which is why this is High,
not Critical.)
**Fix:** Wrap the decode + map in a try that re-maps to the typed error, mirroring
`_send`:
```dart
final res = await _send((token) => _client.get(...));
try {
  final decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) throw const SyncException.transport();
  final body = decoded['body'] as Map<String, dynamic>?;
  final data = body?['data'] as Map<String, dynamic>?;
  final trips = data?['trips'] as List<dynamic>?;
  if (trips == null) throw const SyncException.transport();
  return trips
      .map((e) => TripSerializer.fromJson(e as Map<String, dynamic>))
      .toList();
} on SyncException {
  rethrow;
} on Object {
  throw const SyncException.transport();
}
```
Add a unit test feeding invalid JSON (e.g. `'not json'`) and a malformed trip
element to assert `throwsA(isA<SyncException>())`.

## Medium

### MR-01: `kSettingsAccountSectionTitle` added this phase but never used; section title still hardcoded

**File:** `lib/config/constants.dart:745`, `lib/features/settings/screens/settings_screen.dart:120`
**Issue:** Phase 11 added `const kSettingsAccountSectionTitle = 'Account'` "so the
Phase 11 sync rows live under a stable, non-hardcoded title," but `_AccountSection`
still passes `SettingsSection(title: 'Account', ...)` (a hardcoded literal). The new
constant is dead, and the CLAUDE.md "no hardcoded strings" rule is still violated at
the call site this phase touched. (Note: the widget test asserts `find.text('ACCOUNT')`
because `SettingsSection` upper-cases the title — so the literal and constant must
stay byte-identical or the test breaks; using the constant removes that coupling.)
**Fix:** Replace the literal with the constant:
```dart
return SettingsSection(title: kSettingsAccountSectionTitle, children: rows);
```
Then either keep the constant (now used) or delete it if you revert. Do not leave it
defined-but-unused.

### MR-02: `restoreTrips` doc and parse path disagree on the failure contract

**File:** `lib/sync/api_client.dart:157-161`
**Issue:** The doc-comment promises `SyncException.transport` "on a malformed
envelope rather than silently returning []", but as detailed in HR-01 only the
`trips == null` shape actually produces that. This is the documentation half of
HR-01; fixing HR-01 resolves it. Calling it out separately so the `--fix` pass
updates the comment if it scopes HR-01 narrowly.
**Fix:** After applying HR-01, the doc becomes accurate as written. No further text
change needed beyond HR-01.

### MR-03: Successful drain re-triggers an extra empty `processPending` via `watchPending` self-loop

**File:** `lib/sync/sync_engine.dart:310-312`, `138-143`
**Issue:** The post-save trigger listens to `watchPending()`. When `_drain` marks
rows synced, those rows leave the pending set, so `watchPending` emits a new
(smaller/empty) list, which fires `processPending()` again. The `_inFlight` mutex
prevents overlap *during* a drain, but the trailing emission after the drain
completes schedules one more `processPending()` that does a `getPending()` (empty)
→ sets `SyncSynced` → returns. It is bounded (one redundant empty drain per
successful sync, not a tight loop), and it does not burn retries or hit the network,
but it is wasted work and an extra status churn the review brief explicitly flagged
("re-triggers ONLY on new pending ids, not on the engine's own markSynced writes").
**Fix:** Gate the post-save trigger on a rising edge of *non-empty* pending, e.g.
track the last-seen pending count and only nudge when it increases, or debounce:
```dart
var lastPending = 0;
_pendingSub = _queueDao.watchPending().listen((rows) {
  if (rows.length > lastPending) unawaited(processPending());
  lastPending = rows.length;
});
```
(Reset `lastPending` appropriately; this turns markSynced-driven *shrink* emissions
into no-ops while still firing on genuine new enqueues.)

### MR-04: Connectivity "online" check trusts a non-`none` result == reachability

**File:** `lib/sync/sync_engine.dart:307,316,373`
**Issue:** `connectivity_plus` reports *interface* state, not actual internet
reachability — a device on Wi-Fi with no upstream (captive portal, dead AP) reports
a non-`none` result, so `_isOnline()` returns true and the engine attempts the POST.
This is acceptable because the transport failure is correctly classified as
`retryable` and backed off (the design already assumes network attempts can fail),
so it is not a correctness bug — but it means the rising-edge "connectivity restored"
trigger can fire on a non-usable network and immediately consume a retry +
open a backoff window. Worth a comment acknowledging the limitation; no behavioural
fix required for v0.1.
**Fix:** Add a code comment at the `_isOnline`/seed sites noting that connectivity_plus
is interface-level only and that real reachability is proven by the request itself
(which is why transport failures are retryable). Optionally skip incrementing the
retry counter for the very first attempt after a connectivity rising edge — but that
is a v0.2 refinement, not required now.

## Low

### LR-01: `_failedCount()` duplicates `countFailed()` and is used asymmetrically

**File:** `lib/sync/sync_engine.dart:130,228,337`
**Issue:** The catch-all in `processPending` uses `SyncFailed(await _failedCount())`
while `_drain` uses `SyncFailed(await _queueDao.countFailed())`. `_failedCount()` is
a one-line passthrough to `countFailed()`. Two names for one query is mild noise.
**Fix:** Delete `_failedCount()` and call `_queueDao.countFailed()` directly in the
catch-all for consistency.

### LR-02: `countFailed` loads full rows just to count them

**File:** `lib/database/daos/sync_queue_dao.dart:115-120`
**Issue:** `countFailed` does `select(...).get()` then `rows.length`, materializing
every failed row (including payloads) to compute a length. Functionally correct;
slightly wasteful. (Performance is out of v1 scope, but this is also a clarity
issue — the method name implies a COUNT.)
**Fix:** Use a count aggregate like `insertOrIgnoreTrips` already does:
```dart
final c = syncQueue.id.count(filter: syncQueue.status.equals(kSyncStatusFailed));
final row = await (selectOnly(syncQueue)..addColumns([c])).getSingle();
return row.read(c) ?? 0;
```

### LR-03: `markSynced`/`syncedAt` use `DateTime.now()` while the engine has an injected clock

**File:** `lib/database/daos/sync_queue_dao.dart:127`
**Issue:** The DAO stamps `syncedAt: DateTime.now().toUtc()` directly. The engine
takes an injectable `now` seam for testability, but the DAO does not — so the
`syncedAt` value is non-deterministic in tests (the engine test only asserts
`isNotNull`, so it passes). Minor consistency gap, not a bug.
**Fix:** Acceptable as-is for v0.1; if you want full determinism, thread the clock
through, otherwise leave a note that `syncedAt` is wall-clock by design.

### LR-04: `SyncOffline` doc claims it also covers "not signed in", but the engine never sets it for guests

**File:** `lib/sync/sync_status.dart:30-31`, `lib/sync/sync_engine.dart:117`
**Issue:** The `SyncOffline` doc says "(or the user is not signed in)", but the guest
branch in `processPending` returns early with **no** status change (correct — D-03
"no status change, no DB writes"). So the comment overstates what the state means and
could mislead a future reader into expecting `SyncOffline` on sign-out.
**Fix:** Trim the parenthetical: `/// The device is offline — pending rows wait.`

### LR-05: Engine catch-all maps a stray `notSignedIn` thrown mid-drain to `SyncFailed`

**File:** `lib/sync/sync_engine.dart:127-130`
**Issue:** `_handleFailure` correctly treats `SyncException.notSignedIn` as a no-op
(returns false). But if a `notSignedIn` were to propagate from outside the per-row
try/catch (e.g. a future refactor moving an API call), the outer `on Object` catch
would surface `SyncFailed(count)` — a misleading "failed" state for a
not-signed-in condition. Today this path is unreachable (the only API calls are
inside per-row try/catch, and guests are gated at step (c)), so it is defensive-only.
**Fix:** Optionally special-case `on SyncException` in the outer catch to skip the
`SyncFailed` set when `e.notSignedIn` is true. Low priority; current code is correct
for all current call paths.

## Notes (verified correct — no action)

- Serializer keys, ISO-8601-Z timestamps, omitted `userId`, non-null numerics for
  manual entries: match `validation.ts` `tripSchema` exactly. (trip_serializer.dart)
- Queue collapse (create+update→one upsert; create→delete→no orphan create;
  delete supersede; per-tripId): correct and well-tested. (sync_engine.dart:147-180)
- In-flight mutex claimed synchronously before any `await`; backoff-window guard
  prevents trigger bypass; `retryFailed` clears the window first. (sync_engine.dart:107-119, 273-298)
- Error classification: 5xx/401-final/transport → retryable; other 4xx/400 →
  markFailed immediately, no retry burn. delete-404 → success. (api_client.dart:33-44, 147-155)
- Token never logged; `SyncException.toString` PII-free (tested). 401→forceRefresh→
  retry once, no infinite loop. (api_client.dart:59-61, 103-126)
- Restore: single `batch` insertAll insertOrIgnore, count via real `COUNT(*)` delta
  (not rowid), enqueues zero sync rows. (trips_dao.dart:121-133, restore_controller.dart)
- Settings widgets: <100 lines; copy from constants; rows only in signed-in branch;
  failed-tap calls `retryFailed()` once; sealed `SyncStatus`/`RestoreState` switches
  exhaustive; restore SnackBar guarded with `context.mounted` after the await.
- dispose() cancels all four resources (pending sub, connectivity sub, lifecycle
  listener, backoff timer). (sync_engine.dart:330-335)
- Tests assert real behavior (collapse, retry cap, in-flight overlap via Completer,
  dedupe non-overwrite, auth-state branches); no skipped tests; widget tests cover
  guest + signed-in + failed-tap + restore-success + restore-error.

---

## Severity Counts

- **Critical:** 0
- **High:** 1
- **Medium:** 4
- **Low:** 5
- **Total:** 10

**Verdict:** Solid, contract-faithful, well-tested phase — ship after fixing HR-01
(map restore parse/JSON errors to `SyncException`) and MR-01 (use the unused Account
title constant); the remaining items are polish.

_Reviewed: 2026-06-01_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
