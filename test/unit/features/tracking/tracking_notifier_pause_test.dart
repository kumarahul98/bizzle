import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_event_source.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';

/// Unit tests for `TrackingNotifier.pause()` / `resume()` (Phase 18 Plan 03).
///
/// The notifier is a DUMB TERMINAL (D-08): pause()/resume() forward the
/// command to the controller and set NO local paused state. The displayed
/// paused/running flag arrives later via the next snapshot's `isPaused`.
class _NoopNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();

  // ignore: use_setters_to_change_properties
  void forceState(TrackingState value) {
    state = value;
  }
}

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
  Future<bool> start() async => true;

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}
}

class _RecordingController extends TrackingServiceController {
  _RecordingController({
    required super.source,
    required super.database,
    required super.tripsDao,
    required super.syncQueueDao,
    required super.notifications,
    required super.userPreferencesDao,
    required super.tripBreaksDao,
  });

  int pauseCalls = 0;
  int resumeCalls = 0;

  @override
  Future<void> pause() async {
    pauseCalls += 1;
  }

  @override
  Future<void> resume() async {
    resumeCalls += 1;
  }
}

class _NoopNotifications implements TrackingNotificationService {
  @override
  Future<void> dismiss() async {}

  @override
  Future<void> showRecording({
    int elapsedSeconds = 0,
    double distanceMeters = 0,
    int timeStuckSeconds = 0,
    String direction = kDirectionToOffice,
  }) async {}

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TrackingActive _activeState() => TrackingActive(
  startedAt: DateTime.utc(2026, 4, 12, 8),
  elapsedSeconds: 10,
  distanceMeters: 100,
  currentSpeedKmh: 20,
  timeMovingSeconds: 10,
  timeStuckSeconds: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('TrackingNotifier.pause()/resume()', () {
    late AppDatabase db;
    late _RecordingController controller;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      final fakeSource = _FakeTrackingEventSource();
      controller = _RecordingController(
        source: fakeSource,
        database: db,
        tripsDao: db.tripsDao,
        syncQueueDao: db.syncQueueDao,
        notifications: _NoopNotifications(),
        userPreferencesDao: db.userPreferencesDao,
        tripBreaksDao: db.tripBreaksDao,
      );
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          trackingEventSourceProvider.overrideWithValue(fakeSource),
          trackingServiceControllerProvider.overrideWithValue(controller),
          trackingStateProvider.overrideWith(_NoopNotifier.new),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test(
      'pause() while active forwards to the controller exactly once',
      () async {
        final notifier =
            container.read(trackingStateProvider.notifier) as _NoopNotifier
              ..forceState(_activeState());

        await notifier.pause();

        expect(controller.pauseCalls, 1);
        expect(controller.resumeCalls, 0);
      },
    );

    test(
      'resume() while active forwards to the controller exactly once',
      () async {
        final notifier =
            container.read(trackingStateProvider.notifier) as _NoopNotifier
              ..forceState(_activeState());

        await notifier.resume();

        expect(controller.resumeCalls, 1);
        expect(controller.pauseCalls, 0);
      },
    );

    test(
      'pause() sets NO local paused state — state is unchanged (D-08)',
      () async {
        final notifier =
            container.read(trackingStateProvider.notifier) as _NoopNotifier
              ..forceState(_activeState());

        await notifier.pause();

        // Dumb terminal: the notifier never flips isPaused locally; the next
        // snapshot dictates it. State remains the same running TrackingActive.
        final active = notifier.state as TrackingActive;
        expect(active.isPaused, isFalse);
      },
    );

    test('pause() is a no-op when not active', () async {
      final notifier =
          container.read(trackingStateProvider.notifier) as _NoopNotifier
            ..forceState(const TrackingIdle());

      await notifier.pause();

      expect(controller.pauseCalls, 0);
    });

    test('resume() is a no-op when not active', () async {
      final notifier =
          container.read(trackingStateProvider.notifier) as _NoopNotifier
            ..forceState(const TrackingStopping());

      await notifier.resume();

      expect(controller.resumeCalls, 0);
    });
  });

  group('trackingActiveFromSnapshotMap pause fields', () {
    test('decodes isPaused/pausedSeconds/breakCount from the snapshot map', () {
      final active = trackingActiveFromSnapshotMap(<String, Object?>{
        'startedAtUs': DateTime.utc(2026, 4, 12, 8).microsecondsSinceEpoch,
        'elapsedSeconds': 120,
        'distanceMeters': 500,
        'timeMovingSeconds': 90,
        'timeStuckSeconds': 30,
        'currentSpeedMs': 5,
        'isPaused': true,
        'pausedSeconds': 45,
        'breakCount': 2,
      });

      expect(active.isPaused, isTrue);
      expect(active.pausedSeconds, 45);
      expect(active.breakCount, 2);
    });

    test('defaults pause fields when absent (tolerant decode)', () {
      final active = trackingActiveFromSnapshotMap(<String, Object?>{
        'startedAtUs': DateTime.utc(2026, 4, 12, 8).microsecondsSinceEpoch,
        'elapsedSeconds': 120,
        'distanceMeters': 500,
        'timeMovingSeconds': 90,
        'timeStuckSeconds': 30,
        'currentSpeedMs': 5,
      });

      expect(active.isPaused, isFalse);
      expect(active.pausedSeconds, 0);
      expect(active.breakCount, 0);
    });
  });
}
