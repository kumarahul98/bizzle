import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('TripStuckSegmentsDao.deleteSegmentsOutsideWindow', () {
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

    /// Insert a parent trip so segment inserts satisfy the FK constraint.
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

    Future<void> insertSegment({
      required String id,
      required String tripId,
      required int startPointIndex,
      required int endPointIndex,
      required DateTime startTime,
      required DateTime endTime,
    }) {
      return db.tripStuckSegmentsDao.insertSegments([
        TripStuckSegmentsCompanion.insert(
          id: id,
          tripId: tripId,
          startPointIndex: startPointIndex,
          endPointIndex: endPointIndex,
          startTime: startTime,
          endTime: endTime,
        ),
      ]);
    }

    test(
      'wholly-before, touches-start, inside, both straddles, wholly-after '
      'and touches-end are each resolved per the endTime<=newStart OR '
      'startTime>=newEnd rule; a straddling segment keeps its original '
      'timestamps and point indices untouched (D-3)',
      () async {
        final tripId = await insertParentTrip();
        const newStart = 8; // 08:00Z
        const newEnd = 9; // 09:00Z
        final windowStart = DateTime.utc(2026, 1, 1, newStart);
        final windowEnd = DateTime.utc(2026, 1, 1, newEnd);

        // Wholly before the window -> deleted.
        await insertSegment(
          id: 'before',
          tripId: tripId,
          startPointIndex: 0,
          endPointIndex: 1,
          startTime: DateTime.utc(2026, 1, 1, 7),
          endTime: DateTime.utc(2026, 1, 1, 7, 30),
        );

        // endTime == newStart -> the rule is endTime <= newStart, so an
        // exact touch at the boundary is outside -> deleted.
        await insertSegment(
          id: 'touchesStart',
          tripId: tripId,
          startPointIndex: 2,
          endPointIndex: 3,
          startTime: DateTime.utc(2026, 1, 1, 7, 30),
          endTime: DateTime.utc(2026, 1, 1, newStart),
        );

        // Fully within the window -> kept.
        await insertSegment(
          id: 'inside',
          tripId: tripId,
          startPointIndex: 4,
          endPointIndex: 5,
          startTime: DateTime.utc(2026, 1, 1, 8, 10),
          endTime: DateTime.utc(2026, 1, 1, 8, 20),
        );

        // Straddles the start edge -> kept, untouched.
        final straddlesStartStart = DateTime.utc(2026, 1, 1, 7, 50);
        final straddlesStartEnd = DateTime.utc(2026, 1, 1, 8, 10);
        await insertSegment(
          id: 'straddlesStart',
          tripId: tripId,
          startPointIndex: 6,
          endPointIndex: 7,
          startTime: straddlesStartStart,
          endTime: straddlesStartEnd,
        );

        // Straddles the end edge -> kept, untouched.
        final straddlesEndStart = DateTime.utc(2026, 1, 1, 8, 50);
        final straddlesEndEnd = DateTime.utc(2026, 1, 1, 9, 10);
        await insertSegment(
          id: 'straddlesEnd',
          tripId: tripId,
          startPointIndex: 8,
          endPointIndex: 9,
          startTime: straddlesEndStart,
          endTime: straddlesEndEnd,
        );

        // startTime == newEnd -> the rule is startTime >= newEnd, so an
        // exact touch at the boundary is outside -> deleted.
        await insertSegment(
          id: 'touchesEnd',
          tripId: tripId,
          startPointIndex: 10,
          endPointIndex: 11,
          startTime: DateTime.utc(2026, 1, 1, newEnd),
          endTime: DateTime.utc(2026, 1, 1, 9, 10),
        );

        // Wholly after the window -> deleted.
        await insertSegment(
          id: 'after',
          tripId: tripId,
          startPointIndex: 12,
          endPointIndex: 13,
          startTime: DateTime.utc(2026, 1, 1, 9, 30),
          endTime: DateTime.utc(2026, 1, 1, 9, 40),
        );

        // A segment belonging to a DIFFERENT trip, wholly outside the
        // window on the "startTime >= newEnd" side, proves the tripId guard
        // survived the &/| precedence. Without the parentheses around the
        // OR group, Dart's tighter `&` binding drops the tripId guard from
        // this disjunct entirely and this row would be deleted even though
        // it belongs to a different trip.
        final otherTripId = await insertParentTrip();
        await insertSegment(
          id: 'otherTrip',
          tripId: otherTripId,
          startPointIndex: 0,
          endPointIndex: 1,
          startTime: DateTime.utc(2026, 1, 1, 9, 30),
          endTime: DateTime.utc(2026, 1, 1, 9, 40),
        );

        await db.tripStuckSegmentsDao.deleteSegmentsOutsideWindow(
          tripId: tripId,
          startTimeUtc: windowStart,
          endTimeUtc: windowEnd,
        );

        final surviving = await db.tripStuckSegmentsDao.watch(tripId).first;
        expect(
          surviving.map((s) => s.id),
          unorderedEquals(['inside', 'straddlesStart', 'straddlesEnd']),
        );

        final straddlesStart = surviving.singleWhere(
          (s) => s.id == 'straddlesStart',
        );
        expect(
          straddlesStart.startTime.isAtSameMomentAs(straddlesStartStart),
          isTrue,
        );
        expect(
          straddlesStart.endTime.isAtSameMomentAs(straddlesStartEnd),
          isTrue,
        );
        expect(straddlesStart.startPointIndex, 6);
        expect(straddlesStart.endPointIndex, 7);

        final straddlesEnd = surviving.singleWhere(
          (s) => s.id == 'straddlesEnd',
        );
        expect(
          straddlesEnd.startTime.isAtSameMomentAs(straddlesEndStart),
          isTrue,
        );
        expect(
          straddlesEnd.endTime.isAtSameMomentAs(straddlesEndEnd),
          isTrue,
        );
        expect(straddlesEnd.startPointIndex, 8);
        expect(straddlesEnd.endPointIndex, 9);

        // The other trip's wholly-outside segment must survive untouched —
        // proof the tripId guard is correctly parenthesized against the
        // OR group (T-TJX-01).
        final otherTripSurviving = await db.tripStuckSegmentsDao
            .watch(otherTripId)
            .first;
        expect(otherTripSurviving, hasLength(1));
        expect(otherTripSurviving.single.id, 'otherTrip');
      },
    );
  });
}
