import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:traevy/features/stats/widgets/donut_card.dart';
import 'package:traevy/features/stats/widgets/stats_period_selector.dart';
import 'package:traevy/features/stats/widgets/traffic_loss_hero.dart';
import 'package:traevy/features/stats/widgets/trend_bars_card.dart';
import 'package:traevy/features/stats/widgets/weekday_chart_card.dart';
import 'package:traevy/features/tour/tour_config.dart';
import 'package:traevy/shared/widgets/section_label.dart';

const double _kHorizontalPadding = 20;
const double _kTopPadding = 16;
const double _kCardGap = 16;
const double _kBottomSafeArea = 32;

/// Stats screen — Phase 34 multi-period.
///
/// Renders a 'Stats' title, a Week/Month/Year segmented selector, and a
/// '{period} · N commuting days' subtitle, then the period-aware cards
/// ([TrafficLossHero], [DonutCard], [TrendBarsCard]) followed by a dim divider
/// and the fixed-window all-time [WeekdayChartCard].
///
/// Every card watches [statsSummaryProvider] internally; the screen watches it
/// only for the subtitle. No AppBar (deliberate).
class StatsScreen extends ConsumerWidget {
  /// Construct the stats screen.
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textTheme = Theme.of(context).textTheme;
    final asyncStats = ref.watch(statsSummaryProvider);

    final subtitleLabel =
        asyncStats.whenOrNull(
          data: (stats) =>
              '${stats.periodLabel}$kStatsPeriodSeparator'
              '${formatCommutingDays(stats.periodCommutingDays)}',
        ) ??
        '';

    return Scaffold(
      body: asyncStats.when(
        data: (_) => _buildContent(context, tokens, textTheme, subtitleLabel),
        loading: () => _buildContent(
          context,
          tokens,
          textTheme,
          subtitleLabel,
          loading: true,
        ),
        error: (e, _) => const SafeArea(
          child: Center(child: Text(kStatsErrorMessage)),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    TraevyTokensExt tokens,
    TextTheme textTheme,
    String subtitleLabel, {
    bool loading = false,
  }) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _kHorizontalPadding,
          _kTopPadding,
          _kHorizontalPadding,
          _kBottomSafeArea,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Stats', style: textTheme.titleLarge),
            const SizedBox(height: 12),
            const StatsPeriodSelector(),
            const SizedBox(height: 12),
            Text(
              subtitleLabel,
              style: textTheme.bodyMedium?.copyWith(color: tokens.textDim),
            ),
            const SizedBox(height: 20),
            if (loading) ...<Widget>[
              const Center(child: CircularProgressIndicator()),
            ] else ...<Widget>[
              KeyedSubtree(
                key: TourKeys.statsTraffic,
                child: const TrafficLossHero(),
              ),
              const SizedBox(height: _kCardGap),
              KeyedSubtree(
                key: TourKeys.statsBreakdown,
                child: const DonutCard(),
              ),
              const SizedBox(height: _kCardGap),
              const TrendBarsCard(),
              const SizedBox(height: 28),
              Divider(color: tokens.border, height: 1),
              const SizedBox(height: 16),
              const SectionLabel(text: kStatsAllTimeSectionLabel),
              const SizedBox(height: 12),
              const WeekdayChartCard(),
            ],
          ],
        ),
      ),
    );
  }
}
