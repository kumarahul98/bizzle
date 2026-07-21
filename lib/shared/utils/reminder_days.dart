/// Parsing and formatting for the `reminder_days` CSV (Phase 33, D-02).
///
/// The stored format is a comma-separated list of ISO-8601 weekday numbers
/// (Monday = 1 … Sunday = 7) — the same numbering `DateTime.weekday` uses, so
/// a parsed value can be compared against a `DateTime` with no conversion.
library;

import 'package:traevy/config/constants.dart';

/// Parse [csv] into the set of selected weekday numbers, ascending.
///
/// Defensive by contract (T-33-06): unparseable entries are ignored, values
/// outside 1–7 are dropped, and duplicates collapse. An empty or fully
/// invalid input yields an EMPTY set, which means "no reminders" — it must
/// never fall back to weekdays, because that would silently re-enable days
/// the user deselected.
Set<int> parseReminderDays(String csv) {
  final days = <int>{};
  for (final part in csv.split(',')) {
    final day = int.tryParse(part.trim());
    if (day == null) continue;
    if (day < kMinReminderWeekday || day > kMaxReminderWeekday) continue;
    days.add(day);
  }
  final sorted = days.toList()..sort();
  return sorted.toSet();
}

/// Encode [days] back into the stored CSV form, ascending and deduped.
String encodeReminderDays(Set<int> days) {
  final sorted =
      days
          .where((d) => d >= kMinReminderWeekday && d <= kMaxReminderWeekday)
          .toList()
        ..sort();
  return sorted.join(',');
}

/// Human-readable summary of [days] for the Settings subtitle.
///
/// Collapses the three common shapes to a word ("Every day", "Weekdays",
/// "Weekends") and otherwise lists the day names in week order. An empty
/// selection reads [kReminderDaysNoneLabel] — never "Weekdays".
String reminderDaysLabel(Set<int> days) {
  final selected = parseReminderDays(encodeReminderDays(days));
  if (selected.isEmpty) return kReminderDaysNoneLabel;
  if (selected.length == kMaxReminderWeekday) return kReminderDaysEveryDayLabel;
  if (setEqualsInts(selected, parseReminderDays(kDefaultReminderDays))) {
    return kReminderDaysWeekdaysLabel;
  }
  if (setEqualsInts(selected, <int>{DateTime.saturday, DateTime.sunday})) {
    return kReminderDaysWeekendsLabel;
  }
  return selected.map((d) => kReminderDayNames[d - 1]).join(', ');
}

/// True when [a] and [b] hold exactly the same weekday numbers.
///
/// A local helper rather than `package:collection` — the project has no
/// dependency on it, and this is the only set comparison in the feature.
bool setEqualsInts(Set<int> a, Set<int> b) {
  if (a.length != b.length) return false;
  for (final value in a) {
    if (!b.contains(value)) return false;
  }
  return true;
}
