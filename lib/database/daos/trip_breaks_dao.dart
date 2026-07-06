import 'package:drift/drift.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/tables/trip_breaks_table.dart';

part 'trip_breaks_dao.g.dart';

/// Data-access object for the `trip_breaks` table (Phase 18, D-01).
///
/// Persistence is finalize-time and batch-oriented (D-05 discretion
/// resolution): the tracking layer holds break segments in memory while a
/// trip is active and writes them all in one batch when the trip is
/// finalized. There is no incremental per-segment persistence — a trip
/// that is abandoned mid-recording leaves no orphan break rows.
///
/// The `tripId` FK to `trips.id` is enforced by `PRAGMA foreign_keys = ON`
/// (set in `AppDatabase.migration.beforeOpen`), so `insertBreaks` for a
/// trip that does not exist throws (T-18-02).
@DriftAccessor(tables: [TripBreaks])
class TripBreaksDao extends DatabaseAccessor<AppDatabase>
    with _$TripBreaksDaoMixin {
  /// Bind the DAO to its parent `AppDatabase`.
  TripBreaksDao(super.attachedDatabase);

  /// Insert every break segment for a finalized trip in ONE batch
  /// (D-05). Callers construct the companions with the parent trip's id;
  /// the parent trip row MUST already exist or the FK constraint rejects
  /// the insert.
  Future<void> insertBreaks(List<TripBreaksCompanion> rows) {
    return batch((b) => b.insertAll(tripBreaks, rows));
  }

  /// All break segments for [tripId], ordered by `startTime` ascending so
  /// callers receive them in chronological order.
  Future<List<TripBreakRow>> breaksForTrip(String tripId) {
    return (select(tripBreaks)
          ..where((b) => b.tripId.equals(tripId))
          ..orderBy([(b) => OrderingTerm.asc(b.startTime)]))
        .get();
  }

  /// Delete every break segment for [tripId].
  ///
  /// First step of Plan 02's atomic full-edit (D-12): the write path
  /// DELETEs all existing breaks for the trip then INSERTs the validated,
  /// clamped replacements inside ONE `db.transaction`. The WHERE clause
  /// scopes the delete to a single trip — other trips' breaks are never
  /// touched. The parent trip row is never deleted, so this is FK-safe
  /// under `PRAGMA foreign_keys = ON`.
  Future<void> deleteBreaksForTrip(String tripId) {
    return (delete(tripBreaks)..where((b) => b.tripId.equals(tripId))).go();
  }

  /// Reactive stream of break segments for [tripId], ordered by
  /// `startTime` ascending. Mirrors [breaksForTrip] for widgets that need
  /// live updates (e.g. Phase 19 segment editing).
  Stream<List<TripBreakRow>> watch(String tripId) {
    return (select(tripBreaks)
          ..where((b) => b.tripId.equals(tripId))
          ..orderBy([(b) => OrderingTerm.asc(b.startTime)]))
        .watch();
  }
}
