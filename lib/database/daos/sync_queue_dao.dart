import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sync_queue_table.dart';

part 'sync_queue_dao.g.dart';

/// Sync action literals. These mirror the `kSyncAction*` constants that
/// plan 01-02 will expose in `lib/config/constants.dart`; once that
/// plan lands, this file will be swapped to import the constants and
/// delete these locals. The string values are the contract with the
/// backend Lambda, so they must not drift across either source.
const String _actionCreate = 'create';
const String _actionUpdate = 'update';
const String _actionDelete = 'delete';

/// Sync status literals. Same swap story as the action constants.
const String _statusPending = 'pending';
const String _statusSynced = 'synced';

/// Data-access object for the outbound sync queue.
///
/// Phase 1 surface:
///   * enqueue create/update/delete (delete is the only one that
///     carries a payload, per D-13)
///   * watch pending rows as a reactive stream
///   * mark synced / bump retry counter
///
/// The actual POST-to-API-Gateway logic lives in `lib/sync/sync_engine.dart`
/// which Phase 9 will introduce. This DAO is the persistence contract
/// only.
@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// Enqueue a `create` action for [tripId]. Payload is null: the sync
  /// engine re-reads the fresh trip row at sync time so user edits
  /// between enqueue and flush produce the latest payload.
  Future<int> enqueueCreate(String tripId) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        tripId: tripId,
        action: _actionCreate,
      ),
    );
  }

  /// Enqueue an `update` action for [tripId]. Payload is null for the
  /// same reason as `enqueueCreate` — fresh read at sync time.
  Future<int> enqueueUpdate(String tripId) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        tripId: tripId,
        action: _actionUpdate,
      ),
    );
  }

  /// Enqueue a `delete` action. D-13: delete is the ONLY action that
  /// stores the payload inline, because the trip row is gone after
  /// the local delete and the sync engine still needs an identity
  /// snapshot (`{id, user_id}` JSON) to tell the server what to
  /// tombstone.
  Future<int> enqueueDelete({
    required String tripId,
    required String payload,
  }) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        tripId: tripId,
        action: _actionDelete,
        payload: Value<String>(payload),
      ),
    );
  }

  /// Reactive stream of queue rows still in the `pending` state. The
  /// sync engine subscribes to this in Phase 9 and drains the queue
  /// whenever connectivity is available.
  Stream<List<SyncQueueRow>> watchPending() {
    return (select(syncQueue)
          ..where((q) => q.status.equals(_statusPending)))
        .watch();
  }

  /// Mark a queue row as successfully synced and stamp the UTC time.
  Future<void> markSynced(int id) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value<String>(_statusSynced),
        syncedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
  }

  /// Increment the retry counter by one. Combined with a `retryCount`
  /// check in the sync engine, this drives the "max 3 retries then
  /// promote to failed" flow documented in CLAUDE.md.
  Future<void> incrementRetry(int id) async {
    await customUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
      variables: [Variable<int>(id)],
      updates: {syncQueue},
      updateKind: UpdateKind.update,
    );
  }
}
