import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/shared/models/reminder_suggestion_state.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v9.dart' as v9;

/// Proves the Phase 33 v9 → v10 migration (D-02 day selection, D-03 reminder
/// defaults, D-04 suggestion columns).
///
/// The test that matters most here is T-33-02: a user who deliberately turned
/// the reminder OFF must still have it off after upgrading. `reminder_enabled
/// = 0` is simultaneously the old table default AND the value written by a
/// deliberate opt-out — SQLite keeps no third state that tells them apart — so
/// the migration rebuilds the table for its DDL default only and copies every
/// existing row value across untouched. Any `columnTransformer` on
/// `reminder_enabled` would silently re-enable notifications for people who
/// switched them off, which is the one outcome this phase must not produce.
void main() {
  group('Drift v9 → v10 migration (Phase 33)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v9 schema opens cleanly at version 9', () async {
      final connection = await verifier.startAt(9);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      final result = await db.customSelect('SELECT 1 AS one').getSingle();
      expect(result.read<int>('one'), 1);
    });

    test(
      'T-33-02: a row with reminder_enabled = 0 survives v9 → v10 unchanged',
      () async {
        final schema = await verifier.schemaAt(9);
        final oldDb = v9.DatabaseAtV9(schema.newConnection());
        await oldDb
            .into(oldDb.userPreferences)
            .insert(
              const RawValuesInsertable<dynamic>({
                'id': Variable<int>(1),
                'user_id': Variable<String>(kDefaultUserId),
                // The user explicitly turned the reminder off after having
                // picked a time — the exact state that must be preserved.
                'reminder_enabled': Variable<bool>(false),
                'reminder_time': Variable<String>('06:15'),
              }),
            );
        await oldDb.close();

        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 10);

        final prefs = await migratedDb.userPreferencesDao.getOrDefault();
        expect(
          prefs.reminderEnabled,
          isFalse,
          reason:
              'an opted-out user must NOT have notifications re-enabled by '
              'the migration (T-33-02)',
        );
        expect(
          prefs.reminderTime,
          '06:15',
          reason: 'an explicitly chosen time must survive the rebuild',
        );
      },
    );

    test('a null reminder_time stays null across the rebuild', () async {
      final schema = await verifier.schemaAt(9);
      final oldDb = v9.DatabaseAtV9(schema.newConnection());
      await oldDb
          .into(oldDb.userPreferences)
          .insert(
            const RawValuesInsertable<dynamic>({
              'id': Variable<int>(1),
              'user_id': Variable<String>(kDefaultUserId),
              'reminder_enabled': Variable<bool>(false),
            }),
          );
      await oldDb.close();

      final migratedDb = AppDatabase(schema.newConnection());
      addTearDown(migratedDb.close);
      await verifier.migrateAndValidate(migratedDb, 10);

      final prefs = await migratedDb.userPreferencesDao.getOrDefault();
      expect(prefs.reminderTime, isNull);
      expect(prefs.reminderEnabled, isFalse);
    });

    test(
      'SC#3: weekend_reminder = 1 backfills reminder_days to all seven days, '
      'and other rows keep the weekday default',
      () async {
        final schema = await verifier.schemaAt(9);
        final oldDb = v9.DatabaseAtV9(schema.newConnection());
        await oldDb
            .into(oldDb.userPreferences)
            .insert(
              const RawValuesInsertable<dynamic>({
                'id': Variable<int>(1),
                'user_id': Variable<String>(kDefaultUserId),
                'reminder_enabled': Variable<bool>(true),
                'reminder_time': Variable<String>('08:00'),
                'weekend_reminder': Variable<bool>(true),
              }),
            );
        await oldDb.close();

        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 10);

        final prefs = await migratedDb.userPreferencesDao.getOrDefault();
        expect(prefs.reminderDays, kAllReminderDays);
        expect(prefs.reminderDayNumbers, <int>{1, 2, 3, 4, 5, 6, 7});
        // Untouched preferences survive.
        expect(prefs.reminderEnabled, isTrue);
        expect(prefs.reminderTime, '08:00');
      },
    );

    test(
      'weekend_reminder = 0 keeps the weekday default and empty suggestion '
      'state (SC#11)',
      () async {
        final schema = await verifier.schemaAt(9);
        final oldDb = v9.DatabaseAtV9(schema.newConnection());
        await oldDb
            .into(oldDb.userPreferences)
            .insert(
              const RawValuesInsertable<dynamic>({
                'id': Variable<int>(1),
                'user_id': Variable<String>(kDefaultUserId),
                'dark_mode': Variable<String>(kDarkModeDark),
                'reminder_enabled': Variable<bool>(true),
                'reminder_time': Variable<String>('07:30'),
                'weekend_reminder': Variable<bool>(false),
                'seen_tours': Variable<String>('dashboard'),
                'home_lat': Variable<double>(12.5),
                'home_lng': Variable<double>(77.5),
              }),
            );
        await oldDb.close();

        final migratedDb = AppDatabase(schema.newConnection());
        addTearDown(migratedDb.close);
        await verifier.migrateAndValidate(migratedDb, 10);

        final prefs = await migratedDb.userPreferencesDao.getOrDefault();
        expect(prefs.reminderDays, kDefaultReminderDays);
        expect(prefs.reminderSuggestionState, ReminderSuggestionState.none);
        expect(prefs.reminderSuggestionValue, isNull);
        // Every unrelated preference survives the table rebuild (SC#11).
        expect(prefs.darkMode, kDarkModeDark);
        expect(prefs.seenTours, 'dashboard');
        expect(prefs.homeLat, 12.5);
        expect(prefs.homeLng, 77.5);
      },
    );

    test('an existing trip is untouched by the preferences rebuild', () async {
      final schema = await verifier.schemaAt(9);
      final oldDb = v9.DatabaseAtV9(schema.newConnection());
      const tripId = 'trip-v9-survivor';
      await oldDb
          .into(oldDb.trips)
          .insert(
            RawValuesInsertable<dynamic>({
              'id': const Variable<String>(tripId),
              'start_time': Variable<DateTime>(DateTime.utc(2026, 6, 1, 8)),
              'end_time': Variable<DateTime>(DateTime.utc(2026, 6, 1, 9)),
              'duration_seconds': const Variable<int>(3600),
              'total_paused_seconds': const Variable<int>(0),
              'distance_meters': const Variable<double>(9000),
              'direction': const Variable<String>(kDirectionToOffice),
              'time_moving_seconds': const Variable<int>(3000),
              'time_stuck_seconds': const Variable<int>(600),
            }),
          );
      await oldDb.close();

      final migratedDb = AppDatabase(schema.newConnection());
      addTearDown(migratedDb.close);
      await verifier.migrateAndValidate(migratedDb, 10);

      final trip = await migratedDb.tripsDao.findById(tripId);
      expect(trip, isNotNull);
      expect(trip!.durationSeconds, 3600);
      expect(trip.direction, kDirectionToOffice);
    });

    test(
      'SC#1: a fresh install has the reminder on at 07:00 on weekdays',
      () async {
        final db = AppDatabase(
          DatabaseConnection(
            NativeDatabase.memory(),
            closeStreamsSynchronously: true,
          ),
        );
        addTearDown(db.close);

        // No row at all — the D-04 "create on demand" contract means a fresh
        // install reads UserPreferencesValue.defaults(). This is the path
        // that actually delivers SC#1.
        final defaults = await db.userPreferencesDao.getOrDefault();
        expect(defaults.reminderEnabled, isTrue);
        expect(defaults.reminderTime, kDefaultReminderTime);
        expect(defaults.reminderDayNumbers, <int>{1, 2, 3, 4, 5});

        // And the DB-level column defaults agree, so a row created by any
        // single-column upsert (e.g. setHasSeenOnboarding) matches.
        await db
            .into(db.userPreferences)
            .insert(UserPreferencesCompanion.insert(id: const Value<int>(1)));
        final row = await db
            .customSelect(
              'SELECT reminder_enabled, reminder_time, reminder_days, '
              'reminder_suggestion_state, reminder_suggestion_value '
              'FROM user_preferences WHERE id = 1',
            )
            .getSingle();
        expect(row.read<bool>('reminder_enabled'), isTrue);
        expect(row.read<String>('reminder_time'), kDefaultReminderTime);
        expect(row.read<String>('reminder_days'), kDefaultReminderDays);
        expect(
          row.read<String>('reminder_suggestion_state'),
          kReminderSuggestionStateNone,
        );
        expect(row.read<String?>('reminder_suggestion_value'), isNull);
      },
    );

    test('schemaVersion is 10', () {
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(db.close);
      expect(db.schemaVersion, 10);
    });
  });
}
