import 'package:flutter/material.dart';
import 'package:traevy/features/tracking/widgets/current_speed_tile.dart';
import 'package:traevy/features/tracking/widgets/distance_tile.dart';
import 'package:traevy/features/tracking/widgets/duration_tile.dart';

/// Horizontal row of three live metric tiles: Distance, Speed, Stuck.
///
/// Restyled for Variant A — tiles are StatMiniCard adapters displayed
/// side-by-side with [Expanded] children separated by 12dp gaps.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §4 Active Recording.
class TrackingTilesRow extends StatelessWidget {
  /// Creates a [TrackingTilesRow] with the given live values.
  const TrackingTilesRow({
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.currentSpeedKmh,
    this.timeStuckSeconds = 0,
    super.key,
  });

  /// Whole seconds of elapsed time (passed to [DurationTile] for stuck time).
  final int elapsedSeconds;

  /// Running distance in meters.
  final double distanceMeters;

  /// Current speed in km/h.
  final double currentSpeedKmh;

  /// Running stuck-in-traffic seconds. Defaults to 0 for idle/zero state.
  final int timeStuckSeconds;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: DistanceTile(distanceMeters: distanceMeters)),
          const SizedBox(width: 12),
          Expanded(child: CurrentSpeedTile(speedKmh: currentSpeedKmh)),
          const SizedBox(width: 12),
          Expanded(child: DurationTile(elapsedSeconds: timeStuckSeconds)),
        ],
      ),
    );
  }
}
