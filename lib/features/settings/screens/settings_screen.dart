import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/settings/widgets/account_row.dart';
import 'package:traevy/features/settings/widgets/settings_row.dart';
import 'package:traevy/features/settings/widgets/settings_section.dart';
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
              _AccountSection(prefs: prefs),
              _RecordingSection(prefs: prefs),
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

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.prefs});
  final UserPreferencesValue prefs;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Account',
      children: <Widget>[
        const AccountRow(
          name: kPlaceholderUserName,
          email: 'you@traevy.app',
          initial: kPlaceholderUserInitial,
        ),
        const SettingsRow(
          label: 'Cloud sync',
          subtitle: 'OFF — sign in to enable',
          // Wired in Phase 9 when authentication ships.
          trailing: TraevyToggle(value: false, onChanged: _noopBool),
        ),
        SettingsRow(
          label: 'Restore from cloud',
          // Wired in Phase 11 when restore endpoint ships.
          onTap: () => _showComingSoon(context, 'Restore'),
        ),
        const SettingsRow(
          label: 'Sign out',
          dangerous: true,
          // Wired in Phase 9 when authentication ships.
        ),
      ],
    );
  }
}

class _RecordingSection extends StatelessWidget {
  const _RecordingSection({required this.prefs});
  final UserPreferencesValue prefs;

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
        const SettingsRow(
          label: 'Auto-pause on stop',
          // UserPreferences does not yet carry this flag — placeholder
          // until Phase 9 backlog wires it. Toggle is visual-only.
          trailing: TraevyToggle(value: true, onChanged: _noopBool),
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
          label: 'Daily reminder',
          subtitle: reminderSubtitle,
          trailing: TraevyToggle(
            value: prefs.reminderEnabled,
            onChanged: (v) => unawaited(_toggleReminder(ref, prefs, v)),
          ),
        ),
        SettingsRow(
          label: 'Include weekends',
          trailing: TraevyToggle(
            value: prefs.weekendReminder,
            onChanged: (v) => unawaited(_toggleWeekend(ref, prefs, v)),
          ),
        ),
        SettingsRow(
          label: 'Weekly summary',
          subtitle: 'Sunday evening',
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

void _showComingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label — available after sign-in')),
  );
}

/// No-op handler for visual-only placeholder toggles (Cloud sync,
/// Auto-pause on stop). Lifted to a top-level function so the enclosing
/// row can be declared `const`.
void _noopBool(bool _) {}

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
}) =>
    UserPreferencesValue(
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
  if (value && prefs.reminderTime != null) {
    await service.scheduleReminder(
      hhMm: prefs.reminderTime!,
      includeWeekends: prefs.weekendReminder,
    );
  } else {
    await service.cancelReminder();
  }
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
  await ref.read(notificationServiceProvider).scheduleReminder(
        hhMm: prefs.reminderTime!,
        includeWeekends: value,
      );
}
