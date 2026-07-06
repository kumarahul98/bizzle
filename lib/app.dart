import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/screens/login_screen.dart';
import 'package:traevy/features/auth/screens/splash_screen.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/shell/main_shell.dart';
import 'package:traevy/features/tracking/providers/backfill_provider.dart';
import 'package:traevy/sync/sync_engine.dart';

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
/// Firebase session restore; [AuthSignedIn] shows [MainShell]. The switch has
/// no `default` branch so a new [AuthState] variant is a compile error at this
/// call site (T-09-04-02 mitigation).
///
/// Phase 20 (AUTH-04, D-03): the [AuthGuest] arm now composes the persisted
/// `has_seen_onboarding` flag from [userPreferenceProvider] WITHOUT a flash —
/// while prefs load it shows [SplashScreen] (not a flicker between screens),
/// on error it degrades to [MainShell] (never traps a user behind the wall),
/// and on data it routes `seen ? MainShell : LoginScreen`. The [AuthState]
/// switch stays exhaustive with no `default` branch.
class TraevyApp extends ConsumerWidget {
  /// Create the root app widget.
  const TraevyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      // Consume the backfill provider so it fires exactly once at startup.
      // Riverpod keepAlive ensures it does not re-run on rebuild (Pitfall 5).
      ..watch(directionBackfillProvider)
      // Phase 11 (SYNC-02): eager-mount the sync engine so its triggers
      // (post-save, connectivity-restored, app-resume) attach for the full app
      // session. Watching CONSTRUCTS the provider at app root, which runs
      // engine.start() and makes the watchPending() subscription live before
      // the first trip save (M1). keepAlive provider — reading it does NOT
      // block the UI build; all processing is async / fire-and-forget.
      ..watch(syncEngineProvider);

    // D-04: watch user preferences for instant dark mode switching AND the
    // Phase 20 first-run gate. Resolved once as an AsyncValue and reused for
    // both the theme and the gate below.
    final prefsAsync = ref.watch(userPreferenceProvider);
    final themeMode = prefsAsync.when(
      data: (prefs) => _toThemeMode(prefs.darkMode),
      loading: () => ThemeMode.system,
      error: (e, s) => ThemeMode.system,
    );

    // Auth gate — sealed switch on AuthState (NOT .when, which is the
    // AsyncValue API). AuthState is a plain sealed class from a
    // NotifierProvider, not an AsyncValue (RESEARCH Pitfall 6 / A5). The
    // AuthGuest arm composes the prefs AsyncValue (D-03 no-flash gate); the
    // switch stays exhaustive with no `default` branch.
    final auth = ref.watch(authStateProvider);
    final home = switch (auth) {
      AuthLoading() => const SplashScreen(),
      AuthSignedIn() => const MainShell(),
      AuthGuest() => prefsAsync.when(
        // No flash: show the splash while prefs load instead of flickering
        // the login screen.
        loading: () => const SplashScreen(),
        // Degrade: a prefs read failure must never trap a user behind the
        // wall (T-20-03) — fall through to the app.
        error: (_, _) => const MainShell(),
        data: (prefs) =>
            prefs.hasSeenOnboarding ? const MainShell() : const LoginScreen(),
      ),
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
