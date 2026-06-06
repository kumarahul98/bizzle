import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_event_source.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/state/finalized_trip.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/services/direction_label_service.dart';

/// TRACK-12 (D-05 / D-06): the manual direction override must win over the
/// time-of-day auto-label both at finalize (persist) and live (resolved
/// getter the notification refresh consumes).
///
/// All assertions are timezone-independent: the expected auto-label is
/// computed from the SAME [DirectionLabelService] rule the production code
/// uses, so the tests pass under any host timezone (the suite runs under
/// IST +0530, so a fixed-UTC start cannot be assumed to land in the morning).
///
/// Two harnesses:
///   * Tests 1-2 drive `persistFinalizedTrip` directly against an in-memory
///     AppDatabase (mirrors persist_finalized_trip_test setUp).
///   * Test 3 reuses the `_NoopNotifier` build-skip seam so no real
///     event-source streams open, and overrides `userPreferenceProvider`
///     so the auto-label cutoffs are the schema defaults.

/// Minimal [TrackingEventSource] — never emits; satisfies the controller and
/// notifier constructors without touching any plugin.
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
  Future<bool> start() async => true;

  @override
  Future<void> stop() async {}
}

/// No-op notifications fake — records nothing, swallows every call.
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

/// Notifier that skips `super.build()` so no event-source subscriptions open.
/// The resolved-direction getter and setDirection are still real production
/// code under test.
class _NoopNotifier extends TrackingNotifier {
  @override
  TrackingState build() => const TrackingIdle();
}

FinalizedTrip _buildTrip({
  required DateTime startUtc,
  required int durationSeconds,
  required double distanceMeters,
  required String id,
}) {
  return FinalizedTrip(
    id: id,
    startTime: startUtc,
    endTime: startUtc.add(Duration(seconds: durationSeconds)),
    durationSeconds: durationSeconds,
    distanceMeters: distanceMeters,
    timeMovingSeconds: durationSeconds,
    timeStuckSeconds: 0,
    encodedPolyline: 'encoded',
  );
}

/// Compute the auto-label the production persist/notifier path would derive
/// for [startUtc] with the schema-default cutoffs.
String _autoLabelFor(DateTime startUtc) => const DirectionLabelService().label(
  startUtc.toLocal(),
  kDefaultDirectionCutoffHour,
  kDefaultDirectionCutoffHour,
);

/// The direction that is NOT [direction] — used to prove the override beats
/// the heuristic regardless of which way the heuristic falls.
String _opposite(String direction) =>
    direction == kDirectionToOffice ? kDirectionToHome : kDirectionToOffice;

void main() {
  group('persistFinalizedTrip directionOverride (D-06)', () {
    late AppDatabase db;
    late TrackingServiceController controller;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      controller = TrackingServiceController(
        source: _FakeTrackingEventSource(),
        database: db,
        tripsDao: db.tripsDao,
        syncQueueDao: db.syncQueueDao,
        notifications: _NoopNotifications(),
        userPreferencesDao: db.userPreferencesDao,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'override wins at finalize: the persisted direction is the override, '
      'not the time-of-day auto-label',
      () async {
        final startUtc = DateTime.utc(2026, 4, 12, 8);
        final autoLabel = _autoLabelFor(startUtc);
        final override = _opposite(autoLabel);
        final trip = _buildTrip(
          startUtc: startUtc,
          durationSeconds: 120,
          distanceMeters: 800,
          id: 'trip-override',
        );

        final result = await controller.persistFinalizedTrip(
          trip,
          directionOverride: override,
        );

        expect(result, isA<PersistSaved>());
        final row = await db.tripsDao.findById('trip-override');
        expect(row, isNotNull);
        // The override beats the heuristic — and is provably NOT what the
        // auto-label would have produced.
        expect(row!.direction, override);
        expect(row.direction, isNot(autoLabel));
      },
    );

    test(
      'null override preserves the auto-label (existing behaviour, never '
      'kDirectionUnknown)',
      () async {
        final startUtc = DateTime.utc(2026, 4, 12, 8);
        final autoLabel = _autoLabelFor(startUtc);
        final trip = _buildTrip(
          startUtc: startUtc,
          durationSeconds: 120,
          distanceMeters: 800,
          id: 'trip-auto',
        );

        final result = await controller.persistFinalizedTrip(trip);

        expect(result, isA<PersistSaved>());
        final row = await db.tripsDao.findById('trip-auto');
        expect(row, isNotNull);
        expect(row!.direction, isNot(kDirectionUnknown));
        expect(row.direction, autoLabel);
      },
    );
  });

  group('TrackingNotifier.resolvedDirection (D-05)', () {
    late ProviderContainer container;
    late StreamController<UserPreferencesValue> prefsController;

    setUp(() {
      prefsController = StreamController<UserPreferencesValue>.broadcast();
      container = ProviderContainer(
        overrides: [
          // Deterministic schema-default cutoffs; the broadcast controller is
          // kept open and seeded synchronously below so `.asData` populates
          // without the never-closing-stream disposal hang.
          userPreferenceProvider.overrideWith((ref) => prefsController.stream),
          trackingStateProvider.overrideWith(_NoopNotifier.new),
        ],
      );
      addTearDown(() async {
        await prefsController.close();
        container.dispose();
      });
    });

    test(
      'with no override resolvedDirection returns the auto-label; after '
      'setDirection it returns the override regardless of start-time',
      () async {
        // Instantiate the notifier and the prefs subscription, then seed a
        // value and pump a microtask so `.asData` is populated.
        container.read(trackingStateProvider);
        container.listen(
          userPreferenceProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        prefsController.add(const UserPreferencesValue.defaults());
        await Future<void>.delayed(Duration.zero);

        final notifier =
            container.read(trackingStateProvider.notifier) as _NoopNotifier;

        // No override → auto-label for the given start-time.
        final morningUtc = DateTime.utc(2026, 4, 12, 2);
        final eveningUtc = DateTime.utc(2026, 4, 12, 20);
        expect(
          notifier.resolvedDirection(morningUtc),
          _autoLabelFor(morningUtc),
        );
        expect(
          notifier.resolvedDirection(eveningUtc),
          _autoLabelFor(eveningUtc),
        );

        // Override wins regardless of start-time.
        notifier.setDirection(kDirectionToHome);
        expect(notifier.resolvedDirection(morningUtc), kDirectionToHome);
        expect(notifier.resolvedDirection(eveningUtc), kDirectionToHome);

        notifier.setDirection(kDirectionToOffice);
        expect(notifier.resolvedDirection(morningUtc), kDirectionToOffice);
        expect(notifier.resolvedDirection(eveningUtc), kDirectionToOffice);
      },
    );
  });
}
