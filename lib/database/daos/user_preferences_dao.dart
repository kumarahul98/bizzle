import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/user_preferences_table.dart';

part 'user_preferences_dao.g.dart';

/// The fixed primary key for the single user_preferences row. Drift
/// stores preferences as exactly one row at `id = 1`; callers must
/// never insert at a different id.
const int _kUserPreferencesId = 1;

/// Default direction cutoff hour (noon). Mirrors what plan 01-02's
/// `lib/config/constants.dart` will expose as `kDefaultDirectionCutoffHour`.
const int _kDefaultDirectionCutoffHour = 12;

/// Default owning user id placeholder. Mirrors `kDefaultUserId` from
/// the pending `lib/config/constants.dart`.
const String _kDefaultUserId = 'local_user';

/// Dark mode default. Mirrors `kDarkModeSystem` from pending
/// `lib/config/constants.dart`.
const String _kDarkModeSystem = 'system';

/// Plain Dart value type representing the user's preferences.
///
/// Distinct from `UserPreferencesRow` because the DAO must be able to
/// return a value object even when no row exists in the database — the
/// D-04 decision mandates "create on demand, no seed row" so
/// `getOrDefault()` constructs this from hardcoded defaults on first
/// read. A `UserPreferencesRow` cannot be returned in that case because
/// Drift rows represent actual persisted data.
class UserPreferencesValue {
  const UserPreferencesValue({
    required this.userId,
    required this.darkMode,
    required this.morningCutoffHour,
    required this.eveningCutoffHour,
    required this.reminderEnabled,
    required this.reminderTime,
    required this.weekendReminder,
  });

  /// The defaults used the first time the user launches the app —
  /// before the single row exists in the table (D-04).
  const UserPreferencesValue.defaults()
      : userId = _kDefaultUserId,
        darkMode = _kDarkModeSystem,
        morningCutoffHour = _kDefaultDirectionCutoffHour,
        eveningCutoffHour = _kDefaultDirectionCutoffHour,
        reminderEnabled = false,
        reminderTime = null,
        weekendReminder = false;

  final String userId;
  final String darkMode;
  final int morningCutoffHour;
  final int eveningCutoffHour;
  final bool reminderEnabled;
  final String? reminderTime;
  final bool weekendReminder;
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
  UserPreferencesDao(super.db);

  /// Read the user's preferences, or fall back to the hardcoded
  /// defaults if no row has ever been written (first app launch).
  ///
  /// D-04: this is the intended contract. Do not "fix" it by seeding
  /// the row in `AppDatabase.migration.onCreate` — that would race
  /// with first-run reads and complicate future schema upgrades.
  Future<UserPreferencesValue> getOrDefault() async {
    final row = await (select(userPreferences)
          ..where((p) => p.id.equals(_kUserPreferencesId)))
        .getSingleOrNull();
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
    );
  }

  /// Write [value] as the single preferences row. If no row exists the
  /// first call inserts it; subsequent calls update it in place. The
  /// `id` column is forced to `_kUserPreferencesId` so there is never
  /// a second row.
  Future<void> upsert(UserPreferencesValue value) {
    return into(userPreferences).insertOnConflictUpdate(
      UserPreferencesCompanion.insert(
        id: _kUserPreferencesId,
        userId: Value<String>(value.userId),
        darkMode: Value<String>(value.darkMode),
        morningCutoffHour: Value<int>(value.morningCutoffHour),
        eveningCutoffHour: Value<int>(value.eveningCutoffHour),
        reminderEnabled: Value<bool>(value.reminderEnabled),
        reminderTime: Value<String?>(value.reminderTime),
        weekendReminder: Value<bool>(value.weekendReminder),
      ),
    );
  }
}
