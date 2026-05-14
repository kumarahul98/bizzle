import 'package:flutter/material.dart';
import 'package:traevy/config/theme_extension.dart';

/// Proportional moving/stuck horizontal progress bar.
///
/// Renders two color segments — left (moving, green) and right (stuck, amber) —
/// sized by their respective minute counts. When both values are zero, renders
/// a full-width track in `surface2`.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §10 StuckBar contract.
class StuckBar extends StatelessWidget {
  /// Creates a [StuckBar].
  ///
  /// [movingMinutes] and [stuckMinutes] control the proportional fill.
  /// [height] sets the bar height in logical pixels (default 14).
  const StuckBar({
    required this.movingMinutes,
    required this.stuckMinutes,
    this.height = 14,
    super.key,
  });

  /// Minutes spent moving (speed >= 10 km/h). Determines left segment width.
  final int movingMinutes;

  /// Minutes spent stuck in traffic (speed < 10 km/h). Determines right
  /// segment width.
  final int stuckMinutes;

  /// Bar height in logical pixels. Defaults to 14.
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final total = movingMinutes + stuckMinutes;

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
              flex: movingMinutes,
              child: ColoredBox(color: tokens.moving),
            ),
            Expanded(
              flex: stuckMinutes,
              child: ColoredBox(color: tokens.stuck),
            ),
          ],
        ),
      ),
    );
  }
}
