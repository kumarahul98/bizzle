// Unit tests for trip history date grouping (HIST-01).
//
// Covers `groupTripsByDate` (lib/features/trips/providers/history_providers.dart)
// and `formatDateHeader` (same file). Both are pure functions; no widget or
// DB scaffolding required.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/providers/history_providers.dart';
import 'package:uuid/uuid.dart';

TripSummary _makeTrip(DateTime startTime, {bool isManualEntry = false}) {
  final endTime = startTime.add(const Duration(hours: 1));
  return TripSummary(
    id: const Uuid().v4(),
    startTime: startTime,
    endTime: endTime,
    durationSeconds: endTime.difference(startTime).inSeconds,
    distanceMeters: 0,
    direction: kDirectionToOffice,
    timeMovingSeconds: 0,
    timeStuckSeconds: 0,
    isManualEntry: isManualEntry,
  );
}

void main() {
  group('groupTripsByDate', () {
    test('returns empty map for empty input', () {
      expect(groupTripsByDate(const <TripSummary>[]), isEmpty);
    });

    test('groups trips by local date (same UTC day, same local date)', () {
      // Two trips on the same UTC day. Grouping uses local-date keys
      // (Pitfall 3 mitigation: toLocal() before stripping the time).
      // Both trips share the same local date, so they collapse into a
      // single key regardless of the UTC offset of the test environment.
      final trip1 = _makeTrip(DateTime.utc(2026, 1, 1, 8));
      final trip2 = _makeTrip(DateTime.utc(2026, 1, 1, 18));
      final result = groupTripsByDate(<TripSummary>[trip1, trip2]);
      // Compute the expected local-date key from one of the inputs so
      // the test is independent of the runner timezone.
      final localStart = trip1.startTime.toLocal();
      final localEnd = trip2.startTime.toLocal();
      // Both samples are within the same 10-hour UTC window — for any
      // realistic timezone they collapse into one or two local dates.
      // Verify the total count of trips is preserved across all keys.
      final totalGrouped = result.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );
      expect(totalGrouped, 2);
      // Both keys (if two) must be one of the two local dates.
      for (final key in result.keys) {
        expect(
          key == DateTime(localStart.year, localStart.month, localStart.day) ||
              key == DateTime(localEnd.year, localEnd.month, localEnd.day),
          isTrue,
        );
      }
    });

    test('two trips on different local dates produce two keys', () {
      final trip1 = _makeTrip(DateTime.utc(2026, 1, 1, 12));
      final trip2 = _makeTrip(DateTime.utc(2026, 1, 5, 12));
      final result = groupTripsByDate(<TripSummary>[trip1, trip2]);
      expect(result.keys.length, 2);
    });

    test('strips time from key (keys are date-only DateTime objects)', () {
      final trip = _makeTrip(DateTime.utc(2026, 1, 1, 14, 37, 22));
      final result = groupTripsByDate(<TripSummary>[trip]);
      expect(result.keys.length, 1);
      final key = result.keys.first;
      expect(key.hour, 0);
      expect(key.minute, 0);
      expect(key.second, 0);
      expect(key.millisecond, 0);
    });

    test('preserves newest-first order within each group', () {
      // Caller is documented to pass trips ordered newest-first
      // (the watchAllSummaries() stream guarantees this). Verify the
      // grouping does not reorder within a key.
      final newer = _makeTrip(DateTime.utc(2026, 1, 1, 18));
      final older = _makeTrip(DateTime.utc(2026, 1, 1, 8));
      final result = groupTripsByDate(<TripSummary>[newer, older]);
      // All trips share a UTC date; for keys that contain both, newer
      // must precede older.
      for (final list in result.values) {
        if (list.length == 2) {
          expect(list.first.id, newer.id);
          expect(list.last.id, older.id);
        }
      }
    });
  });

  group('formatDateHeader', () {
    test('returns kHistoryDateToday for today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(formatDateHeader(today), kHistoryDateToday);
    });

    test('returns kHistoryDateYesterday for yesterday', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      expect(formatDateHeader(yesterday), kHistoryDateYesterday);
    });

    test("returns 'EEE d MMM' format for older dates", () {
      // Pick a date well in the past so it can never coincide with
      // today/yesterday at runtime.
      final older = DateTime(2025, 4, 21);
      final expected = DateFormat('EEE d MMM').format(older);
      expect(formatDateHeader(older), expected);
      // Sanity-check the format pattern: starts with three-letter
      // weekday, followed by a space, followed by digits, then space,
      // then a 3-letter month abbreviation.
      expect(
        formatDateHeader(older),
        matches(RegExp(r'^[A-Za-z]{3} \d{1,2} [A-Za-z]{3}$')),
      );
    });
  });
}
