import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/providers.dart';

/// One-shot app-start purge of expired Trash entries (Phase 35, D-04).
///
/// Hard-deletes every trip soft-deleted STRICTLY MORE than
/// [kTrashRetentionDays] days ago, cascade-removing its breaks and stuck
/// segments. It runs on app start rather than on a timer or a `WorkManager`
/// job: a once-a-day cleanup of a handful of rows does not justify that
/// machinery, app start is frequent enough that no user accumulates a
/// meaningful backlog, and if the app is never opened nothing needs cleaning.
///
/// The purge enqueues NOTHING — the server was told at soft-delete time and
/// keeps its own soft-deleted copy, so a second delete would be pure noise
/// (D-04). It is defensive about clock skew: the cutoff is computed in UTC and
/// `TripsDao.purgeTripsDeletedBefore` only removes rows strictly older than it,
/// so a device whose clock jumped backward (making a tombstone look
/// future-dated) never purges a recently-deleted trip.
///
/// keepAlive = true (bare `FutureProvider(...)` in Riverpod 3.x). Must NOT be
/// `.autoDispose` — that would re-run it on every widget rebuild. Wiring:
/// consume via `ref.watch(tripPurgeProvider)` in `TraevyApp.build` so it fires
/// exactly once per app session. The return value is the number of rows purged
/// (useful in tests); the UI must not await or block on it.
final FutureProvider<int> tripPurgeProvider = FutureProvider<int>((ref) async {
  final tripsDao = ref.read(tripsDaoProvider);
  final cutoffUtc = DateTime.now().toUtc().subtract(
    const Duration(days: kTrashRetentionDays),
  );
  return tripsDao.purgeTripsDeletedBefore(cutoffUtc);
}, name: 'tripPurgeProvider');
