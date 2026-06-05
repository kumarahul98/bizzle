import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/screens/splash_screen.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/shell/main_shell.dart';
import 'package:traevy/features/tracking/providers/backfill_provider.dart';
import 'package:traevy/features/tracking/services/live_activity_service.dart';
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
/// Firebase session restore; [AuthGuest] and [AuthSignedIn] both show
/// [MainShell]. The switch has no `default` branch so a new [AuthState]
/// variant is a compile error at this call site (T-09-04-02 mitigation).
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

    // IOS-10 contextual notification permission hook (D-07).
    //
    // Fire-and-forget in a post-frame callback so the first frame is never
    // blocked. App-launch cadence (every build at root) is sufficient for the
    // 7-day anchor check — the method itself guards against re-asking via the
    // one-time sentinel file.
    //
    // The shared AppDatabase instance is passed explicitly so
    // _isUsageAnchorMet never constructs a raw AppDatabase() — which would
    // trigger the Drift "multiple database instances" warning (IOS-10 fix).
    //
    // Uses ref.read (not watch) — the service is a stable Provider that never
    // changes; watching it would rebuild the entire app on provider
    // invalidation (unnecessary). The unawaited future is intentional —
    // errors are caught inside maybeRequestNotificationPermissionForUsage.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(notificationServiceProvider)
            .maybeRequestNotificationPermissionForUsage(
              db: ref.read(appDatabaseProvider),
            )
            .catchError((Object _) {}),
      );
    });

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
      // TEMP la-diag UI — remove after diagnosis
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          const _LaDiagBanner(),
        ],
      ),
      // END TEMP la-diag UI
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

// TEMP la-diag UI — remove after diagnosis
/// Translucent always-visible banner at the top of every screen showing
/// the current Live Activity diagnostic state. Works in release builds
/// (reads [liveActivityDiag] ValueNotifier, no dependency on debugPrint).
/// Ignores pointer events so it never blocks taps.
class _LaDiagBanner extends StatelessWidget {
  const _LaDiagBanner();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: SafeArea(
          bottom: false,
          child: ValueListenableBuilder<String>(
            valueListenable: liveActivityDiag,
            builder: (context, value, _) => Container(
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.85),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFFFE000),
                  fontSize: 10,
                  fontFamily: 'monospace',
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.normal,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// END TEMP la-diag UI
