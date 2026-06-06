import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('TripBreaksDao', () {
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

    /// Insert a parent trip so break inserts satisfy the FK constraint.
    Future<String> insertParentTrip() async {
      final id = uuid.v4();
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          startTime: DateTime.utc(2026, 1, 1, 8),
          endTime: DateTime.utc(2026, 1, 1, 9),
          durationSeconds: 3600,
          distanceMeters: 12345.6,
          direction: kDirectionToOffice,
          timeMovingSeconds: 3000,
          timeStuckSeconds: 600,
        ),
      );
      return id;
    }

    test(
      'insertBreaks + breaksForTrip round-trips ordered by startTime',
      () async {
        final tripId = await insertParentTrip();

        // Two segments inserted out of chronological order on purpose, to
        // prove breaksForTrip orders by start_time, not insertion order.
        final laterStart = DateTime.utc(2026, 1, 1, 8, 40);
        final laterEnd = DateTime.utc(2026, 1, 1, 8, 45);
        final earlierStart = DateTime.utc(2026, 1, 1, 8, 10);
        final earlierEnd = DateTime.utc(2026, 1, 1, 8, 15);

        await db.tripBreaksDao.insertBreaks([
          TripBreaksCompanion.insert(
            id: uuid.v4(),
            tripId: tripId,
            startTime: laterStart,
            endTime: Value<DateTime>(laterEnd),
          ),
          TripBreaksCompanion.insert(
            id: uuid.v4(),
            tripId: tripId,
            startTime: earlierStart,
            endTime: Value<DateTime>(earlierEnd),
          ),
        ]);

        // Drift's default datetime storage persists a Unix timestamp and
        // reads it back as a local-time DateTime representing the same
        // instant — so compare instants with isAtSameMomentAs, not the
        // (timezone-tagged) DateTime objects directly.
        final breaks = await db.tripBreaksDao.breaksForTrip(tripId);
        expect(breaks, hasLength(2));
        expect(breaks.first.startTime.isAtSameMomentAs(earlierStart), isTrue);
        expect(breaks.first.endTime!.isAtSameMomentAs(earlierEnd), isTrue);
        expect(breaks.last.startTime.isAtSameMomentAs(laterStart), isTrue);
        expect(breaks.last.endTime!.isAtSameMomentAs(laterEnd), isTrue);
      },
    );

    test('an open break (endTime null) round-trips', () async {
      final tripId = await insertParentTrip();
      final breakId = uuid.v4();
      final start = DateTime.utc(2026, 1, 1, 8, 20);

      await db.tripBreaksDao.insertBreaks([
        TripBreaksCompanion.insert(
          id: breakId,
          tripId: tripId,
          startTime: start,
        ),
      ]);

      final breaks = await db.tripBreaksDao.breaksForTrip(tripId);
      expect(breaks, hasLength(1));
      expect(breaks.single.id, breakId);
      expect(breaks.single.startTime.isAtSameMomentAs(start), isTrue);
      expect(breaks.single.endTime, isNull);
    });

    test('FK enforcement rejects a break for a missing trip id', () async {
      // No parent trip inserted — the FK to trips.id must reject this.
      await expectLater(
        db.tripBreaksDao.insertBreaks([
          TripBreaksCompanion.insert(
            id: uuid.v4(),
            tripId: 'no-such-trip',
            startTime: DateTime.utc(2026, 1, 1, 8, 20),
            endTime: Value<DateTime>(DateTime.utc(2026, 1, 1, 8, 25)),
          ),
        ]),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
