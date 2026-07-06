import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/features/tracking/services/trip_state_persister.dart';

void main() {
  group('TripStatePersister', () {
    late Directory tempDir;
    late TripStatePersister persister;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('trip_state_persister_test');
      persister = TripStatePersister(
        directoryProvider: () async => tempDir,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('loadState returns null when no file exists', () async {
      final state = await persister.loadState();
      expect(state, isNull);
    });

    test('saveState writes to file and loadState reads it', () async {
      final data = {'tripId': '1234', 'distance': 5.0};
      await persister.saveState(data);

      final state = await persister.loadState();
      expect(state, isNotNull);
      expect(state!['tripId'], '1234');
      expect(state['distance'], 5.0);
    });

    test('clear removes the file', () async {
      final data = {'tripId': '1234', 'distance': 5.0};
      await persister.saveState(data);
      
      var state = await persister.loadState();
      expect(state, isNotNull);

      await persister.clear();

      state = await persister.loadState();
      expect(state, isNull);
    });
  });
}
