import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';

const double _kDonutSize = 110;
const double _kDonutHole = 0.65;

/// 110dp donut card showing moving vs stuck split for the selected period,
/// plus the per-commuting-day average and commuting-day count (Phase 34).
///
/// Data source: statsSummaryProvider. The centre total is `periodTotalSeconds`
/// (all trips); the wedges and the stuck share are drawn from the matched
/// non-blank-manual population (`periodMovingSeconds` / `periodStuckSeconds`).
/// The title carries the '· so far' marker while the period is in progress.
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
        final totalMins = stats.periodTotalSeconds ~/ 60;
        final stuckMins = stats.periodStuckSeconds ~/ 60;
        final movingMins = stats.periodMovingSeconds ~/ 60;
        final share = stats.periodStuckSharePercent;
        final title = stats.isPeriodPartial
            ? '${stats.periodLabel}$kStatsPeriodSeparator$kStatsSoFarLabel'
            : stats.periodLabel;
        final stuckLabel = share == null
            ? '${formatDurationHm(stuckMins)} stuck'
            : '${formatDurationHm(stuckMins)} stuck'
                  '$kStatsPeriodSeparator$share$kStatsStuckSharePercent';

        return StatsCard(
          title: title,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      formatDurationHm(totalMins),
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
                      label: '${formatDurationHm(movingMins)} moving',
                    ),
                    const SizedBox(height: 4),
                    _LegendRow(color: tokens.stuck, label: stuckLabel),
                    const SizedBox(height: 12),
                    Text(
                      formatPerCommutingDay(
                        stats.periodAvgSecondsPerCommutingDay,
                      ),
                      style: TraevyFonts.mono(
                        size: 13,
                        weight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                    Text(
                      formatCommutingDays(stats.periodCommutingDays),
                      style: textTheme.bodyMedium?.copyWith(
                        color: tokens.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const StatsCard(child: SizedBox(height: 110)),
      error: (e, _) => const SizedBox.shrink(),
    );
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
