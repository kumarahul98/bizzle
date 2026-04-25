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

        final summaries =
            await db.tripsDao.watchAllSummaries().first;
        expect(summaries, hasLength(1));
        expect(summaries.single.direction, kDirectionToHome);

        final pending =
            await db.syncQueueDao.watchPending().first;
        expect(pending, hasLength(1));
        expect(pending.single.action, kSyncActionUpdate);
        expect(pending.single.tripId, id);
      },
    );

    test(
      'deleteTrip removes trip and enqueues kSyncActionDelete',
      () async {
        final id = await insertTestTrip();

        await container
            .read(tripManagementProvider.notifier)
            .deleteTrip(id);

        final summaries =
            await db.tripsDao.watchAllSummaries().first;
        expect(summaries, isEmpty);

        final pending =
            await db.syncQueueDao.watchPending().first;
        expect(pending, hasLength(1));
        expect(pending.single.action, kSyncActionDelete);
        expect(pending.single.tripId, id);
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

        await container
            .read(tripManagementProvider.notifier)
            .deleteTrip(id);

        expect(
          container.read(tripManagementProvider),
          isA<TripManagementSaved>(),
        );
      },
    );
  });
}
