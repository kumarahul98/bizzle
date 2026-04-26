import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';
import 'package:traevy/shared/utils/formatters.dart';

const double _kRowGap = 12;

/// STAT-02 card: average commute duration for to-office and to-home
/// trips, computed across every trip ever recorded.
///
/// Both averages are nullable (D-10): when no trip has been recorded
/// for a given direction, the value renders as
/// [kStatsEmptyPlaceholder].
class DirectionAveragesCard extends StatelessWidget {
  /// Construct the card from already-computed averages.
  const DirectionAveragesCard({
    required this.toOfficeAvgSeconds,
    required this.toHomeAvgSeconds,
    super.key,
  });

  /// Average duration in seconds for to-office trips, or `null` when
  /// no such trips exist.
  final int? toOfficeAvgSeconds;

  /// Average duration in seconds for to-home trips, or `null` when
  /// no such trips exist.
  final int? toHomeAvgSeconds;

  @override
  Widget build(BuildContext context) {
    return StatsCard(
      title: kStatsCardDirectionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DirectionRow(
            label: kStatsCardToOfficeLabel,
            valueSeconds: toOfficeAvgSeconds,
          ),
          const SizedBox(height: _kRowGap),
          _DirectionRow(
            label: kStatsCardToHomeLabel,
            valueSeconds: toHomeAvgSeconds,
          ),
        ],
      ),
    );
  }
}

class _DirectionRow extends StatelessWidget {
  const _DirectionRow({
    required this.label,
    required this.valueSeconds,
  });

  final String label;
  final int? valueSeconds;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final value = valueSeconds == null
        ? kStatsEmptyPlaceholder
        : formatDuration(valueSeconds!);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
