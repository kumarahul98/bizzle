import 'package:flutter/material.dart';
import 'package:traevy/shared/widgets/traevy_logo_mark.dart';

/// Static full-screen splash rendered while Firebase restores the auth
/// session (D-04, `AuthState.loading`).
///
/// Mounted inline from `app.dart`'s sealed-switch auth gate:
/// ```dart
/// AuthLoading() => const SplashScreen(),
/// ```
/// Not a named route — placed directly as `MaterialApp.home` for the
/// duration of the loading state, which is typically sub-second.
///
/// Design: full-screen container filled with the theme scaffold background
/// (which maps to the `bg` design token via `buildLightTheme` /
/// `buildDarkTheme` in `lib/config/theme.dart` — `scaffoldBackgroundColor`).
/// Centred `TraevyLogoMark` at default size 56. No AppBar, no spinner,
/// no text. The logo mark inverts automatically for light and dark modes
/// via `onSurface` / `scaffoldBackgroundColor` inside `TraevyLogoMark`.
///
/// See UI-SPEC §A and
/// `.planning/phases/09-authentication/09-PATTERNS.md`
/// (splash_screen.dart section).
class SplashScreen extends StatelessWidget {
  /// Create the static splash screen.
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const SizedBox.expand(
        child: Center(
          child: TraevyLogoMark(),
        ),
      ),
    );
  }
}
