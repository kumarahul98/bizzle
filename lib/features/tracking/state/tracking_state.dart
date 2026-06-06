import 'package:flutter/foundation.dart';

/// Sealed high-level state of the tracking feature as observed by the UI
/// isolate. Phase 2 widgets (plan 02-04) switch exhaustively on this type
/// to decide whether to show the idle home CTA, the three live tiles, a
/// spinner, or an error banner.
///
/// Why a sealed class:
/// * exhaustive `switch` / pattern matching with no `default` branch — a
///   new variant would be a compile error at every call site, which is
///   what we want;
/// * matches CLAUDE.md's "Use `sealed` classes for finite state" rule for
///   tracking, sync, and direction enums;
/// * avoids the `enum TrackingStatus { idle, starting, active, ... }` +
///   parallel `TrackingData` pair that Phase 1 researchers considered and
///   rejected as too leaky.
///
/// Unit conversion contract: `currentSpeedKmh` on [TrackingActive] is the
/// ONLY place in Phase 2 where a UI-facing km/h value exists. The service
/// isolate (`TripAccumulator` + `TripSnapshot`) keeps everything in m/s
/// so the traffic-stuck classification can compare raw `Position.speed`
/// against the pre-derived `kStuckSpeedThresholdMs` without per-sample
/// conversion (Pitfall 2). Conversion happens exactly once, in
/// [trackingActiveFromSnapshotMap], at the service → UI isolate boundary.
@immutable
sealed class TrackingState {
  const TrackingState();
}

/// No trip in progress. Shown when the app opens and after a trip is
/// saved or discarded.
final class TrackingIdle extends TrackingState {
  /// Const constructor — singleton at every call site.
  const TrackingIdle();
}

/// User tapped Start, the service is initialising, but the first GPS
/// sample has not yet arrived. UI shows a spinner, not the tiles.
final class TrackingStarting extends TrackingState {
  /// Const constructor — singleton at every call site.
  const TrackingStarting();
}

/// Live tracking — every field is refreshed at `kTrackingUiUpdateInterval`
/// from the service isolate via `service.invoke('tracking_state', ...)`.
final class TrackingActive extends TrackingState {
  /// Construct a new live-tracking state. [startedAt] must be UTC to
  /// match the accumulator's internal clock.
  const TrackingActive({
    required this.startedAt,
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.currentSpeedKmh,
    required this.timeMovingSeconds,
    required this.timeStuckSeconds,
    this.isPaused = false,
    this.pausedSeconds = 0,
    this.breakCount = 0,
  });

  /// UTC wall-clock time the trip started.
  final DateTime startedAt;

  /// `now - startedAt` in whole seconds at snapshot time.
  final int elapsedSeconds;

  /// Running distance counter in meters.
  final double distanceMeters;

  /// Latest accepted sample's speed, in kilometers per hour. This is the
  /// ONLY UI-facing km/h value in Phase 2 — everything below the isolate
  /// boundary stays in m/s.
  final double currentSpeedKmh;

  /// Running moving-seconds counter (interval classified by prev.speed
  /// ≥ stuck threshold).
  final int timeMovingSeconds;

  /// Running stuck-seconds counter (interval classified by prev.speed
  /// < stuck threshold).
  final int timeStuckSeconds;

  /// Whether the trip is currently paused (Phase 18, D-08). Driven purely by
  /// the latest snapshot — the UI is a dumb terminal and never derives this
  /// locally, so after a backgrounding/kill the first reconnected snapshot
  /// dictates the paused-or-running display.
  final bool isPaused;

  /// Total seconds spent paused across all breaks so far (Phase 18). Reflects
  /// the snapshot's running paused-time aggregate.
  final int pausedSeconds;

  /// Number of completed break spans so far (Phase 18). Surfaced as the hero's
  /// break-count indicator. A currently-open break is not counted until it is
  /// closed by a resume.
  final int breakCount;
}

/// Stop tapped but persistence not yet complete. Brief — the UI may show
/// a "Saving trip" spinner or just dim the Stop button. Plan 02-05 will
/// add the Drift transaction that this state bridges.
final class TrackingStopping extends TrackingState {
  /// Const constructor — singleton at every call site.
  const TrackingStopping();
}

/// Terminal error path. [message] is user-facing and never empty.
final class TrackingError extends TrackingState {
  /// Construct an error state. Throws [ArgumentError] if [message] is
  /// empty — the UI contract requires a non-empty message to render.
  TrackingError(this.message) {
    if (message.isEmpty) {
      throw ArgumentError.value(
        message,
        'message',
        'TrackingError message must not be empty',
      );
    }
  }

  /// User-facing error description.
  final String message;
}

/// Convert a `TripSnapshot.toMap()` payload from the service isolate into
/// a UI-ready [TrackingActive] instance.
///
/// This is the ONE and ONLY place in Phase 2 where m/s → km/h conversion
/// happens for UI display. The service isolate keeps `currentSpeedMs` in
/// meters per second so it can compare directly against
/// `kStuckSpeedThresholdMs` (Pitfall 2 guard); the UI isolate wants km/h
/// for display only. Centralising the conversion here means:
///
/// * there is a single grep target (`* 3.6`) for "where does km/h come
///   from";
/// * the accumulator's classification math cannot accidentally mix units;
/// * any future change to the UI unit can touch exactly one line.
///
/// The incoming map is the same shape `TripSnapshot.toMap()` produces:
///
/// ```dart
/// {
///   'startedAtUs': int microseconds since epoch (UTC),
///   'elapsedSeconds': int,
///   'distanceMeters': num,
///   'timeMovingSeconds': int,
///   'timeStuckSeconds': int,
///   'currentSpeedMs': num,
/// }
/// ```
///
/// Throws [ArgumentError] if any required key is missing.
TrackingActive trackingActiveFromSnapshotMap(Map<String, Object?> map) {
  return TrackingActive(
    startedAt: DateTime.fromMicrosecondsSinceEpoch(
      _req<int>(map, 'startedAtUs'),
      isUtc: true,
    ),
    elapsedSeconds: _req<int>(map, 'elapsedSeconds'),
    distanceMeters: _req<num>(map, 'distanceMeters').toDouble(),
    // Isolate-boundary unit conversion — see function doc. Do NOT move
    // this multiplication deeper into the accumulator; the accumulator
    // compares raw `Position.speed` (m/s) against `kStuckSpeedThresholdMs`.
    currentSpeedKmh: _req<num>(map, 'currentSpeedMs').toDouble() * 3.6,
    timeMovingSeconds: _req<int>(map, 'timeMovingSeconds'),
    timeStuckSeconds: _req<int>(map, 'timeStuckSeconds'),
    // Phase 18 (D-08): the pause fields are decoded TOLERANTLY — older
    // snapshots (or a pre-18-02 accumulator) omit them, so a missing key
    // defaults to running/zero rather than throwing. This keeps the dumb
    // terminal robust across version skews at the isolate boundary.
    isPaused: map['isPaused'] as bool? ?? false,
    pausedSeconds: (map['pausedSeconds'] as num?)?.toInt() ?? 0,
    breakCount: (map['breakCount'] as num?)?.toInt() ?? 0,
  );
}

/// Typed required-key lookup helper. Matches the pattern used by
/// `TripSnapshot.fromMap` / `FinalizedTrip.fromMap` so every isolate-
/// boundary cast flows through a single audited site under
/// `strict-casts: true`.
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
