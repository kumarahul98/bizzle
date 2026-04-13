// File-level ignore for `unreachable_from_main`: every member of
// `TrackingNotificationService` is reached indirectly from `main()` via a
// Riverpod provider closure (`trackingNotificationServiceProvider` → the
// controller's `_notifications` field → `showRecording` / `dismiss`).
// `unreachable_from_main` does not follow closures across library
// boundaries, so it false-positives every instance method here.
// `initialize` is called from `main()` directly; the others are
// transitively reached through `TrackingServiceController`.
// ignore_for_file: unreachable_from_main

// UX-03 foreground notification wrapper for the Phase 2 tracking feature.
//
// ## D-14 UNIFICATION CONTRACT (DO NOT DEVIATE)
//
// `kTrackingNotificationId` and `kTrackingNotificationChannelId` are the
// SAME id / channel that `configureBackgroundService()` in
// `tracking_service.dart` pins
// `AndroidConfiguration.foregroundServiceNotificationId` and
// `AndroidConfiguration.notificationChannelId` to (plan 02-03).
//
// Android dedupes notifications by `(channelId, notificationId)`.
// Calling `FlutterLocalNotificationsPlugin.show(kTrackingNotificationId,
// ..., kTrackingNotificationChannelId, ...)` REPLACES the transient
// placeholder notification that `flutter_background_service` raises on
// the same id/channel when the foreground service starts. Result: a
// single shade entry with the Stop action button — never two.
//
// DO NOT change either constant, and DO NOT introduce a second channel
// or second id, without updating both `tracking_service.dart` and this
// file in the same commit.
//
// ## Isolate binding
//
// This service is UI-isolate only. The foreground response handler
// (`_onForegroundResponse`) is an instance method on a UI-isolate object
// and only fires when the user taps the Stop action while the app is in
// the foreground.
//
// The background response handler
// (`trackingNotificationBackgroundHandler` at the bottom of this file) is
// a TOP-LEVEL function annotated `@pragma('vm:entry-point')`. That pragma
// is load-bearing — without it, tree-shaking silently drops the function
// in release builds and the Stop action becomes a no-op when the app is
// backgrounded (Pitfall 4 in 02-RESEARCH.md §10).
//
// Plan 02-05 shows the notification from the UI isolate (from
// `TrackingServiceController.start`) rather than from the service isolate
// because `flutter_local_notifications` in the background isolate is a
// separate plugin instance — showing from the UI isolate keeps the
// foreground response handler bound to the same plugin state that
// registered it.

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/tracking_service_events.dart';

/// UX-03 foreground notification manager. Owns the single "Active commute"
/// channel and the single ongoing "Recording commute" notification that is
/// shown while the tracking service isolate is running.
///
/// Construction cost is negligible — the underlying
/// [FlutterLocalNotificationsPlugin] instance is a singleton, so multiple
/// `TrackingNotificationService` instances share the same plugin state.
/// That is intentional: `main()` creates one instance to call
/// [initialize] before `runApp`, and `tracking_providers.dart` exposes a
/// (different) instance as a Riverpod provider so production code can
/// inject the same API surface. Both share the singleton plugin so
/// channel registration survives across instances.
class TrackingNotificationService {
  /// Construct a notification service. Tests pass an explicit
  /// [FlutterLocalNotificationsPlugin] (or a fake) to keep the plugin
  /// singleton out of the unit-test surface.
  TrackingNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Initialise the plugin with the notification channel and the
  /// foreground / background response handlers. Called ONCE from `main()`
  /// before `runApp`, and again (harmlessly) from the Riverpod provider
  /// factory — `flutter_local_notifications` treats repeat `initialize`
  /// calls as idempotent.
  Future<void> initialize() async {
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          trackingNotificationBackgroundHandler,
    );
    await _createChannel();
  }

  /// Show the UX-03 foreground notification: static title "Recording
  /// commute", no body (D-14 static text — no per-sample refresh), Stop
  /// action button wired through `kStopTrackingEvent`. Collapses onto the
  /// `flutter_background_service` stock notification via the D-14
  /// unification contract.
  Future<void> showRecording() async {
    const androidDetails = AndroidNotificationDetails(
      kTrackingNotificationChannelId,
      kTrackingNotificationChannelName,
      channelDescription: kTrackingNotificationChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.service,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          kTrackingStopActionId,
          kTrackingStopActionLabel,
          // showsUserInterface defaults to false (which is what we want —
          // Stop must not open the app). Do NOT cancel the notification
          // from the action handler; `persistFinalizedTrip`'s dismiss()
          // path is the single place that clears it (T-02-20).
          cancelNotification: false,
        ),
      ],
    );
    await _plugin.show(
      id: kTrackingNotificationId,
      title: kTrackingNotificationTitle,
      notificationDetails:
          const NotificationDetails(android: androidDetails),
      payload: 'tracking_active',
    );
  }

  /// Cancel the UX-03 notification. Called from every exit path of
  /// `TrackingServiceController.persistFinalizedTrip` — success, discard,
  /// and the catch block — so the notification never outlives the
  /// tracking session (T-02-20).
  Future<void> dismiss() async {
    await _plugin.cancel(id: kTrackingNotificationId);
  }

  Future<void> _createChannel() async {
    const channel = AndroidNotificationChannel(
      kTrackingNotificationChannelId,
      kTrackingNotificationChannelName,
      description: kTrackingNotificationChannelDescription,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);
  }

  /// Foreground tap handler. V5 validation (T-02-17): match the exact
  /// Stop action id and ignore everything else.
  void _onForegroundResponse(NotificationResponse response) {
    if (response.actionId == kTrackingStopActionId) {
      FlutterBackgroundService().invoke(kStopTrackingEvent);
    }
  }
}

/// Background notification response handler. Fires when the user taps
/// the Stop action on the foreground notification while the app is NOT
/// in the foreground.
///
/// This function MUST be top-level (not a class method) AND MUST be
/// annotated `@pragma('vm:entry-point')`. Without the pragma, Dart's
/// tree-shaker silently drops the function in release builds and the
/// Stop action button becomes a no-op (Pitfall 4 in 02-RESEARCH.md §10).
///
/// V5 validation (T-02-17): match the exact Stop action id and ignore
/// everything else so a spoofed or stale action id cannot route the
/// background handler anywhere unexpected.
@pragma('vm:entry-point')
void trackingNotificationBackgroundHandler(
  NotificationResponse response,
) {
  if (response.actionId == kTrackingStopActionId) {
    FlutterBackgroundService().invoke(kStopTrackingEvent);
  }
}
