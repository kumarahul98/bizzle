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
      autoPauseEnabled = false;

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

  /// True if the user has opted into auto-pause (Phase 18, D-10). Off by
  /// default so auto-pause is strictly opt-in.
  final bool autoPauseEnabled;
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
      ),
    );
  }
}
