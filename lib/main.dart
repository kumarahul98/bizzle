// Application entry point.
//
// Two plugin bootstraps must run BEFORE `runApp`:
//
//   1. `TrackingNotificationService.initialize()` registers the Android
//      notification channel for the UX-03 active-commute notification
//      and wires the foreground / background tap handlers. The service
//      created here is a fresh instance — the Riverpod provider in
//      `tracking_providers.dart` creates its own instance. Both share
//      the same underlying `FlutterLocalNotificationsPlugin` singleton,
//      so channel registration from this call survives into every
//      `showRecording()` / `dismiss()` invocation through the provider.
//
//   2. `configureBackgroundService()` registers the
//      flutter_background_service onStart entrypoint (plan 02-03) so
//      `FlutterBackgroundService().startService()` on the tracking
//      screen can spin up the tracking isolate.
//
// `WidgetsFlutterBinding.ensureInitialized()` MUST be the first call —
// flutter_local_notifications and flutter_background_service both rely
// on the platform channel infrastructure the binding bootstraps.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/app.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TrackingNotificationService().initialize();
  await configureBackgroundService();
  runApp(const ProviderScope(child: TraevyApp()));
}
