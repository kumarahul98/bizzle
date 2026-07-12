import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('TripsDao', () {
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

    test('inserted trip is returned by watchAllSummaries (SYNC-01)', () async {
      final id = uuid.v4();
      final start = DateTime.utc(2026, 1, 1, 8);
      final end = DateTime.utc(2026, 1, 1, 9);

      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          startTime: start,
          endTime: end,
          durationSeconds: 3600,
          distanceMeters: 12345.6,
          direction: kDirectionToOffice,
          timeMovingSeconds: 3000,
          timeStuckSeconds: 600,
        ),
      );

      final summaries = await db.tripsDao.watchAllSummaries().first;
      expect(summaries, hasLength(1));
      final only = summaries.single;
      expect(only.id, id);
      expect(only.direction, kDirectionToOffice);
      expect(only.durationSeconds, 3600);
      expect(only.distanceMeters, 12345.6);
      expect(only.timeMovingSeconds, 3000);
      expect(only.timeStuckSeconds, 600);
      expect(only.isManualEntry, isFalse);
    });

    test('watchAllSummaries orders by start_time DESC', () async {
      final earlierId = uuid.v4();
      final laterId = uuid.v4();
      final earlierStart = DateTime.utc(2026, 1, 1, 7);
      final laterStart = DateTime.utc(2026, 1, 1, 8);

      // Insert earlier first to prove ordering is by start_time, not by
      // insertion order.
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: earlierId,
          startTime: earlierStart,
          endTime: earlierStart.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
          distanceMeters: 5000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 1500,
          timeStuckSeconds: 300,
        ),
      );
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: laterId,
          startTime: laterStart,
          endTime: laterStart.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
          distanceMeters: 6000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 1500,
          timeStuckSeconds: 300,
        ),
      );

      final summaries = await db.tripsDao.watchAllSummaries().first;
      expect(summaries, hasLength(2));
      expect(summaries.first.id, laterId);
      expect(summaries.last.id, earlierId);
    });

    test('findById returns full row including polyline (D-01)', () async {
      final id = uuid.v4();
      const polyline = 'abc123';

      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          startTime: DateTime.utc(2026, 1, 2, 8),
          endTime: DateTime.utc(2026, 1, 2, 9),
          durationSeconds: 3600,
          distanceMeters: 9876.5,
          direction: kDirectionToHome,
          timeMovingSeconds: 3300,
          timeStuckSeconds: 300,
          routePolyline: const Value<String>(polyline),
        ),
      );

      final row = await db.tripsDao.findById(id);
      expect(row, isNotNull);
      expect(row!.id, id);
      expect(row.routePolyline, polyline);
      expect(row.direction, kDirectionToHome);
    });

    test('updateTrip only mutates the targeted row (Pitfall 4)', () async {
      final id1 = uuid.v4();
      final id2 = uuid.v4();
      final start = DateTime.utc(2026, 1, 1, 8);
      final end = DateTime.utc(2026, 1, 1, 9);
      // Insert two trips
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id1,
          startTime: start,
          endTime: end,
          durationSeconds: 3600,
          distanceMeters: 1000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 3000,
          timeStuckSeconds: 600,
          isManualEntry: const Value(false),
        ),
      );
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id2,
          startTime: start,
          endTime: end,
          durationSeconds: 3600,
          distanceMeters: 2000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 3000,
          timeStuckSeconds: 600,
          isManualEntry: const Value(false),
        ),
      );
      // Update only id1
      await db.tripsDao.updateTrip(
        TripsCompanion(
          id: Value(id1),
          direction: const Value(kDirectionToHome),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      final summaries = await db.tripsDao.watchAllSummaries().first;
      final s1 = summaries.firstWhere((s) => s.id == id1);
      final s2 = summaries.firstWhere((s) => s.id == id2);
      expect(s1.direction, kDirectionToHome);
      expect(s2.direction, kDirectionToOffice); // unchanged
    });

    test('deleteTrip removes only the targeted row', () async {
      final id1 = uuid.v4();
      final id2 = uuid.v4();
      final start = DateTime.utc(2026, 1, 1, 8);
      final end = DateTime.utc(2026, 1, 1, 9);
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id1,
          startTime: start,
          endTime: end,
          durationSeconds: 3600,
          distanceMeters: 1000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 3000,
          timeStuckSeconds: 600,
          isManualEntry: const Value(false),
        ),
      );
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id2,
          startTime: start,
          endTime: end,
          durationSeconds: 3600,
          distanceMeters: 2000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 3000,
          timeStuckSeconds: 600,
          isManualEntry: const Value(false),
        ),
      );
      await db.tripsDao.deleteTrip(id1);
      final summaries = await db.tripsDao.watchAllSummaries().first;
      expect(summaries, hasLength(1));
      expect(summaries.single.id, id2);
    });

    test(
      'manual entry insert has isManualEntry=true, distanceMeters=0.0',
      () async {
        final id = uuid.v4();
        final start = DateTime.utc(2026, 3, 15);
        final end = start.add(const Duration(minutes: 45));
        await db.tripsDao.insertTrip(
          TripsCompanion.insert(
            id: id,
            startTime: start,
            endTime: end,
            durationSeconds: 2700,
            distanceMeters: 0,
            direction: kDirectionToOffice,
            timeMovingSeconds: 0,
            timeStuckSeconds: 0,
            isManualEntry: const Value(true),
          ),
        );
        final summaries = await db.tripsDao.watchAllSummaries().first;
        expect(summaries.single.isManualEntry, isTrue);
        expect(summaries.single.distanceMeters, 0.0);
      },
    );

    group('tripIdsWithNonDefaultMetadata (Phase 26, D-01)', () {
      /// Insert a trip with all-default metadata, returning its id.
      /// Optional overrides flip individual metadata conditions.
      Future<String> insertTripWith({
        bool isEdited = false,
        String directionSource = kDirectionSourceTime,
      }) async {
        final id = uuid.v4();
        final start = DateTime.utc(2026, 5, 1, 8);
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
            isEdited: Value(isEdited),
            directionSource: Value(directionSource),
          ),
        );
        return id;
      }

      Future<void> insertBreakFor(String tripId) {
        final start = DateTime.utc(2026, 5, 1, 8, 10);
        return db.tripBreaksDao.insertBreaks([
          TripBreaksCompanion.insert(
            id: uuid.v4(),
            tripId: tripId,
            startTime: start,
            endTime: Value(start.add(const Duration(minutes: 5))),
          ),
        ]);
      }

      test('trip with isEdited=true is included', () async {
        final id = await insertTripWith(isEdited: true);
        expect(await db.tripsDao.tripIdsWithNonDefaultMetadata(), [id]);
      });

      test('trip with directionSource=geofence is included', () async {
        final id = await insertTripWith(
          directionSource: kDirectionSourceGeofence,
        );
        expect(await db.tripsDao.tripIdsWithNonDefaultMetadata(), [id]);
      });

      test('trip with a break row is included', () async {
        final id = await insertTripWith();
        await insertBreakFor(id);
        expect(await db.tripsDao.tripIdsWithNonDefaultMetadata(), [id]);
      });

      test('all-default trip is excluded', () async {
        await insertTripWith();
        expect(await db.tripsDao.tripIdsWithNonDefaultMetadata(), isEmpty);
      });

      test('trip matching multiple conditions appears exactly once', () async {
        final id = await insertTripWith(isEdited: true);
        await insertBreakFor(id);
        expect(await db.tripsDao.tripIdsWithNonDefaultMetadata(), [id]);
      });
    });
  });
}
