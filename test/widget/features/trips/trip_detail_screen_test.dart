// Widget tests for TripDetailScreen (HIST-03).
//
// Covers loading state, not-found state, manual trip layout (no map), and
// GPS trip stat rendering. flutter_map's TileLayer issues HTTP requests
// for OSM tiles at runtime — per 04-RESEARCH.md the GPS-trip path is not
// pumped through pumpAndSettle in this suite (manual trips and stats are
// asserted directly without rendering map tiles into a deterministic
// frame). The GPS test inserts a trip with an empty polyline so the
// _MapView renders the surfaceContainerLow placeholder instead of
// FlutterMap, sidestepping the tile-network problem entirely while still
// asserting the stat-row pipeline.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/screens/trip_detail_screen.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('TripDetailScreen', () {
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

    Widget buildScreen(String tripId) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        ],
        child: MaterialApp(
          home: TripDetailScreen(tripId: tripId),
        ),
      );
    }

    Future<String> insertGpsTrip() async {
      final id = const Uuid().v4();
      final start = DateTime.utc(2026, 1, 1, 8);
      final end = DateTime.utc(2026, 1, 1, 8, 45);
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          startTime: start,
          endTime: end,
          durationSeconds: 2700,
          distanceMeters: 5000,
          // Empty polyline — _MapView renders the surfaceContainerLow
          // placeholder instead of FlutterMap, avoiding OSM tile HTTP.
          routePolyline: const Value(''),
          direction: kDirectionToOffice,
          timeMovingSeconds: 2400,
          timeStuckSeconds: 300,
          isManualEntry: const Value(false),
          createdAt: Value(start),
          updatedAt: Value(start),
        ),
      );
      return id;
    }

    Future<String> insertManualTrip() async {
      final id = const Uuid().v4();
      final start = DateTime.utc(2026, 1, 1, 8);
      final end = DateTime.utc(2026, 1, 1, 8, 45);
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          startTime: start,
          endTime: end,
          durationSeconds: 2700,
          distanceMeters: 0,
          routePolyline: const Value(''),
          direction: kDirectionToOffice,
          timeMovingSeconds: 0,
          timeStuckSeconds: 0,
          isManualEntry: const Value(true),
          createdAt: Value(start),
          updatedAt: Value(start),
        ),
      );
      return id;
    }

    testWidgets('shows CircularProgressIndicator while loading', (
      tester,
    ) async {
      // Initial frame from pumpWidget runs build() with _loading = true
      // and _trip = null — the loading branch is rendered before the
      // postFrameCallback's findById future resolves on the next event
      // loop turn. Do NOT pumpAndSettle here: the in-memory DB resolves
      // the future synchronously enough that any extra pump flips the
      // screen into the loaded/not-found state.
      await tester.pumpWidget(buildScreen('does-not-matter'));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows Trip not found for invalid id', (tester) async {
      await tester.pumpWidget(buildScreen('nonexistent-id'));
      await tester.pumpAndSettle();
      expect(find.text(kTripDetailNotFound), findsOneWidget);
    });

    testWidgets(
      'manual trip hides map and shows Manually entered badge',
      (tester) async {
        final id = await insertManualTrip();
        await tester.pumpWidget(buildScreen(id));
        await tester.pumpAndSettle();
        expect(find.text(kManualEntryBadge), findsOneWidget);
        // Manual layout never instantiates FlutterMap.
        expect(find.byType(FlutterMap), findsNothing);
        // Manual layout omits Distance/Moving/Stuck rows.
        expect(find.text('Distance'), findsNothing);
        expect(find.text('Stuck in traffic'), findsNothing);
        // Direction + Date + Duration rows are present.
        expect(find.text('Duration'), findsOneWidget);
        expect(find.text('Direction'), findsOneWidget);
        expect(find.text('Date'), findsOneWidget);
      },
    );

    testWidgets('GPS trip shows all six stat rows', (tester) async {
      final id = await insertGpsTrip();
      await tester.pumpWidget(buildScreen(id));
      await tester.pumpAndSettle();
      // All six stat-row labels render.
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Direction'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Moving'), findsOneWidget);
      expect(find.text('Stuck in traffic'), findsOneWidget);
      // Duration value: 2700 seconds → "45 min".
      expect(find.text('45 min'), findsWidgets);
      // Manual badge does not appear for GPS trips.
      expect(find.text(kManualEntryBadge), findsNothing);
    });
  });
}
