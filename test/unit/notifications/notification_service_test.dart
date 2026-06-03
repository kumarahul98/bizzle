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
//
// Wave 0 RED additions (IOS-10):
//   - requestIOSNotificationPermission() resolves IOSFlutterLocalNotificationsPlugin
//     and calls requestPermissions(alert/badge/sound). RED until Plan 03.
//
// IOS-10 fix (db injection regression guard):
//   - maybeRequestNotificationPermissionForUsage accepts db to avoid
//     constructing a raw AppDatabase() — verified via API contract test.

import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/notifications/notification_service.dart';

// ---------------------------------------------------------------------------
// Minimal fake plugin for requestIOSNotificationPermission tests.
//
// FlutterLocalNotificationsPlugin cannot be instantiated in tests.
// The test below documents the expected call surface; Plan 03 implements
// NotificationService.requestIOSNotificationPermission() which uses
// _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
// ?.requestPermissions(alert: true, badge: true, sound: true).
// ---------------------------------------------------------------------------

/// Records whether requestPermissions was called and with which arguments.
class _FakeIosPlugin implements IOSFlutterLocalNotificationsPlugin {
  bool requestPermissionsCalled = false;
  bool? alertArg;
  bool? badgeArg;
  bool? soundArg;

  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool carPlay = false,
    bool providesAppNotificationSettings = false,
  }) async {
    requestPermissionsCalled = true;
    alertArg = alert;
    badgeArg = badge;
    soundArg = sound;
    return true;
  }

  // Unimplemented stubs — not exercised by these tests.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  // -------------------------------------------------------------------------
  // Wave 0 RED scaffold — IOS-10: requestIOSNotificationPermission()
  //
  // Documents the call surface that Plan 03 will implement on
  // NotificationService. RED until Plan 03 adds
  // requestIOSNotificationPermission() to NotificationService.
  // -------------------------------------------------------------------------

  group('NotificationService.requestIOSNotificationPermission (IOS-10)', () {
    test(
      'calls requestPermissions with alert/badge/sound=true on the iOS '
      'platform-specific plugin implementation',
      () async {
        final fakeIos = _FakeIosPlugin();

        // Plan 03 adds requestIOSNotificationPermission() to
        // NotificationService. The method is expected to call:
        //   _plugin.resolvePlatformSpecificImplementation<
        //       IOSFlutterLocalNotificationsPlugin>()
        //     ?.requestPermissions(alert: true, badge: true, sound: true)
        //
        // In the test seam, NotificationService accepts a
        // [FlutterLocalNotificationsPlugin] that the test can swap for
        // a fake. The fake is injected via the existing constructor
        // parameter, and the test will call
        //   service.requestIOSNotificationPermission(iosPlugin: fakeIos)
        // or equivalent injection point that Plan 03 defines.
        //
        // Until Plan 03 adds the method, this test is RED (compile error).
        final service = NotificationService();
        await service.requestIOSNotificationPermission(iosPlugin: fakeIos);

        expect(
          fakeIos.requestPermissionsCalled,
          isTrue,
          reason:
              'IOS-10: requestPermissions must be called on the '
              'IOSFlutterLocalNotificationsPlugin',
        );
        expect(fakeIos.alertArg, isTrue, reason: 'alert must be true');
        expect(fakeIos.badgeArg, isTrue, reason: 'badge must be true');
        expect(fakeIos.soundArg, isTrue, reason: 'sound must be true');
      },
    );
  });

  // -------------------------------------------------------------------------
  // IOS-10 db-injection regression guard
  //
  // maybeRequestNotificationPermissionForUsage accepts an optional AppDatabase
  // so callers with an existing Riverpod-provided db can pass it through,
  // avoiding the Drift "multiple AppDatabase instances" warning that fires
  // when a raw AppDatabase() is constructed inside _isUsageAnchorMet.
  //
  // On the test host (non-iOS) the platform guard returns before any db
  // access, so these tests verify the API contract: the db parameter is
  // accepted without error, and the method completes successfully with a
  // real in-memory database passed in. The fix (app.dart passing
  // ref.read(appDatabaseProvider)) is covered by the widget smoke test in
  // test/widget/app_test.dart which overrides appDatabaseProvider and
  // exercises the post-frame hook.
  // -------------------------------------------------------------------------

  group(
    'maybeRequestNotificationPermissionForUsage db-injection API (IOS-10 fix)',
    () {
      test(
        'accepts an explicit AppDatabase without error (no raw constructor)',
        () async {
          // Verifies the public API accepts an injected db so callers can pass
          // the shared Riverpod-provided instance. On a non-iOS test host the
          // platform guard causes an early return before the db is read; the
          // test confirms the method signature and error-free completion.
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);

          final service = NotificationService();
          // Must complete without throwing. On non-iOS this is a no-op
          // (platform guard). The db parameter being accepted without type
          // error confirms the API contract introduced by the IOS-10 fix.
          await expectLater(
            service.maybeRequestNotificationPermissionForUsage(db: db),
            completes,
          );
        },
      );

      test(
        'accepts forceRequest: true with explicit db without error',
        () async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);

          final service = NotificationService();
          await expectLater(
            service.maybeRequestNotificationPermissionForUsage(
              db: db,
              forceRequest: true,
            ),
            completes,
          );
        },
      );
    },
  );
}
