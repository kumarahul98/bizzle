import 'package:drift/drift.dart';
import 'package:traevy/database/database.dart';

/// Result of [resolveMerge]: the merged trip companion plus the winning
/// side's break segments.
///
/// D-06 step 1 (this file's first shape): `breaks` is always the empty
/// list — this task's ONLY job is extracting the pre-existing 5-field
/// `_applyAll` merge logic into a pure, independently-testable function and
/// pinning its CURRENT behavior. D-04's breaks/metadata ride-along rules are
/// added on top in Plan 06 Task 2, not here.
typedef MergeResult = ({TripsCompanion trip, List<TripBreaksCompanion> breaks});

/// Pure per-field merge resolution for a sync conflict.
///
/// Extracted verbatim from `ConflictResolutionSheet._applyAll`'s Merge
/// branch (D-06 step 1: extract first, pin the CURRENT behavior with unit
/// tests, THEN add new rules in a later step). Every one of the five
/// mergeable fields (`startTime`, `endTime`, `durationSeconds`,
/// `distanceMeters`, `direction`) independently resolves to [local]'s value
/// when `selections[field]` is absent or explicitly `'local'` (the 25.1-02
/// default, preserved byte-for-byte), and to [cloud]'s value otherwise. The
/// merged companion's `id` always remaps to [local]'s id — the merged row is
/// always written under the LOCAL trip's id, never the cloud copy's original
/// id — and `updatedAt` is stamped with a fresh timestamp.
MergeResult resolveMerge({
  required TripRow local,
  required TripsCompanion cloud,
  required Map<String, String> selections,
}) {
  final merged = cloud.copyWith(
    id: Value(local.id),
    startTime: (selections['startTime'] ?? 'local') == 'local'
        ? Value(local.startTime)
        : cloud.startTime,
    endTime: (selections['endTime'] ?? 'local') == 'local'
        ? Value(local.endTime)
        : cloud.endTime,
    durationSeconds: (selections['durationSeconds'] ?? 'local') == 'local'
        ? Value(local.durationSeconds)
        : cloud.durationSeconds,
    distanceMeters: (selections['distanceMeters'] ?? 'local') == 'local'
        ? Value(local.distanceMeters)
        : cloud.distanceMeters,
    direction: (selections['direction'] ?? 'local') == 'local'
        ? Value(local.direction)
        : cloud.direction,
    updatedAt: Value(DateTime.now().toUtc()),
  );
  return (trip: merged, breaks: const <TripBreaksCompanion>[]);
}
