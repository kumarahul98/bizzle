// Widget tests for StatsScreen (Phase 34 multi-period).
//
// Overrides allTripSummariesProvider with a fixed Stream so
// statsSummaryProvider derives a deterministic StatsSummary. No Drift
// in-memory database is needed because StatsScreen is read-only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/stats/screens/stats_screen.dart';
import 'package:traevy/features/stats/widgets/donut_card.dart';
import 'package:traevy/features/stats/widgets/stats_period_selector.dart';
import 'package:traevy/features/stats/widgets/traffic_loss_hero.dart';
import 'package:traevy/features/stats/widgets/trend_bars_card.dart';
import 'package:traevy/features/stats/widgets/weekday_chart_card.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:uuid/uuid.dart';

TripSummary _trip(DateTime startTime, {int durationSeconds = 1800}) {
  return TripSummary(
    id: const Uuid().v4(),
    startTime: startTime,
    endTime: startTime.add(Duration(seconds: durationSeconds)),
    durationSeconds: durationSeconds,
    distanceMeters: 5000,
    direction: kDirectionToOffice,
    timeMovingSeconds: durationSeconds,
    timeStuckSeconds: 0,
    isManualEntry: false,
  );
}

void main() {
  setUpAll(() {
    Intl.defaultLocale = 'en_US';
  });

  group('StatsScreen', () {
    Widget buildScreen({List<TripSummary> trips = const <TripSummary>[]}) {
      return ProviderScope(
        overrides: [
          allTripSummariesProvider.overrideWith(
            (ref) => Stream<List<TripSummary>>.value(trips),
          ),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const StatsScreen(),
        ),
      );
    }

    testWidgets('renders Stats title heading', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.text('Stats'), findsOneWidget);
    });

    testWidgets('renders the Week/Month/Year selector', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(StatsPeriodSelector), findsOneWidget);
      expect(find.text(kStatsPeriodWeekTab), findsOneWidget);
      expect(find.text(kStatsPeriodMonthTab), findsOneWidget);
      expect(find.text(kStatsPeriodYearTab), findsOneWidget);
    });

    testWidgets('subtitle shows the period and commuting-day count', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Empty week → 'This week · No commuting days'.
      expect(
        find.text('This week$kStatsPeriodSeparator$kStatsNoCommutingDays'),
        findsOneWidget,
      );
    });

    testWidgets('renders the period-aware cards and the all-time card', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(TrafficLossHero), findsOneWidget);
      expect(find.byType(DonutCard), findsOneWidget);
      expect(find.byType(TrendBarsCard), findsOneWidget);
      expect(find.byType(WeekdayChartCard), findsOneWidget);
      expect(
        find.text(kStatsAllTimeSectionLabel.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('no AppBar in Stats screen', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('error branch renders kStatsErrorMessage', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTripSummariesProvider.overrideWith(
              (ref) => Stream<List<TripSummary>>.error(StateError('boom')),
            ),
          ],
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const StatsScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(kStatsErrorMessage), findsOneWidget);
    });

    testWidgets(
      'switching to Month moves every period-aware card together',
      (tester) async {
        // A trip earlier this month but NOT this week: appears only when the
        // period is Month. Anchor to a day late in the month so "this week"
        // cannot include the 1st.
        final now = DateTime.now();
        final firstOfMonth = DateTime(now.year, now.month, 2, 8);
        final onlyThisMonth = _trip(firstOfMonth, durationSeconds: 3600);
        final isLateEnough = now.day > 9;

        await tester.pumpWidget(
          buildScreen(trips: <TripSummary>[onlyThisMonth]),
        );
        await tester.pump();

        // Tap Month.
        await tester.tap(find.text(kStatsPeriodMonthTab));
        await tester.pump();

        // The month subtitle uses the month name; the donut title carries the
        // '· so far' marker for the current month.
        final monthName = DateFormat(
          kStatsPeriodMonthPattern,
        ).format(now);
        expect(
          find.textContaining(monthName),
          findsWidgets,
          reason: 'month label should appear once the period is Month',
        );
        if (isLateEnough) {
          // The 1 commuting day is only in-period under Month, proving all
          // period-aware cards recomputed from the shared provider.
          expect(
            find.text(
              '$monthName${kStatsPeriodSeparator}1 $kStatsCommutingDayWord',
            ),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets('current period shows the · so far marker', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // The DonutCard title carries 'This week · so far' for the live week.
      // StatsCard renders titles through SectionLabel, which uppercases.
      final marker = 'This week$kStatsPeriodSeparator$kStatsSoFarLabel'
          .toUpperCase();
      expect(find.text(marker), findsOneWidget);
    });
  });
}
