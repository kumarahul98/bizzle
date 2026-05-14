import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// Color tint applied to the [StatMiniCard] value text.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §4 Active Recording.
enum StatMiniCardTone {
  /// Value in default `onSurface` color.
  neutral,

  /// Value in `moving` token color (green).
  moving,

  /// Value in `stuck` token color (amber).
  stuck,
}

/// Compact metric card: label (Inter 10.5sp) + value (Mono 22sp) + unit.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §4 Active Recording.
class StatMiniCard extends StatelessWidget {
  const StatMiniCard({
    required this.label,
    required this.value,
    this.unit,
    this.tone = StatMiniCardTone.neutral,
    super.key,
  });

  final String label;
  final String value;
  final String? unit;
  final StatMiniCardTone tone;

  Color _toneColor(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return switch (tone) {
      StatMiniCardTone.neutral => Theme.of(context).colorScheme.onSurface,
      StatMiniCardTone.moving => tokens.moving,
      StatMiniCardTone.stuck => tokens.stuck,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final valueColor = _toneColor(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.bgElev,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TraevyFonts.ui(
              size: 10.5,
              weight: FontWeight.w600,
              color: tokens.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TraevyFonts.mono(
                  size: 22,
                  weight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: TraevyFonts.mono(
                    size: 11,
                    weight: FontWeight.w500,
                    color: tokens.textDim,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
