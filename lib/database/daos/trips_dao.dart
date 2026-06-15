import 'package:drift/drift.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/tables/trips_table.dart';

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
  /// Construct a `TripSummary` from already-loaded trip fields. Every
  /// field is required — `TripSummary` is meant to be immutable once
  /// handed to widgets.
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
    this.isEdited = false,
  });

  /// UUID of the trip (matches `Trips.id`).
  final String id;

  /// Trip start timestamp in UTC.
  final DateTime startTime;

  /// Trip end timestamp in UTC.
  final DateTime endTime;

  /// `endTime - startTime` in seconds, precomputed on insert.
  final int durationSeconds;

  /// Total distance in meters as reported by the GPS provider.
  final double distanceMeters;

  /// `'to_office'` or `'to_home'`.
  final String direction;

  /// Seconds the device reported speed ≥ 10 km/h.
  final int timeMovingSeconds;

  /// Seconds the device reported speed < 10 km/h (stuck in traffic).
  final int timeStuckSeconds;

  /// True if the user typed this trip in by hand (no GPS capture).
  final bool isManualEntry;

  /// True once the user has saved a full edit of this trip (Phase 19,
  /// D-04). Drives the "~ estimated" hint on moving/stuck in list/detail
  /// views — edited traffic figures are derived (proportional rescale),
  /// not measured. Defaults to `false` so pre-Phase-19 call sites and
  /// tests that build a `TripSummary` without it stay unchanged.
  final bool isEdited;
}

/// Data-access object for the `trips` table.
///
/// Scope is deliberately narrow for Phase 1: stream all summaries for
/// the daily log, fetch a single full row for the detail screen, and
/// insert. Update/delete methods arrive in Phase 3 when trip editing
/// lands; adding them before then would be dead code (CLAUDE.md rule).
@DriftAccessor(tables: [Trips])
class TripsDao extends DatabaseAccessor<AppDatabase> with _$TripsDaoMixin {
  /// Bind the DAO to its parent `AppDatabase`.
  TripsDao(super.attachedDatabase);

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
    return (select(trips)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Fetch all trips for conflict detection during restore.
  Future<List<TripRow>> getAllTrips() {
    return select(trips).get();
  }

  /// Fetch the full row (including polyline) of the most recent GPS trip, or
  /// null if no GPS trip exists (LOC-01, D-13 picker init fallback).
  ///
  /// Ordered by `startTime` desc and filtered to `is_manual_entry = false` so
  /// the row is guaranteed to carry a recorded route. Used only to seed the
  /// location-picker camera when no saved anchor and no device location are
  /// available — never on a hot path.
  Future<TripRow?> mostRecentGpsTrip() {
    return (select(trips)
          ..where((t) => t.isManualEntry.equals(false))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.startTime,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Insert a new trip. Callers construct a `TripsCompanion.insert(...)`
  /// with all required fields; Drift validates non-null constraints at
  /// compile time via the generated companion.
  Future<void> insertTrip(TripsCompanion companion) {
    return into(trips).insert(companion);
  }

  /// Restore path (D-08, MEDIUM-3): insert every restored [companions] entry
  /// in ONE Drift batch using `InsertMode.insertOrIgnore`, returning the count
  /// of NEW rows actually written.
  ///
  /// Dedupe-by-UUID is enforced by the `id` primary key: a companion whose
  /// `id` already exists locally is SILENTLY SKIPPED — never overwritten — so
  /// a duplicate restore can never clobber a good local row
  /// (client-authoritative, CLAUDE.md). All inserts run inside a single
  /// `batch(...)` transaction (efficient + jank-free), NOT N awaited inserts.
  ///
  /// The NEW-row count is the pre/post `SELECT COUNT(*)` delta around the
  /// batch. This is accepted for v0.1: restore is a manual, single-shot,
  /// user-initiated action with no concurrent writers, so the count cannot
  /// meaningfully race.
  Future<int> insertOrIgnoreTrips(List<TripsCompanion> companions) async {
    if (companions.isEmpty) return 0;
    final before = await _countTrips();
    await batch(
      (b) => b.insertAll(
        trips,
        companions,
        mode: InsertMode.insertOrIgnore,
      ),
    );
    final after = await _countTrips();
    return after - before;
  }

  /// Count all rows in the `trips` table. Used by [insertOrIgnoreTrips] to
  /// compute the number of NEW rows written by a dedupe-by-UUID restore batch.
  Future<int> _countTrips() async {
    final count = trips.id.count();
    final query = selectOnly(trips)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Update the trip identified by `companion.id.value`. Only columns
  /// wrapped in `Value(...)` are touched; `Value.absent()` leaves the
  /// column unchanged. Callers must always pass
  /// `updatedAt: Value(DateTime.now().toUtc())`.
  ///
  /// Pitfall 4 mitigation: the WHERE clause is set explicitly via
  /// `..where((t) => t.id.equals(companion.id.value))`. The `companion.id`
  /// field is used only for the filter — it is not written to the row.
  /// Never use `update(trips).replace(row)` for partial updates.
  Future<void> updateTrip(TripsCompanion companion) {
    return (update(
      trips,
    )..where((t) => t.id.equals(companion.id.value))).write(companion);
  }

  /// Delete the trip with [id].
  ///
  /// D-08: this method MUST be called exclusively inside an
  /// `appDatabase.transaction()` that also calls
  /// `SyncQueueDao.enqueueDelete` — never as a standalone call.
  /// The transaction ensures both the local delete and the sync-queue
  /// tombstone are atomic.
  Future<void> deleteTrip(String id) {
    return (delete(trips)..where((t) => t.id.equals(id))).go();
  }

  /// Rewrite every trip whose `userId` equals [kDefaultUserId] to
  /// [newUserId]. Returns the number of rows that were changed.
  ///
  /// D-11 (Phase 9 auth): called by `AuthService.signIn()` inside a
  /// `db.transaction()` alongside `UserPreferencesDao.backfillUserId`
  /// so the two updates are atomic. The return value is the
  /// first-sign-in signal — a count > 0 means there were guest trips
  /// to migrate; a count of 0 means the user has already signed in on
  /// this device.
  ///
  /// Pitfall 4 mitigation: the WHERE clause is set explicitly via
  /// `..where((t) => t.userId.equals(kDefaultUserId))`. Only
  /// `kDefaultUserId` rows are touched; real-uid rows are untouched.
  /// Never use `update(trips).replace(row)` for partial updates.
  Future<int> backfillUserId(String newUserId) {
    return (update(trips)..where((t) => t.userId.equals(kDefaultUserId))).write(
      TripsCompanion(userId: Value(newUserId)),
    );
  }

  /// All trips eligible for geofence direction relabelling (Phase 21, LOC-02).
  ///
  /// Returns rows where:
  ///   * `direction_source != kDirectionSourceManual` — a user's manual pick
  ///     is NEVER overwritten (T-21-03-01),
  ///   * `is_manual_entry = false` — manual entries have no polyline to decode,
  ///   * `route_polyline` is non-null and non-empty — the resolver needs
  ///     start/end coordinates from the encoded route.
  ///
  /// Ordered by `start_time ASC` (oldest first) — not functionally required
  /// but makes debugging predictable.
  Future<List<TripRow>> geofenceBackfillCandidates() {
    return (select(trips)
          ..where(
            (t) =>
                t.directionSource.equals(kDirectionSourceManual).not() &
                t.isManualEntry.equals(false) &
                t.routePolyline.isNotNull() &
                t.routePolyline.length.isBiggerThanValue(0),
          )
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.startTime,
              mode: OrderingMode.asc,
            ),
          ]))
        .get();
  }

  /// Rewrite the direction label and provenance source for a single trip
  /// (Phase 21, LOC-02 backfill).
  ///
  /// Used by `GeofenceBackfillService` to stamp `direction_source = geofence`
  /// on trips matched by proximity. Updates `updatedAt` to preserve the audit
  /// trail without touching any other column.
  Future<void> updateDirectionAndSource(
    String tripId,
    String direction,
    String source,
  ) {
    return (update(trips)..where((t) => t.id.equals(tripId))).write(
      TripsCompanion(
        direction: Value(direction),
        directionSource: Value(source),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
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
    isEdited: r.isEdited,
  );
}
