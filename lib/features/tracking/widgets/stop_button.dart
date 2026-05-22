import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// Full-width Stop and save trip button for the active recording screen
/// (Variant A). Uses a text-background / bg-text color scheme per spec.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §4 Active Recording.
class StopButton extends StatelessWidget {
  /// Creates a [StopButton] with the given [onPressed] callback.
  const StopButton({required this.onPressed, super.key});

  /// Callback invoked when the button is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // bg token maps to scaffoldBackgroundColor in buildLightTheme/buildDarkTheme.
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: onSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.stop_rounded, size: 22, color: bgColor),
            const SizedBox(width: 12),
            Text(
              'Stop and save trip',
              style: TraevyFonts.ui(
                size: 15,
                weight: FontWeight.w600,
                color: bgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
