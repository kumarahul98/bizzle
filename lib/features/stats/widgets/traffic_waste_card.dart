import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';
import 'package:traevy/shared/utils/formatters.dart';

const double _kHelperGap = 4;

/// STAT-05 card: total seconds the user was stuck in traffic this
/// week (Mon–Sun). Manually-entered trips are excluded from this
/// number upstream by `computeStatsSummary` (D-05).
class TrafficWasteCard extends StatelessWidget {
  /// Construct the card from already-computed weekly traffic seconds.
  const TrafficWasteCard({
    required this.weekStuckSeconds,
    super.key,
  });

  /// Sum of `timeStuckSeconds` for non-manual trips in the current
  /// Mon–Sun week.
  final int weekStuckSeconds;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final value = weekStuckSeconds == 0
        ? kStatsEmptyPlaceholder
        : formatDuration(weekStuckSeconds);
    return StatsCard(
      title: kStatsCardTrafficTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: _kHelperGap),
          Text(
            kStatsCardTrafficHelper,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
