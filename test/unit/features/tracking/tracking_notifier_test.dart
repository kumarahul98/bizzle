import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';

/// Unit tests for `TrackingNotifier` behavioural invariants.
///
/// These tests do NOT reach the real flutter_background_service plugin:
/// a [_NoopNotifier] subclass short-circuits `build()` so no stream
/// subscriptions are opened, and a [_RecordingController] subclass of
/// [TrackingServiceController] records every call to `start` / `stop`
/// without touching the fbs singleton.
///
/// WR-02 coverage: `start()` called while the state is `TrackingStopping`
/// — the post-`trip_finalized` persist window — must NOT invoke the
/// controller and must NOT transition out of `TrackingStopping`.
class _NoopNotifier extends TrackingNotifier {
  @override
  TrackingState build() {
    // Deliberately skip `super.build()`: the production implementation
    // opens three fbs stream subscriptions, which crash under the test
    // harness with a MissingPluginException.
    return const TrackingIdle();
  }

  /// Test-only state driver. `Notifier.state` is protected but accessible
  /// from the subclass itself, so this helper is the single audited
  /// write site for tests.
  // ignore: use_setters_to_change_properties
  void forceState(TrackingState value) {
    state = value;
  }
}

/// [TrackingServiceController] subclass whose `start` / `stop` methods
/// are pure counters. Construction still requires a real
/// [AppDatabase] + DAOs + [TrackingNotificationService] because the
/// superclass has all-required final fields, so setUp builds an
/// in-memory Drift database (same pattern as persist_finalized_trip_test).
class _RecordingController extends TrackingServiceController {
  _RecordingController({
    required super.service,
    required super.database,
    required super.tripsDao,
    required super.syncQueueDao,
    required super.notifications,
    required super.userPreferencesDao,
  });

  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<bool> start() async {
    startCalls += 1;
    return true;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
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
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  group('TrackingNotifier.start() WR-02 guard', () {
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
      controller = _RecordingController(
        service: FlutterBackgroundService(),
        database: db,
        tripsDao: db.tripsDao,
        syncQueueDao: db.syncQueueDao,
        notifications: _NoopNotifications(),
        userPreferencesDao: db.userPreferencesDao,
      );
      container = ProviderContainer(
        overrides: [
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
      'start() while state is TrackingStopping is a no-op — controller is '
      'never invoked and state stays TrackingStopping',
      () async {
        final notifier = container.read(trackingStateProvider.notifier)
            as _NoopNotifier
          // Put the notifier into the exact state the `trip_finalized`
          // listener holds while awaiting `persistFinalizedTrip`.
          ..forceState(const TrackingStopping());
        expect(notifier.state, isA<TrackingStopping>());
        expect(controller.startCalls, 0);

        await notifier.start();

        expect(controller.startCalls, 0);
        expect(notifier.state, isA<TrackingStopping>());
      },
    );

    test(
      'start() while state is TrackingStarting is a no-op — second call '
      'during startup must not queue a second startService',
      () async {
        final notifier = container.read(trackingStateProvider.notifier)
            as _NoopNotifier
          ..forceState(const TrackingStarting());

        await notifier.start();

        expect(controller.startCalls, 0);
        expect(notifier.state, isA<TrackingStarting>());
      },
    );

    test(
      'start() while state is TrackingActive is a no-op',
      () async {
        final notifier = container.read(trackingStateProvider.notifier)
            as _NoopNotifier
          ..forceState(
            TrackingActive(
              startedAt: DateTime.utc(2026, 4, 12, 8),
              elapsedSeconds: 10,
              distanceMeters: 100,
              currentSpeedKmh: 20,
              timeMovingSeconds: 10,
              timeStuckSeconds: 0,
            ),
          );

        await notifier.start();

        expect(controller.startCalls, 0);
        expect(notifier.state, isA<TrackingActive>());
      },
    );

    test(
      'start() from TrackingIdle invokes the controller and transitions '
      'through TrackingStarting',
      () async {
        final notifier = container.read(trackingStateProvider.notifier)
            as _NoopNotifier;

        expect(notifier.state, isA<TrackingIdle>());
        await notifier.start();

        expect(controller.startCalls, 1);
        // Controller's fake `start()` returns true, so the state should
        // remain in TrackingStarting (no transition to TrackingError).
        expect(notifier.state, isA<TrackingStarting>());
      },
    );

    test(
      'start() from TrackingError is allowed (retry path) and invokes the '
      'controller',
      () async {
        final notifier = container.read(trackingStateProvider.notifier)
            as _NoopNotifier
          ..forceState(TrackingError('previous failure'));

        await notifier.start();

        expect(controller.startCalls, 1);
        expect(notifier.state, isA<TrackingStarting>());
      },
    );
  });
}
