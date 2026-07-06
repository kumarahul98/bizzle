import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';

/// Small "PAUSED" badge shown on the hero while a trip is paused (Phase 18,
/// D-09). Part of the distinct paused visual treatment alongside the dimmed,
/// frozen elapsed display. Driven purely by the snapshot's `isPaused` — the
/// hero renders this only when paused.
class PausedBadge extends StatelessWidget {
  /// Creates a [PausedBadge].
  const PausedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        kTrackingPausedBadgeLabel,
        style: TraevyFonts.ui(
          size: 11,
          weight: FontWeight.w700,
          letterSpacing: 1.5,
          color: tokens.textDim,
        ),
      ),
    );
  }
}

/// Break-count indicator for the hero (Phase 18, D-09). Renders "1 break" or
/// "{n} breaks" using the [kTrackingBreakCountSingularLabel] /
/// [kTrackingBreakCountPluralTemplate] constants. The hero shows this only
/// when [breakCount] is greater than zero.
class BreakCountChip extends StatelessWidget {
  /// Creates a [BreakCountChip] for [breakCount] completed breaks.
  const BreakCountChip({required this.breakCount, super.key});

  /// Number of completed break spans. Must be greater than zero — the hero
  /// guards rendering on this.
  final int breakCount;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final label = breakCount == 1
        ? kTrackingBreakCountSingularLabel
        : kTrackingBreakCountPluralTemplate.replaceFirst('{n}', '$breakCount');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.pause_circle_outline_rounded,
          size: 15,
          color: tokens.textDim,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TraevyFonts.ui(
            size: 12.5,
            weight: FontWeight.w600,
            color: tokens.textDim,
          ),
        ),
      ],
    );
  }
}
