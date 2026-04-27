import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/widgets/best_worst_day_card.dart';
import 'package:traevy/features/stats/widgets/direction_averages_card.dart';
import 'package:traevy/features/stats/widgets/traffic_waste_card.dart';
import 'package:traevy/features/stats/widgets/trend_chart_card.dart';
import 'package:traevy/features/stats/widgets/week_month_totals_card.dart';

const double _kHorizontalPadding = 16;
const double _kCardGap = 16;
const double _kBottomSafeArea = 32;

/// Single scrollable stats screen (STAT-01..05).
///
/// Watches [statsSummaryProvider] and dispatches via `AsyncValue.when`:
/// - `loading` -> centered [CircularProgressIndicator]
/// - `error`   -> centered error message text
/// - `data`    -> scrollable [Column] of 5 stat cards in the order
///               locked by D-01
///
/// Uses [SingleChildScrollView] + [Column] (not [ListView]) so all 5
/// cards are always built regardless of viewport height — avoids lazy
/// virtualisation on a fixed-length list and keeps widget tests simple.
///
/// Empty input is handled at the per-card level (D-10): every card
/// renders a `—` placeholder in its value slot when no qualifying
/// data exists. There is no full-screen empty state.
class StatsScreen extends ConsumerWidget {
  /// Construct the stats screen.
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(statsSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(kStatsAppBarTitle)),
      body: asyncStats.when(
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            _kHorizontalPadding,
            _kHorizontalPadding,
            _kHorizontalPadding,
            _kBottomSafeArea,
          ),
          child: Column(
            children: <Widget>[
              WeekMonthTotalsCard(
                weekTotalSeconds: stats.weekTotalSeconds,
                monthTotalSeconds: stats.monthTotalSeconds,
              ),
              const SizedBox(height: _kCardGap),
              DirectionAveragesCard(
                toOfficeAvgSeconds: stats.toOfficeAvgSeconds,
                toHomeAvgSeconds: stats.toHomeAvgSeconds,
              ),
              const SizedBox(height: _kCardGap),
              BestWorstDayCard(
                weekdayAverages: stats.weekdayAverages,
              ),
              const SizedBox(height: _kCardGap),
              TrendChartCard(
                dailyTotalsLast28Days: stats.dailyTotalsLast28Days,
              ),
              const SizedBox(height: _kCardGap),
              TrafficWasteCard(
                weekStuckSeconds: stats.weekStuckSeconds,
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(
          child: Text(kStatsErrorMessage),
        ),
      ),
    );
  }
}
