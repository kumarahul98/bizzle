import 'package:flutter/material.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/tracking/screens/home_screen.dart';

/// Root widget for the Traevy app.
///
/// Owns the `MaterialApp` wiring (title, light/dark themes, named
/// routes, and the home screen). Phase 2 mounts [HomeScreen] as the
/// root — the minimal Start commute CTA per D-13.
class TraevyApp extends StatelessWidget {
  /// Create the root app widget.
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
      routes: kAppRoutes,
      home: const HomeScreen(),
    );
  }
}
