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
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/restore_conflict.dart';
import 'package:traevy/sync/restore_controller.dart';
import 'package:traevy/sync/trip_serializer.dart';

/// Scripted [ApiClient] for restore tests. `restoreTrips()` returns a fixed
/// list of [ParsedTrip]s (built from sample JSON via the real
/// `TripSerializer.fromJson`), or throws when [throwOnRestore] is set. The
/// default constructor wraps bare companions as breaks-less ParsedTrips;
/// [_FakeApiClient.parsed] takes ParsedTrips directly (Phase 26 — trips
/// carrying breaks). No network, no token seam, no Firebase. All other
/// ApiClient members are unreachable in these tests and surface via
/// noSuchMethod if touched.
class _FakeApiClient implements ApiClient {
  _FakeApiClient(List<TripsCompanion> companions, {this.throwOnRestore = false})
    : _parsedTrips = companions
          .map((c) => (trip: c, breaks: const <TripBreaksCompanion>[]))
          .toList();

  _FakeApiClient.parsed(this._parsedTrips) : throwOnRestore = false;

  final List<ParsedTrip> _parsedTrips;
  final bool throwOnRestore;
  int restoreCallCount = 0;

  @override
  Future<List<ParsedTrip>> restoreTrips() async {
    restoreCallCount++;
    if (throwOnRestore) throw const SyncException.transport();
    return _parsedTrips;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Build a restored-trip JSON map (camelCase, ISO-8601 UTC) for [id], matching
/// the Phase 10/26 restore envelope shape that `TripSerializer.fromJson`
/// parses. The Phase 26 metadata fields default to their server-omission
/// defaults; [breaks] entries are `{startTime, endTime}` ISO-UTC maps.
Map<String, dynamic> _tripJson(
  String id, {
  String direction = 'to_office',
  int durationSeconds = 1800,
  String startTime = '2026-05-01T08:00:00.000Z',
  String endTime = '2026-05-01T08:30:00.000Z',
  int totalPausedSeconds = 0,
  bool isEdited = false,
  String directionSource = kDirectionSourceTime,
  List<Map<String, String>> breaks = const [],
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
  'totalPausedSeconds': totalPausedSeconds,
  'isEdited': isEdited,
  'directionSource': directionSource,
  'breaks': breaks,
};

TripsCompanion _companion(
  String id, {
  String direction = 'to_office',
  int durationSeconds = 1800,
  String startTime = '2026-05-01T08:00:00.000Z',
  String endTime = '2026-05-01T08:30:00.000Z',
}) => TripSerializer.fromJson(
  _tripJson(
    id,
    direction: direction,
    durationSeconds: durationSeconds,
    startTime: startTime,
    endTime: endTime,
  ),
).trip;

/// Build a full [ParsedTrip] (trip + break companions) via the real
/// serializer, with Phase 26 metadata and an embedded [breaks] list.
ParsedTrip _parsedTrip(
  String id, {
  String direction = 'to_office',
  int durationSeconds = 1800,
  String startTime = '2026-05-01T08:00:00.000Z',
  String endTime = '2026-05-01T08:30:00.000Z',
  int totalPausedSeconds = 0,
  bool isEdited = false,
  String directionSource = kDirectionSourceTime,
  List<Map<String, String>> breaks = const [],
}) => TripSerializer.fromJson(
  _tripJson(
    id,
    direction: direction,
    durationSeconds: durationSeconds,
    startTime: startTime,
    endTime: endTime,
    totalPausedSeconds: totalPausedSeconds,
    isEdited: isEdited,
    directionSource: directionSource,
    breaks: breaks,
  ),
);

/// Two in-window break maps for a trip spanning 08:00–08:30 UTC.
const List<Map<String, String>> _twoBreaks = [
  {
    'startTime': '2026-05-01T08:05:00.000Z',
    'endTime': '2026-05-01T08:10:00.000Z',
  },
  {
    'startTime': '2026-05-01T08:15:00.000Z',
    'endTime': '2026-05-01T08:20:00.000Z',
  },
];

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
          appDatabaseProvider.overrideWithValue(db),
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          tripBreaksDaoProvider.overrideWithValue(db.tripBreaksDao),
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
          _companion(
            't2',
            startTime: '2026-05-01T09:00:00.000Z',
            endTime: '2026-05-01T09:30:00.000Z',
          ),
          _companion(
            't3',
            startTime: '2026-05-01T10:00:00.000Z',
            endTime: '2026-05-01T10:30:00.000Z',
          ),
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
        _companion(
          'a2',
          startTime: '2026-05-01T09:00:00.000Z',
          endTime: '2026-05-01T09:30:00.000Z',
        ),
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
          _companion(
            'x2',
            startTime: '2026-05-01T09:00:00.000Z',
            endTime: '2026-05-01T09:30:00.000Z',
          ),
        ]);

        final api = _FakeApiClient(<TripsCompanion>[
          _companion('x1'),
          _companion(
            'x2',
            startTime: '2026-05-01T09:00:00.000Z',
            endTime: '2026-05-01T09:30:00.000Z',
          ),
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
          _companion(
            's2',
            startTime: '2026-05-01T09:00:00.000Z',
            endTime: '2026-05-01T09:30:00.000Z',
          ),
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

  // -------------------------------------------------------------------------
  // Phase 26 Plan 05 — D-07 / atomic insert / D-10-D-11 / SC3
  // -------------------------------------------------------------------------

  ProviderContainer phase26Container(_FakeApiClient api) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tripsDaoProvider.overrideWithValue(db.tripsDao),
        tripBreaksDaoProvider.overrideWithValue(db.tripBreaksDao),
        syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('D-07 metadata excluded from conflict detection', () {
    test(
      'same-UUID trip differing ONLY in directionSource → RestoreSuccess, '
      'no conflict',
      () async {
        await db.tripsDao.insertOrIgnoreTrips(<TripsCompanion>[
          _companion('m1'),
        ]);

        final api = _FakeApiClient.parsed([
          _parsedTrip('m1', directionSource: kDirectionSourceGeofence),
        ]);
        final container = phase26Container(api);

        await container.read(restoreControllerProvider.notifier).restore();

        final state = container.read(restoreControllerProvider);
        expect(state, isA<RestoreSuccess>());
        expect((state as RestoreSuccess).count, 0);
      },
    );

    test(
      'same-UUID trip differing ONLY in totalPausedSeconds + isEdited → '
      'RestoreSuccess, no conflict',
      () async {
        await db.tripsDao.insertOrIgnoreTrips(<TripsCompanion>[
          _companion('m2'),
        ]);

        final api = _FakeApiClient.parsed([
          _parsedTrip('m2', totalPausedSeconds: 300, isEdited: true),
        ]);
        final container = phase26Container(api);

        await container.read(restoreControllerProvider.notifier).restore();

        expect(
          container.read(restoreControllerProvider),
          isA<RestoreSuccess>(),
        );
      },
    );

    test(
      'same-UUID trip differing in BOTH startTime (real) AND '
      'totalPausedSeconds (metadata) → exactly ONE conflict, carrying both '
      "sides' breaks",
      () async {
        await db.tripsDao.insertOrIgnoreTrips(<TripsCompanion>[
          _companion('m3'),
        ]);

        final api = _FakeApiClient.parsed([
          _parsedTrip(
            'm3',
            startTime: '2026-05-01T08:01:00.000Z',
            totalPausedSeconds: 300,
            breaks: const [
              {
                'startTime': '2026-05-01T08:05:00.000Z',
                'endTime': '2026-05-01T08:10:00.000Z',
              },
            ],
          ),
        ]);
        final container = phase26Container(api);

        await container.read(restoreControllerProvider.notifier).restore();

        final state = container.read(restoreControllerProvider);
        expect(state, isA<RestoreConflictState>());
        final conflicts = (state as RestoreConflictState).conflicts;
        expect(conflicts.length, 1);
        final conflict = conflicts.single;
        expect(conflict, isA<SameUuidConflict>());
        expect(conflict.cloudBreaks.length, 1);
        expect(conflict.localBreaks, isEmpty);
      },
    );
  });

  group('new trip with breaks — atomic insert', () {
    test(
      'cloud trip with 2 breaks and no local match inserts the trip row AND '
      'both break rows; counts toward RestoreSuccess',
      () async {
        final api = _FakeApiClient.parsed([
          _parsedTrip('b1', totalPausedSeconds: 600, breaks: _twoBreaks),
        ]);
        final container = phase26Container(api);

        await container.read(restoreControllerProvider.notifier).restore();

        final state = container.read(restoreControllerProvider);
        expect(state, isA<RestoreSuccess>());
        expect((state as RestoreSuccess).count, 1);

        final trip = await db.tripsDao.findById('b1');
        expect(trip, isNotNull);
        expect(trip!.totalPausedSeconds, 600);
        expect((await db.tripBreaksDao.breaksForTrip('b1')).length, 2);

        // Restore is a pure download — never enqueues.
        expect(await db.syncQueueDao.watchPending().first, isEmpty);
      },
    );

    test(
      'mixed batch: breakless bulk path + with-breaks transactional path '
      'both count toward RestoreSuccess',
      () async {
        final api = _FakeApiClient.parsed([
          _parsedTrip('b2'),
          _parsedTrip(
            'b3',
            startTime: '2026-05-01T10:00:00.000Z',
            endTime: '2026-05-01T10:30:00.000Z',
            breaks: const [
              {
                'startTime': '2026-05-01T10:05:00.000Z',
                'endTime': '2026-05-01T10:10:00.000Z',
              },
            ],
          ),
        ]);
        final container = phase26Container(api);

        await container.read(restoreControllerProvider.notifier).restore();

        final state = container.read(restoreControllerProvider);
        expect(state, isA<RestoreSuccess>());
        expect((state as RestoreSuccess).count, 2);
        expect(await db.tripBreaksDao.breaksForTrip('b2'), isEmpty);
        expect((await db.tripBreaksDao.breaksForTrip('b3')).length, 1);
      },
    );
  });

  group('D-10/D-11 enrichment', () {
    test(
      'existing default-metadata local trip is enriched with cloud breaks + '
      'all three metadata fields, without enqueueing',
      () async {
        await db.tripsDao.insertOrIgnoreTrips(<TripsCompanion>[
          _companion('e1'),
        ]);

        final api = _FakeApiClient.parsed([
          _parsedTrip(
            'e1',
            totalPausedSeconds: 300,
            isEdited: true,
            directionSource: kDirectionSourceGeofence,
            breaks: _twoBreaks,
          ),
        ]);
        final container = phase26Container(api);

        await container.read(restoreControllerProvider.notifier).restore();

        final state = container.read(restoreControllerProvider);
        expect(state, isA<RestoreSuccess>());
        expect((state as RestoreSuccess).count, 0);

        final trip = await db.tripsDao.findById('e1');
        expect(trip!.totalPausedSeconds, 300);
        expect(trip.isEdited, isTrue);
        expect(trip.directionSource, kDirectionSourceGeofence);
        expect((await db.tripBreaksDao.breaksForTrip('e1')).length, 2);

        expect(await db.syncQueueDao.watchPending().first, isEmpty);
      },
    );

    test(
      'real local values are NEVER overwritten — per-field guard (D-11)',
      () async {
        // Local trip with REAL metadata: 1 break, paused 120, edited, manual.
        await db.tripsDao.insertTrip(
          _parsedTrip(
            'e2',
            totalPausedSeconds: 120,
            isEdited: true,
            directionSource: kDirectionSourceManual,
          ).trip,
        );
        await db.tripBreaksDao.insertBreaks([
          TripBreaksCompanion.insert(
            id: 'local-break-1',
            tripId: 'e2',
            startTime: DateTime.parse('2026-05-01T08:05:00.000Z'),
            endTime: Value(DateTime.parse('2026-05-01T08:07:00.000Z')),
          ),
        ]);

        final api = _FakeApiClient.parsed([
          _parsedTrip(
            'e2',
            totalPausedSeconds: 999,
            directionSource: kDirectionSourceGeofence,
            breaks: _twoBreaks,
          ),
        ]);
        final container = phase26Container(api);

        await container.read(restoreControllerProvider.notifier).restore();

        // Metadata-only difference → no conflict (D-07), and no field of
        // the local trip was replaced (D-11).
        expect(
          container.read(restoreControllerProvider),
          isA<RestoreSuccess>(),
        );
        final trip = await db.tripsDao.findById('e2');
        expect(trip!.totalPausedSeconds, 120);
        expect(trip.isEdited, isTrue);
        expect(trip.directionSource, kDirectionSourceManual);
        final breaks = await db.tripBreaksDao.breaksForTrip('e2');
        expect(breaks.length, 1);
        expect(breaks.single.id, 'local-break-1');
      },
    );
  });

  group('SC3 restore-then-edit preserves breaks', () {
    test(
      "a restored trip's breaks and totalPausedSeconds survive a "
      'direction-only edit (breaks: null)',
      () async {
        final api = _FakeApiClient.parsed([
          _parsedTrip('sc3', totalPausedSeconds: 300, breaks: _twoBreaks),
        ]);
        final container = phase26Container(api);

        await container.read(restoreControllerProvider.notifier).restore();
        expect(
          (container.read(restoreControllerProvider) as RestoreSuccess).count,
          1,
        );

        final restored = await db.tripsDao.findById('sc3');
        expect(restored!.totalPausedSeconds, 300);

        // Direction-only edit: breaks null leaves existing breaks untouched
        // per the editTrip documented contract.
        await container
            .read(tripManagementProvider.notifier)
            .editTrip(
              tripId: 'sc3',
              direction: kDirectionToHome,
              startTimeUtc: restored.startTime,
              endTimeUtc: restored.endTime,
            );
        expect(
          container.read(tripManagementProvider),
          isA<TripManagementSaved>(),
        );

        final edited = await db.tripsDao.findById('sc3');
        expect(edited!.direction, kDirectionToHome);
        expect(edited.totalPausedSeconds, 300);
        expect((await db.tripBreaksDao.breaksForTrip('sc3')).length, 2);
      },
    );
  });
}
