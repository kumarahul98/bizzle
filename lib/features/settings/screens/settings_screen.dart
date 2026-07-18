import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/widgets/sign_in_sheet.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/settings/screens/location_picker_screen.dart';
import 'package:traevy/features/settings/widgets/account_row.dart';
import 'package:traevy/features/settings/widgets/cloud_sync_row.dart';
import 'package:traevy/features/settings/widgets/restore_row.dart';
import 'package:traevy/features/settings/widgets/saved_location_tile.dart';
import 'package:traevy/features/settings/widgets/settings_row.dart';
import 'package:traevy/features/settings/widgets/settings_section.dart';
import 'package:traevy/features/tour/tour_config.dart';
import 'package:traevy/shared/widgets/traevy_toggle.dart';

/// The Traevy-restyled Settings screen — four grouped sections inside
/// `MainShell`.
///
/// Sections (top → bottom): Account, Recording, Notifications, Appearance.
/// UX-02 (theme), UX-04 (weekly summary), UX-05 (daily reminder) wiring is
/// preserved end-to-end through the existing
/// `UserPreferencesDao.upsert` + `NotificationService` flows.
class SettingsScreen extends ConsumerWidget {
  /// Create the settings screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrefs = ref.watch(userPreferenceProvider);
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: asyncPrefs.when(
        data: (prefs) => SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  kSettingsAppBarTitle,
                  style: textTheme.titleLarge,
                ),
              ),
              const _AccountSection(),
              KeyedSubtree(
                key: TourKeys.settingsLocations,
                child: const _LocationsSection(),
              ),
              _RecordingSection(prefs: prefs, ref: ref),
              _NotificationsSection(prefs: prefs, ref: ref),
              _AppearanceSection(prefs: prefs, ref: ref),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(kSettingsErrorMessage, style: textTheme.bodyMedium),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

/// State-aware Account section for the Settings screen (D-07, AUTH-01).
///
/// Watches [authStateProvider] and switches on the sealed [AuthState]:
///   - [AuthSignedIn]: populated [AccountRow] + a functional "Sign out" row.
///   - [AuthGuest] / [AuthLoading]: a single tappable "Sign in to back up"
///     row that opens the sign-in bottom sheet.
///
/// Phase 11 (SYNC-03, D-09): the signed-in branch now also renders a live
/// cloud-sync status row ([CloudSyncRow]) and a Restore-from-cloud row
/// ([RestoreRow]) between the account header and Sign out. The guest branch is
/// unchanged — those rows require an account (and the Phase 11 sync endpoints).
class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    final rows = switch (auth) {
      AuthSignedIn(:final name, :final email) => <Widget>[
        AccountRow(
          name: name,
          email: email,
          initial: name.isNotEmpty
              ? name[0].toUpperCase()
              : kPlaceholderUserInitial,
        ),
        const CloudSyncRow(),
        const RestoreRow(),
        SettingsRow(
          label: kCopySettingsSignOut,
          dangerous: true,
          // FirebaseAuth.signOut() → authStateChanges emits null → the
          // section rebuilds into the guest path above.
          onTap: () => unawaited(ref.read(authServiceProvider).signOut()),
        ),
      ],
      // Guest or still loading — single CTA opens the sign-in sheet. No
      // cloud/sign-out rows: they require an account (and Phase 11 sync).
      _ => <Widget>[
        SettingsRow(
          label: kCopySettingsGuestSignIn,
          // showSignInSheet handles its own async lifecycle.
          onTap: () => showSignInSheet(context),
        ),
      ],
    };

    return SettingsSection(
      title: kSettingsAccountSectionTitle,
      children: rows,
    );
  }
}

/// Commute-anchor section (Phase 21, LOC-01): the Home and Office location
/// rows. Each [SavedLocationTile] reflects the saved coord (or "Not set") and
/// opens the full-screen map picker for that slot on tap. Purely additive —
/// with nothing set both rows simply read [kCopyLocationNotSet].
class _LocationsSection extends StatelessWidget {
  const _LocationsSection();

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: kSettingsLocationsSectionTitle,
      children: <Widget>[
        SavedLocationTile(
          isHome: true,
          onTap: () => _openPicker(context, isHome: true),
        ),
        SavedLocationTile(
          isHome: false,
          onTap: () => _openPicker(context, isHome: false),
        ),
      ],
    );
  }

  void _openPicker(BuildContext context, {required bool isHome}) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LocationPickerScreen(isHome: isHome),
        ),
      ),
    );
  }
}

class _RecordingSection extends StatelessWidget {
  const _RecordingSection({required this.prefs, required this.ref});
  final UserPreferencesValue prefs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Recording',
      children: <Widget>[
        SettingsRow(
          label: 'Cutoff "to office"',
          subtitle:
              'Before ${prefs.morningCutoffHour.toString().padLeft(2, '0')}:00',
          // Wired in a future plan — the settings notifier does not yet
          // expose cutoff updates. Rendered without onTap so no chevron
          // is shown.
        ),
        // Phase 18 (Plan 04, TRACK-10, D-10): real opt-in auto-pause toggle
        // bound to user_preferences.auto_pause_enabled (default OFF). No
        // notification side-effect — flipping it only upserts the preference;
        // the service-side detector reads the gate live via the UI isolate.
        KeyedSubtree(
          key: TourKeys.settingsAutoPause,
          child: SettingsRow(
            label: kSettingsAutoPauseLabel,
            subtitle: prefs.autoPauseEnabled
                ? kSettingsAutoPauseOnSubtitle
                : kSettingsAutoPauseOffSubtitle,
            trailing: TraevyToggle(
              value: prefs.autoPauseEnabled,
              onChanged: (v) => unawaited(_toggleAutoPause(ref, prefs, v)),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({required this.prefs, required this.ref});
  final UserPreferencesValue prefs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final reminderTimeLabel = _formatReminderTime(prefs.reminderTime);
    final reminderSubtitle = prefs.reminderEnabled
        ? '$reminderTimeLabel · weekdays'
        : 'OFF';
    return SettingsSection(
      title: 'Notifications',
      children: <Widget>[
        SettingsRow(
          label: kSettingsReminderLabel,
          subtitle: reminderSubtitle,
          trailing: TraevyToggle(
            value: prefs.reminderEnabled,
            onChanged: (v) => unawaited(_toggleReminder(ref, prefs, v)),
          ),
        ),
        SettingsRow(
          label: kSettingsReminderTimeLabel,
          subtitle: reminderTimeLabel,
          onTap: () => unawaited(_pickReminderTime(context, ref, prefs)),
        ),
        SettingsRow(
          label: kSettingsWeekendReminderLabel,
          trailing: TraevyToggle(
            value: prefs.weekendReminder,
            onChanged: (v) => unawaited(_toggleWeekend(ref, prefs, v)),
          ),
        ),
        SettingsRow(
          label: kSettingsWeeklySummaryLabel,
          subtitle: kSettingsWeeklySummarySubtitle,
          trailing: TraevyToggle(
            value: prefs.weeklyNotificationEnabled,
            onChanged: (v) => unawaited(_toggleWeeklySummary(ref, prefs, v)),
          ),
        ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.prefs, required this.ref});
  final UserPreferencesValue prefs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Appearance',
      children: <Widget>[
        SettingsRow(
          label: 'Theme',
          subtitle: _themeLabel(prefs.darkMode),
          onTap: () async {
            final picked = await _openThemePicker(context, prefs.darkMode);
            if (picked == null) return;
            if (picked == prefs.darkMode) return;
            await ref
                .read(userPreferencesDaoProvider)
                .upsert(_copyPrefs(prefs, darkMode: picked));
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Theme picker bottom sheet
// ---------------------------------------------------------------------------

Future<String?> _openThemePicker(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    showDragHandle: true,
    builder: (sheetCtx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SettingsRow(
              label: 'System',
              onTap: () => Navigator.of(sheetCtx).pop(kDarkModeSystem),
            ),
            SettingsRow(
              label: 'Light',
              onTap: () => Navigator.of(sheetCtx).pop(kDarkModeLight),
            ),
            SettingsRow(
              label: 'Dark',
              onTap: () => Navigator.of(sheetCtx).pop(kDarkModeDark),
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Reminder time picker
// ---------------------------------------------------------------------------

/// Open the system time picker and persist the chosen time as an HH:mm string.
///
/// If the user dismisses without picking, the existing reminder time value in
/// the DB is unchanged. If a time is picked and the reminder is currently
/// enabled, the reminder alarm is rescheduled immediately — no need for the
/// user to re-toggle the switch.
Future<void> _pickReminderTime(
  BuildContext context,
  WidgetRef ref,
  UserPreferencesValue prefs,
) async {
  // Parse the current reminderTime into a TimeOfDay for the picker's
  // initialTime; fall back to 08:00 when no time is set yet.
  final initial =
      _parseReminderTimeOfDay(prefs.reminderTime) ??
      const TimeOfDay(hour: 8, minute: 0);

  final picked = await showTimePicker(
    context: context,
    initialTime: initial,
    helpText: kSettingsReminderTimeLabel,
  );
  if (picked == null) return;

  final hhMm =
      '${picked.hour.toString().padLeft(2, '0')}:'
      '${picked.minute.toString().padLeft(2, '0')}';

  await ref
      .read(userPreferencesDaoProvider)
      .upsert(_copyPrefs(prefs, reminderTime: hhMm));

  // If the reminder is already enabled, reschedule it with the new time.
  if (prefs.reminderEnabled) {
    await ref
        .read(notificationServiceProvider)
        .scheduleReminder(hhMm: hhMm, includeWeekends: prefs.weekendReminder);
  }
}

/// Parse a stored HH:mm string into a [TimeOfDay], returning null on failure.
TimeOfDay? _parseReminderTimeOfDay(String? hhMm) {
  if (hhMm == null) return null;
  final parts = hhMm.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

// ---------------------------------------------------------------------------
// Helpers — copy + format
// ---------------------------------------------------------------------------

String _themeLabel(String mode) {
  if (mode.isEmpty) return mode;
  return mode[0].toUpperCase() + mode.substring(1);
}

String _formatReminderTime(String? time) {
  if (time == null) return '—';
  try {
    return DateFormat.jm().format(DateFormat('HH:mm').parse(time));
  } on FormatException {
    return time;
  }
}

/// Build a copy of [prefs] with every field explicit; named params override
/// specific fields. Centralised so every upsert call provides every column,
/// preventing accidental zeroing (T-07-04-01 mitigation, carried from Plan 02).
///
/// [reminderTime] supports three states:
///   - omitted (sentinel default): keep existing [reminderTime] unchanged.
///   - non-null String: set to that value.
///   - explicit `null`: clear to null.
UserPreferencesValue _copyPrefs(
  UserPreferencesValue prefs, {
  String? darkMode,
  bool? reminderEnabled,
  Object? reminderTime = const _UnsetSentinel(),
  bool? weekendReminder,
  bool? weeklyNotificationEnabled,
  bool? autoPauseEnabled,
}) => UserPreferencesValue(
  userId: prefs.userId,
  darkMode: darkMode ?? prefs.darkMode,
  morningCutoffHour: prefs.morningCutoffHour,
  eveningCutoffHour: prefs.eveningCutoffHour,
  reminderEnabled: reminderEnabled ?? prefs.reminderEnabled,
  reminderTime: reminderTime is _UnsetSentinel
      ? prefs.reminderTime
      : reminderTime as String?,
  weekendReminder: weekendReminder ?? prefs.weekendReminder,
  weeklyNotificationEnabled:
      weeklyNotificationEnabled ?? prefs.weeklyNotificationEnabled,
  autoPauseEnabled: autoPauseEnabled ?? prefs.autoPauseEnabled,
  // Preserve the first-run flag (Phase 20) — a settings write must never
  // reset it and re-trigger the login wall.
  hasSeenOnboarding: prefs.hasSeenOnboarding,
  // Preserve the Phase 21 Home/Office coords — a generic settings write must
  // never zero them. Plan 02 (picker) adds the dedicated setters that mutate
  // these; this copy only carries them through unchanged.
  homeLat: prefs.homeLat,
  homeLng: prefs.homeLng,
  officeLat: prefs.officeLat,
  officeLng: prefs.officeLng,
  // Preserve the Phase 26 backfill marker — a generic settings write must
  // never reset it, or the one-time re-sync would appear to "never have
  // run" and retrigger unnecessarily.
  backfillMarkerVersion: prefs.backfillMarkerVersion,
);

class _UnsetSentinel {
  const _UnsetSentinel();
}

// ---------------------------------------------------------------------------
// Notification side-effects — identical wiring to Phase 7 (UX-04, UX-05)
// ---------------------------------------------------------------------------

Future<void> _toggleWeeklySummary(
  WidgetRef ref,
  UserPreferencesValue prefs,
  bool value,
) async {
  await ref
      .read(userPreferencesDaoProvider)
      .upsert(_copyPrefs(prefs, weeklyNotificationEnabled: value));
  final service = ref.read(notificationServiceProvider);
  if (value) {
    final db = ref.read(appDatabaseProvider);
    await service.scheduleWeeklySummary(db);
  } else {
    await service.cancelWeeklySummary();
  }
}

Future<void> _toggleReminder(
  WidgetRef ref,
  UserPreferencesValue prefs,
  bool value,
) async {
  await ref
      .read(userPreferencesDaoProvider)
      .upsert(_copyPrefs(prefs, reminderEnabled: value));
  final service = ref.read(notificationServiceProvider);
  if (value) {
    // IOS-10 D-07 edge: the user explicitly opts in — always request the iOS
    // notification permission, regardless of whether a reminder time is set
    // yet. forceRequest bypasses the 7-day anchor check so the system dialog
    // fires on this explicit user action.
    await service.maybeRequestNotificationPermissionForUsage(
      forceRequest: true,
    );
    // Only schedule if a time has been chosen. The reminder row shows "—" as
    // the subtitle when no time is set, signalling the user must also pick a
    // time. Scheduling with a null/missing time would silently no-op anyway
    // (NotificationService.scheduleReminder guards malformed input).
    if (prefs.reminderTime != null) {
      await service.scheduleReminder(
        hhMm: prefs.reminderTime!,
        includeWeekends: prefs.weekendReminder,
      );
    }
  } else {
    await service.cancelReminder();
  }
}

/// Persist the opt-in auto-pause preference (Phase 18 Plan 04, TRACK-10,
/// D-10). Unlike the notification toggles this has NO side-effect — auto-pause
/// has no scheduled alarm; the service-side detector reads the flag live via
/// the UI isolate, so flipping it only needs the upsert.
Future<void> _toggleAutoPause(
  WidgetRef ref,
  UserPreferencesValue prefs,
  bool value,
) async {
  await ref
      .read(userPreferencesDaoProvider)
      .upsert(_copyPrefs(prefs, autoPauseEnabled: value));
}

Future<void> _toggleWeekend(
  WidgetRef ref,
  UserPreferencesValue prefs,
  bool value,
) async {
  await ref
      .read(userPreferencesDaoProvider)
      .upsert(_copyPrefs(prefs, weekendReminder: value));
  if (!prefs.reminderEnabled || prefs.reminderTime == null) return;
  await ref
      .read(notificationServiceProvider)
      .scheduleReminder(
        hhMm: prefs.reminderTime!,
        includeWeekends: value,
      );
}
