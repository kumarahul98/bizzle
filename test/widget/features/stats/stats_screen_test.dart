// Widget tests for StatsScreen (STAT-01..05).
//
// Overrides allTripSummariesProvider with a fixed Stream so
// statsSummaryProvider derives a deterministic StatsSummary. No Drift
// in-memory database is needed because StatsScreen is read-only and
// does not invoke any DAO directly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/stats/screens/stats_screen.dart';
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
        child: const MaterialApp(home: StatsScreen()),
      );
    }

    testWidgets('renders Stats AppBar title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.text(kStatsAppBarTitle), findsOneWidget);
    });

    testWidgets('renders all 5 stat-card titles', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Each card's heading constant must appear in the rendered tree.
      // Cards further down the ListView may be scrolled off the default
      // 600px test viewport — use skipOffstage: false so we find them
      // even when they are outside the visible area.
      //
      // Note: kStatsCardWeekLabel ('This week') also appears as the
      // TrendChartCard x-axis label kStatsCardTrendXAxisCurrent, so we
      // use findsAtLeastNWidgets(1) for it.
      expect(
        find.text(kStatsCardWeekLabel, skipOffstage: false),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.text(kStatsCardDirectionTitle, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(kStatsCardBestWorstTitle, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(kStatsCardTrendTitle, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(kStatsCardTrafficTitle, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('renders em-dash placeholders when no trips exist (D-10)', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Empty input -> WeekMonthTotalsCard, DirectionAveragesCard, and
      // TrafficWasteCard all render kStatsEmptyPlaceholder in their
      // value slots. The exact count is not asserted (the chart card
      // may also render some), but at least 4 occurrences are
      // expected (week + month + to-office avg + to-home avg + traffic).
      expect(
        find.text(kStatsEmptyPlaceholder),
        findsAtLeastNWidgets(4),
        reason: 'D-10 requires every empty value slot to render —',
      );
    });

    testWidgets(
      'renders weekly duration when trips exist',
      (tester) async {
        // Pin trip to the current Monday at 08:00 so it is guaranteed
        // in-week relative to any test-runner date, avoiding spurious
        // failures at week boundaries (Sunday 23:59 → Monday 00:00).
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
        // Assert the trip was counted: no empty placeholder and the
        // Mon–Sun helper text is present.
        expect(find.text(kStatsEmptyPlaceholder), findsNothing);
        expect(find.text(kStatsCardWeekHelper), findsOneWidget);
      },
    );

    testWidgets('error branch renders kStatsErrorMessage', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTripSummariesProvider.overrideWith(
              (ref) => Stream<List<TripSummary>>.error(
                StateError('boom'),
              ),
            ),
          ],
          child: const MaterialApp(home: StatsScreen()),
        ),
      );
      await tester.pump();
      expect(find.text(kStatsErrorMessage), findsOneWidget);
    });
  });
}
