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

  /// Reactive stream of stuck segments for [tripId], ordered by
  /// `startPointIndex` ascending — which is also chronological order, because
  /// polyline point order is sample order.
  ///
  /// Emits an empty list for a manual entry, a restored trip, or any trip
  /// recorded before Phase 31; callers render those exactly as they did
  /// before this phase (D-06).
  Stream<List<TripStuckSegmentRow>> watch(String tripId) {
    return (select(tripStuckSegments)
          ..where((s) => s.tripId.equals(tripId))
          ..orderBy([(s) => OrderingTerm.asc(s.startPointIndex)]))
        .watch();
  }
}
