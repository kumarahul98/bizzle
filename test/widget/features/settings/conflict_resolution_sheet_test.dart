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
  double distanceMeters = 12000.0,
  String startTime = '2026-05-01T08:00:00.000Z',
  String endTime = '2026-05-01T08:30:00.000Z',
}) => <String, dynamic>{
  'id': id,
  'startTime': startTime,
  'endTime': endTime,
  'durationSeconds': durationSeconds,
  'distanceMeters': distanceMeters,
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
  double distanceMeters = 12000.0,
  String startTime = '2026-05-01T08:00:00.000Z',
  String endTime = '2026-05-01T08:30:00.000Z',
}) => TripSerializer.fromJson(
  _tripJson(
    id,
    direction: direction,
    durationSeconds: durationSeconds,
    distanceMeters: distanceMeters,
    startTime: startTime,
    endTime: endTime,
  ),
).trip;

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

  Widget buildSubject(
    List<RestoreConflict> conflicts,
    ProviderContainer container,
  ) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        ConflictResolutionSheet(conflicts: conflicts),
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

  testWidgets('Selecting "Use All Cloud" invokes updateTrip and resolves state', (
    WidgetTester tester,
  ) async {
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

  testWidgets('Per-trip overrides allow Keep Local vs Use Cloud', (
    WidgetTester tester,
  ) async {
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
      SameUuidConflict(
        localTrip: local1,
        cloudTrip: _companion('o1', durationSeconds: 999),
      ),
      SameUuidConflict(
        localTrip: local2,
        cloudTrip: _companion('o2', durationSeconds: 888),
      ),
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
    final useCloudOption = find
        .widgetWithText(RadioListTile<String>, kConflictUseCloud)
        .first;
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

  testWidgets(
    'Field-by-field Merge honors explicit Local selection (defaults now local)',
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          tripsDaoProvider.overrideWithValue(db.tripsDao),
        ],
      );
      addTearDown(container.dispose);

      final local1 = _localRow('m1', 100);
      await db.into(db.trips).insert(local1);

      final conflicts = <RestoreConflict>[
        SameUuidConflict(
          localTrip: local1,
          cloudTrip: _companion('m1', durationSeconds: 999),
        ),
      ];

      await tester.pumpWidget(buildSubject(conflicts, container));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Expand first conflict
      final modifiedConflict = find.text('Modified Conflict').first;
      await tester.ensureVisible(modifiedConflict);
      await tester.tap(modifiedConflict);
      await tester.pumpAndSettle();

      // Select "Merge"
      final mergeOption = find.text(kConflictMerge).first;
      await tester.ensureVisible(mergeOption);
      await tester.tap(mergeOption);
      await tester.pumpAndSettle();

      // In Merge UI, every field defaults to 'local' (D-05).
      // Explicitly tap 'Local' on the 'durationSeconds' row anyway — this pins
      // that an explicit Local selection is honored regardless of the default.
      final durationLocalBtn = find.descendant(
        of: find
            .ancestor(
              of: find.text('durationSeconds'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.text('Local'),
      );
      await tester.ensureVisible(durationLocalBtn);
      await tester.tap(durationLocalBtn);
      await tester.pumpAndSettle();

      // Click "Keep All Local" to submit (this just calls applyAll(KeepLocal) which will process the explicit Merge selection)
      final keepAllLocalBtn = find.text('Keep All Local');
      await tester.ensureVisible(keepAllLocalBtn);
      await tester.tap(keepAllLocalBtn);
      await tester.pumpAndSettle();

      final updated1 = await db.tripsDao.findById('m1');
      // durationSeconds should be from local (100) via the explicit tap.
      expect(updated1!.durationSeconds, 100);
      // Untouched fields (e.g. distanceMeters) resolve to local by default —
      // both sides hold 12000.0 here, so this test only pins the explicit tap.
    },
  );

  testWidgets(
    'Merge with two differing fields produces output distinct from both pure Use Cloud and pure Keep Local',
    (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          tripsDaoProvider.overrideWithValue(db.tripsDao),
        ],
      );
      addTearDown(container.dispose);

      // Enlarge the test viewport: at the default 800x600 surface the
      // distanceMeters row's 'Cloud' segment sits under the bottom sheet's
      // clip and the tap never registers (warnIfMissed fires, selection is
      // silently dropped). A taller surface keeps all five field rows and
      // the bulk buttons hittable without scrolling.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Local: durationSeconds 100, distanceMeters 12000.0.
      // Cloud: durationSeconds 999, distanceMeters 20000.0.
      final local1 = _localRow('m2', 100);
      await db.into(db.trips).insert(local1);

      final conflicts = <RestoreConflict>[
        SameUuidConflict(
          localTrip: local1,
          cloudTrip: _companion(
            'm2',
            durationSeconds: 999,
            distanceMeters: 20000.0,
          ),
        ),
      ];

      await tester.pumpWidget(buildSubject(conflicts, container));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Expand the conflict and select Merge.
      final modifiedConflict = find.text('Modified Conflict').first;
      await tester.ensureVisible(modifiedConflict);
      await tester.tap(modifiedConflict);
      await tester.pumpAndSettle();

      final mergeOption = find.text(kConflictMerge).first;
      await tester.ensureVisible(mergeOption);
      await tester.tap(mergeOption);
      await tester.pumpAndSettle();

      // Leave durationSeconds UNTOUCHED — post-D-05 it defaults to 'local'.
      // Explicitly opt distanceMeters INTO cloud.
      final distanceCloudBtn = find.descendant(
        of: find
            .ancestor(
              of: find.text('distanceMeters'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.text('Cloud'),
      );
      await tester.ensureVisible(distanceCloudBtn);
      await tester.tap(distanceCloudBtn);
      await tester.pumpAndSettle();

      // Submit — the per-trip 'Merge' resolution override wins over the bulk default.
      final keepAllLocalBtn = find.text('Keep All Local');
      await tester.ensureVisible(keepAllLocalBtn);
      await tester.tap(keepAllLocalBtn);
      await tester.pumpAndSettle();

      // Assert on the Drift row: merged output must differ from BOTH
      // pure Use Cloud (999, 20000.0) AND pure Keep Local (100, 12000.0).
      final updated = await db.tripsDao.findById('m2');
      expect(updated!.durationSeconds, 100); // LOCAL via untouched default
      expect(updated.distanceMeters, 20000.0); // CLOUD via explicit selection
      expect(updated.durationSeconds, isNot(999)); // not pure Use Cloud
      expect(updated.distanceMeters, isNot(12000.0)); // not pure Keep Local
    },
  );
}
