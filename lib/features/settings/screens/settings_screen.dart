import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/user_preferences_dao.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/settings/screens/location_picker_screen.dart';
import 'package:traevy/features/settings/services/reminder_suggestion_service.dart';
import 'package:traevy/features/settings/widgets/reminder_day_picker.dart';
import 'package:traevy/features/settings/widgets/reminder_suggestion_card.dart';
import 'package:traevy/features/settings/widgets/saved_location_tile.dart';
import 'package:traevy/features/settings/widgets/settings_row.dart';
import 'package:traevy/features/settings/widgets/settings_section.dart';
import 'package:traevy/features/tour/tour_config.dart';
import 'package:traevy/features/trips/screens/deleted_trips_screen.dart';
import 'package:traevy/shared/models/reminder_suggestion_state.dart';
import 'package:traevy/shared/utils/reminder_days.dart';
import 'package:traevy/shared/widgets/info_sheet.dart';
import 'package:traevy/shared/widgets/traevy_toggle.dart';

/// The Traevy-restyled Settings screen — four grouped sections inside
/// `MainShell`.
///
/// Sections (top → bottom): Commute, Recording, Notifications, Appearance.
/// The Account section moved out in Phase 32 (D-02) — those controls now live
/// behind the dashboard avatar in `showAccountSheet`, and deliberately have no
/// copy here: two Sign-out buttons or two Restore rows reading the same state
/// is a correctness hazard, not a convenience.
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
              KeyedSubtree(
                key: TourKeys.settingsLocations,
                child: const _LocationsSection(),
              ),
              _RecordingSection(prefs: prefs, ref: ref),
              _NotificationsSection(prefs: prefs, ref: ref),
              _AppearanceSection(prefs: prefs, ref: ref),
              const _DataSection(),
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
        // Phase 33 (D-01): the read-only cutoff row was deleted. Since
        // Phase 21 direction comes primarily from Home/Office geofences and
        // the trip detail screen lets the user fix a mislabel; a row that
        // only explained an invisible fallback and could not be changed
        // earned none of the space it took. morningCutoffHour still lives in
        // the schema at its default and keeps working as the silent fallback.
        //
        // Phase 18 (Plan 04, TRACK-10, D-10): real opt-in auto-pause toggle
        // bound to user_preferences.auto_pause_enabled. Phase 33 (D-05)
        // renames the label to match reality — the app never pauses on its
        // own, it asks — and adds an InfoIconButton explaining exactly that.
        KeyedSubtree(
          key: TourKeys.settingsAutoPause,
          child: SettingsRow(
            label: kSettingsAutoPauseLabelV2,
            subtitle: prefs.autoPauseEnabled
                ? kSettingsAutoPauseOnSubtitle
                : kSettingsAutoPauseOffSubtitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const InfoIconButton(
                  title: kAutoPauseInfoTitle,
                  body: kAutoPauseInfoBody,
                ),
                const SizedBox(width: 4),
                TraevyToggle(
                  value: prefs.autoPauseEnabled,
                  onChanged: (v) => unawaited(_toggleAutoPause(ref, prefs, v)),
                ),
              ],
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
        ? '$reminderTimeLabel · ${reminderDaysLabel(prefs.reminderDayNumbers)}'
        : 'OFF';

    // Phase 33 (D-04): the recalibration suggestion, surfaced two ways —
    // a dismissible card (below), and a permanent subtitle on the time row.
    final suggestion = ref.watch(reminderSuggestionProvider);
    final subtitle = suggestion == null
        ? reminderTimeLabel
        : '$kReminderSuggestionSubtitlePrefix${_formatReminderTime(suggestion)}';
    final showCard =
        suggestion != null &&
        const ReminderSuggestionService().shouldOffer(
          suggestion: suggestion,
          state: prefs.reminderSuggestionState,
          lastOfferedValue: prefs.reminderSuggestionValue,
        );

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
          subtitle: subtitle,
          onTap: () => unawaited(
            _pickReminderTime(context, ref, prefs, seed: suggestion),
          ),
        ),
        if (showCard)
          ReminderSuggestionCard(
            suggestion: suggestion,
            onAccept: () =>
                unawaited(_acceptSuggestion(ref, prefs, suggestion)),
            onDismiss: () =>
                unawaited(_dismissSuggestion(ref, prefs, suggestion)),
          ),
        ReminderDayPicker(
          selectedDays: prefs.reminderDayNumbers,
          onChanged: (days) => unawaited(_setReminderDays(ref, prefs, days)),
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

/// Data-management section (Phase 35, D-05): the Trash entry. A single row that
/// pushes the full-screen [DeletedTripsScreen] where soft-deleted trips can be
/// restored or permanently removed.
class _DataSection extends StatelessWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: kSettingsDataSectionTitle,
      children: <Widget>[
        SettingsRow(
          label: kTrashSettingsRowLabel,
          onTap: () => unawaited(
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const DeletedTripsScreen(),
              ),
            ),
          ),
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
///
/// When a recalibration suggestion is available it is passed as [seed]: the
/// picker opens on the suggested time rather than the 08:00 hardcode, so an
/// "Edit" from the suggestion lands the user on the value they were offered
/// (D-04). The current reminder time still wins if one is set.
Future<void> _pickReminderTime(
  BuildContext context,
  WidgetRef ref,
  UserPreferencesValue prefs, {
  String? seed,
}) async {
  // Parse the current reminderTime into a TimeOfDay for the picker's
  // initialTime; fall back to the suggestion, then to 08:00.
  final initial =
      _parseReminderTimeOfDay(prefs.reminderTime) ??
      _parseReminderTimeOfDay(seed) ??
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
        .scheduleReminder(hhMm: hhMm, days: prefs.reminderDayNumbers);
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
  String? reminderDays,
  ReminderSuggestionState? reminderSuggestionState,
  Object? reminderSuggestionValue = const _UnsetSentinel(),
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
  // Phase 33 (T-33-04): the three new reminder columns must be carried by
  // this helper from the commit that adds them, or the next unrelated
  // settings write silently resets the user's chosen days and re-offers a
  // suggestion they already dismissed.
  reminderDays: reminderDays ?? prefs.reminderDays,
  reminderSuggestionState:
      reminderSuggestionState ?? prefs.reminderSuggestionState,
  reminderSuggestionValue: reminderSuggestionValue is _UnsetSentinel
      ? prefs.reminderSuggestionValue
      : reminderSuggestionValue as String?,
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
        days: prefs.reminderDayNumbers,
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

/// Persist a new day selection and reschedule the reminder onto exactly
/// those days (Phase 33, D-02).
///
/// An empty [days] is a valid selection meaning "no reminders": it is written
/// through unchanged and `scheduleReminder` cancels every slot without
/// scheduling anything. It is deliberately NOT treated as "unset" and NOT
/// conflated with `reminderEnabled = false`.
Future<void> _setReminderDays(
  WidgetRef ref,
  UserPreferencesValue prefs,
  Set<int> days,
) async {
  await ref
      .read(userPreferencesDaoProvider)
      .upsert(_copyPrefs(prefs, reminderDays: encodeReminderDays(days)));
  if (!prefs.reminderEnabled || prefs.reminderTime == null) return;
  await ref
      .read(notificationServiceProvider)
      .scheduleReminder(hhMm: prefs.reminderTime!, days: days);
}

/// Accept the recalibration suggestion (Phase 33, D-04): adopt [suggestion] as
/// the reminder time and record it as accepted so it never re-prompts for the
/// same value. Reschedules immediately if the reminder is enabled.
Future<void> _acceptSuggestion(
  WidgetRef ref,
  UserPreferencesValue prefs,
  String suggestion,
) async {
  await ref
      .read(userPreferencesDaoProvider)
      .upsert(
        _copyPrefs(
          prefs,
          reminderTime: suggestion,
          reminderSuggestionState: ReminderSuggestionState.accepted,
          reminderSuggestionValue: suggestion,
        ),
      );
  if (prefs.reminderEnabled) {
    await ref
        .read(notificationServiceProvider)
        .scheduleReminder(hhMm: suggestion, days: prefs.reminderDayNumbers);
  }
}

/// Dismiss the recalibration suggestion (Phase 33, D-04). Records [suggestion]
/// as the dismissed value so the same time is remembered indefinitely and only
/// a materially different suggestion (> 20 min away) can re-surface the card
/// (T-33-05). Does NOT touch the reminder time.
Future<void> _dismissSuggestion(
  WidgetRef ref,
  UserPreferencesValue prefs,
  String suggestion,
) async {
  await ref
      .read(userPreferencesDaoProvider)
      .upsert(
        _copyPrefs(
          prefs,
          reminderSuggestionState: ReminderSuggestionState.dismissed,
          reminderSuggestionValue: suggestion,
        ),
      );
}
