import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/sync_queue_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/state/finalized_trip.dart';

/// Fake [TrackingNotificationService] that records every `dismiss` /
/// `showRecording` / `initialize` call so tests can assert on them
/// without instantiating flutter_local_notifications.
class _RecordingNotifications implements TrackingNotificationService {
  int dismissCalls = 0;
  int showCalls = 0;

  @override
  Future<void> dismiss() async {
    dismissCalls += 1;
  }

  @override
  Future<void> showRecording({
    int elapsedSeconds = 0,
    double distanceMeters = 0,
    int timeStuckSeconds = 0,
    String direction = kDirectionToOffice,
  }) async {
    showCalls += 1;
  }

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [SyncQueueDao] subclass whose [enqueueCreate] throws. Used by the
/// rollback test to prove that the trips insert is rolled back when the
/// sync-queue insert fails inside the same transaction.
class _ThrowingSyncQueueDao extends SyncQueueDao {
  _ThrowingSyncQueueDao(super.attachedDatabase);

  @override
  Future<int> enqueueCreate(String tripId) {
    throw StateError('forced failure from _ThrowingSyncQueueDao');
  }
}

FinalizedTrip _buildTrip({
  required int durationSeconds,
  required double distanceMeters,
  String? id,
  String encodedPolyline = 'encoded',
}) {
  final start = DateTime.utc(2026, 4, 12, 8);
  return FinalizedTrip(
    id: id ?? 'trip-${durationSeconds}s-${distanceMeters}m',
    startTime: start,
    endTime: start.add(Duration(seconds: durationSeconds)),
    durationSeconds: durationSeconds,
    distanceMeters: distanceMeters,
    timeMovingSeconds: durationSeconds,
    timeStuckSeconds: 0,
    encodedPolyline: encodedPolyline,
  );
}

void main() {
  group('TrackingServiceController.persistFinalizedTrip', () {
    late AppDatabase db;
    late _RecordingNotifications notifications;
    late TrackingServiceController controller;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      notifications = _RecordingNotifications();
      controller = TrackingServiceController(
        service: FlutterBackgroundService(),
        database: db,
        tripsDao: db.tripsDao,
        syncQueueDao: db.syncQueueDao,
        notifications: notifications,
        userPreferencesDao: db.userPreferencesDao,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'discards a trip below the 30 s duration threshold (D-10) and '
      'dismisses the notification',
      () async {
        final trip = _buildTrip(durationSeconds: 20, distanceMeters: 500);

        final result = await controller.persistFinalizedTrip(trip);

        expect(result, isA<PersistDiscardedTooShort>());
        final summaries = await db.tripsDao.watchAllSummaries().first;
        expect(summaries, isEmpty);
        final pending = await db.syncQueueDao.watchPending().first;
        expect(pending, isEmpty);
        expect(notifications.dismissCalls, 1);
      },
    );

    test(
      'discards a trip below the 100 m distance threshold (D-10) and '
      'dismisses the notification',
      () async {
        final trip = _buildTrip(durationSeconds: 60, distanceMeters: 50);

        final result = await controller.persistFinalizedTrip(trip);

        expect(result, isA<PersistDiscardedTooShort>());
        final summaries = await db.tripsDao.watchAllSummaries().first;
        expect(summaries, isEmpty);
        final pending = await db.syncQueueDao.watchPending().first;
        expect(pending, isEmpty);
        expect(notifications.dismissCalls, 1);
      },
    );

    test(
      'persists a qualifying trip inside a transaction, enqueues the '
      'create row, and dismisses the notification',
      () async {
        final trip = _buildTrip(
          durationSeconds: 120,
          distanceMeters: 800,
          id: 'trip-saved-1',
          encodedPolyline: 'polyline-value',
        );

        final result = await controller.persistFinalizedTrip(trip);

        expect(result, isA<PersistSaved>());
        expect((result as PersistSaved).tripId, 'trip-saved-1');

        final summaries = await db.tripsDao.watchAllSummaries().first;
        expect(summaries, hasLength(1));
        expect(summaries.single.id, 'trip-saved-1');
        // Phase 3 D-06: direction is now labeled at save time, never unknown.
        expect(summaries.single.direction, isNot(kDirectionUnknown));
        expect(summaries.single.durationSeconds, 120);
        expect(summaries.single.distanceMeters, 800);
        expect(summaries.single.timeMovingSeconds, 120);
        expect(summaries.single.timeStuckSeconds, 0);
        expect(summaries.single.isManualEntry, isFalse);

        final row = await db.tripsDao.findById('trip-saved-1');
        expect(row, isNotNull);
        expect(row!.userId, kDefaultUserId);
        expect(row.routePolyline, 'polyline-value');

        final pending = await db.syncQueueDao.watchPending().first;
        expect(pending, hasLength(1));
        expect(pending.single.tripId, 'trip-saved-1');
        expect(pending.single.action, kSyncActionCreate);
        expect(pending.single.status, kSyncStatusPending);
        expect(pending.single.payload, isNull);

        expect(notifications.dismissCalls, 1);
      },
    );

    test(
      'rolls back the trips insert when the sync-queue insert throws',
      () async {
        final throwingDao = _ThrowingSyncQueueDao(db);
        final throwingController = TrackingServiceController(
          service: FlutterBackgroundService(),
          database: db,
          tripsDao: db.tripsDao,
          syncQueueDao: throwingDao,
          notifications: notifications,
          userPreferencesDao: db.userPreferencesDao,
        );
        final trip = _buildTrip(
          durationSeconds: 180,
          distanceMeters: 1500,
          id: 'trip-rollback-1',
        );

        final result = await throwingController.persistFinalizedTrip(trip);

        expect(result, isA<PersistFailed>());
        final summaries = await db.tripsDao.watchAllSummaries().first;
        expect(summaries, isEmpty);
        final pending = await db.syncQueueDao.watchPending().first;
        expect(pending, isEmpty);
        // dismiss still called even on failure (T-02-20).
        expect(notifications.dismissCalls, 1);
      },
    );

    test(
      'persisted trip direction is not kDirectionUnknown after Phase 3 '
      '(D-06)',
      () async {
        // No user_preferences row → getOrDefault() returns defaults
        // (morningCutoffHour = 12). _buildTrip uses startTime
        // DateTime.utc(2026, 4, 12, 8), which is 08:00 UTC. With a
        // UTC+0 local timezone hour 8 < 12 → kDirectionToOffice.
        // In any timezone where the local hour is < 12, the same label
        // applies. The test asserts the invariant: direction is never
        // kDirectionUnknown.
        final trip = _buildTrip(
          durationSeconds: 120,
          distanceMeters: 800,
          id: 'trip-direction-check',
        );

        final result = await controller.persistFinalizedTrip(trip);

        expect(result, isA<PersistSaved>());
        final summaries = await db.tripsDao.watchAllSummaries().first;
        expect(summaries.single.direction, isNot(kDirectionUnknown));
      },
    );
  });
}
