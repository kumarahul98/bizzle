// Application entry point.
//
// Three plugin bootstraps must run BEFORE `runApp`:
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
// `WidgetsFlutterBinding.ensureInitialized()` MUST be the first call —
// flutter_local_notifications and flutter_background_service both rely
// on the platform channel infrastructure the binding bootstraps.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:traevy/app.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_service.dart';
import 'package:traevy/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones(); // Must be before any TZDateTime use.
  await TrackingNotificationService().initialize();
  // Registers weekly summary + commute reminder channels.
  await NotificationService().initialize();
  await configureBackgroundService();
  runApp(const ProviderScope(child: TraevyApp()));
}
