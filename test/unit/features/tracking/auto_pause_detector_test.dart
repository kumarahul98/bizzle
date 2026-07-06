// Unit tests for the pure `AutoPauseDetector` stuck-streak state machine
// (Phase 18 Plan 04, TRACK-10, D-11/D-12).
//
// The detector consumes the SAME stuck/moving classification the
// `TripAccumulator` already computes (never raw `Position.speed`). It tracks an
// uninterrupted stuck streak; any moving interval resets the streak AND re-arms
// the prompt latch. `shouldPrompt()` fires exactly once per streak the instant
// the streak first reaches/crosses the threshold, then stays silent until a
// moving interval re-arms it. These tests prove:
//   1. below threshold → never prompts;
//   2. crossing the threshold → prompts exactly once;
//   3. movement resets the streak and re-arms (a fresh streak prompts again);
//   4. stop-and-go (alternating small stuck + moving) never reaches threshold;
//   5. stuck time accumulates ONLY across uninterrupted stuck intervals.

import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/tracking/services/auto_pause_detector.dart';

void main() {
  group('AutoPauseDetector', () {
    test('below threshold never prompts', () {
      final detector = AutoPauseDetector(thresholdSeconds: 60)
        ..onStuckInterval(10)
        ..onStuckInterval(20)
        ..onStuckInterval(29); // 59 < 60
      expect(detector.shouldPrompt(), isFalse);
      expect(detector.stuckStreakSecondsForTest, 59);
    });

    test('streak crossing the threshold prompts exactly once', () {
      final detector = AutoPauseDetector(thresholdSeconds: 60)
        ..onStuckInterval(40);
      expect(detector.shouldPrompt(), isFalse); // 40 < 60
      detector.onStuckInterval(20); // 60 == threshold
      // First poll after crossing → true.
      expect(detector.shouldPrompt(), isTrue);
      // Latch disarmed → subsequent polls are false even though still stuck.
      expect(detector.shouldPrompt(), isFalse);
    });

    test(
      'still-stuck after a prompt does not prompt again (once per streak)',
      () {
        final detector = AutoPauseDetector(thresholdSeconds: 60)
          ..onStuckInterval(60);
        expect(detector.shouldPrompt(), isTrue);
        // Keep accumulating stuck time WITHOUT any movement.
        detector
          ..onStuckInterval(120)
          ..onStuckInterval(120);
        expect(detector.shouldPrompt(), isFalse);
        expect(detector.stuckStreakSecondsForTest, 300);
      },
    );

    test('movement resets the streak and re-arms (re-arm after movement)', () {
      final detector = AutoPauseDetector(thresholdSeconds: 60)
        ..onStuckInterval(60);
      expect(detector.shouldPrompt(), isTrue);

      // Movement resumes — streak resets, latch re-arms.
      detector.onMovingInterval();
      expect(detector.stuckStreakSecondsForTest, 0);
      expect(detector.shouldPrompt(), isFalse);

      // A NEW stuck streak that re-crosses the threshold prompts again.
      detector.onStuckInterval(60);
      expect(detector.shouldPrompt(), isTrue);
    });

    test('stop-and-go never reaches the threshold (no false positive)', () {
      final detector = AutoPauseDetector(thresholdSeconds: 60);
      // Alternate small stuck bursts with movement: each moving interval
      // resets the streak, so it can never grow to the threshold.
      for (var i = 0; i < 20; i++) {
        detector
          ..onStuckInterval(30) // well under 60
          ..onMovingInterval();
        expect(detector.shouldPrompt(), isFalse);
        expect(detector.stuckStreakSecondsForTest, 0);
      }
    });

    test('accumulates only across uninterrupted stuck intervals', () {
      final detector = AutoPauseDetector(thresholdSeconds: 100)
        ..onStuckInterval(30)
        ..onStuckInterval(30) // streak 60
        ..onMovingInterval() // reset
        ..onStuckInterval(30)
        ..onStuckInterval(30); // streak 60 again, never 120
      expect(detector.shouldPrompt(), isFalse);
      expect(detector.stuckStreakSecondsForTest, 60);
    });

    test('uses the production threshold constant by default arithmetic', () {
      final detector = AutoPauseDetector(
        thresholdSeconds: kAutoPauseStationaryThresholdSeconds,
      )..onStuckInterval(kAutoPauseStationaryThresholdSeconds - 1);
      // One second short of 15 minutes → no prompt.
      expect(detector.shouldPrompt(), isFalse);
      // Crossing the 15-minute boundary → prompt once.
      detector.onStuckInterval(1);
      expect(detector.shouldPrompt(), isTrue);
      expect(detector.shouldPrompt(), isFalse);
    });
  });
}
