import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/shared/models/reminder_suggestion_state.dart';

/// Derives a suggested reminder time from when the user actually leaves for
/// work (Phase 33, D-04).
///
/// Pure logic, no I/O: callers pass the already-loaded trips and the current
/// suggestion state, and this returns what — if anything — to show. That keeps
/// it exhaustively unit-testable and off the hot trip-save path (the query
/// runs on settings-screen open, D-04).
///
/// The rules, all from D-04:
///   * Consider only `to_office`, non-manual (GPS) trips within the last
///     [kReminderSuggestionWindowDays] days.
///   * Suggest nothing below [kReminderSuggestionMinTrips] qualifying trips —
///     a handful of commutes is not a pattern, and a wrong first impression
///     destroys trust in the feature.
///   * Use the MEDIAN local start minute-of-day, not the mean: one 3am airport
///     run must not drag an n=5 sample by half an hour.
///   * Suggest [kReminderSuggestionLeadMinutes] before that median, rounded
///     DOWN to [kReminderSuggestionRoundingMinutes], wrapping below midnight.
///   * Re-offer only when a freshly computed suggestion differs from the last
///     offered value by strictly more than
///     [kReminderSuggestionReofferDeltaMinutes] — a dismissal is remembered
///     indefinitely for its value (T-33-05).
class ReminderSuggestionService {
  /// Create a stateless suggestion service.
  const ReminderSuggestionService();

  /// Compute the raw suggested time as `HH:mm`, or null when there are fewer
  /// than [kReminderSuggestionMinTrips] qualifying trips.
  ///
  /// [trips] is any trip list (typically `watchAllSummaries().first`); it is
  /// filtered here. [now] is injectable so the 28-day window is testable.
  String? computeSuggestion(List<TripSummary> trips, {required DateTime now}) {
    final windowStart = now.subtract(
      const Duration(days: kReminderSuggestionWindowDays),
    );

    final startMinutes = <int>[];
    for (final trip in trips) {
      if (trip.isManualEntry) continue; // typed, not observed (D-04)
      if (trip.direction != kDirectionToOffice) continue; // outbound only
      final localStart = trip.startTime.toLocal();
      if (localStart.isBefore(windowStart)) continue; // older than 28 days
      if (localStart.isAfter(now)) continue; // guard clock skew / future rows
      startMinutes.add(localStart.hour * 60 + localStart.minute);
    }

    if (startMinutes.length < kReminderSuggestionMinTrips) return null;

    final median = _medianMinuteOfDay(startMinutes);
    final suggestedMinute = _applyLeadAndRounding(median);
    return _formatMinuteOfDay(suggestedMinute);
  }

  /// Whether [suggestion] should be surfaced given the last-offered value and
  /// the current [state] (T-33-05).
  ///
  /// A null [suggestion] (too few trips) is never shown. If nothing was ever
  /// offered, any suggestion shows. Otherwise the suggestion only re-surfaces
  /// when it moves more than [kReminderSuggestionReofferDeltaMinutes] from the
  /// last offered value — so a three-minute drift a month later never nags,
  /// but a genuinely different routine does.
  bool shouldOffer({
    required String? suggestion,
    required ReminderSuggestionState state,
    required String? lastOfferedValue,
  }) {
    if (suggestion == null) return false;
    if (state == ReminderSuggestionState.none || lastOfferedValue == null) {
      return true;
    }
    final delta = _circularDeltaMinutes(
      _parseMinuteOfDay(suggestion),
      _parseMinuteOfDay(lastOfferedValue),
    );
    return delta > kReminderSuggestionReofferDeltaMinutes;
  }

  /// Median minute-of-day. For an even count this averages the two central
  /// values (floored) rather than picking one arbitrarily; for an odd count it
  /// is the middle value. Operates on minutes-of-day, so it is stable for the
  /// normal case where every commute starts in the same morning band — the
  /// midnight-wrap concern only affects the LEAD subtraction, not this median.
  int _medianMinuteOfDay(List<int> minutes) {
    final sorted = [...minutes]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) ~/ 2;
  }

  /// Subtract the lead, round DOWN to the rounding granularity, and wrap into
  /// `[0, 1440)` so a suggestion just after midnight lands late the previous
  /// evening rather than going negative.
  int _applyLeadAndRounding(int minuteOfDay) {
    final lead = minuteOfDay - kReminderSuggestionLeadMinutes;
    final wrapped = ((lead % kMinutesPerDay) + kMinutesPerDay) % kMinutesPerDay;
    return wrapped - (wrapped % kReminderSuggestionRoundingMinutes);
  }

  /// Smallest circular distance in minutes between two minute-of-day values,
  /// so 23:55 and 00:05 read as 10 minutes apart, not 1430.
  int _circularDeltaMinutes(int a, int b) {
    final raw = (a - b).abs();
    return raw <= kMinutesPerDay - raw ? raw : kMinutesPerDay - raw;
  }

  String _formatMinuteOfDay(int minuteOfDay) {
    final hour = minuteOfDay ~/ 60;
    final minute = minuteOfDay % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  int _parseMinuteOfDay(String hhMm) {
    final parts = hhMm.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }
}
