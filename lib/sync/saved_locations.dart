import 'package:flutter/foundation.dart';

/// The user's saved Home / Office coordinates as they cross the wire
/// (Phase 29, LOC-03).
///
/// Mirrors the backend `SavedLocations` interface
/// (`backend/functions/src/types/preferences.ts`) field-for-field, and the four
/// nullable coordinate columns on the client's single-row `user_preferences`
/// table. `null` means "not set" in all three places — the same meaning end to
/// end, so no translation layer is needed.
///
/// ## PII posture
///
/// These coordinates reveal where the user lives and works. Phase 21 recorded
/// (T-21-02) that they must never leave the device; Phase 29 reverses that
/// deliberately — see D-01 in
/// `.planning/phases/29-sync-home-office-locations/29-PLAN.md`.
///
/// **T-21-03 was NOT reversed: never log these values.** This class has no
/// `toString` override for exactly that reason — the default
/// `Instance of 'SavedLocations'` is the safe thing to print. Do not add one.
@immutable
class SavedLocations {
  /// Construct from four nullable coordinates.
  const SavedLocations({
    required this.homeLat,
    required this.homeLng,
    required this.officeLat,
    required this.officeLng,
  });

  /// All-null — the user who has never set either location.
  const SavedLocations.empty()
    : homeLat = null,
      homeLng = null,
      officeLat = null,
      officeLng = null;

  /// Parse from the backend's `savedLocations` JSON object.
  ///
  /// Any value that is not a finite number reads as `null`. The server already
  /// validates and normalizes, so this is defence in depth against a malformed
  /// or hand-edited document: a `NaN` reaching the geofence resolver would not
  /// throw, it would silently mislabel the direction of every future trip.
  factory SavedLocations.fromJson(Map<String, dynamic> json) {
    return SavedLocations(
      homeLat: _coordinate(json['homeLat']),
      homeLng: _coordinate(json['homeLng']),
      officeLat: _coordinate(json['officeLat']),
      officeLng: _coordinate(json['officeLng']),
    );
  }

  static double? _coordinate(Object? value) {
    if (value is num) {
      final d = value.toDouble();
      return d.isFinite ? d : null;
    }
    return null;
  }

  /// Saved Home latitude, or `null` when not set.
  final double? homeLat;

  /// Saved Home longitude, or `null` when not set.
  final double? homeLng;

  /// Saved Office latitude, or `null` when not set.
  final double? officeLat;

  /// Saved Office longitude, or `null` when not set.
  final double? officeLng;

  /// True when neither Home nor Office is set — nothing worth pushing.
  bool get isEmpty =>
      homeLat == null &&
      homeLng == null &&
      officeLat == null &&
      officeLng == null;

  /// Serialize for `POST /preferences/sync`.
  ///
  /// Emits all four keys including nulls. Omitting a null would be read by the
  /// server's `.default(null)` as "absent" and produce the same result, but
  /// sending the full shape keeps the payload a complete statement of current
  /// truth — which is what makes the queue-free push in D-02 safe to re-send.
  Map<String, Object?> toJson() => {
    'homeLat': homeLat,
    'homeLng': homeLng,
    'officeLat': officeLat,
    'officeLng': officeLng,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedLocations &&
          other.homeLat == homeLat &&
          other.homeLng == homeLng &&
          other.officeLat == officeLat &&
          other.officeLng == officeLng;

  @override
  int get hashCode => Object.hash(homeLat, homeLng, officeLat, officeLng);
}
