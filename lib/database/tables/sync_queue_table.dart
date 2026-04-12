import 'package:drift/drift.dart';

/// Outbound sync queue for the client-authoritative (one-way) sync engine.
///
/// Every local mutation on `trips` enqueues a row here so the sync engine
/// can push the change to DynamoDB opportunistically (on connectivity
/// restore, app resume, or post-save). The client is the only writer —
/// no server-to-client reconciliation exists in v0.1.
///
/// D-13: `payload` is nullable text. Create/update actions leave it null
/// and the sync engine re-reads the fresh trip row at sync time (avoids
/// stale payload races if the user edits between enqueue and sync).
/// Delete actions are the ONLY action that carries a payload, because
/// after deletion the source row is gone and the server still needs the
/// identity snapshot to process the tombstone.
///
/// Status values use the `kSyncStatus*` constants from
/// `lib/config/constants.dart` (pending/synced/failed).
@DataClassName('SyncQueueRow')
class SyncQueue extends Table {
  /// Auto-increment primary key. Distinct from the trip UUID so the
  /// same trip can have multiple queued actions (e.g. create → update).
  IntColumn get id => integer().autoIncrement()();

  /// Foreign-key-ish reference to `trips.id`. Not a hard FK because the
  /// trip row may be deleted before the delete action is flushed.
  TextColumn get tripId => text()();

  /// `'create'`, `'update'`, or `'delete'`. Consumer code should use the
  /// `kSyncActionCreate/Update/Delete` constants from `constants.dart`
  /// once plan 01-02 lands.
  TextColumn get action => text()();

  /// D-13: nullable text. Populated ONLY for delete actions with a JSON
  /// snapshot `{id, user_id}` so the server can tombstone without the
  /// now-missing trip row. Null for create/update.
  TextColumn get payload => text().nullable()();

  /// Literal default `'pending'` until plan 01-02 exposes
  /// `kSyncStatusPending` in `lib/config/constants.dart`. A follow-up swap
  /// replaces this literal with the constant reference.
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();

  /// Monotonic retry counter; the sync engine gives up after 3 attempts
  /// and promotes the row to `'failed'`.
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Set when the row transitions to `'synced'`. Null while pending/failed.
  DateTimeColumn get syncedAt => dateTime().nullable()();
}
