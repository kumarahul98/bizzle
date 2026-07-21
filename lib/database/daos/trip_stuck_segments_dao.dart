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

  /// Delete every stuck segment for [tripId].
  ///
  /// Called when a full edit rewrites `timeStuckSeconds` (Phase 31, D-03
  /// invariant). The stored index ranges were derived from the ORIGINAL
  /// recording's speed classification; once the user overwrites the stuck
  /// total by hand there is nothing left to re-derive them from, so keeping
  /// them would let the map paint more stuck time than the trip claims to
  /// measure. Dropping them degrades the trip to the D-06 no-segments path,
  /// which renders a plain route — honest about what is no longer known.
  Future<void> deleteSegmentsForTrip(String tripId) {
    return (delete(
      tripStuckSegments,
    )..where((s) => s.tripId.equals(tripId))).go();
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
