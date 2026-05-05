// Unit tests for NotificationService.
//
// RED phase: fails until lib/notifications/notification_service.dart is
// created with the full NotificationService class.
//
// Uses a fake FlutterLocalNotificationsPlugin subclass to capture calls
// without touching Android platform channels.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/notifications/notification_service.dart';

/// Records every cancel() and zonedSchedule() call made during a test.
class _FakePlugin extends FlutterLocalNotificationsPlugin {
  final List<int> cancelledIds = [];
  final List<_ScheduledCall> scheduledCalls = [];

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    dynamic scheduledDate,
    NotificationDetails notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    scheduledCalls.add(
      _ScheduledCall(
        id: id,
        title: title,
        matchDateTimeComponents: matchDateTimeComponents,
      ),
    );
  }

  @override
  T? resolvePlatformSpecificImplementation<
      T extends FlutterLocalNotificationsPlugin>() =>
      null;
}

class _ScheduledCall {
  const _ScheduledCall({
    required this.id,
    required this.title,
    required this.matchDateTimeComponents,
  });
  final int id;
  final String? title;
  final DateTimeComponents? matchDateTimeComponents;
}

void main() {
  group('NotificationService', () {
    late _FakePlugin fakePlugin;
    late NotificationService service;

    setUp(() {
      fakePlugin = _FakePlugin();
      service = NotificationService(plugin: fakePlugin);
    });

    test(
      'scheduleReminder with includeWeekends=false cancels IDs 20-24 '
      'and schedules 5 dayOfWeekAndTime alarms',
      () async {
        await service.scheduleReminder(
          hhMm: '08:00',
          includeWeekends: false,
        );

        // Cancels all 5 reminder slots before scheduling.
        expect(
          fakePlugin.cancelledIds,
          containsAll([20, 21, 22, 23, 24]),
        );

        // Schedules exactly 5 alarms (Mon–Fri).
        expect(fakePlugin.scheduledCalls, hasLength(5));

        // All use dayOfWeekAndTime repeat component.
        for (final call in fakePlugin.scheduledCalls) {
          expect(
            call.matchDateTimeComponents,
            DateTimeComponents.dayOfWeekAndTime,
          );
        }

        // IDs are kReminderNotificationId (20) through 24.
        final ids = fakePlugin.scheduledCalls.map((c) => c.id).toList()..sort();
        expect(ids, [20, 21, 22, 23, 24]);
      },
    );

    test(
      'scheduleReminder with includeWeekends=true cancels IDs 20-24 '
      'and schedules 1 DateTimeComponents.time alarm at ID 20',
      () async {
        await service.scheduleReminder(
          hhMm: '08:00',
          includeWeekends: true,
        );

        // Cancels all 5 slots first.
        expect(
          fakePlugin.cancelledIds,
          containsAll([20, 21, 22, 23, 24]),
        );

        // Only one alarm scheduled.
        expect(fakePlugin.scheduledCalls, hasLength(1));
        expect(fakePlugin.scheduledCalls.first.id, kReminderNotificationId);
        expect(
          fakePlugin.scheduledCalls.first.matchDateTimeComponents,
          DateTimeComponents.time,
        );
      },
    );

    test(
      'NotificationService uses distinct channel IDs from tracking channel',
      () {
        // D-14: new channels must not reuse kTrackingNotificationChannelId.
        expect(kWeeklySummaryChannelId, isNot(kTrackingNotificationChannelId));
        expect(kReminderChannelId, isNot(kTrackingNotificationChannelId));
        expect(kWeeklySummaryChannelId, isNot(kReminderChannelId));
      },
    );
  });
}
