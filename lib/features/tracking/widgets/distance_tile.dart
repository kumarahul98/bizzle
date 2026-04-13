import 'package:flutter/material.dart';

/// Live distance tile shown on the tracking screen (D-12).
///
/// Renders a Material 3 [Card] with a `Distance` label above a large
/// display value. Values under 1 km are rendered as whole meters
/// (`XXX m`); values at or above 1 km are rendered as kilometers with
/// two decimal places (`X.XX km`). The tile is stateless — the parent
/// passes [distanceMeters] on every rebuild of `trackingStateProvider`.
class DistanceTile extends StatelessWidget {
  /// Create a new tile displaying [distanceMeters].
  const DistanceTile({required this.distanceMeters, super.key});

  /// Running trip distance in meters. Negative values are clamped to zero.
  final double distanceMeters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Distance', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              _formatDistance(distanceMeters),
              style: theme.textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Format [meters] as `X.XX km` (>= 1000) or `XXX m` (< 1000).
///
/// Private to this file to keep the build method small. Negative inputs
/// are clamped to zero so `TrackingActive` fixture variants in widget
/// tests can't accidentally push `-0.0` into the UI layer.
String _formatDistance(double meters) {
  final safe = meters < 0 ? 0.0 : meters;
  if (safe >= 1000) {
    final km = safe / 1000;
    return '${km.toStringAsFixed(2)} km';
  }
  return '${safe.round()} m';
}
