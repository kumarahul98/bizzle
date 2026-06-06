import 'package:drift/drift.dart';
import 'package:traevy/database/database.dart';

/// Wire (de)serialization between a Drift [TripRow] and the backend trip JSON.
///
/// The output of [toJson] MUST satisfy the deployed Phase 10 zod `tripSchema`
/// (backend/functions/src/utils/validation.ts) byte-for-byte:
///   * camelCase keys matching the schema exactly;
///   * `userId` OMITTED — the server forces it from the verified token (D-04);
///   * timestamps as RFC-3339 UTC strings ending with `Z`
///     (`toUtc().toIso8601String()`) so `z.string().datetime()` accepts them;
///   * the four non-nullable numerics always emitted as numbers (0 for manual
///     entries), never null (Pitfall 7);
///   * `routePolyline` nullable; `direction` the stored `'to_office'` /
///     `'to_home'` literal passed through unchanged.
///
/// [fromJson] is the restore parser: it maps a server trip JSON object back to
/// a [TripsCompanion] for insert-or-ignore. It parses ISO strings to UTC
/// `DateTime`s and deliberately does NOT set `userId` (the server copy is
/// ignored — local auth backfill owns the column).
class TripSerializer {
  const TripSerializer._();

  /// Serialize a [TripRow] to the backend trip JSON map (D-04). Omits `userId`.
  static Map<String, dynamic> toJson(TripRow t) => <String, dynamic>{
    'id': t.id,
    'startTime': t.startTime.toUtc().toIso8601String(),
    'endTime': t.endTime.toUtc().toIso8601String(),
    'durationSeconds': t.durationSeconds,
    'distanceMeters': t.distanceMeters,
    'routePolyline': t.routePolyline,
    'direction': t.direction,
    'timeMovingSeconds': t.timeMovingSeconds,
    'timeStuckSeconds': t.timeStuckSeconds,
    'isManualEntry': t.isManualEntry,
    'createdAt': t.createdAt.toUtc().toIso8601String(),
    'updatedAt': t.updatedAt.toUtc().toIso8601String(),
  };

  /// Parse a server trip JSON object into a [TripsCompanion] (D-08). ISO
  /// strings become UTC `DateTime`s; `userId` is intentionally NOT set so the
  /// local auth backfill (not the server copy) owns ownership.
  static TripsCompanion fromJson(Map<String, dynamic> json) =>
      TripsCompanion.insert(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String).toUtc(),
        endTime: DateTime.parse(json['endTime'] as String).toUtc(),
        durationSeconds: (json['durationSeconds'] as num).toInt(),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        routePolyline: Value<String?>(json['routePolyline'] as String?),
        direction: json['direction'] as String,
        timeMovingSeconds: (json['timeMovingSeconds'] as num).toInt(),
        timeStuckSeconds: (json['timeStuckSeconds'] as num).toInt(),
        isManualEntry: Value<bool>(json['isManualEntry'] as bool),
        createdAt: Value<DateTime>(
          DateTime.parse(json['createdAt'] as String).toUtc(),
        ),
        updatedAt: Value<DateTime>(
          DateTime.parse(json['updatedAt'] as String).toUtc(),
        ),
      );
}
