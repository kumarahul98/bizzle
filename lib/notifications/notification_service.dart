import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/shared/utils/formatters.dart';

/// Manages the two Phase 7 notification channels and their scheduled alarms.
///
/// Separate from `TrackingNotificationService` per D-14: this service owns
/// [kWeeklySummaryChannelId] and [kReminderChannelId]; the tracking service
/// owns [kTrackingNotificationChannelId]. Never reuse channel IDs across
/// services.
///
/// Constructor injection of [FlutterLocalNotificationsPlugin] allows test
/// fakes. Production callers pass no argument.
class NotificationService {
  /// Create a [NotificationService].
  ///
  /// [plugin] defaults to a fresh [FlutterLocalNotificationsPlugin] instance.
  /// The plugin is a singleton under the hood, so sharing state with
  /// `TrackingNotificationService` is safe.
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Register the two Phase 7 notification channels and reschedule any
  /// already-enabled notifications from persisted preferences.
  ///
  /// Must be called from `main` AFTER `tz.initializeTimeZones()` and AFTER
  /// `TrackingNotificationService.initialize()`. This call is idempotent —
  /// Android channel creation is a no-op if the channel already exists.
  ///
  /// See D-08, D-14 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
  Future<void> initialize() async {
    // Initialize the plugin for both platforms.
    // Darwin settings defer permission to TrackingPermissionService.preflight()
    // in Phase 15, so all request* flags are false here.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      ),
    );
    await _createChannels();
    // Reschedule any already-enabled notifications from DB preferences.
    // Uses a temporary AppDatabase instance — NOT Riverpod (not yet running).
    // D-08: schedule on app start if enabled.
    final db = AppDatabase();
    try {
      final prefs = await db.userPreferencesDao.getOrDefault();
      if (prefs.weeklyNotificationEnabled) {
        // Reuse the public method so there is one canonical scheduling path.
        // Body is built from current DB data on every app start (WR-01).
        await scheduleWeeklySummary(db);
      }
      if (prefs.reminderEnabled && prefs.reminderTime != null) {
        await scheduleReminder(
          hhMm: prefs.reminderTime!,
          includeWeekends: prefs.weekendReminder,
        );
      }
    } on Exception catch (e, s) {
      // Log and continue — a bad preferences row must never crash startup.
      debugPrint('NotificationService.initialize: $e\n$s');
    } finally {
      await db.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Weekly Summary
  // ---------------------------------------------------------------------------

  /// Schedule the weekly commute summary notification for Sunday at 6 PM.
  ///
  /// Cancels any existing alarm before rescheduling (Pitfall 3 mitigation).
  /// Builds the notification body by querying the DAO for current week totals.
  ///
  /// See D-05, D-06 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
  Future<void> scheduleWeeklySummary(AppDatabase db) async {
    await cancelWeeklySummary();
    final body = await _buildWeeklyBody(db);
    await _plugin.zonedSchedule(
      id: kWeeklySummaryNotificationId,
      title: kWeeklySummaryNotificationTitle,
      body: body,
      scheduledDate: _nextSunday6pm(),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          kWeeklySummaryChannelId,
          kWeeklySummaryChannelName,
          channelDescription: kWeeklySummaryChannelDescription,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Cancel the weekly summary notification.
  ///
  /// Safe to call even if no alarm is scheduled — `cancel()` is a no-op
  /// for unknown IDs.
  Future<void> cancelWeeklySummary() async {
    await _plugin.cancel(id: kWeeklySummaryNotificationId);
  }

  // ---------------------------------------------------------------------------
  // Reminder
  // ---------------------------------------------------------------------------

  /// Schedule the daily tracking reminder notification.
  ///
  /// When [includeWeekends] is false, schedules 5 separate alarms (Mon–Fri)
  /// using `DateTimeComponents.dayOfWeekAndTime` at IDs
  /// [kReminderNotificationId] through [kReminderNotificationId] + 4.
  ///
  /// When [includeWeekends] is true, schedules a single daily alarm using
  /// `DateTimeComponents.time` at ID [kReminderNotificationId].
  ///
  /// Cancels all reminder slots (IDs 20–24) before rescheduling to avoid
  /// stale alarms (Pitfall 3 mitigation from RESEARCH.md).
  ///
  /// See D-12 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
  Future<void> scheduleReminder({
    required String hhMm,
    required bool includeWeekends,
  }) async {
    // Cancel all reminder slots first (Pitfall 6 from RESEARCH.md).
    for (var i = 0; i <= 4; i++) {
      await _plugin.cancel(id: kReminderNotificationId + i);
    }

    final parts = hhMm.split(':');
    if (parts.length != 2) return; // guard malformed input
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return; // silently skip rather than crash
    }

    if (includeWeekends) {
      // Single daily reminder — fires every day at the given time.
      await _plugin.zonedSchedule(
        id: kReminderNotificationId,
        title: kReminderNotificationTitle,
        body: kReminderNotificationBody,
        scheduledDate: _nextDailyTime(hour, minute),
        notificationDetails: _reminderDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      // Mon–Fri only: 5 separate alarms, one per weekday.
      // kReminderNotificationId + 0 = Monday (DateTime.monday = 1)
      // kReminderNotificationId + 1 = Tuesday, ..., + 4 = Friday
      const weekdays = <int>[
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      ];
      for (var i = 0; i < weekdays.length; i++) {
        await _plugin.zonedSchedule(
          id: kReminderNotificationId + i,
          title: kReminderNotificationTitle,
          body: kReminderNotificationBody,
          scheduledDate: _nextWeekday(weekdays[i], hour, minute),
          notificationDetails: _reminderDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  /// Cancel all reminder notification slots (IDs 20–24).
  Future<void> cancelReminder() async {
    for (var i = 0; i <= 4; i++) {
      await _plugin.cancel(id: kReminderNotificationId + i);
    }
  }

  // ---------------------------------------------------------------------------
  // iOS notification permission (IOS-10)
  // ---------------------------------------------------------------------------

  /// Request the iOS notification permission (alert, badge, sound).
  ///
  /// No-op on non-iOS platforms when called without an explicit [iosPlugin].
  /// When [iosPlugin] is provided (test seam), the platform guard is bypassed
  /// so the injected fake is always exercised — the caller is responsible for
  /// ensuring this is only done in tests or iOS-specific code paths.
  ///
  /// Errors are caught and logged, never thrown — matches the [initialize]
  /// error-handling pattern.
  Future<void> requestIOSNotificationPermission({
    IOSFlutterLocalNotificationsPlugin? iosPlugin,
  }) async {
    // When an explicit iosPlugin is provided (test seam), skip the platform
    // guard — the injected fake is the intended recipient regardless of the
    // host platform.
    if (iosPlugin == null && defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      final ios =
          iosPlugin ??
          _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } on Exception catch (e, s) {
      debugPrint(
        'NotificationService.requestIOSNotificationPermission: $e\n$s',
      );
    }
  }

  /// Request iOS notification permission once, using a contextual trigger.
  ///
  /// Requests when EITHER of the following is true:
  ///   (a) The oldest recorded trip's `startTime` is ≥7 days ago (natural
  ///       weekly-summary anchor, D-07).
  ///   (b) Called directly from the departure-reminder enable path — the
  ///       caller opts in before the 7-day mark.
  ///
  /// A sentinel file is written to the app support directory on the first
  /// call so this never re-asks (one-time permission request). The method
  /// is a no-op on non-iOS platforms and never throws.
  ///
  /// Pass [forceRequest] = true to bypass the 7-day anchor check (used from
  /// the reminder-enable path, where the user's explicit action is the
  /// contextual signal regardless of trip age).
  Future<void> maybeRequestNotificationPermissionForUsage({
    AppDatabase? db,
    bool forceRequest = false,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      // Check one-time sentinel so we never ask twice.
      if (await _hasRequestedPermission()) return;

      final shouldRequest = forceRequest || await _isUsageAnchorMet(db: db);
      if (!shouldRequest) return;

      await requestIOSNotificationPermission();
      await _writePermissionRequestedSentinel();
    } on Exception catch (e, s) {
      debugPrint(
        'NotificationService.maybeRequestNotificationPermissionForUsage: '
        '$e\n$s',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    const weeklySummaryChannel = AndroidNotificationChannel(
      kWeeklySummaryChannelId,
      kWeeklySummaryChannelName,
      description: kWeeklySummaryChannelDescription,
    );
    const reminderChannel = AndroidNotificationChannel(
      kReminderChannelId,
      kReminderChannelName,
      description: kReminderChannelDescription,
    );
    await android?.createNotificationChannel(weeklySummaryChannel);
    await android?.createNotificationChannel(reminderChannel);
  }

  /// Build the weekly summary notification body from current DB data.
  ///
  /// Queries trips for the current Mon–Sun week directly via the DAO — not
  /// through Riverpod (which is unavailable at schedule time in main.dart).
  /// Uses [formatDuration] for both totals.
  Future<String> _buildWeeklyBody(AppDatabase db) async {
    final trips = await db.tripsDao.watchAllSummaries().first;
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final daysSinceMonday = today.weekday - DateTime.monday;
    final weekStart = today.subtract(Duration(days: daysSinceMonday));
    final weekEnd = weekStart.add(const Duration(days: 7));

    var weekTotalSeconds = 0;
    var weekStuckSeconds = 0;
    for (final trip in trips) {
      final local = trip.startTime.toLocal();
      if (!local.isBefore(weekStart) && local.isBefore(weekEnd)) {
        weekTotalSeconds += trip.durationSeconds;
        if (!trip.isManualEntry) {
          weekStuckSeconds += trip.timeStuckSeconds;
        }
      }
    }

    if (weekTotalSeconds == 0) {
      return kWeeklySummaryNotificationBodyEmpty;
    }
    return '${formatDuration(weekTotalSeconds)} total, '
        '${formatDuration(weekStuckSeconds)} in traffic';
  }

  NotificationDetails _reminderDetails() => const NotificationDetails(
    android: AndroidNotificationDetails(
      kReminderChannelId,
      kReminderChannelName,
      channelDescription: kReminderChannelDescription,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
    ),
  );

  /// Compute the next Sunday at 6:00 PM local time.
  ///
  /// If today is Sunday and it is already past 6 PM, advances to next Sunday.
  tz.TZDateTime _nextSunday6pm() {
    final now = tz.TZDateTime.now(tz.local);
    var candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      18, // 6 PM
    );
    while (candidate.weekday != DateTime.sunday || candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  /// Compute the next occurrence of [hour]:[minute] local time today or
  /// tomorrow (for daily reminders).
  tz.TZDateTime _nextDailyTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  /// Compute the next occurrence of [weekday] (DateTime.monday..friday) at
  /// [hour]:[minute] local time.
  tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (candidate.weekday != weekday || candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  // ---------------------------------------------------------------------------
  // Permission sentinel helpers (IOS-10)
  // ---------------------------------------------------------------------------

  /// Filename for the iOS notification permission sentinel file.
  ///
  /// Written to the app support directory on the first contextual permission
  /// request so the request is never repeated.
  static const String _kPermissionSentinelFile =
      '.ios_notif_permission_requested';

  /// Returns the sentinel [File] in the app support directory.
  Future<File> _sentinelFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_kPermissionSentinelFile');
  }

  /// True if the one-time sentinel has already been written.
  Future<bool> _hasRequestedPermission() async {
    final f = await _sentinelFile();
    return f.existsSync();
  }

  /// Write the one-time sentinel so the request is not repeated.
  Future<void> _writePermissionRequestedSentinel() async {
    try {
      final f = await _sentinelFile();
      await f.create(recursive: true);
    } on Exception catch (e, s) {
      debugPrint(
        'NotificationService._writePermissionRequestedSentinel: $e\n$s',
      );
    }
  }

  /// Returns true if the 7-day usage anchor is met (the oldest recorded
  /// trip's startTime is at least 7 days before now).
  ///
  /// Opens a fresh [AppDatabase] if [db] is null (fire-and-forget caller
  /// in app.dart has no provider context).
  Future<bool> _isUsageAnchorMet({AppDatabase? db}) async {
    final ownDb = db == null;
    final database = db ?? AppDatabase();
    try {
      final trips = await database.tripsDao.watchAllSummaries().first;
      if (trips.isEmpty) return false;
      // Find the oldest trip start time.
      final oldest = trips.reduce(
        (a, b) => a.startTime.isBefore(b.startTime) ? a : b,
      );
      final age = DateTime.now().difference(oldest.startTime);
      return age.inDays >= kNotificationPermissionAnchorDays;
    } finally {
      if (ownDb) await database.close();
    }
  }
}
