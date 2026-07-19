# Phase 26: Sync Breaks & Edit Metadata to Cloud - Pattern Map

**Mapped:** 2026-07-12
**Files analyzed:** 18 (13 modified, 3 new client, 2 new tests explicitly called out; several backend files modified in place)
**Analogs found:** 18 / 18 (every file is itself an existing file to extend, OR has a direct in-repo precedent for its "new" shape)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sync/trip_serializer.dart` (extend) | utility (wire codec) | transform | itself (existing file, extend in place) | exact |
| `lib/sync/sync_engine.dart` (extend `_drain`) | service | batch / event-driven | itself (existing file, extend in place) | exact |
| `lib/sync/api_client.dart` (extend `syncTrips`) | service (HTTP client) | request-response | itself (existing file, extend in place) | exact |
| `lib/sync/restore_controller.dart` (extend `restore()`) | controller (Riverpod Notifier) | request-response + CRUD | itself; transaction shape from `lib/features/tracking/services/tracking_service_controller.dart` | exact (self) / role-match (transaction) |
| `lib/sync/restore_conflict.dart` (no shape change; D-07 consumed in `restore_controller.dart`) | model | — | itself | exact |
| `lib/sync/merge_resolution.dart` (**NEW**) | utility (pure function) | transform | extracted from `lib/features/settings/widgets/conflict_resolution_sheet.dart`'s `_applyAll` (lines 28-82) | exact (extraction source) |
| `lib/features/settings/widgets/conflict_resolution_sheet.dart` (extend) | component (StatefulWidget) | request-response | itself (existing file, extend in place) | exact |
| `lib/database/tables/user_preferences_table.dart` (add marker column) | model (Drift table) | CRUD | itself — mirrors the `homeLat`/`officeLat` v5→v6 additive-column pattern already in the same file | exact |
| `lib/database/daos/trip_breaks_dao.dart` (add `breaksForTripIds`) | model (DAO) | batch / CRUD | itself — mirrors `breaksForTrip` (lines 34-39) in the same file | exact |
| `lib/database/daos/user_preferences_dao.dart` (add marker getter/setter) | model (DAO) | CRUD | itself — mirrors `setHasSeenOnboarding` (lines 232-251) in the same file | exact |
| `lib/database/database.dart` (schemaVersion 6→7, new `onUpgrade` branch) | config (migration) | batch | itself — mirrors the `from < 6 && to >= 6` branch (lines 110-123) in the same file | exact |
| `lib/features/shell/main_shell.dart` (add backfill call) | component (shell / trigger) | event-driven | itself — mirrors the `ref.listen<AuthState>` → `_runAutoRestore()` seam (lines 160-165) | exact |
| `lib/config/constants.dart` (add new constants) | config | — | itself — mirrors the Phase 24 `kAutoRestore*`/`kConflict*` block (lines 1171-1195) | exact |
| `backend/functions/src/utils/validation.ts` (extend `tripSchema`) | utility (validation schema) | request-response | itself (existing file, extend in place) | exact |
| `backend/functions/src/types/trip.ts` (extend `Trip`/`TripDoc`) | model (TS interfaces) | — | itself (existing file, extend in place) | exact |
| `backend/functions/src/utils/firestore.ts` (extend `tripConverter.fromFirestore`) | utility (Firestore converter) | transform | itself (existing file, extend in place) | exact |
| `backend/functions/src/handlers/sync-trips.ts` (extend doc literal) | controller (HTTPS handler) | request-response | itself (existing file, extend in place) | exact |
| `backend/functions/src/handlers/restore-trips.ts` (extend Trip projection) | controller (HTTPS handler) | request-response | itself (existing file, extend in place) | exact |
| `test/unit/database/migration_v7_test.dart` (**NEW**) | test | batch | `test/unit/database/migration_v6_test.dart` (verify exists; follow structure exactly per RESEARCH.md) | exact (by convention, not yet read this session) |
| `test/unit/sync/merge_resolution_test.dart` (**NEW**) | test | transform | `test/unit/sync/sync_engine_test.dart` / `restore_controller_test.dart` (fake-clock, fixture-builder conventions) | role-match |

## Pattern Assignments

### `lib/sync/trip_serializer.dart` (utility, transform)

**Analog:** itself — existing 62-line file, extend in place.

**Full current file for reference** (all 62 lines already read — no re-read needed):
```dart
// Source: lib/sync/trip_serializer.dart:25-38 (toJson) and :43-61 (fromJson)
static Map<String, dynamic> toJson(TripRow t) => <String, dynamic>{
  'id': t.id,
  'startTime': t.startTime.toUtc().toIso8601String(),
  'endTime': t.endTime.toUtc().toIso8601String(),
  'durationSeconds': t.durationSeconds,
  'distanceMeters': t.distanceMeters,
  'routePolyline': t.routePolyline,
  'direction': t.direction,
  'timeMovingSeconds': t.timeMovingSeconds,
  'timeStuckSeconds': t.timeStuckSeconds,
  'isManualEntry': t.isManualEntry,
  'createdAt': t.createdAt.toUtc().toIso8601String(),
  'updatedAt': t.updatedAt.toUtc().toIso8601String(),
};

static TripsCompanion fromJson(Map<String, dynamic> json) =>
    TripsCompanion.insert(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String).toUtc(),
      endTime: DateTime.parse(json['endTime'] as String).toUtc(),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      routePolyline: Value<String?>(json['routePolyline'] as String?),
      direction: json['direction'] as String,
      timeMovingSeconds: (json['timeMovingSeconds'] as num).toInt(),
      timeStuckSeconds: (json['timeStuckSeconds'] as num).toInt(),
      isManualEntry: Value<bool>(json['isManualEntry'] as bool),
      createdAt: Value<DateTime>(
        DateTime.parse(json['createdAt'] as String).toUtc(),
      ),
      updatedAt: Value<DateTime>(
        DateTime.parse(json['updatedAt'] as String).toUtc(),
      ),
    );
```

**What changes (per RESEARCH.md Pitfall 3):** `toJson` becomes a 2-arg function
`toJson(TripRow t, List<TripBreakRow> breaks)` — add `totalPausedSeconds`,
`isEdited`, `directionSource`, and `breaks: breaks.map((b) => {'startTime':
b.startTime.toUtc().toIso8601String(), 'endTime':
b.endTime!.toUtc().toIso8601String()}).toList()` to the returned map.
`fromJson` gains `totalPausedSeconds: Value<int>((json['totalPausedSeconds']
as num?)?.toInt() ?? 0)`, `isEdited: Value<bool>(json['isEdited'] as bool? ??
false)`, `directionSource: Value<String>(json['directionSource'] as String? ??
kDirectionSourceTime)` — matching the existing `Value<T>(...)` wrapping
convention for nullable/optional companion fields (see `routePolyline` above)
— PLUS a separately-returned breaks list (fromJson cannot attach breaks to a
`TripsCompanion` since `trip_breaks` is a different table; return a record or
tuple `({TripsCompanion trip, List<TripBreaksCompanion> breaks})` mirroring
the codec's existing one-function-per-direction shape).

**Ripple:** `api_client.dart:132` (`trips.map(TripSerializer.toJson)`) and
`:186` (`TripSerializer.fromJson`) both need call-site updates — see
`api_client.dart` pattern below.

---

### `lib/sync/sync_engine.dart` (service, batch / event-driven)

**Analog:** itself — existing 431-line file.

**Imports pattern** (lines 1-14):
```dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/sync_queue_dao.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/sync_status.dart';
```
Add `import 'package:traevy/database/daos/trip_breaks_dao.dart';` and inject
`required TripBreaksDao tripBreaksDao` into the constructor (mirrors the
existing DI seam — every dependency is injected, never a global/singleton
read, per the class doc's "INJECTED seams so unit tests need no real
network").

**Core batch-fetch-then-serialize pattern** (lines 199-231, `_drain`'s upsert
section — this is the insertion point):
```dart
// Source: lib/sync/sync_engine.dart:201-231
final liveTrips = <TripRow>[];
final effForTrip = <String, _Effective>{};
for (final entry in upserts.entries) {
  final trip = await _tripsDao.findById(entry.key);
  if (trip == null) {
    await _markAllSynced(entry.value);
    continue;
  }
  liveTrips.add(trip);
  effForTrip[entry.key] = entry.value;
}

for (var i = 0; i < liveTrips.length; i += kMaxSyncBatchTrips) {
  final end = (i + kMaxSyncBatchTrips < liveTrips.length)
      ? i + kMaxSyncBatchTrips
      : liveTrips.length;
  final chunk = liveTrips.sublist(i, end);
  try {
    await _api.syncTrips(chunk);
    for (final trip in chunk) {
      await _markAllSynced(effForTrip[trip.id]!);
    }
  } on SyncException catch (e) {
    for (final trip in chunk) {
      final failed = await _handleFailure(effForTrip[trip.id]!, e);
      hadFailure = hadFailure || failed;
    }
  }
}
```
**What changes:** after `liveTrips` is built (before the chunk loop), add one
batch call — `final breaksByTripId = await _tripBreaksDao.breaksForTripIds(
liveTrips.map((t) => t.id).toList());` — per RESEARCH.md's explicit
Don't-Hand-Roll guidance (avoid N calls to `breaksForTrip` inside the chunk
loop). Then `_api.syncTrips(chunk)`'s signature changes to accept the breaks
map (or a `List<({TripRow trip, List<TripBreakRow> breaks})>`) alongside
`chunk` — see `api_client.dart` pattern.

**Error-handling / retry classification** (unchanged, reuse as-is — lines
264-286, `_handleFailure`): the 400-poison-pill vs. 5xx-retryable branching
does not change; a new field that fails the backend's `.max(50)` breaks-array
zod check simply surfaces as a non-retryable `SyncException.http(400)` through
the EXISTING code path — no new error class needed.

---

### `lib/sync/api_client.dart` (service, request-response)

**Analog:** itself — existing 215-line file.

**Current `syncTrips` signature and body-build** (lines 130-141):
```dart
// Source: lib/sync/api_client.dart:130-141
Future<void> syncTrips(List<TripRow> trips) async {
  final body = jsonEncode({
    'trips': trips.map(TripSerializer.toJson).toList(),
  });
  await _send(
    (token) => _client.post(
      Uri.parse('$_baseUrl$kSyncTripsPath'),
      headers: _headers(token),
      body: body,
    ),
  );
}
```
**What changes:** signature becomes `syncTrips(List<TripRow> trips, Map<String,
List<TripBreakRow>> breaksByTripId)`; the tearoff `trips.map(TripSerializer.toJson)`
becomes `trips.map((t) => TripSerializer.toJson(t, breaksByTripId[t.id] ??
const [])).toList()` — exactly the ripple RESEARCH.md's Pitfall 3 calls out.

**Restore envelope-unwrap + per-trip mapping pattern** (lines 162-193,
`restoreTrips`):
```dart
// Source: lib/sync/api_client.dart:175-192
try {
  final decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) {
    throw const SyncException.transport();
  }
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
**What changes:** `TripSerializer.fromJson` now returns the trip companion
PLUS breaks (see trip_serializer pattern above); `restoreTrips()`'s return
type changes from `List<TripsCompanion>` to something carrying both — the
malformed-envelope error handling (`SyncException.transport()` for any decode/
cast failure) is REUSED verbatim; do not add a separate try/catch for the
breaks sub-parse — let a malformed break entry fall through to the same
catch-all (consistent with "never a raw exception" for this method).

**Error classification** (lines 23-62, `SyncException`) — unchanged, reuse
as-is; no new exception variant needed for this phase.

---

### `lib/sync/restore_controller.dart` (controller, request-response + CRUD)

**Analog:** itself — existing 207-line file, PLUS the transaction pattern from
`lib/features/tracking/services/tracking_service_controller.dart`.

**Current conflict-detection + insert flow** (lines 80-140, `restore()`):
```dart
// Source: lib/sync/restore_controller.dart:99-136
for (final cloud in companions) {
  bool isConflict = false;

  final sameUuidLocal = localById[cloud.id.value];
  if (sameUuidLocal != null) {
    if (_isDifferent(sameUuidLocal, cloud)) {
      conflicts.add(
        SameUuidConflict(localTrip: sameUuidLocal, cloudTrip: cloud),
      );
      isConflict = true;
    }
  } else if (cloud.startTime.present && cloud.endTime.present) {
    // ... overlap scan ...
  }

  if (!isConflict && sameUuidLocal == null) {
    nonConflicts.add(cloud);
  }
}

final inserted = await tripsDao.insertOrIgnoreTrips(nonConflicts);
```
**What changes (Open Question 2 in RESEARCH.md):** add a THIRD branch — when
`sameUuidLocal != null` AND `!_isDifferent(...)` (today this branch does
nothing) — check D-10/D-11 enrichment eligibility (local breaks empty AND
cloud has breaks, OR any of the 4 metadata fields is at local-default while
cloud carries a real value) and, if eligible, write via `TripsDao.updateTrip`
+ `TripBreaksDao.insertBreaks` inside a transaction, bypassing
`insertOrIgnoreTrips` (per RESEARCH.md's Open Question 3 recommendation: no
`enqueueUpdate` call — matches the ACTUAL undocumented behavior of the
existing `kConflictUseCloud` merge branch in `conflict_resolution_sheet.dart`,
which also calls `updateTrip` alone with no re-queue).

**`_isDifferent` field-by-field comparator** (lines 142-178) — this is the
D-07 exclusion point:
```dart
// Source: lib/sync/restore_controller.dart:142-178
bool _isDifferent(TripRow local, TripsCompanion cloud) {
  if (cloud.startTime.present &&
      !local.startTime.isAtSameMomentAs(cloud.startTime.value))
    return true;
  // ... 10 more field checks, INCLUDING totalPausedSeconds (:152-154),
  // directionSource (:160-162), isEdited (:172-173) — these three ALREADY
  // exist in this comparator from prior phases ...
  return false;
}
```
**What changes:** per D-07, REMOVE (or never add) `breaks`-array comparison
from this method, and DELETE the existing `totalPausedSeconds` (:152-154),
`directionSource` (:160-162), and `isEdited` (:172-173) checks — they
currently DO trigger same-UUID conflicts and must stop doing so. This is a
**subtraction**, exactly as RESEARCH.md's Don't-Hand-Roll table states — not a
new comparator.

**Transaction pattern to copy for new-trip insert-with-breaks** (source:
`lib/features/tracking/services/tracking_service_controller.dart:252-279`):
```dart
// Source: lib/features/tracking/services/tracking_service_controller.dart:252-279
await _database.transaction(() async {
  await _tripsDao.insertTrip(TripsCompanion.insert(/* ... */));
  final breakRows = _breakRowsFor(trip);
  if (breakRows.isNotEmpty) {
    await _tripBreaksDao.insertBreaks(breakRows);
  }
  await _syncQueueDao.enqueueCreate(trip.id);
});
```
Apply the same shape to restore's non-conflict insert path — per RESEARCH.md
Pitfall 2, decide at plan time whether this replaces the bulk
`insertOrIgnoreTrips` batch call entirely for trips-with-breaks (keeping bulk
insert only for breakless trips) or restructures into one multi-table
`batch()` call. **No enqueue call** on the restore-insert path (restore is a
download, never re-enqueues — matches the existing class doc: "Restore is a
DOWNLOAD: it NEVER enqueues sync_queue rows").

---

### `lib/sync/merge_resolution.dart` (NEW FILE — utility, pure function; D-06)

**Analog:** extracted directly from `lib/features/settings/widgets/conflict_resolution_sheet.dart`'s `_applyAll` (lines 28-82) — NOT a new pattern, a refactor-extraction.

**Source to extract from** (`_applyAll`'s merge branch, lines 47-73):
```dart
// Source: lib/features/settings/widgets/conflict_resolution_sheet.dart:47-73
} else if (action == kConflictMerge) {
  final localTrip = conflict.localTrip;
  final cloudTrip = conflict.cloudTrip;
  final selections = _mergeSelections[localTrip.id] ?? {};

  final merged = cloudTrip.copyWith(
    id: drift.Value(localTrip.id),
    startTime: (selections['startTime'] ?? 'local') == 'local'
        ? drift.Value(localTrip.startTime)
        : cloudTrip.startTime,
    endTime: (selections['endTime'] ?? 'local') == 'local'
        ? drift.Value(localTrip.endTime)
        : cloudTrip.endTime,
    durationSeconds: (selections['durationSeconds'] ?? 'local') == 'local'
        ? drift.Value(localTrip.durationSeconds)
        : cloudTrip.durationSeconds,
    distanceMeters: (selections['distanceMeters'] ?? 'local') == 'local'
        ? drift.Value(localTrip.distanceMeters)
        : cloudTrip.distanceMeters,
    direction: (selections['direction'] ?? 'local') == 'local'
        ? drift.Value(localTrip.direction)
        : cloudTrip.direction,
    updatedAt: drift.Value(DateTime.now().toUtc()),
  );
  await tripsDao.updateTrip(merged);
  resolvedCount++;
}
```
**D-06 sequencing:** first extract this AS-IS into a pure function (e.g.
`TripsCompanion resolveMerge(TripRow local, TripsCompanion cloud, Map<String,
String> selections)`), pin it with `test/unit/sync/merge_resolution_test.dart`
unit tests reproducing the CURRENT 5-field behavior, THEN add D-04 ride-along
rules: breaks + `totalPausedSeconds` follow whichever side won `startTime`/
`endTime` (i.e., reuse the SAME `selections['startTime']`/`selections['endTime']`
choice — no new selection key), `directionSource` follows the `direction`
selection, and `isEdited` is unconditionally forced `true` in the merge output
(Claude's discretion per D-04, since a merge is by definition user-touched
output).

**Note:** breaks themselves are NOT a `TripsCompanion` field — the pure
function's signature likely needs to also accept/return
`List<TripBreakRow>`/`List<TripBreaksCompanion>` for whichever side wins, and
the caller (`_applyAll`) writes them via `TripBreaksDao.deleteBreaksForTrip` +
`insertBreaks` inside a transaction (mirrors the existing full-edit pattern
documented in `trip_breaks_dao.dart:41-51`).

---

### `lib/features/settings/widgets/conflict_resolution_sheet.dart` (component, request-response)

**Analog:** itself — existing 220-line file.

**Imports pattern** (lines 1-7):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/sync/restore_conflict.dart';
import 'package:traevy/sync/restore_controller.dart';
import 'package:drift/drift.dart' as drift;
```
Add `import 'package:traevy/sync/merge_resolution.dart';`.

**`_applyAll` after extraction** — the merge branch (lines 47-73 above) is
replaced with a call to the extracted `resolveMerge(...)` function; the
`kConflictUseCloud` branch (lines 44-46) is UNCHANGED (still calls
`tripsDao.updateTrip(companion)` directly, no `enqueueUpdate` — confirmed
by RESEARCH.md's direct read, this is the precedent for D-10/D-11's
"bypass sync queue" decision).

**D-05 read-only breaks indicator placement** — insert alongside the existing
per-field `SegmentedButton` rows (lines 150-188, the `for (final field in [
'startTime', 'endTime', 'durationSeconds', 'distanceMeters', 'direction'])`
loop): add a plain `Text` row ABOVE or BELOW that loop, shown only
`if (conflict.localTrip's breaks differ from conflict.cloudTrip's breaks)` —
copy pattern mirrors the existing conditional `if (selectedAction ==
kConflictMerge)` block (line 140) that already gates extra UI on a condition.
No new `SegmentedButton`/toggle — per D-05, text only.

---

### `lib/database/tables/user_preferences_table.dart` (model, CRUD)

**Analog:** itself — existing 100-line file; copy the exact additive-column
doc-comment convention used for `homeLat`/`officeLat` etc. (lines 79-96).

**Pattern to copy** (lines 79-88, one additive nullable column with full
provenance doc comment):
```dart
// Source: lib/database/tables/user_preferences_table.dart:79-88
/// Saved Home latitude (Phase 21, D-01). Null = not set; single-row table.
///
/// PII-adjacent — this coordinate reveals where the user lives. NEVER log it
/// (T-21-03). Stored locally in Drift only; no sync field carries it.
/// Added by schema migration v5 → v6 (additive); existing rows read null.
RealColumn get homeLat => real().nullable()();
```
**What to add:** a new `IntColumn get backfillMarkerVersion => integer()
.withDefault(const Constant(0))();` (or similar) — using
`.withDefault(const Constant(...))` (NOT `.nullable()`) since D-03's "already
ran" check needs a comparable default value (0 = never run), mirroring the
`weeklyNotificationEnabled`/`autoPauseEnabled` boolean-default convention
(lines 54-64) more closely than the nullable Home/Office pattern.

---

### `lib/database/daos/trip_breaks_dao.dart` (model/DAO, batch)

**Analog:** itself — existing 62-line file; `breaksForTrip` is the direct
template for the new batch method.

**Pattern to copy** (lines 34-39):
```dart
// Source: lib/database/daos/trip_breaks_dao.dart:34-39
Future<List<TripBreakRow>> breaksForTrip(String tripId) {
  return (select(tripBreaks)
        ..where((b) => b.tripId.equals(tripId))
        ..orderBy([(b) => OrderingTerm.asc(b.startTime)]))
      .get();
}
```
**New method** (already specified in RESEARCH.md Code Examples verbatim —
copy directly):
```dart
Future<Map<String, List<TripBreakRow>>> breaksForTripIds(List<String> tripIds) async {
  if (tripIds.isEmpty) return {};
  final rows = await (select(tripBreaks)
        ..where((b) => b.tripId.isIn(tripIds))
        ..orderBy([(b) => OrderingTerm.asc(b.startTime)]))
      .get();
  final map = <String, List<TripBreakRow>>{};
  for (final row in rows) {
    map.putIfAbsent(row.tripId, () => []).add(row);
  }
  return map;
}
```

---

### `lib/database/daos/user_preferences_dao.dart` (model/DAO, CRUD)

**Analog:** itself — existing 287-line file; `setHasSeenOnboarding` (lines
232-251) is the direct template for a single-column marker upsert.

**Pattern to copy** (lines 244-251):
```dart
// Source: lib/database/daos/user_preferences_dao.dart:244-251
// ignore: avoid_positional_boolean_parameters
Future<void> setHasSeenOnboarding(bool value) {
  return into(userPreferences).insertOnConflictUpdate(
    UserPreferencesCompanion.insert(
      id: const Value<int>(_kUserPreferencesId),
      hasSeenOnboarding: Value<bool>(value),
    ),
  );
}
```
**What to add:** `Future<void> setBackfillMarkerVersion(int version)` following
this EXACT shape (single-column `insertOnConflictUpdate` targeting `id =
_kUserPreferencesId`), plus a `Future<int> getBackfillMarkerVersion()` reading
via the `getOrDefault()` pattern (lines 124-147) — add the new field to
`UserPreferencesValue`'s constructor/`.defaults()` factory (lines 21-57)
alongside the other 13 fields, matching the required-named-param convention.

---

### `lib/database/database.dart` (config, migration)

**Analog:** itself — existing 145-line file; the v5→v6 branch (lines 110-123)
is the direct template.

**Pattern to copy** (lines 40, 110-123):
```dart
// Source: lib/database/database.dart:40
int get schemaVersion => 6;   // → bump to 7

// Source: lib/database/database.dart:110-123
if (from < 6 && to >= 6) {
  // Phase 21 (D-01/D-02, T-21-01): additive-only v5 → v6 migration. Adds
  // four nullable Home/Office coordinate columns on user_preferences and
  // the trips.direction_source column (default 'time'). No UPDATE/DROP
  // touches existing rows, so every historical commute survives unchanged
  // and reads direction_source='time' with null coords (SC#5). Ordered
  // AFTER the from<5 branch so a v1..v5 install runs every branch in
  // sequence.
  await m.addColumn(userPreferences, userPreferences.homeLat);
  await m.addColumn(userPreferences, userPreferences.homeLng);
  await m.addColumn(userPreferences, userPreferences.officeLat);
  await m.addColumn(userPreferences, userPreferences.officeLng);
  await m.addColumn(trips, trips.directionSource);
}
```
**What to add:** `if (from < 7 && to >= 7) { await m.addColumn(userPreferences,
userPreferences.backfillMarkerVersion); }` — ordered AFTER the `from < 6`
branch, same additive-only, no UPDATE/DROP shape. Follow with the exact
migration-ceremony commands (from RESEARCH.md, sourced from
`.planning/phases/21-home-office-locations-geofence/21-01-PLAN.md:167-168`):
```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/database/database.dart drift_schemas/drift_schema_v7.json
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

---

### `lib/features/shell/main_shell.dart` (component/trigger, event-driven)

**Analog:** itself — existing 233-line file; the `AuthSignedIn` listener
(lines 160-165) is the D-02 backfill seam.

**Pattern to copy** (lines 160-165):
```dart
// Source: lib/features/shell/main_shell.dart:160-165
ref.listen<AuthState>(authStateProvider, (previous, next) {
  if (next is AuthSignedIn && !_hasRunAutoRestoreForCurrentSession) {
    _hasRunAutoRestoreForCurrentSession = true;
    _runAutoRestore();
  }
});
```
**What to add:** compose the backfill call into (or alongside) this SAME
listener callback — check the D-03 marker via
`ref.read(userPreferencesDaoProvider).getBackfillMarkerVersion()` against
`kBackfillMarkerVersion` (new constant), and if not yet run, call
`SyncQueueDao.enqueueUpdate(tripId)` for every local trip with non-default
metadata (D-01 query — new DAO method, e.g. `TripsDao.tripsWithNonDefaultMetadata()`),
then persist the marker via `setBackfillMarkerVersion(kBackfillMarkerVersion)`.
Per RESEARCH.md's explicit note: "compose so backfill and auto-restore don't
fight on sign-in" — sequence the backfill AFTER `_runAutoRestore()` completes
(the existing `_runAutoRestore` is `await`ed at lines 118 inside its own
async method), not as a second independent `ref.listen` callback that could
race pause/resume of uploads.

**`_runAutoRestore` full method for reference** (lines 110-144) — the
fire-and-forget / snackbar-feedback shape to mirror if the backfill also
needs user-facing feedback (likely silent per CONTEXT.md — no UI decision was
made for backfill, unlike restore):
```dart
// Source: lib/features/shell/main_shell.dart:110-118
Future<void> _runAutoRestore() async {
  ref.read(syncEngineProvider).pauseUploads();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(kAutoRestoreInProgress)),
    );
  }

  await ref.read(restoreControllerProvider.notifier).restore();
  // ...
```

---

### `lib/config/constants.dart` (config)

**Analog:** itself — existing 1213-line file; the Phase 24 block (lines
1171-1195) is the placement + doc-comment template for this phase's new
constants.

**Pattern to copy** (lines 1171-1195, section header + grouped constants):
```dart
// Source: lib/config/constants.dart:1171-1195
// ---------------------------------------------------------------------------
// Phase 24 — Automatic Cloud Sync & Restore
// ---------------------------------------------------------------------------

/// Auto-restore in-progress message
const String kAutoRestoreInProgress = 'Restoring your trips…';
...
const String kConflictResolutionTitle = 'Resolve Sync Conflicts';
const String kConflictKeepLocal = 'Keep local';
const String kConflictUseCloud = 'Use cloud';
```
**Existing related constants already in file (do not redefine):**
`kDirectionSourceManual`/`Geofence`/`Time` (lines 1109/1113/1121),
`kMaxSyncBatchTrips` (line 871), `kConflictMerge` (line 1195).

**New constants to add**, in a new `// Phase 26 — Sync Breaks & Edit Metadata
to Cloud` section: `kMaxBreaksPerTrip` (int, e.g. 50 — mirrors the backend's
`kMaxBreaksPerTrip` in `validation.ts`, must be numerically identical),
`kBackfillMarkerVersion` (int, e.g. 2 — "backfill done for payload schema
v2"), and the D-05 breaks-indicator copy string (e.g. `kConflictBreaksDiffer
Template`).

---

### `backend/functions/src/utils/validation.ts` (utility, request-response validation)

**Analog:** itself — existing 62-line file.

**Full current `tripSchema`** (lines 25-39):
```typescript
// Source: backend/functions/src/utils/validation.ts:25-39
export const tripSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().optional(),
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
  durationSeconds: z.number().int().nonnegative(),
  distanceMeters: z.number().nonnegative(),
  routePolyline: z.string().max(kMaxRoutePolylineChars).nullable(),
  direction: z.enum(['to_office', 'to_home']),
  timeMovingSeconds: z.number().int().nonnegative(),
  timeStuckSeconds: z.number().int().nonnegative(),
  isManualEntry: z.boolean(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
});
```
**What to add** (RESEARCH.md Code Examples, verified against pinned zod
^4.4.3 — `.default()` alone, no `.optional()` needed per Pitfall 1):
```typescript
export const kMaxBreaksPerTrip = 50;

const tripBreakSchema = z.object({
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
});

// added to tripSchema:
totalPausedSeconds: z.number().int().nonnegative().default(0),
isEdited: z.boolean().default(false),
directionSource: z.enum(['manual', 'geofence', 'time']).default('time'),
breaks: z.array(tripBreakSchema).max(kMaxBreaksPerTrip).default([]),
```
**Enum values MUST match** `kDirectionSourceManual`/`Geofence`/`Time` exactly
(`'manual'`/`'geofence'`/`'time'`) from `lib/config/constants.dart:1109-1121` —
Pitfall 4 warns a typo here silently poison-pills every sync.

---

### `backend/functions/src/types/trip.ts` (model, TS interfaces)

**Analog:** itself — existing 43-line file.

**Full current `Trip`/`TripDoc`** (lines 18-43):
```typescript
// Source: backend/functions/src/types/trip.ts:18-43
export interface Trip {
  id: string;
  userId: string;
  startTime: string;
  endTime: string;
  durationSeconds: number;
  distanceMeters: number;
  routePolyline: string | null;
  direction: Direction;
  timeMovingSeconds: number;
  timeStuckSeconds: number;
  isManualEntry: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface TripDoc extends Trip {
  deleted: boolean;
  deletedAt: Timestamp | null;
  serverUpdatedAt: Timestamp;
}
```
**What to add to `Trip`** (strict TS, no `any` per CLAUDE.md):
```typescript
export type DirectionSource = 'manual' | 'geofence' | 'time';
export interface TripBreak {
  startTime: string;
  endTime: string;
}
// added fields:
totalPausedSeconds: number;
isEdited: boolean;
directionSource: DirectionSource;
breaks: TripBreak[];
```
`TripDoc` inherits these automatically via `extends Trip` — no separate edit
needed there.

---

### `backend/functions/src/utils/firestore.ts` (utility, transform / defaulting)

**Analog:** itself — existing 74-line file; `fromFirestore`'s existing
field-by-field `?? default` pattern (lines 45-65) is the exact template
(RESEARCH.md Pattern 2 — this is the ONLY correct place for read-side
defaulting, NOT the handler).

**Full current `fromFirestore`** (lines 43-66):
```typescript
// Source: backend/functions/src/utils/firestore.ts:43-66
fromFirestore: (snapshot: QueryDocumentSnapshot): TripDoc => {
  const data = snapshot.data();
  return {
    id: data.id as string,
    userId: data.userId as string,
    startTime: toIsoString(data.startTime),
    endTime: toIsoString(data.endTime),
    durationSeconds: data.durationSeconds as number,
    distanceMeters: data.distanceMeters as number,
    routePolyline: (data.routePolyline as string | null) ?? null,
    direction: data.direction as Direction,
    timeMovingSeconds: data.timeMovingSeconds as number,
    timeStuckSeconds: data.timeStuckSeconds as number,
    isManualEntry: data.isManualEntry as boolean,
    createdAt: toIsoString(data.createdAt),
    updatedAt: toIsoString(data.updatedAt),
    deleted: data.deleted as boolean,
    deletedAt: toNullableTimestamp(data.deletedAt),
    serverUpdatedAt:
      data.serverUpdatedAt instanceof Timestamp
        ? data.serverUpdatedAt
        : Timestamp.now(),
  };
},
```
**What to add**, following the SAME `(data.field as Type | undefined) ??
default` shape already used for `routePolyline` (line 52):
```typescript
totalPausedSeconds: (data.totalPausedSeconds as number | undefined) ?? 0,
isEdited: (data.isEdited as boolean | undefined) ?? false,
directionSource: (data.directionSource as DirectionSource | undefined) ?? 'time',
breaks: (data.breaks as TripBreak[] | undefined) ?? [],
```
This is SC4's implementation point (old docs restore cleanly with defaults) —
do NOT add a zod parse here; zod never runs on the restore/read path
(RESEARCH.md Anti-Pattern).

---

### `backend/functions/src/handlers/sync-trips.ts` (controller, request-response)

**Analog:** itself — existing 98-line file.

**Verify → validate → trust structure** (lines 37-56):
```typescript
// Source: backend/functions/src/handlers/sync-trips.ts:37-56
export async function syncTripsHandler(
  req: Request,
  res: Response,
): Promise<void> {
  let uid: string;
  try {
    uid = await verifyAuth(req);
  } catch (err) {
    const status = err instanceof AuthError ? err.statusCode : 401;
    res.status(status).json({ statusCode: status, body: { error: 'Unauthorized' } });
    return;
  }

  const parsed = syncTripsBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ statusCode: 400, body: { error: 'Invalid request body' } });
    return;
  }

  const { trips } = parsed.data;
```

**Doc-literal write pattern** (lines 66-88 — this is the extension point):
```typescript
// Source: backend/functions/src/handlers/sync-trips.ts:66-88
const doc: WithFieldValue<TripDoc> = {
  id: trip.id,
  userId: uid,
  startTime: trip.startTime,
  endTime: trip.endTime,
  durationSeconds: trip.durationSeconds,
  distanceMeters: trip.distanceMeters,
  routePolyline: trip.routePolyline,
  direction: trip.direction,
  timeMovingSeconds: trip.timeMovingSeconds,
  timeStuckSeconds: trip.timeStuckSeconds,
  isManualEntry: trip.isManualEntry,
  createdAt: trip.createdAt,
  updatedAt: trip.updatedAt,
  // `deleted:false` is deliberate (D-11, client-authoritative): re-syncing
  // an id resurrects a server-soft-deleted trip. ...
  deleted: false,
  deletedAt: null,
  serverUpdatedAt: FieldValue.serverTimestamp(),
};
batch.set(collection.doc(trip.id), doc, { merge: true });
```
**What to add:** four more lines inside the `doc` literal —
`totalPausedSeconds: trip.totalPausedSeconds`, `isEdited: trip.isEdited`,
`directionSource: trip.directionSource`, `breaks: trip.breaks` — read
directly off `trip` (the already-validated, already-defaulted zod output; per
Pattern 3, `.default()` guarantees these are never `undefined` here, so NO
additional `??` needed on this write path).

---

### `backend/functions/src/handlers/restore-trips.ts` (controller, request-response)

**Analog:** itself — existing 70-line file.

**Trip-projection pattern** (lines 42-64 — the extension point):
```typescript
// Source: backend/functions/src/handlers/restore-trips.ts:42-64
const trips: Trip[] = snap.docs.map((docSnap) => {
  const doc: TripDoc = docSnap.data();
  return {
    id: doc.id,
    userId: doc.userId,
    startTime: doc.startTime,
    endTime: doc.endTime,
    durationSeconds: doc.durationSeconds,
    distanceMeters: doc.distanceMeters,
    routePolyline: doc.routePolyline,
    direction: doc.direction,
    timeMovingSeconds: doc.timeMovingSeconds,
    timeStuckSeconds: doc.timeStuckSeconds,
    isManualEntry: doc.isManualEntry,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
});
```
**What to add:** four more lines in the returned object literal —
`totalPausedSeconds: doc.totalPausedSeconds`, `isEdited: doc.isEdited`,
`directionSource: doc.directionSource`, `breaks: doc.breaks` — sourced from
`doc` (already defaulted by `tripConverter.fromFirestore`, per the Pattern 2
seam above; NO additional defaulting logic belongs in this handler).

---

## Shared Patterns

### Atomic parent+children Drift write (D-06/D-10 transaction shape)
**Source:** `lib/features/tracking/services/tracking_service_controller.dart:252-279`
**Apply to:** `restore_controller.dart`'s new-trip insert-with-breaks path,
the D-10/D-11 enrichment write path, and `merge_resolution.dart`'s caller
(the merge branch of `_applyAll` writing breaks for the winning side).
```dart
await _database.transaction(() async {
  await _tripsDao.insertTrip(TripsCompanion.insert(/* ... */));
  final breakRows = _breakRowsFor(trip);
  if (breakRows.isNotEmpty) {
    await _tripBreaksDao.insertBreaks(breakRows);
  }
  await _syncQueueDao.enqueueCreate(trip.id);
});
```

### Verify → validate → trust (backend handler entry)
**Source:** `backend/functions/src/handlers/sync-trips.ts:41-56`
**Apply to:** No new handlers this phase (only extending sync-trips.ts and
restore-trips.ts in place) — this pattern is already correctly applied in
both touched handlers; do not duplicate the auth/validation gate deeper in
either file.

### Field-by-field defaulting on Firestore read
**Source:** `backend/functions/src/utils/firestore.ts:43-66` (`tripConverter.fromFirestore`)
**Apply to:** `firestore.ts` itself (the 4 new fields), and nowhere else —
do NOT re-implement defaulting in `restore-trips.ts`.

### Sealed-state / no-raw-strings for control flow
**Source:** `lib/sync/restore_controller.dart:12-49` (`RestoreState` sealed
class), `lib/sync/restore_conflict.dart:5-30` (`RestoreConflict` sealed class)
**Apply to:** Any NEW finite-state introduced for backfill status tracking
(if the plan adds one) — the 4 new metadata wire fields themselves are plain
data, not state, and do not need a sealed wrapper.

### Constants-only, no hardcoded values
**Source:** `lib/config/constants.dart:1171-1195` (Phase 24 block) and
`:1109-1121` (`kDirectionSource*`)
**Apply to:** `kMaxBreaksPerTrip`, `kBackfillMarkerVersion`, and the D-05
indicator copy string — all new constants land in `constants.dart`, matching
every other threshold/label in the file (no literal `50`, no literal version
int, no literal copy string in `merge_resolution.dart`, `restore_controller.dart`,
`main_shell.dart`, or `conflict_resolution_sheet.dart`).

### Single-column marker upsert (D-03 backfill marker)
**Source:** `lib/database/daos/user_preferences_dao.dart:244-251` (`setHasSeenOnboarding`)
**Apply to:** New `setBackfillMarkerVersion`/`getBackfillMarkerVersion` in
`user_preferences_dao.dart`.

## No Analog Found

None — every file in this phase is either an existing file being extended in
place, or a genuinely new file (`merge_resolution.dart`, two new test files)
with a direct, explicit in-repo extraction/precedent source already covered
above. RESEARCH.md's own analysis independently reached the same conclusion
("Every piece of this phase has a direct structural precedent already in the
codebase").

## Metadata

**Analog search scope:** `lib/sync/`, `lib/database/`, `lib/features/settings/widgets/`,
`lib/features/shell/`, `lib/features/tracking/services/`, `lib/config/`,
`backend/functions/src/` (all subdirectories)
**Files scanned:** 18 source files read directly this session (all listed in
File Classification above), plus targeted greps of `trips_dao.dart`,
`sync_queue_dao.dart`
**Pattern extraction date:** 2026-07-12
