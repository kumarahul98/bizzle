// Wave 0 stub tests for TripDetailScreen (HIST-03).
//
// These stubs compile and pass immediately (via markTestSkipped) so the test
// runner stays green before TripDetailScreen exists. Wave 2 implements the
// screen in lib/features/trips/screens/trip_detail_screen.dart and
// uncomments the import below, then fills these stubs in with real
// assertions. The makeGpsTrip helper builds a TripsCompanion with the
// canonical Google polyline reference so map rendering tests have a known
// route to assert against.
//
// Do NOT import TripDetailScreen — it does not exist yet and importing it
// would fail compilation.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/database.dart';
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

    // Helper kept for Wave 2 use; stubs do not yet invoke it.
    // ignore: unused_element
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

    // Helper kept for Wave 2 use; stubs do not yet invoke it.
    // ignore: unused_element
    TripsCompanion makeGpsTrip({String routePolyline = '_p~iF~ps|U'}) {
      final start = DateTime.utc(2026, 1, 1, 8);
      final end = DateTime.utc(2026, 1, 1, 9);
      return TripsCompanion.insert(
        id: const Uuid().v4(),
        userId: const Value(''),
        startTime: start,
        endTime: end,
        durationSeconds: 3600,
        distanceMeters: 1240,
        routePolyline: Value(routePolyline),
        direction: kDirectionToOffice,
        timeMovingSeconds: 3000,
        timeStuckSeconds: 600,
        isManualEntry: const Value(false),
        createdAt: Value(start),
        updatedAt: Value(start),
      );
    }

    testWidgets('shows CircularProgressIndicator while loading', (
      tester,
    ) async {
      markTestSkipped('Wave 2: implement TripDetailScreen loading state first');
    });

    testWidgets('shows Trip not found for invalid id', (tester) async {
      markTestSkipped(
        'Wave 2: implement TripDetailScreen not-found state first',
      );
    });

    testWidgets('manual trip hides map and shows Manually entered badge', (
      tester,
    ) async {
      markTestSkipped('Wave 2: implement TripDetailScreen manual mode first');
    });

    testWidgets('GPS trip shows all six stat rows', (tester) async {
      markTestSkipped('Wave 2: implement TripDetailScreen stat rows first');
    });
  });
}
