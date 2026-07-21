// Unit tests for the reminder_days CSV parser (Phase 33, D-02, T-33-06).
//
// The stored value is user-influenced and survives migrations, so every
// malformed shape must degrade predictably. The load-bearing case is the
// empty result: it means "no reminders", and must NEVER silently become
// weekdays — that would re-enable days the user deliberately deselected.

import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/shared/utils/reminder_days.dart';

void main() {
  group('parseReminderDays (T-33-06)', () {
    test('parses the weekday default', () {
      expect(parseReminderDays(kDefaultReminderDays), <int>{1, 2, 3, 4, 5});
    });

    test('parses all seven days', () {
      expect(parseReminderDays(kAllReminderDays), <int>{1, 2, 3, 4, 5, 6, 7});
    });

    test('empty string yields an empty set, not weekdays', () {
      expect(parseReminderDays(''), isEmpty);
    });

    test("'0' is out of range and dropped", () {
      expect(parseReminderDays('0'), isEmpty);
    });

    test("'8' is out of range and dropped", () {
      expect(parseReminderDays('8'), isEmpty);
    });

    test("'3,3,1' dedupes and sorts to {1, 3}", () {
      expect(parseReminderDays('3,3,1').toList(), <int>[1, 3]);
    });

    test("'abc' is unparseable and yields an empty set", () {
      expect(parseReminderDays('abc'), isEmpty);
    });

    test('a trailing comma is tolerated', () {
      expect(parseReminderDays('1,2,').toList(), <int>[1, 2]);
    });

    test('mixed valid and invalid entries keeps only the valid ones', () {
      expect(parseReminderDays('1,x,9,,5, 6 ').toList(), <int>[1, 5, 6]);
    });

    test('parsed numbers line up with DateTime.weekday', () {
      expect(parseReminderDays('1'), contains(DateTime.monday));
      expect(parseReminderDays('7'), contains(DateTime.sunday));
    });
  });

  group('encodeReminderDays', () {
    test('round-trips the default', () {
      expect(
        encodeReminderDays(parseReminderDays(kDefaultReminderDays)),
        kDefaultReminderDays,
      );
    });

    test('sorts and drops out-of-range values', () {
      expect(encodeReminderDays(<int>{5, 1, 9, 0}), '1,5');
    });

    test('an empty set encodes to an empty string', () {
      expect(encodeReminderDays(const <int>{}), '');
    });
  });

  group('reminderDaysLabel', () {
    test('empty selection reads as "no days", never "weekdays"', () {
      expect(reminderDaysLabel(const <int>{}), kReminderDaysNoneLabel);
      expect(
        reminderDaysLabel(const <int>{}),
        isNot(kReminderDaysWeekdaysLabel),
      );
    });

    test('all seven days collapse to "Every day"', () {
      expect(
        reminderDaysLabel(<int>{1, 2, 3, 4, 5, 6, 7}),
        kReminderDaysEveryDayLabel,
      );
    });

    test('Mon–Fri collapses to "Weekdays"', () {
      expect(
        reminderDaysLabel(<int>{1, 2, 3, 4, 5}),
        kReminderDaysWeekdaysLabel,
      );
    });

    test('Sat+Sun collapses to "Weekends"', () {
      expect(reminderDaysLabel(<int>{6, 7}), kReminderDaysWeekendsLabel);
    });

    test('an arbitrary subset lists day names in week order', () {
      expect(reminderDaysLabel(<int>{5, 1, 3}), 'Mon, Wed, Fri');
    });
  });
}
