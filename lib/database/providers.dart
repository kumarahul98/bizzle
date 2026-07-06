import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/daos/sync_queue_dao.dart';
import 'package:traevy/database/daos/trip_breaks_dao.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';

/// Riverpod 3.x wiring for `AppDatabase` and its DAOs.
///
/// Manual provider declarations (not the `@riverpod` code-gen pattern)
/// because Phase 1 Plan 01 deferred `riverpod_generator` / `custom_lint`
/// / `riverpod_lint` — those packages pin `analyzer ^9` while
/// `drift_dev 2.32.1` pins `analyzer ^10`, so the combination is not
/// installable today. The manual shape below produces identical
/// runtime behavior and is officially supported by flutter_riverpod
/// 3.3.1. Once the analyzer-10 riverpod tooling ships, a later plan
/// will migrate this file to the `@Riverpod` annotation form.
///
/// Lifecycle notes:
///   * `AppDatabase` must live for the full app session. In Riverpod
///     3.x, a bare `Provider(...)` call (i.e. NOT `Provider.autoDispose`)
///     defaults to `isAutoDispose = false`, which is the manual
///     equivalent of the codegen annotation `@Riverpod(keepAlive: true)`.
///     Without keepAlive semantics every widget disposal would close
///     the database (Pitfall 2 in 01-RESEARCH.md).
///   * `ref.onDispose(db.close)` still fires if the provider is
///     invalidated (e.g. tests calling `container.dispose()`), so the
///     underlying SQLite handle is released cleanly in those paths.
///   * DAO providers watch `appDatabaseProvider` so any invalidation
///     cascades into the DAOs automatically.

/// The single `AppDatabase` instance for the app.
///
/// Manual keepAlive: true semantics — `Provider((ref) => ...)` defaults
/// to `isAutoDispose = false` in Riverpod 3.x, matching the codegen
/// `@Riverpod(keepAlive: true)` annotation. The explicit comment
/// documents this because the manual syntax does not surface the
/// `keepAlive` name in the provider declaration itself.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>(
  (ref) {
    final db = AppDatabase();
    ref.onDispose(db.close);
    return db;
  },
  name: 'appDatabaseProvider',
);

/// `TripsDao` sourced from the keepAlive'd `appDatabaseProvider`.
final Provider<TripsDao> tripsDaoProvider = Provider<TripsDao>(
  (ref) => ref.watch(appDatabaseProvider).tripsDao,
  name: 'tripsDaoProvider',
);

/// `SyncQueueDao` sourced from the keepAlive'd `appDatabaseProvider`.
final Provider<SyncQueueDao> syncQueueDaoProvider = Provider<SyncQueueDao>(
  (ref) => ref.watch(appDatabaseProvider).syncQueueDao,
  name: 'syncQueueDaoProvider',
);

/// `UserPreferencesDao` sourced from the keepAlive'd `appDatabaseProvider`.
final Provider<UserPreferencesDao> userPreferencesDaoProvider =
    Provider<UserPreferencesDao>(
      (ref) => ref.watch(appDatabaseProvider).userPreferencesDao,
      name: 'userPreferencesDaoProvider',
    );

/// `TripBreaksDao` sourced from the keepAlive'd `appDatabaseProvider`.
final Provider<TripBreaksDao> tripBreaksDaoProvider = Provider<TripBreaksDao>(
  (ref) => ref.watch(appDatabaseProvider).tripBreaksDao,
  name: 'tripBreaksDaoProvider',
);
