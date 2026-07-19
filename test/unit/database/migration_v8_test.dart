import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v7.dart' as v7;

/// Proves the Phase 27 v7 → v8 migration (UX-08 auto-pause default flip +
/// UX-07 tour persistence scaffold) is additive AND applies the D-10
/// supersession backfill: an existing install upgrades with
/// `auto_pause_enabled` flipped to true (even though it was written as
/// false under the v3 opt-in default) and gains a `seen_tours` column that
/// defaults to `''`, while every existing trip and preferences row
/// survives unchanged.
void main() {
  group('Drift v7 → v8 migration (Phase 27, UX-07/UX-08)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v7 schema opens cleanly at version 7', () async {
      final connection = await verifier.startAt(7);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      final result = await db.customSelect('SELECT 1 AS one').getSingle();
      expect(result.read<int>('one'), 1);
    });

    test(
      'v7 → v8 migration applies, preserves existing rows, backfills '
      "auto_pause_enabled=1, and adds seen_tours defaulting to ''",
      () async {
        // 1. Open at v7 and seed one user_preferences row (explicitly
        //    false, matching the pre-Phase-27 v3 opt-in default) plus one
        //    trip row through the generated v7 schema classes. seen_tours
        //    does not exist yet at v7.
        final schema = await verifier.schemaAt(7);
        final oldDb = v7.DatabaseAtV7(schema.newConnection());

        await oldDb
            .into(oldDb.userPreferences)
            .insert(
              const RawValuesInsertable<dynamic>({
                'id': Variable<int>(1),
                'user_id': Variable<String>(kDefaultUserId),
                'auto_pause_enabled': Variable<bool>(false),
              }),
            );

        const tripId = 'trip-v7-survivor';
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

        // 2. Run the real v7 → v8 migration and validate the DDL diff
        //    against the generated v8 snapshot (proves no schema drift).
        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 8);

        // 3a. The trip survives unchanged (additive migration).
        final tripRow = await migratedDb.tripsDao.findById(tripId);
        expect(tripRow, isNotNull, reason: 'existing trip must survive v8');
        expect(tripRow!.id, tripId);
        expect(tripRow.durationSeconds, 3600);
        expect(tripRow.direction, 'to_office');

        // 3b. The pre-existing prefs row, which was explicitly false under
        //     the old v3 opt-in default, is backfilled to true — UX-08
        //     supersedes D-10 for every existing install, not just fresh
        //     ones.
        final prefs = await migratedDb.userPreferencesDao.getOrDefault();
        expect(
          prefs.autoPauseEnabled,
          isTrue,
          reason:
              'existing prefs row must be backfilled to '
              'auto_pause_enabled=1 (UX-08)',
        );
        expect(prefs.userId, kDefaultUserId);

        // 3c. seen_tours is added and defaults to '' (no tours seen) for
        //     the pre-existing row — parses to an empty set.
        expect(prefs.seenTours, '');
        expect(prefs.seenTourKeys, isEmpty);
      },
    );

    test(
      'fresh install: auto_pause_enabled defaults to true and seen_tours '
      "defaults to '' (control)",
      () async {
        final db = AppDatabase(
          DatabaseConnection(
            NativeDatabase.memory(),
            closeStreamsSynchronously: true,
          ),
        );
        addTearDown(db.close);

        // Insert a row WITHOUT specifying auto_pause_enabled/seen_tours,
        // proving the DB-level column defaults (not just the DAO's
        // hardcoded UserPreferencesValue.defaults()) are true / '' on a
        // fresh onCreate schema.
        await db
            .into(db.userPreferences)
            .insert(UserPreferencesCompanion.insert(id: const Value<int>(1)));
        final row = await db
            .customSelect(
              'SELECT auto_pause_enabled, seen_tours FROM user_preferences '
              'WHERE id = 1',
            )
            .getSingle();
        expect(row.read<bool>('auto_pause_enabled'), isTrue);
        expect(row.read<String>('seen_tours'), '');

        // The DAO reading the freshly-inserted row agrees with the raw SQL.
        final prefs = await db.userPreferencesDao.getOrDefault();
        expect(prefs.autoPauseEnabled, isTrue);
        expect(prefs.seenTours, '');
        expect(prefs.seenTourKeys, isEmpty);
      },
    );
  });
}
