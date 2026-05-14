// Widget tests for TripDetailScreen (HIST-03) — Phase 8 UI-Overhaul restyled layout.
//
// Covers loading state, not-found state, manual trip layout (no map), and
// GPS trip layout with the new custom header, RepaintBoundary-wrapped FlutterMap
// (Review LOW #5), mono stat pair, StuckBar, TrafficInsightCard, and TripTimeline.
//
// The GPS-trip test inserts a trip with an empty polyline so _MapView renders
// the placeholder container instead of FlutterMap tiles (avoids OSM HTTP). The
// RepaintBoundary-around-FlutterMap assertion is verified separately using a
// non-empty polyline path where FlutterMap itself is instantiated.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/screens/trip_detail_screen.dart';
import 'package:traevy/features/trips/widgets/traffic_insight_card.dart';
import 'package:traevy/features/trips/widgets/trip_timeline.dart';
import 'package:traevy/shared/widgets/stuck_bar.dart';
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
          theme: buildLightTheme(),
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
          // Empty polyline — _MapView renders the placeholder container
          // instead of FlutterMap, avoiding OSM tile HTTP requests.
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
      await tester.pumpWidget(buildScreen('does-not-matter'));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows Trip not found for invalid id', (tester) async {
      await tester.pumpWidget(buildScreen('nonexistent-id'));
      await tester.pumpAndSettle();
      expect(find.text(kTripDetailNotFound), findsOneWidget);
    });

    testWidgets('uses custom back-arrow header instead of AppBar', (
      tester,
    ) async {
      final id = await insertGpsTrip();
      await tester.pumpWidget(buildScreen(id));
      await tester.pumpAndSettle();
      // New layout: back arrow icon button in custom header row.
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      // No AppBar widget in the tree.
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('GPS trip renders StuckBar, TrafficInsightCard, TripTimeline', (
      tester,
    ) async {
      final id = await insertGpsTrip();
      await tester.pumpWidget(buildScreen(id));
      await tester.pumpAndSettle();
      expect(find.byType(StuckBar), findsOneWidget);
      expect(find.byType(TrafficInsightCard), findsOneWidget);
      expect(find.byType(TripTimeline), findsOneWidget);
    });

    testWidgets('GPS trip renders duration value', (tester) async {
      final id = await insertGpsTrip();
      await tester.pumpWidget(buildScreen(id));
      await tester.pumpAndSettle();
      // 2700 seconds = 45 min
      expect(find.textContaining('45'), findsWidgets);
    });

    testWidgets('FlutterMap is wrapped in RepaintBoundary (Review LOW #5)', (
      tester,
    ) async {
      // Use a non-empty polyline so FlutterMap is instantiated (not the
      // placeholder container). Encoded polyline for a single LatLng point.
      final id = const Uuid().v4();
      final start = DateTime.utc(2026, 1, 1, 18);
      final end = DateTime.utc(2026, 1, 1, 18, 47);
      // Two-point encoded polyline: (38.5,-120.2) → (40.7,-120.95).
      // A single-point polyline causes CameraFit to throw (zero-area bounds).
      const encoded = '_p~iF~ps|U_ulLnnqC';
      await db.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: id,
          startTime: start,
          endTime: end,
          durationSeconds: 2820,
          distanceMeters: 6400,
          routePolyline: const Value(encoded),
          direction: kDirectionToHome,
          timeMovingSeconds: 1740,
          timeStuckSeconds: 1080,
          isManualEntry: const Value(false),
          createdAt: Value(start),
          updatedAt: Value(start),
        ),
      );
      await tester.pumpWidget(buildScreen(id));
      // Pump once to trigger postFrameCallback, once more for setState.
      await tester.pump();
      await tester.pump();
      // FlutterMap must exist in the tree.
      expect(find.byType(FlutterMap), findsOneWidget);
      // FlutterMap must have a RepaintBoundary ancestor (Review LOW #5).
      expect(
        find.ancestor(
          of: find.byType(FlutterMap),
          matching: find.byType(RepaintBoundary),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets(
      'manual trip hides map area and shows manual entry context',
      (tester) async {
        final id = await insertManualTrip();
        await tester.pumpWidget(buildScreen(id));
        await tester.pumpAndSettle();
        // Manual layout never instantiates FlutterMap.
        expect(find.byType(FlutterMap), findsNothing);
        // Manual trips have no stuck data so TrafficInsightCard is not shown.
        expect(find.byType(TrafficInsightCard), findsNothing);
      },
    );
  });
}
