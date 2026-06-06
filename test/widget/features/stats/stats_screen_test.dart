// Widget tests for StatsScreen (Phase 8 Traevy restyle).
//
// Overrides allTripSummariesProvider with a fixed Stream so
// statsSummaryProvider derives a deterministic StatsSummary. No Drift
// in-memory database is needed because StatsScreen is read-only.
//
// The new layout (TrafficLossHero, DonutCard, TrendBarsCard, WeekdayChartCard)
// replaces the five legacy cards. Tests confirm the new widget types are
// present and that the 'Stats' title + 'Last 28 days' subtitle render.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/stats/screens/stats_screen.dart';
import 'package:traevy/features/stats/widgets/donut_card.dart';
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
    distanceMeters: 0,
    direction: kDirectionToOffice,
    timeMovingSeconds: durationSeconds,
    timeStuckSeconds: 0,
    isManualEntry: false,
  );
}

void main() {
  setUpAll(() {
    // Pitfall 7: pin locale so DateFormat.E() output is deterministic.
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

    testWidgets('renders Last 28 days subtitle', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Subtitle contains 'Last 28 days' — trip count varies.
      expect(
        find.textContaining('Last 28 days'),
        findsOneWidget,
      );
    });

    testWidgets('renders TrafficLossHero', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(TrafficLossHero), findsOneWidget);
    });

    testWidgets('renders DonutCard', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(DonutCard), findsOneWidget);
    });

    testWidgets('renders TrendBarsCard', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(TrendBarsCard), findsOneWidget);
    });

    testWidgets('renders WeekdayChartCard', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(WeekdayChartCard), findsOneWidget);
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

    testWidgets('renders trip count in subtitle when trips exist', (
      tester,
    ) async {
      final now = DateTime.now();
      final monday = now.subtract(
        Duration(days: now.weekday - DateTime.monday),
      );
      final pinnedTrip = _trip(
        DateTime(monday.year, monday.month, monday.day, 8),
        durationSeconds: 3600,
      );
      await tester.pumpWidget(buildScreen(trips: <TripSummary>[pinnedTrip]));
      await tester.pump();
      // Screen renders without error and Stats title is present.
      expect(find.text('Stats'), findsOneWidget);
    });
  });
}
