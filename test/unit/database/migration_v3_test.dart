import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v2.dart' as v2;

/// Proves the Phase 18 v2 → v3 migration is additive-only and preserves
/// every existing trip row (T-18-01, D-03/D-04/D-10).
void main() {
  group('Drift v2 → v3 migration (Phase 18, D-04)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v2 schema opens cleanly at version 2', () async {
      final connection = await verifier.startAt(2);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      // Trivial sanity query — proves the v2 connection is live.
      final result = await db.customSelect('SELECT 1 AS one').getSingle();
      expect(result.read<int>('one'), 1);
    });

    test(
      'v2 → v3 migration applies and preserves existing trip rows',
      () async {
        // 1. Open the database at the v2 schema and insert a trip row plus a
        //    user_preferences row through the generated v2 schema classes
        //    (no break columns exist yet at v2).
        final schema = await verifier.schemaAt(2);
        final oldDb = v2.DatabaseAtV2(schema.newConnection());

        const tripId = 'trip-v2-survivor';
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
                'distance_meters': const Variable<double>(12345.6),
                'direction': const Variable<String>('to_office'),
                'time_moving_seconds': const Variable<int>(3000),
                'time_stuck_seconds': const Variable<int>(600),
              }),
            );
        await oldDb
            .into(oldDb.userPreferences)
            .insert(
              const RawValuesInsertable<dynamic>({'id': Variable<int>(1)}),
            );
        await oldDb.close();

        // 2. Run the real v2 → v3 migration and validate the resulting schema
        //    against the generated v3 snapshot (DDL diff applies cleanly).
        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 3);

        // 3a. The previously-inserted trip still exists after migration.
        final tripRow = await migratedDb.tripsDao.findById(tripId);
        expect(tripRow, isNotNull, reason: 'existing trip must survive v3');
        expect(tripRow!.id, tripId);
        expect(tripRow.durationSeconds, 3600);

        // 3b. The new total_paused_seconds column defaults to 0 for the
        //     pre-existing row (D-02/D-03 — active duration == wall-clock).
        expect(tripRow.totalPausedSeconds, 0);

        // 3c. The user_preferences row written before migration reflects
        //     auto_pause_enabled = false (D-10 — opt-in default).
        final prefs = await migratedDb.userPreferencesDao.getOrDefault();
        expect(prefs.autoPauseEnabled, isFalse);
      },
    );
  });
}
