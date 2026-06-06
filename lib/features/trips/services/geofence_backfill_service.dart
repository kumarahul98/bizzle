import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/features/trips/services/geofence_direction_resolver.dart';
import 'package:traevy/shared/utils/polyline_codec.dart';

/// One-shot service that re-labels historical trips by proximity to the
/// user's saved Home/Office anchors (Phase 21, LOC-02, D-11).
///
/// Reuses the same pure [GeofenceDirectionResolver] that finalize uses so
/// live and backfilled labels are identical (D-09 single source of truth).
///
/// Safety contract (T-21-03-01): trips where `direction_source = manual`
/// are excluded by the DAO query — a user's manual pick is NEVER changed.
///
/// Idempotent: running twice with the same anchors produces no further
/// changes — the second pass sees `direction_source = geofence` on already-
/// matched rows and the DAO query still selects them, but the resolver
/// returns the same label so the write is a no-op at the SQLite level.
///
/// PII guard (T-21-03-02): decoded trip endpoints are held in-memory for
/// distance math only — never logged, never emitted.
class GeofenceBackfillService {
  /// Create the backfill service.
  const GeofenceBackfillService({
    required this.tripsDao,
    required this.prefsDao,
    this.resolver = const GeofenceDirectionResolver(),
  });

  /// Data access for trip candidate query and direction update.
  final TripsDao tripsDao;

  /// Data access for saved Home/Office coordinates.
  final UserPreferencesDao prefsDao;

  /// The geofence resolver — injected so tests can verify calls or use a
  /// custom radius without touching production wiring.
  final GeofenceDirectionResolver resolver;

  /// Run the backfill: query non-manual GPS trips, decode their polyline
  /// endpoints, and relabel any that are within the geofence radius of a
  /// saved anchor.
  ///
  /// Returns the number of trips that were relabelled. Zero when no
  /// locations are set (SC#5 — purely additive) or when no candidates
  /// match.
  Future<int> run() async {
    final prefs = await prefsDao.getOrDefault();

    // No-op guard: if neither anchor is set, every resolver call would
    // return null — skip the full table scan entirely (SC#5, D-09).
    if (prefs.homeLat == null &&
        prefs.homeLng == null &&
        prefs.officeLat == null &&
        prefs.officeLng == null) {
      return 0;
    }

    final candidates = await tripsDao.geofenceBackfillCandidates();
    var relabelled = 0;

    for (final trip in candidates) {
      final polyline = trip.routePolyline;
      if (polyline == null || polyline.isEmpty) continue;

      // Decode endpoints — guarded against malformed polylines (same
      // pattern as the finalize path in tracking_service_controller).
      final List<({double lat, double lng})> points;
      try {
        points = decodePolyline(polyline);
      } on Object {
        // Corrupt polyline — skip silently (no PII log).
        continue;
      }
      if (points.isEmpty) continue;

      final start = points.first;
      final end = points.last;

      final direction = resolver.resolve(
        start: start,
        end: end,
        homeLat: prefs.homeLat,
        homeLng: prefs.homeLng,
        officeLat: prefs.officeLat,
        officeLng: prefs.officeLng,
      );

      // Only write when the resolver has a confident match AND it differs from
      // the current label. This makes the backfill strictly idempotent.
      if (direction != null && direction != trip.direction) {
        await tripsDao.updateDirectionAndSource(
          trip.id,
          direction,
          kDirectionSourceGeofence,
        );
        relabelled++;
      }
    }

    return relabelled;
  }
}
