import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/trips/services/geofence_backfill_service.dart';

/// One-shot geofence backfill task (Phase 21, LOC-02).
///
/// Triggered by [LocationPickerScreen]'s confirm path via
/// `ref.invalidate(geofenceBackfillProvider)` after a Home/Office location
/// is saved. This runs [GeofenceBackfillService.run] once and caches the
/// result. Subsequent reads are a no-op until the next invalidation.
///
/// Mirrors [directionBackfillProvider]'s keepAlive semantics — bare
/// `FutureProvider` (not `.autoDispose`) so an unrelated widget rebuild
/// does NOT re-trigger the full table scan (T-21-03-03 DoS guard).
///
/// Errors are silently absorbed: a backfill failure is non-fatal — the
/// user's existing labels are preserved, and the backfill will re-run on
/// the next location save.
final FutureProvider<int> geofenceBackfillProvider = FutureProvider<int>(
  (ref) async {
    final tripsDao = ref.read(tripsDaoProvider);
    final prefsDao = ref.read(userPreferencesDaoProvider);
    final service = GeofenceBackfillService(
      tripsDao: tripsDao,
      prefsDao: prefsDao,
    );
    return service.run();
  },
  name: 'geofenceBackfillProvider',
);
