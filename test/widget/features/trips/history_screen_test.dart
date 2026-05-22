// Widget tests for HistoryScreen (HIST-01, HIST-02).
//
// Uses an in-memory Drift database so the appDatabaseProvider /
// tripsDaoProvider / syncQueueDaoProvider chain stays wired exactly
// as in production. The allTripSummariesProvider is overridden with
// a fixed Stream to make assertions deterministic — the in-memory DB
// is still required because handleDeleteTrip and EditTripSheet (used
// by TripRowCard's options sheet) read from those DAO providers.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:traevy/features/trips/screens/history_screen.dart';
import 'package:traevy/features/trips/widgets/history_view_toggle.dart';
import 'package:traevy/features/trips/widgets/trip_section_card.dart';
import 'package:traevy/shared/widgets/trip_row_card.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('HistoryScreen', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
    });

    tearDown(() async => db.close());

    TripSummary makeSummary({
      String direction = kDirectionToOffice,
      DateTime? startTime,
    }) {
      final start = startTime ?? DateTime.utc(2026, 1, 1, 8);
      final end = start.add(const Duration(hours: 1));
      return TripSummary(
        id: const Uuid().v4(),
        startTime: start,
        endTime: end,
        durationSeconds: 3600,
        distanceMeters: 0,
        direction: direction,
        timeMovingSeconds: 0,
        timeStuckSeconds: 0,
        isManualEntry: false,
      );
    }

    Widget buildScreen({List<TripSummary> trips = const <TripSummary>[]}) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
          allTripSummariesProvider.overrideWith(
            (ref) => Stream<List<TripSummary>>.value(trips),
          ),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          home: const HistoryScreen(),
        ),
      );
    }

    testWidgets('renders Trips as title text when trips exist', (tester) async {
      await tester.pumpWidget(buildScreen(trips: <TripSummary>[makeSummary()]));
      await tester.pump();
      // New design: title row with Text('Trips'), not an AppBar.
      expect(find.text('Trips'), findsOneWidget);
    });

    testWidgets('renders HistoryViewToggle in list and calendar views', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(trips: <TripSummary>[makeSummary()]));
      await tester.pump();
      expect(find.byType(HistoryViewToggle), findsOneWidget);
    });

    testWidgets('shows empty state when no trips', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.text(kHistoryEmptyHeading), findsOneWidget);
      expect(find.text(kHistoryEmptyBody), findsOneWidget);
    });

    testWidgets('renders TripSectionCard for a date group when trips exist', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(trips: <TripSummary>[makeSummary()]));
      await tester.pump();
      expect(find.byType(TripSectionCard), findsOneWidget);
    });

    testWidgets('renders TripRowCard inside TripSectionCard', (tester) async {
      await tester.pumpWidget(buildScreen(trips: <TripSummary>[makeSummary()]));
      await tester.pump();
      expect(find.byType(TripRowCard), findsOneWidget);
    });

    testWidgets('calendar view shows TableCalendar after toggle tap', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(trips: <TripSummary>[makeSummary()]));
      await tester.pump();
      // Initially in list view — TableCalendar must not be present yet.
      expect(find.byType(TableCalendar<TripSummary>), findsNothing);
      // Tap the calendar icon button in the new title row.
      await tester.tap(find.byIcon(Icons.calendar_today_rounded));
      await tester.pump();
      expect(find.byType(TableCalendar<TripSummary>), findsOneWidget);
    });

    testWidgets('HistoryViewToggle switches between List and Calendar views', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(trips: <TripSummary>[makeSummary()]));
      await tester.pump();
      // List view active — no calendar.
      expect(find.byType(TableCalendar<TripSummary>), findsNothing);
      // Tap 'Calendar' in the HistoryViewToggle.
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      expect(find.byType(TableCalendar<TripSummary>), findsOneWidget);
      // Tap 'List' to switch back.
      await tester.tap(find.text('List'));
      await tester.pump();
      expect(find.byType(TableCalendar<TripSummary>), findsNothing);
    });
  });
}
