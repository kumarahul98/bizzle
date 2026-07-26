// Unit tests for TripsDao.deleteAllTrips (Phase 38, DEL-ALL-DATA).
//
// Mirrors the setUp/tearDown shape in test/unit/database/trips_dao_test.dart:
// in-memory Drift, closed in tearDown.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('TripsDao.deleteAllTrips', () {
    late AppDatabase db;
    const uuid = Uuid();

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<String> insertTrip() async {
      final id = uuid.v4();
      final start = DateTime.utc(2026, 1, 1, 8);
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          startTime: start,
          endTime: start.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
          distanceMeters: 5000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 1500,
          timeStuckSeconds: 300,
        ),
      );
      return id;
    }

    test(
      'removes every trip and cascades to trip_breaks + '
      'trip_stuck_segments, returning the deleted-row count',
      () async {
        final id1 = await insertTrip();
        final id2 = await insertTrip();

        // Child rows for id1 in both cascade tables.
        await db.tripBreaksDao.insertBreaks([
          TripBreaksCompanion.insert(
            id: uuid.v4(),
            tripId: id1,
            startTime: DateTime.utc(2026, 1, 1, 8, 5),
            endTime: Value(DateTime.utc(2026, 1, 1, 8, 10)),
          ),
        ]);
        await db.tripStuckSegmentsDao.insertSegments([
          TripStuckSegmentsCompanion.insert(
            id: uuid.v4(),
            tripId: id1,
            startPointIndex: 0,
            endPointIndex: 5,
            startTime: DateTime.utc(2026, 1, 1, 8, 1),
            endTime: DateTime.utc(2026, 1, 1, 8, 2),
          ),
        ]);

        final deletedCount = await db.tripsDao.deleteAllTrips();

        expect(deletedCount, 2);
        expect(await db.tripsDao.getAllTrips(), isEmpty);
        expect(await db.tripBreaksDao.breaksForTrip(id1), isEmpty);
        expect(
          await (db.select(
            db.tripStuckSegments,
          )..where((s) => s.tripId.equals(id1))).get(),
          isEmpty,
        );
        // id2 (no children) is gone too.
        expect(await db.tripsDao.findById(id2), isNull);
      },
    );

    test('returns 0 on an already-empty table', () async {
      expect(await db.tripsDao.deleteAllTrips(), 0);
    });
  });
}
