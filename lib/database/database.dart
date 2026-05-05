import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/sync_queue_dao.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/tables/sync_queue_table.dart';
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
  tables: [Trips, SyncQueue, UserPreferences],
  daos: [TripsDao, SyncQueueDao, UserPreferencesDao],
)
class AppDatabase extends _$AppDatabase {
  /// Construct an `AppDatabase`.
  ///
  /// Production callers pass no argument and get a `drift_flutter`
  /// connection. Tests inject `NativeDatabase.memory()` (wrapped in a
  /// `DatabaseConnection` if they need `closeStreamsSynchronously`).
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

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
          if (from < 2) {
            // D-13: adds weeklyNotificationEnabled boolean column to
            // user_preferences. Default false provided by
            // withDefault(const Constant(false)) in the table definition
            // — existing rows get false automatically.
            await m.addColumn(
              userPreferences,
              userPreferences.weeklyNotificationEnabled,
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
