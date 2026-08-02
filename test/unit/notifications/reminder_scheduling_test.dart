// Behavioural tests for NotificationService.scheduleReminder (Phase 33,
// D-02, T-33-03).
//
// The older notification_service_test.dart asserts only the ID *constants*,
// on the stated grounds that FlutterLocalNotificationsPlugin "cannot be
// subclassed or invoked in pure unit tests". With the plugin's current API
// that is no longer true: the class can be `implements`-ed and every call
// routed through noSuchMethod, exactly as that file already does for
// IOSFlutterLocalNotificationsPlugin. Recording the real calls is the only
// way to catch the bug this phase exists to prevent — a cancel sweep that
// is narrower than the schedule range, stranding weekend alarms forever.

import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/notifications/notification_service.dart';

/// Records every cancel and zonedSchedule call, in order.
class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  final List<int> cancelledIds = <int>[];
  final List<int> scheduledIds = <int>[];
  final List<tz.TZDateTime> scheduledDates = <tz.TZDateTime>[];
  final List<DateTimeComponents?> matchComponents = <DateTimeComponents?>[];
  final List<AndroidScheduleMode> scheduleModes = <AndroidScheduleMode>[];

  /// True once at least one schedule call has happened; used to prove the
  /// cancel sweep runs BEFORE any scheduling.
  bool sawScheduleBeforeCancel = false;

  @override
  Future<void> cancel({required int id, String? tag}) async {
    if (scheduledIds.isNotEmpty) sawScheduleBeforeCancel = true;
    cancelledIds.add(id);
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduledIds.add(id);
    scheduledDates.add(scheduledDate);
    matchComponents.add(matchDateTimeComponents);
    scheduleModes.add(androidScheduleMode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
  });

  group('scheduleReminder (Phase 33, D-02)', () {
    late _RecordingPlugin plugin;
    late NotificationService service;

    setUp(() {
      plugin = _RecordingPlugin();
      service = NotificationService(plugin: plugin);
    });

    test('cancels the full 20–26 range before scheduling anything', () async {
      await service.scheduleReminder(hhMm: '07:00', days: <int>{1, 2, 3, 4, 5});

      expect(
        plugin.cancelledIds,
        equals(<int>[20, 21, 22, 23, 24, 25, 26]),
        reason:
            'a sweep narrower than 20–26 leaves Saturday/Sunday alarms '
            'firing forever after the weekend is deselected (T-33-03)',
      );
      expect(
        plugin.sawScheduleBeforeCancel,
        isFalse,
        reason: 'every cancel must precede every schedule',
      );
    });

    test(
      'schedules exactly one alarm per selected day, at day-derived IDs',
      () async {
        await service.scheduleReminder(hhMm: '07:00', days: <int>{1, 3, 5});

        expect(plugin.scheduledIds, equals(<int>[20, 22, 24]));
        expect(
          plugin.matchComponents,
          everyElement(DateTimeComponents.dayOfWeekAndTime),
          reason: 'one uniform path — no DateTimeComponents.time branch',
        );
      },
    );

    test('Sunday maps to slot 26, Saturday to 25', () async {
      await service.scheduleReminder(
        hhMm: '09:30',
        days: <int>{DateTime.saturday, DateTime.sunday},
      );

      expect(plugin.scheduledIds, equals(<int>[25, 26]));
    });

    test('all seven days schedules seven alarms at 20–26', () async {
      await service.scheduleReminder(
        hhMm: '07:00',
        days: <int>{1, 2, 3, 4, 5, 6, 7},
      );

      expect(plugin.scheduledIds, equals(<int>[20, 21, 22, 23, 24, 25, 26]));
    });

    test('empty selection cancels everything and schedules nothing', () async {
      await service.scheduleReminder(hhMm: '07:00', days: const <int>{});

      expect(plugin.cancelledIds, equals(<int>[20, 21, 22, 23, 24, 25, 26]));
      expect(
        plugin.scheduledIds,
        isEmpty,
        reason:
            'an empty day set means no reminders — it must NOT fall back '
            'to weekdays (D-02)',
      );
    });

    test(
      'each scheduled date lands on its own weekday at the given time',
      () async {
        await service.scheduleReminder(hhMm: '07:05', days: <int>{2, 7});

        expect(plugin.scheduledDates.length, 2);
        expect(plugin.scheduledDates[0].weekday, DateTime.tuesday);
        expect(plugin.scheduledDates[1].weekday, DateTime.sunday);
        for (final date in plugin.scheduledDates) {
          expect(date.hour, 7);
          expect(date.minute, 5);
        }
      },
    );

    test('malformed time still cancels, but schedules nothing', () async {
      await service.scheduleReminder(hhMm: '25:99', days: <int>{1, 2});

      expect(plugin.cancelledIds, equals(<int>[20, 21, 22, 23, 24, 25, 26]));
      expect(plugin.scheduledIds, isEmpty);
    });

    test('out-of-range weekday numbers are ignored, not crashed on', () async {
      await service.scheduleReminder(hhMm: '07:00', days: <int>{0, 3, 8});

      expect(plugin.scheduledIds, equals(<int>[22]));
    });

    test('cancelReminder sweeps all seven slots', () async {
      await service.cancelReminder();

      expect(plugin.cancelledIds, equals(<int>[20, 21, 22, 23, 24, 25, 26]));
      expect(plugin.cancelledIds.length, kReminderNotificationSlotCount);
    });

    test(
      'every scheduled reminder alarm uses inexactAllowWhileIdle, never '
      'exactAllowWhileIdle',
      () async {
        await service.scheduleReminder(
          hhMm: '07:00',
          days: <int>{1, 2, 3, 4, 5},
        );

        expect(
          plugin.scheduleModes,
          isNotEmpty,
          reason:
              'this selection must produce 5 alarms — an empty list would '
              'make everyElement() below pass vacuously',
        );
        expect(
          plugin.scheduleModes,
          everyElement(AndroidScheduleMode.inexactAllowWhileIdle),
          reason:
              'restoring exactAllowWhileIdle reintroduces the need for '
              'USE_EXACT_ALARM, which Google Play restricts to calendar '
              'and alarm-clock apps — this test is the only thing that '
              'would surface that regression before a Play submission '
              'fails',
        );
        expect(
          plugin.scheduleModes,
          isNot(contains(AndroidScheduleMode.exactAllowWhileIdle)),
          reason:
              'negative control: exactAllowWhileIdle must never appear '
              'among the recorded modes',
        );
      },
    );
  });

  group('scheduleWeeklySummary (quick-260802-x1q)', () {
    late _RecordingPlugin plugin;
    late NotificationService service;
    late AppDatabase db;

    setUp(() {
      plugin = _RecordingPlugin();
      service = NotificationService(plugin: plugin);
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'schedules the weekly summary alarm on inexactAllowWhileIdle, never '
      'exactAllowWhileIdle',
      () async {
        await service.scheduleWeeklySummary(db);

        expect(
          plugin.scheduledIds,
          equals(<int>[kWeeklySummaryNotificationId]),
          reason: 'exactly one weekly-summary alarm must be scheduled',
        );
        expect(
          plugin.scheduleModes,
          equals(<AndroidScheduleMode>[
            AndroidScheduleMode.inexactAllowWhileIdle,
          ]),
          reason:
              'restoring exactAllowWhileIdle reintroduces the need for '
              'USE_EXACT_ALARM, which Google Play restricts to calendar '
              'and alarm-clock apps — this test is the only thing that '
              'would surface that regression before a Play submission '
              'fails',
        );
        expect(
          plugin.scheduleModes,
          isNot(contains(AndroidScheduleMode.exactAllowWhileIdle)),
          reason:
              'negative control: exactAllowWhileIdle must never appear '
              'among the recorded modes',
        );
      },
    );
  });
}
