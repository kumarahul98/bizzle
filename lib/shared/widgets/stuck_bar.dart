import 'package:flutter/material.dart';
import 'package:traevy/config/theme_extension.dart';

/// Proportional moving/stuck horizontal progress bar.
///
/// Renders two color segments — left (moving, green) and right (stuck,
/// amber) — sized by SECONDS, not minutes, so the proportions are exact and
/// a sub-minute stuck stretch still paints a visible sliver (Quick
/// 260801-oux). There is deliberately NO minimum-width floor on a segment —
/// fudging the width would misreport the proportion, which is the one thing
/// this bar exists to show honestly. When both values are zero, renders a
/// full-width track in `surface2`.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §10 StuckBar contract.
class StuckBar extends StatelessWidget {
  /// Creates a [StuckBar].
  ///
  /// [movingSeconds] and [stuckSeconds] control the proportional fill.
  /// [height] sets the bar height in logical pixels (default 14).
  const StuckBar({
    required this.movingSeconds,
    required this.stuckSeconds,
    this.height = 14,
    super.key,
  });

  /// Seconds spent moving (speed >= 10 km/h). Determines left segment width.
  final int movingSeconds;

  /// Seconds spent stuck in traffic (speed < 10 km/h). Determines right
  /// segment width.
  final int stuckSeconds;

  /// Bar height in logical pixels. Defaults to 14.
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    // Defensive clamp — Expanded.flex asserts non-negative, and the
    // week-card call site derives moving by subtraction rather than reading
    // a trusted stored value.
    final moving = movingSeconds < 0 ? 0 : movingSeconds;
    final stuck = stuckSeconds < 0 ? 0 : stuckSeconds;
    final total = moving + stuck;

    if (total == 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: ColoredBox(
          color: tokens.surface2,
          child: SizedBox(height: height, width: double.infinity),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        color: tokens.surface2,
        height: height,
        child: Row(
          children: [
            Expanded(
              flex: moving,
              child: ColoredBox(color: tokens.moving),
            ),
            Expanded(
              flex: stuck,
              child: ColoredBox(color: tokens.stuck),
            ),
          ],
        ),
      ),
    );
  }
}
