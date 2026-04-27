import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';
import 'package:traevy/shared/utils/formatters.dart';

// Spacing constants — multiples of 4 per UI-SPEC.
const double _kRowGap = 8;
const double _kHelperGap = 4;

/// Summary card displayed at the top of the dashboard showing this week's
/// commute totals and today's trip count.
///
/// Tapping the card navigates to the Stats screen ([kRouteStats]).
/// Receives pre-computed values from the parent — this widget never watches
/// providers directly, keeping it testable in isolation.
class WeeklySummaryCard extends StatelessWidget {
  /// Construct the weekly summary card from already-computed totals.
  const WeeklySummaryCard({
    required this.weekTotalSeconds,
    required this.weekStuckSeconds,
    required this.todayTripCount,
    super.key,
  });

  /// Total commute seconds Mon–Sun sourced from the stats summary provider.
  final int weekTotalSeconds;

  /// Stuck-in-traffic seconds this week sourced from the stats summary
  /// provider.
  final int weekStuckSeconds;

  /// Today's completed trip count sourced from the today's trips provider.
  final int todayTripCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final weekValue = weekTotalSeconds == 0
        ? kStatsEmptyPlaceholder
        : formatDuration(weekTotalSeconds);
    final trafficValue = weekStuckSeconds == 0
        ? kStatsEmptyPlaceholder
        : formatDuration(weekStuckSeconds);
    final countLabel = todayTripCount == 1
        ? kDashboardTripCountSingular
        : '$todayTripCount $kDashboardTripCountPlural';

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(kRouteStats),
      child: StatsCard(
        title: kDashboardWeeklySummaryTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              weekValue,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _kRowGap),
            Text(
              kDashboardInTrafficLabel,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: _kHelperGap),
            Text(
              trafficValue,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _kRowGap),
            Text(countLabel, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
