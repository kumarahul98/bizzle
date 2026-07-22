// Phase 35 (Deleted Trips / Trash) DAO-level coverage: the soft-delete filter,
// the deleted-trips stream, restore, the app-start purge (with clock-skew
// boundaries), the T-35-06 FK-cascade regression, and the two D-02 reader
// decisions (mostRecentGpsTrip / tripIdsWithNonDefaultMetadata excluding
// deleted rows). In-memory Drift at the current schema (v11).

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';

void main() {
  group('TripsDao soft delete / trash (Phase 35)', () {
    late AppDatabase db;

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

    Future<String> insertTrip({
      required String id,
      DateTime? start,
      bool manual = false,
    }) async {
      final s = start ?? DateTime.utc(2026, 1, 1, 8);
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          startTime: s,
          endTime: s.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
          distanceMeters: 5000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 1500,
          timeStuckSeconds: 300,
          isManualEntry: Value(manual),
        ),
      );
      return id;
    }

    test(
      'watchAllSummaries excludes soft-deleted rows; getAllTrips includes them '
      '(T-35-01)',
      () async {
        await insertTrip(id: 'live', start: DateTime.utc(2026, 1, 2, 8));
        await insertTrip(id: 'deleted', start: DateTime.utc(2026, 1, 1, 8));
        await db.tripsDao.softDeleteTrip('deleted', DateTime.utc(2026, 1, 3));

        final summaries = await db.tripsDao.watchAllSummaries().first;
        expect(summaries.map((s) => s.id), <String>['live']);
        expect(summaries.single.deletedAt, isNull);

        // Restore conflict detection MUST still see the deleted row, or a
        // cloud restore would treat it as absent and re-import it.
        final all = await db.tripsDao.getAllTrips();
        expect(all.map((t) => t.id).toSet(), <String>{'live', 'deleted'});
        expect(
          all.firstWhere((t) => t.id == 'deleted').deletedAt,
          isNotNull,
        );
      },
    );

    test(
      'watchDeletedSummaries returns only soft-deleted rows, most recently '
      'deleted first, carrying deletedAt',
      () async {
        await insertTrip(id: 'a');
        await insertTrip(id: 'b');
        await insertTrip(id: 'c'); // stays live
        await db.tripsDao.softDeleteTrip('a', DateTime.utc(2026, 1, 2));
        await db.tripsDao.softDeleteTrip('b', DateTime.utc(2026, 1, 5));

        final deleted = await db.tripsDao.watchDeletedSummaries().first;
        expect(deleted.map((s) => s.id), <String>['b', 'a']);
        expect(deleted.every((s) => s.deletedAt != null), isTrue);
      },
    );

    test(
      'softDeleteTrip then restoreTrip round-trips live visibility',
      () async {
        await insertTrip(id: 't');
        await db.tripsDao.softDeleteTrip('t', DateTime.utc(2026, 1, 3));
        expect(await db.tripsDao.watchAllSummaries().first, isEmpty);

        await db.tripsDao.restoreTrip('t');
        final summaries = await db.tripsDao.watchAllSummaries().first;
        expect(summaries.map((s) => s.id), <String>['t']);
        final row = await db.tripsDao.findById('t');
        expect(row!.deletedAt, isNull);
      },
    );

    group('purgeTripsDeletedBefore (D-04 boundaries)', () {
      // A fixed reference "now" so the boundaries are exact and deterministic.
      final now = DateTime.utc(2026, 6, 1, 12);
      final cutoff = now.subtract(const Duration(days: kTrashRetentionDays));

      test(
        '29 days kept, exactly 30 days kept (boundary), 31 days purged; live '
        'row untouched',
        () async {
          await insertTrip(id: 'd31');
          await insertTrip(id: 'd30');
          await insertTrip(id: 'd29');
          await insertTrip(id: 'live'); // never deleted
          await db.tripsDao.softDeleteTrip(
            'd31',
            now.subtract(const Duration(days: 31)),
          );
          await db.tripsDao.softDeleteTrip(
            'd30',
            now.subtract(const Duration(days: 30)),
          );
          await db.tripsDao.softDeleteTrip(
            'd29',
            now.subtract(const Duration(days: 29)),
          );

          final removed = await db.tripsDao.purgeTripsDeletedBefore(cutoff);
          expect(removed, 1);
          final remaining = (await db.tripsDao.getAllTrips())
              .map((t) => t.id)
              .toSet();
          expect(remaining, <String>{'d30', 'd29', 'live'});
        },
      );

      test(
        'a future-dated tombstone (clock moved backward) is never purged',
        () async {
          await insertTrip(id: 'future');
          await db.tripsDao.softDeleteTrip(
            'future',
            now.add(const Duration(days: 5)),
          );
          final removed = await db.tripsDao.purgeTripsDeletedBefore(cutoff);
          expect(removed, 0);
          expect(
            (await db.tripsDao.getAllTrips()).map((t) => t.id),
            contains('future'),
          );
        },
      );

      test('the purge enqueues nothing', () async {
        await insertTrip(id: 'old');
        await db.tripsDao.softDeleteTrip(
          'old',
          now.subtract(const Duration(days: 40)),
        );
        await db.tripsDao.purgeTripsDeletedBefore(cutoff);
        expect(await db.syncQueueDao.watchPending().first, isEmpty);
      });

      test(
        'purging a trip that HAS breaks cascades cleanly on a v11 db (T-35-06)',
        () async {
          await insertTrip(id: 'withbreak');
          await db.tripBreaksDao.insertBreaks([
            TripBreaksCompanion.insert(
              id: 'brk-1',
              tripId: 'withbreak',
              startTime: DateTime.utc(2026, 1, 1, 8, 4),
              endTime: Value(DateTime.utc(2026, 1, 1, 8, 6)),
            ),
          ]);
          await db.tripsDao.softDeleteTrip(
            'withbreak',
            now.subtract(const Duration(days: 40)),
          );

          final removed = await db.tripsDao.purgeTripsDeletedBefore(cutoff);
          expect(removed, 1);
          // Cascade removed the child break rather than raising an FK error.
          expect(await db.tripBreaksDao.breaksForTrip('withbreak'), isEmpty);
        },
      );
    });

    test('mostRecentGpsTrip excludes soft-deleted rows (D-02)', () async {
      await insertTrip(id: 'older', start: DateTime.utc(2026, 1, 1, 8));
      await insertTrip(id: 'newer', start: DateTime.utc(2026, 1, 2, 8));
      await db.tripsDao.softDeleteTrip('newer', DateTime.utc(2026, 1, 3));

      final row = await db.tripsDao.mostRecentGpsTrip();
      expect(row!.id, 'older');
    });

    test(
      'tripIdsWithNonDefaultMetadata excludes soft-deleted rows (D-02)',
      () async {
        await insertTrip(id: 'edited');
        await db.tripsDao.updateTrip(
          TripsCompanion(
            id: const Value('edited'),
            isEdited: const Value(true),
            updatedAt: Value(DateTime.utc(2026, 1, 2)),
          ),
        );
        expect(
          await db.tripsDao.tripIdsWithNonDefaultMetadata(),
          <String>['edited'],
        );

        await db.tripsDao.softDeleteTrip('edited', DateTime.utc(2026, 1, 3));
        expect(await db.tripsDao.tripIdsWithNonDefaultMetadata(), isEmpty);
      },
    );
  });
}
