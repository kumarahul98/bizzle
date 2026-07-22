import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';

void main() {
  group('TripManagementNotifier', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    /// Insert a minimal valid trip for testing purposes.
    Future<String> insertTestTrip({String? id}) async {
      final tripId = id ?? 'test-trip-001';
      final start = DateTime.utc(2026, 4, 25, 8);
      final end = start.add(const Duration(minutes: 30));
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: tripId,
          startTime: start,
          endTime: end,
          durationSeconds: 1800,
          distanceMeters: 5000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 1500,
          timeStuckSeconds: 300,
        ),
      );
      return tripId;
    }

    test(
      'editTrip updates direction and enqueues kSyncActionUpdate',
      () async {
        final id = await insertTestTrip();
        final start = DateTime.utc(2026, 4, 25, 8);
        final end = start.add(const Duration(minutes: 30));

        await container
            .read(tripManagementProvider.notifier)
            .editTrip(
              tripId: id,
              direction: kDirectionToHome,
              startTimeUtc: start,
              endTimeUtc: end,
            );

        final summaries = await db.tripsDao.watchAllSummaries().first;
        expect(summaries, hasLength(1));
        expect(summaries.single.direction, kDirectionToHome);

        final pending = await db.syncQueueDao.watchPending().first;
        expect(pending, hasLength(1));
        expect(pending.single.action, kSyncActionUpdate);
        expect(pending.single.tripId, id);
      },
    );

    test(
      'deleteTrip removes trip and enqueues kSyncActionDelete',
      () async {
        final id = await insertTestTrip();

        await container.read(tripManagementProvider.notifier).deleteTrip(id);

        final summaries = await db.tripsDao.watchAllSummaries().first;
        expect(summaries, isEmpty);

        final pending = await db.syncQueueDao.watchPending().first;
        expect(pending, hasLength(1));
        expect(pending.single.action, kSyncActionDelete);
        expect(pending.single.tripId, id);
      },
    );

    // --- Phase 35: soft delete, restore, permanent delete ------------------

    test(
      'deleteTrip SOFT-deletes: the row survives with deletedAt set and the '
      'delete payload shape is unchanged (Phase 35, D-01/D-03)',
      () async {
        final id = await insertTestTrip();

        await container.read(tripManagementProvider.notifier).deleteTrip(id);

        // Gone from the live surface, but still physically present (soft).
        expect(await db.tripsDao.watchAllSummaries().first, isEmpty);
        final row = await db.tripsDao.findById(id);
        expect(row, isNotNull);
        expect(row!.deletedAt, isNotNull);

        // The wire contract is untouched: a delete action carrying the same
        // {id, userId} payload as before soft delete existed.
        final pending = await db.syncQueueDao.watchPending().first;
        expect(pending, hasLength(1));
        expect(pending.single.action, kSyncActionDelete);
        final payload =
            jsonDecode(pending.single.payload!) as Map<String, dynamic>;
        expect(payload.keys.toSet(), <String>{'id', 'userId'});
        expect(payload['id'], id);
        expect(payload['userId'], kDefaultUserId);
      },
    );

    test(
      'deleteTrip on a trip WITH breaks succeeds — no FK violation (T-35-06)',
      () async {
        final id = await insertTestTrip();
        await db.tripBreaksDao.insertBreaks([
          TripBreaksCompanion.insert(
            id: 'brk-1',
            tripId: id,
            startTime: DateTime.utc(2026, 4, 25, 8, 10),
            endTime: Value(DateTime.utc(2026, 4, 25, 8, 12)),
          ),
        ]);

        await container.read(tripManagementProvider.notifier).deleteTrip(id);

        expect(
          container.read(tripManagementProvider),
          isA<TripManagementSaved>(),
        );
        // Soft delete performs no DELETE, so the break is untouched and returns
        // with the trip on restore.
        expect(await db.tripBreaksDao.breaksForTrip(id), hasLength(1));
      },
    );

    test(
      'restoreTrip clears deletedAt and enqueues a create (Phase 35, D-03)',
      () async {
        final id = await insertTestTrip();
        await container.read(tripManagementProvider.notifier).deleteTrip(id);
        expect(await db.tripsDao.watchAllSummaries().first, isEmpty);

        await container.read(tripManagementProvider.notifier).restoreTrip(id);

        // Back on the live surface, deletedAt cleared.
        final summaries = await db.tripsDao.watchAllSummaries().first;
        expect(summaries.map((s) => s.id), <String>[id]);
        expect((await db.tripsDao.findById(id))!.deletedAt, isNull);

        // A create is enqueued alongside the earlier delete.
        final pending = await db.syncQueueDao.watchPending().first;
        expect(
          pending.map((r) => r.action),
          containsAll(<String>[kSyncActionDelete, kSyncActionCreate]),
        );
        final create = pending.firstWhere((r) => r.action == kSyncActionCreate);
        expect(create.tripId, id);
      },
    );

    test(
      'deleteTripPermanently hard-deletes, cascades breaks, and enqueues '
      'nothing (Phase 35, D-05)',
      () async {
        final id = await insertTestTrip();
        await db.tripBreaksDao.insertBreaks([
          TripBreaksCompanion.insert(
            id: 'brk-1',
            tripId: id,
            startTime: DateTime.utc(2026, 4, 25, 8, 10),
            endTime: Value(DateTime.utc(2026, 4, 25, 8, 12)),
          ),
        ]);
        // Simulate a trip already sitting in the Trash.
        await db.tripsDao.softDeleteTrip(id, DateTime.utc(2026, 4, 26));

        await container
            .read(tripManagementProvider.notifier)
            .deleteTripPermanently(id);

        expect(
          container.read(tripManagementProvider),
          isA<TripManagementSaved>(),
        );
        expect(await db.tripsDao.findById(id), isNull);
        expect(await db.tripBreaksDao.breaksForTrip(id), isEmpty);
        // The tombstone was already pushed at soft-delete time; the permanent
        // delete pushes nothing further.
        expect(await db.syncQueueDao.watchPending().first, isEmpty);
      },
    );

    test(
      'editTrip transitions state: Idle → Saving → Saved',
      () async {
        final id = await insertTestTrip();
        final start = DateTime.utc(2026, 4, 25, 8);
        final end = start.add(const Duration(minutes: 30));

        expect(
          container.read(tripManagementProvider),
          isA<TripManagementIdle>(),
        );

        await container
            .read(tripManagementProvider.notifier)
            .editTrip(
              tripId: id,
              direction: kDirectionToHome,
              startTimeUtc: start,
              endTimeUtc: end,
            );

        expect(
          container.read(tripManagementProvider),
          isA<TripManagementSaved>(),
        );
      },
    );

    test(
      'deleteTrip transitions state: Idle → Saving → Saved',
      () async {
        final id = await insertTestTrip();

        expect(
          container.read(tripManagementProvider),
          isA<TripManagementIdle>(),
        );

        await container.read(tripManagementProvider.notifier).deleteTrip(id);

        expect(
          container.read(tripManagementProvider),
          isA<TripManagementSaved>(),
        );
      },
    );
  });
}
