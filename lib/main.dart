// Application entry point.
//
// Plugin bootstraps that must run BEFORE `runApp`:
//
//   1. `tz.initializeTimeZones()` populates the timezone database used by
//      `flutter_local_notifications` `zonedSchedule`. Must be the first
//      call after `WidgetsFlutterBinding.ensureInitialized()` — any
//      `TZDateTime` construction before this call throws.
//
//   2. `TrackingNotificationService.initialize()` registers the Android
//      notification channel for the UX-03 active-commute notification
//      and wires the foreground / background tap handlers. The service
//      created here is a fresh instance — the Riverpod provider in
//      `tracking_providers.dart` creates its own instance. Both share
//      the same underlying `FlutterLocalNotificationsPlugin` singleton,
//      so channel registration from this call survives into every
//      `showRecording()` / `dismiss()` invocation through the provider.
//
//   3. `NotificationService().initialize()` registers the two Phase 7
//      Android notification channels (weekly summary, commute reminder)
//      and reschedules any already-enabled notifications from DB
//      preferences. Must run after `tz.initializeTimeZones()`.
//
//   4. `configureBackgroundService()` registers the
//      flutter_background_service onStart entrypoint (plan 02-03) so
//      `FlutterBackgroundService().startService()` on the tracking
//      screen can spin up the tracking isolate. Android-only: Phase 14
//      replaced flutter_background_service with a main-isolate GPS engine
//      on iOS, so configuring the Android service on iOS is unnecessary
//      and was the likely cause of the ~20s white-screen stall.
//
//   5. Firebase + GoogleSignIn bootstrap (D-15 degrade — try/catch):
//      `Firebase.initializeApp` loads `DefaultFirebaseOptions` (generated
//      by `flutterfire configure`). `GoogleSignIn.instance.initialize`
//      configures the Web OAuth client ID so Android can mint a Firebase-
//      usable ID token (RESEARCH Pitfall 2). Both calls are wrapped in a
//      try/catch so the app degrades gracefully to guest mode when
//      `google-services.json` / `firebase_options.dart` is absent (e.g.
//      dev or CI builds). The resulting `firebaseReady` flag is injected
//      into the `ProviderScope` via `firebaseReadyProvider.overrideWithValue`
//      so `AuthStateNotifier` can detect and react to the degrade path
//      without crashing.
//
// `WidgetsFlutterBinding.ensureInitialized()` MUST be the first call —
// flutter_local_notifications and flutter_background_service both rely
// on the platform channel infrastructure the binding bootstraps.

import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:traevy/app.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:traevy/firebase_options.dart';
import 'package:traevy/notifications/notification_service.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  print('=== BACKGROUND CALLBACK FIRED: $uri ===');
  if (uri?.host == 'toggletracking') {
    final container = ProviderContainer();
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      print('=== SERVICE IS RUNNING: $isRunning ===');
      if (isRunning) {
        await HomeWidget.saveWidgetData<String>('widget_title', 'Stopping...');
        await HomeWidget.updateWidget(
          name: 'CommuteWidgetProvider',
          androidName: 'CommuteWidgetProvider',
        );
        await container.read(trackingServiceControllerProvider).stop();
      } else {
        await HomeWidget.saveWidgetData<String>('widget_title', 'Starting...');
        await HomeWidget.updateWidget(
          name: 'CommuteWidgetProvider',
          androidName: 'CommuteWidgetProvider',
        );
        await container.read(trackingServiceControllerProvider).start();
      }
    } finally {
      container.dispose();
    }
  }
}

// Helper: run [fn] with a [timeout]. If it exceeds the timeout or throws,
// the error is swallowed so startup always proceeds to runApp.
Future<void> _safeInit(
  String label,
  Future<void> Function() fn, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    await fn().timeout(timeout);
  } on Object {
    // Swallow — platform-channel timeouts / errors must never block runApp.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Disable google_fonts runtime network fetching — fonts are bundled in
  // assets/fonts/ as TTF files. Must be set before any GoogleFonts call.
  // See Pitfall 2 in .planning/phases/08-ui-overhaul/08-RESEARCH.md.
  GoogleFonts.config.allowRuntimeFetching = false;
  tz.initializeTimeZones(); // Must be before any TZDateTime use.

  // Set the device-local timezone so that `tz.local` resolves to the correct
  // IANA zone (e.g. "Asia/Kolkata") rather than defaulting to UTC.
  // Without this, `tz.TZDateTime(tz.local, ...)` in NotificationService
  // schedules reminders at the chosen HH:mm in UTC — off by the UTC offset.
  //
  // Wrapped in try/catch: a detection failure (unknown zone name, platform
  // channel error) logs and falls back to leaving tz.local as-is (UTC) without
  // crashing startup — matches the Firebase degrade pattern below.
  try {
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    debugPrint('[main] bootstrap: tz.local set to ${timezoneInfo.identifier}');
  } on Object catch (e) {
    debugPrint('[main] bootstrap: tz.setLocalLocation failed, using UTC: $e');
  }

  // Each init below is wrapped in a timeout. On iOS, platform-channel calls
  // made before runApp can silently deadlock in release mode (the
  // FlutterLocalNotificationsPlugin and FlutterBackgroundService both open
  // platform channels that the engine does not guarantee to service until
  // runApp wires up the window). The timeout ensures runApp is always reached
  // and the user sees real UI instead of a permanent white screen.
  //
  // The inits are independent of each other, so they run concurrently and
  // the pre-runApp delay is bounded by the SLOWEST init instead of the sum
  // of all of them. The one ordering constraint kept: the two notification
  // services share the same underlying FlutterLocalNotificationsPlugin
  // singleton, so their initialize() calls stay sequential within one branch.
  //
  // D-15 degrade (Firebase branch): wrapped in try/catch so the app starts
  // as guest mode when google-services.json / firebase_options.dart is
  // absent (Pitfall 5 — boot-time crash prevention). The flag is injected
  // into the ProviderScope so AuthStateNotifier detects the degrade path and
  // does NOT open an authStateChanges() subscription on the uninitialized
  // Firebase SDK. Never block UI on getIdToken() here — offline-first
  // contract.
  var firebaseReady = false;
  await Future.wait<void>([
    _safeInit(
      'NotificationServices',
      () async {
        await TrackingNotificationService().initialize();
        await NotificationService().initialize();
      },
      timeout: const Duration(seconds: 8),
    ),
    _safeInit(
      'HomeWidget',
      () => HomeWidget.registerBackgroundCallback(backgroundCallback),
    ),
    // configureBackgroundService is Android-only. Phase 14 replaced
    // flutter_background_service with a main-isolate GPS engine on iOS
    // (IosTrackingEngine), so the service is not started or configured on
    // iOS. Calling FlutterBackgroundService().configure() unconditionally on
    // iOS was the likely cause of the ~20s white-screen stall seen during
    // Phase 15 UAT on iPhone 13 / iOS 26.5.
    if (Platform.isAndroid)
      _safeInit(
        'configureBackgroundService',
        () => configureBackgroundService(),
      ),
    () async {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 8));
        await GoogleSignIn.instance
            .initialize(
              serverClientId: kGoogleServerClientId,
            )
            .timeout(const Duration(seconds: 4));
        firebaseReady = true;
      } on Object {
        firebaseReady = false;
      }
    }(),
  ]);

  debugPrint('[main] bootstrap: runApp');
  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
      child: const TraevyApp(),
    ),
  );
}
