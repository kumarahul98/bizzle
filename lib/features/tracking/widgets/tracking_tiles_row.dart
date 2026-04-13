import 'package:flutter/material.dart';
import 'package:traevy/features/tracking/widgets/current_speed_tile.dart';
import 'package:traevy/features/tracking/widgets/distance_tile.dart';
import 'package:traevy/features/tracking/widgets/duration_tile.dart';

/// Vertical stack of the three live tracking tiles (duration, distance,
/// current speed) shown on the tracking screen body.
///
/// Extracted into its own widget so the tracking screen build method
/// stays short and the tile layout can be reused verbatim for both
/// the `idle` (zero-valued) and `active` (live-valued) states.
class TrackingTilesRow extends StatelessWidget {
  /// Create a new tiles row with the given values.
  const TrackingTilesRow({
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.currentSpeedKmh,
    super.key,
  });

  /// Whole seconds of elapsed time.
  final int elapsedSeconds;

  /// Running distance in meters.
  final double distanceMeters;

  /// Current speed in km/h (already converted from m/s at the isolate
  /// boundary by `trackingActiveFromSnapshotMap`).
  final double currentSpeedKmh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DurationTile(elapsedSeconds: elapsedSeconds),
        const SizedBox(height: 12),
        DistanceTile(distanceMeters: distanceMeters),
        const SizedBox(height: 12),
        CurrentSpeedTile(speedKmh: currentSpeedKmh),
      ],
    );
  }
}
