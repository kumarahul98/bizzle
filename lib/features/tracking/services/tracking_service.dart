// Tracking service isolate entrypoint.
//
// IMPORTANT:
// * This file runs inside the flutter_background_service background
//   isolate. DO NOT import Flutter UI (`package:flutter/material.dart`,
//   widgets, Riverpod, etc.) — the isolate has no UI Engine and those
//   imports will either fail at link time or silently no-op.
// * DO NOT log `Position` fields. Raw latitude / longitude is PII
//   (T-02-07 in the plan's threat model). The only allowed egress is the
//   encoded polyline inside `FinalizedTrip`.
// * Every top-level function below MUST carry `@pragma('vm:entry-point')`.
//   flutter_background_service looks them up reflectively in release
//   builds, so tree-shaking will silently delete them otherwise
//   (Pitfall 4 in 02-RESEARCH.md §10).
//
// The three event-name constants (`kTrackingStateEvent`,
// `kTripFinalizedEvent`, `kStopTrackingEvent`) used to live at the bottom
// of this file as the private coupling contract between the service
// isolate and its UI-side wrapper. Plan 02-05 lifted them into
// `tracking_service_events.dart` so the new
// `tracking_notification_service.dart` can import `kStopTrackingEvent`
// (for its Stop action handlers) without pulling in this file's
// `@pragma('vm:entry-point')` isolate entrypoint. The constants remain
// feature-local — they are deliberately NOT in `lib/config/constants.dart`.

import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/tracking_service_events.dart';
import 'package:traevy/features/tracking/services/trip_accumulator.dart';

/// flutter_background_service onStart entrypoint. Runs in a background
/// isolate as soon as `FlutterBackgroundService.startService()` is
/// called.
///
/// Lifecycle:
///
///   1. Construct a [TripAccumulator] with `DateTime.now().toUtc()`.
///   2. Subscribe to `Geolocator.getPositionStream` using
///      [kTrackingSampleInterval] and push accepted samples into the
///      accumulator.
///   3. On a [kTrackingUiUpdateInterval] timer, send a
///      [TripAccumulator.snapshot] payload to the UI isolate via
///      [ServiceInstance.invoke] under the [kTrackingStateEvent] channel.
///   4. On [kStopTrackingEvent] from the UI isolate: set the stopping
///      flag FIRST, then cancel the position subscription (stop-race
///      guard from 02-RESEARCH §8), finalize the trip, emit
///      [kTripFinalizedEvent], and call [ServiceInstance.stopSelf].
///
/// On Android the service isolate is promoted to foreground state via
/// `setAsForegroundService()` so Android keeps it alive across app
/// suspend/resume. The visible UX-03 notification is shown from the UI
/// isolate (via `TrackingNotificationService.showRecording()` in
/// `TrackingServiceController.start()`) — see
/// `tracking_notification_service.dart`'s file-level comment for why
/// showing from the UI isolate keeps the foreground response handler
/// bound to the same plugin state.
@pragma('vm:entry-point')
Future<void> trackingServiceOnStart(ServiceInstance service) async {
  // Android-only in Phase 2 per project constraints (iOS is post-v0.1).
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    // The UI isolate's `showRecording()` will replace this entry via the
    // D-14 unification contract (same channel id + same notification id).
    // Setting an empty body here avoids a flash of fbs's default body
    // text between service-start and the UI isolate's first `show()`.
    await service.setForegroundNotificationInfo(
      title: kTrackingNotificationTitle,
      content: '',
    );
  }

  final accumulator = TripAccumulator(startedAt: DateTime.now().toUtc());
  var stopping = false;
  StreamSubscription<Position>? positionSub;
  Timer? uiTimer;

  // LocationSettings: high accuracy, no distance-based throttling (time
  // throttling comes from intervalDuration), 3-second sample cadence.
  // See 02-RESEARCH §3 for the battery/fidelity rationale.
  // distanceFilter defaults to 0 (no distance throttling — we time-throttle
  // via intervalDuration instead), so it is deliberately omitted.
  final settings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    intervalDuration: kTrackingSampleInterval,
  );

  positionSub = Geolocator.getPositionStream(locationSettings: settings)
      .listen((position) {
    // Race guard: a position can still arrive after the stop handler has
    // started but before `positionSub?.cancel()` returns. The
    // `stopping` flag short-circuits those late samples before they
    // touch the accumulator. See 02-RESEARCH §8 stop-race.
    if (stopping) return;
    accumulator.addSample(position);
  });

  uiTimer = Timer.periodic(kTrackingUiUpdateInterval, (_) {
    if (stopping) return;
    service.invoke(
      kTrackingStateEvent,
      accumulator.snapshot(DateTime.now().toUtc()).toMap(),
    );
  });

  service.on(kStopTrackingEvent).listen((_) async {
    // Order matters: set the flag BEFORE cancelling the subscription so
    // any in-flight listener callback early-returns instead of touching
    // a disposed accumulator (02-RESEARCH §8).
    stopping = true;
    await positionSub?.cancel();
    uiTimer?.cancel();
    final trip = accumulator.finalize(DateTime.now().toUtc());
    service.invoke(kTripFinalizedEvent, trip.toMap());
    // The UX-03 notification is dismissed from the UI isolate inside
    // TrackingServiceController.persistFinalizedTrip — every exit path
    // of that method calls `_notifications.dismiss()` so the shade
    // entry is always cleared (T-02-20). We do NOT dismiss from here
    // because flutter_local_notifications state in the service isolate
    // is a separate plugin instance from the UI isolate's, and
    // dismiss() must target the plugin that showed the notification.
    await service.stopSelf();
  });
}

/// Configure `FlutterBackgroundService` for the tracking feature. Called
/// once from `main()` (plan 02-05 wires it in).
///
/// ## D-14 UNIFICATION CONTRACT (DO NOT DEVIATE)
///
/// Android dedupes notifications by `(channelId, notificationId)`. If we
/// let `flutter_background_service` spawn its stock notification with a
/// DIFFERENT id, the user sees TWO shade entries during tracking — one
/// stock, one from `flutter_local_notifications`. Instead we pin
/// [AndroidConfiguration.foregroundServiceNotificationId] to the exact
/// same [kTrackingNotificationId] the UX-03 notification will use in
/// plan 02-05, and we pin [AndroidConfiguration.notificationChannelId] to
/// [kTrackingNotificationChannelId].
///
/// Plan 02-05 then calls
/// `flutterLocalNotificationsPlugin.show(kTrackingNotificationId, ...)`
/// on the same channel, which Android treats as "update existing
/// notification", collapsing them into a single entry with the Stop
/// action button.
///
/// The [AndroidConfiguration.initialNotificationTitle] below is a brief
/// placeholder that plan 02-05 overwrites immediately — it must still be
/// non-empty for fbs to start the service.
@pragma('vm:entry-point')
Future<void> configureBackgroundService() async {
  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: trackingServiceOnStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      // D-14: same channel id the UX-03 notification uses (plan 02-05).
      notificationChannelId: kTrackingNotificationChannelId,
      initialNotificationTitle: kTrackingNotificationTitle,
      initialNotificationContent: '',
      // D-14: same id the UX-03 notification uses (plan 02-05). This is
      // the dedup contract — see function doc above.
      foregroundServiceNotificationId: kTrackingNotificationId,
      foregroundServiceTypes: const <AndroidForegroundType>[
        AndroidForegroundType.location,
      ],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
    ),
  );
}

// Event-name constants for the service ↔ UI isolate protocol now live in
// `tracking_service_events.dart` so `tracking_notification_service.dart`
// can import them without pulling in this file's entrypoint symbols. See
// that file's doc comment for the rationale.
