import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';

const double _kBarWidth = 4;
const double _kChartHeight = 100;
const double _kBottomTitlesSize = 20;

/// 28-day bar chart of daily commute totals.
///
/// Data source: statsSummaryProvider — uses dailyTotalsLast28Days
/// (List of int seconds, index 0 = today) via TRIVIAL-LOCAL-COMPUTE
/// (divide by 60 for minutes). Bars are colored:
/// - Today (index 0): tokens.accent
/// - Worst day (max value): tokens.stuck
/// - All others: tokens.borderStr
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §7 Stats Screen.
class TrendBarsCard extends ConsumerWidget {
  /// Creates a [TrendBarsCard].
  const TrendBarsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textTheme = Theme.of(context).textTheme;

    final asyncStats = ref.watch(statsSummaryProvider);
    return asyncStats.when(
      data: (stats) {
        // dailyTotalsLast28Days[0] = today, [27] = 27 days ago.
        // Reverse so x=0 is oldest (left) and x=27 is today (right).
        final raw = stats.dailyTotalsLast28Days;
        final minutes = List<int>.generate(
          kStatsTrendWindowDays,
          (i) => raw[kStatsTrendWindowDays - 1 - i] ~/ 60,
        );

        // Worst day = highest bar.
        var worstIdx = 0;
        for (var i = 1; i < kStatsTrendWindowDays; i++) {
          if (minutes[i] > minutes[worstIdx]) worstIdx = i;
        }
        // Today is the last bar (index 27 in reversed list).
        const todayIdx = kStatsTrendWindowDays - 1;

        final maxY = minutes.reduce((a, b) => a > b ? a : b).toDouble();

        final barGroups = List<BarChartGroupData>.generate(
          kStatsTrendWindowDays,
          (i) {
            Color color;
            if (i == todayIdx) {
              color = tokens.accent;
            } else if (i == worstIdx && minutes[i] > 0) {
              color = tokens.stuck;
            } else {
              color = tokens.borderStr;
            }
            return BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: minutes[i].toDouble(),
                  color: color,
                  width: _kBarWidth,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ],
            );
          },
        );

        // Sparse x-axis labels: oldest date, mid, and today.
        final today = DateTime.now();
        final oldestDate = today.subtract(
          const Duration(days: kStatsTrendWindowDays - 1),
        );
        final midDate = today.subtract(
          const Duration(days: kStatsTrendWindowDays ~/ 2),
        );
        final fmt = DateFormat('MMM d');

        return StatsCard(
          title: '28-day trend',
          child: SizedBox(
            height: _kChartHeight,
            child: BarChart(
              BarChartData(
                maxY: maxY == 0 ? 10 : maxY * 1.2,
                minY: 0,
                barGroups: barGroups,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: const BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: _kBottomTitlesSize,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        String? label;
                        if (i == 0) label = fmt.format(oldestDate);
                        if (i == kStatsTrendWindowDays ~/ 2) {
                          label = fmt.format(midDate);
                        }
                        if (i == kStatsTrendWindowDays - 1) {
                          label = fmt.format(today);
                        }
                        if (label == null) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            label,
                            style: textTheme.labelSmall?.copyWith(
                              color: tokens.textDim,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const StatsCard(
        title: '28-day trend',
        child: SizedBox(height: _kChartHeight),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}
