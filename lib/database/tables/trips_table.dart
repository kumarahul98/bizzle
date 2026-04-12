import 'package:drift/drift.dart';
import 'package:traevy/config/constants.dart';

/// Trips table: the primary record of every commute.
///
/// Schema locked by phase 01-foundation decisions:
///   * D-01: `routePolyline` lives on this table as nullable text; list
///     queries MUST project into `TripSummary` so the column never loads
///     for list views (Pitfall 7 — selective column loading).
///   * D-02: `userId` defaults to `'local_user'`. Phase 8 swaps this with
///     the Cognito subject via an UPDATE when auth lands.
///   * D-03: Two composite indexes registered via `@TableIndex`:
///       - `idx_trips_start_time` supports daily-log / date-range scans.
///       - `idx_trips_direction_start` supports stats queries that filter
///         by direction then order by start time.
///
/// Column names stay camelCase in Dart; Drift's default snake_case SQL
/// mapping converts them (e.g. `startTime` → `start_time`). Do not rename
/// the Dart identifiers — raw SQL in later phases depends on the derived
/// snake_case form.
@DataClassName('TripRow')
@TableIndex(name: 'idx_trips_start_time', columns: {#startTime})
@TableIndex(
  name: 'idx_trips_direction_start',
  columns: {#direction, #startTime},
)
class Trips extends Table {
  /// Client-generated UUID v4. Never null.
  TextColumn get id => text()();

  /// Owning user. Defaults to `kDefaultUserId`. Phase 8 auth rewrites
  /// existing rows with the Cognito subject when authentication lands.
  TextColumn get userId =>
      text().withDefault(const Constant(kDefaultUserId))();

  /// Trip start timestamp, stored in UTC.
  DateTimeColumn get startTime => dateTime()();

  /// Trip end timestamp, stored in UTC.
  DateTimeColumn get endTime => dateTime()();

  /// Derived from `endTime - startTime` by the trip processor so stats
  /// queries do not have to recompute per row.
  IntColumn get durationSeconds => integer()();

  /// Distance from the GPS provider, in meters.
  RealColumn get distanceMeters => real()();

  /// Encoded polyline string (Google polyline algorithm). D-01 keeps this
  /// on the trips table; list DAOs MUST project into `TripSummary` so
  /// the column does not load for daily-log renders (Pitfall 7).
  TextColumn get routePolyline => text().nullable()();

  /// `'to_office'` or `'to_home'`. Auto-labeled from the morning/evening
  /// cutoff, always user-editable from the trip detail screen.
  TextColumn get direction => text()();

  /// Time the device reported speed ≥ 10 km/h (kSpeedThresholdKmh).
  IntColumn get timeMovingSeconds => integer()();

  /// Time the device reported speed < 10 km/h. This is the "stuck in
  /// traffic" signal that drives the weekly stats dashboard.
  IntColumn get timeStuckSeconds => integer()();

  /// `true` for trips the user typed in by hand (no GPS capture). Manual
  /// entries never have a polyline.
  BoolColumn get isManualEntry =>
      boolean().withDefault(const Constant(false))();

  /// Insertion time. Defaults to `CURRENT_TIMESTAMP` so the DAO does
  /// not have to set it explicitly.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Last-modified time. Currently updated manually by the DAO on
  /// every write; future Phase 3 code may move this to a trigger.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
