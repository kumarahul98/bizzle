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
  TextColumn get userId => text().withDefault(const Constant(kDefaultUserId))();

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

  /// True if the user has opted into auto-pause (Phase 18, D-10).
  ///
  /// Off by default so auto-pause is strictly opt-in: existing users see
  /// no behaviour change until they enable it. Added by schema migration
  /// v2 → v3; `withDefault(const Constant(false))` gives every existing
  /// row false automatically.
  BoolColumn get autoPauseEnabled =>
      boolean().withDefault(const Constant(false))();

  /// True once the user has cleared the first-run login wall (Phase 20,
  /// D-01/D-02). Drives the root gate in `lib/app.dart`: while false a guest
  /// sees the `LoginScreen`; after Skip or a successful Google sign-in it
  /// flips true and the gate routes to the main shell.
  ///
  /// Default false. Added by schema migration v4 → v5; the migration's
  /// returning-user guard (D-02) flips the EXISTING single row to true so a
  /// pre-update install is NEVER walled — the login screen is first-INSTALL
  /// only. Fresh installs run `onCreate` (no row) → `getOrDefault()` returns
  /// false → the wall shows exactly once.
  BoolColumn get hasSeenOnboarding =>
      boolean().withDefault(const Constant(false))();

  /// Saved Home latitude (Phase 21, D-01). Null = not set; single-row table.
  ///
  /// PII-adjacent — this coordinate reveals where the user lives. NEVER log it
  /// (T-21-03). Stored locally in Drift only; no sync field carries it.
  /// Added by schema migration v5 → v6 (additive); existing rows read null.
  RealColumn get homeLat => real().nullable()();

  /// Saved Home longitude (Phase 21, D-01). Null = not set. PII-adjacent —
  /// NEVER log (T-21-03). Added by schema migration v5 → v6 (additive).
  RealColumn get homeLng => real().nullable()();

  /// Saved Office latitude (Phase 21, D-01). Null = not set. PII-adjacent —
  /// NEVER log (T-21-03). Added by schema migration v5 → v6 (additive).
  RealColumn get officeLat => real().nullable()();

  /// Saved Office longitude (Phase 21, D-01). Null = not set. PII-adjacent —
  /// NEVER log (T-21-03). Added by schema migration v5 → v6 (additive).
  RealColumn get officeLng => real().nullable()();

  /// Version-keyed backfill marker (Phase 26, D-03): tracks "backfill done
  /// for payload schema v{N}" so the one-time re-sync for trips with breaks
  /// or edits runs at most once per target schema version, not once per app
  /// launch. `0` = backfill has never run on this install. Compared against
  /// `kBackfillMarkerVersion` (`lib/config/constants.dart`) by
  /// `UserPreferencesDao.getBackfillMarkerVersion()`. Added by schema
  /// migration v6 → v7 (additive).
  IntColumn get backfillMarkerVersion =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
