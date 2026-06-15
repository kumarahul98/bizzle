import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/sync/restore_conflict.dart';
import 'package:traevy/sync/restore_controller.dart';
import 'package:traevy/features/settings/widgets/conflict_resolution_sheet.dart';
import 'package:traevy/sync/trip_serializer.dart';

Map<String, dynamic> _tripJson(
  String id, {
  String direction = 'to_office',
  int durationSeconds = 1800,
  String startTime = '2026-05-01T08:00:00.000Z',
  String endTime = '2026-05-01T08:30:00.000Z',
}) => <String, dynamic>{
  'id': id,
  'startTime': startTime,
  'endTime': endTime,
  'durationSeconds': durationSeconds,
  'distanceMeters': 12000.0,
  'routePolyline': null,
  'direction': direction,
  'timeMovingSeconds': 1200,
  'timeStuckSeconds': 600,
  'isManualEntry': false,
  'createdAt': '2026-05-01T08:30:00.000Z',
  'updatedAt': '2026-05-01T08:30:00.000Z',
};

TripsCompanion _companion(
  String id, {
  String direction = 'to_office',
  int durationSeconds = 1800,
  String startTime = '2026-05-01T08:00:00.000Z',
  String endTime = '2026-05-01T08:30:00.000Z',
}) => TripSerializer.fromJson(
  _tripJson(id, direction: direction, durationSeconds: durationSeconds, startTime: startTime, endTime: endTime),
);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSubject(List<RestoreConflict> conflicts, ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ConflictResolutionSheet(conflicts: conflicts),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
  }

  TripRow _localRow(String id, int duration) => TripRow(
    id: id,
    userId: 'user',
    startTime: DateTime.parse('2026-05-01T08:00:00.000Z'),
    endTime: DateTime.parse('2026-05-01T08:30:00.000Z'),
    durationSeconds: duration,
    distanceMeters: 12000.0,
    direction: 'to_office',
    directionSource: 'time',
    timeMovingSeconds: 1200,
    timeStuckSeconds: 600,
    isManualEntry: false,
    isEdited: false,
    createdAt: DateTime.parse('2026-05-01T08:30:00.000Z'),
    updatedAt: DateTime.parse('2026-05-01T08:30:00.000Z'),
    totalPausedSeconds: 0,
    routePolyline: null,
  );

  testWidgets('Selecting "Use All Cloud" invokes updateTrip and resolves state', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        tripsDaoProvider.overrideWithValue(db.tripsDao),
      ],
    );
    addTearDown(container.dispose);

    final local1 = _localRow('c1', 100);
    final local2 = _localRow('c2', 200);

    // Need them in DB so updateTrip actually updates a row if we want findById to find them.
    // Wait, if they are not in DB, updateTrip does nothing (0 rows updated), but it shouldn't crash.
    // If we want to check DB, we should insert them using raw insert.
    await db.into(db.trips).insert(local1);
    await db.into(db.trips).insert(local2);

    final cloud1 = _companion('c1', durationSeconds: 999);
    final cloud2 = _companion('c2', durationSeconds: 888);

    final conflicts = <RestoreConflict>[
      SameUuidConflict(localTrip: local1, cloudTrip: cloud1),
      SameUuidConflict(localTrip: local2, cloudTrip: cloud2),
    ];

    print('pumpWidget');
    await tester.pumpWidget(buildSubject(conflicts, container));
    print('tap Open');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    print('expect title');
    expect(find.text(kConflictResolutionTitle), findsOneWidget);

    print('tap Use All Cloud');
    await tester.tap(find.text('Use All Cloud'));
    await tester.pumpAndSettle();
    print('done pumping');

    // Check DB
    final updated1 = await db.tripsDao.findById('c1');
    expect(updated1!.durationSeconds, 999);
    
    final updated2 = await db.tripsDao.findById('c2');
    expect(updated2!.durationSeconds, 888);

    // Check state
    final state = container.read(restoreControllerProvider);
    expect(state, isA<RestoreSuccess>());
    expect((state as RestoreSuccess).count, 2);
  });

  testWidgets('Per-trip overrides allow Keep Local vs Use Cloud', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        tripsDaoProvider.overrideWithValue(db.tripsDao),
      ],
    );
    addTearDown(container.dispose);

    final local1 = _localRow('o1', 100);
    final local2 = _localRow('o2', 200);
    
    await db.into(db.trips).insert(local1);
    await db.into(db.trips).insert(local2);

    final conflicts = <RestoreConflict>[
      SameUuidConflict(localTrip: local1, cloudTrip: _companion('o1', durationSeconds: 999)),
      SameUuidConflict(localTrip: local2, cloudTrip: _companion('o2', durationSeconds: 888)),
    ];

    await tester.pumpWidget(buildSubject(conflicts, container));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Expand first conflict
    final modifiedConflict = find.text('Modified Conflict').first;
    await tester.ensureVisible(modifiedConflict);
    await tester.tap(modifiedConflict);
    await tester.pumpAndSettle();

    // Select "Use Cloud" for the first one explicitly to set _resolutions
    final useCloudOption = find.widgetWithText(RadioListTile<String>, kConflictUseCloud).first;
    await tester.ensureVisible(useCloudOption);
    await tester.tap(useCloudOption);
    await tester.pumpAndSettle();

    // Click "Keep All Local" to submit
    final keepAllLocalBtn = find.text('Keep All Local');
    await tester.ensureVisible(keepAllLocalBtn);
    await tester.tap(keepAllLocalBtn);
    await tester.pumpAndSettle();

    final updated1 = await db.tripsDao.findById('o1');
    expect(updated1!.durationSeconds, 999); // Used cloud explicitly

    final updated2 = await db.tripsDao.findById('o2');
    expect(updated2!.durationSeconds, 200); // Kept local by default
  });
}
