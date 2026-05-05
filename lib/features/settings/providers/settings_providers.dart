import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/providers.dart';

/// Reactive stream of the user's preferences (single row, id = 1).
///
/// Manual provider — no @riverpod annotation per the project-wide constraint
/// documented in `lib/database/providers.dart` (analyzer version conflict
/// with riverpod_generator).
///
/// Emits [UserPreferencesValue.defaults()] when no row exists (first launch).
/// Downstream consumers: `TraevyApp` (for dynamic `ThemeMode`) and
/// `SettingsScreen` (to display and edit current settings).
///
/// See D-04 in `.planning/phases/07-polish-notifications/07-CONTEXT.md`.
final StreamProvider<UserPreferencesValue> userPreferenceProvider =
    StreamProvider<UserPreferencesValue>(
  (ref) => ref.watch(userPreferencesDaoProvider).watch(),
  name: 'userPreferenceProvider',
);
