// Widget tests for the Trash screen (Phase 35, D-05).
//
// Uses an in-memory Drift database so the full deletedTripSummariesProvider →
// watchDeletedSummaries chain and the trip-management notifier (restore /
// permanent-delete) stay wired exactly as in production.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/screens/deleted_trips_screen.dart';
import 'package:traevy/features/trips/widgets/deleted_trip_tile.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('DeletedTripsScreen', () {
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

    Future<String> insertSoftDeleted({
      required String id,
      required DateTime deletedAt,
    }) async {
      final start = DateTime.utc(2026, 1, 1, 8);
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          startTime: start,
          endTime: start.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
          distanceMeters: 5000,
          direction: kDirectionToOffice,
          timeMovingSeconds: 1500,
          timeStuckSeconds: 300,
        ),
      );
      await db.tripsDao.softDeleteTrip(id, deletedAt);
      return id;
    }

    Widget buildScreen() {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          home: const DeletedTripsScreen(),
        ),
      );
    }

    testWidgets('shows the empty state when nothing is deleted', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.text(kTrashEmptyHeading), findsOneWidget);
      expect(find.byType(DeletedTripTile), findsNothing);
    });

    testWidgets('renders a tile per soft-deleted trip with the actions', (
      tester,
    ) async {
      await insertSoftDeleted(id: 'x', deletedAt: DateTime.now().toUtc());
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(DeletedTripTile), findsOneWidget);
      expect(find.text(kTrashRestoreLabel), findsOneWidget);
      expect(find.text(kTrashDeletePermanentlyLabel), findsOneWidget);
      // The retention countdown is present (deleted just now → today).
      expect(find.textContaining(kTrashDeletedTodayLabel), findsOneWidget);
    });

    testWidgets('Restore brings the trip back and empties the trash', (
      tester,
    ) async {
      await insertSoftDeleted(id: 'r1', deletedAt: DateTime.now().toUtc());
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text(kTrashRestoreLabel));
      await tester.pumpAndSettle();

      // Trip is live again and gone from the Trash list.
      final row = await db.tripsDao.findById('r1');
      expect(row!.deletedAt, isNull);
      expect(find.byType(DeletedTripTile), findsNothing);
      expect(find.text(kTrashRestoredSnackbar), findsOneWidget);
    });

    testWidgets('Delete permanently confirms, then hard-deletes', (
      tester,
    ) async {
      await insertSoftDeleted(id: 'p1', deletedAt: DateTime.now().toUtc());
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text(kTrashDeletePermanentlyLabel));
      await tester.pumpAndSettle();
      // Confirmation dialog is shown first (irreversible action).
      expect(find.text(kTrashPermanentDeleteDialogTitle), findsOneWidget);

      await tester.tap(find.text(kTrashPermanentDeleteConfirm));
      await tester.pumpAndSettle();

      expect(await db.tripsDao.findById('p1'), isNull);
      expect(find.byType(DeletedTripTile), findsNothing);
      expect(find.text(kTrashPermanentlyDeletedSnackbar), findsOneWidget);
    });
  });
}
