import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/services/stats_period.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';

const double _kChartHeight = 100;
const double _kBottomTitlesSize = 20;

/// Period-aware trend chart (Phase 34, Q6 overrule).
///
/// Bars come straight from `statsSummaryProvider.periodTrendBars`, already
/// bucketed per period: 7 daily bars for the week, one per calendar week for
/// the month, 12 monthly bars for the year. The bucket containing today is
/// the accent bar; the tallest non-zero bucket is the stuck (worst) bar.
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
        final bars = stats.periodTrendBars;
        final minutes = <int>[
          for (final bar in bars) bar.seconds ~/ 60,
        ];
        final title = switch (stats.period) {
          WeekPeriod() => kStatsTrendDailyTitle,
          MonthPeriod() => kStatsTrendWeeklyTitle,
          YearPeriod() => kStatsTrendMonthlyTitle,
        };

        // Worst bucket = tallest bar; current bucket carries its own flag.
        var worstIdx = 0;
        for (var i = 1; i < minutes.length; i++) {
          if (minutes[i] > minutes[worstIdx]) worstIdx = i;
        }
        final maxY = minutes.isEmpty
            ? 0.0
            : minutes.reduce((a, b) => a > b ? a : b).toDouble();
        // Fewer bars → wider bars.
        final barWidth = bars.length <= 8 ? 16.0 : 8.0;

        final barGroups = <BarChartGroupData>[
          for (var i = 0; i < bars.length; i++)
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: minutes[i].toDouble(),
                  color: bars[i].isCurrent
                      ? tokens.accent
                      : (i == worstIdx && minutes[i] > 0)
                      ? tokens.stuck
                      : tokens.borderStr,
                  width: barWidth,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ],
            ),
        ];

        return StatsCard(
          title: title,
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
                        if (i < 0 || i >= bars.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            bars[i].label,
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
        title: kStatsTrendDailyTitle,
        child: SizedBox(height: _kChartHeight),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}
