// Unit tests for the UI-isolate auto-pause prompt gate (Phase 18 Plan 04,
// TRACK-10, D-11/D-12, SC#5).
//
// The service isolate signals once per stationary streak on
// `onAutoPausePrompt`. The OPT-IN gate lives in `TrackingNotifier._attach`,
// where Drift is reachable: the prompt is posted ONLY when
// `user_preferences.auto_pause_enabled` is true. These tests drive a
// controllable prompt stream and a notification spy through the REAL notifier
// (`TrackingNotifier.new`, not the no-op subclass) and assert:
//   * enabled → showAutoPausePrompt() is called once per signal;
//   * disabled (default) → showAutoPausePrompt() is NEVER called (SC#5).

import 'dart:async';

import 'package:drift/drift.dart';
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

/// Event source whose `onAutoPausePrompt` is driven by the test. Every other
/// stream is empty so the notifier's other listeners stay inert.
class _PromptDrivingEventSource implements TrackingEventSource {
  final StreamController<Map<String, dynamic>?> promptController =
      StreamController<Map<String, dynamic>?>.broadcast();

  @override
  Stream<Map<String, dynamic>?> get onAutoPausePrompt =>
      promptController.stream;

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
  Future<bool> start({Map<String, dynamic>? initialAccumulatorState}) async =>
      true;

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}
}

/// Notification spy: records every showAutoPausePrompt() call so the gate can
/// be asserted without touching flutter_local_notifications.
class _SpyNotifications implements TrackingNotificationService {
  int autoPausePromptCalls = 0;

  @override
  Future<void> showAutoPausePrompt() async {
    autoPausePromptCalls += 1;
  }

  @override
  Future<void> dismiss() async {}

  @override
  Future<void> showRecording({
    int elapsedSeconds = 0,
    double distanceMeters = 0,
    int timeMovingSeconds = 0,
    int timeStuckSeconds = 0,
    String direction = kDirectionToOffice,
  }) async {}

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Subscribe to `userPreferenceProvider` and resolve once it reaches the data
/// state, so the gate's synchronous `asData` read sees a value. Keeping the
/// subscription alive (the returned listener is held by the container) avoids
/// the StreamProvider being disposed mid-loading.
Future<void> _awaitPrefsData(ProviderContainer container) async {
  final completer = Completer<void>();
  container.listen(userPreferenceProvider, (prev, next) {
    if (next.hasValue && !completer.isCompleted) completer.complete();
  }, fireImmediately: true);
  if (container.read(userPreferenceProvider).hasValue) return;
  await completer.future;
}

ProviderContainer _container({
  required _PromptDrivingEventSource source,
  required _SpyNotifications notifications,
  required AppDatabase db,
  required bool autoPauseEnabled,
}) {
  final controller = TrackingServiceController(
    source: source,
    database: db,
    tripsDao: db.tripsDao,
    syncQueueDao: db.syncQueueDao,
    notifications: notifications,
    userPreferencesDao: db.userPreferencesDao,
    tripBreaksDao: db.tripBreaksDao,
  );
  final prefs = autoPauseEnabled
      ? const UserPreferencesValue(
          userId: kDefaultUserId,
          darkMode: kDarkModeSystem,
          morningCutoffHour: 12,
          eveningCutoffHour: 12,
          reminderEnabled: false,
          reminderTime: null,
          weekendReminder: false,
          weeklyNotificationEnabled: false,
          autoPauseEnabled: true,
          hasSeenOnboarding: false,
          homeLat: null,
          homeLng: null,
          officeLat: null,
          officeLng: null,
          backfillMarkerVersion: 0,
        )
      : const UserPreferencesValue(
          userId: kDefaultUserId,
          darkMode: kDarkModeSystem,
          morningCutoffHour: 12,
          eveningCutoffHour: 12,
          reminderEnabled: false,
          reminderTime: null,
          weekendReminder: false,
          weeklyNotificationEnabled: false,
          autoPauseEnabled: false,
          hasSeenOnboarding: false,
          homeLat: null,
          homeLng: null,
          officeLat: null,
          officeLng: null,
          backfillMarkerVersion: 0,
        );
  return ProviderContainer(
    overrides: [
      trackingEventSourceProvider.overrideWithValue(source),
      trackingServiceControllerProvider.overrideWithValue(controller),
      trackingNotificationServiceProvider.overrideWithValue(notifications),
      userPreferenceProvider.overrideWith(
        (ref) => Stream<UserPreferencesValue>.value(prefs),
      ),
    ],
  );
}

void main() {
  group('auto-pause prompt gate (SC#5)', () {
    late AppDatabase db;
    late _PromptDrivingEventSource source;
    late _SpyNotifications notifications;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      source = _PromptDrivingEventSource();
      notifications = _SpyNotifications();
    });

    tearDown(() async {
      await source.promptController.close();
      await db.close();
    });

    test(
      'enabled → prompt signal posts the notification once per signal',
      () async {
        final container = _container(
          source: source,
          notifications: notifications,
          db: db,
          autoPauseEnabled: true,
        );
        addTearDown(container.dispose);
        // Build the real notifier so _attach subscribes to onAutoPausePrompt.
        container.read(trackingStateProvider.notifier);
        // Keep userPreferenceProvider subscribed and wait until it is in the
        // data state (the gate reads it synchronously via `asData`).
        await _awaitPrefsData(container);

        source.promptController.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(notifications.autoPausePromptCalls, 1);

        source.promptController.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(notifications.autoPausePromptCalls, 2);
      },
    );

    test('disabled (default OFF) → prompt signal NEVER posts (SC#5)', () async {
      final container = _container(
        source: source,
        notifications: notifications,
        db: db,
        autoPauseEnabled: false,
      );
      addTearDown(container.dispose);
      container.read(trackingStateProvider.notifier);
      await _awaitPrefsData(container);

      source.promptController.add(null);
      await Future<void>.delayed(Duration.zero);
      source.promptController.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(notifications.autoPausePromptCalls, 0);
    });
  });
}
