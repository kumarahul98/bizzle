// Phase 35 (T-35-05): soft-deleting a trip must drop it out of stats, and
// restoring it must bring the totals back. This exercises the real reactive
// chain — watchAllSummaries() → allTripSummariesProvider → statsSummaryProvider
// — against an in-memory Drift database, proving the SINGLE watchAllSummaries
// filter reaches stats and not just history/dashboard.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';

void main() {
  group('stats react to soft delete / restore (Phase 35, T-35-05)', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      // The cascade keeps the derived stats provider (and its upstream Drift
      // stream) alive for the duration of the test.
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tripsDaoProvider.overrideWithValue(db.tripsDao),
        ],
      )..listen(statsSummaryProvider, (_, _) {});
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    // Let the Drift query-stream re-emit and the derived providers recompute.
    Future<void> settle() => Future<void>.delayed(
      const Duration(milliseconds: 50),
    );

    test('week total drops on soft delete and returns on restore', () async {
      // A trip an hour ago — unambiguously inside this week and month.
      final start = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: 'stat-trip',
          startTime: start,
          endTime: start.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
          distanceMeters: 5000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 1500,
          timeStuckSeconds: 300,
        ),
      );
      await settle();

      final withTrip = container.read(statsSummaryProvider).value;
      expect(withTrip, isNotNull);
      expect(withTrip!.hasAnyTrips, isTrue);
      expect(withTrip.weekTotalSeconds, 1800);
      expect(withTrip.weekStuckSeconds, 300);

      await db.tripsDao.softDeleteTrip('stat-trip', DateTime.now().toUtc());
      await settle();

      final afterDelete = container.read(statsSummaryProvider).value;
      expect(afterDelete!.hasAnyTrips, isFalse);
      expect(afterDelete.weekTotalSeconds, 0);
      expect(afterDelete.weekStuckSeconds, 0);

      await db.tripsDao.restoreTrip('stat-trip');
      await settle();

      final afterRestore = container.read(statsSummaryProvider).value;
      expect(afterRestore!.hasAnyTrips, isTrue);
      expect(afterRestore.weekTotalSeconds, 1800);
      expect(afterRestore.weekStuckSeconds, 300);
    });
  });
}
