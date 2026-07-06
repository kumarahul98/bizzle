import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/features/trips/services/geofence_backfill_service.dart';
import 'package:traevy/features/trips/services/geofence_direction_resolver.dart';
import 'package:traevy/shared/utils/polyline_codec.dart';

void main() {
  group('GeofenceBackfillService', () {
    late AppDatabase db;
    late TripsDao tripsDao;
    late UserPreferencesDao prefsDao;
    late GeofenceBackfillService service;

    // Bengaluru constants for tests
    const homeLat = 12.9716;
    const homeLng = 77.5946;
    const officeLat = 12.9352;
    const officeLng = 77.6245;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      tripsDao = TripsDao(db);
      prefsDao = UserPreferencesDao(db);
      service = GeofenceBackfillService(
        tripsDao: tripsDao,
        prefsDao: prefsDao,
        resolver: const GeofenceDirectionResolver(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('SC#5: returns 0 and does nothing if no locations are set', () async {
      await tripsDao
          .into(tripsDao.trips)
          .insert(
            TripsCompanion.insert(
              id: 'trip1',
              userId: const Value(kDefaultUserId),
              startTime: DateTime.now().toUtc(),
              endTime: DateTime.now().toUtc(),
              durationSeconds: 600,
              distanceMeters: 1000,
              direction: kDirectionUnknown,
              timeMovingSeconds: 600,
              timeStuckSeconds: 0,
              routePolyline: const Value('test_polyline'),
              directionSource: const Value(kDirectionSourceTime),
            ),
          );

      final result = await service.run();

      expect(result, 0);
      final updatedTrip = await tripsDao.findById('trip1');
      expect(updatedTrip?.direction, kDirectionUnknown);
      expect(updatedTrip?.directionSource, kDirectionSourceTime);
    });

    test('T-21-03-01: manual trips are skipped entirely', () async {
      await prefsDao.setHomeLocation(homeLat, homeLng);

      // Start somewhere else, end exactly at home
      final polyline = encodePolyline([
        (lat: 12.0, lng: 77.0),
        (lat: homeLat, lng: homeLng),
      ]);

      await tripsDao
          .into(tripsDao.trips)
          .insert(
            TripsCompanion.insert(
              id: 'manual_trip',
              userId: const Value(kDefaultUserId),
              startTime: DateTime.now().toUtc(),
              endTime: DateTime.now().toUtc(),
              durationSeconds: 600,
              distanceMeters: 1000,
              direction: kDirectionToOffice, // User manually set to office
              timeMovingSeconds: 600,
              timeStuckSeconds: 0,
              routePolyline: Value(polyline),
              directionSource: const Value(kDirectionSourceManual),
            ),
          );

      final result = await service.run();

      expect(result, 0); // Not processed
      final updatedTrip = await tripsDao.findById('manual_trip');
      expect(updatedTrip?.direction, kDirectionToOffice); // Untouched
      expect(updatedTrip?.directionSource, kDirectionSourceManual); // Untouched
    });

    test('manual_entry trips (no polyline) are skipped', () async {
      await prefsDao.setHomeLocation(homeLat, homeLng);

      await tripsDao
          .into(tripsDao.trips)
          .insert(
            TripsCompanion.insert(
              id: 'manual_entry_trip',
              userId: const Value(kDefaultUserId),
              startTime: DateTime.now().toUtc(),
              endTime: DateTime.now().toUtc(),
              durationSeconds: 600,
              distanceMeters: 1000,
              direction: kDirectionUnknown,
              timeMovingSeconds: 600,
              timeStuckSeconds: 0,
              isManualEntry: const Value(true),
              routePolyline: const Value.absent(), // No polyline
              directionSource: const Value(kDirectionSourceTime),
            ),
          );

      final result = await service.run();

      expect(result, 0);
      final updatedTrip = await tripsDao.findById('manual_entry_trip');
      expect(updatedTrip?.direction, kDirectionUnknown);
    });

    test('SC#2: trips ending near Home are relabelled to_home', () async {
      await prefsDao.setHomeLocation(homeLat, homeLng);

      // End exactly at home
      final polyline = encodePolyline([
        (lat: 12.0, lng: 77.0),
        (lat: homeLat, lng: homeLng),
      ]);

      await tripsDao
          .into(tripsDao.trips)
          .insert(
            TripsCompanion.insert(
              id: 'home_trip',
              userId: const Value(kDefaultUserId),
              startTime: DateTime.now().toUtc(),
              endTime: DateTime.now().toUtc(),
              durationSeconds: 600,
              distanceMeters: 1000,
              direction: kDirectionUnknown, // Was unknown or time-based
              timeMovingSeconds: 600,
              timeStuckSeconds: 0,
              routePolyline: Value(polyline),
              directionSource: const Value(kDirectionSourceTime),
            ),
          );

      final result = await service.run();

      expect(result, 1);
      final updatedTrip = await tripsDao.findById('home_trip');
      expect(updatedTrip?.direction, kDirectionToHome);
      expect(updatedTrip?.directionSource, kDirectionSourceGeofence);
    });

    test('SC#2: trips ending near Office are relabelled to_office', () async {
      await prefsDao.setOfficeLocation(officeLat, officeLng);

      // End exactly at office
      final polyline = encodePolyline([
        (lat: 12.0, lng: 77.0),
        (lat: officeLat, lng: officeLng),
      ]);

      await tripsDao
          .into(tripsDao.trips)
          .insert(
            TripsCompanion.insert(
              id: 'office_trip',
              userId: const Value(kDefaultUserId),
              startTime: DateTime.now().toUtc(),
              endTime: DateTime.now().toUtc(),
              durationSeconds: 600,
              distanceMeters: 1000,
              direction: kDirectionUnknown,
              timeMovingSeconds: 600,
              timeStuckSeconds: 0,
              routePolyline: Value(polyline),
              directionSource: const Value(kDirectionSourceTime),
            ),
          );

      final result = await service.run();

      expect(result, 1);
      final updatedTrip = await tripsDao.findById('office_trip');
      expect(updatedTrip?.direction, kDirectionToOffice);
      expect(updatedTrip?.directionSource, kDirectionSourceGeofence);
    });

    test('SC#3: non-matching trips are left untouched', () async {
      await prefsDao.setHomeLocation(homeLat, homeLng);

      // End far away from home
      final polyline = encodePolyline([
        (lat: 12.0, lng: 77.0),
        (lat: 12.1, lng: 77.1),
      ]);

      await tripsDao
          .into(tripsDao.trips)
          .insert(
            TripsCompanion.insert(
              id: 'far_trip',
              userId: const Value(kDefaultUserId),
              startTime: DateTime.now().toUtc(),
              endTime: DateTime.now().toUtc(),
              durationSeconds: 600,
              distanceMeters: 1000,
              direction: kDirectionToOffice, // Had a time-based label
              timeMovingSeconds: 600,
              timeStuckSeconds: 0,
              routePolyline: Value(polyline),
              directionSource: const Value(kDirectionSourceTime),
            ),
          );

      final result = await service.run();

      expect(result, 0); // Not relabelled
      final updatedTrip = await tripsDao.findById('far_trip');
      expect(updatedTrip?.direction, kDirectionToOffice); // Untouched
      expect(updatedTrip?.directionSource, kDirectionSourceTime); // Untouched
    });

    test('idempotency: running again produces zero changes', () async {
      await prefsDao.setHomeLocation(homeLat, homeLng);

      final polyline = encodePolyline([
        (lat: 12.0, lng: 77.0),
        (lat: homeLat, lng: homeLng),
      ]);

      await tripsDao
          .into(tripsDao.trips)
          .insert(
            TripsCompanion.insert(
              id: 'idempotent_trip',
              userId: const Value(kDefaultUserId),
              startTime: DateTime.now().toUtc(),
              endTime: DateTime.now().toUtc(),
              durationSeconds: 600,
              distanceMeters: 1000,
              direction: kDirectionUnknown,
              timeMovingSeconds: 600,
              timeStuckSeconds: 0,
              routePolyline: Value(polyline),
              directionSource: const Value(kDirectionSourceTime),
            ),
          );

      // First run should process it
      final result1 = await service.run();
      expect(result1, 1);

      // Second run should return 0 (idempotent, no changes)
      final result2 = await service.run();
      expect(result2, 0);
    });
  });
}
