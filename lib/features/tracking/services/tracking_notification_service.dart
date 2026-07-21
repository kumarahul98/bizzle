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
// DO NOT change either constant, and DO NOT route any OTHER notification
// through this id/channel pair, without updating both
// `tracking_service.dart` and this file in the same commit.
//
// Scope note (2026-07-21): this contract governs the FOREGROUND-SERVICE
// notification only. The auto-pause prompt is a separate notification on
// `kAutoPauseNotificationId` and, since 2026-07-21, its own
// `kAutoPauseChannelId` at `Importance.high` (D-01) — it never touches the
// pair above, so it is outside this rule rather than an exception to it.
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

import 'dart:io' show Platform;

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
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _platformIsAndroid = Platform.isAndroid;

  /// Test-seam constructor. Allows injecting [platformIsAndroid] to exercise
  /// the iOS gate without relying on dart:io [Platform] (RESEARCH Pitfall 2).
  ///
  /// [plugin] may also be injected to replace the singleton in tests.
  TrackingNotificationService.forTesting({
    required bool platformIsAndroid,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _platformIsAndroid = platformIsAndroid;

  final FlutterLocalNotificationsPlugin _plugin;

  /// Runtime platform flag. True on Android, false on iOS / other platforms.
  ///
  /// Set via the default constructor from [Platform.isAndroid] (dart:io).
  /// Overridable via [TrackingNotificationService.forTesting] for unit tests.
  final bool _platformIsAndroid;

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
            // Phase 18 (Plan 04, D-12): the auto-pause prompt's Pause action.
            // Additive on iOS — Android-first; the same category serves the
            // prompt notification so the action id is recognised on both.
            DarwinNotificationAction.plain(
              kTrackingAutoPauseActionId,
              kTrackingAutoPauseActionLabel,
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
    await _createChannels();
  }

  /// Show / refresh the recording notification.
  ///
  /// Idempotent on the same `(channelId, notificationId)` — calling this
  /// method again replaces the previous notification's title/body in
  /// place without re-triggering sound or vibration.
  ///
  /// Pass `snapshot: null` for the placeholder show on service ready
  /// (before the first GPS sample arrives) — the body will display
  /// "0:00 elapsed · 0.0 km\nMoving 0m · Stuck 0m".
  ///
  /// `direction` defaults to [kDirectionToOffice] for the placeholder
  /// case; the notifier's snapshot listener should pass the resolved
  /// direction once it is known.
  ///
  /// IOS-11: no-op on iOS (dart:io Platform.isAndroid guard, defence-in-depth
  /// at service level). The primary testable guard lives in
  /// `TrackingServiceController.start` (defaultTargetPlatform check).
  Future<void> showRecording({
    int elapsedSeconds = 0,
    double distanceMeters = 0,
    int timeMovingSeconds = 0,
    int timeStuckSeconds = 0,
    String direction = kDirectionToOffice,
  }) async {
    // IOS-11 belt-and-suspenders guard: do not post a notification on iOS.
    // The controller gate (defaultTargetPlatform != iOS) is the primary,
    // testable guard; this guard makes the service self-documenting and
    // ensures the post never fires even if the controller is bypassed.
    if (!_platformIsAndroid) return;

    final title = _renderTitle(direction);
    final body = _renderBody(
      elapsedSeconds: elapsedSeconds,
      distanceMeters: distanceMeters,
      timeMovingSeconds: timeMovingSeconds,
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
      // BigTextStyle expands to the two-line body (IOS-14: line1\nline2).
      // summary is the compact one-liner shown in collapsed shade —
      // UI-SPEC Surface E: "{km} km · {elapsed}".
      styleInformation: BigTextStyleInformation(
        body,
        summaryText:
            '${(distanceMeters / 1000).toStringAsFixed(1)} km'
            ' · ${formatElapsed(elapsedSeconds)}',
      ),
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
    // POST_NOTIFICATIONS denied on Android 13+ or plugin not initialised in
    // test host → swallow silently. Tracking must never be gated on
    // notification permission (D-14). The controller also swallows this,
    // but swallowing here too keeps the service self-contained.
    try {
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
    } on Object {
      // intentionally swallowed — same rationale as controller gate
    }
  }

  /// Post the opt-in auto-pause prompt (Phase 18 Plan 04, D-12).
  ///
  /// A SEPARATE, dismissible notification on [kAutoPauseNotificationId] (NOT
  /// the ongoing [kTrackingNotificationId], so it never replaces or collides
  /// with the recording notification). It carries a single "Pause"
  /// `AndroidNotificationAction` whose action id is
  /// [kTrackingAutoPauseActionId] — tapping it routes to the pause command
  /// via the shared foreground/background response handlers (the same mechanism
  /// the Stop action uses). PROMPT ONLY: ignoring or swiping the prompt away
  /// (`autoCancel: true`, not ongoing) leaves the trip recording normally.
  ///
  /// The caller (`TrackingNotifier`) only invokes this when the user has opted
  /// into auto-pause, so with the preference OFF no prompt is ever posted
  /// (SC#5).
  Future<void> showAutoPausePrompt() async {
    const androidDetails = AndroidNotificationDetails(
      // 2026-07-21 (D-01): its OWN channel, not the tracking one. Importance
      // lives on the channel on Android 8+ and is immutable once created, so
      // while this shared kTrackingNotificationChannelId (Importance.low) the
      // prompt could never surface as a heads-up — raising `importance:` here
      // would have silently done nothing on every existing install.
      kAutoPauseChannelId,
      kAutoPauseChannelName,
      channelDescription: kAutoPauseChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      // Non-ongoing (default) + autoCancel (default) so the user can trivially
      // dismiss the prompt; dismissing leaves recording untouched (D-12).
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      styleInformation: BigTextStyleInformation(kAutoPauseNotificationBody),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          kTrackingAutoPauseActionId,
          kTrackingAutoPauseActionLabel,
          // showsUserInterface: true — Activity PendingIntent on Android 14
          // (our minSdk) so selectedNotificationAction delivers the actionId
          // to the response handlers, mirroring the Stop action.
          // cancelNotification defaults to true — tapping Pause clears the
          // prompt, which is exactly what we want (the prompt is one-shot).
          showsUserInterface: true,
        ),
      ],
    );
    const darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: kTrackingNotificationCategoryId,
      presentSound: false,
      presentBadge: false,
    );
    await _plugin.show(
      id: kAutoPauseNotificationId,
      title: kAutoPauseNotificationTitle,
      body: kAutoPauseNotificationBody,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      ),
      payload: 'auto_pause_prompt',
    );
  }

  /// Cancel the UX-03 notification. Called from every exit path of
  /// `TrackingServiceController.persistFinalizedTrip` — success, discard,
  /// and the catch block — so the notification never outlives the
  /// tracking session (T-02-20).
  Future<void> dismiss() async {
    await _plugin.cancel(id: kTrackingNotificationId);
  }

  /// Create both Android notification channels.
  ///
  /// TWO channels, deliberately (2026-07-21, D-01):
  ///
  ///   * the tracking channel stays `Importance.low` — its ongoing
  ///     notification refreshes every ~5 s and would buzz constantly at any
  ///     higher importance;
  ///   * the auto-pause prompt gets `Importance.high` so it surfaces as a
  ///     heads-up banner above that ongoing notification.
  ///
  /// They cannot be one channel. Importance is a CHANNEL property on Android
  /// 8+ and is immutable after creation, so a single channel can only ever have
  /// one of those two behaviours. Splitting them also gives the user
  /// independent control: silencing the prompt in system settings leaves the
  /// recording notification intact.
  Future<void> _createChannels() async {
    const trackingChannel = AndroidNotificationChannel(
      kTrackingNotificationChannelId,
      kTrackingNotificationChannelName,
      description: kTrackingNotificationChannelDescription,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );
    // Sound and vibration stay OFF (D-04): Importance.high alone gives the
    // heads-up banner, and this prompt can fire on every 15-minute stuck
    // streak — in heavy traffic that could be several times per commute.
    const autoPauseChannel = AndroidNotificationChannel(
      kAutoPauseChannelId,
      kAutoPauseChannelName,
      description: kAutoPauseChannelDescription,
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(trackingChannel);
    await android?.createNotificationChannel(autoPauseChannel);
  }

  /// Render the title with the resolved direction substituted.
  static String _renderTitle(String direction) {
    final label = direction == kDirectionToHome ? 'home' : 'office';
    return kTrackingNotificationTitleTemplate.replaceFirst(
      '{direction}',
      label,
    );
  }

  /// Render the two-line enriched notification body (IOS-14).
  ///
  /// Line 1 uses [kTrackingNotificationBodyLine1Template] with {elapsed} and
  /// {km} substituted. Line 2 uses [kTrackingNotificationBodyLine2Template]
  /// with {moving} and {stuck} substituted. Lines are joined by '\n' so
  /// BigTextStyleInformation renders them as two distinct rows in the expanded
  /// notification shade.
  ///
  /// formatElapsed produces MM:SS / H:MM:SS; formatStuck produces compact
  /// 'Nm' / 'NhMm' notation (both shared with the Live Activity bridge).
  static String _renderBody({
    required int elapsedSeconds,
    required double distanceMeters,
    required int timeMovingSeconds,
    required int timeStuckSeconds,
  }) {
    final elapsed = formatElapsed(elapsedSeconds);
    final km = (distanceMeters / 1000).toStringAsFixed(1);
    final moving = formatStuck(timeMovingSeconds);
    final stuck = formatStuck(timeStuckSeconds);
    final line1 = kTrackingNotificationBodyLine1Template
        .replaceFirst('{elapsed}', elapsed)
        .replaceFirst('{km}', km);
    final line2 = kTrackingNotificationBodyLine2Template
        .replaceFirst('{moving}', moving)
        .replaceFirst('{stuck}', stuck);
    return '$line1\n$line2';
  }

  /// Foreground tap handler. V5 validation (T-02-17): match the exact
  /// action id and ignore everything else. OPEN is a no-op here — the
  /// platform brings the app to the foreground via the Activity
  /// PendingIntent before this handler fires.
  void _onForegroundResponse(NotificationResponse response) {
    if (response.actionId == kTrackingStopActionId) {
      FlutterBackgroundService().invoke(kStopTrackingEvent);
    }
    // Phase 18 (Plan 04, D-12 / T-18-12): the auto-pause prompt's Pause action
    // routes to the SAME pause command path the active-hero Pause button uses.
    // Exact action-id match (V5 validation) so a spoofed/stale id is ignored.
    if (response.actionId == kTrackingAutoPauseActionId) {
      // 2026-07-21 (D-02): does NOT pause. Relays to the service, which bounces
      // kAutoPauseConfirmEvent back to whichever isolate owns the UI so the
      // user gets a confirmation dialog. Pausing here directly — the previous
      // behaviour — gave zero feedback that anything had happened.
      FlutterBackgroundService().invoke(kAutoPauseConfirmCommand);
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
  // 2026-07-21 (D-02): identical to the foreground handler — relay, never
  // pause. This isolate cannot reach the UI, which is exactly why the relay
  // goes through the service instead of an in-app stream. Exact action-id
  // match so a spoofed/stale id cannot trigger anything.
  if (response.actionId == kTrackingAutoPauseActionId) {
    FlutterBackgroundService().invoke(kAutoPauseConfirmCommand);
  }
  // OPEN action: handled by the platform resume path; no Dart work needed.
}
