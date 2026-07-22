// Widget tests for TrendBarsCard bucketing per period (Phase 34, Q6 overrule).
//
// Overrides statsSummaryProvider directly so the trend bars and period are
// fully deterministic, then reads back the BarChart's data to assert the bar
// count and title per period.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/services/stats_period.dart';
import 'package:traevy/features/stats/services/stats_service.dart';
import 'package:traevy/features/stats/widgets/trend_bars_card.dart';

StatsSummary _summary({
  required StatsPeriod period,
  required List<StatsTrendBar> bars,
}) {
  return StatsSummary(
    weekTotalSeconds: 0,
    weekStuckSeconds: 0,
    period: period,
    periodLabel: 'x',
    isPeriodPartial: true,
    periodTotalSeconds: 0,
    periodStuckSeconds: 0,
    periodMovingSeconds: 0,
    periodStuckSharePercent: null,
    periodCommutingDays: 0,
    periodAvgSecondsPerCommutingDay: null,
    periodTrendBars: bars,
    toOfficeAvgSeconds: null,
    toHomeAvgSeconds: null,
    weekdayAverages: const <int?>[null, null, null, null, null, null, null],
    dailyTotalsLast28Days: List<int>.filled(28, 0),
    hasAnyTrips: false,
  );
}

List<StatsTrendBar> _bars(int n) => <StatsTrendBar>[
  for (var i = 0; i < n; i++)
    StatsTrendBar(seconds: i * 60, label: 'L$i', isCurrent: i == 0),
];

Future<BarChart> _pump(
  WidgetTester tester, {
  required StatsPeriod period,
  required int barCount,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        statsSummaryProvider.overrideWithValue(
          AsyncValue<StatsSummary>.data(
            _summary(period: period, bars: _bars(barCount)),
          ),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(body: TrendBarsCard()),
      ),
    ),
  );
  await tester.pump();
  return tester.widget<BarChart>(find.byType(BarChart));
}

void main() {
  testWidgets('week → 7 daily bars, Daily trend title', (tester) async {
    final chart = await _pump(tester, period: const WeekPeriod(), barCount: 7);
    expect(chart.data.barGroups.length, 7);
    expect(find.text(kStatsTrendDailyTitle.toUpperCase()), findsOneWidget);
  });

  testWidgets('month → 5 weekly bars, Weekly trend title', (tester) async {
    final chart = await _pump(tester, period: const MonthPeriod(), barCount: 5);
    expect(chart.data.barGroups.length, 5);
    expect(find.text(kStatsTrendWeeklyTitle.toUpperCase()), findsOneWidget);
  });

  testWidgets('year → 12 monthly bars, Monthly trend title', (tester) async {
    final chart = await _pump(tester, period: const YearPeriod(), barCount: 12);
    expect(chart.data.barGroups.length, 12);
    expect(find.text(kStatsTrendMonthlyTitle.toUpperCase()), findsOneWidget);
  });
}
