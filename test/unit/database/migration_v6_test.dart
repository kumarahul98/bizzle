import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v5.dart' as v5;

/// Proves the Phase 21 v5 → v6 migration is ADDITIVE ONLY (T-21-01): an
/// existing install upgrades with four nullable Home/Office coordinate columns
/// on user_preferences and a `direction_source` column on trips, while every
/// existing trip row survives unchanged and reads `direction_source='time'`
/// with the prefs coords null (D-01/D-02, SC#5).
void main() {
  group('Drift v5 → v6 migration (Phase 21, D-01/D-02)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v5 schema opens cleanly at version 5', () async {
      final connection = await verifier.startAt(5);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      final result = await db.customSelect('SELECT 1 AS one').getSingle();
      expect(result.read<int>('one'), 1);
    });

    test(
      'v5 → v6 migration applies, preserves existing rows, defaults '
      'direction_source to time, and leaves prefs coords null (additive)',
      () async {
        // 1. Open at v5 and seed one user_preferences row plus one trip row
        //    through the generated v5 schema classes. Neither direction_source
        //    nor the coord columns exist at v5.
        final schema = await verifier.schemaAt(5);
        final oldDb = v5.DatabaseAtV5(schema.newConnection());

        await oldDb
            .into(oldDb.userPreferences)
            .insert(
              const RawValuesInsertable<dynamic>({
                'id': Variable<int>(1),
                'user_id': Variable<String>(kDefaultUserId),
              }),
            );

        const tripId = 'trip-v5-survivor';
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
        //    the DDL diff against the generated snapshot. The v5 → v6 step
        //    still runs as part of the stepwise upgrade; migrating to the
        //    terminal version is required so the real DAOs can read every
        //    column (Phase 26 added backfill_marker_version after v6).
        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 7);

        // 3a. The trip survives unchanged (additive migration).
        final tripRow = await migratedDb.tripsDao.findById(tripId);
        expect(tripRow, isNotNull, reason: 'existing trip must survive v6');
        expect(tripRow!.id, tripId);
        expect(tripRow.durationSeconds, 3600);
        expect(tripRow.direction, 'to_office');

        // 3b. The new direction_source column defaults to 'time' for the
        //     pre-existing row (read via the migrated trip row).
        final sourceRow = await migratedDb
            .customSelect(
              'SELECT direction_source FROM trips WHERE id = ?',
              variables: [Variable<String>(tripId)],
            )
            .getSingle();
        expect(
          sourceRow.read<String>('direction_source'),
          kDirectionSourceTime,
          reason: 'existing row must read direction_source=time (SC#5)',
        );

        // 3c. The four new coord columns read null for the migrated prefs row.
        final prefs = await migratedDb.userPreferencesDao.getOrDefault();
        expect(prefs.homeLat, isNull);
        expect(prefs.homeLng, isNull);
        expect(prefs.officeLat, isNull);
        expect(prefs.officeLng, isNull);
        expect(prefs.userId, kDefaultUserId);
      },
    );

    test(
      'fresh install defaults: coords null and a new trip defaults '
      'direction_source to time (control)',
      () async {
        final db = AppDatabase(
          DatabaseConnection(
            NativeDatabase.memory(),
            closeStreamsSynchronously: true,
          ),
        );
        addTearDown(db.close);

        // No prefs row → getOrDefault returns the defaults with null coords.
        final prefs = await db.userPreferencesDao.getOrDefault();
        expect(prefs.homeLat, isNull);
        expect(prefs.homeLng, isNull);
        expect(prefs.officeLat, isNull);
        expect(prefs.officeLng, isNull);

        // A trip persisted without an explicit direction_source defaults to
        // 'time' at the DB level (the v6 column default).
        const tripId = 'fresh-trip';
        await db.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: tripId,
            startTime: DateTime.utc(2026, 2, 2, 8),
            endTime: DateTime.utc(2026, 2, 2, 9),
            durationSeconds: 3600,
            distanceMeters: 5000,
            direction: kDirectionToOffice,
            timeMovingSeconds: 3000,
            timeStuckSeconds: 600,
          ),
        );
        final row = await db
            .customSelect(
              'SELECT direction_source FROM trips WHERE id = ?',
              variables: [Variable<String>(tripId)],
            )
            .getSingle();
        expect(row.read<String>('direction_source'), kDirectionSourceTime);
      },
    );
  });
}
