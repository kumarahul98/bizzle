import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';

void main() {
  group('UserPreferencesDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'getOrDefault returns hardcoded defaults when row absent (D-04)',
      () async {
        final value = await db.userPreferencesDao.getOrDefault();

        expect(value.userId, kDefaultUserId);
        expect(value.darkMode, kDarkModeSystem);
        expect(value.morningCutoffHour, kDefaultDirectionCutoffHour);
        expect(value.eveningCutoffHour, kDefaultDirectionCutoffHour);
        expect(value.reminderEnabled, isFalse);
        expect(value.reminderTime, isNull);
        expect(value.weekendReminder, isFalse);
      },
    );

    test('upsert then getOrDefault returns the upserted value', () async {
      const updated = UserPreferencesValue(
        userId: kDefaultUserId,
        darkMode: 'dark',
        morningCutoffHour: 9,
        eveningCutoffHour: 17,
        reminderEnabled: true,
        reminderTime: '08:30',
        weekendReminder: true,
        weeklyNotificationEnabled: true,
        autoPauseEnabled: true,
      );

      await db.userPreferencesDao.upsert(updated);
      final read = await db.userPreferencesDao.getOrDefault();

      expect(read.darkMode, 'dark');
      expect(read.morningCutoffHour, 9);
      expect(read.eveningCutoffHour, 17);
      expect(read.reminderEnabled, isTrue);
      expect(read.reminderTime, '08:30');
      expect(read.weekendReminder, isTrue);
      expect(read.autoPauseEnabled, isTrue);
    });

    test('upsert is idempotent — second upsert overwrites first', () async {
      const first = UserPreferencesValue(
        userId: kDefaultUserId,
        darkMode: 'dark',
        morningCutoffHour: 9,
        eveningCutoffHour: 17,
        reminderEnabled: true,
        reminderTime: '08:30',
        weekendReminder: true,
        weeklyNotificationEnabled: true,
        autoPauseEnabled: true,
      );
      const second = UserPreferencesValue(
        userId: kDefaultUserId,
        darkMode: 'light',
        morningCutoffHour: 10,
        eveningCutoffHour: 18,
        reminderEnabled: false,
        reminderTime: null,
        weekendReminder: false,
        weeklyNotificationEnabled: false,
        autoPauseEnabled: false,
      );

      await db.userPreferencesDao.upsert(first);
      await db.userPreferencesDao.upsert(second);

      final read = await db.userPreferencesDao.getOrDefault();
      expect(read.darkMode, 'light');
      expect(read.morningCutoffHour, 10);
      expect(read.reminderEnabled, isFalse);
      expect(read.reminderTime, isNull);
      expect(read.autoPauseEnabled, isFalse);
    });

    test('watch() emits UserPreferencesValue.defaults() when no row exists '
        '(first launch)', () async {
      final value = await db.userPreferencesDao.watch().first;

      expect(value.userId, kDefaultUserId);
      expect(value.darkMode, kDarkModeSystem);
      expect(value.morningCutoffHour, kDefaultDirectionCutoffHour);
      expect(value.eveningCutoffHour, kDefaultDirectionCutoffHour);
      expect(value.reminderEnabled, isFalse);
      expect(value.reminderTime, isNull);
      expect(value.weekendReminder, isFalse);
      expect(value.weeklyNotificationEnabled, isFalse);
      expect(value.autoPauseEnabled, isFalse);
    });

    test('watch() emits updated value after upsert()', () async {
      const updated = UserPreferencesValue(
        userId: kDefaultUserId,
        darkMode: 'dark',
        morningCutoffHour: 9,
        eveningCutoffHour: 17,
        reminderEnabled: true,
        reminderTime: '08:30',
        weekendReminder: true,
        weeklyNotificationEnabled: true,
        autoPauseEnabled: true,
      );

      await db.userPreferencesDao.upsert(updated);
      final value = await db.userPreferencesDao.watch().first;

      expect(value.darkMode, 'dark');
      expect(value.morningCutoffHour, 9);
      expect(value.reminderEnabled, isTrue);
      expect(value.reminderTime, '08:30');
      expect(value.weekendReminder, isTrue);
      expect(value.weeklyNotificationEnabled, isTrue);
    });
  });
}
