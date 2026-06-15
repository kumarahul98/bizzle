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
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/auto_pause_detector.dart';
import 'package:traevy/features/tracking/services/location_settings_builder.dart';
import 'package:traevy/features/tracking/services/tracking_service_events.dart';
import 'package:traevy/features/tracking/services/trip_accumulator.dart';
import 'package:home_widget/home_widget.dart';

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
    // `setAsForegroundService()` calls Android's `startForeground(id,
    // notification)` internally, which REPLACES whatever notification
    // flutter_local_notifications previously posted at that id — including
    // our action-bearing Stop notification from the UI isolate. The
    // resulting fbs placeholder has no actions, so the Stop button
    // disappears.
    //
    // Fix (D-14 race resolution): signal the UI isolate that
    // setAsForegroundService has completed. `TrackingNotifier` listens
    // on `kServiceReadyEvent` and immediately re-posts the action-bearing
    // notification via `TrackingNotificationService.showRecording()`,
    // overwriting fbs's placeholder with our Stop-button version.
    service.invoke(kServiceReadyEvent);
  }

  var accumulator = TripAccumulator(startedAt: DateTime.now().toUtc());
  var stopping = false;

  service.on(kSetInitialStateCommand).listen((event) {
    if (stopping) return;
    if (event != null && event['initialState'] != null) {
      try {
        final state = Map<String, dynamic>.from(event['initialState'] as Map);
        accumulator = TripAccumulator.restore(state);
      } catch (e) {
        // T-25-03: Ensure parsing exceptions in the background isolate are caught
        // and logged so a malformed state doesn't crash the background process.
        print('Failed to restore initial state: $e');
      }
    }
  });
  // Phase 18 (Plan 04, D-11): the auto-pause detector runs SERVICE-SIDE,
  // alongside the accumulator, consuming the SAME stuck/moving classification
  // addSample() returns — never raw speed, never a second threshold. It fires
  // at most once per uninterrupted stuck streak; the UI isolate gates the
  // actual prompt on the opt-in pref (so OFF → no prompt, SC#5).
  final autoPauseDetector = AutoPauseDetector(
    thresholdSeconds: kAutoPauseStationaryThresholdSeconds,
  );
  StreamSubscription<Position>? positionSub;
  Timer? uiTimer;

  // LocationSettings: platform-branched via buildLocationSettings() so the
  // SC#4 AppleSettings/AndroidSettings selection lives in exactly one place.
  // On Android this produces AndroidSettings(accuracy: high,
  // intervalDuration: kTrackingSampleInterval) — byte-for-byte identical to
  // the previous inline construction (D-08 regression guard).
  // See location_settings_builder.dart and 02-RESEARCH §3.
  final settings = buildLocationSettings();

  positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
    (position) {
      // Race guard: a position can still arrive after the stop handler
      // has started but before `positionSub?.cancel()` returns. The
      // `stopping` flag short-circuits those late samples before they
      // touch the accumulator. See 02-RESEARCH §8 stop-race.
      if (stopping) return;
      final interval = accumulator.addSample(position);
      // Phase 18 (Plan 04, D-11/D-12): feed each ATTRIBUTED interval's
      // classification into the detector. A moving interval resets the streak
      // and re-arms; a stuck interval extends it. When the uninterrupted stuck
      // streak first crosses the threshold AND the trip is not already paused,
      // signal the UI isolate ONCE — it posts the prompt only if the user opted
      // in. NO payload crosses the boundary (T-18-08), just the channel name.
      if (interval != null) {
        if (interval.stuck) {
          autoPauseDetector.onStuckInterval(interval.seconds);
        } else {
          autoPauseDetector.onMovingInterval();
        }
        if (!accumulator.isPaused && autoPauseDetector.shouldPrompt()) {
          service.invoke(kAutoPausePromptEvent);
        }
      }
    },
    onError: (Object error, StackTrace stack) async {
      // Mid-trip position stream failure path (WR-01). Examples: the
      // user toggles Location Services off while a trip is active, a
      // transient platform error surfaces, or permissions are revoked.
      // Without this handler the error would propagate to the isolate
      // zone, be silently swallowed, and leave the UI stuck in
      // TrackingActive with no further events ever arriving.
      //
      // PII guard (T-02-07): we deliberately DO NOT log or forward
      // `error.toString()` — raw platform errors can include lat/lng
      // coordinates. Instead we forward a stable short `reason` tag
      // that the UI notifier maps to a user-facing message.
      if (stopping) return;
      stopping = true;
      uiTimer?.cancel();
      await positionSub?.cancel();
      service.invoke(
        kTrackingErrorEvent,
        <String, Object?>{'reason': 'position_stream_error'},
      );
      await service.stopSelf();
    },
    cancelOnError: true,
  );

  print('=== TRACKING SERVICE ONSTART BOOTED ===');
  HomeWidget.saveWidgetData<String>('widget_title', 'Stop Commute');
  HomeWidget.saveWidgetData<bool>('widget_show_stats', true);
  HomeWidget.updateWidget(name: 'CommuteWidgetProvider', androidName: 'CommuteWidgetProvider');

  uiTimer = Timer.periodic(kTrackingUiUpdateInterval, (_) {
    if (stopping) return;
    final snapshot = accumulator.snapshot(DateTime.now().toUtc());
    service.invoke(
      kTrackingStateEvent,
      snapshot.toMap(),
    );
    try {
      final distance = '${(snapshot.distanceMeters / 1000).toStringAsFixed(1)} km';
      final m = snapshot.elapsedSeconds ~/ 60;
      final h = m ~/ 60;
      final min = m % 60;
      final duration = h > 0 ? '${h}h ${min}m' : '${min}m';
      
      print('=== TRACKING SERVICE UPDATING WIDGET TICK: $duration ===');
      HomeWidget.saveWidgetData<String>('widget_distance', distance).catchError((_) => false);
      HomeWidget.saveWidgetData<String>('widget_duration', duration).catchError((_) => false);
      HomeWidget.updateWidget(
        name: 'CommuteWidgetProvider',
        androidName: 'CommuteWidgetProvider',
      ).catchError((_) => false);
    } catch (_) {}
  });

  // Phase 18 (D-08): pause/resume only TOGGLE the accumulator — they do NOT
  // cancel the position subscription or stop the service. The very next
  // uiTimer tick emits a snapshot whose `isPaused` reflects the new state, so
  // the dumb-terminal UI updates from that snapshot, never from a local
  // action. Both handlers early-return when `stopping` is set (T-18-10): a
  // late pause racing the Stop handler must not touch a finalized accumulator,
  // mirroring the stop-race guard above.
  service.on(kTrackingPauseCommand).listen((_) {
    if (stopping) return;
    accumulator.pause(DateTime.now().toUtc());
  });

  service.on(kTrackingResumeCommand).listen((_) {
    if (stopping) return;
    accumulator.resume(DateTime.now().toUtc());
  });

  service.on(kStopTrackingEvent).listen((_) async {
    // Order matters: set the flag BEFORE cancelling the subscription so
    // any in-flight listener callback early-returns instead of touching
    // a disposed accumulator (02-RESEARCH §8).
    stopping = true;
    await positionSub?.cancel();
    uiTimer?.cancel();
    await HomeWidget.saveWidgetData<String>('widget_title', 'Start Commute');
    await HomeWidget.saveWidgetData<bool>('widget_show_stats', false);
    await HomeWidget.updateWidget(name: 'CommuteWidgetProvider', androidName: 'CommuteWidgetProvider');
    final trip = accumulator.finalize(DateTime.now().toUtc());
    // WR-05: if the app is force-stopped before the UI isolate can
    // receive and persist kTripFinalizedEvent, the trip is lost. Save it
    // to SharedPreferences so the UI can recover on relaunch.
    try {
      const platform = MethodChannel('traevy/tracking');
      await platform.invokeMethod<void>(
        'savePendingTrip',
        jsonEncode(trip.toMap()),
      );
    } on Object {
      // Platform call failed — trip will be lost, but service stops anyway
    }
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
