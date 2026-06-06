import 'package:drift/drift.dart';
import 'package:traevy/database/tables/trips_table.dart';

/// Break segments captured during a single commute (Phase 18, D-01).
///
/// A trip can be paused and resumed any number of times. Each pause →
/// resume span is one row here, giving a normalized 1:N relationship to
/// `trips`. Phase 19 (full trip editing) edits individual segments, so
/// breaks are a normalized table — not a JSON blob on `trips` (D-01).
///
/// `tripId` is a hard foreign key to `trips.id` via `references(Trips, #id)`.
/// The FK is enforced because `PRAGMA foreign_keys = ON` is set in
/// `AppDatabase.migration.beforeOpen` — inserting a break for a missing
/// trip id is rejected at the SQLite layer (T-18-02).
///
/// `endTime` is nullable only transiently: while a break is open (the user
/// has paused but not yet resumed) it is null. Trip finalize closes every
/// segment, so a persisted, finalized trip never carries an open break
/// (D-05, D-07).
///
/// Column names stay camelCase in Dart; Drift maps them to snake_case SQL
/// (`tripId` → `trip_id`, `startTime` → `start_time`). All timestamps are
/// stored in UTC, matching the rest of the schema.
@DataClassName('TripBreakRow')
class TripBreaks extends Table {
  /// Client-generated UUID v4 primary key. Never null.
  TextColumn get id => text()();

  /// Owning trip. Hard FK to `trips.id`, enforced by
  /// `PRAGMA foreign_keys = ON` (D-01, T-18-02).
  TextColumn get tripId => text().references(Trips, #id)();

  /// Break start timestamp (pause), stored in UTC.
  DateTimeColumn get startTime => dateTime()();

  /// Break end timestamp (resume), stored in UTC. Null while the break is
  /// open; finalize closes every segment so a persisted trip never has a
  /// null `endTime` (D-05, D-07).
  DateTimeColumn get endTime => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
