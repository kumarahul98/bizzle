import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/tracking/providers/backfill_provider.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('DirectionBackfillProvider', () {
    late AppDatabase db;
    late ProviderContainer container;
    const uuid = Uuid();

    /// Insert a minimal trip with [direction] and [startTime].
    Future<String> insertTrip({
      required String direction,
      required DateTime startTime,
    }) async {
      final id = uuid.v4();
      final end = startTime.add(const Duration(minutes: 30));
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          startTime: startTime,
          endTime: end,
          durationSeconds: 1800,
          distanceMeters: 0,
          direction: direction,
          timeMovingSeconds: 0,
          timeStuckSeconds: 0,
        ),
      );
      return id;
    }

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
          userPreferencesDaoProvider.overrideWithValue(
            db.userPreferencesDao,
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test(
      'updates kDirectionUnknown trips with labeled direction',
      () async {
        // 08:00 UTC — hour < 12 → kDirectionToOffice
        // 18:00 UTC — hour >= 12 → kDirectionToHome
        // (toLocal() in UTC test env preserves hours)
        await insertTrip(
          direction: kDirectionUnknown,
          startTime: DateTime.utc(2026, 4, 25, 8),
        );
        await insertTrip(
          direction: kDirectionUnknown,
          startTime: DateTime.utc(2026, 4, 25, 18),
        );

        await container.read(directionBackfillProvider.future);

        final summaries =
            await db.tripsDao.watchAllSummaries().first;
        expect(summaries, hasLength(2));
        for (final s in summaries) {
          expect(s.direction, isNot(kDirectionUnknown));
        }
        final morning = summaries.firstWhere(
          (s) =>
              s.startTime.millisecondsSinceEpoch ==
              DateTime.utc(2026, 4, 25, 8)
                  .millisecondsSinceEpoch,
        );
        final evening = summaries.firstWhere(
          (s) =>
              s.startTime.millisecondsSinceEpoch ==
              DateTime.utc(2026, 4, 25, 18)
                  .millisecondsSinceEpoch,
        );
        expect(morning.direction, kDirectionToOffice);
        expect(evening.direction, kDirectionToHome);
      },
    );

    test(
      'leaves already-labeled trips unchanged',
      () async {
        final labeledId = await insertTrip(
          direction: kDirectionToOffice,
          startTime: DateTime.utc(2026, 4, 25, 8),
        );
        await insertTrip(
          direction: kDirectionUnknown,
          startTime: DateTime.utc(2026, 4, 25, 18),
        );

        await container.read(directionBackfillProvider.future);

        final summaries =
            await db.tripsDao.watchAllSummaries().first;
        final labeled =
            summaries.firstWhere((s) => s.id == labeledId);
        expect(labeled.direction, kDirectionToOffice);

        final backfilled = summaries.firstWhere(
          (s) => s.id != labeledId,
        );
        expect(backfilled.direction, kDirectionToHome);
      },
    );

    test(
      'enqueues kSyncActionUpdate for each backfilled trip',
      () async {
        await insertTrip(
          direction: kDirectionUnknown,
          startTime: DateTime.utc(2026, 4, 25, 8),
        );
        await insertTrip(
          direction: kDirectionUnknown,
          startTime: DateTime.utc(2026, 4, 25, 18),
        );

        await container.read(directionBackfillProvider.future);

        final pending =
            await db.syncQueueDao.watchPending().first;
        expect(pending, hasLength(2));
        for (final row in pending) {
          expect(row.action, kSyncActionUpdate);
        }
      },
    );

    test(
      'no-op when no kDirectionUnknown trips exist',
      () async {
        await insertTrip(
          direction: kDirectionToOffice,
          startTime: DateTime.utc(2026, 4, 25, 8),
        );

        await container.read(directionBackfillProvider.future);

        final pending =
            await db.syncQueueDao.watchPending().first;
        expect(pending, isEmpty);
      },
    );
  });
}
