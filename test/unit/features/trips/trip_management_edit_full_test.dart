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
  });
}
