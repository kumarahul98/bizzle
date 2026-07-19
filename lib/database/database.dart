import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/sync_queue_dao.dart';
import 'package:traevy/database/daos/trip_breaks_dao.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/tables/sync_queue_table.dart';
import 'package:traevy/database/tables/trip_breaks_table.dart';
import 'package:traevy/database/tables/trips_table.dart';
import 'package:traevy/database/tables/user_preferences_table.dart';

part 'database.g.dart';

/// The single top-level Drift database for the Traevy app.
///
/// Registers the three Phase 1 tables (Trips, SyncQueue, UserPreferences)
/// and their DAOs. Schema starts at version 1 per D-09; every future
/// schema change must bump `schemaVersion` and add an `onUpgrade` branch.
///
/// The constructor accepts an optional `QueryExecutor` so unit tests can
/// inject `NativeDatabase.memory()` without hitting the filesystem.
/// Production callers pass no argument and get a `drift_flutter`-managed
/// connection rooted in the app's support directory (NOT the documents
/// directory — see the anti-patterns note in 01-RESEARCH.md).
@DriftDatabase(
  tables: [Trips, SyncQueue, UserPreferences, TripBreaks],
  daos: [TripsDao, SyncQueueDao, UserPreferencesDao, TripBreaksDao],
)
class AppDatabase extends _$AppDatabase {
  /// Construct an `AppDatabase`.
  ///
  /// Production callers pass no argument and get a `drift_flutter`
  /// connection. Tests inject `NativeDatabase.memory()` (wrapped in a
  /// `DatabaseConnection` if they need `closeStreamsSynchronously`).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // D-04: Do NOT seed user_preferences here. UserPreferencesDao
      // .getOrDefault() returns hardcoded defaults when the single
      // row (id = 1) is absent. Seeding on create would race with
      // fresh-install reads and complicates future migrations.
    },
    onUpgrade: (m, from, to) async {
      // Each branch is guarded by both `from` (has this step NOT yet run on
      // this install?) and `to` (is the migration actually targeting at
      // least this version?). The `to` guard keeps stepwise migrations
      // correct now that more than one terminal version exists: a verifier
      // migrating v2 → v3 must NOT also apply the v4 step (D-04).
      if (from < 2 && to >= 2) {
        // D-13: adds weeklyNotificationEnabled boolean column to
        // user_preferences. Default false provided by
        // withDefault(const Constant(false)) in the table definition
        // — existing rows get false automatically.
        await m.addColumn(
          userPreferences,
          userPreferences.weeklyNotificationEnabled,
        );
      }
      if (from < 3 && to >= 3) {
        // Phase 18 (D-01/D-02/D-10): additive-only v2 → v3 migration.
        // Creates the normalized trip_breaks table and adds two columns
        // with safe defaults. No UPDATE/DROP touches existing trip rows,
        // so every historical commute survives unchanged (T-18-01):
        //   * trips.total_paused_seconds defaults 0 → active duration
        //     equals wall-clock for all pre-Phase-18 rows (D-03).
        //   * user_preferences.auto_pause_enabled defaults false →
        //     auto-pause is opt-in (D-10).
        // Ordered AFTER the from<2 branch so a v1 install runs both
        // branches in sequence.
        await m.createTable(tripBreaks);
        await m.addColumn(trips, trips.totalPausedSeconds);
        await m.addColumn(
          userPreferences,
          userPreferences.autoPauseEnabled,
        );
      }
      if (from < 4 && to >= 4) {
        // Phase 19 (D-04): additive-only v3 → v4 migration. Adds a single
        // boolean trips.is_edited column with default false. No UPDATE/DROP
        // touches existing trip rows, so every historical commute survives
        // unchanged and reads is_edited=false (T-19-01). Ordered AFTER the
        // from<3 branch so a v1/v2/v3 install runs every branch in sequence.
        await m.addColumn(trips, trips.isEdited);
      }
      if (from < 5 && to >= 5) {
        // Phase 20 (D-01/D-02): v4 → v5 adds the boolean
        // user_preferences.has_seen_onboarding column (default false) that
        // drives the first-run login gate. Additive — no DROP/DELETE touches
        // existing rows.
        await m.addColumn(userPreferences, userPreferences.hasSeenOnboarding);
        // D-02 returning-user guard: an install that reaches this migration
        // has, by definition, already passed first-run. Flip the EXISTING
        // single row (id = 1) to true so the login wall is FIRST-INSTALL
        // ONLY — a returning user is never walled after an update. Fresh
        // installs run onCreate (no row), so getOrDefault() returns false and
        // the wall shows exactly once. Ordered AFTER the from<4 branch so a
        // v1..v4 install runs every branch in sequence.
        await customStatement(
          'UPDATE user_preferences SET has_seen_onboarding = 1 WHERE id = 1',
        );
      }
      if (from < 6 && to >= 6) {
        // Phase 21 (D-01/D-02, T-21-01): additive-only v5 → v6 migration. Adds
        // four nullable Home/Office coordinate columns on user_preferences and
        // the trips.direction_source column (default 'time'). No UPDATE/DROP
        // touches existing rows, so every historical commute survives unchanged
        // and reads direction_source='time' with null coords (SC#5). Ordered
        // AFTER the from<5 branch so a v1..v5 install runs every branch in
        // sequence.
        await m.addColumn(userPreferences, userPreferences.homeLat);
        await m.addColumn(userPreferences, userPreferences.homeLng);
        await m.addColumn(userPreferences, userPreferences.officeLat);
        await m.addColumn(userPreferences, userPreferences.officeLng);
        await m.addColumn(trips, trips.directionSource);
      }
      if (from < 7 && to >= 7) {
        // Phase 26 (D-03): additive-only v6 → v7 migration. Adds the
        // version-keyed user_preferences.backfill_marker_version column
        // (default 0) that tracks whether the one-time re-sync of trips with
        // breaks/edits has run for the current payload schema. No UPDATE/DROP
        // touches existing rows, so every historical preferences row survives
        // unchanged and reads backfill_marker_version=0 (never run). Ordered
        // AFTER the from<6 branch so a v1..v6 install runs every branch in
        // sequence.
        await m.addColumn(
          userPreferences,
          userPreferences.backfillMarkerVersion,
        );
      }
      if (from < 8 && to >= 8) {
        // Phase 27 (UX-08/UX-07): v7 → v8 migration bundling two
        // user_preferences changes to avoid a second codegen/migration
        // round-trip. Uses `alterTable` (SQLite's 12-step table-rebuild
        // procedure), NOT `addColumn` + a bare `UPDATE`, because a plain
        // `addColumn` only ever adds a NEW column — it cannot change the
        // DEFAULT constraint already baked into an EXISTING column's DDL
        // (`auto_pause_enabled` was added back at v3 with `DEFAULT 0`;
        // that constraint is permanent for every row-holding install unless
        // the table is rebuilt). Rebuilding here — instead of a bare
        // `customStatement('UPDATE ...')` — keeps every upgraded install's
        // on-disk schema byte-for-byte identical to a fresh install's (both
        // read `auto_pause_enabled` as `DEFAULT 1` and `seen_tours` as
        // `DEFAULT ''` from the DDL itself), which is what
        // `SchemaVerifier.migrateAndValidate` asserts in the migration
        // tests — a bare UPDATE only fixes data for the single existing
        // row, not the column's DEFAULT metadata for any future INSERT.
        //   1. `seenTours` is declared a "new" column (doesn't exist on
        //      disk yet); it has no transformer, so every existing row
        //      takes its table default (`''` — no tours seen), same as a
        //      fresh install (additive, UX-07 scaffold).
        //   2. `autoPauseEnabled` already exists on disk (added at v3
        //      with the old `false` default) but gets an explicit
        //      `columnTransformer` of `Constant(true)`, so every EXISTING
        //      row is rewritten to `true` during the rebuild — this is
        //      the backfill (D-10 opt-in default is superseded by UX-08)
        //      — while the rebuilt column's own DDL also now carries the
        //      new `DEFAULT 1` for any future insert.
        //   3. Every other column has neither entry, so `alterTable`
        //      copies its existing value across unchanged — no other
        //      historical trip or preferences data is touched. Ordered
        //      AFTER the from<7 branch so a v1..v7 install runs every
        //      branch in sequence.
        await m.alterTable(
          TableMigration(
            userPreferences,
            newColumns: [userPreferences.seenTours],
            columnTransformer: {
              userPreferences.autoPauseEnabled: const Constant(true),
            },
          ),
        );
      }
    },
    beforeOpen: (details) async {
      // Phase 1 has no foreign keys, but turning the pragma on now
      // means later schema changes that add FKs get enforcement for
      // free without another migration.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Open the on-device SQLite file via `drift_flutter`. Uses
  /// `getApplicationSupportDirectory` so the DB lives in the sandboxed
  /// app-support dir (not the user-visible documents dir, which would
  /// leak into iOS iCloud backups when iOS support lands).
  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: kDatabaseName,
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
