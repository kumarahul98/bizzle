// Regression test for PERSIST-INJECT-FIX / TRACK-13.
//
// The bug: `TripStatePersister` was never injected into `TripAccumulator` at
// any production construction site, so `_persistState()` always early-returned
// on its null-persister guard. `active_trip.json` was never written during a
// real trip, so interrupted-trip recovery could never fire.
//
// The existing accumulator suite passed because it never persisted at all
// (no persister injected). These tests construct a PRODUCTION-SHAPED
// accumulator — a real `TripStatePersister` wired in exactly as the fixed
// call sites now do — and prove the file is actually written on sample intake
// and on pause/resume state transitions, then removed on finalize.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/features/tracking/services/trip_accumulator.dart';
import 'package:traevy/features/tracking/services/trip_state_persister.dart';

/// Build a real `geolocator` [Position] for tests. Using the real class (not a
/// mock) catches API drift, mirroring `trip_accumulator_test.dart`.
Position _pos({
  required double lat,
  required double lng,
  required double speedMs,
  required DateTime timestamp,
  double accuracy = 5,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: timestamp,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speedMs,
    speedAccuracy: 0,
  );
}

/// `_persistState` fires-and-forgets the write (`unawaited(saveState(...))`),
/// so let the event loop flush the async file IO before asserting.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  final start = DateTime.utc(2026, 1, 1, 8);

  group('TripAccumulator persistence (production wiring)', () {
    late Directory tempDir;
    late File stateFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'trip_accumulator_persistence_test',
      );
      stateFile = File('${tempDir.path}/active_trip.json');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    // A real persister pointed at a temp dir — the production-shaped
    // dependency the buggy call sites failed to pass.
    TripStatePersister buildPersister() =>
        TripStatePersister(directoryProvider: () async => tempDir);

    test(
      'addSample writes a non-empty active_trip.json',
      () async {
        final acc = TripAccumulator(
          startedAt: start,
          persister: buildPersister(),
        );

        acc.addSample(
          _pos(lat: 37.7749, lng: -122.4194, speedMs: 5, timestamp: start),
        );
        await _settle();

        expect(stateFile.existsSync(), isTrue);
        expect(stateFile.readAsStringSync(), isNotEmpty);
      },
    );

    test(
      'pause+resume state transition keeps active_trip.json present',
      () async {
        final acc = TripAccumulator(
          startedAt: start,
          persister: buildPersister(),
        );

        acc.addSample(
          _pos(lat: 37.7749, lng: -122.4194, speedMs: 5, timestamp: start),
        );
        acc.pause(start.add(const Duration(seconds: 5)));
        acc.resume(start.add(const Duration(seconds: 15)));
        await _settle();

        expect(stateFile.existsSync(), isTrue);
        expect(stateFile.readAsStringSync(), isNotEmpty);
      },
    );

    test(
      'finalize clears active_trip.json (Phase 25 SC#5 clean-stop)',
      () async {
        final acc = TripAccumulator(
          startedAt: start,
          persister: buildPersister(),
        );

        acc.addSample(
          _pos(lat: 37.7749, lng: -122.4194, speedMs: 5, timestamp: start),
        );
        await _settle();
        expect(stateFile.existsSync(), isTrue);

        acc.finalize(start.add(const Duration(seconds: 30)));
        await _settle();

        expect(stateFile.existsSync(), isFalse);
      },
    );

    // Guard test documenting the regression itself: without an injected
    // persister (the OLD, buggy production wiring) NOTHING is ever written,
    // because `_persistState()` early-returns on its null-persister guard.
    // If a future refactor makes persistence depend on injection again,
    // this contrast keeps the failure visible.
    test(
      'no persister injected → nothing is written (documents the bug)',
      () async {
        final acc = TripAccumulator(startedAt: start);

        acc.addSample(
          _pos(lat: 37.7749, lng: -122.4194, speedMs: 5, timestamp: start),
        );
        acc.pause(start.add(const Duration(seconds: 5)));
        acc.resume(start.add(const Duration(seconds: 15)));
        await _settle();

        expect(stateFile.existsSync(), isFalse);
      },
    );
  });
}
