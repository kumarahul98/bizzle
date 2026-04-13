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
// The three event-name constants at the bottom of the file are
// deliberately NOT in `lib/config/constants.dart`. They are the private
// coupling contract between this file and
// `tracking_service_controller.dart` + `tracking_providers.dart`.
// Surfacing them globally would invite other features to reuse the same
// strings, which is architecturally wrong — the service isolate's
// invoke channel is a local protocol, not a cross-feature concept.

import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
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
/// Plan 02-05 will add two things to this handler (each marked with an
/// explicit "Plan 02-05 hook" comment below):
///
///   * `setForegroundNotificationInfo` + the flutter_local_notifications
///     `.show(kTrackingNotificationId, ...)` call so Android collapses
///     the fbs stock foreground-service notification and our UX-03 Stop
///     button notification into a single shade entry (D-14).
///   * A notification-dismiss call on the finalize path so the
///     notification clears when the trip saves.
@pragma('vm:entry-point')
Future<void> trackingServiceOnStart(ServiceInstance service) async {
  // Android-only in Phase 2 per project constraints (iOS is post-v0.1).
  if (service is AndroidServiceInstance) {
    // Plan 02-05 hook: the stock initial notification title
    // ("Recording commute") is already set by `configureBackgroundService`
    // below, but plan 02-05 replaces it with the full UX-03 notification
    // via:
    //   await service.setForegroundNotificationInfo(
    //     title: kTrackingNotificationTitle,
    //     content: '', // or a short subtitle the plan decides on
    //   );
    //   await TrackingNotificationService.showRecording(); // same id
    // Left empty here so plan 02-05 has an obvious insertion point.
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
    // Plan 02-05 hook: dismiss the UX-03 notification here so the
    // "Recording commute" entry clears from the shade before the UI
    // isolate's persistence path runs. Something like:
    //   await TrackingNotificationService.dismissRecording();
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

// ---------------------------------------------------------------------------
// Service ↔ UI isolate event names.
//
// These three constants are intentionally local to this file rather than
// in `lib/config/constants.dart`. They are the private coupling contract
// between `tracking_service.dart` (producer) and
// `tracking_service_controller.dart` + `tracking_providers.dart`
// (consumers). Exposing them globally would invite unrelated features to
// reuse the strings, which is architecturally wrong — the invoke channel
// is a local protocol, not a cross-feature concept.
// ---------------------------------------------------------------------------

/// Event name for the 1 Hz snapshot stream from service → UI isolate.
const String kTrackingStateEvent = 'tracking_state';

/// Event name for the finalised trip payload from service → UI isolate.
const String kTripFinalizedEvent = 'trip_finalized';

/// Event name for the stop command from UI → service isolate.
const String kStopTrackingEvent = 'stop_tracking';
