// Wave 0 stub — tests will fail until Plan 03-02 implements TripManagementNotifier.
// These stubs define the expected behaviors that Wave 1 must satisfy.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('TripManagementNotifier', () {
    late AppDatabase db;
    late ProviderContainer container;
    const uuid = Uuid();

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tripsDaoProvider.overrideWithValue(db.tripsDao),
          syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('editTrip updates direction and enqueues kSyncActionUpdate', () async {
      // TODO: implement in Plan 03-02 when TripManagementNotifier exists.
      // Insert a trip, call editTrip, assert direction changed and
      // sync_queue has a kSyncActionUpdate row for the trip.
      expect(true, isTrue); // placeholder — replace with real assertions
    }, skip: 'Wave 0 stub — implement in Plan 03-02');

    test('deleteTrip removes trip and enqueues kSyncActionDelete', () async {
      // TODO: implement in Plan 03-02.
      // Insert a trip, call deleteTrip, assert trip gone from trips table
      // and sync_queue has a kSyncActionDelete row.
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-02');

    test('editTrip transitions state: Idle → Saving → Saved', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-02');

    test('deleteTrip transitions state: Idle → Saving → Saved', () async {
      expect(true, isTrue);
    }, skip: 'Wave 0 stub — implement in Plan 03-02');
  });
}
