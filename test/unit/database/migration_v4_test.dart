import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v3.dart' as v3;

/// Proves the Phase 19 v3 → v4 migration is additive-only and preserves
/// every existing trip row (T-19-01, D-04).
void main() {
  group('Drift v3 → v4 migration (Phase 19, D-04)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v3 schema opens cleanly at version 3', () async {
      final connection = await verifier.startAt(3);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      // Trivial sanity query — proves the v3 connection is live.
      final result = await db.customSelect('SELECT 1 AS one').getSingle();
      expect(result.read<int>('one'), 1);
    });

    test(
      'v3 → v4 migration applies and preserves existing trip rows',
      () async {
        // 1. Open the database at the v3 schema and insert a trip row through
        //    the generated v3 schema classes (no is_edited column exists yet
        //    at v3, but total_paused_seconds already does).
        final schema = await verifier.schemaAt(3);
        final oldDb = v3.DatabaseAtV3(schema.newConnection());

        const tripId = 'trip-v3-survivor';
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
                'total_paused_seconds': const Variable<int>(120),
                'distance_meters': const Variable<double>(12345.6),
                'direction': const Variable<String>('to_office'),
                'time_moving_seconds': const Variable<int>(3000),
                'time_stuck_seconds': const Variable<int>(600),
              }),
            );
        await oldDb.close();

        // 2. Run the real v3 → v4 migration and validate the resulting schema
        //    against the generated v4 snapshot (DDL diff applies cleanly).
        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 4);

        // 3a. The previously-inserted trip still exists after migration with
        //     its existing columns intact.
        final tripRow = await migratedDb.tripsDao.findById(tripId);
        expect(tripRow, isNotNull, reason: 'existing trip must survive v4');
        expect(tripRow!.id, tripId);
        expect(tripRow.durationSeconds, 3600);
        expect(tripRow.totalPausedSeconds, 120);

        // 3b. The new is_edited column defaults to false for the pre-existing
        //     row (D-04 — additive migration, no data loss).
        expect(tripRow.isEdited, isFalse);
      },
    );
  });
}
