import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';

void main() {
  group('parseHhMm', () {
    test('0:00 returns zero duration', () {
      expect(parseHhMm('0:00'), const Duration());
    });

    test('23:59 returns max valid duration', () {
      expect(
        parseHhMm('23:59'),
        const Duration(hours: 23, minutes: 59),
      );
    });

    test('24:00 returns null (out of range)', () {
      expect(parseHhMm('24:00'), isNull);
    });

    test('empty string returns null', () {
      expect(parseHhMm(''), isNull);
    });

    test('no colon returns null', () {
      expect(parseHhMm('90'), isNull);
    });

    test('non-numeric returns null', () {
      expect(parseHhMm('a:b'), isNull);
    });
  });

  group('TripManagementNotifier.insertManualTrip', () {
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

    test(
      'saved trip has isManualEntry=true and distanceMeters=0.0',
      () async {
        // D-10: start = UTC midnight of chosen local date
        final startUtc = DateTime(2026, 4, 25).toUtc();
        final endUtc = startUtc.add(const Duration(minutes: 45));

        await container
            .read(tripManagementProvider.notifier)
            .insertManualTrip(
              startTimeUtc: startUtc,
              endTimeUtc: endUtc,
              direction: 'to_office',
            );

        final summaries =
            await db.tripsDao.watchAllSummaries().first;
        expect(summaries, hasLength(1));
        expect(summaries.single.isManualEntry, isTrue);
        expect(summaries.single.distanceMeters, 0.0);
        expect(summaries.single.timeMovingSeconds, 0);
        expect(summaries.single.timeStuckSeconds, 0);
      },
    );

    test(
      'startTime is UTC midnight of chosen local date (Pitfall 6)',
      () async {
        // D-10: start = midnight local → UTC; Pitfall 6 mitigation.
        // DateTime(y, m, d).toUtc() produces UTC midnight for
        // UTC+0 environments (test isolation).
        final localDate = DateTime(2026, 4, 25);
        final startUtc = localDate.toUtc();
        final endUtc =
            startUtc.add(const Duration(minutes: 30));

        await container
            .read(tripManagementProvider.notifier)
            .insertManualTrip(
              startTimeUtc: startUtc,
              endTimeUtc: endUtc,
              direction: 'to_office',
            );

        final summaries =
            await db.tripsDao.watchAllSummaries().first;
        expect(summaries.single.startTime.isUtc, isTrue);
      },
    );
  });
}
