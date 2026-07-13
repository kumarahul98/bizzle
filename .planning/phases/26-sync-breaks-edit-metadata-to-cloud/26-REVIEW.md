---
phase: 26-sync-breaks-edit-metadata-to-cloud
reviewed: 2026-07-13T02:34:54Z
depth: standard
files_reviewed: 26
files_reviewed_list:
  - backend/functions/src/handlers/restore-trips.ts
  - backend/functions/src/handlers/sync-trips.ts
  - backend/functions/src/types/trip.ts
  - backend/functions/src/utils/firestore.ts
  - backend/functions/src/utils/validation.ts
  - backend/functions/src/utils/__tests__/validation.test.ts
  - backend/functions/test/handlers/restore-trips.test.ts
  - backend/functions/test/handlers/sync-trips.test.ts
  - backend/functions/test/helpers/emulator.ts
  - backend/functions/test/helpers/fixtures.ts
  - lib/config/constants.dart
  - lib/database/daos/trip_breaks_dao.dart
  - lib/database/daos/trips_dao.dart
  - lib/database/daos/user_preferences_dao.dart
  - lib/database/database.dart
  - lib/database/tables/user_preferences_table.dart
  - lib/features/settings/screens/settings_screen.dart
  - lib/features/settings/widgets/conflict_resolution_sheet.dart
  - lib/features/shell/main_shell.dart
  - lib/sync/api_client.dart
  - lib/sync/merge_resolution.dart
  - lib/sync/restore_conflict.dart
  - lib/sync/restore_controller.dart
  - lib/sync/sync_engine.dart
  - lib/sync/trip_serializer.dart
  - test/widget/features/settings/conflict_resolution_sheet_test.dart
findings:
  critical: 0
  warning: 1
  info: 5
  total: 6
status: issues_found
resolved:
  - WR-01 (fixed in commit b7727ca — open breaks filtered before serialize; regression test added)
---

# Phase 26: Code Review Report

**Reviewed:** 2026-07-13T02:34:54Z
**Depth:** standard
**Files Reviewed:** 26
**Status:** issues_found

## Summary

Phase 26 extends the trip sync contract to carry break segments, paused total,
the edited flag, and direction source so a cloud restore reproduces a trip
exactly. The implementation is careful and well-documented: the phase invariants
called out in the brief all hold up under review.

Verified sound:
- **Break cap parity.** `kMaxBreaksPerTrip = 50` (constants.dart) matches the
  backend zod `.max(50)` (validation.ts). `TripSerializer.toJson` truncates
  oldest-first via `.take(kMaxBreaksPerTrip)`, so the client can never emit a
  payload the backend would 400 on — the poison-pill path is closed.
- **Restore split-path.** Breakless new trips use the bulk
  `insertOrIgnoreTrips`; trips with breaks insert trip + breaks in one
  `db.transaction()`. Same-UUID metadata differences are excluded from
  `_isDifferent` (D-07), so no conflict-prompt storm on first post-upgrade
  restore. Enrichment adopts cloud values only where local is default/empty and
  never enqueues.
- **Merge.** `resolveMerge` is a pure function; breaks + `totalPausedSeconds`
  follow the `startTime` winner, `directionSource` follows `direction`, breaks
  are always rebuilt under the LOCAL trip id with fresh UUIDs, and writes are
  transactional. Per-field defaults are `'local'`. Merge-All ≡ Keep-All-Local is
  the accepted behavior (not flagged).
- **Backfill.** Marker-guarded exactly-once, runs after auto-restore, silent,
  stamps the marker only after the enqueue loop; a partial failure leaves the
  marker unstamped so it retries.
- **Backend.** verify → zod → trust; `userId` forced from token; the converter
  defaults the four new fields for legacy docs on read.
- **Migration.** v6 → v7 is additive-only, `to`-guarded, with a passing
  additive-migration test.

The findings below are one latent robustness gap (a non-`SyncException` thrown
during serialization would bypass the drain's poison-pill handling) plus minor
quality items. No data-loss or security issues were found.

## Warnings

### WR-01: A break with a null `endTime` throws a non-`SyncException` that bypasses drain failure handling

**RESOLVED** (commit `b7727ca`): `TripSerializer.toJson` now filters open
(null-`endTime`) breaks via `.where((b) => b.endTime != null)` before the cap,
making the `endTime!` provably safe — an open break degrades to "skipped"
instead of throwing. Regression test `toJson skips open (null-endTime) breaks
instead of throwing (WR-01)` added to `trip_serializer_test.dart`.

**File:** `lib/sync/trip_serializer.dart:72` (and `lib/sync/sync_engine.dart:230-240`)
**Issue:** `TripSerializer.toJson` dereferences `b.endTime!`. The map is built
synchronously inside `ApiClient.syncTrips` (`jsonEncode({...trips.map(toJson)})`)
before the HTTP call. If any break in the chunk has a null `endTime`, the `!`
throws a plain `TypeError` — not a `SyncException`. In `SyncEngine._drain` the
call is wrapped only by `on SyncException catch`, so the raw error escapes the
chunk loop, propagates out of `_drain`, and is swallowed by
`processPending`'s `on Object` catch-all (which just sets a generic
`SyncFailed`). None of the rows in that chunk are `markFailed`/`markSynced`, so
they stay `pending` and the *entire chunk* re-throws on every subsequent drain —
a silent wedge, never a terminal poison-pill.

This is gated in practice (finalize closes every break; only finalized trips are
enqueued or restored), so it is latent rather than active — hence Warning, not
Critical. But the `!` turns a data-shape surprise into an unbounded retry loop
that affects unrelated trips sharing the chunk.

**Fix:** Make the open-break case explicit and non-fatal rather than relying on
`!`. Either skip open breaks during serialization:
```dart
'breaks': breaks
    .where((b) => b.endTime != null)
    .take(kMaxBreaksPerTrip)
    .map((b) => <String, dynamic>{
          'startTime': b.startTime.toUtc().toIso8601String(),
          'endTime': b.endTime!.toUtc().toIso8601String(),
        })
    .toList(),
```
or, at minimum, broaden the drain guard so a serialization error is classified
as a non-retryable failure and `markFailed`'d per-trip instead of wedging the
chunk (e.g. wrap the `toJson` mapping and rethrow as
`SyncException.http(400)`-equivalent).

## Info

### IN-01: Restored non-conflicting trips are not counted when conflicts coexist

**File:** `lib/sync/restore_controller.dart:175-191`, `326`
**Issue:** When a restore batch contains both new non-conflicting trips and
conflicts, the non-conflicting trips are inserted (correct), but the branch
`if (conflicts.isNotEmpty) { state = RestoreConflictState(...) }` discards the
`inserted` count. After the user resolves conflicts, `resolveConflicts(resolvedCount)`
reports only the resolved count. The trips silently inserted before the conflict
sheet are never reflected in the "Restored N trips" snackbar, so the count can
under-report. Data is correct; only the user-facing tally is off.
**Fix:** Carry `inserted` into `RestoreConflictState` and add it to
`resolvedCount` when transitioning to `RestoreSuccess`, or surface the pre-insert
count separately.

### IN-02: `_isDifferent` uses multi-line `if` bodies without braces

**File:** `lib/sync/restore_controller.dart:278-306`
**Issue:** Every guard is written as `if (cond)\n  return true;` with no braces
across lines. Under `very_good_analysis` (listed in the project stack), the
`curly_braces_in_flow_control_structures` rule flags exactly this shape.
Depending on the active analysis_options this may already emit `flutter analyze`
warnings.
**Fix:** Wrap each body in braces, e.g. `if (cond) { return true; }`.

### IN-03: Debug `print()` statements left in a widget test

**File:** `test/widget/features/settings/conflict_resolution_sheet_test.dart:160,163,166,169,172`
**Issue:** The first test contains `print('pumpWidget')`, `print('tap Open')`,
`print('expect title')`, etc. — leftover debugging noise that clutters test
output and would trip `avoid_print`.
**Fix:** Remove the `print(...)` calls.

### IN-04: Merge field names duplicated as magic strings across two files

**File:** `lib/features/settings/widgets/conflict_resolution_sheet.dart:186-192` and `lib/sync/merge_resolution.dart:40-75`
**Issue:** The mergeable-field keys (`'startTime'`, `'endTime'`,
`'durationSeconds'`, `'distanceMeters'`, `'direction'`) are hardcoded string
literals in both the sheet's selection UI and `resolveMerge`'s `selections`
lookups. A rename in one place silently desyncs the other (a wrong key just
falls through to the `'local'` default with no error).
**Fix:** Extract the field keys to shared constants (e.g. in `constants.dart` or
a small enum) referenced by both the widget and `resolveMerge`.

### IN-05: Two overlapping restore-controller test files

**File:** `test/sync/restore_controller_test.dart` and `test/unit/sync/restore_controller_test.dart`
**Issue:** Two separate restore-controller suites exist with their own
`FakeApiClient`/`FakeTripsDao` scaffolding. The `test/unit/sync` one is the
richer Phase 26 suite; `test/sync` is an older, thinner variant. Maintaining both
risks divergence and duplicated fixtures.
**Fix:** Consolidate into the `test/unit/sync` suite (or clarify why the split is
intentional) and delete the redundant file.

---

_Reviewed: 2026-07-13T02:34:54Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
