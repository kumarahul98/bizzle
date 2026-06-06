import 'package:flutter/foundation.dart';

/// Pure stuck-streak state machine for the opt-in auto-pause prompt (Phase 18
/// Plan 04, TRACK-10, D-11/D-12).
///
/// Owned by the tracking service isolate alongside the `TripAccumulator`. It
/// consumes the accumulator's OWN stuck/moving classification per attributed
/// interval — it NEVER sees raw `Position.speed` and introduces NO second speed
/// threshold (D-11). This is what protects the app's core stuck-time metric:
/// the same `prev.speed < kStuckSpeedThresholdMs` decision drives both the
/// metric and this detector, so the two can never diverge.
///
/// Semantics:
///
///   * [onStuckInterval] adds the interval's seconds to the current
///     uninterrupted stuck streak.
///   * [onMovingInterval] RESETS the streak to zero AND re-arms the prompt
///     latch. Any moving interval breaks the streak, so stop-and-go
///     micro-movement can never accumulate to the threshold (no false
///     positive — T-18-11).
///   * [shouldPrompt] returns `true` exactly ONCE per streak: the first poll
///     after the streak reaches/crosses [thresholdSeconds] while the latch is
///     armed. It disarms the latch on that fire, so subsequent polls return
///     `false` — even while still stuck — until [onMovingInterval] re-arms it
///     (at most one prompt per stationary streak — T-18-14).
///
/// Pure, deterministic, no I/O: trivially unit-testable with synthetic
/// intervals. The threshold is injected (never a constant baked in here) so the
/// service can pass `kAutoPauseStationaryThresholdSeconds` and tests can use a
/// small value for fast arithmetic.
class AutoPauseDetector {
  /// Create a detector that prompts once the uninterrupted stuck streak first
  /// reaches [thresholdSeconds].
  AutoPauseDetector({required this.thresholdSeconds});

  /// Continuous stuck seconds required before a prompt fires. Injected — the
  /// production value is `kAutoPauseStationaryThresholdSeconds` (15 minutes).
  final int thresholdSeconds;

  // Uninterrupted stuck streak in seconds. Reset to 0 by onMovingInterval().
  int _stuckStreakSeconds = 0;
  // Prompt latch. Armed (true) until shouldPrompt() fires once; re-armed by
  // onMovingInterval(). Guarantees at most one prompt per stationary streak.
  bool _armed = true;

  /// Extend the current uninterrupted stuck streak by [seconds] (an attributed
  /// STUCK interval from the accumulator). Does not itself prompt.
  void onStuckInterval(int seconds) {
    _stuckStreakSeconds += seconds;
  }

  /// Record an attributed MOVING interval: reset the streak and re-arm the
  /// latch so a subsequent stationary streak can prompt again.
  void onMovingInterval() {
    _stuckStreakSeconds = 0;
    _armed = true;
  }

  /// Whether a prompt should be posted right now. Returns `true` exactly once
  /// per streak — the first time the streak reaches/crosses [thresholdSeconds]
  /// while armed — then disarms until [onMovingInterval] re-arms it.
  bool shouldPrompt() {
    if (_armed && _stuckStreakSeconds >= thresholdSeconds) {
      _armed = false;
      return true;
    }
    return false;
  }

  /// For testing: the current uninterrupted stuck streak in seconds.
  @visibleForTesting
  int get stuckStreakSecondsForTest => _stuckStreakSeconds;
}
