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
//      screen can spin up the tracking isolate.
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

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:traevy/app.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_service.dart';
import 'package:traevy/firebase_options.dart';
import 'package:traevy/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Disable google_fonts runtime network fetching — fonts are bundled in
  // assets/fonts/ as TTF files. Must be set before any GoogleFonts call.
  // See Pitfall 2 in .planning/phases/08-ui-overhaul/08-RESEARCH.md.
  GoogleFonts.config.allowRuntimeFetching = false;
  tz.initializeTimeZones(); // Must be before any TZDateTime use.
  await TrackingNotificationService().initialize();
  // Registers weekly summary + commute reminder channels.
  await NotificationService().initialize();
  await configureBackgroundService();

  // D-15 degrade: wrap Firebase init in try/catch so the app starts as
  // guest mode when google-services.json / firebase_options.dart is absent
  // (Pitfall 5 — boot-time crash prevention). The flag is injected into the
  // ProviderScope so AuthStateNotifier detects the degrade path and does NOT
  // open an authStateChanges() subscription on the uninitialized Firebase SDK.
  // Never block UI on getIdToken() here — offline-first contract.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await GoogleSignIn.instance.initialize(
      serverClientId: kGoogleServerClientId,
    );
    firebaseReady = true;
  } on Object catch (_) {
    firebaseReady = false;
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
      child: const TraevyApp(),
    ),
  );
}
