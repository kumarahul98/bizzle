import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';
import 'package:traevy/features/trips/services/trip_edit_recompute.dart';
import 'package:uuid/uuid.dart';

/// Proves the Phase 19 atomic full-edit write path (D-11/D-12) and the
/// preserved direction-only backward-compatible path.
void main() {
  group('TripManagementNotifier.editTrip (full edit, Phase 19)', () {
    late AppDatabase db;
    late ProviderContainer container;
    const uuid = Uuid();

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    final start = DateTime.utc(2026, 1, 1, 8);
    final end = DateTime.utc(2026, 1, 1, 9);

    Future<String> insertTrip() async {
      final id = uuid.v4();
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
      return id;
    }

    Future<void> insertBreak(String tripId, int startMin, int endMin) {
      return db.tripBreaksDao.insertBreaks([
        TripBreaksCompanion.insert(
          id: uuid.v4(),
          tripId: tripId,
          startTime: start.add(Duration(minutes: startMin)),
          endTime: Value<DateTime>(start.add(Duration(minutes: endMin))),
        ),
      ]);
    }

    Future<int> pendingSyncCount() async {
      final pending = await db.syncQueueDao.getPending();
      return pending.length;
    }

    test(
      'direction-only editTrip leaves breaks + is_edited untouched',
      () async {
        final tripId = await insertTrip();
        await insertBreak(tripId, 10, 15);
        await insertBreak(tripId, 40, 45);

        final notifier = container.read(tripManagementProvider.notifier);
        await notifier.editTrip(
          tripId: tripId,
          direction: kDirectionToHome,
          startTimeUtc: start,
          endTimeUtc: end,
        );

        expect(
          container.read(tripManagementProvider),
          isA<TripManagementSaved>(),
        );

        final row = await db.tripsDao.findById(tripId);
        expect(row!.direction, kDirectionToHome);
        expect(row.isEdited, isFalse, reason: 'no full-edit params → no flag');

        final breaks = await db.tripBreaksDao.breaksForTrip(tripId);
        expect(breaks, hasLength(2), reason: 'breaks untouched');

        expect(await pendingSyncCount(), 1);
      },
    );

    test(
      'full editTrip replaces breaks, recomputes stats, sets is_edited, '
      'enqueues one update',
      () async {
        final tripId = await insertTrip();
        await insertBreak(tripId, 10, 15); // old break to be replaced

        // New window: 08:00–09:30 (5400s) with a single 600s break →
        // active 4800. Original moving:stuck 3000:600 (5:1).
        final newEnd = DateTime.utc(2026, 1, 1, 9, 30);
        final newBreak = EditBreakSegment(
          start: DateTime.utc(2026, 1, 1, 8, 20),
          end: DateTime.utc(2026, 1, 1, 8, 30),
        );
        const newActive = 4800;
        final rescaled = TripEditRecompute.rescaleTraffic(
          origMoving: 3000,
          origStuck: 600,
          newActiveSeconds: newActive,
        );

        final notifier = container.read(tripManagementProvider.notifier);
        await notifier.editTrip(
          tripId: tripId,
          direction: kDirectionToOffice,
          startTimeUtc: start,
          endTimeUtc: newEnd,
          breaks: [newBreak],
          totalPausedSeconds: 600,
          timeMovingSeconds: rescaled.moving,
          timeStuckSeconds: rescaled.stuck,
          durationSecondsOverride: newActive,
          markEdited: true,
        );

        expect(
          container.read(tripManagementProvider),
          isA<TripManagementSaved>(),
        );

        final row = await db.tripsDao.findById(tripId);
        expect(row!.durationSeconds, newActive);
        expect(row.totalPausedSeconds, 600);
        expect(row.timeMovingSeconds, rescaled.moving);
        expect(row.timeStuckSeconds, rescaled.stuck);
        expect(row.timeMovingSeconds + row.timeStuckSeconds, newActive);
        expect(row.isEdited, isTrue);
        expect(row.endTime.isAtSameMomentAs(newEnd), isTrue);

        final breaks = await db.tripBreaksDao.breaksForTrip(tripId);
        expect(breaks, hasLength(1), reason: 'wholesale replace');
        expect(
          breaks.single.startTime.isAtSameMomentAs(newBreak.start),
          isTrue,
        );
        expect(breaks.single.endTime!.isAtSameMomentAs(newBreak.end), isTrue);

        expect(await pendingSyncCount(), 1);
      },
    );

    test('transaction rolls back on failure', () async {
      // No trips row for this id, but request a break insert. The break's FK
      // to trips.id is rejected, rolling back the whole transaction: no break
      // row is left behind and the notifier reports an error.
      final missingTripId = uuid.v4();
      final orphanBreak = EditBreakSegment(
        start: start.add(const Duration(minutes: 5)),
        end: start.add(const Duration(minutes: 10)),
      );

      final notifier = container.read(tripManagementProvider.notifier);
      await notifier.editTrip(
        tripId: missingTripId,
        direction: kDirectionToOffice,
        startTimeUtc: start,
        endTimeUtc: end,
        breaks: [orphanBreak],
        totalPausedSeconds: 300,
        timeMovingSeconds: 0,
        timeStuckSeconds: 0,
        durationSecondsOverride: 3300,
        markEdited: true,
      );

      expect(
        container.read(tripManagementProvider),
        isA<TripManagementError>(),
      );
      // Rollback: no break rows for the missing trip.
      expect(await db.tripBreaksDao.breaksForTrip(missingTripId), isEmpty);
    });

    /// A single in-window stuck segment. Used to prove a full edit RETAINS a
    /// segment overlapping the new window even when the hand-entered
    /// `timeStuckSeconds` no longer matches it (D-4).
    Future<void> insertStuckSegment(String tripId) {
      return db.tripStuckSegmentsDao.insertSegments([
        TripStuckSegmentsCompanion.insert(
          id: uuid.v4(),
          tripId: tripId,
          startPointIndex: 0,
          endPointIndex: 40,
          startTime: start,
          endTime: start.add(const Duration(minutes: 10)),
        ),
      ]);
    }

    test(
      'full edit RETAINS an in-window stuck segment even though the new '
      'stuck total no longer matches it (D-4, reverses Phase 31 D-06)',
      () async {
        final id = await insertTrip();
        await insertStuckSegment(id);
        expect(await db.tripStuckSegmentsDao.watch(id).first, hasLength(1));

        final notifier = container.read(tripManagementProvider.notifier);
        // The window is unchanged (start..end), so the segment still fully
        // overlaps it. The new stuck total of 60s is far below the 600s
        // segment already stored — that mismatch is the accepted D-4
        // consequence, not a reason to delete the segment: a stuck segment
        // records WHERE the user was physically slow, and no edit to the
        // trip's times or totals can make that untrue.
        await notifier.editTrip(
          tripId: id,
          direction: kDirectionToOffice,
          startTimeUtc: start,
          endTimeUtc: end,
          totalPausedSeconds: 0,
          timeMovingSeconds: 3540,
          timeStuckSeconds: 60,
          durationSecondsOverride: 3600,
          markEdited: true,
        );

        expect(
          container.read(tripManagementProvider),
          isA<TripManagementSaved>(),
        );
        final survivors = await db.tripStuckSegmentsDao.watch(id).first;
        expect(survivors, hasLength(1));
        expect(survivors.single.startTime.isAtSameMomentAs(start), isTrue);
        expect(
          survivors.single.endTime.isAtSameMomentAs(
            start.add(const Duration(minutes: 10)),
          ),
          isTrue,
        );
        expect(survivors.single.startPointIndex, 0);
        expect(survivors.single.endPointIndex, 40);
      },
    );

    test(
      'full edit deletes only the stuck segment stranded by the new window, '
      'inside the same transaction as the trip update',
      () async {
        final id = await insertTrip();
        await db.tripStuckSegmentsDao.insertSegments([
          TripStuckSegmentsCompanion.insert(
            id: 'early',
            tripId: id,
            startPointIndex: 0,
            endPointIndex: 5,
            startTime: start,
            endTime: start.add(const Duration(minutes: 5)),
          ),
          TripStuckSegmentsCompanion.insert(
            id: 'late',
            tripId: id,
            startPointIndex: 30,
            endPointIndex: 40,
            startTime: start.add(const Duration(minutes: 45)),
            endTime: start.add(const Duration(minutes: 50)),
          ),
        ]);
        expect(await db.tripStuckSegmentsDao.watch(id).first, hasLength(2));

        // New window starts after the early segment ends, excluding it.
        final newStart = start.add(const Duration(minutes: 20));
        final notifier = container.read(tripManagementProvider.notifier);
        await notifier.editTrip(
          tripId: id,
          direction: kDirectionToOffice,
          startTimeUtc: newStart,
          endTimeUtc: end,
          totalPausedSeconds: 0,
          timeMovingSeconds: 2340,
          timeStuckSeconds: 300,
          durationSecondsOverride: 2400,
          markEdited: true,
        );

        expect(
          container.read(tripManagementProvider),
          isA<TripManagementSaved>(),
        );
        final survivors = await db.tripStuckSegmentsDao.watch(id).first;
        expect(survivors, hasLength(1));
        expect(survivors.single.id, 'late');
      },
    );

    test(
      'direction-only edit keeps stuck segments, which stay valid',
      () async {
        final id = await insertTrip();
        await insertStuckSegment(id);

        final notifier = container.read(tripManagementProvider.notifier);
        // No markEdited: timeStuckSeconds is left absent, so the recorded
        // segments still describe the same measurement.
        await notifier.editTrip(
          tripId: id,
          direction: kDirectionToHome,
          startTimeUtc: start,
          endTimeUtc: end,
        );

        expect(
          container.read(tripManagementProvider),
          isA<TripManagementSaved>(),
        );
        expect(await db.tripStuckSegmentsDao.watch(id).first, hasLength(1));
      },
    );
  });
}
