import 'package:drift/drift.dart';
import 'package:traevy/database/database.dart';
import 'package:uuid/uuid.dart';

/// Result of [resolveMerge]: the merged trip companion, the winning side's
/// break segments (D-04 ride-along: breaks travel with whichever side won the
/// `startTime`/`endTime` fields), and the stuck segments that are
/// index-coherent with the merged trip's polyline.
typedef MergeResult = ({
  TripsCompanion trip,
  List<TripBreaksCompanion> breaks,
  List<TripStuckSegmentsCompanion> stuckSegments,
});

/// Pure per-field merge resolution for a sync conflict.
///
/// Extracted from `ConflictResolutionSheet._applyAll`'s Merge branch (D-06
/// step 1: extract first, pin the CURRENT 5-field behavior with unit tests,
/// THEN add the D-04 ride-along rules — this is the step-2 shape). Every one
/// of the five mergeable fields (`startTime`, `endTime`, `durationSeconds`,
/// `distanceMeters`, `direction`) independently resolves to [local]'s value
/// when `selections[field]` is absent or explicitly `'local'` (the 25.1-02
/// default, preserved byte-for-byte), and to [cloud]'s value otherwise. The
/// merged companion's `id` always remaps to [local]'s id — the merged row is
/// always written under the LOCAL trip's id, never the cloud copy's original
/// id — and `updatedAt` is stamped with a fresh timestamp.
///
/// D-04 ride-along rules (added on top of the pinned 5-field contract):
///   * `breaks` follow whichever side won `startTime` — REUSES the same
///     resolved boolean the `startTime` ternary above already computes, so a
///     break can never fall outside the merged trip's time window. Every
///     output break is rebuilt with a fresh UUID and `tripId` remapped to
///     [local]'s id (never the losing/original side's id — see T-26-16).
///   * `totalPausedSeconds` follows the SAME side as `startTime`'s winner.
///   * `directionSource` follows the `direction` field's own selection.
///   * `isEdited` is ALWAYS `true` in merge output (Claude's discretion,
///     documented in CONTEXT.md D-04: merged output is user-touched).
///
/// Stuck segments deliberately do NOT follow the `startTime` ride-along rule
/// that breaks use. A break is defined purely by timestamps, so it is valid
/// against any trip whose window contains it. A stuck segment additionally
/// carries `startPointIndex`/`endPointIndex`, which address the DECODED
/// `routePolyline` — and the merged trip's polyline always comes from [cloud],
/// because `routePolyline` is not a selectable field and `merged` is built
/// with `cloud.copyWith(...)`. Handing back local segments whose indices were
/// computed against a different polyline would paint the wrong stretch of road
/// as slow, which is a visible lie about the one thing this app measures. So:
///   * cloud segments are used whenever present — always index-coherent;
///   * otherwise local segments are used ONLY if the local polyline is
///     identical to the merged one, which makes their indices equally valid
///     (the common case: same recording, same geometry — and the case that
///     matters right after this field shipped, when local trips have segments
///     but their cloud copies do not yet);
///   * otherwise none, because there is no honest way to place them.
MergeResult resolveMerge({
  required TripRow local,
  required TripsCompanion cloud,
  required Map<String, String> selections,
  List<TripBreakRow> localBreaks = const [],
  List<TripBreaksCompanion> cloudBreaks = const [],
  List<TripStuckSegmentRow> localStuckSegments = const [],
  List<TripStuckSegmentsCompanion> cloudStuckSegments = const [],
}) {
  final useLocalTime = (selections['startTime'] ?? 'local') == 'local';
  final useLocalDirection = (selections['direction'] ?? 'local') == 'local';

  final List<TripBreaksCompanion> winningBreaks = useLocalTime
      ? [
          for (final b in localBreaks)
            TripBreaksCompanion.insert(
              id: const Uuid().v4(),
              tripId: local.id,
              startTime: b.startTime,
              endTime: Value<DateTime?>(b.endTime),
            ),
        ]
      : [
          for (final b in cloudBreaks)
            TripBreaksCompanion.insert(
              id: const Uuid().v4(),
              tripId: local.id,
              startTime: b.startTime.value,
              endTime: b.endTime,
            ),
        ];

  final merged = cloud.copyWith(
    id: Value(local.id),
    startTime: useLocalTime ? Value(local.startTime) : cloud.startTime,
    endTime: (selections['endTime'] ?? 'local') == 'local'
        ? Value(local.endTime)
        : cloud.endTime,
    durationSeconds: (selections['durationSeconds'] ?? 'local') == 'local'
        ? Value(local.durationSeconds)
        : cloud.durationSeconds,
    distanceMeters: (selections['distanceMeters'] ?? 'local') == 'local'
        ? Value(local.distanceMeters)
        : cloud.distanceMeters,
    direction: useLocalDirection ? Value(local.direction) : cloud.direction,
    totalPausedSeconds: useLocalTime
        ? Value(local.totalPausedSeconds)
        : (cloud.totalPausedSeconds.present
              ? cloud.totalPausedSeconds
              : Value(local.totalPausedSeconds)),
    directionSource: useLocalDirection
        ? Value(local.directionSource)
        : (cloud.directionSource.present
              ? cloud.directionSource
              : Value(local.directionSource)),
    isEdited: const Value(true),
    updatedAt: Value(DateTime.now().toUtc()),
  );

  // `merged` carries cloud's polyline (see the dartdoc above), so cloud
  // segments are index-coherent by construction; local ones only when the two
  // polylines are identical.
  final mergedPolyline = merged.routePolyline.present
      ? merged.routePolyline.value
      : null;
  final localGeometryMatches = local.routePolyline == mergedPolyline;

  final List<TripStuckSegmentsCompanion> winningStuckSegments;
  if (cloudStuckSegments.isNotEmpty) {
    winningStuckSegments = [
      for (final s in cloudStuckSegments)
        TripStuckSegmentsCompanion.insert(
          id: const Uuid().v4(),
          tripId: local.id,
          startPointIndex: s.startPointIndex.value,
          endPointIndex: s.endPointIndex.value,
          startTime: s.startTime.value,
          endTime: s.endTime.value,
        ),
    ];
  } else if (localGeometryMatches) {
    winningStuckSegments = [
      for (final s in localStuckSegments)
        TripStuckSegmentsCompanion.insert(
          id: const Uuid().v4(),
          tripId: local.id,
          startPointIndex: s.startPointIndex,
          endPointIndex: s.endPointIndex,
          startTime: s.startTime,
          endTime: s.endTime,
        ),
    ];
  } else {
    winningStuckSegments = const [];
  }

  return (
    trip: merged,
    breaks: winningBreaks,
    stuckSegments: winningStuckSegments,
  );
}
