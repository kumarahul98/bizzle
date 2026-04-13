import 'package:flutter/material.dart';

/// Live speed tile shown on the tracking screen (D-12).
///
/// Renders the latest accepted GPS sample's speed in kilometers per
/// hour as a whole number. Values under `0.5` km/h render as `0 km/h`
/// to avoid the `-0` display edge case that surfaces when the
/// accumulator is stationary but geolocator reports a sub-millimeter
/// negative residual.
///
/// The conversion from `Position.speed` (m/s) to km/h happens exactly
/// once, inside `trackingActiveFromSnapshotMap` — this tile only
/// renders the already-converted value.
class CurrentSpeedTile extends StatelessWidget {
  /// Create a new tile displaying [speedKmh].
  const CurrentSpeedTile({required this.speedKmh, super.key});

  /// Current speed in kilometers per hour.
  final double speedKmh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Speed', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              _formatSpeed(speedKmh),
              style: theme.textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Format [kmh] as `X km/h` (rounded). Sub-0.5 values render as `0 km/h`
/// to avoid the `-0` edge case from floating-point residuals while the
/// trip is stationary.
String _formatSpeed(double kmh) {
  if (kmh < 0.5) return '0 km/h';
  return '${kmh.round()} km/h';
}
