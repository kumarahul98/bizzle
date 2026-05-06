import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/notifications/notification_service.dart';

const double _kSectionHeaderPaddingLeft = 16;
const double _kSectionHeaderPaddingTop = 16;
const double _kSectionHeaderPaddingRight = 16;
const double _kSectionHeaderPaddingBottom = 8;
const double _kBottomPadding = 32;
const Duration _kOpacityDuration = Duration(milliseconds: 200);
const double _kDisabledOpacity = 0.38;
const double _kEnabledOpacity = 1;

/// The settings screen — single scrollable screen with Appearance and
/// Notifications sections (UX-02, UX-04, UX-05).
///
/// Entry point: gear IconButton in DashboardScreen AppBar (D-01).
/// Layout: Appearance section (3 RadioListTile rows) + Notifications section
/// (weekly summary toggle + reminder subsection).
class SettingsScreen extends ConsumerWidget {
  /// Create the settings screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrefs = ref.watch(userPreferenceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(kSettingsAppBarTitle)),
      body: asyncPrefs.when(
        data: (prefs) => SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: _kBottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _AppearanceSection(prefs: prefs, ref: ref),
              const Divider(),
              _NotificationsSection(prefs: prefs, ref: ref),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => const Center(child: Text(kSettingsErrorMessage)),
      ),
    );
  }
}

/// Section header widget following Material 3 settings-page convention.
///
/// Renders [label] in titleSmall weight colored primary with 16pt horizontal
/// padding and 16pt top / 8pt bottom padding.
Widget _sectionHeader(BuildContext context, String label) {
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(
      _kSectionHeaderPaddingLeft,
      _kSectionHeaderPaddingTop,
      _kSectionHeaderPaddingRight,
      _kSectionHeaderPaddingBottom,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
          ),
    ),
  );
}

/// Build a copy of [prefs] with every field explicit, with named params
/// overriding specific fields.
///
/// All upsert callers pass every field to prevent accidental zeroing
/// (T-07-04-01 mitigation). This helper centralises the copy pattern.
UserPreferencesValue _copyPrefs(
  UserPreferencesValue prefs, {
  String? darkMode,
  bool? reminderEnabled,
  String? reminderTime,
  bool? weekendReminder,
  bool? weeklyNotificationEnabled,
}) =>
    UserPreferencesValue(
      userId: prefs.userId,
      darkMode: darkMode ?? prefs.darkMode,
      morningCutoffHour: prefs.morningCutoffHour,
      eveningCutoffHour: prefs.eveningCutoffHour,
      reminderEnabled: reminderEnabled ?? prefs.reminderEnabled,
      reminderTime: reminderTime ?? prefs.reminderTime,
      weekendReminder: weekendReminder ?? prefs.weekendReminder,
      weeklyNotificationEnabled:
          weeklyNotificationEnabled ?? prefs.weeklyNotificationEnabled,
    );

/// Appearance section: 3 RadioListTile rows for System/Light/Dark theme.
///
/// Tapping a row calls UserPreferencesDao.upsert immediately — theme
/// change propagates via userPreferenceProvider to TraevyApp.themeMode
/// with no app restart required (D-04).
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.prefs, required this.ref});

  /// Current user preferences.
  final UserPreferencesValue prefs;

  /// Riverpod ref from the parent ConsumerWidget.
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: prefs.darkMode,
      onChanged: (value) {
        if (value != null) {
          unawaited(
            ref.read(userPreferencesDaoProvider).upsert(
                  _copyPrefs(prefs, darkMode: value),
                ),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionHeader(context, kSettingsAppearanceSectionTitle),
          const RadioListTile<String>(
            title: Text(kSettingsDarkModeSystemLabel),
            value: kDarkModeSystem,
          ),
          const RadioListTile<String>(
            title: Text(kSettingsDarkModeLightLabel),
            value: kDarkModeLight,
          ),
          const RadioListTile<String>(
            title: Text(kSettingsDarkModeDarkLabel),
            value: kDarkModeDark,
          ),
        ],
      ),
    );
  }
}

/// Notifications section: weekly summary toggle + reminder subsection.
///
/// Weekly summary toggle (D-07): schedules Sunday 6pm notification via
/// NotificationService.scheduleWeeklySummary on enable.
///
/// Reminder subsection (D-10): delegated to [_ReminderRows].
class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({required this.prefs, required this.ref});

  /// Current user preferences.
  final UserPreferencesValue prefs;

  /// Riverpod ref from the parent ConsumerWidget.
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionHeader(context, kSettingsNotificationsSectionTitle),
        SwitchListTile(
          title: const Text(kSettingsWeeklySummaryLabel),
          subtitle: const Text(kSettingsWeeklySummarySubtitle),
          value: prefs.weeklyNotificationEnabled,
          onChanged: (value) =>
              unawaited(_toggleWeeklySummary(ref, prefs, value)),
        ),
        const Divider(indent: 16, endIndent: 16),
        SwitchListTile(
          title: const Text(kSettingsReminderLabel),
          value: prefs.reminderEnabled,
          onChanged: (value) =>
              unawaited(_toggleReminder(ref, prefs, value)),
        ),
        _ReminderRows(prefs: prefs, ref: ref),
      ],
    );
  }
}

/// Reminder time row and weekend toggle, with AnimatedOpacity transitions.
///
/// Both rows remain in the widget tree (no Visibility) so layout height
/// stays consistent when reminder is toggled on/off (D-10 UI-SPEC).
/// Opacity 0.38 matches Material 3 disabled-state spec.
class _ReminderRows extends StatelessWidget {
  const _ReminderRows({required this.prefs, required this.ref});

  /// Current user preferences.
  final UserPreferencesValue prefs;

  /// Riverpod ref from the parent ConsumerWidget.
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final formattedTime = _formatReminderTime(prefs.reminderTime);
    final enabled = prefs.reminderEnabled;
    return Column(
      children: <Widget>[
        AnimatedOpacity(
          opacity: enabled ? _kEnabledOpacity : _kDisabledOpacity,
          duration: _kOpacityDuration,
          child: Semantics(
            label: enabled
                ? 'Reminder time, currently $formattedTime, tap to change'
                : 'Reminder time, disabled',
            excludeSemantics: !enabled,
            child: ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text(kSettingsReminderTimeLabel),
              subtitle: Text(formattedTime),
              enabled: enabled,
              onTap: () => unawaited(_pickTime(context, ref, prefs)),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: enabled ? _kEnabledOpacity : _kDisabledOpacity,
          duration: _kOpacityDuration,
          child: SwitchListTile(
            title: const Text(kSettingsWeekendReminderLabel),
            value: prefs.weekendReminder,
            onChanged: enabled
                ? (value) => unawaited(_toggleWeekend(ref, prefs, value))
                : null,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Action helpers (top-level so they are shared without subclassing)
// ---------------------------------------------------------------------------

/// Format HH:mm string for display (e.g., '08:00' → '8:00 AM').
String _formatReminderTime(String? time) {
  if (time == null) return '—';
  try {
    return DateFormat.jm().format(DateFormat('HH:mm').parse(time));
  } on FormatException {
    return time;
  }
}

Future<void> _toggleWeeklySummary(
  WidgetRef ref,
  UserPreferencesValue prefs,
  bool value,
) async {
  await ref
      .read(userPreferencesDaoProvider)
      .upsert(_copyPrefs(prefs, weeklyNotificationEnabled: value));
  final service = NotificationService();
  if (value) {
    // Use the Riverpod-managed DB instance — no second connection opened.
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
  final service = NotificationService();
  if (value && prefs.reminderTime != null) {
    await service.scheduleReminder(
      hhMm: prefs.reminderTime!,
      includeWeekends: prefs.weekendReminder,
    );
  } else {
    await service.cancelReminder();
  }
}

Future<void> _pickTime(
  BuildContext context,
  WidgetRef ref,
  UserPreferencesValue prefs,
) async {
  final parts = (prefs.reminderTime ?? '08:00').split(':');
  final initial = TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 8,
    minute: int.tryParse(parts[1]) ?? 0,
  );
  if (!context.mounted) return;
  final picked = await showTimePicker(
    context: context,
    initialTime: initial,
  );
  if (picked == null) return;
  final hhMm = '${picked.hour.toString().padLeft(2, '0')}:'
      '${picked.minute.toString().padLeft(2, '0')}';
  await ref
      .read(userPreferencesDaoProvider)
      .upsert(_copyPrefs(prefs, reminderTime: hhMm));
  if (!prefs.reminderEnabled) return;
  await NotificationService().scheduleReminder(
    hhMm: hhMm,
    includeWeekends: prefs.weekendReminder,
  );
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
  await NotificationService().scheduleReminder(
    hhMm: prefs.reminderTime!,
    includeWeekends: value,
  );
}
