import 'package:flutter/material.dart';
import 'package:traevy/shared/widgets/stat_mini_card.dart';

/// Live speed tile shown on the active tracking screen (Variant A).
///
/// Thin adapter over [StatMiniCard] — preserves the public `speedKmh`
/// constructor so existing widget-test `find.byType(CurrentSpeedTile)` calls
/// continue to resolve. Tone switches to `moving` when speed ≥ 10 km/h,
/// otherwise `stuck`.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §4 Active Recording.
class CurrentSpeedTile extends StatelessWidget {
  /// Creates a [CurrentSpeedTile] displaying [speedKmh].
  const CurrentSpeedTile({required this.speedKmh, super.key});

  /// Current speed in kilometers per hour.
  final double speedKmh;

  @override
  Widget build(BuildContext context) {
    final tone = speedKmh >= 10
        ? StatMiniCardTone.moving
        : StatMiniCardTone.stuck;
    return StatMiniCard(
      label: 'SPEED',
      value: _formatSpeed(speedKmh),
      unit: 'km/h',
      tone: tone,
    );
  }
}

/// Format [kmh] as `X` (integer, rounded). Sub-0.5 values render as `0`
/// to avoid the `-0` edge case from floating-point residuals.
String _formatSpeed(double kmh) {
  if (kmh < 0.5) return '0';
  return '${kmh.round()}';
}
