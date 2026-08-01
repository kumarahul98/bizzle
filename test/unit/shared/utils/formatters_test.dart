// Wave 0 scaffold — RED tests for formatElapsed + formatStuck.
//
// These tests reference functions that do NOT yet exist in
// lib/shared/utils/formatters.dart. They MUST fail to compile/run until
// Plan 02 adds those functions. That is the intended RED state.
//
// Requirements covered:
//   IOS-13: formatElapsed powers the Live Activity elapsed display (MM:SS /
//           H:MM:SS) — distinct from formatDuration which outputs "N min".
//   IOS-14: formatStuck is extracted from TrackingNotificationService to be
//           shared between the Android notification renderer and the Live
//           Activity Dart bridge.
//
// See RESEARCH.md Pitfall 7 for the formatDuration vs formatElapsed
// distinction. The two formatters serve different display contexts:
//   - formatDuration: static summaries ("22 min", "1h 04min")
//   - formatElapsed:  live tracking surfaces ("22:14", "1:04:15")
//   - formatStuck:    compact stuck/moving display ("4m", "1h2m")

import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/shared/utils/formatters.dart';

void main() {
  group('formatElapsed (IOS-13/IOS-14 live surface formatter)', () {
    group('MM:SS format (under 1 hour)', () {
      test('formatElapsed(0) == "00:00"', () {
        expect(formatElapsed(0), '00:00');
      });

      test('formatElapsed(82) == "01:22"', () {
        // 82 seconds = 1 min 22 sec
        expect(formatElapsed(82), '01:22');
      });

      test('formatElapsed(3599) == "59:59"', () {
        // 3599 seconds = 59 min 59 sec — last value before H:MM:SS boundary
        expect(formatElapsed(3599), '59:59');
      });
    });

    group('H:MM:SS format (1 hour and above)', () {
      test('formatElapsed(3600) == "1:00:00"', () {
        // Exactly 1 hour — boundary value where H:MM:SS format begins
        expect(formatElapsed(3600), '1:00:00');
      });

      test('formatElapsed(3855) == "1:04:15"', () {
        // 3855 seconds = 1 hour 4 min 15 sec
        expect(formatElapsed(3855), '1:04:15');
      });
    });

    group('format boundary invariants', () {
      test('formatElapsed uses MM:SS strictly below 3600 seconds', () {
        // 3599 should be the last MM:SS value
        final result = formatElapsed(3599);
        // MM:SS has no colon-prefixed hour component
        expect(result.split(':').length, 2);
      });

      test('formatElapsed uses H:MM:SS at and above 3600 seconds', () {
        // 3600 should be the first H:MM:SS value
        final result = formatElapsed(3600);
        // H:MM:SS has exactly two colons
        expect(result.split(':').length, 3);
      });

      test('formatElapsed is distinct from formatDuration (Pitfall 7)', () {
        // formatDuration(82) == "1 min" — human-readable summary
        // formatElapsed(82) == "01:22" — live tracking clock display
        // These must NOT produce the same output for the same input.
        expect(formatElapsed(82), isNot(equals(formatDuration(82))));
      });
    });
  });

  group('formatStuck (IOS-14 compact stuck/moving formatter)', () {
    // These cases match the existing private _formatStuck logic in
    // tracking_notification_service.dart lines 269–275, which Plan 02
    // extracts to lib/shared/utils/formatters.dart as a named function.

    group('minutes only (under 60 minutes)', () {
      test('formatStuck(240) == "4m"', () {
        // 240 seconds = 4 minutes
        expect(formatStuck(240), '4m');
      });

      test('formatStuck(2040) == "34m"', () {
        // 2040 seconds = 34 minutes
        expect(formatStuck(2040), '34m');
      });
    });

    group('hours and minutes (60 minutes and above)', () {
      test('formatStuck(3600) == "1h"', () {
        // Exactly 1 hour — no minutes remainder → omit minutes component
        expect(formatStuck(3600), '1h');
      });

      test('formatStuck(3720) == "1h2m"', () {
        // 3720 seconds = 1 hour 2 minutes — compact without space
        expect(formatStuck(3720), '1h2m');
      });
    });

    group('zero and edge cases', () {
      test('formatStuck(0) == "0m"', () {
        // Zero seconds stuck — rendered as "0m" not empty string
        expect(formatStuck(0), '0m');
      });

      test('formatStuck(59) == "0m"', () {
        // 59 seconds — under 1 minute → rounds down to 0m
        expect(formatStuck(59), '0m');
      });

      test('formatStuck(60) == "1m"', () {
        // Exactly 1 minute
        expect(formatStuck(60), '1m');
      });
    });
  });

  group('formatTrafficDuration', () {
    // Quick 260801-oux: the trip detail legend / history row formatter for
    // FINALIZED moving/stuck figures. Distinct from formatStuck (compact,
    // live-tracking surfaces, pinned to '0m' under a minute) — this one
    // surfaces sub-minute values honestly instead of flooring them away.

    test('formatTrafficDuration(0) == "0m"', () {
      // Zero seconds — no traffic figure to show, matches formatStuck(0).
      expect(formatTrafficDuration(0), '0m');
    });

    test('formatTrafficDuration(1) == kSubMinuteDurationLabel', () {
      // The smallest non-zero value must still be visibly distinct from 0.
      expect(formatTrafficDuration(1), kSubMinuteDurationLabel);
    });

    test('formatTrafficDuration(59) == kSubMinuteDurationLabel', () {
      // Last value before the 1-minute boundary — still sub-minute.
      expect(formatTrafficDuration(59), kSubMinuteDurationLabel);
    });

    test('formatTrafficDuration(60) == "1m"', () {
      // Exactly 1 minute — first value that renders as a whole minute.
      expect(formatTrafficDuration(60), '1m');
    });

    test('formatTrafficDuration(3599) == "59m"', () {
      // Last value before the 1-hour boundary.
      expect(formatTrafficDuration(3599), '59m');
    });

    test('formatTrafficDuration(3600) == "1h"', () {
      // Exactly 1 hour — no minutes remainder, so omit the minutes part.
      expect(formatTrafficDuration(3600), '1h');
    });

    test('formatTrafficDuration(3660) == "1h 1m"', () {
      // 1 hour 1 minute — space-separated, matching the legend it replaces.
      expect(formatTrafficDuration(3660), '1h 1m');
    });

    test(
      'regression guard: formatTrafficDuration(30) != formatTrafficDuration(0)',
      () {
        // This is the reported bug: a real, edited-down stuck value must not
        // collapse to the same label as "nothing changed".
        expect(
          formatTrafficDuration(30),
          isNot(equals(formatTrafficDuration(0))),
        );
      },
    );

    test(
      'distinctness guard: formatTrafficDuration(59) != formatStuck(59)',
      () {
        // formatStuck stays pinned at '0m' for 59 seconds (live surfaces);
        // formatTrafficDuration must not share that behaviour.
        expect(formatTrafficDuration(59), isNot(equals(formatStuck(59))));
      },
    );
  });
}
