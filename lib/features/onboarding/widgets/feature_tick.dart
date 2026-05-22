import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// A single feature row on the onboarding screen: a 28dp `movingBg`
/// circle with a check icon, followed by a title + subtitle text column.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §9 Onboarding.
class FeatureTick extends StatelessWidget {
  /// Creates a [FeatureTick] with [title] and [subtitle].
  const FeatureTick({
    required this.title,
    required this.subtitle,
    super.key,
  });

  /// Primary heading (Inter 14sp w600).
  final String title;

  /// Secondary helper text (Inter 12sp dim).
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: tokens.movingBg,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(Icons.check_rounded, size: 16, color: tokens.moving),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TraevyFonts.ui(
                  size: 14,
                  weight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TraevyFonts.ui(size: 12, color: tokens.textDim),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
