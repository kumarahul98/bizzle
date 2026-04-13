import 'package:flutter/material.dart';
import 'package:traevy/features/tracking/widgets/tracking_tiles_row.dart';

/// Idle-state body for the tracking screen: three zero-valued tiles
/// stacked above a `Start` button.
///
/// Extracted from `tracking_screen.dart` so the screen file stays under
/// the 100-line CLAUDE.md widget cap. The parent wires [onStart] to the
/// `trackingStateProvider.notifier.start()` call.
class TrackingIdleLayout extends StatelessWidget {
  /// Create the idle layout.
  const TrackingIdleLayout({required this.onStart, super.key});

  /// Handler invoked when the user taps the Start button.
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          const TrackingTilesRow(
            elapsedSeconds: 0,
            distanceMeters: 0,
            currentSpeedKmh: 0,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
