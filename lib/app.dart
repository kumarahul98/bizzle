import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/screens/splash_screen.dart';
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
///
/// Phase 9 (AUTH-02, AUTH-03): watches [authStateProvider] and routes via an
/// exhaustive sealed `switch` — [AuthLoading] shows [SplashScreen] during
/// Firebase session restore; [AuthGuest] and [AuthSignedIn] both show
/// [MainShell]. The switch has no `default` branch so a new [AuthState]
/// variant is a compile error at this call site (T-09-04-02 mitigation).
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

    // Phase 9 auth gate — sealed switch on AuthState (NOT .when, which is
    // the AsyncValue API). AuthState is a plain sealed class from a
    // NotifierProvider, not an AsyncValue (RESEARCH Pitfall 6 / A5).
    final auth = ref.watch(authStateProvider);
    final home = switch (auth) {
      AuthLoading() => const SplashScreen(),
      AuthGuest() => const MainShell(),
      AuthSignedIn() => const MainShell(),
    };

    return MaterialApp(
      title: 'Traevy',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routes: kAppRoutes,
      home: home,
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
