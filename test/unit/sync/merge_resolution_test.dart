import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/sync/merge_resolution.dart';

TripRow _local({
  String id = 'trip1',
  DateTime? startTime,
  DateTime? endTime,
  int durationSeconds = 100,
  double distanceMeters = 1000.0,
  String direction = 'to_office',
  String directionSource = 'time',
  int totalPausedSeconds = 0,
  bool isEdited = false,
}) => TripRow(
  id: id,
  userId: 'user',
  startTime: startTime ?? DateTime.utc(2026, 5, 1, 8),
  endTime: endTime ?? DateTime.utc(2026, 5, 1, 8, 30),
  durationSeconds: durationSeconds,
  totalPausedSeconds: totalPausedSeconds,
  distanceMeters: distanceMeters,
  routePolyline: null,
  direction: direction,
  directionSource: directionSource,
  timeMovingSeconds: 1200,
  timeStuckSeconds: 600,
  isManualEntry: false,
  isEdited: isEdited,
  createdAt: DateTime.utc(2026, 5, 1, 8, 30),
  updatedAt: DateTime.utc(2026, 5, 1, 8, 30),
);

TripsCompanion _cloud({
  String id = 'trip1',
  DateTime? startTime,
  DateTime? endTime,
  int durationSeconds = 999,
  double distanceMeters = 2000.0,
  String direction = 'to_home',
  String directionSource = 'manual',
  int totalPausedSeconds = 50,
  bool isEdited = true,
}) => TripsCompanion.insert(
  id: id,
  startTime: startTime ?? DateTime.utc(2026, 5, 1, 9),
  endTime: endTime ?? DateTime.utc(2026, 5, 1, 9, 30),
  durationSeconds: durationSeconds,
  distanceMeters: distanceMeters,
  direction: direction,
  timeMovingSeconds: 1200,
  timeStuckSeconds: 600,
  totalPausedSeconds: Value(totalPausedSeconds),
  isEdited: Value(isEdited),
  directionSource: Value(directionSource),
);

void main() {
  group('resolveMerge — D-06 step 1: pin CURRENT 5-field behavior', () {
    test('empty selections resolves every field to local', () {
      final local = _local();
      final cloud = _cloud();

      final result = resolveMerge(local: local, cloud: cloud, selections: {});

      expect(result.trip.startTime.value, local.startTime);
      expect(result.trip.endTime.value, local.endTime);
      expect(result.trip.durationSeconds.value, local.durationSeconds);
      expect(result.trip.distanceMeters.value, local.distanceMeters);
      expect(result.trip.direction.value, local.direction);
    });

    test(
      'selecting cloud for one field resolves ONLY that field to cloud; '
      'the other four stay local',
      () {
        final local = _local();
        final cloud = _cloud();

        final result = resolveMerge(
          local: local,
          cloud: cloud,
          selections: {'durationSeconds': 'cloud'},
        );

        expect(result.trip.durationSeconds.value, cloud.durationSeconds.value);
        expect(result.trip.startTime.value, local.startTime);
        expect(result.trip.endTime.value, local.endTime);
        expect(result.trip.distanceMeters.value, local.distanceMeters);
        expect(result.trip.direction.value, local.direction);
      },
    );

    test(
      'output trip.id always equals local.id (never cloud.id) and '
      'updatedAt is stamped with a fresh timestamp',
      () {
        final local = _local(id: 'local-id');
        final cloud = _cloud(id: 'cloud-id');
        final before = DateTime.now().toUtc();

        final result = resolveMerge(local: local, cloud: cloud, selections: {});

        expect(result.trip.id.value, 'local-id');
        expect(result.trip.id.value, isNot('cloud-id'));
        expect(result.trip.updatedAt.present, isTrue);
        expect(
          result.trip.updatedAt.value.isAfter(
            before.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
      },
    );

    test(
      'this task adds NO breaks/metadata ride-along yet — output breaks is '
      'always empty regardless of selections',
      () {
        final local = _local();
        final cloud = _cloud();

        final result = resolveMerge(
          local: local,
          cloud: cloud,
          selections: {'startTime': 'cloud'},
        );

        expect(result.breaks, isEmpty);
      },
    );

    test('explicit local selection behaves the same as an absent one', () {
      final local = _local();
      final cloud = _cloud();

      final resultExplicit = resolveMerge(
        local: local,
        cloud: cloud,
        selections: {'direction': 'local'},
      );
      final resultAbsent = resolveMerge(
        local: local,
        cloud: cloud,
        selections: {},
      );

      expect(resultExplicit.trip.direction.value, resultAbsent.trip.direction.value);
      expect(resultExplicit.trip.direction.value, local.direction);
    });
  });
}
