import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';
import 'package:traevy/shared/utils/formatters.dart';

const double _kRowGap = 8;
const double _kHelperGap = 4;

/// STAT-01 card: weekly (Mon–Sun) and monthly totals.
///
/// Empty week or month renders as [kStatsEmptyPlaceholder] (D-10).
/// `0` is treated as "no trips this week/month" because every
/// recorded trip has positive duration (D-10 + Phase 2 minimum-trip
/// length).
class WeekMonthTotalsCard extends StatelessWidget {
  /// Construct the card from already-computed totals.
  const WeekMonthTotalsCard({
    required this.weekTotalSeconds,
    required this.monthTotalSeconds,
    super.key,
  });

  /// Total commute seconds for the current Mon–Sun week.
  final int weekTotalSeconds;

  /// Total commute seconds for the current calendar month.
  final int monthTotalSeconds;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final weekValue = weekTotalSeconds == 0
        ? kStatsEmptyPlaceholder
        : formatDuration(weekTotalSeconds);
    final monthValue = monthTotalSeconds == 0
        ? kStatsEmptyPlaceholder
        : formatDuration(monthTotalSeconds);
    return StatsCard(
      title: kStatsCardWeekLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            weekValue,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: _kHelperGap),
          Text(
            kStatsCardWeekHelper,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: _kRowGap),
          Text(
            kStatsCardMonthLabel,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: _kHelperGap),
          Text(
            monthValue,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
