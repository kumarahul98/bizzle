import 'package:drift/drift.dart';

/// User-level preferences (dark mode, reminder times, direction cutoffs).
///
/// Designed as a single-row table keyed at `id = 1`. Per D-04 the
/// `onCreate` migration must NOT seed a row — `UserPreferencesDao.getOrDefault()`
/// returns a hardcoded default value object when the row is absent. This
/// lets first-run code read preferences without a racey upsert, and keeps
/// migration logic trivial (nothing to re-seed after schema bumps).
///
/// The literal defaults below (`'local_user'`, `'system'`, `12`, `false`)
/// will be replaced with `kDefaultUserId`, `kDarkModeSystem`, and
/// `kDefaultDirectionCutoffHour` once plan 01-02 lands
/// `lib/config/constants.dart`. Until then, keep the values in lockstep
/// with `lib/config/constants.dart` when it arrives.
@DataClassName('UserPreferencesRow')
class UserPreferences extends Table {
  /// Non-auto-increment integer so callers always write `id = 1`. There
  /// is exactly one row per app install in Phase 1.
  IntColumn get id => integer()();

  /// Owning user. Defaults to the `'local_user'` placeholder like the
  /// trips table; Phase 8 replaces this with the Cognito sub.
  TextColumn get userId =>
      text().withDefault(const Constant('local_user'))();

  /// `'system'`, `'light'`, or `'dark'`.
  TextColumn get darkMode =>
      text().withDefault(const Constant('system'))();

  /// Hour (0-23) before which starting trips auto-label as `'to_office'`.
  /// Defaults to 12 (noon) per CLAUDE.md direction auto-labeling section.
  IntColumn get morningCutoffHour =>
      integer().withDefault(const Constant(12))();

  /// Hour (0-23) after which starting trips auto-label as `'to_home'`.
  /// Defaults to 12 (noon) per CLAUDE.md direction auto-labeling section.
  IntColumn get eveningCutoffHour =>
      integer().withDefault(const Constant(12))();

  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// `HH:mm` formatted local time. Null when no reminder is scheduled.
  TextColumn get reminderTime => text().nullable()();

  BoolColumn get weekendReminder =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
