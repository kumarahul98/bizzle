import 'package:drift/drift.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/tables/trip_stuck_segments_table.dart';

part 'trip_stuck_segments_dao.g.dart';

/// Data-access object for the `trip_stuck_segments` table (Phase 31, D-02).
///
/// Writes are finalize-time and batch-oriented, mirroring `TripBreaksDao`: the
/// accumulator collapses the run classification in memory and the persist path
/// inserts every segment in ONE batch inside the trip's transaction. There is
/// no incremental persistence, so an abandoned recording leaves no orphan
/// segment rows.
///
/// The `tripId` FK to `trips.id` is enforced by `PRAGMA foreign_keys = ON`, so
/// [insertSegments] for a trip that does not exist throws.
@DriftAccessor(tables: [TripStuckSegments])
class TripStuckSegmentsDao extends DatabaseAccessor<AppDatabase>
    with _$TripStuckSegmentsDaoMixin {
  /// Bind the DAO to its parent `AppDatabase`.
  TripStuckSegmentsDao(super.attachedDatabase);

  /// Insert every stuck segment for a finalized trip in ONE batch. The parent
  /// trip row MUST already exist or the FK constraint rejects the insert.
  Future<void> insertSegments(List<TripStuckSegmentsCompanion> rows) {
    return batch((b) => b.insertAll(tripStuckSegments, rows));
  }

  /// Delete only the segments of [tripId] that fall WHOLLY outside the new
  /// `[startTimeUtc, endTimeUtc]` window — the parts of the recording the
  /// user cut away by editing the trip's times.
  ///
  /// A segment is deleted only when `segment.endTime <= startTimeUtc` OR
  /// `segment.startTime >= endTimeUtc`; anything else — any segment
  /// overlapping the window at all — is retained. A retained segment is kept
  /// ENTIRELY UNTOUCHED: its `startTime`/`endTime` are NOT clamped to the new
  /// window, because its `startPointIndex`/`endPointIndex` address the
  /// original decoded polyline, and the polyline itself is never edited.
  /// Clamping the timestamps without also clamping the geometry would
  /// misreport which stretch of road was actually slow, so partial overflow
  /// past a window edge is the honest, lesser evil.
  Future<void> deleteSegmentsOutsideWindow({
    required String tripId,
    required DateTime startTimeUtc,
    required DateTime endTimeUtc,
  }) {
    return (delete(tripStuckSegments)..where(
          (s) =>
              s.tripId.equals(tripId) &
              (s.endTime.isSmallerOrEqualValue(startTimeUtc) |
                  s.startTime.isBiggerOrEqualValue(endTimeUtc)),
        ))
        .go();
  }

  /// Delete EVERY stuck segment for [tripId].
  ///
  /// Narrowly scoped to conflict resolution, where the trip's
  /// `routePolyline` itself is replaced by the cloud copy's. A segment's
  /// `startPointIndex`/`endPointIndex` address the polyline they were computed
  /// from, so once the polyline changes the existing segments are not stale —
  /// they are meaningless, and rendering them would paint the wrong stretch of
  /// road as slow.
  ///
  /// Do NOT reach for this from the trip-EDIT path. Editing a trip's times
  /// leaves the polyline untouched, so its segments stay valid; that path uses
  /// [deleteSegmentsOutsideWindow], which drops only what fell outside the new
  /// window. Wiping segments on edit was a real bug once — it is what
  /// [deleteSegmentsOutsideWindow] exists to prevent.
  Future<void> deleteSegmentsForTrip(String tripId) {
    return (delete(
      tripStuckSegments,
    )..where((s) => s.tripId.equals(tripId))).go();
  }

  /// All stuck segments for [tripId], ordered by `startPointIndex` ascending.
  ///
  /// The one-shot counterpart to [watch], used by the sync serializer. Mirrors
  /// `TripBreaksDao.breaksForTrip`.
  Future<List<TripStuckSegmentRow>> segmentsForTrip(String tripId) {
    return (select(tripStuckSegments)
          ..where((s) => s.tripId.equals(tripId))
          ..orderBy([(s) => OrderingTerm.asc(s.startPointIndex)]))
        .get();
  }

  /// All stuck segments for every trip in [tripIds], keyed by `tripId` and
  /// ordered by `startPointIndex` ascending within each trip's list.
  ///
  /// A single `WHERE tripId IN (...)` query grouped client-side, mirroring
  /// `TripBreaksDao.breaksForTripIds` — avoids the N+1 of calling
  /// [segmentsForTrip] once per trip while draining the sync queue. An empty
  /// [tripIds] short-circuits to `{}` without touching the database.
  Future<Map<String, List<TripStuckSegmentRow>>> segmentsForTripIds(
    List<String> tripIds,
  ) async {
    if (tripIds.isEmpty) return {};
    final rows =
        await (select(tripStuckSegments)
              ..where((s) => s.tripId.isIn(tripIds))
              ..orderBy([(s) => OrderingTerm.asc(s.startPointIndex)]))
            .get();
    final result = <String, List<TripStuckSegmentRow>>{};
    for (final row in rows) {
      result.putIfAbsent(row.tripId, () => []).add(row);
    }
    return result;
  }

  /// Reactive stream of stuck segments for [tripId], ordered by
  /// `startPointIndex` ascending — which is also chronological order, because
  /// polyline point order is sample order.
  ///
  /// Emits an empty list for a manual entry or any trip recorded before
  /// Phase 31; callers render those exactly as they did before that phase
  /// (D-06). Restored trips USED to be in that list too — segments were
  /// device-only until they were added to the wire contract, so a reinstall
  /// silently dropped every painted stretch.
  Stream<List<TripStuckSegmentRow>> watch(String tripId) {
    return (select(tripStuckSegments)
          ..where((s) => s.tripId.equals(tripId))
          ..orderBy([(s) => OrderingTerm.asc(s.startPointIndex)]))
        .watch();
  }
}
