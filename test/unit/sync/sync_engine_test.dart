import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/sync_queue_dao.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/sync_engine.dart';
import 'package:traevy/sync/sync_status.dart';

/// Recording fake of the [ApiClient] surface used by [SyncEngine]. Records
/// every call and can be configured to throw a chosen [SyncException] (or to
/// gate a call on an external [Completer] for the in-flight-guard test). NO
/// real network, NO platform channels.
class FakeApiClient implements ApiClient {
  FakeApiClient();

  /// Each entry is the list of trip ids passed to one [syncTrips] call.
  final List<List<String>> syncCalls = <List<String>>[];

  /// Each entry is a trip id passed to one [deleteTrip] call.
  final List<String> deleteCalls = <String>[];

  /// When set, [syncTrips] throws this instead of succeeding.
  SyncException? syncThrow;

  /// When set, [deleteTrip] throws this instead of succeeding.
  SyncException? deleteThrow;

  /// When non-null, [syncTrips] awaits this completer before returning — used
  /// to overlap two `processPending()` futures for the in-flight-guard test.
  Completer<void>? syncGate;

  @override
  Future<void> syncTrips(List<TripRow> trips) async {
    syncCalls.add(trips.map((t) => t.id).toList());
    if (syncGate != null) await syncGate!.future;
    if (syncThrow != null) throw syncThrow!;
  }

  @override
  Future<void> deleteTrip(String tripId) async {
    deleteCalls.add(tripId);
    if (deleteThrow != null) throw deleteThrow!;
  }

  @override
  Future<List<TripsCompanion>> restoreTrips() async => <TripsCompanion>[];
}

/// Builds a live [TripsCompanion] for [id] so `findById` returns a real row.
TripsCompanion _trip(String id) => TripsCompanion.insert(
  id: id,
  startTime: DateTime.utc(2026, 1, 1, 8),
  endTime: DateTime.utc(2026, 1, 1, 9),
  durationSeconds: 3600,
  distanceMeters: 12000,
  direction: kDirectionToOffice,
  timeMovingSeconds: 3000,
  timeStuckSeconds: 600,
);

void main() {
  group('SyncEngine', () {
    late AppDatabase db;
    late SyncQueueDao queueDao;
    late TripsDao tripsDao;
    late FakeApiClient api;
    late SyncStatusNotifier status;
    late List<SyncStatus> emitted;
    late DateTime clock;

    /// Build an engine with injected seams. Defaults: signed in, online,
    /// frozen clock. Tests override per-case.
    SyncEngine buildEngine({
      bool signedIn = true,
      bool online = true,
    }) {
      return SyncEngine(
        apiClient: api,
        syncQueueDao: queueDao,
        tripsDao: tripsDao,
        status: status,
        isSignedIn: () => signedIn,
        isOnline: () async => online,
        now: () => clock,
      );
    }

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      queueDao = db.syncQueueDao;
      tripsDao = db.tripsDao;
      api = FakeApiClient();
      clock = DateTime.utc(2026, 6, 1, 12);
      emitted = <SyncStatus>[];
      // A tiny SyncStatusNotifier stand-in that records every transition
      // without needing a ProviderContainer.
      status = _RecordingStatus(emitted);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> pendingRetry(String tripId) async {
      final rows = await (db.select(
        db.syncQueue,
      )..where((q) => q.tripId.equals(tripId))).get();
      return rows.first.retryCount;
    }

    Future<String> rowStatus(int id) async {
      final row = await (db.select(
        db.syncQueue,
      )..where((q) => q.id.equals(id))).getSingle();
      return row.status;
    }

    // ---- HIGH-1: queue collapse -------------------------------------------

    test('create+update same trip collapses to ONE syncTrips entry; both rows '
        'end synced', () async {
      await tripsDao.insertTrip(_trip('t1'));
      final createId = await queueDao.enqueueCreate('t1');
      final updateId = await queueDao.enqueueUpdate('t1');

      await buildEngine().processPending();

      expect(api.syncCalls, hasLength(1));
      expect(api.syncCalls.single, ['t1']);
      expect(api.deleteCalls, isEmpty);
      expect(await rowStatus(createId), kSyncStatusSynced);
      expect(await rowStatus(updateId), kSyncStatusSynced);
    });

    test('create-then-delete same trip sends NO create and one deleteTrip; '
        'create row synced without sending', () async {
      // No live trip row needed: the delete supersedes the create.
      final createId = await queueDao.enqueueCreate('t1');
      final deleteId = await queueDao.enqueueDelete(
        tripId: 't1',
        payload: '{"id":"t1"}',
      );

      await buildEngine().processPending();

      expect(api.syncCalls, isEmpty);
      expect(api.deleteCalls, ['t1']);
      expect(await rowStatus(createId), kSyncStatusSynced);
      expect(await rowStatus(deleteId), kSyncStatusSynced);
    });

    test('delete-only sends the delete and marks the row synced', () async {
      final deleteId = await queueDao.enqueueDelete(
        tripId: 't1',
        payload: '{"id":"t1"}',
      );

      await buildEngine().processPending();

      expect(api.deleteCalls, ['t1']);
      expect(api.syncCalls, isEmpty);
      expect(await rowStatus(deleteId), kSyncStatusSynced);
    });

    test(
      'distinct trips are each represented once (collapse is per-tripId)',
      () async {
        await tripsDao.insertTrip(_trip('a'));
        await tripsDao.insertTrip(_trip('b'));
        await queueDao.enqueueCreate('a');
        await queueDao.enqueueCreate('b');

        await buildEngine().processPending();

        expect(api.syncCalls, hasLength(1));
        expect(api.syncCalls.single.toSet(), {'a', 'b'});
      },
    );

    // ---- Batching ----------------------------------------------------------

    test(
      '2 creates + 1 update across 3 trips batch into one syncTrips call',
      () async {
        await tripsDao.insertTrip(_trip('a'));
        await tripsDao.insertTrip(_trip('b'));
        await tripsDao.insertTrip(_trip('c'));
        await queueDao.enqueueCreate('a');
        await queueDao.enqueueCreate('b');
        await queueDao.enqueueUpdate('c');

        await buildEngine().processPending();

        expect(api.syncCalls, hasLength(1));
        expect(api.syncCalls.single.toSet(), {'a', 'b', 'c'});
      },
    );

    test('zero syncTrips calls when only deletes are pending', () async {
      await queueDao.enqueueDelete(tripId: 'x', payload: '{}');
      await queueDao.enqueueDelete(tripId: 'y', payload: '{}');

      await buildEngine().processPending();

      expect(api.syncCalls, isEmpty);
      expect(api.deleteCalls.toSet(), {'x', 'y'});
    });

    // ---- Missing-trip skip -------------------------------------------------

    test('missing trip (findById null) -> row markSynced and excluded from '
        'payload', () async {
      // Enqueue create for a trip that was never inserted.
      final createId = await queueDao.enqueueCreate('ghost');

      await buildEngine().processPending();

      expect(api.syncCalls, isEmpty);
      expect(await rowStatus(createId), kSyncStatusSynced);
    });

    // ---- Success -----------------------------------------------------------

    test(
      'success -> markSynced + syncedAt set; status ends SyncSynced',
      () async {
        await tripsDao.insertTrip(_trip('t1'));
        final id = await queueDao.enqueueCreate('t1');

        await buildEngine().processPending();

        final row = await (db.select(
          db.syncQueue,
        )..where((q) => q.id.equals(id))).getSingle();
        expect(row.status, kSyncStatusSynced);
        expect(row.syncedAt, isNotNull);
        expect(emitted.last, isA<SyncSynced>());
      },
    );

    // ---- HIGH-2: retryable branching --------------------------------------

    test(
      'retryable failure (503) -> incrementRetry, row stays pending',
      () async {
        await tripsDao.insertTrip(_trip('t1'));
        await queueDao.enqueueCreate('t1');
        api.syncThrow = const SyncException.http(503);

        await buildEngine().processPending();

        expect(await pendingRetry('t1'), 1);
        final rows = await (db.select(
          db.syncQueue,
        )..where((q) => q.tripId.equals('t1'))).get();
        expect(rows.first.status, kSyncStatusPending);
      },
    );

    test(
      'retryable failure at retryCount 2 -> retryCount 3 + markFailed',
      () async {
        await tripsDao.insertTrip(_trip('t1'));
        final id = await queueDao.enqueueCreate('t1');
        // Drive retryCount to 2 directly.
        await queueDao.incrementRetry(id);
        await queueDao.incrementRetry(id);
        api.syncThrow = const SyncException.http(503);

        await buildEngine().processPending();

        expect(await pendingRetry('t1'), kSyncQueueMaxRetries);
        expect(await rowStatus(id), kSyncStatusFailed);
        expect(emitted.last, isA<SyncFailed>());
      },
    );

    test('non-retryable 400 -> markFailed IMMEDIATELY, retryCount untouched, '
        'no backoff', () async {
      await tripsDao.insertTrip(_trip('t1'));
      final id = await queueDao.enqueueCreate('t1');
      api.syncThrow = const SyncException.http(400);

      final engine = buildEngine();
      await engine.processPending();

      expect(await rowStatus(id), kSyncStatusFailed);
      expect(await pendingRetry('t1'), 0);
      // No backoff window opened for a non-retryable failure.
      expect(engine.backoffActive(), isFalse);
      expect(emitted.last, isA<SyncFailed>());
    });

    test(
      'notSignedIn thrown mid-drain is a no-op skip (no retry, no fail)',
      () async {
        await tripsDao.insertTrip(_trip('t1'));
        final id = await queueDao.enqueueCreate('t1');
        api.syncThrow = const SyncException.notSignedIn();

        await buildEngine().processPending();

        expect(await rowStatus(id), kSyncStatusPending);
        expect(await pendingRetry('t1'), 0);
      },
    );

    // ---- In-flight guard ---------------------------------------------------

    test('concurrent processPending() runs the queue exactly once', () async {
      await tripsDao.insertTrip(_trip('t1'));
      await queueDao.enqueueCreate('t1');
      api.syncGate = Completer<void>();

      final engine = buildEngine();
      final first = engine.processPending();
      final second = engine.processPending();
      api.syncGate!.complete();
      await Future.wait<void>([first, second]);

      expect(api.syncCalls, hasLength(1));
    });

    // ---- Backoff math ------------------------------------------------------

    test('backoffDelay = base x 2^n capped at kSyncRetryMaxDelay', () {
      final engine = buildEngine();
      expect(engine.backoffDelay(0), kSyncRetryBaseDelay);
      expect(engine.backoffDelay(1), kSyncRetryBaseDelay * 2);
      expect(engine.backoffDelay(2), kSyncRetryBaseDelay * 4);
      expect(engine.backoffDelay(100), kSyncRetryMaxDelay);
    });

    // ---- MEDIUM-2: backoff-window trigger coalescing ----------------------

    test(
      'trigger during active backoff window makes zero new apiClient calls',
      () async {
        await tripsDao.insertTrip(_trip('t1'));
        await queueDao.enqueueCreate('t1');
        api.syncThrow = const SyncException.http(503);

        final engine = buildEngine();
        await engine.processPending(); // opens a backoff window
        final callsAfterFirst = api.syncCalls.length;
        expect(engine.backoffActive(), isTrue);

        // A trigger (connectivity/resume/post-save) fires before the window
        // elapses — clock unchanged so now() is still before _backoffUntil.
        await engine.processPending();

        expect(api.syncCalls.length, callsAfterFirst);
      },
    );

    test('retryFailed clears the backoff window and is not blocked', () async {
      await tripsDao.insertTrip(_trip('t1'));
      final id = await queueDao.enqueueCreate('t1');
      api.syncThrow = const SyncException.http(503);

      final engine = buildEngine();
      await engine.processPending(); // opens window, increments retry
      expect(engine.backoffActive(), isTrue);

      // Now let the next attempt succeed.
      api.syncThrow = null;
      // Mark the row failed so resetFailed has something to re-enqueue.
      await queueDao.markFailed(id);

      await engine.retryFailed();

      expect(engine.backoffActive(), isFalse);
      expect(await rowStatus(id), kSyncStatusSynced);
    });

    // ---- Status transitions ------------------------------------------------

    test('idle -> syncing -> synced on success', () async {
      await tripsDao.insertTrip(_trip('t1'));
      await queueDao.enqueueCreate('t1');

      await buildEngine().processPending();

      expect(emitted.any((s) => s is SyncSyncing), isTrue);
      expect(emitted.last, isA<SyncSynced>());
    });

    // ---- Offline / guest no-ops -------------------------------------------

    test(
      'offline -> zero API calls, status SyncOffline, retry untouched',
      () async {
        await tripsDao.insertTrip(_trip('t1'));
        await queueDao.enqueueCreate('t1');

        await buildEngine(online: false).processPending();

        expect(api.syncCalls, isEmpty);
        expect(api.deleteCalls, isEmpty);
        expect(emitted.last, isA<SyncOffline>());
        expect(await pendingRetry('t1'), 0);
      },
    );

    test('guest -> zero API calls and zero DB mutations', () async {
      await tripsDao.insertTrip(_trip('t1'));
      final id = await queueDao.enqueueCreate('t1');

      await buildEngine(signedIn: false).processPending();

      expect(api.syncCalls, isEmpty);
      expect(api.deleteCalls, isEmpty);
      expect(await rowStatus(id), kSyncStatusPending);
      expect(emitted, isEmpty);
    });

    // ---- Delete-404 idempotent (amendment) --------------------------------

    test(
      'deleteTrip returning normally (404 mapped to success) -> synced',
      () async {
        // FakeApiClient.deleteTrip does not throw -> mirrors deleteTrip's
        // 404->success mapping from Plan 01.
        final id = await queueDao.enqueueDelete(tripId: 't1', payload: '{}');

        await buildEngine().processPending();

        expect(await rowStatus(id), kSyncStatusSynced);
      },
    );

    // ---- retryFailed chain (H2) -------------------------------------------

    test(
      'retryFailed re-enqueues a failed row and drains it to synced',
      () async {
        await tripsDao.insertTrip(_trip('t1'));
        final id = await queueDao.enqueueCreate('t1');
        await queueDao.markFailed(id);

        await buildEngine().retryFailed();

        expect(api.syncCalls, hasLength(1));
        expect(api.syncCalls.single, ['t1']);
        expect(await rowStatus(id), kSyncStatusSynced);
      },
    );

    // ---- Never throws ------------------------------------------------------

    test('processPending never rethrows a SyncException', () async {
      await tripsDao.insertTrip(_trip('t1'));
      await queueDao.enqueueCreate('t1');
      api.syncThrow = const SyncException.http(503);

      // Must complete without throwing.
      await buildEngine().processPending();
    });

    // ---- Empty queue -------------------------------------------------------

    test('empty queue -> SyncSynced, no API calls', () async {
      await buildEngine().processPending();

      expect(api.syncCalls, isEmpty);
      expect(api.deleteCalls, isEmpty);
      expect(emitted.last, isA<SyncSynced>());
    });
  });

  // ---- MR-03: post-save watchPending rising-edge guard ---------------------
  //
  // The post-save trigger (wired in start()) must nudge ONLY when the pending
  // count rises (a genuine new enqueue). A successful drain's own markSynced
  // writes shrink the pending set; that trailing emission must NOT re-fire a
  // redundant empty processPending() (extra SyncSynced churn / wasted drain).
  group('SyncEngine.start() post-save rising-edge guard (MR-03)', () {
    const channel = 'dev.fluttercommunity.plus/connectivity';
    late AppDatabase db;
    late SyncQueueDao queueDao;
    late TripsDao tripsDao;
    late FakeApiClient api;
    late List<SyncStatus> emitted;
    late SyncStatusNotifier status;
    late SyncEngine engine;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      // Stub the connectivity method channel so start()'s checkConnectivity()
      // resolves (wifi) without a real platform.
      TestDefaultBinaryMessenger messenger() =>
          TestWidgetsFlutterBinding.instance.defaultBinaryMessenger;
      messenger().setMockMethodCallHandler(
        const MethodChannel(channel),
        (call) async => <String>['wifi'],
      );

      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      queueDao = db.syncQueueDao;
      tripsDao = db.tripsDao;
      api = FakeApiClient();
      emitted = <SyncStatus>[];
      status = _RecordingStatus(emitted);
      engine = SyncEngine(
        apiClient: api,
        syncQueueDao: queueDao,
        tripsDao: tripsDao,
        status: status,
        isSignedIn: () => true,
        isOnline: () async => true,
        now: () => DateTime.utc(2026, 6, 1, 12),
      );
    });

    tearDown(() async {
      engine.dispose();
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(channel), null);
      await db.close();
    });

    test(
      'a new enqueue drains once; a markSynced shrink does NOT re-fire an '
      'empty drain',
      () async {
        await tripsDao.insertTrip(_trip('t1'));
        await engine.start();

        // Genuine new enqueue → pending count rises 0→1 → one drain.
        await queueDao.enqueueCreate('t1');

        // Let the reactive watchPending() stream deliver both the rising-edge
        // emission AND the post-drain shrink emission, then settle.
        await _pumpEventQueue();

        // Exactly one network drain happened.
        expect(api.syncCalls, hasLength(1));
        expect(api.syncCalls.single, ['t1']);

        // And exactly one SyncSynced was emitted — the shrink emission was a
        // no-op (without the guard it would emit a second redundant one).
        expect(
          emitted.whereType<SyncSynced>(),
          hasLength(1),
          reason: 'markSynced shrink must not re-fire an empty drain',
        );
      },
    );
  });
}

/// Drain the microtask + timer queue so reactive stream emissions and the
/// fire-and-forget processPending() futures they schedule all settle.
Future<void> _pumpEventQueue() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Minimal [SyncStatusNotifier] that records transitions without a
/// ProviderContainer. Overrides only [set]; the engine never reads `state`.
class _RecordingStatus extends SyncStatusNotifier {
  _RecordingStatus(this._log);

  final List<SyncStatus> _log;

  @override
  void set(SyncStatus status) => _log.add(status);
}
