import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/state/finalized_trip.dart';
import 'package:traevy/features/tracking/services/trip_state_persister.dart';
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
    this.isPaused = false,
    this.pausedSeconds = 0,
    this.breakCount = 0,
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
      // Phase 18 (D-06): pause fields are backward-tolerant — a pre-Phase-18
      // snapshot map omits these keys and decodes to the running defaults.
      isPaused: map['isPaused'] as bool? ?? false,
      pausedSeconds: map['pausedSeconds'] as int? ?? 0,
      breakCount: map['breakCount'] as int? ?? 0,
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

  /// Whether the trip is currently paused (Phase 18, D-06). While paused the
  /// UI freezes the timer and shows a "paused" affordance (Plan 18-03).
  final bool isPaused;

  /// Total seconds spent paused so far, including the currently-open break
  /// span while [isPaused] (Phase 18, D-06).
  final int pausedSeconds;

  /// Number of break segments so far, counting the currently-open break
  /// while [isPaused] (Phase 18, D-06).
  final int breakCount;

  /// Serialize to a primitive-only map safe for the isolate channel.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'startedAtUs': startedAt.toUtc().microsecondsSinceEpoch,
      'elapsedSeconds': elapsedSeconds,
      'distanceMeters': distanceMeters,
      'timeMovingSeconds': timeMovingSeconds,
      'timeStuckSeconds': timeStuckSeconds,
      'currentSpeedMs': currentSpeedMs,
      'isPaused': isPaused,
      'pausedSeconds': pausedSeconds,
      'breakCount': breakCount,
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
  TripAccumulator({
    required this.startedAt,
    String? tripId,
    TripStatePersister? persister,
  })  : _tripId = tripId ?? const Uuid().v4(),
        _persister = persister;

  final TripStatePersister? _persister;

  /// Restore an accumulator from a previously saved state.
  factory TripAccumulator.restore(Map<String, dynamic> state, {TripStatePersister? persister}) {
    final acc = TripAccumulator(
      startedAt: DateTime.fromMicrosecondsSinceEpoch(state['startedAtUs'] as int, isUtc: true),
      tripId: state['_tripId'] as String,
      persister: persister,
    );
    if (state['_lastAccepted'] != null) {
      acc._lastAccepted = Position.fromMap(Map<String, dynamic>.from(state['_lastAccepted'] as Map));
    }
    if (state['_lastAcceptedAtUs'] != null) {
      acc._lastAcceptedAt = DateTime.fromMicrosecondsSinceEpoch(state['_lastAcceptedAtUs'] as int, isUtc: true);
    }
    acc._distanceMeters = (state['_distanceMeters'] as num).toDouble();
    acc._timeMovingSeconds = state['_timeMovingSeconds'] as int;
    acc._timeStuckSeconds = state['_timeStuckSeconds'] as int;
    
    final samples = state['_samples'] as List;
    acc._samples.addAll(samples.map((s) => Position.fromMap(Map<String, dynamic>.from(s as Map))));
    
    acc._finalized = state['_finalized'] as bool;
    acc._isPaused = state['_isPaused'] as bool;
    if (state['_currentPauseStartUs'] != null) {
      acc._currentPauseStart = DateTime.fromMicrosecondsSinceEpoch(state['_currentPauseStartUs'] as int, isUtc: true);
    }
    acc._accumulatedPausedSeconds = state['_accumulatedPausedSeconds'] as int;
    
    final breaks = state['_breaks'] as List;
    acc._breaks.addAll(breaks.map((b) {
      final map = b as Map;
      return (
        DateTime.fromMicrosecondsSinceEpoch(map['startUs'] as int, isUtc: true),
        DateTime.fromMicrosecondsSinceEpoch(map['endUs'] as int, isUtc: true),
      );
    }));

    return acc;
  }

  /// Dump the internal state to a JSON-serializable map.
  Map<String, dynamic> dumpState() {
    return {
      'startedAtUs': startedAt.toUtc().microsecondsSinceEpoch,
      '_tripId': _tripId,
      '_lastAccepted': _lastAccepted?.toJson(),
      '_lastAcceptedAtUs': _lastAcceptedAt?.toUtc().microsecondsSinceEpoch,
      '_distanceMeters': _distanceMeters,
      '_timeMovingSeconds': _timeMovingSeconds,
      '_timeStuckSeconds': _timeStuckSeconds,
      '_samples': _samples.map((p) => p.toJson()).toList(),
      '_finalized': _finalized,
      '_isPaused': _isPaused,
      '_currentPauseStartUs': _currentPauseStart?.toUtc().microsecondsSinceEpoch,
      '_accumulatedPausedSeconds': _accumulatedPausedSeconds,
      '_breaks': _breaks.map((b) => {
        'startUs': b.$1.toUtc().microsecondsSinceEpoch,
        'endUs': b.$2.toUtc().microsecondsSinceEpoch,
      }).toList(),
    };
  }

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

  // Phase 18 pause model (D-05/D-06/D-07).
  bool _isPaused = false;
  // UTC instant of the currently-open break's pause, or null while running.
  DateTime? _currentPauseStart;
  // Seconds accumulated from already-closed break segments.
  int _accumulatedPausedSeconds = 0;
  // Completed (pauseStart, resumeEnd) break segments, both UTC.
  final List<(DateTime start, DateTime end)> _breaks = <(DateTime, DateTime)>[];

  /// Add one GPS fix. Safe to call many times per second. Samples with
  /// accuracy worse than [kTrackingMaxAcceptableAccuracyMeters] are
  /// silently dropped. After [finalize] has been called, further calls
  /// are no-ops.
  ///
  /// Returns the interval's classification for the prev → curr pair when this
  /// sample ATTRIBUTED time — `(stuck: prev.speed < kStuckSpeedThresholdMs,
  /// seconds: rounded interval)` — or `null` when no time was attributed (the
  /// sample was dropped on the accuracy gate, was the first sample, had a
  /// zero/negative delta, arrived while paused, or the gap exceeded
  /// [kTrackingMaxAttributableGapSeconds]). The internal moving/stuck/distance
  /// counters remain authoritative; the return value is purely informational so
  /// the service isolate can feed the SAME classification into the
  /// `AutoPauseDetector` without re-deriving speed or introducing a second
  /// threshold (Phase 18 Plan 04, D-11). Existing callers may ignore the return
  /// — `void`-style `accumulator.addSample(p);` is still valid.
  ({bool stuck, int seconds})? addSample(Position p) {
    if (_finalized) return null;
    if (p.accuracy > kTrackingMaxAcceptableAccuracyMeters) return null;

    final prev = _lastAccepted;
    if (prev == null) {
      _lastAccepted = p;
      _lastAcceptedAt = p.timestamp;
      _samples.add(p);
      _persister?.saveState(dumpState());
      return null;
    }

    final deltaMillis = p.timestamp.difference(prev.timestamp).inMilliseconds;
    if (deltaMillis <= 0) {
      // Clock skew or duplicate: keep the sample in the polyline (so the
      // path is visually complete) but do not move distance or time
      // counters — T-02-05 tampering guard.
      _samples.add(p);
      _lastAccepted = p;
      _lastAcceptedAt = p.timestamp;
      _persister?.saveState(dumpState());
      return null;
    }

    // Phase 18 (D-05): while paused, keep the sample in the polyline so the
    // path bridges the gap (last-pre-pause → first-post-resume draws one
    // straight line) but attribute NO distance and NO moving/stuck time. We
    // advance _lastAccepted to this sample so the first post-resume interval
    // bridges from here — but the paused interval itself contributes nothing
    // to _distanceMeters/_timeMovingSeconds/_timeStuckSeconds (T-18-04: paused
    // time must never leak into the stuck/moving metric or distance).
    if (_isPaused) {
      _samples.add(p);
      _lastAccepted = p;
      _lastAcceptedAt = p.timestamp;
      _persister?.saveState(dumpState());
      return null;
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
    ({bool stuck, int seconds})? interval;
    if (deltaSec <= kTrackingMaxAttributableGapSeconds) {
      final deltaSecInt = deltaSec.round();
      // D-03: prev.speed classifies the prev → curr INTERVAL.
      // kStuckSpeedThresholdMs is pre-converted at compile time in
      // constants.dart so the comparison is unit-correct against the
      // m/s value from geolocator with zero per-sample conversion
      // overhead (Pitfall 2).
      final stuck = prev.speed < kStuckSpeedThresholdMs;
      if (stuck) {
        _timeStuckSeconds += deltaSecInt;
      } else {
        _timeMovingSeconds += deltaSecInt;
      }
      // Phase 18 (D-11): hand the service isolate the SAME classification the
      // counters above used — never a second speed comparison.
      interval = (stuck: stuck, seconds: deltaSecInt);
    }

    _lastAccepted = p;
    _lastAcceptedAt = p.timestamp;
    _samples.add(p);
    _persister?.saveState(dumpState());
    return interval;
  }

  /// Begin a break at [at] (UTC). Idempotent: a `pause` while already paused
  /// is a no-op, so the open break stays anchored at the FIRST pause instant.
  /// A `pause` after [finalize] is a no-op (Phase 18, D-05).
  void pause(DateTime at) {
    if (_finalized || _isPaused) return;
    _isPaused = true;
    _currentPauseStart = at.toUtc();
    _persister?.saveState(dumpState());
  }

  /// End the current break at [at] (UTC): record the `(start, end)` segment
  /// and fold its whole-second span into the accumulated paused total. A
  /// `resume` while not paused — or after [finalize] — is a no-op
  /// (Phase 18, D-05).
  void resume(DateTime at) {
    if (_finalized || !_isPaused) return;
    final pauseStart = _currentPauseStart!;
    final end = at.toUtc();
    _breaks.add((pauseStart, end));
    _accumulatedPausedSeconds += end.difference(pauseStart).inSeconds;
    _isPaused = false;
    _currentPauseStart = null;
    _persister?.saveState(dumpState());
  }

  /// Total paused seconds as of [now], including the currently-open break
  /// span while paused (Phase 18, D-06).
  int _pausedSecondsAt(DateTime now) {
    if (!_isPaused) return _accumulatedPausedSeconds;
    return _accumulatedPausedSeconds +
        now.toUtc().difference(_currentPauseStart!).inSeconds;
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
    final isFresh =
        lastAt != null &&
        now.difference(lastAt) <= kTrackingSpeedFreshnessWindow;
    // D-06: the displayed timer freezes the instant pause fires. While paused
    // we measure elapsed up to the pause instant (not `now`), and we always
    // subtract the accumulated paused time so the active timer resumes
    // ticking from where it stopped after resume.
    final refNow = _isPaused ? (_currentPauseStart ?? now) : now;
    // D-06: subtract only the CLOSED paused segments here. The currently-open
    // break is already excluded by freezing `refNow` at the pause instant —
    // adding the open span again would double-count and drive elapsed
    // negative. After resume, `refNow == now` and the just-closed span lives
    // in `_accumulatedPausedSeconds`, so the active timer continues smoothly.
    final elapsedSeconds =
        refNow.difference(startedAt).inSeconds - _accumulatedPausedSeconds;
    return TripSnapshot(
      startedAt: startedAt,
      elapsedSeconds: elapsedSeconds,
      distanceMeters: _distanceMeters,
      timeMovingSeconds: _timeMovingSeconds,
      timeStuckSeconds: _timeStuckSeconds,
      currentSpeedMs: isFresh ? (_lastAccepted?.speed ?? 0) : 0,
      isPaused: _isPaused,
      pausedSeconds: _pausedSecondsAt(now),
      breakCount: _breaks.length + (_isPaused ? 1 : 0),
    );
  }

  /// Build the final [FinalizedTrip]. After calling, further [addSample]
  /// invocations are no-ops. Returns a DTO whose [FinalizedTrip.toMap]
  /// output is safe to send across the service → UI isolate boundary.
  FinalizedTrip finalize(DateTime endedAt) {
    _finalized = true;
    final end = endedAt.toUtc();
    // D-07: a Stop while paused closes the open break at the stop instant so
    // the persisted trip never carries an open segment.
    if (_isPaused) {
      final pauseStart = _currentPauseStart!;
      _breaks.add((pauseStart, end));
      _accumulatedPausedSeconds += end.difference(pauseStart).inSeconds;
      _isPaused = false;
      _currentPauseStart = null;
    }
    final totalPaused = _accumulatedPausedSeconds;
    final encoded = encodePolyline(
      _samples
          .map((p) => (lat: p.latitude, lng: p.longitude))
          .toList(growable: false),
    );
    // D-07: serialize break segments as primitive UTC-microsecond maps so the
    // list crosses the service → UI isolate boundary with no DateTime/object
    // (T-18-05). timeMoving/timeStuck already exclude paused intervals — they
    // were never attributed while paused (D-05).
    final breakMaps = _breaks
        .map(
          (b) => <String, Object?>{
            'startUs': b.$1.toUtc().microsecondsSinceEpoch,
            'endUs': b.$2.toUtc().microsecondsSinceEpoch,
          },
        )
        .toList(growable: false);
    
    _persister?.clear();
    
    return FinalizedTrip(
      id: _tripId,
      startTime: startedAt.toUtc(),
      endTime: end,
      // D-03/D-07: ACTIVE duration = wall-clock − total paused.
      durationSeconds: end.difference(startedAt).inSeconds - totalPaused,
      distanceMeters: _distanceMeters,
      timeMovingSeconds: _timeMovingSeconds,
      timeStuckSeconds: _timeStuckSeconds,
      encodedPolyline: encoded,
      totalPausedSeconds: totalPaused,
      breaks: breakMaps,
    );
  }

  /// Whether a break is currently open (Phase 18). Public so the service
  /// isolate can gate the auto-pause prompt on `!isPaused` — a prompt must
  /// never fire while the trip is already paused (Plan 04, D-12).
  bool get isPaused => _isPaused;

  /// For testing: current distance accumulator in meters.
  @visibleForTesting
  double get distanceMetersForTest => _distanceMeters;

  /// For testing: current moving-seconds accumulator.
  @visibleForTesting
  int get timeMovingSecondsForTest => _timeMovingSeconds;

  /// For testing: current stuck-seconds accumulator.
  @visibleForTesting
  int get timeStuckSecondsForTest => _timeStuckSeconds;

  /// For testing: whether a break is currently open.
  @visibleForTesting
  bool get isPausedForTest => _isPaused;

  /// For testing: paused seconds from already-closed segments only.
  @visibleForTesting
  int get accumulatedPausedSecondsForTest => _accumulatedPausedSeconds;
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
