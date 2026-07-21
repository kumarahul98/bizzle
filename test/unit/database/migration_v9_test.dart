import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v8.dart' as v8;

/// Proves the Phase 31 v8 → v9 migration (D-02: the `trip_stuck_segments`
/// table) is purely additive: an existing install upgrades with every trip row
/// intact and simply gains an empty segments table, which is exactly how a
/// pre-Phase-31 trip is meant to render (D-06, SC#5/SC#9).
void main() {
  group('Drift v8 → v9 migration (Phase 31, D-02)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v8 schema opens cleanly at version 8', () async {
      final connection = await verifier.startAt(8);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      final result = await db.customSelect('SELECT 1 AS one').getSingle();
      expect(result.read<int>('one'), 1);
    });

    test(
      'v8 → v9 adds trip_stuck_segments and preserves every existing trip',
      () async {
        // 1. Seed a trip through the generated v8 schema classes, where
        //    trip_stuck_segments does not exist yet.
        final schema = await verifier.schemaAt(8);
        final oldDb = v8.DatabaseAtV8(schema.newConnection());

        const tripId = 'trip-v8-survivor';
        final start = DateTime.utc(2026, 2, 3, 8);
        final end = DateTime.utc(2026, 2, 3, 8, 45);
        await oldDb
            .into(oldDb.trips)
            .insert(
              RawValuesInsertable<dynamic>({
                'id': const Variable<String>(tripId),
                'start_time': Variable<DateTime>(start),
                'end_time': Variable<DateTime>(end),
                'duration_seconds': const Variable<int>(2700),
                'total_paused_seconds': const Variable<int>(0),
                'distance_meters': const Variable<double>(8400.5),
                'direction': const Variable<String>('to_office'),
                'time_moving_seconds': const Variable<int>(2100),
                'time_stuck_seconds': const Variable<int>(600),
                'route_polyline': const Variable<String>('_p~iF~ps|U_ulLnnqC'),
              }),
            );
        await oldDb.close();

        // 2. Run the real v8 → v9 migration and validate the DDL diff against
        //    the generated v9 snapshot (proves no schema drift).
        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 9);

        // 3a. The trip survives byte-for-byte (additive migration, SC#9).
        final tripRow = await migratedDb.tripsDao.findById(tripId);
        expect(tripRow, isNotNull, reason: 'existing trip must survive v9');
        expect(tripRow!.durationSeconds, 2700);
        expect(tripRow.timeStuckSeconds, 600);
        expect(tripRow.direction, 'to_office');
        expect(tripRow.routePolyline, '_p~iF~ps|U_ulLnnqC');

        // 3b. The pre-Phase-31 trip has zero segments — no backfill is
        //     attempted, because the source speeds no longer exist (D-06).
        final segments = await migratedDb.tripStuckSegmentsDao
            .watch(tripId)
            .first;
        expect(segments, isEmpty);
      },
    );

    test('segments cascade-delete with their trip (T-31-04)', () async {
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(db.close);

      const tripId = 'trip-cascade';
      final start = DateTime.utc(2026, 2, 3, 8);
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: tripId,
          startTime: start,
          endTime: start.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
          distanceMeters: 5000,
          direction: 'to_office',
          timeMovingSeconds: 1200,
          timeStuckSeconds: 600,
        ),
      );
      await db.tripStuckSegmentsDao.insertSegments([
        TripStuckSegmentsCompanion.insert(
          id: 'seg-1',
          tripId: tripId,
          startPointIndex: 2,
          endPointIndex: 9,
          startTime: start.add(const Duration(minutes: 4)),
          endTime: start.add(const Duration(minutes: 6)),
        ),
      ]);
      expect(await db.tripStuckSegmentsDao.watch(tripId).first, hasLength(1));

      await db.tripsDao.deleteTrip(tripId);

      expect(
        await db.tripStuckSegmentsDao.watch(tripId).first,
        isEmpty,
        reason: 'onDelete: cascade must leave no orphan segment rows',
      );
    });
  });
}
