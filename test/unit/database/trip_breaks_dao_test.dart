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
      'deleteBreaksForTrip removes only the target trip breaks',
      () async {
        final tripA = await insertParentTrip();
        final tripB = await insertParentTrip();

        Future<void> insertTwoBreaks(String tripId) {
          return db.tripBreaksDao.insertBreaks([
            TripBreaksCompanion.insert(
              id: uuid.v4(),
              tripId: tripId,
              startTime: DateTime.utc(2026, 1, 1, 8, 10),
              endTime: Value<DateTime>(DateTime.utc(2026, 1, 1, 8, 15)),
            ),
            TripBreaksCompanion.insert(
              id: uuid.v4(),
              tripId: tripId,
              startTime: DateTime.utc(2026, 1, 1, 8, 40),
              endTime: Value<DateTime>(DateTime.utc(2026, 1, 1, 8, 45)),
            ),
          ]);
        }

        await insertTwoBreaks(tripA);
        await insertTwoBreaks(tripB);

        await db.tripBreaksDao.deleteBreaksForTrip(tripA);

        expect(await db.tripBreaksDao.breaksForTrip(tripA), isEmpty);
        expect(await db.tripBreaksDao.breaksForTrip(tripB), hasLength(2));
      },
    );

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

    group('breaksForTripIds', () {
      test('empty list returns {} with no query executed', () async {
        final result = await db.tripBreaksDao.breaksForTripIds([]);
        expect(result, isEmpty);
      });

      test(
        'two trips each with breaks returns a correctly-keyed and ordered '
        'map, excluding a third trip not in the requested id list',
        () async {
          final tripA = await insertParentTrip();
          final tripB = await insertParentTrip();
          final tripC = await insertParentTrip();

          // tripA: two breaks inserted out of chronological order, to prove
          // ordering is by startTime, not insertion order.
          await db.tripBreaksDao.insertBreaks([
            TripBreaksCompanion.insert(
              id: uuid.v4(),
              tripId: tripA,
              startTime: DateTime.utc(2026, 1, 1, 8, 40),
              endTime: Value<DateTime>(DateTime.utc(2026, 1, 1, 8, 45)),
            ),
            TripBreaksCompanion.insert(
              id: uuid.v4(),
              tripId: tripA,
              startTime: DateTime.utc(2026, 1, 1, 8, 10),
              endTime: Value<DateTime>(DateTime.utc(2026, 1, 1, 8, 15)),
            ),
          ]);

          // tripB: a single break.
          await db.tripBreaksDao.insertBreaks([
            TripBreaksCompanion.insert(
              id: uuid.v4(),
              tripId: tripB,
              startTime: DateTime.utc(2026, 1, 1, 9, 0),
              endTime: Value<DateTime>(DateTime.utc(2026, 1, 1, 9, 5)),
            ),
          ]);

          // tripC: breaks exist but tripC is NOT in the requested id list —
          // must be excluded from the result entirely.
          await db.tripBreaksDao.insertBreaks([
            TripBreaksCompanion.insert(
              id: uuid.v4(),
              tripId: tripC,
              startTime: DateTime.utc(2026, 1, 1, 10, 0),
              endTime: Value<DateTime>(DateTime.utc(2026, 1, 1, 10, 5)),
            ),
          ]);

          final result = await db.tripBreaksDao.breaksForTripIds([
            tripA,
            tripB,
          ]);

          expect(result.keys, unorderedEquals([tripA, tripB]));
          expect(result[tripA], hasLength(2));
          expect(
            result[tripA]!.first.startTime.isAtSameMomentAs(
              DateTime.utc(2026, 1, 1, 8, 10),
            ),
            isTrue,
          );
          expect(
            result[tripA]!.last.startTime.isAtSameMomentAs(
              DateTime.utc(2026, 1, 1, 8, 40),
            ),
            isTrue,
          );
          expect(result[tripB], hasLength(1));
        },
      );
    });
  });
}
