import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/state/finalized_trip.dart';
import 'package:traevy/shared/utils/polyline_codec.dart';
import 'package:uuid/uuid.dart';

/// Instantaneous read-only snapshot of an in-progress trip, emitted from
/// the tracking service isolate to the UI isolate every
/// `kTrackingUiUpdateInterval`.
///
/// All fields are primitive-compatible so `toMap` / `fromMap` can send
/// the snapshot across the `flutter_background_service.invoke` channel.
@immutable
class TripSnapshot {
  /// Construct a snapshot. [startedAt] must be UTC.
  const TripSnapshot({
    required this.startedAt,
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.timeMovingSeconds,
    required this.timeStuckSeconds,
    required this.currentSpeedMs,
  });

  /// Rebuild a [TripSnapshot] from its [toMap] form.
  factory TripSnapshot.fromMap(Map<String, Object?> map) {
    return TripSnapshot(
      startedAt: DateTime.fromMicrosecondsSinceEpoch(
        _req<int>(map, 'startedAtUs'),
        isUtc: true,
      ),
      elapsedSeconds: _req<int>(map, 'elapsedSeconds'),
      distanceMeters: _req<num>(map, 'distanceMeters').toDouble(),
      timeMovingSeconds: _req<int>(map, 'timeMovingSeconds'),
      timeStuckSeconds: _req<int>(map, 'timeStuckSeconds'),
      currentSpeedMs: _req<num>(map, 'currentSpeedMs').toDouble(),
    );
  }

  /// Wall-clock time (UTC) the trip started.
  final DateTime startedAt;

  /// `now - startedAt` in whole seconds when the snapshot was produced.
  final int elapsedSeconds;

  /// Running distance in meters from the accumulator.
  final double distanceMeters;

  /// Running moving-seconds counter from the accumulator.
  final int timeMovingSeconds;

  /// Running stuck-seconds counter from the accumulator.
  final int timeStuckSeconds;

  /// Latest accepted sample's `Position.speed` in meters per second, or 0
  /// if no sample has been accepted yet.
  final double currentSpeedMs;

  /// Serialize to a primitive-only map safe for the isolate channel.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'startedAtUs': startedAt.toUtc().microsecondsSinceEpoch,
      'elapsedSeconds': elapsedSeconds,
      'distanceMeters': distanceMeters,
      'timeMovingSeconds': timeMovingSeconds,
      'timeStuckSeconds': timeStuckSeconds,
      'currentSpeedMs': currentSpeedMs,
    };
  }
}

/// Streaming accumulator for a single in-progress trip. Owned by the
/// tracking service isolate (plan 02-03). Lifecycle:
///
///   1. Construct with the trip `startedAt` (UTC).
///   2. Call [addSample] for every GPS fix that arrives from the
///      `geolocator` position stream.
///   3. Call [snapshot] on the 1 Hz UI timer to produce a payload for the
///      UI isolate.
///   4. Call [finalize] once on Stop to produce a [FinalizedTrip].
///
/// Key design points:
///
/// * **D-02**: uses `Position.speed` directly — never derives speed from
///   distance/time deltas.
/// * **D-03**: classifies the INTERVAL `(prev → curr)` by `prev.speed`.
///   Classification uses [kStuckSpeedThresholdMs] (meters per second,
///   pre-derived in `constants.dart`) so the comparison is unit-correct
///   against `Position.speed` without per-sample conversion. Guards
///   Pitfall 2 — never bring the km/h constant into this file.
/// * **D-04**: distance is summed via `Geolocator.distanceBetween` on each
///   accepted sample pair.
/// * **D-06**: samples live in memory only. No incremental persistence.
/// * **Pitfall 6**: samples with accuracy worse than
///   [kTrackingMaxAcceptableAccuracyMeters] are dropped. Intervals longer
///   than [kTrackingMaxAttributableGapSeconds] still contribute distance
///   but are excluded from time attribution.
///
/// **Accepted drift**: `timeMovingSeconds + timeStuckSeconds` MAY differ
/// from `durationSeconds` by a few seconds when samples are dropped or
/// gaps exceed the attribution window. This is intentional — RESEARCH §6
/// "accept sub-second drift" ruling. Phase 3/5 should not treat this as a
/// bug.
///
/// **Security**: this class MUST NOT log `Position` fields. Raw lat/lng
/// is PII (T-02-07 in the plan's threat model). The only allowed egress
/// is the encoded polyline inside [FinalizedTrip], which is stored in
/// Drift (never logged, never printed).
class TripAccumulator {
  /// Create an accumulator for a new trip. [startedAt] should be the
  /// wall-clock UTC instant the Start button was tapped.
  TripAccumulator({required this.startedAt}) : _tripId = const Uuid().v4();

  /// UTC instant the trip started.
  final DateTime startedAt;

  /// Stable trip id (UUID v4) generated once on construction so snapshot
  /// and finalize both refer to the same id.
  final String _tripId;

  Position? _lastAccepted;
  // Timestamp of the most-recently accepted sample. Used by snapshot() to
  // decide whether _lastAccepted.speed is still fresh enough to surface as
  // currentSpeedMs. Set wherever _lastAccepted is set.
  DateTime? _lastAcceptedAt;
  double _distanceMeters = 0;
  int _timeMovingSeconds = 0;
  int _timeStuckSeconds = 0;
  final List<Position> _samples = <Position>[];
  bool _finalized = false;

  /// Add one GPS fix. Safe to call many times per second. Samples with
  /// accuracy worse than [kTrackingMaxAcceptableAccuracyMeters] are
  /// silently dropped. After [finalize] has been called, further calls
  /// are no-ops.
  void addSample(Position p) {
    if (_finalized) return;
    if (p.accuracy > kTrackingMaxAcceptableAccuracyMeters) return;

    final prev = _lastAccepted;
    if (prev == null) {
      _lastAccepted = p;
      _lastAcceptedAt = p.timestamp;
      _samples.add(p);
      return;
    }

    final deltaMillis = p.timestamp.difference(prev.timestamp).inMilliseconds;
    if (deltaMillis <= 0) {
      // Clock skew or duplicate: keep the sample in the polyline (so the
      // path is visually complete) but do not move distance or time
      // counters — T-02-05 tampering guard.
      _samples.add(p);
      _lastAccepted = p;
      _lastAcceptedAt = p.timestamp;
      return;
    }
    final deltaSec = deltaMillis / 1000.0;

    // Distance accumulates regardless of gap size — Haversine is robust
    // and the user still traveled between the two fixes even if the
    // stream paused in between.
    _distanceMeters += Geolocator.distanceBetween(
      prev.latitude,
      prev.longitude,
      p.latitude,
      p.longitude,
    );

    // Time attribution is gap-guarded: gaps longer than
    // kTrackingMaxAttributableGapSeconds don't move the moving/stuck
    // buckets, because we have no evidence the user was actually
    // moving during the black hole (tunnel, GPS dropout, suspend).
    if (deltaSec <= kTrackingMaxAttributableGapSeconds) {
      final deltaSecInt = deltaSec.round();
      // D-03: prev.speed classifies the prev → curr INTERVAL.
      // kStuckSpeedThresholdMs is pre-converted at compile time in
      // constants.dart so the comparison is unit-correct against the
      // m/s value from geolocator with zero per-sample conversion
      // overhead (Pitfall 2).
      if (prev.speed >= kStuckSpeedThresholdMs) {
        _timeMovingSeconds += deltaSecInt;
      } else {
        _timeStuckSeconds += deltaSecInt;
      }
    }

    _lastAccepted = p;
    _lastAcceptedAt = p.timestamp;
    _samples.add(p);
  }

  /// Project the current accumulator state into a [TripSnapshot] for
  /// streaming to the UI isolate.
  ///
  /// `currentSpeedMs` is gated on `kTrackingSpeedFreshnessWindow`: when the
  /// most-recent accepted sample is older than the window, the snapshot
  /// reports speed 0. This prevents the SPEED tile from "sticking" at the
  /// last in-motion value when the device stops emitting fresh GPS samples
  /// (Android throttles emissions when stationary, and the 30 m accuracy
  /// gate drops stationary low-accuracy samples). Diagnosed in
  /// `.planning/debug/active-speed-tile-stale.md`.
  TripSnapshot snapshot(DateTime now) {
    final lastAt = _lastAcceptedAt;
    final isFresh = lastAt != null &&
        now.difference(lastAt) <= kTrackingSpeedFreshnessWindow;
    return TripSnapshot(
      startedAt: startedAt,
      elapsedSeconds: now.difference(startedAt).inSeconds,
      distanceMeters: _distanceMeters,
      timeMovingSeconds: _timeMovingSeconds,
      timeStuckSeconds: _timeStuckSeconds,
      currentSpeedMs: isFresh ? (_lastAccepted?.speed ?? 0) : 0,
    );
  }

  /// Build the final [FinalizedTrip]. After calling, further [addSample]
  /// invocations are no-ops. Returns a DTO whose [FinalizedTrip.toMap]
  /// output is safe to send across the service → UI isolate boundary.
  FinalizedTrip finalize(DateTime endedAt) {
    _finalized = true;
    final encoded = encodePolyline(
      _samples
          .map((p) => (lat: p.latitude, lng: p.longitude))
          .toList(growable: false),
    );
    return FinalizedTrip(
      id: _tripId,
      startTime: startedAt.toUtc(),
      endTime: endedAt.toUtc(),
      durationSeconds: endedAt.difference(startedAt).inSeconds,
      distanceMeters: _distanceMeters,
      timeMovingSeconds: _timeMovingSeconds,
      timeStuckSeconds: _timeStuckSeconds,
      encodedPolyline: encoded,
    );
  }

  /// For testing: current distance accumulator in meters.
  @visibleForTesting
  double get distanceMetersForTest => _distanceMeters;

  /// For testing: current moving-seconds accumulator.
  @visibleForTesting
  int get timeMovingSecondsForTest => _timeMovingSeconds;

  /// For testing: current stuck-seconds accumulator.
  @visibleForTesting
  int get timeStuckSecondsForTest => _timeStuckSeconds;
}

/// Typed required-key lookup helper used by [TripSnapshot.fromMap] to
/// keep `strict-casts: true` happy.
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
