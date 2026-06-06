import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/features/tracking/services/tracking_event_source.dart';
import 'package:traevy/features/tracking/services/tracking_notification_service.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/state/finalized_trip.dart';
import 'package:traevy/features/trips/services/direction_label_service.dart';
import 'package:traevy/shared/utils/polyline_codec.dart';

/// Phase 21 (D-09/D-10): finalize applies `override ?? geofence ?? time` and
/// records the winning path in `trips.direction_source`.
///
///   * END within radius of Office → direction=to_office, source=geofence.
///   * Endpoints far from both anchors → time auto-label, source=time.
///   * directionOverride set → override wins, source=manual (beats geofence).
///   * Empty polyline (no endpoints) → time fallback, source=time.

/// Minimal [TrackingEventSource] — never emits; satisfies the controller ctor.
class _FakeTrackingEventSource implements TrackingEventSource {
  @override
  Stream<Map<String, dynamic>?> get onState =>
      const Stream<Map<String, dynamic>?>.empty();

  @override
  Stream<Map<String, dynamic>?> get onFinalized =>
      const Stream<Map<String, dynamic>?>.empty();

  @override
  Stream<Map<String, dynamic>?> get onError =>
      const Stream<Map<String, dynamic>?>.empty();

  @override
  Stream<Map<String, dynamic>?> get onReady =>
      const Stream<Map<String, dynamic>?>.empty();

  @override
  Stream<Map<String, dynamic>?> get onAutoPausePrompt =>
      const Stream<Map<String, dynamic>?>.empty();

  @override
  Future<bool> start() async => true;

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}
}

/// No-op notifications fake — swallows every call.
class _NoopNotifications implements TrackingNotificationService {
  @override
  Future<void> dismiss() async {}

  @override
  Future<void> showRecording({
    int elapsedSeconds = 0,
    double distanceMeters = 0,
    int timeStuckSeconds = 0,
    String direction = kDirectionToOffice,
  }) async {}

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Bengaluru-scale fixtures, Home and Office ~4.5 km apart.
const ({double lat, double lng}) _home = (lat: 12.9716, lng: 77.5946);
const ({double lat, double lng}) _office = (lat: 12.9352, lng: 77.6245);
const ({double lat, double lng}) _nearHome = (lat: 12.97205, lng: 77.5946);
const ({double lat, double lng}) _nearOffice = (lat: 12.93565, lng: 77.6245);
const ({double lat, double lng}) _farA = (lat: 13.05, lng: 77.70);
const ({double lat, double lng}) _farB = (lat: 13.06, lng: 77.71);

FinalizedTrip _buildTrip({
  required String id,
  required String encodedPolyline,
}) {
  final start = DateTime.utc(2026, 4, 12, 8);
  return FinalizedTrip(
    id: id,
    startTime: start,
    endTime: start.add(const Duration(seconds: 600)),
    durationSeconds: 600,
    distanceMeters: 5000,
    timeMovingSeconds: 540,
    timeStuckSeconds: 60,
    encodedPolyline: encodedPolyline,
  );
}

/// The time-of-day auto-label the production path would derive for this trip,
/// using the schema-default cutoffs (timezone-independent).
String _autoLabel(DateTime startUtc) => const DirectionLabelService().label(
  startUtc.toLocal(),
  kDefaultDirectionCutoffHour,
  kDefaultDirectionCutoffHour,
);

void main() {
  group('persistFinalizedTrip geofence + direction_source (D-09/D-10)', () {
    late AppDatabase db;
    late TrackingServiceController controller;

    setUp(() async {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      controller = TrackingServiceController(
        source: _FakeTrackingEventSource(),
        database: db,
        tripsDao: db.tripsDao,
        syncQueueDao: db.syncQueueDao,
        notifications: _NoopNotifications(),
        userPreferencesDao: db.userPreferencesDao,
        tripBreaksDao: db.tripBreaksDao,
      );
      // Seed Home + Office coords so the geofence path is active.
      await db.userPreferencesDao.upsert(
        UserPreferencesValue(
          userId: kDefaultUserId,
          darkMode: kDarkModeSystem,
          morningCutoffHour: kDefaultDirectionCutoffHour,
          eveningCutoffHour: kDefaultDirectionCutoffHour,
          reminderEnabled: false,
          reminderTime: null,
          weekendReminder: false,
          weeklyNotificationEnabled: false,
          autoPauseEnabled: false,
          hasSeenOnboarding: true,
          homeLat: _home.lat,
          homeLng: _home.lng,
          officeLat: _office.lat,
          officeLng: _office.lng,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<String> readSource(String tripId) async {
      final row = await db
          .customSelect(
            'SELECT direction_source FROM trips WHERE id = ?',
            variables: [Variable<String>(tripId)],
          )
          .getSingle();
      return row.read<String>('direction_source');
    }

    test('END near Office → direction=to_office, source=geofence', () async {
      final polyline = encodePolyline([_nearHome, _nearOffice]);
      final trip = _buildTrip(id: 'geo-office', encodedPolyline: polyline);

      final result = await controller.persistFinalizedTrip(trip);

      expect(result, isA<PersistSaved>());
      final row = await db.tripsDao.findById('geo-office');
      expect(row!.direction, kDirectionToOffice);
      expect(await readSource('geo-office'), kDirectionSourceGeofence);
    });

    test('END near Home → direction=to_home, source=geofence', () async {
      final polyline = encodePolyline([_nearOffice, _nearHome]);
      final trip = _buildTrip(id: 'geo-home', encodedPolyline: polyline);

      final result = await controller.persistFinalizedTrip(trip);

      expect(result, isA<PersistSaved>());
      final row = await db.tripsDao.findById('geo-home');
      expect(row!.direction, kDirectionToHome);
      expect(await readSource('geo-home'), kDirectionSourceGeofence);
    });

    test('endpoints far from both → time auto-label, source=time', () async {
      final polyline = encodePolyline([_farA, _farB]);
      final trip = _buildTrip(id: 'geo-time', encodedPolyline: polyline);

      final result = await controller.persistFinalizedTrip(trip);

      expect(result, isA<PersistSaved>());
      final row = await db.tripsDao.findById('geo-time');
      expect(row!.direction, _autoLabel(trip.startTime));
      expect(await readSource('geo-time'), kDirectionSourceTime);
    });

    test(
      'directionOverride set → override wins, source=manual (beats geofence)',
      () async {
        // Endpoints near Office (would geofence to to_office), but the user
        // overrode to to_home — the manual choice must win and stamp manual.
        final polyline = encodePolyline([_nearHome, _nearOffice]);
        final trip = _buildTrip(id: 'geo-manual', encodedPolyline: polyline);

        final result = await controller.persistFinalizedTrip(
          trip,
          directionOverride: kDirectionToHome,
        );

        expect(result, isA<PersistSaved>());
        final row = await db.tripsDao.findById('geo-manual');
        expect(row!.direction, kDirectionToHome);
        expect(await readSource('geo-manual'), kDirectionSourceManual);
      },
    );

    test('empty polyline → time fallback, source=time', () async {
      final trip = _buildTrip(id: 'geo-empty', encodedPolyline: '');

      final result = await controller.persistFinalizedTrip(trip);

      expect(result, isA<PersistSaved>());
      final row = await db.tripsDao.findById('geo-empty');
      expect(row!.direction, _autoLabel(trip.startTime));
      expect(await readSource('geo-empty'), kDirectionSourceTime);
    });
  });
}
