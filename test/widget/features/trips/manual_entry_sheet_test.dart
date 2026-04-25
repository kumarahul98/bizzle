import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/widgets/manual_entry_sheet.dart';

void main() {
  group('ManualEntrySheet', () {
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

    Widget buildSheet() {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ManualEntrySheet(),
          ),
        ),
      );
    }

    testWidgets('shows Add missed commute title', (tester) async {
      await tester.pumpWidget(buildSheet());
      expect(find.text('Add missed commute'), findsOneWidget);
    });

    testWidgets('shows Date label', (tester) async {
      await tester.pumpWidget(buildSheet());
      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('shows Duration HH:MM label', (tester) async {
      await tester.pumpWidget(buildSheet());
      expect(find.text('Duration (HH:MM)'), findsOneWidget);
    });

    testWidgets('shows Direction SegmentedButton with To office and To home', (
      tester,
    ) async {
      await tester.pumpWidget(buildSheet());
      expect(find.text('Direction'), findsOneWidget);
      expect(find.text('To office'), findsOneWidget);
      expect(find.text('To home'), findsOneWidget);
    });

    testWidgets('shows Cancel and Save buttons', (tester) async {
      await tester.pumpWidget(buildSheet());
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
