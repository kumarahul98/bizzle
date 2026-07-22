import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/services/stats_period.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';

/// Hero card showing "You lost Xh Ym to traffic {this week / in July / in
/// 2026}." for the selected period (Phase 34).
///
/// Data source: statsSummaryProvider — `periodStuckSeconds` (the matched
/// non-blank-manual population). The "vs last period" comparison row is not
/// rendered — StatsSummary carries no prior-period figure.
class TrafficLossHero extends ConsumerWidget {
  /// Creates a [TrafficLossHero].
  const TrafficLossHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textTheme = Theme.of(context).textTheme;

    final asyncStats = ref.watch(statsSummaryProvider);
    return asyncStats.when(
      data: (stats) {
        final stuckMinutes = stats.periodStuckSeconds ~/ 60;
        final label = formatDurationHm(stuckMinutes);
        final suffix = switch (stats.period) {
          WeekPeriod() => kStatsHeroTrafficThisWeek,
          MonthPeriod() ||
          YearPeriod() => '$kStatsHeroTrafficInPrefix${stats.periodLabel}.',
        };
        return StatsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'You lost',
                style: textTheme.bodyMedium?.copyWith(color: tokens.textDim),
              ),
              Text(
                label,
                style: TraevyFonts.mono(
                  size: 56,
                  weight: FontWeight.w500,
                  color: tokens.stuck,
                  letterSpacing: -2.5,
                ),
              ),
              Text(
                suffix,
                style: textTheme.bodyMedium?.copyWith(color: tokens.textDim),
              ),
            ],
          ),
        );
      },
      loading: () => const StatsCard(child: SizedBox(height: 80)),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}
