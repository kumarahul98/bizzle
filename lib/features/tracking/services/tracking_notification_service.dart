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
// 08-10: Traevy notification redesign — title/body now reflect the active
// commute direction and live snapshot values; OPEN action added alongside
// STOP. Cross-platform from day one (Android + iOS via DarwinInitializationSettings)
// so future iOS support is additive Dart, not a rewrite. The Android
// custom-RemoteViews "design v2" can layer on later behind the same
// public interface (showRecording / updateRecording / dismiss).
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
// ..., kTrackingNotificationChannelId, ...)` REPLACES the placeholder
// notification that `flutter_background_service` raises on the same
// id/channel when the foreground service starts. Result: a single shade
// entry with the action buttons — never two.
//
// DO NOT change either constant, and DO NOT introduce a second channel
// or second id, without updating both `tracking_service.dart` and this
// file in the same commit.
//
// ## Live updates
//
// `showRecording(snapshot, direction)` is invoked once on service ready
// and again on every TrackingActive snapshot via the notifier's _stateSub
// listener. The plugin's `show()` is idempotent on the same id+channel —
// it overwrites the previous notification's title/body without
// re-triggering sound/vibration (`onlyAlertOnce: true`).
//
// ## Isolate binding
//
// This service is UI-isolate only. The foreground response handler
// (`_onForegroundResponse`) is an instance method on a UI-isolate object
// and only fires when the user taps an action while the app is in
// the foreground.
//
// The background response handler
// (`trackingNotificationBackgroundHandler` at the bottom of this file) is
// a TOP-LEVEL function annotated `@pragma('vm:entry-point')`. That pragma
// is load-bearing — without it, tree-shaking silently drops the function
// in release builds and the actions become no-ops when the app is
// backgrounded (Pitfall 4 in 02-RESEARCH.md §10).

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/tracking_service_events.dart';
import 'package:traevy/shared/utils/formatters.dart';

/// UX-03 foreground notification manager. Owns the single "Active commute"
/// channel and the single ongoing notification that is shown while the
/// tracking service isolate is running. Live-updated on every snapshot
/// (08-10).
///
/// Construction cost is negligible — the underlying
/// [FlutterLocalNotificationsPlugin] instance is a singleton, so multiple
/// `TrackingNotificationService` instances share the same plugin state.
class TrackingNotificationService {
  /// Construct a notification service. Tests pass an explicit
  /// [FlutterLocalNotificationsPlugin] (or a fake) to keep the plugin
  /// singleton out of the unit-test surface.
  TrackingNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Initialise the plugin with platform-specific init settings, the
  /// notification channel, and the foreground / background response
  /// handlers. Called ONCE from `main()` before `runApp`, and again
  /// (harmlessly) from the Riverpod provider factory.
  ///
  /// Cross-platform: Android settings configure the launcher icon; iOS
  /// (Darwin) settings configure permission prompts and notification
  /// categories so the OPEN/STOP actions appear on iOS too. iOS support
  /// is wired but inert until `ios/Runner` is added to the project.
  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinInit = DarwinInitializationSettings(
      // Permission prompt is gated through the existing
      // TrackingPermissionService flow, not requested here.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          kTrackingNotificationCategoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              kTrackingOpenActionId,
              kTrackingOpenActionLabel,
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              kTrackingStopActionId,
              kTrackingStopActionLabel,
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
      ],
    );
    final initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          trackingNotificationBackgroundHandler,
    );
    await _createChannel();
  }

  /// Show / refresh the recording notification.
  ///
  /// Idempotent on the same `(channelId, notificationId)` — calling this
  /// method again replaces the previous notification's title/body in
  /// place without re-triggering sound or vibration.
  ///
  /// Pass `snapshot: null` for the placeholder show on service ready
  /// (before the first GPS sample arrives) — the body will display
  /// "0:00 elapsed · 0.0 km · 0m stuck".
  ///
  /// `direction` defaults to [kDirectionToOffice] for the placeholder
  /// case; the notifier's snapshot listener should pass the resolved
  /// direction once it is known.
  Future<void> showRecording({
    int elapsedSeconds = 0,
    double distanceMeters = 0,
    int timeStuckSeconds = 0,
    String direction = kDirectionToOffice,
  }) async {
    final title = _renderTitle(direction);
    final body = _renderBody(
      elapsedSeconds: elapsedSeconds,
      distanceMeters: distanceMeters,
      timeStuckSeconds: timeStuckSeconds,
    );
    final androidDetails = AndroidNotificationDetails(
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
      // BigTextStyle wraps the long stat row across multiple lines when
      // the notification is expanded, so the user sees the full
      // "{elapsed} elapsed · {km} km · {stuck} stuck" line on small
      // shades. Plain BigText is supported on every Android version.
      styleInformation: BigTextStyleInformation(body),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          kTrackingOpenActionId,
          kTrackingOpenActionLabel,
          showsUserInterface: true,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          kTrackingStopActionId,
          kTrackingStopActionLabel,
          // showsUserInterface: true — see D-14 contract above. Activity
          // PendingIntent is required on Android 14 (our minSdk) for
          // selectedNotificationAction to deliver the actionId.
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );
    final darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: kTrackingNotificationCategoryId,
      presentSound: false,
      presentBadge: false,
      // iOS treats every show() as a fresh notification; matching
      // identifier (the notification id) is what dedupes them. Keep
      // body short to avoid clipping in the lock-screen preview.
    );
    await _plugin.show(
      id: kTrackingNotificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      ),
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
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(channel);
  }

  /// Render the title with the resolved direction substituted.
  static String _renderTitle(String direction) {
    final label = direction == kDirectionToHome ? 'home' : 'office';
    return kTrackingNotificationTitleTemplate.replaceFirst(
      '{direction}',
      label,
    );
  }

  /// Render the body with formatted live values substituted.
  static String _renderBody({
    required int elapsedSeconds,
    required double distanceMeters,
    required int timeStuckSeconds,
  }) {
    final elapsed = formatDuration(elapsedSeconds);
    final km = (distanceMeters / 1000).toStringAsFixed(1);
    final stuck = formatStuck(timeStuckSeconds);
    return kTrackingNotificationBodyTemplate
        .replaceFirst('{elapsed}', elapsed)
        .replaceFirst('{km}', km)
        .replaceFirst('{stuck}', stuck);
  }

  /// Foreground tap handler. V5 validation (T-02-17): match the exact
  /// action id and ignore everything else. OPEN is a no-op here — the
  /// platform brings the app to the foreground via the Activity
  /// PendingIntent before this handler fires.
  void _onForegroundResponse(NotificationResponse response) {
    if (response.actionId == kTrackingStopActionId) {
      FlutterBackgroundService().invoke(kStopTrackingEvent);
    }
    // OPEN: no Dart action needed — the showsUserInterface: true /
    // DarwinNotificationActionOption.foreground options route through
    // the platform's resume path on both Android (onNewIntent) and iOS
    // (UNUserNotificationCenter delegate).
  }
}

/// Background notification response handler. Fires when the user taps
/// an action on the foreground notification while the app is NOT in the
/// foreground.
///
/// This function MUST be top-level (not a class method) AND MUST be
/// annotated `@pragma('vm:entry-point')`. Without the pragma, Dart's
/// tree-shaker silently drops the function in release builds and the
/// action buttons become no-ops (Pitfall 4 in 02-RESEARCH.md §10).
///
/// V5 validation (T-02-17): match the exact action id and ignore
/// everything else so a spoofed or stale action id cannot route the
/// background handler anywhere unexpected.
@pragma('vm:entry-point')
void trackingNotificationBackgroundHandler(
  NotificationResponse response,
) {
  if (response.actionId == kTrackingStopActionId) {
    FlutterBackgroundService().invoke(kStopTrackingEvent);
  }
  // OPEN action: handled by the platform resume path; no Dart work needed.
}
