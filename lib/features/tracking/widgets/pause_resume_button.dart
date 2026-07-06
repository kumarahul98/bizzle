import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';

/// Pause / Resume toggle for the active recording hero (Phase 18, D-09).
///
/// A pure stateless toggle: its label and icon are driven entirely by
/// [isPaused] — there is no local state. While running it reads
/// [kTrackingPauseLabel] with a pause glyph; while paused it reads
/// [kTrackingResumeLabel] with a play glyph. A tap fires [onPressed].
///
/// Styled as an outlined sibling to the StopButton so the two read as one
/// control row — Stop is the filled primary action, Pause/Resume the
/// secondary outline.
class PauseResumeButton extends StatelessWidget {
  /// Creates a [PauseResumeButton].
  const PauseResumeButton({
    required this.isPaused,
    required this.onPressed,
    super.key,
  });

  /// Whether the trip is currently paused. Drives label + icon.
  final bool isPaused;

  /// Callback invoked when the button is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final label = isPaused ? kTrackingResumeLabel : kTrackingPauseLabel;
    final icon = isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: tokens.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 22, color: onSurface),
            const SizedBox(width: 12),
            Text(
              label,
              style: TraevyFonts.ui(
                size: 15,
                weight: FontWeight.w600,
                color: onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
