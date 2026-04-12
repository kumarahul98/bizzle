import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/trips_table.dart';

part 'trips_dao.g.dart';

/// Lightweight projection of a trip for list views.
///
/// Pitfall 7 mitigation: `TripRow` contains `routePolyline` which is
/// 5–15 KB of encoded path data per trip. Loading that into memory for
/// every row in the daily log is wasteful and eventually jank-inducing.
/// List DAO methods project into this class instead so the polyline
/// never touches the stream. Only `findById()` (trip detail screen
/// use only) returns the full `TripRow`.
///
/// Immutable by construction — all fields are `final` and the
/// constructor is `const`. The class is intentionally a plain Dart
/// value, not a Drift row type, so downstream layers cannot accidentally
/// upcast it to `TripRow` and pull the polyline back in.
class TripSummary {
  const TripSummary({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.direction,
    required this.timeMovingSeconds,
    required this.timeStuckSeconds,
    required this.isManualEntry,
  });

  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final double distanceMeters;
  final String direction;
  final int timeMovingSeconds;
  final int timeStuckSeconds;
  final bool isManualEntry;
}

/// Data-access object for the `trips` table.
///
/// Scope is deliberately narrow for Phase 1: stream all summaries for
/// the daily log, fetch a single full row for the detail screen, and
/// insert. Update/delete methods arrive in Phase 3 when trip editing
/// lands; adding them before then would be dead code (CLAUDE.md rule).
@DriftAccessor(tables: [Trips])
class TripsDao extends DatabaseAccessor<AppDatabase> with _$TripsDaoMixin {
  TripsDao(super.db);

  /// Reactive stream of every trip as a `TripSummary`, ordered newest
  /// first. The daily log and dashboard widgets bind to this stream
  /// via Riverpod. Polyline column is never materialized — see
  /// `TripSummary` doc for the Pitfall 7 context.
  Stream<List<TripSummary>> watchAllSummaries() {
    final query = select(trips)
      ..orderBy([
        (t) => OrderingTerm(
              expression: t.startTime,
              mode: OrderingMode.desc,
            ),
      ]);
    return query.map(_toSummary).watch();
  }

  /// Fetch the full row (including polyline) for a single trip.
  ///
  /// Intended for the trip detail screen ONLY. Do not call this from
  /// list or aggregate contexts — use `watchAllSummaries()` instead so
  /// the polyline does not flow through UI code unnecessarily.
  Future<TripRow?> findById(String id) {
    return (select(trips)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new trip. Callers construct a `TripsCompanion.insert(...)`
  /// with all required fields; Drift validates non-null constraints at
  /// compile time via the generated companion.
  Future<void> insertTrip(TripsCompanion companion) {
    return into(trips).insert(companion);
  }

  TripSummary _toSummary(TripRow r) => TripSummary(
        id: r.id,
        startTime: r.startTime,
        endTime: r.endTime,
        durationSeconds: r.durationSeconds,
        distanceMeters: r.distanceMeters,
        direction: r.direction,
        timeMovingSeconds: r.timeMovingSeconds,
        timeStuckSeconds: r.timeStuckSeconds,
        isManualEntry: r.isManualEntry,
      );
}
