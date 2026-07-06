import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';

/// SC#4 / D-08 — the riskiest correctness point of Phase 20.
///
/// A guest saves trips while in `local_user` state; those trips enqueue
/// pending sync_queue rows that never flush until sign-in. After sign-in,
/// `AuthService.signIn()` runs (inside one transaction) the trips/prefs
/// backfill PLUS `SyncQueueDao.reconcilePendingUserId(uid)`. These tests pin
/// the exactly-once invariant of the reconcile in isolation: the call
/// `signIn()` makes is exercised directly against a real in-memory DB.
void main() {
  group('Sign-in sync backlog reconcile (SC#4, D-08)', () {
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

    const realUid = 'real-uid-123';

    Future<void> seedGuestTrip(String id) {
      return db
          .into(db.trips)
          .insert(
            TripsCompanion.insert(
              id: id,
              userId: const Value<String>(kDefaultUserId),
              startTime: DateTime.utc(2026, 1, 1, 8),
              endTime: DateTime.utc(2026, 1, 1, 9),
              durationSeconds: 3600,
              distanceMeters: 1000,
              direction: 'to_office',
              timeMovingSeconds: 3000,
              timeStuckSeconds: 600,
            ),
          );
    }

    test(
      'pending DELETE payload userId is rewritten local_user → real uid; '
      'CREATE row payload stays null',
      () async {
        // Guest backlog: a create (null payload) and a delete (local_user).
        await seedGuestTrip('trip-create');
        await db.syncQueueDao.enqueueCreate('trip-create');
        final deletePayload = jsonEncode(<String, String>{
          'id': 'trip-delete',
          'userId': kDefaultUserId,
        });
        await db.syncQueueDao.enqueueDelete(
          tripId: 'trip-delete',
          payload: deletePayload,
        );

        final changed = await db.syncQueueDao.reconcilePendingUserId(realUid);
        expect(changed, 1, reason: 'only the delete payload is rewritten');

        final rows = await db.syncQueueDao.getPending();
        final createRow = rows.firstWhere((r) => r.tripId == 'trip-create');
        final deleteRow = rows.firstWhere((r) => r.tripId == 'trip-delete');

        // Create row: payload untouched (null) — engine re-reads the trip.
        expect(createRow.payload, isNull);

        // Delete row: userId now carries the real uid.
        final map = jsonDecode(deleteRow.payload!) as Map<String, dynamic>;
        expect(map['userId'], realUid);
        expect(map['id'], 'trip-delete');
      },
    );

    test(
      'reconcile is idempotent — a second call rewrites 0 (exactly-once)',
      () async {
        final deletePayload = jsonEncode(<String, String>{
          'id': 'trip-delete',
          'userId': kDefaultUserId,
        });
        await db.syncQueueDao.enqueueDelete(
          tripId: 'trip-delete',
          payload: deletePayload,
        );

        final first = await db.syncQueueDao.reconcilePendingUserId(realUid);
        final second = await db.syncQueueDao.reconcilePendingUserId(realUid);

        expect(first, 1);
        expect(second, 0, reason: 'no duplicate rewrite — exactly-once');
      },
    );

    test(
      'a delete payload already at the real uid is left untouched',
      () async {
        final alreadyReal = jsonEncode(<String, String>{
          'id': 'trip-delete',
          'userId': realUid,
        });
        await db.syncQueueDao.enqueueDelete(
          tripId: 'trip-delete',
          payload: alreadyReal,
        );

        final changed = await db.syncQueueDao.reconcilePendingUserId(realUid);
        expect(changed, 0);
      },
    );

    test(
      'backfillUserId rewrites the guest trip so the engine serializes the '
      'real-uid-owned row (userId omitted on the wire)',
      () async {
        await seedGuestTrip('trip-create');
        await db.syncQueueDao.enqueueCreate('trip-create');

        final changed = await db.tripsDao.backfillUserId(realUid);
        expect(changed, 1);

        final trip = await db.tripsDao.findById('trip-create');
        expect(trip, isNotNull);
        expect(trip!.userId, realUid);
      },
    );
  });
}
