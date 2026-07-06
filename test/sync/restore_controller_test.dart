import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/restore_conflict.dart';
import 'package:traevy/sync/restore_controller.dart';

class FakeApiClient implements ApiClient {
  Future<List<TripsCompanion>> Function()? restoreTripsImpl;
  @override
  Future<List<TripsCompanion>> restoreTrips() async => restoreTripsImpl!();
  
  @override
  Future<void> syncTrips(List<TripRow> trips) async {}
  
  @override
  Future<void> deleteTrip(String tripId) async {}
}

class FakeTripsDao implements TripsDao {
  Future<List<TripRow>> Function()? getAllTripsImpl;
  Future<int> Function(List<TripsCompanion>)? insertOrIgnoreTripsImpl;
  
  @override
  Future<List<TripRow>> getAllTrips() async => getAllTripsImpl!();
  
  @override
  Future<int> insertOrIgnoreTrips(List<TripsCompanion> companions) async => insertOrIgnoreTripsImpl!(companions);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeApiClient apiClient;
  late FakeTripsDao tripsDao;
  late ProviderContainer container;

  setUp(() {
    apiClient = FakeApiClient();
    tripsDao = FakeTripsDao();
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        tripsDaoProvider.overrideWithValue(tripsDao),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  final startTime = DateTime.parse('2023-01-01T08:00:00Z');
  final endTime = DateTime.parse('2023-01-01T08:30:00Z');

  final baseTripRow = TripRow(
    id: 'uuid-1',
    userId: 'user',
    startTime: startTime,
    endTime: endTime,
    durationSeconds: 1800,
    totalPausedSeconds: 0,
    distanceMeters: 5000,
    routePolyline: null,
    direction: 'to_office',
    directionSource: 'time',
    timeMovingSeconds: 1500,
    timeStuckSeconds: 300,
    isManualEntry: false,
    isEdited: false,
    createdAt: startTime,
    updatedAt: startTime,
  );

  final baseCompanion = TripsCompanion.insert(
    id: 'uuid-1',
    userId: const Value('user'),
    startTime: startTime,
    endTime: endTime,
    durationSeconds: 1800,
    totalPausedSeconds: const Value(0),
    distanceMeters: 5000,
    routePolyline: const Value(null),
    direction: 'to_office',
    directionSource: const Value('time'),
    timeMovingSeconds: 1500,
    timeStuckSeconds: 300,
    isManualEntry: const Value(false),
    isEdited: const Value(false),
    createdAt: Value(startTime),
    updatedAt: Value(startTime),
  );

  test('restore emits Success when no conflicts', () async {
    tripsDao.getAllTripsImpl = () async => [];
    apiClient.restoreTripsImpl = () async => [baseCompanion];
    tripsDao.insertOrIgnoreTripsImpl = (_) async => 1;

    final controller = container.read(restoreControllerProvider.notifier);
    await controller.restore();

    final state = container.read(restoreControllerProvider);
    expect(state, isA<RestoreSuccess>());
    expect((state as RestoreSuccess).count, 1);
  });

  test('restore detects same UUID conflict with different fields', () async {
    tripsDao.getAllTripsImpl = () async => [baseTripRow];
    
    final modifiedCompanion = baseCompanion.copyWith(durationSeconds: const Value(2000));
    apiClient.restoreTripsImpl = () async => [modifiedCompanion];
    tripsDao.insertOrIgnoreTripsImpl = (_) async => 0;

    final controller = container.read(restoreControllerProvider.notifier);
    await controller.restore();

    final state = container.read(restoreControllerProvider);
    expect(state, isA<RestoreConflictState>());
    final conflictState = state as RestoreConflictState;
    expect(conflictState.conflicts.length, 1);
    expect(conflictState.conflicts.first, isA<SameUuidConflict>());
  });

  test('restore skips identical same UUID trip as non-conflict', () async {
    tripsDao.getAllTripsImpl = () async => [baseTripRow];
    apiClient.restoreTripsImpl = () async => [baseCompanion];
    tripsDao.insertOrIgnoreTripsImpl = (_) async => 0;

    final controller = container.read(restoreControllerProvider.notifier);
    await controller.restore();

    final state = container.read(restoreControllerProvider);
    expect(state, isA<RestoreSuccess>());
    expect((state as RestoreSuccess).count, 0);
  });

  test('restore detects time overlap conflict (> 1 min)', () async {
    final existingRow = baseTripRow.copyWith(id: 'uuid-local');
    tripsDao.getAllTripsImpl = () async => [existingRow];
    
    final overlapCompanion = baseCompanion.copyWith(
      id: const Value('uuid-cloud'),
      startTime: Value(startTime.add(const Duration(minutes: 5))), // 08:05 to 08:35, overlaps by 25 mins
      endTime: Value(endTime.add(const Duration(minutes: 5))),
    );
    apiClient.restoreTripsImpl = () async => [overlapCompanion];
    tripsDao.insertOrIgnoreTripsImpl = (_) async => 0;

    final controller = container.read(restoreControllerProvider.notifier);
    await controller.restore();

    final state = container.read(restoreControllerProvider);
    expect(state, isA<RestoreConflictState>());
    final conflictState = state as RestoreConflictState;
    expect(conflictState.conflicts.length, 1);
    expect(conflictState.conflicts.first, isA<OverlapConflict>());
  });

  test('restore ignores time overlap <= 1 min', () async {
    final existingRow = baseTripRow.copyWith(id: 'uuid-local');
    tripsDao.getAllTripsImpl = () async => [existingRow];
    
    final noOverlapCompanion = baseCompanion.copyWith(
      id: const Value('uuid-cloud'),
      startTime: Value(endTime.subtract(const Duration(seconds: 30))), // Overlaps by 30 seconds
      endTime: Value(endTime.add(const Duration(minutes: 30))),
    );
    apiClient.restoreTripsImpl = () async => [noOverlapCompanion];
    tripsDao.insertOrIgnoreTripsImpl = (_) async => 1;

    final controller = container.read(restoreControllerProvider.notifier);
    await controller.restore();

    final state = container.read(restoreControllerProvider);
    expect(state, isA<RestoreSuccess>());
    expect((state as RestoreSuccess).count, 1);
  });
}
