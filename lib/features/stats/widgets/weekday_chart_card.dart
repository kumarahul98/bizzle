import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';

const double _kChartHeight = 120;
const double _kBarWidth = 16;

/// Mon-Fri bar chart showing average commute duration per weekday.
///
/// Data source: statsSummaryProvider — uses weekdayAverages (list of nullable
/// int seconds, index 0=Mon...4=Fri) via TRIVIAL-LOCAL-COMPUTE (~/ 60 for minutes).
/// bestDay and worstDay are computed locally by argmin/argmax over the list.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §7 Stats Screen.
class WeekdayChartCard extends ConsumerWidget {
  /// Creates a [WeekdayChartCard].
  const WeekdayChartCard({super.key});

  static const List<String> _weekdayNames = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;

    final asyncStats = ref.watch(statsSummaryProvider);
    return asyncStats.when(
      data: (stats) {
        // weekdayAverages: 7-element list, index 0=Mon…4=Fri; 5-6 always null.
        final avgSeconds = stats.weekdayAverages;
        final avgMins = List<int?>.generate(
          5,
          (i) => avgSeconds[i] != null ? (avgSeconds[i]! ~/ 60) : null,
        );

        // Find best (lowest) and worst (highest) non-null weekday.
        int? bestIdx;
        int? worstIdx;
        var bestVal = 1 << 30;
        var worstVal = -1;
        for (var i = 0; i < 5; i++) {
          final v = avgMins[i];
          if (v == null) continue;
          if (v < bestVal) {
            bestVal = v;
            bestIdx = i;
          }
          if (v > worstVal) {
            worstVal = v;
            worstIdx = i;
          }
        }
        // Tie: when all non-null values equal, drop worstIdx.
        if (bestIdx != null && worstIdx != null && bestVal == worstVal) {
          worstIdx = null;
        }

        final maxY = avgMins
            .whereType<int>()
            .fold<int>(0, (prev, v) => v > prev ? v : prev)
            .toDouble();

        final barGroups = List<BarChartGroupData>.generate(5, (i) {
          final val = avgMins[i]?.toDouble() ?? 0;
          Color color;
          if (i == worstIdx) {
            color = tokens.stuck;
          } else if (i == bestIdx) {
            color = tokens.moving;
          } else {
            color = tokens.borderStr;
          }
          return BarChartGroupData(
            x: i,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: val,
                color: color,
                width: _kBarWidth,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ],
          );
        });

        final bestName = bestIdx != null ? _weekdayNames[bestIdx] : null;
        final worstName = worstIdx != null ? _weekdayNames[worstIdx] : null;
        final bestAvg = bestIdx != null ? avgMins[bestIdx] : null;
        final worstAvg = worstIdx != null ? avgMins[worstIdx] : null;

        return StatsCard(
          title: 'Weekday averages',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: _kChartHeight,
                child: BarChart(
                  BarChartData(
                    maxY: maxY == 0 ? 10 : maxY * 1.25,
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
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= 5) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                _weekdayNames[i],
                                style: TraevyFonts.ui(
                                  size: 11,
                                  weight: FontWeight.w600,
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
              if (bestName != null || worstName != null) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    if (worstName != null)
                      Text(
                        'Worst $worstName · ${worstAvg}m',
                        style: TraevyFonts.ui(
                          size: 12,
                          weight: FontWeight.w600,
                          color: tokens.stuck,
                        ),
                      ),
                    const Spacer(),
                    if (bestName != null)
                      Text(
                        'Best $bestName · ${bestAvg}m',
                        style: TraevyFonts.ui(
                          size: 12,
                          weight: FontWeight.w600,
                          color: tokens.moving,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const StatsCard(
        title: 'Weekday averages',
        child: SizedBox(height: _kChartHeight),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}
