import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';

void main() {
  group('SyncQueueDao', () {
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

    test('enqueueCreate writes a row with null payload (D-13)', () async {
      await db.syncQueueDao.enqueueCreate('trip-1');

      final row = await (db.select(db.syncQueue)
            ..where((q) => q.tripId.equals('trip-1')))
          .getSingle();

      expect(row.payload, isNull);
      expect(row.action, kSyncActionCreate);
      expect(row.status, kSyncStatusPending);
      expect(row.retryCount, 0);
      expect(row.syncedAt, isNull);
    });

    test('enqueueDelete writes a row with non-null payload (D-13)',
        () async {
      const payload = '{"id":"trip-1","user_id":"local_user"}';
      await db.syncQueueDao.enqueueDelete(
        tripId: 'trip-1',
        payload: payload,
      );

      final row = await (db.select(db.syncQueue)
            ..where((q) => q.tripId.equals('trip-1')))
          .getSingle();

      expect(row.payload, isNotNull);
      expect(row.payload, payload);
      expect(row.action, kSyncActionDelete);
      expect(row.status, kSyncStatusPending);
    });

    test('watchPending streams pending rows; markSynced removes them',
        () async {
      await db.syncQueueDao.enqueueCreate('trip-a');
      await db.syncQueueDao.enqueueCreate('trip-b');

      final pendingFirst = await db.syncQueueDao.watchPending().first;
      expect(pendingFirst, hasLength(2));

      // Mark the first row synced; the pending stream should drop it.
      await db.syncQueueDao.markSynced(pendingFirst.first.id);

      final pendingAfter = await db.syncQueueDao.watchPending().first;
      expect(pendingAfter, hasLength(1));
      expect(pendingAfter.single.id, isNot(pendingFirst.first.id));
    });
  });
}
