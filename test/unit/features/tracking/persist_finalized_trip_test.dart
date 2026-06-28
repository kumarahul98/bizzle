import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/sync_queue_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/features/tracking/services/tracking_event_source.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/state/finalized_trip.dart';

/// Minimal [TrackingEventSource] for tests that only exercise
/// [TrackingServiceController.persistFinalizedTrip] — start/stop/streams
/// are never called in these tests.
class _FakeTrackingEventSource implements TrackingEventSource {
  @override
  Stream<Map<String, dynamic>?> get onState =>
      const Stream<Map<String, dynamic>?>.empty();

  @override
  Stream<Map<String, dynamic>?> get onFinalized =>
      const Stream<Map<String, dynamic>?>.empty();

  @override
  Stream<Map<String, dynamic>?> get onError =>
      const Stream<Map<String, dynamic>?>.empty();

  @override
  Stream<Map<String, dynamic>?> get onReady =>
      const Stream<Map<String, dynamic>?>.empty();

  @override
  Stream<Map<String, dynamic>?> get onAutoPausePrompt =>
      const Stream<Map<String, dynamic>?>.empty();

  @override
  Future<bool> start({Map<String, dynamic>? initialAccumulatorState}) async => true;

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}
}

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
  int totalPausedSeconds = 0,
  List<Map<String, Object?>> breaks = const <Map<String, Object?>>[],
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
    totalPausedSeconds: totalPausedSeconds,
    breaks: breaks,
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
        source: _FakeTrackingEventSource(),
        database: db,
        tripsDao: db.tripsDao,
        syncQueueDao: db.syncQueueDao,
        notifications: notifications,
        userPreferencesDao: db.userPreferencesDao,
        tripBreaksDao: db.tripBreaksDao,
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
          source: _FakeTrackingEventSource(),
          database: db,
          tripsDao: db.tripsDao,
          syncQueueDao: throwingDao,
          notifications: notifications,
          userPreferencesDao: db.userPreferencesDao,
          tripBreaksDao: db.tripBreaksDao,
        );
        final start = DateTime.utc(2026, 4, 12, 8);
        final trip = _buildTrip(
          durationSeconds: 180,
          distanceMeters: 1500,
          id: 'trip-rollback-1',
          totalPausedSeconds: 30,
          breaks: <Map<String, Object?>>[
            <String, Object?>{
              'startUs': start
                  .add(const Duration(seconds: 60))
                  .microsecondsSinceEpoch,
              'endUs': start
                  .add(const Duration(seconds: 90))
                  .microsecondsSinceEpoch,
            },
          ],
        );

        final result = await throwingController.persistFinalizedTrip(trip);

        expect(result, isA<PersistFailed>());
        final summaries = await db.tripsDao.watchAllSummaries().first;
        expect(summaries, isEmpty);
        final pending = await db.syncQueueDao.watchPending().first;
        expect(pending, isEmpty);
        // T-18-06: no break row survives the atomic rollback.
        final breakRows = await db.tripBreaksDao.breaksForTrip(
          'trip-rollback-1',
        );
        expect(breakRows, isEmpty);
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

    test(
      'persists break rows + total_paused_seconds atomically (Phase 18, D-07)',
      () async {
        final start = DateTime.utc(2026, 4, 12, 8);
        final firstBreakStart = start.add(const Duration(seconds: 60));
        final firstBreakEnd = start.add(const Duration(seconds: 90));
        final secondBreakStart = start.add(const Duration(seconds: 200));
        final secondBreakEnd = start.add(const Duration(seconds: 260));
        final trip = _buildTrip(
          durationSeconds: 600,
          distanceMeters: 3000,
          id: 'trip-with-breaks',
          totalPausedSeconds: 90, // 30 + 60
          breaks: <Map<String, Object?>>[
            <String, Object?>{
              'startUs': firstBreakStart.microsecondsSinceEpoch,
              'endUs': firstBreakEnd.microsecondsSinceEpoch,
            },
            <String, Object?>{
              'startUs': secondBreakStart.microsecondsSinceEpoch,
              'endUs': secondBreakEnd.microsecondsSinceEpoch,
            },
          ],
        );

        final result = await controller.persistFinalizedTrip(trip);

        expect(result, isA<PersistSaved>());

        // The trips row carries the aggregate.
        final row = await db.tripsDao.findById('trip-with-breaks');
        expect(row, isNotNull);
        expect(row!.totalPausedSeconds, 90);

        // Two normalized break rows, chronological, UTC start/end preserved.
        final breakRows = await db.tripBreaksDao.breaksForTrip(
          'trip-with-breaks',
        );
        expect(breakRows, hasLength(2));
        expect(breakRows.every((b) => b.tripId == 'trip-with-breaks'), isTrue);
        expect(breakRows.every((b) => b.id.isNotEmpty), isTrue);
        expect(breakRows.first.startTime.toUtc(), firstBreakStart);
        expect(breakRows.first.endTime?.toUtc(), firstBreakEnd);
        expect(breakRows.last.startTime.toUtc(), secondBreakStart);
        expect(breakRows.last.endTime?.toUtc(), secondBreakEnd);

        // The trip + sync row landed in the SAME transaction.
        final pending = await db.syncQueueDao.watchPending().first;
        expect(pending, hasLength(1));
        expect(pending.single.tripId, 'trip-with-breaks');
      },
    );

    test(
      'no-break trip writes zero break rows and total_paused_seconds 0',
      () async {
        final trip = _buildTrip(
          durationSeconds: 120,
          distanceMeters: 800,
          id: 'trip-no-breaks',
        );

        final result = await controller.persistFinalizedTrip(trip);

        expect(result, isA<PersistSaved>());
        final row = await db.tripsDao.findById('trip-no-breaks');
        expect(row, isNotNull);
        expect(row!.totalPausedSeconds, 0);
        final breakRows = await db.tripBreaksDao.breaksForTrip(
          'trip-no-breaks',
        );
        expect(breakRows, isEmpty);
      },
    );
  });
}
