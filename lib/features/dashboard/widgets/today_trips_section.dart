import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/dashboard/widgets/in_progress_card.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/shared/widgets/trip_row_card.dart';

// Spacing constant — multiples of 4 per UI-SPEC.
const double _kSectionLabelGapBelow = 8;

/// Renders the "Today" section of the dashboard.
///
/// Shows the [InProgressCard] when tracking is active, a flat list of
/// [TripRowCard]s for completed trips, or an empty-state message when no
/// trips exist today and tracking is idle.
class TodayTripsSection extends StatelessWidget {
  /// Create the today trips section.
  const TodayTripsSection({
    required this.asyncToday,
    required this.trackingState,
    super.key,
  });

  /// Today's trips from the today's trips provider.
  final AsyncValue<List<TripSummary>> asyncToday;

  /// Current tracking state; drives [InProgressCard] visibility.
  final TrackingState trackingState;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = trackingState is TrackingActive;

    return asyncToday.when(
      data: (trips) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            kDashboardTodaySectionLabel,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: _kSectionLabelGapBelow),
          if (isActive)
            InProgressCard(active: trackingState as TrackingActive),
          if (trips.isEmpty && !isActive)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  kDashboardEmptyStateLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (int i = 0; i < trips.length; i++)
                  TripRowCard(
                    direction: trips[i].direction,
                    startTime: trips[i].startTime,
                    endTime: trips[i].endTime,
                    durationSeconds: trips[i].durationSeconds,
                    distanceMeters: trips[i].distanceMeters,
                    stuckSeconds: trips[i].timeStuckSeconds,
                    showDivider: i < trips.length - 1,
                  ),
              ],
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          kDashboardErrorMessage,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
