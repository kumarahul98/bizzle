// Widget tests for HistoryScreen (HIST-01, HIST-02).
//
// Uses an in-memory Drift database so the appDatabaseProvider /
// tripsDaoProvider / syncQueueDaoProvider chain stays wired exactly
// as in production. The allTripSummariesProvider is overridden with
// a fixed Stream to make assertions deterministic — the in-memory DB
// is still required because handleDeleteTrip and EditTripSheet (used
// by TripCard's options sheet) read from those DAO providers.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:traevy/features/trips/screens/history_screen.dart';
import 'package:uuid/uuid.dart';

void main() {
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
        child: const MaterialApp(home: HistoryScreen()),
      );
    }

    testWidgets('renders History as AppBar title when trips exist', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(trips: <TripSummary>[makeSummary()]));
      await tester.pump();
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('shows empty state when no trips', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.text(kHistoryEmptyHeading), findsOneWidget);
      expect(find.text(kHistoryEmptyBody), findsOneWidget);
    });

    testWidgets('renders trip departure time text when trips exist', (
      tester,
    ) async {
      final summary = makeSummary();
      await tester.pumpWidget(buildScreen(trips: <TripSummary>[summary]));
      await tester.pump();
      // The TripCard renders DateFormat.jm() of the local start time.
      // Compute the expected string the same way to avoid timezone
      // assumptions in the test runner.
      final expectedTime = DateFormat.jm().format(summary.startTime.toLocal());
      expect(find.text(expectedTime), findsOneWidget);
    });

    testWidgets('calendar view shows TableCalendar after toggle tap', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(trips: <TripSummary>[makeSummary()]));
      await tester.pump();
      // Initially in list view — TableCalendar must not be present yet.
      expect(find.byType(TableCalendar<TripSummary>), findsNothing);
      // Tap the AppBar toggle (the calendar icon).
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pump();
      expect(find.byType(TableCalendar<TripSummary>), findsOneWidget);
    });

    testWidgets('tapping a trip card opens the options sheet', (tester) async {
      // Verifies the more_vert IconButton path. The actual navigation
      // tap target is the InkWell wrapping the card body — covered here
      // by ensuring the more-vert path also works (T-04-03-01 requires
      // a two-step delete; this confirms the options sheet renders).
      await tester.pumpWidget(buildScreen(trips: <TripSummary>[makeSummary()]));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Edit trip'), findsOneWidget);
      expect(find.text('Delete trip'), findsOneWidget);
    });
  });
}
