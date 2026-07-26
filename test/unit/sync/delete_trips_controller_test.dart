// Unit tests for the "Delete all data" flow (Phase 38, DEL-ALL-DATA).
//
// In-memory Drift + a fake ApiClient (no network, no Firebase platform
// channels) + a fake AuthStateNotifier — mirrors the setUp/tearDown and
// provider-override shape in test/unit/sync/restore_controller_test.dart.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/sync/api_client.dart';
import 'package:traevy/sync/delete_trips_controller.dart';

/// Fake auth notifier so tests can force `AuthGuest` / `AuthSignedIn` without
/// any Firebase platform channel. Mirrors `_FakeAuthNotifier` in
/// account_sheet_test.dart.
class _FakeAuthNotifier extends AuthStateNotifier {
  _FakeAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

/// Scripted [ApiClient] recording whether/how many times `deleteAllTrips()`
/// was called, or throwing when [throwOnDelete] is set. All other members are
/// unreachable in these tests and surface via `noSuchMethod` if touched.
class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.throwOnDelete = false});

  final bool throwOnDelete;
  int deleteAllTripsCallCount = 0;

  @override
  Future<int> deleteAllTrips() async {
    deleteAllTripsCallCount++;
    if (throwOnDelete) throw const SyncException.transport();
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer containerWith({
    required AuthState authState,
    required _FakeApiClient api,
  }) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tripsDaoProvider.overrideWithValue(db.tripsDao),
        syncQueueDaoProvider.overrideWithValue(db.syncQueueDao),
        apiClientProvider.overrideWithValue(api),
        authStateProvider.overrideWith(() => _FakeAuthNotifier(authState)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<String> seedTrip(String id) async {
    await db.tripsDao.insertTrip(
      TripsCompanion.insert(
        id: id,
        startTime: DateTime.utc(2026, 5, 1, 8),
        endTime: DateTime.utc(2026, 5, 1, 8, 30),
        durationSeconds: 1800,
        distanceMeters: 5000,
        direction: 'to_office',
        timeMovingSeconds: 1500,
        timeStuckSeconds: 300,
      ),
    );
    return id;
  }

  group('DeleteTripsController.deleteAllTrips — guest path', () {
    test(
      'does NOT call apiClient; wipes local trips; DeleteTripsSuccess',
      () async {
        await seedTrip('g1');
        await seedTrip('g2');
        final api = _FakeApiClient();
        final container = containerWith(
          authState: const AuthGuest(),
          api: api,
        );

        await container
            .read(deleteTripsControllerProvider.notifier)
            .deleteAllTrips();

        expect(api.deleteAllTripsCallCount, 0);
        expect(await db.tripsDao.getAllTrips(), isEmpty);
        final state = container.read(deleteTripsControllerProvider);
        expect(state, isA<DeleteTripsSuccess>());
        expect((state as DeleteTripsSuccess).count, 2);
      },
    );
  });

  group('DeleteTripsController.deleteAllTrips — signed-in path', () {
    test(
      'calls apiClient.deleteAllTrips ONCE, then wipes local; '
      'DeleteTripsSuccess',
      () async {
        await seedTrip('s1');
        final api = _FakeApiClient();
        final container = containerWith(
          authState: const AuthSignedIn(uid: 'u1', name: 'A', email: 'a@b.c'),
          api: api,
        );

        await container
            .read(deleteTripsControllerProvider.notifier)
            .deleteAllTrips();

        expect(api.deleteAllTripsCallCount, 1);
        expect(await db.tripsDao.getAllTrips(), isEmpty);
        final state = container.read(deleteTripsControllerProvider);
        expect(state, isA<DeleteTripsSuccess>());
        expect((state as DeleteTripsSuccess).count, 1);
      },
    );

    test(
      'API error → DeleteTripsError, local trips NOT wiped, no rethrow',
      () async {
        await seedTrip('e1');
        final api = _FakeApiClient(throwOnDelete: true);
        final container = containerWith(
          authState: const AuthSignedIn(uid: 'u1', name: 'A', email: 'a@b.c'),
          api: api,
        );

        // Must NOT throw out of deleteAllTrips() (errors caught internally).
        await container
            .read(deleteTripsControllerProvider.notifier)
            .deleteAllTrips();

        expect(
          container.read(deleteTripsControllerProvider),
          isA<DeleteTripsError>(),
        );
        expect(await db.tripsDao.getAllTrips(), hasLength(1));
      },
    );
  });

  group('DeleteTripsController double-tap guard', () {
    test('starts at DeleteTripsIdle', () {
      final container = containerWith(
        authState: const AuthGuest(),
        api: _FakeApiClient(),
      );
      expect(
        container.read(deleteTripsControllerProvider),
        isA<DeleteTripsIdle>(),
      );
    });
  });
}
