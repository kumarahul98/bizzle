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
    directionSource: kDirectionSourceTime,
    timeMovingSeconds: 1500,
    timeStuckSeconds: 300,
    isManualEntry: false,
    isEdited: false,
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
    directionSource: kDirectionSourceManual,
    timeMovingSeconds: 0,
    timeStuckSeconds: 0,
    isManualEntry: true,
    isEdited: false,
    createdAt: DateTime.utc(2026, 5, 31, 18, 45, 1),
    updatedAt: DateTime.utc(2026, 5, 31, 18, 45, 2),
  );

  // A trip with edit/pause metadata set (Phase 26 fields non-default).
  TripRow editedPausedTrip() => TripRow(
    id: '44444444-4444-4444-8444-444444444444',
    userId: kDefaultUserId,
    startTime: DateTime.utc(2026, 5, 31, 8, 30),
    endTime: DateTime.utc(2026, 5, 31, 9, 30),
    durationSeconds: 3000,
    totalPausedSeconds: 600,
    distanceMeters: 12500.5,
    routePolyline: 'abc_polyline',
    direction: kDirectionToOffice,
    directionSource: kDirectionSourceManual,
    timeMovingSeconds: 2700,
    timeStuckSeconds: 300,
    isManualEntry: false,
    isEdited: true,
    createdAt: DateTime.utc(2026, 5, 31, 9, 0, 1),
    updatedAt: DateTime.utc(2026, 5, 31, 9, 0, 2),
  );

  /// Build [n] break rows for [tripId], ordered by `startTime` ascending
  /// (mirroring `TripBreaksDao.breaksForTripIds`/`breaksForTrip`'s ordering
  /// contract), starting at [base] and spaced 2 minutes apart, each 1 minute
  /// long.
  List<TripBreakRow> buildBreaks(String tripId, int n, {DateTime? base}) {
    final start = base ?? DateTime.utc(2026, 5, 31, 8, 40);
    return List<TripBreakRow>.generate(n, (i) {
      final s = start.add(Duration(minutes: i * 2));
      return TripBreakRow(
        id: 'break-$i',
        tripId: tripId,
        startTime: s,
        endTime: s.add(const Duration(minutes: 1)),
      );
    });
  }

  group('TripSerializer.toJson', () {
    test('produces exactly the zod tripSchema key set (Phase 26), minus '
        'userId', () {
      final json = TripSerializer.toJson(gpsTrip(), const []);

      expect(json.keys.toSet(), {
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
        'totalPausedSeconds',
        'isEdited',
        'directionSource',
        'breaks',
      });
      expect(json.containsKey('userId'), isFalse);
      // Phase 29 (LOC-03) guard: Home/Office coordinates sync on their OWN
      // endpoint, never as trip fields. This exact-set assertion is what makes
      // that structural — if a coord ever leaks into the trip payload, this
      // test fails rather than the leak shipping silently.
      expect(json.containsKey('homeLat'), isFalse);
      expect(json.containsKey('officeLat'), isFalse);
    });

    test('timestamps serialize as UTC ISO-8601 ending with Z', () {
      final json = TripSerializer.toJson(gpsTrip(), const []);

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
        directionSource: kDirectionSourceTime,
        timeMovingSeconds: 1800,
        timeStuckSeconds: 0,
        isManualEntry: false,
        isEdited: false,
        createdAt: localStart,
        updatedAt: localStart,
      );

      final json = TripSerializer.toJson(row, const []);

      expect((json['startTime']! as String).endsWith('Z'), isTrue);
      expect(
        DateTime.parse(json['startTime']! as String).toUtc(),
        localStart.toUtc(),
      );
    });

    test(
      'manual-entry serializes numerics as 0 (not null) and polyline null',
      () {
        final json = TripSerializer.toJson(manualTrip(), const []);

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
        TripSerializer.toJson(gpsTrip(), const [])['direction'],
        kDirectionToOffice,
      );
      expect(
        TripSerializer.toJson(manualTrip(), const [])['direction'],
        kDirectionToHome,
      );
    });

    // ---- Phase 26: metadata fields ----------------------------------------

    test(
      'toJson(trip, []) includes totalPausedSeconds/isEdited/directionSource '
      'and an empty breaks array',
      () {
        final json = TripSerializer.toJson(gpsTrip(), const []);

        expect(json['totalPausedSeconds'], 0);
        expect(json['isEdited'], false);
        expect(json['directionSource'], kDirectionSourceTime);
        expect(json['breaks'], isA<List<dynamic>>());
        expect(json['breaks'], isEmpty);
      },
    );

    test(
      'toJson emits non-default totalPausedSeconds/isEdited/directionSource '
      'unchanged',
      () {
        final json = TripSerializer.toJson(editedPausedTrip(), const []);

        expect(json['totalPausedSeconds'], 600);
        expect(json['isEdited'], true);
        expect(json['directionSource'], kDirectionSourceManual);
      },
    );

    // ---- Phase 26: breaks array --------------------------------------------

    test(
      'toJson(trip, [break1, break2]) emits a breaks array of '
      '{startTime, endTime} ISO-8601 UTC string maps, ordered as given',
      () {
        final breaks = buildBreaks('t', 2);
        final json = TripSerializer.toJson(gpsTrip(), breaks);

        final breaksJson = json['breaks']! as List<dynamic>;
        expect(breaksJson, hasLength(2));
        for (var i = 0; i < 2; i++) {
          final entry = breaksJson[i] as Map<String, dynamic>;
          expect(entry.keys.toSet(), {'startTime', 'endTime'});
          expect(
            entry['startTime'],
            breaks[i].startTime.toUtc().toIso8601String(),
          );
          expect(
            entry['endTime'],
            breaks[i].endTime!.toUtc().toIso8601String(),
          );
        }
      },
    );

    test(
      'toJson(trip, [51 breaks]) truncates to exactly kMaxBreaksPerTrip, '
      'keeping the FIRST 50 chronologically (oldest-first retention)',
      () {
        final breaks = buildBreaks('t', kMaxBreaksPerTrip + 1);
        final json = TripSerializer.toJson(gpsTrip(), breaks);

        final breaksJson = json['breaks']! as List<dynamic>;
        expect(breaksJson, hasLength(kMaxBreaksPerTrip));
        expect(
          (breaksJson.first as Map<String, dynamic>)['startTime'],
          breaks.first.startTime.toUtc().toIso8601String(),
        );
        expect(
          (breaksJson.last as Map<String, dynamic>)['startTime'],
          breaks[kMaxBreaksPerTrip - 1].startTime.toUtc().toIso8601String(),
        );
        // The 51st (last) break is dropped.
        expect(
          breaksJson.any(
            (e) =>
                (e as Map<String, dynamic>)['startTime'] ==
                breaks.last.startTime.toUtc().toIso8601String(),
          ),
          isFalse,
        );
      },
    );

    test(
      'toJson(trip, [exactly kMaxBreaksPerTrip breaks]) emits all of them '
      'unchanged (at-cap boundary, no off-by-one)',
      () {
        final breaks = buildBreaks('t', kMaxBreaksPerTrip);
        final json = TripSerializer.toJson(gpsTrip(), breaks);

        final breaksJson = json['breaks']! as List<dynamic>;
        expect(breaksJson, hasLength(kMaxBreaksPerTrip));
      },
    );

    test(
      'toJson skips open (null-endTime) breaks instead of throwing (WR-01)',
      () {
        // A stray open break should never reach a finalized trip, but if it
        // does, toJson must degrade it to "skipped" rather than throwing a
        // TypeError that escapes SyncEngine._drain's SyncException handler.
        final closed = buildBreaks('t', 1).single;
        // endTime omitted → null: the open-break case under test.
        final open = TripBreakRow(
          id: 'break-open',
          tripId: 't',
          startTime: DateTime.utc(2026, 5, 31, 8, 50),
        );

        final json = TripSerializer.toJson(gpsTrip(), [closed, open]);

        final breaksJson = json['breaks']! as List<dynamic>;
        expect(breaksJson, hasLength(1));
        expect(
          (breaksJson.single as Map<String, dynamic>)['startTime'],
          closed.startTime.toUtc().toIso8601String(),
        );
      },
    );
  });

  group('TripSerializer.fromJson', () {
    test('round-trips toJson(row, []) back into an equal ParsedTrip.trip', () {
      final row = gpsTrip();
      final parsed = TripSerializer.fromJson(
        TripSerializer.toJson(row, const []),
      );
      final companion = parsed.trip;

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
      expect(companion.totalPausedSeconds.value, row.totalPausedSeconds);
      expect(companion.isEdited.value, row.isEdited);
      expect(companion.directionSource.value, row.directionSource);
      expect(parsed.breaks, isEmpty);
    });

    test('does NOT set userId even when the server JSON includes it', () {
      // Server restore payload includes userId; the client must ignore it.
      final json = TripSerializer.toJson(gpsTrip(), const [])
        ..['userId'] = 'server-uid-should-be-ignored';

      final parsed = TripSerializer.fromJson(json);

      expect(parsed.trip.userId.present, isFalse);
    });

    test('parses ISO timestamps into UTC DateTimes', () {
      final json = TripSerializer.toJson(manualTrip(), const []);

      final parsed = TripSerializer.fromJson(json);

      expect(parsed.trip.startTime.value.isUtc, isTrue);
      expect(parsed.trip.startTime.value, manualTrip().startTime);
    });

    // ---- Phase 26: metadata + breaks parsing -------------------------------

    test(
      'fromJson on a payload WITH all 4 new fields + 2 breaks returns '
      '.trip with Value(...)-set metadata and .breaks of length 2 with '
      'fresh, non-colliding UUIDs and matching tripId',
      () {
        final row = editedPausedTrip();
        final breaks = buildBreaks(row.id, 2);
        final json = TripSerializer.toJson(row, breaks);

        final parsed = TripSerializer.fromJson(json);

        expect(parsed.trip.totalPausedSeconds.value, 600);
        expect(parsed.trip.isEdited.value, true);
        expect(parsed.trip.directionSource.value, kDirectionSourceManual);

        expect(parsed.breaks, hasLength(2));
        final ids = parsed.breaks.map((b) => b.id.value).toSet();
        expect(ids, hasLength(2)); // non-colliding
        for (final id in ids) {
          expect(id, isNotEmpty);
        }
        for (final b in parsed.breaks) {
          expect(b.tripId.value, row.id);
        }
        expect(
          parsed.breaks[0].startTime.value,
          breaks[0].startTime.toUtc(),
        );
        expect(parsed.breaks[0].endTime.value, breaks[0].endTime!.toUtc());
      },
    );

    test(
      'fromJson on a payload OMITTING all 4 new keys returns .trip with '
      'totalPausedSeconds=0, isEdited=false, directionSource=time and '
      '.breaks = []',
      () {
        // Legacy-shape payload (pre-Phase-26 server or old-client emission):
        // no totalPausedSeconds/isEdited/directionSource/breaks keys at all.
        final json = <String, dynamic>{
          'id': 'legacy-1',
          'startTime': '2026-05-01T08:00:00.000Z',
          'endTime': '2026-05-01T08:30:00.000Z',
          'durationSeconds': 1800,
          'distanceMeters': 12000.0,
          'routePolyline': null,
          'direction': 'to_office',
          'timeMovingSeconds': 1200,
          'timeStuckSeconds': 600,
          'isManualEntry': false,
          'createdAt': '2026-05-01T08:30:00.000Z',
          'updatedAt': '2026-05-01T08:30:00.000Z',
        };

        final parsed = TripSerializer.fromJson(json);

        expect(parsed.trip.totalPausedSeconds.value, 0);
        expect(parsed.trip.isEdited.value, false);
        expect(parsed.trip.directionSource.value, kDirectionSourceTime);
        expect(parsed.breaks, isEmpty);
      },
    );

    test(
      'fromJson on a payload with exactly kMaxBreaksPerTrip break entries '
      'parses all of them without loss',
      () {
        final row = gpsTrip();
        final breaks = buildBreaks(row.id, kMaxBreaksPerTrip);
        final json = TripSerializer.toJson(row, breaks);

        final parsed = TripSerializer.fromJson(json);

        expect(parsed.breaks, hasLength(kMaxBreaksPerTrip));
      },
    );
  });
}
