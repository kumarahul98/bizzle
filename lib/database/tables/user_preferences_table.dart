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

  /// True if the user has opted into auto-pause (Phase 18, D-10; default
  /// flipped Phase 27, UX-08).
  ///
  /// Added by schema migration v2 → v3 with a `false` (opt-in) default.
  /// Phase 27 (UX-08) flips the DEFAULT to `true` — auto-pause is now ON
  /// out of the box for fresh installs — while the v7 → v8 migration
  /// explicitly backfills every EXISTING row to `true` too, so upgraded
  /// installs get the same behaviour change (see `database.dart` v8
  /// branch). `withDefault(const Constant(true))` covers the `onCreate`
  /// (fresh-install, no row) path only; it does NOT retroactively change
  /// already-created rows, hence the explicit backfill.
  BoolColumn get autoPauseEnabled =>
      boolean().withDefault(const Constant(true))();

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
  /// PII — this coordinate reveals where the user lives. **NEVER log it**
  /// (T-21-03, still in force).
  ///
  /// **These coordinates DO leave the device as of Phase 29 (LOC-03).** Until
  /// then this dartdoc read "Stored locally in Drift only; no sync field
  /// carries it", per Phase 21's T-21-02. Phase 29 reversed that decision
  /// deliberately so a reinstall restores Home/Office instead of silently
  /// degrading geofence labeling — see D-01 in
  /// `.planning/phases/29-sync-home-office-locations/29-PLAN.md`, and the Play
  /// Data Safety declaration that reversal requires.
  ///
  /// What did NOT change: T-21-03. Transporting a coordinate over TLS to our
  /// own Firestore is a different act from writing it to a log sink. The sync
  /// path (`PreferencesSyncService`, `ApiClient.syncPreferences`) logs nothing.
  ///
  /// Added by schema migration v5 → v6 (additive); existing rows read null.
  RealColumn get homeLat => real().nullable()();

  /// Saved Home longitude (Phase 21, D-01). Null = not set. PII — NEVER log
  /// (T-21-03). Syncs to the cloud as of Phase 29; see [homeLat] for the full
  /// posture. Added by schema migration v5 → v6 (additive).
  RealColumn get homeLng => real().nullable()();

  /// Saved Office latitude (Phase 21, D-01). Null = not set. PII — NEVER log
  /// (T-21-03). Syncs to the cloud as of Phase 29; see [homeLat] for the full
  /// posture. Added by schema migration v5 → v6 (additive).
  RealColumn get officeLat => real().nullable()();

  /// Saved Office longitude (Phase 21, D-01). Null = not set. PII — NEVER log
  /// (T-21-03). Syncs to the cloud as of Phase 29; see [homeLat] for the full
  /// posture. Added by schema migration v5 → v6 (additive).
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

  /// CSV of page keys whose one-time guided tour has already been shown
  /// (Phase 27, UX-07 tour persistence scaffold). Empty string = no tour
  /// seen yet. Parsed into a `Set<String>` by
  /// `UserPreferencesValue.seenTourKeys`; mutated one key at a time by
  /// `UserPreferencesDao.markTourSeen()`. Added by schema migration v7 →
  /// v8 (additive) — existing rows read `''` (no tours seen), so every
  /// upgraded install still sees each page's tour once, same as a fresh
  /// install.
  TextColumn get seenTours => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
