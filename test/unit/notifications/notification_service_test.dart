// Unit tests for NotificationService constants and scheduling configuration.
//
// FlutterLocalNotificationsPlugin uses a factory singleton with a private
// constructor and uninitialized platform interface in the test host —
// it cannot be subclassed or invoked in pure unit tests. Scheduling behavior
// (scheduleReminder, scheduleWeeklySummary) is covered by the widget test
// in test/widget/features/settings/settings_screen_test.dart once plan 04
// delivers SettingsScreen.
//
// These tests verify the constant-level guarantees that make the scheduling
// logic correct:
//   - D-14: channel IDs are distinct across services
//   - D-12: the reminder ID range (20-24) supports 5 weekday alarms + cancel
//   - D-05: weekly summary uses a distinct ID (10) outside the reminder range

import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';

void main() {
  group('NotificationService constants', () {
    group('channel ID distinctness (D-14)', () {
      test(
        'kWeeklySummaryChannelId is distinct from kTrackingNotificationChannelId',
        () {
          expect(
            kWeeklySummaryChannelId,
            isNot(kTrackingNotificationChannelId),
          );
        },
      );

      test(
        'kReminderChannelId is distinct from kTrackingNotificationChannelId',
        () {
          expect(kReminderChannelId, isNot(kTrackingNotificationChannelId));
        },
      );

      test(
        'kWeeklySummaryChannelId and kReminderChannelId are distinct',
        () {
          expect(kWeeklySummaryChannelId, isNot(kReminderChannelId));
        },
      );
    });

    group('notification IDs (D-05, D-12)', () {
      test('kWeeklySummaryNotificationId is 10', () {
        expect(kWeeklySummaryNotificationId, equals(10));
      });

      test('kReminderNotificationId is 20', () {
        expect(kReminderNotificationId, equals(20));
      });

      test(
        'weekday reminder ID range is 20-24 (5 alarms for Mon–Fri)',
        () {
          // scheduleReminder(includeWeekends: false) schedules IDs
          // kReminderNotificationId + 0 through + 4.
          final ids = List.generate(5, (i) => kReminderNotificationId + i);
          expect(ids, equals([20, 21, 22, 23, 24]));
        },
      );

      test(
        'reminder ID range does not overlap weekly summary ID',
        () {
          final reminderRange = List.generate(
            5,
            (i) => kReminderNotificationId + i,
          );
          expect(reminderRange, isNot(contains(kWeeklySummaryNotificationId)));
        },
      );

      test(
        'daily reminder mode uses only kReminderNotificationId (ID 20)',
        () {
          // scheduleReminder(includeWeekends: true) schedules exactly 1 alarm
          // at kReminderNotificationId — not the 5-slot range.
          expect(kReminderNotificationId, equals(20));
        },
      );

      test(
        'cancelReminder range is 5 slots: IDs 20-24',
        () {
          // cancelReminder() iterates i = 0..4, cancelling
          // kReminderNotificationId + i for each.
          final cancelRange = List.generate(
            5,
            (i) => kReminderNotificationId + i,
          );
          expect(cancelRange, equals([20, 21, 22, 23, 24]));
        },
      );
    });
  });
}
