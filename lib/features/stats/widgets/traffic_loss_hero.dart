import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/widgets/stats_card.dart';

/// Hero card showing "You lost Xh Ym to traffic this week."
///
/// Data source: statsSummaryProvider — uses weekStuckSeconds divided by 60.
/// The "vs last week" comparison row is omitted because StatsSummary does
/// not expose a `previousWeekStuckMinutes` field (GRACEFUL-DEGRADE per
/// 08-06-STATS-DATA-MAPPING.md).
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §7 Stats Screen.
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
        final stuckMinutes = stats.weekStuckSeconds ~/ 60;
        final label = _formatStuckHm(stuckMinutes);
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
                'to traffic this week.',
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

  String _formatStuckHm(int minutes) {
    if (minutes == 0) return '0m';
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}
