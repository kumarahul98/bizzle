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

    test('getPending returns pending rows oldest-first (id ASC)', () async {
      final firstId = await db.syncQueueDao.enqueueCreate('trip-a');
      final secondId = await db.syncQueueDao.enqueueCreate('trip-b');

      final pending = await db.syncQueueDao.getPending();

      expect(pending.map((r) => r.id).toList(), [firstId, secondId]);
      expect(pending.map((r) => r.status), everyElement(kSyncStatusPending));
    });

    test('getPending excludes synced and failed rows', () async {
      final pendingId = await db.syncQueueDao.enqueueCreate('trip-pending');
      final syncedId = await db.syncQueueDao.enqueueCreate('trip-synced');
      final failedId = await db.syncQueueDao.enqueueCreate('trip-failed');
      await db.syncQueueDao.markSynced(syncedId);
      await db.syncQueueDao.markFailed(failedId);

      final pending = await db.syncQueueDao.getPending();

      expect(pending.map((r) => r.id).toList(), [pendingId]);
    });

    test('markFailed sets status=failed', () async {
      final id = await db.syncQueueDao.enqueueCreate('trip-1');

      await db.syncQueueDao.markFailed(id);

      final row = await (db.select(db.syncQueue)
            ..where((q) => q.id.equals(id)))
          .getSingle();
      expect(row.status, kSyncStatusFailed);
    });

    test('resetFailed flips failed→pending and zeroes retryCount', () async {
      final id = await db.syncQueueDao.enqueueCreate('trip-1');
      await db.syncQueueDao.incrementRetry(id);
      await db.syncQueueDao.incrementRetry(id);
      await db.syncQueueDao.markFailed(id);

      await db.syncQueueDao.resetFailed();

      final row = await (db.select(db.syncQueue)
            ..where((q) => q.id.equals(id)))
          .getSingle();
      expect(row.status, kSyncStatusPending);
      expect(row.retryCount, 0);
    });

    test('countFailed returns the number of failed rows only (LR-02)',
        () async {
      final f1 = await db.syncQueueDao.enqueueCreate('trip-f1');
      final f2 = await db.syncQueueDao.enqueueCreate('trip-f2');
      final syncedId = await db.syncQueueDao.enqueueCreate('trip-synced');
      await db.syncQueueDao.enqueueCreate('trip-pending');
      await db.syncQueueDao.markFailed(f1);
      await db.syncQueueDao.markFailed(f2);
      await db.syncQueueDao.markSynced(syncedId);

      expect(await db.syncQueueDao.countFailed(), 2);
    });

    test('countFailed is zero when no rows are failed (LR-02)', () async {
      await db.syncQueueDao.enqueueCreate('trip-1');

      expect(await db.syncQueueDao.countFailed(), 0);
    });

    test('resetFailed leaves pending and synced rows untouched', () async {
      final pendingId = await db.syncQueueDao.enqueueCreate('trip-pending');
      final syncedId = await db.syncQueueDao.enqueueCreate('trip-synced');
      await db.syncQueueDao.markSynced(syncedId);

      await db.syncQueueDao.resetFailed();

      final pendingRow = await (db.select(db.syncQueue)
            ..where((q) => q.id.equals(pendingId)))
          .getSingle();
      final syncedRow = await (db.select(db.syncQueue)
            ..where((q) => q.id.equals(syncedId)))
          .getSingle();
      expect(pendingRow.status, kSyncStatusPending);
      expect(syncedRow.status, kSyncStatusSynced);
    });
  });
}
