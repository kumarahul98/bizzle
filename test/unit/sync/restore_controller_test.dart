// Unit tests for the restore-from-cloud flow (SYNC-03, Phase 11 Plan 03).
//
// Covers the new `TripsDao.insertOrIgnoreTrips` single-batch dedupe DAO method
// (Tests A / B / B2) and the `RestoreController` state machine (Tests C–F),
// including the contract that restore NEVER enqueues sync_queue rows.
//
// In-memory Drift + a fake ApiClient (no network, no Firebase platform
// channels) — mirrors the setUp/tearDown shape in
// test/unit/database/sync_queue_dao_test.dart.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/restore_controller.dart';
import 'package:traevy/sync/trip_serializer.dart';

/// Scripted [ApiClient] for restore tests. `restoreTrips()` returns a fixed
/// list of companions (built from sample JSON via the real
/// `TripSerializer.fromJson`), or throws when [throwOnRestore] is set. No
/// network, no token seam, no Firebase. All other ApiClient members are
/// unreachable in these tests and surface via noSuchMethod if touched.
class _FakeApiClient implements ApiClient {
  _FakeApiClient(this._companions, {this.throwOnRestore = false});

  final List<TripsCompanion> _companions;
  final bool throwOnRestore;
  int restoreCallCount = 0;

  @override
  Future<List<TripsCompanion>> restoreTrips() async {
    restoreCallCount++;
    if (throwOnRestore) throw const SyncException.transport();
    return _companions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Build a restored-trip JSON map (camelCase, ISO-8601 UTC) for [id], matching
/// the Phase 10 restore envelope shape that `TripSerializer.fromJson` parses.
Map<String, dynamic> _tripJson(
  String id, {
  String direction = 'to_office',
  int durationSeconds = 1800,
  String startTime = '2026-05-01T08:00:00.000Z',
  String endTime = '2026-05-01T08:30:00.000Z',
}) => <String, dynamic>{
  'id': id,
  'startTime': startTime,
  'endTime': endTime,
  'durationSeconds': durationSeconds,
  'distanceMeters': 12000.0,
  'routePolyline': null,
  'direction': direction,
  'timeMovingSeconds': 1200,
  'timeStuckSeconds': 600,
  'isManualEntry': false,
  'createdAt': '2026-05-01T08:30:00.000Z',
  'updatedAt': '2026-05-01T08:30:00.000Z',
};

TripsCompanion _companion(
  String id, {
  String direction = 'to_office',
  int durationSeconds = 1800,
  String startTime = '2026-05-01T08:00:00.000Z',
  String endTime = '2026-05-01T08:30:00.000Z',
}) => TripSerializer.fromJson(
  _tripJson(id, direction: direction, durationSeconds: durationSeconds, startTime: startTime, endTime: endTime),
);

void main() {
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

  // -------------------------------------------------------------------------
  // DAO: insertOrIgnoreTrips — single-batch dedupe (MEDIUM-3)
  // -------------------------------------------------------------------------

  group('TripsDao.insertOrIgnoreTrips', () {
    test(
      'Test A: all-new companions insert and return the full count',
      () async {
        final inserted = await db.tripsDao.insertOrIgnoreTrips(<TripsCompanion>[
          _companion('t1'),
          _companion('t2'),
          _companion('t3'),
        ]);

        expect(inserted, 3);
        expect(await db.tripsDao.findById('t1'), isNotNull);
        expect(await db.tripsDao.findById('t2'), isNotNull);
        expect(await db.tripsDao.findById('t3'), isNotNull);
      },
    );

    test(
      'Test B: existing UUIDs are skipped (not overwritten); only NEW rows '
      'counted',
      () async {
        // Seed an existing row with a distinctive direction/duration.
        await db.tripsDao.insertOrIgnoreTrips(<TripsCompanion>[
          _companion('t1', direction: 'to_home', durationSeconds: 999),
        ]);

        // Restore a batch that re-includes t1 (with DIFFERENT values) plus two
        // brand-new ids.
        final inserted = await db.tripsDao.insertOrIgnoreTrips(<TripsCompanion>[
          _companion('t1', durationSeconds: 1),
          _companion('t2'),
          _companion('t3'),
        ]);

        // Only t2 + t3 are new.
        expect(inserted, 2);

        // t1 was NOT overwritten — original values intact (dedupe-by-UUID).
        final t1 = await db.tripsDao.findById('t1');
        expect(t1, isNotNull);
        expect(t1!.direction, 'to_home');
        expect(t1.durationSeconds, 999);

        // Total rows == 3.
        final all = await db.select(db.trips).get();
        expect(all.length, 3);
      },
    );

    test('Test B2: empty list returns 0 and writes nothing', () async {
      final inserted = await db.tripsDao.insertOrIgnoreTrips(
        const <TripsCompanion>[],
      );
      expect(inserted, 0);
      final all = await db.select(db.trips).get();
      expect(all, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // RestoreController — state machine + no-sync-rows contract
  // -------------------------------------------------------------------------

  group('RestoreController.restore', () {
    ProviderContainer containerWith(_FakeApiClient api) {
      final container = ProviderContainer(
        overrides: [
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
          apiClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'Test C: 3 restored, 1 already present → 3 rows total, '
      'RestoreSuccess(2)',
      () async {
        await db.tripsDao.insertOrIgnoreTrips(<TripsCompanion>[
          _companion('t1'),
        ]);

        final api = _FakeApiClient(<TripsCompanion>[
          _companion('t1'),
          _companion('t2', startTime: '2026-05-01T09:00:00.000Z', endTime: '2026-05-01T09:30:00.000Z'),
          _companion('t3', startTime: '2026-05-01T10:00:00.000Z', endTime: '2026-05-01T10:30:00.000Z'),
        ]);
        final container = containerWith(api);

        await container.read(restoreControllerProvider.notifier).restore();

        final state = container.read(restoreControllerProvider);
        expect(state, isA<RestoreSuccess>());
        expect((state as RestoreSuccess).count, 2);

        final all = await db.select(db.trips).get();
        expect(all.length, 3);
      },
    );

    test('Test D: all-new on empty DB → RestoreSuccess(2)', () async {
      final api = _FakeApiClient(<TripsCompanion>[
        _companion('a1'),
        _companion('a2', startTime: '2026-05-01T09:00:00.000Z', endTime: '2026-05-01T09:30:00.000Z'),
      ]);
      final container = containerWith(api);

      await container.read(restoreControllerProvider.notifier).restore();

      final state = container.read(restoreControllerProvider);
      expect(state, isA<RestoreSuccess>());
      expect((state as RestoreSuccess).count, 2);
      expect((await db.select(db.trips).get()).length, 2);
    });

    test(
      'Test E: already up to date → RestoreSuccess(0), DB unchanged',
      () async {
        await db.tripsDao.insertOrIgnoreTrips(<TripsCompanion>[
          _companion('x1'),
          _companion('x2', startTime: '2026-05-01T09:00:00.000Z', endTime: '2026-05-01T09:30:00.000Z'),
        ]);

        final api = _FakeApiClient(<TripsCompanion>[
          _companion('x1'),
          _companion('x2', startTime: '2026-05-01T09:00:00.000Z', endTime: '2026-05-01T09:30:00.000Z'),
        ]);
        final container = containerWith(api);

        await container.read(restoreControllerProvider.notifier).restore();

        final state = container.read(restoreControllerProvider);
        expect(state, isA<RestoreSuccess>());
        expect((state as RestoreSuccess).count, 0);
        expect((await db.select(db.trips).get()).length, 2);
      },
    );

    test(
      'Test F: ApiClient throws → RestoreError, DB unchanged, no rethrow',
      () async {
        final api = _FakeApiClient(
          const <TripsCompanion>[],
          throwOnRestore: true,
        );
        final container = containerWith(api);

        // Must NOT throw out of restore() (errors caught internally).
        await container.read(restoreControllerProvider.notifier).restore();

        final state = container.read(restoreControllerProvider);
        expect(state, isA<RestoreError>());
        expect(await db.select(db.trips).get(), isEmpty);
      },
    );

    test(
      'restore enqueues ZERO sync_queue rows (D-08 — download only)',
      () async {
        final api = _FakeApiClient(<TripsCompanion>[
          _companion('s1'),
          _companion('s2', startTime: '2026-05-01T09:00:00.000Z', endTime: '2026-05-01T09:30:00.000Z'),
        ]);
        final container = containerWith(api);

        await container.read(restoreControllerProvider.notifier).restore();

        final pending = await db.syncQueueDao.watchPending().first;
        expect(pending, isEmpty);
      },
    );

    test('starts at RestoreIdle and transitions through restoring', () async {
      final api = _FakeApiClient(const <TripsCompanion>[]);
      final container = containerWith(api);

      expect(container.read(restoreControllerProvider), isA<RestoreIdle>());
      await container.read(restoreControllerProvider.notifier).restore();
      expect(container.read(restoreControllerProvider), isA<RestoreSuccess>());
    });
  });
}
