import 'package:flutter/foundation.dart';

/// Immutable DTO produced by `TripAccumulator.finalize()` and passed from
/// the tracking service isolate to the UI isolate across the
/// `flutter_background_service.invoke` boundary (plan 02-03).
///
/// Every field is a primitive or primitive-compatible type so
/// `toMap` / `fromMap` can serialize it to a `Map<String, Object?>` for
/// the isolate channel.
///
/// Phase 2 scope: consumed by plan 02-05's persistence path, which inserts
/// the trip row and enqueues the sync-queue entry inside a single Drift
/// transaction. Phase 2 does NOT hold the raw list of `Position` samples
/// beyond `TripAccumulator` — PII (lat/lng) stays inside the service
/// isolate and only the encoded polyline leaves it (D-06).
@immutable
class FinalizedTrip {
  /// Create a finalized trip DTO. All timestamps must be UTC.
  const FinalizedTrip({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.timeMovingSeconds,
    required this.timeStuckSeconds,
    required this.encodedPolyline,
  });

  /// Reconstruct a [FinalizedTrip] from its [toMap] form.
  factory FinalizedTrip.fromMap(Map<String, Object?> map) {
    return FinalizedTrip(
      id: _req<String>(map, 'id'),
      startTime: DateTime.fromMicrosecondsSinceEpoch(
        _req<int>(map, 'startTimeUs'),
        isUtc: true,
      ),
      endTime: DateTime.fromMicrosecondsSinceEpoch(
        _req<int>(map, 'endTimeUs'),
        isUtc: true,
      ),
      durationSeconds: _req<int>(map, 'durationSeconds'),
      distanceMeters: _req<num>(map, 'distanceMeters').toDouble(),
      timeMovingSeconds: _req<int>(map, 'timeMovingSeconds'),
      timeStuckSeconds: _req<int>(map, 'timeStuckSeconds'),
      encodedPolyline: _req<String>(map, 'encodedPolyline'),
    );
  }

  /// Client-generated UUID v4. Unique per trip; produced inside
  /// `TripAccumulator` on construction so the id is stable across
  /// snapshot → finalize.
  final String id;

  /// Trip start timestamp in UTC.
  final DateTime startTime;

  /// Trip end timestamp in UTC.
  final DateTime endTime;

  /// `endTime - startTime` in whole seconds, computed at finalize time.
  final int durationSeconds;

  /// Total distance in meters accumulated by the Haversine sum across all
  /// accepted sample pairs.
  final double distanceMeters;

  /// Seconds attributed to "moving" (prev.speed ≥ `kStuckSpeedThresholdMs`).
  final int timeMovingSeconds;

  /// Seconds attributed to "stuck" (prev.speed < `kStuckSpeedThresholdMs`).
  final int timeStuckSeconds;

  /// Google-polyline-algorithm encoded route. Empty string if the trip
  /// accumulated fewer than two samples.
  final String encodedPolyline;

  /// Serialize to a primitive-only map safe to send across the service →
  /// UI isolate boundary via `flutter_background_service.invoke`.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'startTimeUs': startTime.toUtc().microsecondsSinceEpoch,
      'endTimeUs': endTime.toUtc().microsecondsSinceEpoch,
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'timeMovingSeconds': timeMovingSeconds,
      'timeStuckSeconds': timeStuckSeconds,
      'encodedPolyline': encodedPolyline,
    };
  }

  /// Return a copy with selected fields replaced. Useful for test builders
  /// and for the persistence layer when it needs to rewrite a field
  /// without allocating a new constructor call site.
  FinalizedTrip copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    double? distanceMeters,
    int? timeMovingSeconds,
    int? timeStuckSeconds,
    String? encodedPolyline,
  }) {
    return FinalizedTrip(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      timeMovingSeconds: timeMovingSeconds ?? this.timeMovingSeconds,
      timeStuckSeconds: timeStuckSeconds ?? this.timeStuckSeconds,
      encodedPolyline: encodedPolyline ?? this.encodedPolyline,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FinalizedTrip &&
        other.id == id &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.durationSeconds == durationSeconds &&
        other.distanceMeters == distanceMeters &&
        other.timeMovingSeconds == timeMovingSeconds &&
        other.timeStuckSeconds == timeStuckSeconds &&
        other.encodedPolyline == encodedPolyline;
  }

  @override
  int get hashCode => Object.hash(
    id,
    startTime,
    endTime,
    durationSeconds,
    distanceMeters,
    timeMovingSeconds,
    timeStuckSeconds,
    encodedPolyline,
  );
}

/// Typed required-key lookup helper. Keeps `strict-casts: true` happy by
/// funneling the cast through one call site instead of sprinkling `as`
/// through every fromMap field.
T _req<T>(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    throw ArgumentError.value(
      map,
      'map',
      'missing required key "$key"',
    );
  }
  return value as T;
}
