import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';

const double _kPlotTopPadding = 24;
const double _kPlotBottomReservedSize = 28;
const double _kDotRadius = 2;

/// STAT-04 card: an fl_chart LineChart of total commute time per day
/// for the last 28 calendar days.
///
/// Data source: dailyTotalsLast28Days from StatsSummary, where
/// index 0 = today and index 27 = 27 days ago. This widget reverses
/// that order so the x-axis reads chronologically left-to-right
/// (oldest day on the left, today on the right).
///
/// X-axis: exactly 4 labels — "Week 1", "Week 2", "Week 3", "This
/// week" — at integer x positions 3, 10, 17, and 24 (week midpoints).
/// All other x positions return SizedBox.shrink so they take no
/// vertical space.
///
/// Y-axis: hidden. minY is pinned to 0 so a uniformly low data range
/// still renders against a flat baseline (Pitfall 5).
///
/// Interaction: disabled. Tap-to-reveal deferred to a future phase.
class TrendChartCard extends StatelessWidget {
  const TrendChartCard({
    required this.dailyTotalsLast28Days,
    super.key,
  });

  /// 28 entries of total seconds per calendar day, index 0 = today.
  final List<int> dailyTotalsLast28Days;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Reverse so x=0 is 27 days ago (left edge) and x=27 is today.
    // Convert seconds to minutes for a legible y scale.
    final spots = List<FlSpot>.generate(
      kStatsTrendWindowDays,
      (i) => FlSpot(
        i.toDouble(),
        dailyTotalsLast28Days[kStatsTrendWindowDays - 1 - i] / 60.0,
      ),
    );

    return StatsCard(
      title: kStatsCardTrendTitle,
      child: SizedBox(
        height: kStatsTrendChartHeight,
        child: Padding(
          padding: const EdgeInsets.only(top: _kPlotTopPadding),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (kStatsTrendWindowDays - 1).toDouble(),
              minY: 0,
              lineTouchData: const LineTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: _kPlotBottomReservedSize,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      // Week midpoints at x=3,10,17,24 (mid of 7-day blocks).
                      const labelPositions = <int, _LabelKey>{
                        3: _LabelKey.week1,
                        10: _LabelKey.week2,
                        17: _LabelKey.week3,
                        24: _LabelKey.thisWeek,
                      };
                      final key = labelPositions[value.toInt()];
                      if (key == null) return const SizedBox.shrink();
                      final label = switch (key) {
                        _LabelKey.week1 => '${kStatsCardTrendXAxisPrefix}1',
                        _LabelKey.week2 => '${kStatsCardTrendXAxisPrefix}2',
                        _LabelKey.week3 => '${kStatsCardTrendXAxisPrefix}3',
                        _LabelKey.thisWeek => kStatsCardTrendXAxisCurrent,
                      };
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          label,
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: <LineChartBarData>[
                LineChartBarData(
                  spots: spots,
                  color: colorScheme.primary,
                  dotData: FlDotData(
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: _kDotRadius,
                      color: colorScheme.primary,
                    ),
                  ),
                  belowBarData: BarAreaData(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _LabelKey { week1, week2, week3, thisWeek }
