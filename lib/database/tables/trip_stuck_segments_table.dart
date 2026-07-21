import 'package:drift/drift.dart';
import 'package:traevy/database/tables/trips_table.dart';

/// Contiguous stretches of a commute the user spent stuck in traffic
/// (Phase 31, D-02).
///
/// Each row is one run of consecutive below-threshold intervals that lasted at
/// least `kStuckSegmentMinSeconds`, expressed as an INCLUSIVE index range into
/// the decoded `trips.route_polyline`. Storing index ranges rather than raw
/// per-sample speed keeps a 45-minute commute at ~5–20 rows instead of ~900,
/// and — crucially — stores the DECISION rather than the inputs, so a painted
/// segment can never disagree with the `trips.time_stuck_seconds` printed
/// above it (T-31-03): both are written from the same classification.
///
/// `tripId` is a hard foreign key to `trips.id` with `onDelete:
/// KeyAction.cascade`, enforced because `PRAGMA foreign_keys = ON` is set in
/// `AppDatabase.migration.beforeOpen`. Deleting a trip therefore removes its
/// segments in the same statement — no orphan rows survive (T-31-04).
///
/// **Local-only (D-04).** These rows are never serialized into a sync payload,
/// never sent to Firestore and never returned by restore. They are derived
/// presentation data with no independent value once the raw samples are gone,
/// and they reveal where the user idles (T-31-01), so the smallest possible
/// blast radius is the right one. A restored or pre-Phase-31 trip simply has
/// zero rows here and renders a plain single polyline (D-06).
///
/// All timestamps are stored in UTC, matching the rest of the schema.
@DataClassName('TripStuckSegmentRow')
class TripStuckSegments extends Table {
  /// Client-generated UUID v4 primary key. Never null.
  TextColumn get id => text()();

  /// Owning trip. Hard FK to `trips.id`, cascading on delete (T-31-04).
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// Index of the first decoded-polyline point in the stuck stretch.
  IntColumn get startPointIndex => integer()();

  /// Index of the last decoded-polyline point in the stretch, INCLUSIVE.
  IntColumn get endPointIndex => integer()();

  /// Timestamp (UTC) of the sample at [startPointIndex].
  DateTimeColumn get startTime => dateTime()();

  /// Timestamp (UTC) of the sample at [endPointIndex].
  DateTimeColumn get endTime => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
