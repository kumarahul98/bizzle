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

      expect(
        resultExplicit.trip.direction.value,
        resultAbsent.trip.direction.value,
      );
      expect(resultExplicit.trip.direction.value, local.direction);
    });
  });

  group('resolveMerge — D-04 ride-along rules', () {
    final localBreaks = <TripBreakRow>[
      TripBreakRow(
        id: 'lb1',
        tripId: 'trip1',
        startTime: DateTime.utc(2026, 5, 1, 8, 5),
        endTime: DateTime.utc(2026, 5, 1, 8, 10),
      ),
    ];
    final cloudBreaks = <TripBreaksCompanion>[
      TripBreaksCompanion.insert(
        id: 'cb1',
        tripId: 'cloud-original-id',
        startTime: DateTime.utc(2026, 5, 1, 9, 5),
        endTime: Value(DateTime.utc(2026, 5, 1, 9, 10)),
      ),
      TripBreaksCompanion.insert(
        id: 'cb2',
        tripId: 'cloud-original-id',
        startTime: DateTime.utc(2026, 5, 1, 9, 15),
        endTime: Value(DateTime.utc(2026, 5, 1, 9, 20)),
      ),
    ];

    test(
      'when startTime resolves local, output breaks are LOCAL breaks '
      'rebuilt with tripId remapped to local.id',
      () {
        final local = _local(id: 'trip1');
        final cloud = _cloud(id: 'trip1');

        final result = resolveMerge(
          local: local,
          cloud: cloud,
          selections: {}, // startTime defaults local
          localBreaks: localBreaks,
          cloudBreaks: cloudBreaks,
        );

        expect(result.breaks, hasLength(1));
        expect(result.breaks.single.tripId.value, 'trip1');
        expect(
          result.breaks.single.startTime.value,
          localBreaks.single.startTime,
        );
        expect(result.breaks.single.endTime.value, localBreaks.single.endTime);
        // Fresh UUID, never the original local break id reused blindly is
        // fine either way, but tripId must NEVER be the cloud original id.
        expect(result.breaks.single.tripId.value, isNot('cloud-original-id'));
      },
    );

    test(
      'when startTime resolves cloud, output breaks are CLOUD breaks '
      'rebuilt with tripId remapped to local.id (never the cloud original id)',
      () {
        final local = _local(id: 'trip1');
        final cloud = _cloud(id: 'trip1');

        final result = resolveMerge(
          local: local,
          cloud: cloud,
          selections: {'startTime': 'cloud'},
          localBreaks: localBreaks,
          cloudBreaks: cloudBreaks,
        );

        expect(result.breaks, hasLength(2));
        for (final b in result.breaks) {
          expect(b.tripId.value, 'trip1');
          expect(b.tripId.value, isNot('cloud-original-id'));
        }
        expect(
          result.breaks[0].startTime.value,
          cloudBreaks[0].startTime.value,
        );
        expect(
          result.breaks[1].startTime.value,
          cloudBreaks[1].startTime.value,
        );
      },
    );

    test(
      'totalPausedSeconds follows the SAME side as startTime\'s winner',
      () {
        final local = _local(totalPausedSeconds: 111);
        final cloud = _cloud(totalPausedSeconds: 222);

        final localWins = resolveMerge(
          local: local,
          cloud: cloud,
          selections: {},
        );
        expect(localWins.trip.totalPausedSeconds.value, 111);

        final cloudWins = resolveMerge(
          local: local,
          cloud: cloud,
          selections: {'startTime': 'cloud'},
        );
        expect(cloudWins.trip.totalPausedSeconds.value, 222);
      },
    );

    test('directionSource follows the direction field\'s own selection', () {
      final local = _local(directionSource: 'manual');
      final cloud = _cloud(directionSource: 'geofence');

      final localWins = resolveMerge(
        local: local,
        cloud: cloud,
        selections: {},
      );
      expect(localWins.trip.directionSource.value, 'manual');

      final cloudWins = resolveMerge(
        local: local,
        cloud: cloud,
        selections: {'direction': 'cloud'},
      );
      expect(cloudWins.trip.directionSource.value, 'geofence');
    });

    test(
      'isEdited is ALWAYS true in merge output, regardless of selections',
      () {
        final local = _local(isEdited: false);
        final cloud = _cloud(isEdited: false);

        final allLocal = resolveMerge(
          local: local,
          cloud: cloud,
          selections: {},
        );
        expect(allLocal.trip.isEdited.value, isTrue);

        final allCloud = resolveMerge(
          local: local,
          cloud: cloud,
          selections: {
            'startTime': 'cloud',
            'endTime': 'cloud',
            'durationSeconds': 'cloud',
            'distanceMeters': 'cloud',
            'direction': 'cloud',
          },
        );
        expect(allCloud.trip.isEdited.value, isTrue);
      },
    );
  });
}
