import 'package:drift/drift.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/database.dart';
import 'package:traevy/database/tables/user_preferences_table.dart';

part 'user_preferences_dao.g.dart';

/// The fixed primary key for the single user_preferences row. Drift
/// stores preferences as exactly one row at `id = 1`; callers must
/// never insert at a different id.
const int _kUserPreferencesId = 1;

/// Plain Dart value type representing the user's preferences.
///
/// Distinct from `UserPreferencesRow` because the DAO must be able to
/// return a value object even when no row exists in the database — the
/// D-04 decision mandates "create on demand, no seed row" so
/// `getOrDefault()` constructs this from hardcoded defaults on first
/// read. A `UserPreferencesRow` cannot be returned in that case because
/// Drift rows represent actual persisted data.
class UserPreferencesValue {
  /// Construct an explicit `UserPreferencesValue`. All fields required
  /// so callers cannot accidentally leave a preference unset.
  const UserPreferencesValue({
    required this.userId,
    required this.darkMode,
    required this.morningCutoffHour,
    required this.eveningCutoffHour,
    required this.reminderEnabled,
    required this.reminderTime,
    required this.weekendReminder,
    required this.weeklyNotificationEnabled,
    required this.autoPauseEnabled,
    required this.hasSeenOnboarding,
    required this.homeLat,
    required this.homeLng,
    required this.officeLat,
    required this.officeLng,
    required this.backfillMarkerVersion,
    this.seenTours = '',
  });

  /// The defaults used the first time the user launches the app —
  /// before the single row exists in the table (D-04).
  const UserPreferencesValue.defaults()
    : userId = kDefaultUserId,
      darkMode = kDarkModeSystem,
      morningCutoffHour = kDefaultDirectionCutoffHour,
      eveningCutoffHour = kDefaultDirectionCutoffHour,
      reminderEnabled = false,
      reminderTime = null,
      weekendReminder = false,
      weeklyNotificationEnabled = false,
      autoPauseEnabled = true,
      hasSeenOnboarding = false,
      homeLat = null,
      homeLng = null,
      officeLat = null,
      officeLng = null,
      backfillMarkerVersion = 0,
      seenTours = '';

  /// Owning user placeholder (Phase 8 replaces with Cognito sub).
  final String userId;

  /// `'system'`, `'light'`, or `'dark'`.
  final String darkMode;

  /// Hour (0-23) before which starts auto-label as `'to_office'`.
  final int morningCutoffHour;

  /// Hour (0-23) after which starts auto-label as `'to_home'`.
  final int eveningCutoffHour;

  /// True if the user has opted into the daily tracking reminder.
  final bool reminderEnabled;

  /// `HH:mm` local time for the reminder; null when disabled.
  final String? reminderTime;

  /// True if the reminder should also fire on Saturday and Sunday.
  final bool weekendReminder;

  /// True if weekly summary notification is enabled (D-07, D-13).
  final bool weeklyNotificationEnabled;

  /// True if the user has opted into auto-pause (Phase 18, D-10). Default
  /// flipped to `true` in Phase 27 (UX-08) — auto-pause is now ON out of
  /// the box for fresh installs, and existing rows are explicitly
  /// backfilled to `true` by the v7 → v8 migration.
  final bool autoPauseEnabled;

  /// True once the first-run login wall has been cleared (Phase 20, D-01).
  /// False on a fresh install (no row) so the gate shows the login screen
  /// exactly once.
  final bool hasSeenOnboarding;

  /// Saved Home latitude (Phase 21, D-01). Null = not set. PII-adjacent —
  /// never log this coordinate (T-21-03).
  final double? homeLat;

  /// Saved Home longitude (Phase 21, D-01). Null = not set. PII-adjacent.
  final double? homeLng;

  /// Saved Office latitude (Phase 21, D-01). Null = not set. PII-adjacent.
  final double? officeLat;

  /// Saved Office longitude (Phase 21, D-01). Null = not set. PII-adjacent.
  final double? officeLng;

  /// Version-keyed backfill marker (Phase 26, D-03): "backfill done for
  /// payload schema v{N}". `0` = backfill has never run on this install.
  /// Compared against [kBackfillMarkerVersion] by the caller that decides
  /// whether the one-time re-sync for trips with breaks/edits should run.
  final int backfillMarkerVersion;

  /// CSV of page keys whose one-time guided tour has already been shown
  /// (Phase 27, UX-07 tour persistence scaffold). Empty string on a fresh
  /// install/row — see [seenTourKeys] for the parsed form. Prefer
  /// [seenTourKeys] over reading this raw CSV directly.
  final String seenTours;

  /// Parsed view of [seenTours]: the set of page keys whose tour has
  /// already been shown. Empty when [seenTours] is `''` (no tours seen
  /// yet).
  Set<String> get seenTourKeys =>
      seenTours.split(',').where((s) => s.isNotEmpty).toSet();
}

/// Data-access object for the single-row user_preferences table.
///
/// Enforces D-04 ("create on demand, no seed row"): reads return
/// hardcoded defaults if the row is absent; writes always target
/// `id = 1` via `insertOnConflictUpdate` so the first write creates
/// and subsequent writes update.
@DriftAccessor(tables: [UserPreferences])
class UserPreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$UserPreferencesDaoMixin {
  /// Bind the DAO to its parent `AppDatabase`.
  UserPreferencesDao(super.attachedDatabase);

  /// Read the user's preferences, or fall back to the hardcoded
  /// defaults if no row has ever been written (first app launch).
  ///
  /// D-04: this is the intended contract. Do not "fix" it by seeding
  /// the row in `AppDatabase.migration.onCreate` — that would race
  /// with first-run reads and complicate future schema upgrades.
  Future<UserPreferencesValue> getOrDefault() async {
    final row = await (select(
      userPreferences,
    )..where((p) => p.id.equals(_kUserPreferencesId))).getSingleOrNull();
    if (row == null) {
      return const UserPreferencesValue.defaults();
    }
    return UserPreferencesValue(
      userId: row.userId,
      darkMode: row.darkMode,
      morningCutoffHour: row.morningCutoffHour,
      eveningCutoffHour: row.eveningCutoffHour,
      reminderEnabled: row.reminderEnabled,
      reminderTime: row.reminderTime,
      weekendReminder: row.weekendReminder,
      weeklyNotificationEnabled: row.weeklyNotificationEnabled,
      autoPauseEnabled: row.autoPauseEnabled,
      hasSeenOnboarding: row.hasSeenOnboarding,
      homeLat: row.homeLat,
      homeLng: row.homeLng,
      officeLat: row.officeLat,
      officeLng: row.officeLng,
      backfillMarkerVersion: row.backfillMarkerVersion,
      seenTours: row.seenTours,
    );
  }

  /// Reactive stream of the user's preferences row.
  ///
  /// Emits [UserPreferencesValue.defaults()] when the row is absent (first
  /// launch). Uses `watchSingleOrNull` — not `watchSingle` — because the
  /// row is absent until the user first changes a setting (D-04 "no seed
  /// row" contract). `watchSingle` would emit an error for a missing row;
  /// `watchSingleOrNull` emits null which maps cleanly to defaults.
  ///
  /// See D-04 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
  Stream<UserPreferencesValue> watch() {
    return (select(
      userPreferences,
    )..where((p) => p.id.equals(_kUserPreferencesId))).watchSingleOrNull().map(
      (row) => row == null
          ? const UserPreferencesValue.defaults()
          : UserPreferencesValue(
              userId: row.userId,
              darkMode: row.darkMode,
              morningCutoffHour: row.morningCutoffHour,
              eveningCutoffHour: row.eveningCutoffHour,
              reminderEnabled: row.reminderEnabled,
              reminderTime: row.reminderTime,
              weekendReminder: row.weekendReminder,
              weeklyNotificationEnabled: row.weeklyNotificationEnabled,
              autoPauseEnabled: row.autoPauseEnabled,
              hasSeenOnboarding: row.hasSeenOnboarding,
              homeLat: row.homeLat,
              homeLng: row.homeLng,
              officeLat: row.officeLat,
              officeLng: row.officeLng,
              backfillMarkerVersion: row.backfillMarkerVersion,
              seenTours: row.seenTours,
            ),
    );
  }

  /// Rewrite the single user-preferences row's `userId` from
  /// [kDefaultUserId] to [newUserId]. Returns the number of rows
  /// changed (0 or 1).
  ///
  /// D-11 (Phase 9 auth): called by `AuthService.signIn()` inside a
  /// `db.transaction()` alongside `TripsDao.backfillUserId` so the
  /// two updates are atomic. This table holds at most one row (at
  /// `id = _kUserPreferencesId`) so the return value is at most 1.
  /// The caller keys off the *trips* count for the first-sign-in
  /// signal (D-12) — preferences count is returned here for symmetry.
  ///
  /// Pitfall 4 mitigation: the WHERE clause is set explicitly via
  /// `..where((p) => p.userId.equals(kDefaultUserId))`. Only rows
  /// with [kDefaultUserId] are touched; a row already carrying a real
  /// uid (from a previous sign-in) is untouched.
  /// Never use `update(userPreferences).replace(row)` for partial
  /// updates.
  Future<int> backfillUserId(String newUserId) {
    return (update(userPreferences)
          ..where((p) => p.userId.equals(kDefaultUserId)))
        .write(UserPreferencesCompanion(userId: Value(newUserId)));
  }

  /// Write [value] as the single preferences row. If no row exists the
  /// first call inserts it; subsequent calls update it in place. The
  /// `id` column is forced to `_kUserPreferencesId` so there is never
  /// a second row.
  Future<void> upsert(UserPreferencesValue value) {
    return into(userPreferences).insertOnConflictUpdate(
      UserPreferencesCompanion.insert(
        id: const Value<int>(_kUserPreferencesId),
        userId: Value<String>(value.userId),
        darkMode: Value<String>(value.darkMode),
        morningCutoffHour: Value<int>(value.morningCutoffHour),
        eveningCutoffHour: Value<int>(value.eveningCutoffHour),
        reminderEnabled: Value<bool>(value.reminderEnabled),
        reminderTime: Value<String?>(value.reminderTime),
        weekendReminder: Value<bool>(value.weekendReminder),
        weeklyNotificationEnabled: Value<bool>(value.weeklyNotificationEnabled),
        autoPauseEnabled: Value<bool>(value.autoPauseEnabled),
        hasSeenOnboarding: Value<bool>(value.hasSeenOnboarding),
        homeLat: Value<double?>(value.homeLat),
        homeLng: Value<double?>(value.homeLng),
        officeLat: Value<double?>(value.officeLat),
        officeLng: Value<double?>(value.officeLng),
        backfillMarkerVersion: Value<int>(value.backfillMarkerVersion),
        seenTours: Value<String>(value.seenTours),
      ),
    );
  }

  /// Set the first-run flag (D-05). Single-column upsert so the gate is
  /// stable across restarts. Targets the single row at `id = 1`; the first
  /// write CREATES it (a fresh install has no row per D-04, so a guest Skip
  /// must be able to create it), later writes update in place. All other
  /// columns take their table defaults — i.e. the guest default state
  /// (userId=local_user, darkMode=system, …) — consistent with
  /// `getOrDefault()`.
  ///
  /// The single positional bool reads clearly at every call site
  /// (`setHasSeenOnboarding(true)`); there is no second flag to confuse it
  /// with, so the named-parameter lint is intentionally suppressed here.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setHasSeenOnboarding(bool value) {
    return into(userPreferences).insertOnConflictUpdate(
      UserPreferencesCompanion.insert(
        id: const Value<int>(_kUserPreferencesId),
        hasSeenOnboarding: Value<bool>(value),
      ),
    );
  }

  /// Persist the user's Home anchor coordinate (Phase 21, LOC-01, D-12).
  ///
  /// Single-column upsert mirroring [setHasSeenOnboarding]: targets the single
  /// row at `id = 1`; the first write CREATES it (a fresh install has no row
  /// per D-04), later writes update only `home_lat`/`home_lng` in place. Every
  /// other column keeps its existing value (or table default on first write),
  /// so saving Home never disturbs Office, notification, or theme settings.
  ///
  /// PII note (T-21-02-01): [lat]/[lng] are PII-adjacent. They are written to
  /// local Drift only and must NEVER be logged or sent to any backend here.
  Future<void> setHomeLocation(double lat, double lng) {
    return into(userPreferences).insertOnConflictUpdate(
      UserPreferencesCompanion.insert(
        id: const Value<int>(_kUserPreferencesId),
        homeLat: Value<double?>(lat),
        homeLng: Value<double?>(lng),
      ),
    );
  }

  /// Persist the user's Office anchor coordinate (Phase 21, LOC-01, D-12).
  ///
  /// See [setHomeLocation] — identical single-row, single-pair upsert for the
  /// `office_lat`/`office_lng` columns. PII-adjacent (T-21-02-01): local-only,
  /// never logged.
  Future<void> setOfficeLocation(double lat, double lng) {
    return into(userPreferences).insertOnConflictUpdate(
      UserPreferencesCompanion.insert(
        id: const Value<int>(_kUserPreferencesId),
        officeLat: Value<double?>(lat),
        officeLng: Value<double?>(lng),
      ),
    );
  }

  /// Read the backfill marker version (Phase 26, D-03). `0` on a fresh DB
  /// (no row) — backfill has never run on this install. Compare the result
  /// against `kBackfillMarkerVersion` to decide whether the one-time
  /// re-sync for trips with breaks/edits should run.
  Future<int> getBackfillMarkerVersion() async {
    final value = await getOrDefault();
    return value.backfillMarkerVersion;
  }

  /// Set the backfill marker version (Phase 26, D-03). Single-column upsert
  /// mirroring [setHasSeenOnboarding]: targets the single row at `id = 1`;
  /// the first write CREATES it (a fresh install has no row per D-04), later
  /// writes update only `backfill_marker_version` in place. Every other
  /// column keeps its existing value (or table default on first write).
  Future<void> setBackfillMarkerVersion(int version) {
    return into(userPreferences).insertOnConflictUpdate(
      UserPreferencesCompanion.insert(
        id: const Value<int>(_kUserPreferencesId),
        backfillMarkerVersion: Value<int>(version),
      ),
    );
  }

  /// Mark the one-time guided tour for [pageKey] as seen (Phase 27, UX-07
  /// tour persistence scaffold). No-ops if [pageKey] is already present in
  /// the CSV (idempotent — a page's tour never re-triggers once seen or
  /// skipped).
  ///
  /// Single-column-style upsert mirroring [setHasSeenOnboarding]: targets
  /// the single row at `id = 1`; the first write CREATES it (a fresh
  /// install has no row per D-04), later writes update only `seen_tours`
  /// in place. Every other column keeps its existing value (or table
  /// default on first write).
  Future<void> markTourSeen(String pageKey) async {
    final current = await getOrDefault();
    if (current.seenTourKeys.contains(pageKey)) {
      return;
    }
    final updatedKeys = <String>[...current.seenTourKeys, pageKey];
    await into(userPreferences).insertOnConflictUpdate(
      UserPreferencesCompanion.insert(
        id: const Value<int>(_kUserPreferencesId),
        seenTours: Value<String>(updatedKeys.join(',')),
      ),
    );
  }
}
