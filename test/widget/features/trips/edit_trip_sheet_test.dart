import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/widgets/edit_trip_sheet.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('EditTripSheet', () {
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

    Widget buildSheet(TripSummary summary) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EditTripSheet(summary: summary),
          ),
        ),
      );
    }

    TripSummary makeSummary({String direction = kDirectionToOffice}) {
      final start = DateTime.utc(2026, 1, 1, 8);
      final end = DateTime.utc(2026, 1, 1, 9);
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

    testWidgets('shows Edit trip title', (tester) async {
      await tester.pumpWidget(buildSheet(makeSummary()));
      expect(find.text('Edit trip'), findsOneWidget);
    });

    testWidgets('shows Direction label and SegmentedButton segments',
        (tester) async {
      await tester.pumpWidget(buildSheet(makeSummary()));
      expect(find.text('Direction'), findsOneWidget);
      expect(find.text('To office'), findsOneWidget);
      expect(find.text('To home'), findsOneWidget);
    });

    testWidgets('shows Start time and End time labels', (tester) async {
      await tester.pumpWidget(buildSheet(makeSummary()));
      expect(find.text('Start time'), findsOneWidget);
      expect(find.text('End time'), findsOneWidget);
    });

    testWidgets('shows Cancel and Save buttons', (tester) async {
      await tester.pumpWidget(buildSheet(makeSummary()));
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
