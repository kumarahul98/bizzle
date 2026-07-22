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
    this.deletedAt,
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

  /// Soft-delete tombstone (Phase 35, D-01). `null` for a live trip; a UTC
  /// timestamp for a trip sitting in the Trash. `watchAllSummaries` only ever
  /// returns live trips, so this is `null` there; `watchDeletedSummaries`
  /// carries the real value so the Trash screen can compute its retention
  /// countdown from it without a second query. Defaults to `null` so existing
  /// call sites and tests that build a `TripSummary` without it are unchanged.
  final DateTime? deletedAt;
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

  /// Reactive stream of every LIVE trip as a `TripSummary`, ordered newest
  /// first. The daily log and dashboard widgets bind to this stream
  /// via Riverpod. Polyline column is never materialized — see
  /// `TripSummary` doc for the Pitfall 7 context.
  ///
  /// Phase 35 (D-02): the `deletedAt IS NULL` filter is the SINGLE point that
  /// hides soft-deleted trips. Because `statsSummaryProvider` derives from
  /// `allTripSummariesProvider`, which wraps this exact stream, one filter
  /// removes deleted trips from history, the dashboard AND stats together —
  /// filtering at the call sites would leave the next consumer to rediscover
  /// the requirement. Restore's conflict detection uses `getAllTrips()`, which
  /// deliberately does NOT filter (T-35-01), so a deleted trip is still known
  /// to it and never re-imported.
  Stream<List<TripSummary>> watchAllSummaries() {
    final query = select(trips)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.startTime,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.map(_toSummary).watch();
  }

  /// Reactive stream of every SOFT-DELETED trip as a `TripSummary`, ordered by
  /// `deletedAt` descending (most recently deleted first) for the Settings →
  /// Deleted trips screen (Phase 35, D-05). `deletedAt` is carried on each
  /// summary so the screen renders its retention countdown without a second
  /// query. The polyline is never materialized here either.
  Stream<List<TripSummary>> watchDeletedSummaries() {
    final query = select(trips)
      ..where((t) => t.deletedAt.isNotNull())
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.deletedAt,
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
  ///
  /// Phase 35 (T-35-01, D-02): this deliberately does NOT filter out
  /// soft-deleted rows, and that omission is load-bearing. Restore's
  /// conflict detection matches cloud trips against local ids; if a
  /// soft-deleted trip were hidden here it would look absent, get re-imported
  /// from the cloud backup as a brand-new live trip, and the user's deletion
  /// would silently undo itself on the next restore. Seeing the deleted row
  /// lets restore recognise the id and skip it (enrichment never clears
  /// `deletedAt`), so the trip stays in the Trash.
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
  ///
  /// Phase 35 (D-02): also excludes soft-deleted trips (`deletedAt IS NULL`) —
  /// a trip the user has thrown away is a poor camera anchor.
  Future<TripRow?> mostRecentGpsTrip() {
    return (select(trips)
          ..where(
            (t) => t.isManualEntry.equals(false) & t.deletedAt.isNull(),
          )
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

  /// HARD-delete the trip with [id]. Cascade removes its breaks and stuck
  /// segments in the same statement (both FKs are `onDelete: cascade` under
  /// `PRAGMA foreign_keys = ON`).
  ///
  /// Phase 35 (D-04/D-05): as of soft delete this is NO LONGER the everyday
  /// delete path — user deletes call [softDeleteTrip] and enqueue a tombstone.
  /// This method is the irreversible sink used only by the app-start purge
  /// ([purgeTripsDeletedBefore]) and "delete permanently" from the Trash.
  /// Both of those enqueue NOTHING: the server was already told at
  /// soft-delete time and keeps its own soft-deleted copy, so a second delete
  /// would be redundant noise (D-04).
  Future<void> deleteTrip(String id) {
    return (delete(trips)..where((t) => t.id.equals(id))).go();
  }

  /// SOFT-delete the trip with [id] by stamping [deletedAtUtc] (Phase 35,
  /// D-01). The row stays in the table — no cascade fires — so its breaks and
  /// stuck segments survive intact for a later restore. `updatedAt` is bumped
  /// to the same instant to preserve the audit trail. Caller wraps this in the
  /// same transaction that enqueues the delete tombstone (D-03).
  Future<void> softDeleteTrip(String id, DateTime deletedAtUtc) {
    return (update(trips)..where((t) => t.id.equals(id))).write(
      TripsCompanion(
        deletedAt: Value(deletedAtUtc),
        updatedAt: Value(deletedAtUtc),
      ),
    );
  }

  /// Restore the soft-deleted trip with [id] by clearing `deletedAt` back to
  /// NULL (Phase 35, D-03). The trip reappears in every live surface; its
  /// breaks and stuck segments were never removed, so they return with it.
  /// Caller wraps this in the same transaction that enqueues a create so the
  /// server upsert clears its own `deleted: true`.
  Future<void> restoreTrip(String id) {
    return (update(trips)..where((t) => t.id.equals(id))).write(
      TripsCompanion(
        deletedAt: const Value<DateTime?>(null),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Hard-delete every trip soft-deleted STRICTLY BEFORE [cutoffUtc], returning
  /// the number of rows removed (Phase 35, D-04 purge). Live rows
  /// (`deletedAt IS NULL`) can never match — SQLite `<` against NULL is NULL,
  /// never true — so a trip that was never deleted is safe. Cascade removes
  /// each purged trip's breaks and stuck segments. Enqueues nothing.
  ///
  /// The caller computes [cutoffUtc] as `now - kTrashRetentionDays`; passing it
  /// in (rather than reading the clock here) keeps this method pure and lets
  /// the boundary tests pin an exact cutoff. A trip whose `deletedAt` is at or
  /// after the cutoff (deleted recently, or a future-dated tombstone from a
  /// clock moved backward) is never purged — the "negative age clamped to
  /// zero" requirement expressed as a comparison.
  Future<int> purgeTripsDeletedBefore(DateTime cutoffUtc) {
    return (delete(
      trips,
    )..where((t) => t.deletedAt.isSmallerThanValue(cutoffUtc))).go();
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

  /// Ids of every trip with non-default v0.3 metadata (Phase 26, D-01
  /// backfill candidate query).
  ///
  /// "Non-default metadata" means ANY of:
  ///   * one or more `trip_breaks` rows exist for the trip,
  ///   * `is_edited = true`,
  ///   * `direction_source != kDirectionSourceTime`.
  ///
  /// Deliberately wider than the literal roadmap wording ("breaks or
  /// edits") per CONTEXT.md D-01, so geofence-/manual-labeled trips are
  /// included and their `direction_source` reaches the cloud copy.
  ///
  /// A single query with OR'd conditions — a trip matching several
  /// conditions still appears exactly once (one row per trip, no join).
  /// Projects to plain ids: the caller feeds them straight into
  /// `SyncQueueDao.enqueueUpdate`, which re-reads the payload at sync time.
  Future<List<String>> tripIdsWithNonDefaultMetadata() {
    final breaks = attachedDatabase.tripBreaks;
    final query = select(trips)
      ..where(
        // Phase 35 (D-02): exclude soft-deleted trips — there is no reason to
        // push metadata for a trip the user has deleted.
        (t) =>
            t.deletedAt.isNull() &
            (t.isEdited.equals(true) |
                t.directionSource.equals(kDirectionSourceTime).not() |
                existsQuery(
                  attachedDatabase.selectOnly(breaks)
                    ..addColumns([breaks.id])
                    ..where(breaks.tripId.equalsExp(t.id)),
                )),
      );
    return query.map((row) => row.id).get();
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
    deletedAt: r.deletedAt,
  );
}
