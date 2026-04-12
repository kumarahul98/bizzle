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

    test('inserted trip is returned by watchAllSummaries (SYNC-01)',
        () async {
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
  });
}
