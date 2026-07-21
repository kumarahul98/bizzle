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
    this.totalPausedSeconds = 0,
    this.breaks = const <Map<String, Object?>>[],
    this.stuckSegments = const <Map<String, Object?>>[],
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
      // Phase 18 (D-07): the pause aggregate + break segments are
      // backward-tolerant — a pre-Phase-18 map omits both keys, decoding to
      // the safe defaults (no breaks, zero paused).
      totalPausedSeconds: map['totalPausedSeconds'] as int? ?? 0,
      breaks: _decodePrimitiveMaps(map['breaks']),
      // Phase 31 (D-02): also backward-tolerant — a pre-Phase-31 map omits
      // the key and decodes to no segments, which renders exactly as today
      // (D-06).
      stuckSegments: _decodePrimitiveMaps(map['stuckSegments']),
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

  /// Total seconds the trip spent paused across every break (Phase 18, D-07).
  /// Subtracted from wall-clock to yield the ACTIVE [durationSeconds]. Zero
  /// for a trip that never paused, so historical rows are unchanged.
  final int totalPausedSeconds;

  /// Completed break segments, each a primitive map of UTC microseconds
  /// (`{'startUs': int, 'endUs': int}`) so the list crosses the
  /// service → UI isolate boundary as primitives only (Phase 18, D-07).
  /// The persist path decodes these into `trip_breaks` rows. Empty for a
  /// trip that never paused.
  final List<Map<String, Object?>> breaks;

  /// Contiguous stuck stretches that survived the `kStuckSegmentMinSeconds`
  /// floor, each a primitive map
  /// (`{'startIndex': int, 'endIndex': int, 'startUs': int, 'endUs': int}`)
  /// so the list crosses the service → UI isolate boundary as primitives only
  /// (Phase 31, D-02/D-03). The indices address the decoded
  /// [encodedPolyline]'s points inclusively. The persist path decodes these
  /// into `trip_stuck_segments` rows. Empty for a manual entry, for a trip
  /// with no run over the floor, and for every trip recorded before Phase 31.
  ///
  /// LOCAL-ONLY (D-04): never serialized into a sync payload.
  final List<Map<String, Object?>> stuckSegments;

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
      'totalPausedSeconds': totalPausedSeconds,
      // Re-wrap each segment as a fresh primitive map so the serialized list
      // is a plain List<Map<String,Object?>> with no DateTime/object leaking
      // onto the isolate channel (T-18-05).
      'breaks': breaks
          .map(
            (b) => <String, Object?>{
              'startUs': b['startUs'],
              'endUs': b['endUs'],
            },
          )
          .toList(growable: false),
      // Same re-wrap discipline as `breaks` — plain primitive maps only.
      'stuckSegments': stuckSegments
          .map(
            (s) => <String, Object?>{
              'startIndex': s['startIndex'],
              'endIndex': s['endIndex'],
              'startUs': s['startUs'],
              'endUs': s['endUs'],
            },
          )
          .toList(growable: false),
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
    int? totalPausedSeconds,
    List<Map<String, Object?>>? breaks,
    List<Map<String, Object?>>? stuckSegments,
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
      totalPausedSeconds: totalPausedSeconds ?? this.totalPausedSeconds,
      breaks: breaks ?? this.breaks,
      stuckSegments: stuckSegments ?? this.stuckSegments,
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
        other.encodedPolyline == encodedPolyline &&
        other.totalPausedSeconds == totalPausedSeconds &&
        _primitiveMapsEqual(other.breaks, breaks) &&
        _primitiveMapsEqual(other.stuckSegments, stuckSegments);
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
    totalPausedSeconds,
    Object.hashAll(
      breaks.map((b) => Object.hash(b['startUs'], b['endUs'])),
    ),
    Object.hashAll(
      stuckSegments.map((s) => Object.hash(s['startIndex'], s['endIndex'])),
    ),
  );
}

/// Deep value-equality for a primitive map list (breaks, stuck segments): a
/// per-element [mapEquals] gives the value semantics the default `List.==`
/// (identity) would not.
bool _primitiveMapsEqual(
  List<Map<String, Object?>> a,
  List<Map<String, Object?>> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!mapEquals(a[i], b[i])) return false;
  }
  return true;
}

/// Decode a primitive map list (`breaks`, `stuckSegments`) from a
/// [FinalizedTrip.toMap] / isolate-channel map into a typed
/// `List<Map<String, Object?>>`. A missing or null value (a legacy map from
/// before the field existed) decodes to an empty list.
List<Map<String, Object?>> _decodePrimitiveMaps(Object? raw) {
  if (raw is! List) {
    return const <Map<String, Object?>>[];
  }
  return raw
      .map((e) => (e as Map).cast<String, Object?>())
      .toList(growable: false);
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
