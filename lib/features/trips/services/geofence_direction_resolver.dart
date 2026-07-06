import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';

/// Pure geofence direction policy (Phase 21, D-04..D-09).
///
/// Given a trip's start/end coordinates and the user's saved Home/Office
/// anchors, returns [kDirectionToOffice], [kDirectionToHome], or `null` when
/// there is no confident match (the caller then falls back to the time-of-day
/// heuristic).
///
/// This is the SINGLE source of geofence truth, used identically at finalize
/// (D-10) and in the Plan 03 backfill (D-11). It does NO I/O: no Drift, no
/// Riverpod, no plugin channel — only the static [Geolocator.distanceBetween]
/// great-circle math, which is safe on the plain Dart VM. The const
/// constructor mirrors `DirectionLabelService` so callers can write
/// `const GeofenceDirectionResolver()` without allocation cost.
///
/// PII guard (T-21-02): the resolver NEVER logs. Coordinates flow in and only
/// the resulting label flows out — nothing is persisted, printed, or emitted
/// here. Callers must keep the coords as local variables.
class GeofenceDirectionResolver {
  /// Create a geofence direction resolver.
  const GeofenceDirectionResolver();

  /// Resolve the trip direction from proximity of [end] (and, on overlap,
  /// [start]) to the saved Home/Office anchors.
  ///
  /// Returns:
  ///   * [kDirectionToOffice] when [end] is confidently at the Office,
  ///   * [kDirectionToHome] when [end] is confidently at Home,
  ///   * `null` when there is no confident match — the caller falls back to
  ///     the time-of-day heuristic (D-06/D-09).
  ///
  /// Rules (D-04..D-09):
  ///   * [end] is the primary signal. A point is "near" an anchor when
  ///     `distanceBetween(end, anchor) < radiusMeters` (STRICT — a point
  ///     exactly at the radius is OUTSIDE, D-06).
  ///   * An anchor that is not set (lat or lng null) is never "near"; the
  ///     resolver never guesses the unset anchor (D-08).
  ///   * If both anchors are unset, or [end] is null (empty/short polyline),
  ///     the result is `null` — purely additive (D-09).
  ///   * Overlap (D-07): if [end] is near BOTH anchors, tie-break by [start] —
  ///     start strictly nearer Home → [kDirectionToOffice]; start strictly
  ///     nearer Office → [kDirectionToHome]; start null or equidistant →
  ///     `null`.
  String? resolve({
    required ({double lat, double lng})? start,
    required ({double lat, double lng})? end,
    required double? homeLat,
    required double? homeLng,
    required double? officeLat,
    required double? officeLng,
    double radiusMeters = kGeofenceRadiusMeters,
  }) {
    // No END anchor (manual entry / <1 polyline point) → no geofence signal.
    if (end == null) return null;

    final hasHome = homeLat != null && homeLng != null;
    final hasOffice = officeLat != null && officeLng != null;

    // Purely additive: with no saved anchors the geofence path is inert (D-09).
    if (!hasHome && !hasOffice) return null;

    // An unset anchor is never "near" (D-08): the guard short-circuits before
    // the distance math, so a null anchor cannot label a trip.
    final endNearHome =
        hasHome &&
        Geolocator.distanceBetween(end.lat, end.lng, homeLat, homeLng) <
            radiusMeters;
    final endNearOffice =
        hasOffice &&
        Geolocator.distanceBetween(end.lat, end.lng, officeLat, officeLng) <
            radiusMeters;

    // Overlap (D-07): END is within radius of BOTH anchors. Tie-break by which
    // anchor the START is nearer to — a commute that BEGAN at Home is heading
    // to the Office, and vice-versa.
    if (endNearHome && endNearOffice) {
      if (start == null) return null;
      final startToHome = Geolocator.distanceBetween(
        start.lat,
        start.lng,
        homeLat,
        homeLng,
      );
      final startToOffice = Geolocator.distanceBetween(
        start.lat,
        start.lng,
        officeLat,
        officeLng,
      );
      if (startToHome < startToOffice) return kDirectionToOffice;
      if (startToOffice < startToHome) return kDirectionToHome;
      // Equidistant — cannot decide.
      return null;
    }

    if (endNearOffice) return kDirectionToOffice;
    if (endNearHome) return kDirectionToHome;

    // END is not confidently near either anchor → fall back to time (D-06).
    return null;
  }
}
