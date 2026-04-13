import 'package:flutter/material.dart';
import 'package:traevy/features/tracking/widgets/tracking_tiles_row.dart';

/// Active-state body for the tracking screen: three live tiles stacked
/// above a big Stop button.
///
/// Extracted from `tracking_screen.dart` so the screen file stays under
/// the 100-line CLAUDE.md widget cap. The parent passes the live values
/// from the `TrackingActive` sealed-class variant after destructuring.
class TrackingActiveLayout extends StatelessWidget {
  /// Create the active layout with current live values.
  const TrackingActiveLayout({
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.currentSpeedKmh,
    required this.onStop,
    super.key,
  });

  /// Current elapsed time in whole seconds.
  final int elapsedSeconds;

  /// Current trip distance in meters.
  final double distanceMeters;

  /// Current speed in km/h.
  final double currentSpeedKmh;

  /// Handler invoked when the user taps the Stop button.
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          TrackingTilesRow(
            elapsedSeconds: elapsedSeconds,
            distanceMeters: distanceMeters,
            currentSpeedKmh: currentSpeedKmh,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}
