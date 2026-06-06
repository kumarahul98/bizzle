import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v4.dart' as v4;

/// Proves the Phase 20 v4 → v5 migration is additive AND applies the D-02
/// returning-user guard: an existing install upgrades with
/// `has_seen_onboarding` added, the existing prefs row flipped to true, and
/// every trip row preserved — so a returning user is NEVER shown the
/// first-run login wall (T-20-01).
void main() {
  group('Drift v4 → v5 migration (Phase 20, D-01/D-02)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v4 schema opens cleanly at version 4', () async {
      final connection = await verifier.startAt(4);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      final result = await db.customSelect('SELECT 1 AS one').getSingle();
      expect(result.read<int>('one'), 1);
    });

    test(
      'v4 → v5 migration applies, preserves existing rows, AND sets '
      'has_seen_onboarding=true for the existing prefs row (D-02 guard)',
      () async {
        // 1. Open at v4 and seed one user_preferences row (the returning user)
        //    plus one trip row through the generated v4 schema classes. No
        //    has_seen_onboarding column exists yet at v4.
        final schema = await verifier.schemaAt(4);
        final oldDb = v4.DatabaseAtV4(schema.newConnection());

        await oldDb
            .into(oldDb.userPreferences)
            .insert(
              const RawValuesInsertable<dynamic>({
                'id': Variable<int>(1),
                'user_id': Variable<String>(kDefaultUserId),
              }),
            );

        const tripId = 'trip-v4-survivor';
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

        // 2. Run the real v4 → v5 migration and validate the DDL diff against
        //    the generated v5 snapshot.
        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 5);

        // 3a. The trip survives unchanged (additive migration).
        final tripRow = await migratedDb.tripsDao.findById(tripId);
        expect(tripRow, isNotNull, reason: 'existing trip must survive v5');
        expect(tripRow!.id, tripId);
        expect(tripRow.durationSeconds, 3600);

        // 3b. The returning-user guard flipped the existing prefs row's flag
        //     to true — a returning user is NOT walled after the update.
        final prefs = await migratedDb.userPreferencesDao.getOrDefault();
        expect(
          prefs.hasSeenOnboarding,
          isTrue,
          reason: 'returning user must keep has_seen_onboarding=true (D-02)',
        );
        expect(prefs.userId, kDefaultUserId);
      },
    );

    test(
      'fresh install (no prefs row) reads has_seen_onboarding=false so the '
      'wall shows once (control)',
      () async {
        final db = AppDatabase(
          DatabaseConnection(
            NativeDatabase.memory(),
            closeStreamsSynchronously: true,
          ),
        );
        addTearDown(db.close);

        final prefs = await db.userPreferencesDao.getOrDefault();
        expect(prefs.hasSeenOnboarding, isFalse);
      },
    );
  });
}
