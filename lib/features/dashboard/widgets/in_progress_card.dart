import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/shared/utils/formatters.dart';

/// Card shown at the top of today's trip list when GPS tracking is active.
///
/// Displays elapsed time and distance from [active] and navigates to the
/// tracking screen on tap. The timelapse icon and 4 px primary-color
/// left-border stripe communicate the active state without relying on
/// color alone (WCAG 1.4.1).
class InProgressCard extends StatelessWidget {
  /// Create the in-progress commute card.
  const InProgressCard({required this.active, super.key});

  /// The live tracking state supplying elapsed time and distance.
  final TrackingActive active;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final elapsed = formatDuration(active.elapsedSeconds);
    final distanceKm =
        (active.distanceMeters / 1000).toStringAsFixed(1);

    return Semantics(
      label: 'Commute in progress, elapsed: $elapsed',
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(kRouteTracking),
        borderRadius: BorderRadius.circular(12),
        child: Card(
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colorScheme.primary, width: 4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Icon(Icons.timelapse, color: colorScheme.primary),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      kDashboardInProgressLabel,
                      style: textTheme.titleMedium,
                    ),
                    Text(
                      elapsed,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$distanceKm km',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
