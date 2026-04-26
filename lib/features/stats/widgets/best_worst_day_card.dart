import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';
import 'package:traevy/shared/utils/formatters.dart';

const double _kChipSpacing = 8;
const double _kIconChipGap = 4;

/// STAT-03 card: five chips (Mon–Fri) coloured by best/worst commute day.
///
/// Best = weekday with the lowest non-null average; worst = highest.
/// When fewer than two weekdays have data no chip is highlighted.
/// When exactly one weekday has data it renders as best only (tie-break).
class BestWorstDayCard extends StatelessWidget {
  const BestWorstDayCard({
    required this.weekdayAverages,
    super.key,
  });

  /// Average duration in seconds per weekday indexed by
  /// `DateTime.weekday - 1` (0 = Mon … 6 = Sun). Indices 5–6 always null.
  final List<int?> weekdayAverages;

  @override
  Widget build(BuildContext context) {
    // Anchor dates: 2024-01-01 is a Monday — adding 0..4 gives Mon..Fri.
    // Locale pinned to en_US per UI-SPEC §Copywriting Contract.
    final fmt = DateFormat.E('en_US');
    final labels = List<String>.generate(
      5,
      (i) => fmt.format(DateTime(2024, 1, 1 + i)),
    );

    // Determine best (lowest) and worst (highest) among Mon–Fri (0..4).
    int? bestIdx;
    int? worstIdx;
    var bestAvg = 1 << 30;
    var worstAvg = -1;
    for (var i = 0; i < 5; i++) {
      final avg = weekdayAverages[i];
      if (avg == null) continue;
      if (avg < bestAvg) {
        bestAvg = avg;
        bestIdx = i;
      }
      if (avg > worstAvg) {
        worstAvg = avg;
        worstIdx = i;
      }
    }
    // Single-weekday case: drop worstIdx so chip renders only as best.
    if (bestIdx != null && bestIdx == worstIdx) {
      worstIdx = null;
    }

    return StatsCard(
      title: kStatsCardBestWorstTitle,
      child: Wrap(
        spacing: _kChipSpacing,
        runSpacing: _kChipSpacing,
        children: <Widget>[
          for (var i = 0; i < 5; i++)
            _DayChip(
              label: labels[i],
              avgSeconds: weekdayAverages[i],
              isBest: i == bestIdx,
              isWorst: i == worstIdx,
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.avgSeconds,
    required this.isBest,
    required this.isWorst,
  });

  final String label;
  final int? avgSeconds;
  final bool isBest;
  final bool isWorst;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color? bg;
    Color? fg;
    IconData? icon;
    String? semanticPrefix;
    if (isBest) {
      bg = colorScheme.primaryContainer;
      fg = colorScheme.onPrimaryContainer;
      icon = Icons.trending_down_rounded;
      semanticPrefix = kStatsCardBestLabel;
    } else if (isWorst) {
      bg = colorScheme.errorContainer;
      fg = colorScheme.onErrorContainer;
      icon = Icons.trending_up_rounded;
      semanticPrefix = kStatsCardWorstLabel;
    }

    final semanticDuration = avgSeconds == null
        ? kStatsEmptyPlaceholder
        : formatDuration(avgSeconds!);
    final semanticLabel = semanticPrefix == null
        ? '$label, average $semanticDuration'
        : '$semanticPrefix commute day: $label, average $semanticDuration';

    return Semantics(
      label: semanticLabel,
      container: true,
      child: Chip(
        backgroundColor: bg,
        visualDensity: VisualDensity.standard,
        avatar: icon == null
            ? null
            : Icon(icon, size: 16, color: fg ?? colorScheme.onSurfaceVariant),
        label: Padding(
          padding: const EdgeInsets.only(left: _kIconChipGap),
          child: Text(
            label,
            style: textTheme.labelMedium?.copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}
