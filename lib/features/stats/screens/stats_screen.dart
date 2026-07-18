import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/widgets/donut_card.dart';
import 'package:traevy/features/stats/widgets/traffic_loss_hero.dart';
import 'package:traevy/features/stats/widgets/trend_bars_card.dart';
import 'package:traevy/features/stats/widgets/weekday_chart_card.dart';
import 'package:traevy/features/tour/tour_config.dart';

const double _kHorizontalPadding = 20;
const double _kTopPadding = 16;
const double _kCardGap = 16;
const double _kBottomSafeArea = 32;

/// Stats screen — Phase 8 Traevy restyle.
///
/// Removes the AppBar. Renders a 'Stats' title + 'Last 28 days · N trips'
/// subtitle, followed by four bgElev cards: [TrafficLossHero], [DonutCard],
/// [TrendBarsCard], [WeekdayChartCard].
///
/// Watches [statsSummaryProvider] for the trip count subtitle only; each
/// card watches the same provider internally.
class StatsScreen extends ConsumerWidget {
  /// Construct the stats screen.
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textTheme = Theme.of(context).textTheme;
    final asyncStats = ref.watch(statsSummaryProvider);

    // Derive trip count from non-zero daily totals as an approximation.
    // StatsSummary does not expose a tripCount field directly.
    final tripCountLabel =
        asyncStats.whenOrNull(
          data: (stats) {
            final count = stats.dailyTotalsLast28Days
                .where((s) => s > 0)
                .length;
            return 'Last 28 days · $count trips';
          },
        ) ??
        'Last 28 days';

    return Scaffold(
      body: asyncStats.when(
        data: (_) => _buildContent(context, tokens, textTheme, tripCountLabel),
        loading: () => _buildContent(
          context,
          tokens,
          textTheme,
          tripCountLabel,
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
            const SizedBox(height: 4),
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
              const SizedBox(height: _kCardGap),
              const WeekdayChartCard(),
            ],
          ],
        ),
      ),
    );
  }
}
