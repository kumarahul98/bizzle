import 'package:drift/drift.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/tables/sync_queue_table.dart';

part 'sync_queue_dao.g.dart';

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
  /// Bind the DAO to its parent `AppDatabase`.
  SyncQueueDao(super.attachedDatabase);

  /// Enqueue a `create` action for [tripId]. Payload is null: the sync
  /// engine re-reads the fresh trip row at sync time so user edits
  /// between enqueue and flush produce the latest payload.
  Future<int> enqueueCreate(String tripId) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        tripId: tripId,
        action: kSyncActionCreate,
      ),
    );
  }

  /// Enqueue an `update` action for [tripId]. Payload is null for the
  /// same reason as `enqueueCreate` — fresh read at sync time.
  Future<int> enqueueUpdate(String tripId) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        tripId: tripId,
        action: kSyncActionUpdate,
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
        action: kSyncActionDelete,
        payload: Value<String>(payload),
      ),
    );
  }

  /// Reactive stream of queue rows still in the `pending` state. The
  /// sync engine subscribes to this in Phase 9 and drains the queue
  /// whenever connectivity is available.
  Stream<List<SyncQueueRow>> watchPending() {
    return (select(syncQueue)
          ..where((q) => q.status.equals(kSyncStatusPending)))
        .watch();
  }

  /// One-shot read of all `pending` queue rows, oldest-first (by ascending
  /// `id`). D-05: the sync engine pulls the pending batch this way to drain
  /// the queue in enqueue order, rather than holding the `watchPending()`
  /// stream for a single flush.
  Future<List<SyncQueueRow>> getPending() {
    return (select(syncQueue)
          ..where((q) => q.status.equals(kSyncStatusPending))
          ..orderBy([(q) => OrderingTerm.asc(q.id)]))
        .get();
  }

  /// Promote a queue row to the terminal `failed` state (D-06). Called when a
  /// row exhausts [kSyncQueueMaxRetries] retries, OR immediately on a
  /// NON-retryable response (e.g. a 400 validation poison-pill, HIGH-2). A
  /// failed row is not auto-retried until the user taps "retry", which runs
  /// [resetFailed].
  Future<void> markFailed(int id) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      const SyncQueueCompanion(status: Value<String>(kSyncStatusFailed)),
    );
  }

  /// Bulk-reset every `failed` row back to `pending` with a fresh retry budget
  /// (D-06). This is the manual "tap to retry" action: Plan 02's
  /// `SyncEngine.retryFailed()` calls it and Plan 03's Settings failed-state
  /// row surfaces it. `pending`/`synced` rows are left untouched.
  Future<void> resetFailed() {
    return (update(syncQueue)..where((q) => q.status.equals(kSyncStatusFailed)))
        .write(
      const SyncQueueCompanion(
        status: Value<String>(kSyncStatusPending),
        retryCount: Value<int>(0),
      ),
    );
  }

  /// Mark a queue row as successfully synced and stamp the UTC time.
  Future<void> markSynced(int id) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value<String>(kSyncStatusSynced),
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
