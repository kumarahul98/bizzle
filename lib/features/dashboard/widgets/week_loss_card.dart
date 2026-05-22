import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/shell/providers/main_shell_provider.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/shared/widgets/section_label.dart';
import 'package:traevy/shared/widgets/stuck_bar.dart';

/// "You lost X to traffic this week" card on the dashboard.
///
/// The "See stats →" link switches the shell tab index to 2 (Stats) rather
/// than pushing a route — per Assumption A5/A6 in RESEARCH.md.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §3 Week loss card.
class WeekLossCard extends ConsumerWidget {
  /// Create the week loss card.
  const WeekLossCard({super.key});

  static String _formatHm(int minutes) {
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  static String _formatStuckHm(int minutes) {
    if (minutes == 0) return '0m';
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textTheme = Theme.of(context).textTheme;
    final asyncStats = ref.watch(statsSummaryProvider);

    return asyncStats.when(
      data: (stats) {
        final stuckMins = stats.weekStuckSeconds ~/ 60;
        final totalMins = stats.weekTotalSeconds ~/ 60;
        final movingMins = totalMins - stuckMins;

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: tokens.border),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SectionLabel(text: 'This week'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          ref.read(mainShellIndexProvider.notifier).setIndex(2),
                      child: Text(
                        'See stats →',
                        style: TraevyFonts.ui(
                          size: 12,
                          weight: FontWeight.w600,
                          color: tokens.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'You lost',
                  style: textTheme.bodyMedium?.copyWith(color: tokens.textDim),
                ),
                Text(
                  _formatStuckHm(stuckMins),
                  style: TraevyFonts.mono(
                    size: 38,
                    weight: FontWeight.w500,
                    color: tokens.stuck,
                    letterSpacing: -1.5,
                  ),
                ),
                Text(
                  'to traffic this week.',
                  style: textTheme.bodyMedium?.copyWith(color: tokens.textDim),
                ),
                const SizedBox(height: 14),
                StuckBar(
                  movingMinutes: movingMins,
                  stuckMinutes: stuckMins,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${_formatHm(movingMins)} moving',
                      style: TraevyFonts.mono(
                        size: 11.5,
                        color: tokens.moving,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_formatHm(totalMins)} total',
                      style: TraevyFonts.mono(
                        size: 11.5,
                        color: tokens.textDim,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
