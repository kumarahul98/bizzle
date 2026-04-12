import 'package:flutter/material.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/config/theme.dart';

/// Root widget for the Traevy app.
///
/// Owns the `MaterialApp` wiring (title, light/dark themes, named routes,
/// and the home screen). Phase 1 mounts only a minimal placeholder home —
/// real feature screens land in phases 2+.
class TraevyApp extends StatelessWidget {
  const TraevyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traevy',
      theme: lightTheme,
      darkTheme: darkTheme,
      // Explicit even though it matches the MaterialApp default —
      // plan 01-02 locks the theme-mode contract so future phases
      // cannot silently change it.
      // ignore: avoid_redundant_argument_values
      themeMode: ThemeMode.system,
      // Explicit even though the map is empty today — reserves the
      // symbol kAppRoutes for phases 4+ to populate.
      // ignore: avoid_redundant_argument_values
      routes: kAppRoutes,
      home: const PlaceholderHome(),
    );
  }
}

/// Minimal Phase 1 home screen.
///
/// Exists so the app has *something* to render while the foundation
/// phase is being built out. Plan 04's widget smoke test pumps this
/// widget to prove Riverpod + MaterialApp wiring resolves correctly.
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traevy')),
      body: const Center(
        child: Text('Traevy Phase 1'),
      ),
    );
  }
}
