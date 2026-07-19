import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/features/tracking/services/pending_trip_store.dart';

void main() {
  group('PendingTripStore (WR-05)', () {
    late Directory tempDir;
    late PendingTripStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'pending_trip_store_test',
      );
      store = PendingTripStore(directoryProvider: () async => tempDir);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('load returns null when nothing is pending', () async {
      expect(await store.load(), isNull);
    });

    test('save then load round-trips the payload', () async {
      await store.save({'id': 'trip-uuid-1', 'durationSeconds': 900});

      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!['id'], 'trip-uuid-1');
      expect(loaded['durationSeconds'], 900);
    });

    test('clear removes the pending trip', () async {
      await store.save({'id': 'trip-uuid-1'});
      expect(await store.load(), isNotNull);

      await store.clear();
      expect(await store.load(), isNull);
    });

    test('clear is a no-op when nothing is pending', () async {
      // Must not throw — the controller clears unconditionally on every
      // terminal outcome, including trips that never wrote a pending slot
      // (e.g. the iOS main-isolate engine).
      await expectLater(store.clear(), completes);
    });

    test('save overwrites a previous pending trip', () async {
      await store.save({'id': 'first'});
      await store.save({'id': 'second'});

      final loaded = await store.load();
      expect(loaded!['id'], 'second');
    });

    test(
      'load returns null on a corrupt payload rather than throwing',
      () async {
        // Recovery runs during app start-up: a throw here would break launch.
        await File(
          '${tempDir.path}/pending_trip.json',
        ).writeAsString('{not valid json');

        expect(await store.load(), isNull);
      },
    );

    test('save leaves no .tmp file behind', () async {
      await store.save({'id': 'trip-uuid-1'});

      final leftovers = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'))
          .toList();
      expect(
        leftovers,
        isEmpty,
        reason: 'the temp file must be renamed over the target, not orphaned',
      );
    });

    test(
      'a save interrupted mid-write cannot corrupt the previous trip',
      () async {
        // Simulates the atomicity guarantee: the target file is only ever
        // replaced by a complete document via rename. A partially written .tmp
        // sitting alongside it must not affect what load() returns.
        await store.save({'id': 'good-trip'});
        await File(
          '${tempDir.path}/pending_trip.json.tmp',
        ).writeAsString('{"id": "half-writ');

        final loaded = await store.load();
        expect(loaded!['id'], 'good-trip');
      },
    );

    test('payload survives a full FinalizedTrip-shaped map', () async {
      // Guards the jsonEncode round trip against the real payload shape,
      // including the nested primitive break list crossing the isolate
      // boundary (D-07 / T-18-05).
      final tripMap = <String, Object?>{
        'id': 'uuid-v4',
        'startTime': DateTime.utc(2026, 7, 19, 8).microsecondsSinceEpoch,
        'endTime': DateTime.utc(2026, 7, 19, 8, 45).microsecondsSinceEpoch,
        'durationSeconds': 2700,
        'distanceMeters': 18450.5,
        'timeMovingSeconds': 1800,
        'timeStuckSeconds': 900,
        'totalPausedSeconds': 0,
        'encodedPolyline': '_p~iF~ps|U_ulLnnqC',
        'breaks': <Map<String, Object?>>[
          {'startUs': 1000, 'endUs': 2000},
        ],
      };

      await store.save(tripMap);
      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!['id'], 'uuid-v4');
      expect(loaded['distanceMeters'], 18450.5);
      expect(loaded['encodedPolyline'], '_p~iF~ps|U_ulLnnqC');
      final breaks = (loaded['breaks']! as List).cast<Map<String, Object?>>();
      expect(breaks.single['startUs'], 1000);
      // The decoded document must be byte-identical in meaning to the input.
      expect(jsonEncode(loaded), jsonEncode(tripMap));
    });
  });
}
