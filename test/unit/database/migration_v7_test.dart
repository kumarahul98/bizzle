import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v6.dart' as v6;

/// Proves the Phase 26 v6 → v7 migration is ADDITIVE ONLY (T-26-07): an
/// existing install upgrades with a `backfill_marker_version` column on
/// user_preferences, while every existing trip row and preferences row
/// survives unchanged and the new column defaults to 0 ("never run", D-03).
void main() {
  group('Drift v6 → v7 migration (Phase 26, D-03)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v6 schema opens cleanly at version 6', () async {
      final connection = await verifier.startAt(6);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      final result = await db.customSelect('SELECT 1 AS one').getSingle();
      expect(result.read<int>('one'), 1);
    });

    test(
      'v6 → v7 migration applies, preserves existing rows, defaults '
      'backfill_marker_version to 0 (additive)',
      () async {
        // 1. Open at v6 and seed one user_preferences row plus one trip row
        //    through the generated v6 schema classes. backfill_marker_version
        //    does not exist at v6.
        final schema = await verifier.schemaAt(6);
        final oldDb = v6.DatabaseAtV6(schema.newConnection());

        await oldDb
            .into(oldDb.userPreferences)
            .insert(
              const RawValuesInsertable<dynamic>({
                'id': Variable<int>(1),
                'user_id': Variable<String>(kDefaultUserId),
              }),
            );

        const tripId = 'trip-v6-survivor';
        final start = DateTime.utc(2026, 1, 1, 8);
        final end = DateTime.utc(2026, 1, 1, 9);
        await oldDb
            .into(oldDb.trips)
            .insert(
              RawValuesInsertable<dynamic>({
                'id': const Variable<String>(tripId),
                'start_time': Variable<DateTime>(start),
                'end_time': Variable<DateTime>(end),
                'duration_seconds': const Variable<int>(3600),
                'total_paused_seconds': const Variable<int>(0),
                'distance_meters': const Variable<double>(12345.6),
                'direction': const Variable<String>('to_office'),
                'time_moving_seconds': const Variable<int>(3000),
                'time_stuck_seconds': const Variable<int>(600),
              }),
            );
        await oldDb.close();

        // 2. Run the real migration up to the terminal version and validate
        //    the DDL diff against the generated snapshot. The v6 → v7 step
        //    still runs as part of the stepwise upgrade; migrating to the
        //    terminal version is required so the real DAO's getOrDefault()
        //    can read every column (Phase 27 added seen_tours after v7).
        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 8);

        // 3a. The trip survives unchanged (additive migration).
        final tripRow = await migratedDb.tripsDao.findById(tripId);
        expect(tripRow, isNotNull, reason: 'existing trip must survive v7');
        expect(tripRow!.id, tripId);
        expect(tripRow.durationSeconds, 3600);
        expect(tripRow.direction, 'to_office');

        // 3b. The new backfill_marker_version column defaults to 0 for the
        //     pre-existing prefs row (read directly, since Task 2's DAO
        //     getter does not exist yet at this point in the plan).
        final markerRow = await migratedDb
            .customSelect(
              'SELECT backfill_marker_version FROM user_preferences '
              'WHERE id = 1',
            )
            .getSingle();
        expect(
          markerRow.read<int>('backfill_marker_version'),
          0,
          reason: 'existing prefs row must read backfill_marker_version=0',
        );

        // 3c. The existing prefs row otherwise survives unchanged.
        final prefs = await migratedDb.userPreferencesDao.getOrDefault();
        expect(prefs.userId, kDefaultUserId);
      },
    );

    test(
      'fresh install: backfill_marker_version column defaults to 0 '
      '(control)',
      () async {
        final db = AppDatabase(
          DatabaseConnection(
            NativeDatabase.memory(),
            closeStreamsSynchronously: true,
          ),
        );
        addTearDown(db.close);

        // Insert a row WITHOUT specifying backfill_marker_version, proving
        // the DB-level column default (not the DAO getter, which is Task 2)
        // is 0 on a fresh onCreate schema.
        await db
            .into(db.userPreferences)
            .insert(
              UserPreferencesCompanion.insert(
                id: const Value<int>(1),
              ),
            );
        final row = await db
            .customSelect(
              'SELECT backfill_marker_version FROM user_preferences '
              'WHERE id = 1',
            )
            .getSingle();
        expect(row.read<int>('backfill_marker_version'), 0);
      },
    );
  });
}
