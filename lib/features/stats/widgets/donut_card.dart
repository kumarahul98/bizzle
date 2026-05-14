import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';

const double _kDonutSize = 110;
const double _kDonutHole = 0.65;

/// 110dp donut chart showing moving vs stuck split for the current week.
///
/// Data source: statsSummaryProvider — uses weekTotalSeconds and
/// weekStuckSeconds with TRIVIAL-LOCAL-COMPUTE to derive moving minutes
/// (weekTotalSeconds - weekStuckSeconds) ~/ 60.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §7 Stats Screen.
class DonutCard extends ConsumerWidget {
  /// Creates a [DonutCard].
  const DonutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textTheme = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final asyncStats = ref.watch(statsSummaryProvider);
    return asyncStats.when(
      data: (stats) {
        final totalMins = stats.weekTotalSeconds ~/ 60;
        final stuckMins = stats.weekStuckSeconds ~/ 60;
        final movingMins = totalMins - stuckMins;

        return StatsCard(
          title: 'This week',
          child: Row(
            children: <Widget>[
              SizedBox(
                width: _kDonutSize,
                height: _kDonutSize,
                child: _DonutChart(
                  movingMinutes: movingMins,
                  stuckMinutes: stuckMins,
                  tokens: tokens,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _formatHm(totalMins),
                      style: TraevyFonts.mono(
                        size: 22,
                        weight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                    Text(
                      'total',
                      style: textTheme.bodyMedium?.copyWith(
                        color: tokens.textDim,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LegendRow(
                      color: tokens.moving,
                      label: '${_formatHm(movingMins)} moving',
                    ),
                    const SizedBox(height: 4),
                    _LegendRow(
                      color: tokens.stuck,
                      label: '${_formatHm(stuckMins)} stuck',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const StatsCard(title: 'This week', child: SizedBox(height: 110)),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  String _formatHm(int minutes) {
    if (minutes == 0) return '0m';
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.movingMinutes,
    required this.stuckMinutes,
    required this.tokens,
  });

  final int movingMinutes;
  final int stuckMinutes;
  final TraevyTokensExt tokens;

  @override
  Widget build(BuildContext context) {
    final total = movingMinutes + stuckMinutes;
    if (total == 0) {
      // Empty donut — render a full surface2 ring.
      return PieChart(
        PieChartData(
          sections: <PieChartSectionData>[
            PieChartSectionData(
              value: 1,
              color: tokens.surface2,
              radius: _kDonutSize * (1 - _kDonutHole) / 2,
              showTitle: false,
            ),
          ],
          centerSpaceRadius: _kDonutSize * _kDonutHole / 2,
          sectionsSpace: 0,
        ),
      );
    }

    return PieChart(
      PieChartData(
        sections: <PieChartSectionData>[
          PieChartSectionData(
            value: movingMinutes.toDouble(),
            color: tokens.moving,
            radius: _kDonutSize * (1 - _kDonutHole) / 2,
            showTitle: false,
          ),
          PieChartSectionData(
            value: stuckMinutes.toDouble(),
            color: tokens.stuck,
            radius: _kDonutSize * (1 - _kDonutHole) / 2,
            showTitle: false,
          ),
        ],
        centerSpaceRadius: _kDonutSize * _kDonutHole / 2,
        sectionsSpace: 2,
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TraevyFonts.mono(size: 11.5, color: color)),
      ],
    );
  }
}
