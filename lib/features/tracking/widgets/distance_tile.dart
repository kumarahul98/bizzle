import 'package:flutter/material.dart';
import 'package:traevy/shared/widgets/stat_mini_card.dart';

/// Live distance tile shown on the active tracking screen (Variant A).
///
/// Thin adapter over [StatMiniCard] — preserves the public `distanceMeters`
/// constructor so existing widget-test `find.byType(DistanceTile)` calls
/// continue to resolve.
class DistanceTile extends StatelessWidget {
  /// Creates a [DistanceTile] displaying [distanceMeters].
  const DistanceTile({required this.distanceMeters, super.key});

  /// Running trip distance in meters. Negative values are clamped to zero.
  final double distanceMeters;

  @override
  Widget build(BuildContext context) {
    final (value, unit) = _formatDistance(distanceMeters);
    return StatMiniCard(
      label: 'DISTANCE',
      value: value,
      unit: unit,
    );
  }
}

/// Returns (value string, unit string) for [meters].
///
/// Values >= 1000 m render as `X.X km`; values < 1000 m render as `XXX m`.
(String, String) _formatDistance(double meters) {
  final safe = meters < 0 ? 0.0 : meters;
  if (safe >= 1000) {
    return ((safe / 1000).toStringAsFixed(2), 'km');
  }
  return ('${safe.round()}', 'm');
}
