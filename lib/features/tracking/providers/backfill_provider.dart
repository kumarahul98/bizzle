import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/services/direction_label_service.dart';

/// One-shot background backfill that labels all `kDirectionUnknown`
/// rows saved by Phase 2 with the correct direction from
/// `DirectionLabelService`.
///
/// keepAlive = true (default for bare `FutureProvider(...)` in
/// Riverpod 3.x). Must NOT be `.autoDispose` — Pitfall 5: autoDispose
/// causes re-runs on every widget rebuild cycle.
///
/// Wiring: consume via `ref.watch(directionBackfillProvider)` inside
/// `TraevyApp.build` so the provider is read exactly once at startup.
/// The UI must not await or block on its result — the return value is
/// void and errors are silently swallowed (backfill failure is
/// non-fatal; unlabeled rows will be corrected on the next app launch).
final FutureProvider<void> directionBackfillProvider = FutureProvider<void>(
  (ref) async {
    final db = ref.read(appDatabaseProvider);
    final prefsDao = ref.read(userPreferencesDaoProvider);
    final tripsDao = ref.read(tripsDaoProvider);
    final syncDao = ref.read(syncQueueDaoProvider);

    final prefs = await prefsDao.getOrDefault();
    final unknownTrips = await (db.select(
      db.trips,
    )..where((t) => t.direction.equals(kDirectionUnknown))).get();

    if (unknownTrips.isEmpty) return;

    const labeler = DirectionLabelService();
    await db.transaction(() async {
      for (final trip in unknownTrips) {
        final direction = labeler.label(
          trip.startTime.toLocal(), // Pitfall 2: convert before label
          prefs.morningCutoffHour,
        );
        await tripsDao.updateTrip(
          TripsCompanion(
            id: Value(trip.id),
            direction: Value(direction),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        await syncDao.enqueueUpdate(trip.id);
      }
    });
  },
  name: 'directionBackfillProvider',
);
