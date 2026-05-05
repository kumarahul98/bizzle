import 'package:drift/drift.dart';
import 'package:traevy/config/constants.dart';

/// User-level preferences (dark mode, reminder times, direction cutoffs).
///
/// Designed as a single-row table keyed at `id = 1`. Per D-04 the
/// `onCreate` migration must NOT seed a row — the DAO's
/// `getOrDefault()` returns a hardcoded default value object when the
/// row is absent. This lets first-run code read preferences without a
/// racey upsert, and keeps migration logic trivial (nothing to re-seed
/// after schema bumps).
///
/// Column defaults use `kDefaultUserId`, `kDarkModeSystem`, and
/// `kDefaultDirectionCutoffHour` from `lib/config/constants.dart`.
@DataClassName('UserPreferencesRow')
class UserPreferences extends Table {
  /// Non-auto-increment integer so callers always write `id = 1`. There
  /// is exactly one row per app install in Phase 1.
  IntColumn get id => integer()();

  /// Owning user. Defaults to `kDefaultUserId`; Phase 8 replaces this
  /// with the Cognito sub.
  TextColumn get userId =>
      text().withDefault(const Constant(kDefaultUserId))();

  /// `'system'`, `'light'`, or `'dark'`. Default: `kDarkModeSystem`.
  TextColumn get darkMode =>
      text().withDefault(const Constant(kDarkModeSystem))();

  /// Hour (0-23) before which starting trips auto-label as `'to_office'`.
  /// Default: `kDefaultDirectionCutoffHour`.
  IntColumn get morningCutoffHour =>
      integer().withDefault(const Constant(kDefaultDirectionCutoffHour))();

  /// Hour (0-23) after which starting trips auto-label as `'to_home'`.
  /// Default: `kDefaultDirectionCutoffHour`.
  IntColumn get eveningCutoffHour =>
      integer().withDefault(const Constant(kDefaultDirectionCutoffHour))();

  /// True if the user has opted into the daily tracking reminder.
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// `HH:mm` formatted local time. Null when no reminder is scheduled.
  TextColumn get reminderTime => text().nullable()();

  /// True if the reminder should also fire on Saturday and Sunday.
  BoolColumn get weekendReminder =>
      boolean().withDefault(const Constant(false))();

  /// True if the user has opted into the weekly commute summary notification.
  ///
  /// Default false so no notification fires until the user enables it.
  /// Added by schema migration v1 → v2 (D-07, D-13).
  BoolColumn get weeklyNotificationEnabled =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
