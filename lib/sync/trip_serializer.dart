import 'package:drift/drift.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:uuid/uuid.dart';

/// The result of [TripSerializer.fromJson]: the parsed trip companion plus
/// its embedded break companions, returned as one unit so a caller never has
/// to re-derive break `tripId`s or forget to persist them (Phase 26, Plan 03).
typedef ParsedTrip = ({TripsCompanion trip, List<TripBreaksCompanion> breaks});

/// Wire (de)serialization between a Drift [TripRow] (+ its breaks) and the
/// backend trip JSON.
///
/// The output of [toJson] MUST satisfy the deployed Phase 10/26 zod
/// `tripSchema` (backend/functions/src/utils/validation.ts) byte-for-byte:
///   * camelCase keys matching the schema exactly;
///   * `userId` OMITTED — the server forces it from the verified token (D-04);
///   * timestamps as RFC-3339 UTC strings ending with `Z`
///     (`toUtc().toIso8601String()`) so `z.string().datetime()` accepts them;
///   * the four non-nullable numerics always emitted as numbers (0 for manual
///     entries), never null (Pitfall 7);
///   * `routePolyline` nullable; `direction` the stored `'to_office'` /
///     `'to_home'` literal passed through unchanged;
///   * `totalPausedSeconds`/`isEdited`/`directionSource` (Phase 26) always
///     emitted; `breaks` always emitted, truncated to [kMaxBreaksPerTrip].
///
/// [fromJson] is the restore parser: it maps a server trip JSON object back to
/// a [ParsedTrip] (trip companion + break companions) for insert-or-ignore.
/// It parses ISO strings to UTC `DateTime`s and deliberately does NOT set
/// `userId` on the trip (the server copy is ignored — local auth backfill
/// owns the column).
class TripSerializer {
  const TripSerializer._();

  /// Serialize a [TripRow] + its [breaks] to the backend trip JSON map
  /// (D-04, Phase 26). Omits `userId`.
  ///
  /// `breaks` is truncated to [kMaxBreaksPerTrip] (Phase 26 revision issue 6,
  /// T-26-18): this is a DEFENSIVE client-side mirror of the backend zod
  /// `.max(kMaxBreaksPerTrip)` cap. Without it, a >50-break trip would get a
  /// non-retryable 400 from `/trips/sync`, permanently poison-pilling the
  /// trip in the sync queue. Callers (`SyncEngine._drain` via
  /// `TripBreaksDao.breaksForTripIds`/`breaksForTrip`) always supply breaks
  /// ordered by `startTime` ascending, so `.take(kMaxBreaksPerTrip)` keeps
  /// the FIRST 50 chronologically (oldest-first retention) — the trip itself
  /// always syncs; only excess break detail beyond 50 is dropped.
  static Map<String, dynamic> toJson(TripRow t, List<TripBreakRow> breaks) =>
      <String, dynamic>{
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
        'totalPausedSeconds': t.totalPausedSeconds,
        'isEdited': t.isEdited,
        'directionSource': t.directionSource,
        'breaks': breaks
            .take(kMaxBreaksPerTrip)
            .map(
              (b) => <String, dynamic>{
                'startTime': b.startTime.toUtc().toIso8601String(),
                // Safe `!`: trip_breaks_table.dart's own doc guarantees a
                // finalized/persisted trip never carries an open (null
                // endTime) break — finalize closes every segment (D-05/D-07).
                'endTime': b.endTime!.toUtc().toIso8601String(),
              },
            )
            .toList(),
      };

  /// Parse a server trip JSON object into a [ParsedTrip] (D-08, Phase 26).
  /// ISO strings become UTC `DateTime`s; `userId` is intentionally NOT set on
  /// the trip companion so the local auth backfill (not the server copy)
  /// owns ownership.
  ///
  /// Break entries are given FRESH client-side UUIDs on parse — the wire
  /// format carries no break id (roadmap SC1 locks the embedded shape to
  /// `{startTime, endTime}` only), so restore/merge can never round-trip an
  /// original local break UUID. This is intentional, not a gap.
  static ParsedTrip fromJson(Map<String, dynamic> json) {
    final tripId = json['id'] as String;
    final tripCompanion = TripsCompanion.insert(
      id: tripId,
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
      totalPausedSeconds: Value<int>(
        (json['totalPausedSeconds'] as num?)?.toInt() ?? 0,
      ),
      isEdited: Value<bool>(json['isEdited'] as bool? ?? false),
      directionSource: Value<String>(
        json['directionSource'] as String? ?? kDirectionSourceTime,
      ),
    );

    final breaksJson = json['breaks'] as List<dynamic>? ?? const [];
    final breakCompanions = breaksJson
        .map(
          (e) => TripBreaksCompanion.insert(
            id: const Uuid().v4(),
            tripId: tripId,
            startTime: DateTime.parse(
              (e as Map<String, dynamic>)['startTime'] as String,
            ).toUtc(),
            endTime: Value<DateTime>(
              DateTime.parse(e['endTime'] as String).toUtc(),
            ),
          ),
        )
        .toList();

    return (trip: tripCompanion, breaks: breakCompanions);
  }
}
