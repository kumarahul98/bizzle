import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/shell/main_shell.dart';
import 'package:traevy/features/tracking/providers/backfill_provider.dart';

/// Root widget for the Traevy app.
///
/// Owns the [MaterialApp] wiring including dynamic [ThemeMode] driven by
/// [userPreferenceProvider] (D-04, UX-02). Phase 8 mounts [MainShell] as the
/// app root — a 4-tab bottom-navigation shell replacing the direct
/// DashboardScreen mount.
///
/// Phase 3 (D-05): [TraevyApp] is a [ConsumerWidget] so it can call
/// `ref.watch(directionBackfillProvider)` to trigger the one-shot
/// background backfill on app startup.
class TraevyApp extends ConsumerWidget {
  /// Create the root app widget.
  const TraevyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Consume the backfill provider so it fires exactly once at startup.
    // Riverpod keepAlive ensures it does not re-run on rebuild (Pitfall 5).
    ref.watch(directionBackfillProvider);

    // D-04: watch user preferences for instant dark mode switching.
    // Falls back to ThemeMode.system while the stream initialises or
    // if the DB is unavailable.
    final themeMode = ref
        .watch(userPreferenceProvider)
        .when(
          data: (prefs) => _toThemeMode(prefs.darkMode),
          loading: () => ThemeMode.system,
          error: (e, s) => ThemeMode.system,
        );

    return MaterialApp(
      title: 'Traevy',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routes: kAppRoutes,
      home: const MainShell(),
    );
  }

  /// Map a [darkMode] string literal to Flutter's [ThemeMode].
  ///
  /// Returns [ThemeMode.system] for unknown or null-equivalent values.
  ThemeMode _toThemeMode(String darkMode) {
    switch (darkMode) {
      case kDarkModeLight:
        return ThemeMode.light;
      case kDarkModeDark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
