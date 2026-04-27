import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';
import 'package:traevy/features/tracking/providers/backfill_provider.dart';

/// Root widget for the Traevy app.
///
/// Owns the `MaterialApp` wiring (title, light/dark themes, named
/// routes, and the home screen). Phase 6 mounts [DashboardScreen] as the
/// app root — the full dashboard UI with weekly summary and today's trips
/// per UX-01.
///
/// Phase 3 (D-05): `TraevyApp` is a `ConsumerWidget` so it can call
/// `ref.watch(directionBackfillProvider)` to trigger the one-shot
/// background backfill on app startup. The UI does not block on the
/// result — the provider is void and runs asynchronously.
class TraevyApp extends ConsumerWidget {
  /// Create the root app widget.
  const TraevyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Consume the backfill provider so it fires exactly once at startup.
    // Riverpod keepAlive ensures it does not re-run on rebuild (Pitfall 5).
    // The UI does not await or block on the result — it is void and runs
    // in the background.
    ref.watch(directionBackfillProvider);

    return MaterialApp(
      title: 'Traevy',
      theme: lightTheme,
      darkTheme: darkTheme,
      // Explicit even though it matches the MaterialApp default —
      // plan 01-02 locks the theme-mode contract so future phases
      // cannot silently change it.
      // ignore: avoid_redundant_argument_values
      themeMode: ThemeMode.system,
      routes: kAppRoutes,
      home: const DashboardScreen(),
    );
  }
}
