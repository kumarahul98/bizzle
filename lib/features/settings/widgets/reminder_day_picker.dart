import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/shared/utils/reminder_days.dart';

const double _kDaySize = 40;
const double _kRowVerticalPadding = 14;

/// A Mon–Sun day-of-week selector for the daily reminder (Phase 33, D-02).
///
/// Replaces the old "Include weekends" boolean. Each day is an independent
/// toggle; [onChanged] receives the full new selection (ISO-8601 weekday
/// numbers, Monday = 1). An empty selection is valid and means "no reminders"
/// — it is emitted as-is and never silently coerced back to weekdays.
class ReminderDayPicker extends StatelessWidget {
  /// Create a day picker reflecting [selectedDays] (weekday numbers 1–7).
  const ReminderDayPicker({
    required this.selectedDays,
    required this.onChanged,
    super.key,
  });

  /// Currently selected weekday numbers (Monday = 1 … Sunday = 7).
  final Set<int> selectedDays;

  /// Called with the complete new selection whenever a day is tapped.
  final ValueChanged<Set<int>> onChanged;

  void _toggle(int weekday) {
    final next = <int>{...selectedDays};
    if (!next.remove(weekday)) next.add(weekday);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: _kRowVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            kSettingsReminderDaysLabel,
            style: TraevyFonts.ui(
              size: 14,
              weight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reminderDaysLabel(selectedDays),
            style: TraevyFonts.mono(size: 12, color: tokens.textDim),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (
                var weekday = kMinReminderWeekday;
                weekday <= kMaxReminderWeekday;
                weekday++
              )
                _DayDot(
                  weekday: weekday,
                  selected: selectedDays.contains(weekday),
                  onTap: () => _toggle(weekday),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single circular day toggle inside [ReminderDayPicker].
class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.weekday,
    required this.selected,
    required this.onTap,
  });

  final int weekday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    // The knob on TraevyToggle is white on the same `moving` green, so a
    // selected day reuses white for contrast rather than inventing a token.
    const onMoving = Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: '$kReminderDaySemanticPrefix${kReminderDayNames[weekday - 1]}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: _kDaySize,
          height: _kDaySize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? tokens.moving : Colors.transparent,
            border: Border.all(
              color: selected ? tokens.moving : tokens.borderStr,
            ),
          ),
          child: Text(
            kReminderDayShortLabels[weekday - 1],
            style: TraevyFonts.ui(
              size: 13,
              weight: FontWeight.w600,
              color: selected ? onMoving : tokens.textDim,
            ),
          ),
        ),
      ),
    );
  }
}
