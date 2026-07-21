// Unit tests for ReminderSuggestionService (Phase 33, D-04).
//
// This is the part of the phase that decides whether the feature is liked or
// hated: a wrong suggestion at the wrong moment, or a repeated nag, both
// destroy trust. Every gate, the median (not mean), the offset, and the
// re-offer rule are exercised here.

import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/settings/services/reminder_suggestion_service.dart';
import 'package:traevy/shared/models/reminder_suggestion_state.dart';

const _service = ReminderSuggestionService();

/// A reference "now" well clear of DST edges.
final DateTime _now = DateTime(2026, 7, 20, 12);

/// Build a `to_office` GPS trip starting at local [hour]:[minute], [daysAgo]
/// days before [_now].
TripSummary _trip({
  required int hour,
  int minute = 0,
  int daysAgo = 1,
  bool isManual = false,
  String direction = kDirectionToOffice,
}) {
  final localStart = DateTime(
    _now.year,
    _now.month,
    _now.day,
    hour,
    minute,
  ).subtract(Duration(days: daysAgo));
  return TripSummary(
    id: 't-$daysAgo-$hour-$minute-$direction-$isManual',
    startTime: localStart,
    endTime: localStart.add(const Duration(minutes: 40)),
    durationSeconds: 2400,
    distanceMeters: 8000,
    direction: direction,
    timeMovingSeconds: 2000,
    timeStuckSeconds: 400,
    isManualEntry: isManual,
  );
}

void main() {
  group('computeSuggestion — gating', () {
    test('returns null below 5 qualifying trips', () {
      final trips = List.generate(4, (i) => _trip(hour: 8, daysAgo: i + 1));
      expect(_service.computeSuggestion(trips, now: _now), isNull);
    });

    test('returns a suggestion at exactly 5 qualifying trips', () {
      final trips = List.generate(5, (i) => _trip(hour: 8, daysAgo: i + 1));
      expect(_service.computeSuggestion(trips, now: _now), isNotNull);
    });

    test('manual entries are excluded from the count and the median', () {
      // Five GPS trips at 08:00, plus five manual trips at 05:00 that would
      // drag the median if counted.
      final gps = List.generate(5, (i) => _trip(hour: 8, daysAgo: i + 1));
      final manual = List.generate(
        5,
        (i) => _trip(hour: 5, daysAgo: i + 1, isManual: true),
      );
      final suggestion = _service.computeSuggestion([
        ...gps,
        ...manual,
      ], now: _now);
      // Median of the GPS trips alone is 08:00 → 07:45.
      expect(suggestion, '07:45');
    });

    test('to_home trips are excluded', () {
      final office = List.generate(3, (i) => _trip(hour: 8, daysAgo: i + 1));
      final home = List.generate(
        4,
        (i) => _trip(hour: 18, daysAgo: i + 1, direction: kDirectionToHome),
      );
      // Only 3 qualifying → below the gate.
      expect(
        _service.computeSuggestion([...office, ...home], now: _now),
        isNull,
      );
    });

    test('trips older than 28 days are excluded', () {
      final recent = List.generate(3, (i) => _trip(hour: 8, daysAgo: i + 1));
      final old = List.generate(
        5,
        (i) => _trip(hour: 8, daysAgo: 29 + i),
      );
      // Only 3 fall inside the window → below the gate.
      expect(
        _service.computeSuggestion([...recent, ...old], now: _now),
        isNull,
      );
    });

    test('a trip exactly at the 28-day boundary is inside the window', () {
      // daysAgo just under 28 to stay strictly inside.
      final trips = List.generate(
        5,
        (i) => _trip(hour: 8, minute: 0, daysAgo: 27),
      );
      expect(_service.computeSuggestion(trips, now: _now), '07:45');
    });
  });

  group('computeSuggestion — median (not mean)', () {
    test('odd count uses the middle value', () {
      // Starts: 07:00, 08:00, 09:00 → median 08:00 → 07:45.
      final trips = [
        _trip(hour: 7, daysAgo: 1),
        _trip(hour: 9, daysAgo: 2),
        _trip(hour: 8, daysAgo: 3),
        _trip(hour: 8, daysAgo: 4),
        _trip(hour: 8, daysAgo: 5),
      ];
      expect(_service.computeSuggestion(trips, now: _now), '07:45');
    });

    test('even count averages the two central values', () {
      // Six trips: 08:00, 08:00, 08:10, 08:20, 08:30, 08:30.
      // Central two are 08:10 and 08:20 → 08:15 → minus 15 = 08:00.
      final trips = [
        _trip(hour: 8, minute: 0, daysAgo: 1),
        _trip(hour: 8, minute: 0, daysAgo: 2),
        _trip(hour: 8, minute: 10, daysAgo: 3),
        _trip(hour: 8, minute: 20, daysAgo: 4),
        _trip(hour: 8, minute: 30, daysAgo: 5),
        _trip(hour: 8, minute: 30, daysAgo: 6),
      ];
      expect(_service.computeSuggestion(trips, now: _now), '08:00');
    });

    test('median resists a single wild outlier that mean would not', () {
      // Four commutes at 08:00 and one 03:00 airport run. Median = 08:00 →
      // 07:45. The mean would be ~07:00, so this proves median is used.
      final trips = [
        _trip(hour: 8, daysAgo: 1),
        _trip(hour: 8, daysAgo: 2),
        _trip(hour: 8, daysAgo: 3),
        _trip(hour: 8, daysAgo: 4),
        _trip(hour: 3, daysAgo: 5),
      ];
      expect(_service.computeSuggestion(trips, now: _now), '07:45');
    });

    test('trips spanning midnight keep their own local minute-of-day', () {
      // A cluster of night-shift departures around 00:10 local.
      final trips = List.generate(
        5,
        (i) => _trip(hour: 0, minute: 10, daysAgo: i + 1),
      );
      // Median 00:10, minus 15 wraps to 23:55 the previous evening.
      expect(_service.computeSuggestion(trips, now: _now), '23:55');
    });
  });

  group('computeSuggestion — offset and 5-minute rounding', () {
    test('rounds DOWN to the nearest five minutes', () {
      // Median 08:07 → minus 15 = 07:52 → rounded down = 07:50.
      final trips = List.generate(
        5,
        (i) => _trip(hour: 8, minute: 7, daysAgo: i + 1),
      );
      expect(_service.computeSuggestion(trips, now: _now), '07:50');
    });

    test('an already-multiple-of-five time is unchanged by rounding', () {
      // Median 08:20 → minus 15 = 08:05, already a multiple of 5.
      final trips = List.generate(
        5,
        (i) => _trip(hour: 8, minute: 20, daysAgo: i + 1),
      );
      expect(_service.computeSuggestion(trips, now: _now), '08:05');
    });

    test('offset wraps below midnight to the previous evening', () {
      // Median 00:05 → minus 15 = -10 → wraps to 23:50.
      final trips = List.generate(
        5,
        (i) => _trip(hour: 0, minute: 5, daysAgo: i + 1),
      );
      expect(_service.computeSuggestion(trips, now: _now), '23:50');
    });

    test('exactly midnight median rounds to 23:45', () {
      final trips = List.generate(
        5,
        (i) => _trip(hour: 0, minute: 0, daysAgo: i + 1),
      );
      // 00:00 minus 15 = 23:45.
      expect(_service.computeSuggestion(trips, now: _now), '23:45');
    });
  });

  group('shouldOffer — re-offer rule (T-33-05)', () {
    test('a null suggestion is never offered', () {
      expect(
        _service.shouldOffer(
          suggestion: null,
          state: ReminderSuggestionState.none,
          lastOfferedValue: null,
        ),
        isFalse,
      );
    });

    test('first-ever suggestion is offered (state none)', () {
      expect(
        _service.shouldOffer(
          suggestion: '07:45',
          state: ReminderSuggestionState.none,
          lastOfferedValue: null,
        ),
        isTrue,
      );
    });

    test('delta 0 against a dismissal is NOT re-offered', () {
      expect(
        _service.shouldOffer(
          suggestion: '07:45',
          state: ReminderSuggestionState.dismissed,
          lastOfferedValue: '07:45',
        ),
        isFalse,
      );
    });

    test('delta 19 is NOT re-offered', () {
      expect(
        _service.shouldOffer(
          suggestion: '08:04',
          state: ReminderSuggestionState.dismissed,
          lastOfferedValue: '07:45',
        ),
        isFalse,
      );
    });

    test('delta exactly 20 is NOT re-offered (strictly greater than)', () {
      expect(
        _service.shouldOffer(
          suggestion: '08:05',
          state: ReminderSuggestionState.dismissed,
          lastOfferedValue: '07:45',
        ),
        isFalse,
      );
    });

    test('delta 21 IS re-offered', () {
      expect(
        _service.shouldOffer(
          suggestion: '08:06',
          state: ReminderSuggestionState.dismissed,
          lastOfferedValue: '07:45',
        ),
        isTrue,
      );
    });

    test('the re-offer rule holds against an accepted value too', () {
      expect(
        _service.shouldOffer(
          suggestion: '07:50',
          state: ReminderSuggestionState.accepted,
          lastOfferedValue: '07:45',
        ),
        isFalse,
      );
      expect(
        _service.shouldOffer(
          suggestion: '08:10',
          state: ReminderSuggestionState.accepted,
          lastOfferedValue: '07:45',
        ),
        isTrue,
      );
    });

    test('delta is measured circularly across midnight', () {
      // 23:55 vs 00:05 is 10 minutes apart, not 1430 — must NOT re-offer.
      expect(
        _service.shouldOffer(
          suggestion: '00:05',
          state: ReminderSuggestionState.dismissed,
          lastOfferedValue: '23:55',
        ),
        isFalse,
      );
    });
  });
}
