import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/shared/utils/formatters.dart';

/// Card shown at the top of today's trip list when GPS tracking is active.
///
/// Displays elapsed time and distance from [active]. Inert in 08-08:
/// HeroRecordCard above shows the active recording UI in place, so there
/// is no separate tracking screen to navigate to. The timelapse icon and
/// 4 px primary-color left-border stripe communicate the active state
/// without relying on color alone (WCAG 1.4.1).
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
    final distanceKm = (active.distanceMeters / 1000).toStringAsFixed(1);
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;

    return Semantics(
      label: 'Commute in progress, elapsed: $elapsed',
      child: Card(
        // Pitfall 9: use tokens.bgElev instead of surfaceContainerLow.
        color: tokens.bgElev,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.primary, width: 4),
          // Pitfall 4: radius updated from 12 to 16.
          borderRadius: BorderRadius.circular(16),
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
    );
  }
}
