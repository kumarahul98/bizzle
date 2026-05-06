import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/database.dart';
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
        if (value != null) unawaited(_setDarkMode(value));
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

  Future<void> _setDarkMode(String value) {
    return ref.read(userPreferencesDaoProvider).upsert(
          UserPreferencesValue(
            userId: prefs.userId,
            darkMode: value,
            morningCutoffHour: prefs.morningCutoffHour,
            eveningCutoffHour: prefs.eveningCutoffHour,
            reminderEnabled: prefs.reminderEnabled,
            reminderTime: prefs.reminderTime,
            weekendReminder: prefs.weekendReminder,
            weeklyNotificationEnabled: prefs.weeklyNotificationEnabled,
          ),
        );
  }
}

/// Notifications section: weekly summary toggle + reminder subsection.
///
/// Weekly summary toggle (D-07): schedules Sunday 6pm notification via
/// NotificationService.scheduleWeeklySummary on enable.
///
/// Reminder subsection (D-10): SwitchListTile enable/disable, time picker
/// ListTile (tap → showTimePicker), weekend SwitchListTile. Time row and
/// weekend toggle use AnimatedOpacity (0.38 disabled, 1.0 enabled, 200ms)
/// and enabled: reminderEnabled so they are non-interactive when off.
class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({required this.prefs, required this.ref});

  /// Current user preferences.
  final UserPreferencesValue prefs;

  /// Riverpod ref from the parent ConsumerWidget.
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final formattedTime = _formattedReminderTime();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionHeader(context, kSettingsNotificationsSectionTitle),
        SwitchListTile(
          title: const Text(kSettingsWeeklySummaryLabel),
          subtitle: const Text(kSettingsWeeklySummarySubtitle),
          value: prefs.weeklyNotificationEnabled,
          onChanged: (value) =>
              _toggleWeeklySummary(ref.read(userPreferencesDaoProvider), value),
        ),
        const Divider(indent: 16, endIndent: 16),
        SwitchListTile(
          title: const Text(kSettingsReminderLabel),
          value: prefs.reminderEnabled,
          onChanged: (value) =>
              _toggleReminder(ref.read(userPreferencesDaoProvider), value),
        ),
        AnimatedOpacity(
          opacity: prefs.reminderEnabled ? _kEnabledOpacity : _kDisabledOpacity,
          duration: _kOpacityDuration,
          child: Semantics(
            label: prefs.reminderEnabled
                ? 'Reminder time, currently $formattedTime, tap to change'
                : 'Reminder time, disabled',
            excludeSemantics: !prefs.reminderEnabled,
            child: ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text(kSettingsReminderTimeLabel),
              subtitle: Text(formattedTime),
              enabled: prefs.reminderEnabled,
              onTap: () => _pickTime(
                context,
                ref.read(userPreferencesDaoProvider),
              ),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: prefs.reminderEnabled ? _kEnabledOpacity : _kDisabledOpacity,
          duration: _kOpacityDuration,
          child: SwitchListTile(
            title: const Text(kSettingsWeekendReminderLabel),
            value: prefs.weekendReminder,
            onChanged: prefs.reminderEnabled
                ? (value) => _toggleWeekend(
                      ref.read(userPreferencesDaoProvider),
                      value,
                    )
                : null,
          ),
        ),
      ],
    );
  }

  /// Format the stored HH:mm string for display (e.g., '08:00' → '8:00 AM').
  String _formattedReminderTime() {
    final time = prefs.reminderTime;
    if (time == null) return '—';
    try {
      return DateFormat.jm().format(DateFormat('HH:mm').parse(time));
    } on FormatException {
      return time;
    }
  }

  Future<void> _toggleWeeklySummary(
    UserPreferencesDao dao,
    bool value,
  ) async {
    await dao.upsert(
      UserPreferencesValue(
        userId: prefs.userId,
        darkMode: prefs.darkMode,
        morningCutoffHour: prefs.morningCutoffHour,
        eveningCutoffHour: prefs.eveningCutoffHour,
        reminderEnabled: prefs.reminderEnabled,
        reminderTime: prefs.reminderTime,
        weekendReminder: prefs.weekendReminder,
        weeklyNotificationEnabled: value,
      ),
    );
    final service = NotificationService();
    if (value) {
      final db = AppDatabase();
      try {
        await service.scheduleWeeklySummary(db);
      } finally {
        await db.close();
      }
    } else {
      await service.cancelWeeklySummary();
    }
  }

  Future<void> _toggleReminder(UserPreferencesDao dao, bool value) async {
    await dao.upsert(
      UserPreferencesValue(
        userId: prefs.userId,
        darkMode: prefs.darkMode,
        morningCutoffHour: prefs.morningCutoffHour,
        eveningCutoffHour: prefs.eveningCutoffHour,
        reminderEnabled: value,
        reminderTime: prefs.reminderTime,
        weekendReminder: prefs.weekendReminder,
        weeklyNotificationEnabled: prefs.weeklyNotificationEnabled,
      ),
    );
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

  Future<void> _pickTime(BuildContext context, UserPreferencesDao dao) async {
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
    final hhMm =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    await dao.upsert(
      UserPreferencesValue(
        userId: prefs.userId,
        darkMode: prefs.darkMode,
        morningCutoffHour: prefs.morningCutoffHour,
        eveningCutoffHour: prefs.eveningCutoffHour,
        reminderEnabled: prefs.reminderEnabled,
        reminderTime: hhMm,
        weekendReminder: prefs.weekendReminder,
        weeklyNotificationEnabled: prefs.weeklyNotificationEnabled,
      ),
    );
    if (!prefs.reminderEnabled) return;
    await NotificationService().scheduleReminder(
      hhMm: hhMm,
      includeWeekends: prefs.weekendReminder,
    );
  }

  Future<void> _toggleWeekend(UserPreferencesDao dao, bool value) async {
    await dao.upsert(
      UserPreferencesValue(
        userId: prefs.userId,
        darkMode: prefs.darkMode,
        morningCutoffHour: prefs.morningCutoffHour,
        eveningCutoffHour: prefs.eveningCutoffHour,
        reminderEnabled: prefs.reminderEnabled,
        reminderTime: prefs.reminderTime,
        weekendReminder: value,
        weeklyNotificationEnabled: prefs.weeklyNotificationEnabled,
      ),
    );
    if (!prefs.reminderEnabled || prefs.reminderTime == null) return;
    await NotificationService().scheduleReminder(
      hhMm: prefs.reminderTime!,
      includeWeekends: value,
    );
  }
}
