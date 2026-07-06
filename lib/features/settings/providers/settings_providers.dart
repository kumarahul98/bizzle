import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/notifications/notification_service.dart';

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

/// Reactive count of `pending` sync-queue rows (Phase 11, D-09).
///
/// The Settings cloud-sync status row reads this alongside `syncStatusProvider`
/// to render the "$N pending" subtitle. Derived from
/// `SyncQueueDao.watchPending()` so the row updates live as trips enqueue/drain.
/// Manual provider per the project-wide constraint (see
/// `lib/database/providers.dart`). Widget tests override it to script a count.
final StreamProvider<int> pendingSyncCountProvider = StreamProvider<int>(
  (ref) =>
      ref.watch(syncQueueDaoProvider).watchPending().map((rows) => rows.length),
  name: 'pendingSyncCountProvider',
);

/// Riverpod-managed [NotificationService] handle for Settings screen wiring.
///
/// Production callers (settings notification toggles, app startup) read this
/// to schedule / cancel the weekly summary and daily reminder alarms.
/// Widget tests override this with a fake to avoid platform-channel calls
/// from `flutter_local_notifications` (which crash on the test host).
final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>(
      (ref) => NotificationService(),
      name: 'notificationServiceProvider',
    );
