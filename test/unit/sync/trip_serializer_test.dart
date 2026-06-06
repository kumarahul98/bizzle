import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/sync/trip_serializer.dart';

void main() {
  // A representative GPS-recorded trip with a polyline and non-zero metrics.
  TripRow gpsTrip() => TripRow(
    id: '11111111-1111-4111-8111-111111111111',
    userId: kDefaultUserId,
    startTime: DateTime.utc(2026, 5, 31, 8, 30),
    endTime: DateTime.utc(2026, 5, 31, 9),
    durationSeconds: 1800,
    totalPausedSeconds: 0,
    distanceMeters: 12500.5,
    routePolyline: 'abc_polyline',
    direction: kDirectionToOffice,
    timeMovingSeconds: 1500,
    timeStuckSeconds: 300,
    isManualEntry: false,
    createdAt: DateTime.utc(2026, 5, 31, 9, 0, 1),
    updatedAt: DateTime.utc(2026, 5, 31, 9, 0, 2),
  );

  // A manually-entered trip: no GPS, so the numeric fields are 0 and the
  // polyline is null. Mirrors the bug-manual-entry note (Pitfall 7).
  TripRow manualTrip() => TripRow(
    id: '22222222-2222-4222-8222-222222222222',
    userId: kDefaultUserId,
    startTime: DateTime.utc(2026, 5, 31, 18),
    endTime: DateTime.utc(2026, 5, 31, 18, 45),
    durationSeconds: 0,
    totalPausedSeconds: 0,
    distanceMeters: 0,
    direction: kDirectionToHome,
    timeMovingSeconds: 0,
    timeStuckSeconds: 0,
    isManualEntry: true,
    createdAt: DateTime.utc(2026, 5, 31, 18, 45, 1),
    updatedAt: DateTime.utc(2026, 5, 31, 18, 45, 2),
  );

  group('TripSerializer.toJson', () {
    test('produces exactly the zod tripSchema key set, minus userId', () {
      final json = TripSerializer.toJson(gpsTrip());

      expect(
        json.keys.toSet(),
        {
          'id',
          'startTime',
          'endTime',
          'durationSeconds',
          'distanceMeters',
          'routePolyline',
          'direction',
          'timeMovingSeconds',
          'timeStuckSeconds',
          'isManualEntry',
          'createdAt',
          'updatedAt',
        },
      );
      expect(json.containsKey('userId'), isFalse);
    });

    test('timestamps serialize as UTC ISO-8601 ending with Z', () {
      final json = TripSerializer.toJson(gpsTrip());

      for (final key in ['startTime', 'endTime', 'createdAt', 'updatedAt']) {
        expect(json[key], isA<String>());
        expect(
          (json[key]! as String).endsWith('Z'),
          isTrue,
          reason: '$key must end with Z',
        );
      }
    });

    test('a non-UTC input DateTime still emits a Z-suffixed UTC string', () {
      final localStart = DateTime(2026, 5, 31, 8, 30); // local kind
      final row = TripRow(
        id: '33333333-3333-4333-8333-333333333333',
        userId: kDefaultUserId,
        startTime: localStart,
        endTime: localStart.add(const Duration(minutes: 30)),
        durationSeconds: 1800,
        totalPausedSeconds: 0,
        distanceMeters: 100,
        direction: kDirectionToOffice,
        timeMovingSeconds: 1800,
        timeStuckSeconds: 0,
        isManualEntry: false,
        createdAt: localStart,
        updatedAt: localStart,
      );

      final json = TripSerializer.toJson(row);

      expect((json['startTime']! as String).endsWith('Z'), isTrue);
      expect(
        DateTime.parse(json['startTime']! as String).toUtc(),
        localStart.toUtc(),
      );
    });

    test(
      'manual-entry serializes numerics as 0 (not null) and polyline null',
      () {
        final json = TripSerializer.toJson(manualTrip());

        expect(json['durationSeconds'], 0);
        expect(json['distanceMeters'], 0);
        expect(json['timeMovingSeconds'], 0);
        expect(json['timeStuckSeconds'], 0);
        expect(json['routePolyline'], isNull);
        // The numeric fields are present and numeric, never null.
        expect(json['durationSeconds'], isA<num>());
        expect(json['distanceMeters'], isA<num>());
      },
    );

    test('direction passes through unchanged as the stored literal', () {
      expect(
        TripSerializer.toJson(gpsTrip())['direction'],
        kDirectionToOffice,
      );
      expect(
        TripSerializer.toJson(manualTrip())['direction'],
        kDirectionToHome,
      );
    });
  });

  group('TripSerializer.fromJson', () {
    test('round-trips toJson(row) back into an equal TripsCompanion', () {
      final row = gpsTrip();
      final companion = TripSerializer.fromJson(TripSerializer.toJson(row));

      expect(companion.id.value, row.id);
      expect(companion.startTime.value, row.startTime);
      expect(companion.endTime.value, row.endTime);
      expect(companion.durationSeconds.value, row.durationSeconds);
      expect(companion.distanceMeters.value, row.distanceMeters);
      expect(companion.routePolyline.value, row.routePolyline);
      expect(companion.direction.value, row.direction);
      expect(companion.timeMovingSeconds.value, row.timeMovingSeconds);
      expect(companion.timeStuckSeconds.value, row.timeStuckSeconds);
      expect(companion.isManualEntry.value, row.isManualEntry);
      expect(companion.createdAt.value, row.createdAt);
      expect(companion.updatedAt.value, row.updatedAt);
    });

    test('does NOT set userId even when the server JSON includes it', () {
      // Server restore payload includes userId; the client must ignore it.
      final json = TripSerializer.toJson(gpsTrip())
        ..['userId'] = 'server-uid-should-be-ignored';

      final companion = TripSerializer.fromJson(json);

      expect(companion.userId.present, isFalse);
    });

    test('parses ISO timestamps into UTC DateTimes', () {
      final json = TripSerializer.toJson(manualTrip());

      final companion = TripSerializer.fromJson(json);

      expect(companion.startTime.value.isUtc, isTrue);
      expect(companion.startTime.value, manualTrip().startTime);
    });
  });
}
