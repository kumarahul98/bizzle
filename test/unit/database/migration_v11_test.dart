import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v10.dart' as v10;

/// Proves the Phase 35 v10 → v11 migration (D-01):
///   * additive `trips.deleted_at` — every existing trip and break survives and
///     reads `deleted_at = NULL` (live), exactly how it rendered before (SC#9);
///   * the `trip_breaks` FK-cascade rebuild (T-35-06) — after the migration,
///     hard-deleting a trip that has breaks cascades cleanly instead of raising
///     the `SqliteException(787)` a pre-v11 database throws.
void main() {
  group('Drift v10 → v11 migration (Phase 35, D-01)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v10 schema opens cleanly at version 10', () async {
      final connection = await verifier.startAt(10);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      final result = await db.customSelect('SELECT 1 AS one').getSingle();
      expect(result.read<int>('one'), 1);
    });

    test(
      'v10 → v11 adds deleted_at and preserves an existing trip and its break',
      () async {
        final schema = await verifier.schemaAt(10);
        final oldDb = v10.DatabaseAtV10(schema.newConnection());

        const tripId = 'trip-v10-survivor';
        final start = DateTime.utc(2026, 3, 4, 8);
        await oldDb
            .into(oldDb.trips)
            .insert(
              RawValuesInsertable<dynamic>({
                'id': const Variable<String>(tripId),
                'start_time': Variable<DateTime>(start),
                'end_time': Variable<DateTime>(
                  start.add(const Duration(minutes: 30)),
                ),
                'duration_seconds': const Variable<int>(1800),
                'total_paused_seconds': const Variable<int>(0),
                'distance_meters': const Variable<double>(5000),
                'direction': const Variable<String>(kDirectionToOffice),
                'time_moving_seconds': const Variable<int>(1500),
                'time_stuck_seconds': const Variable<int>(300),
              }),
            );
        await oldDb
            .into(oldDb.tripBreaks)
            .insert(
              RawValuesInsertable<dynamic>({
                'id': const Variable<String>('brk-v10'),
                'trip_id': const Variable<String>(tripId),
                'start_time': Variable<DateTime>(
                  start.add(const Duration(minutes: 4)),
                ),
                'end_time': Variable<DateTime>(
                  start.add(const Duration(minutes: 6)),
                ),
              }),
            );
        await oldDb.close();

        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 11);

        // The trip survives, now readable as a live (deleted_at = NULL) row.
        final trip = await migratedDb.tripsDao.findById(tripId);
        expect(trip, isNotNull);
        expect(trip!.durationSeconds, 1800);
        expect(trip.deletedAt, isNull);

        // The break survives the trip_breaks table rebuild.
        final breaks = await migratedDb.tripBreaksDao.breaksForTrip(tripId);
        expect(breaks, hasLength(1));
        expect(breaks.single.id, 'brk-v10');
      },
    );

    test(
      'after v10 → v11 the trip_breaks FK cascades on hard delete (T-35-06)',
      () async {
        final schema = await verifier.schemaAt(10);
        final oldDb = v10.DatabaseAtV10(schema.newConnection());

        const tripId = 'trip-cascade-migrated';
        final start = DateTime.utc(2026, 3, 4, 8);
        await oldDb
            .into(oldDb.trips)
            .insert(
              RawValuesInsertable<dynamic>({
                'id': const Variable<String>(tripId),
                'start_time': Variable<DateTime>(start),
                'end_time': Variable<DateTime>(
                  start.add(const Duration(minutes: 30)),
                ),
                'duration_seconds': const Variable<int>(1800),
                'total_paused_seconds': const Variable<int>(0),
                'distance_meters': const Variable<double>(5000),
                'direction': const Variable<String>(kDirectionToOffice),
                'time_moving_seconds': const Variable<int>(1500),
                'time_stuck_seconds': const Variable<int>(300),
              }),
            );
        await oldDb
            .into(oldDb.tripBreaks)
            .insert(
              RawValuesInsertable<dynamic>({
                'id': const Variable<String>('brk-cascade'),
                'trip_id': const Variable<String>(tripId),
                'start_time': Variable<DateTime>(
                  start.add(const Duration(minutes: 4)),
                ),
                'end_time': Variable<DateTime>(
                  start.add(const Duration(minutes: 6)),
                ),
              }),
            );
        await oldDb.close();

        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 11);

        // On a MIGRATED (not fresh) v11 db, the rebuilt FK must cascade — a
        // pre-v11 database throws SqliteException(787) here.
        await migratedDb.tripsDao.deleteTrip(tripId);
        expect(await migratedDb.tripBreaksDao.breaksForTrip(tripId), isEmpty);
      },
    );

    test('schemaVersion is 11', () {
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(db.close);
      expect(db.schemaVersion, 11);
    });
  });
}
