import 'package:traevy/config/constants.dart';

/// Lifecycle of the recalibration suggestion (Phase 33, D-04).
///
/// Persisted as TEXT in `user_preferences.reminder_suggestion_state` alongside
/// `reminder_suggestion_value` (the `HH:mm` last offered). Modelled as an enum
/// rather than a bare string because the set is finite and closed — the
/// anti-nag rule in `ReminderSuggestionService` switches on it directly.
enum ReminderSuggestionState {
  /// Nothing has ever been offered on this install. Any computable
  /// suggestion is shown.
  none(kReminderSuggestionStateNone),

  /// A suggestion is currently on screen, neither accepted nor dismissed.
  offered(kReminderSuggestionStateOffered),

  /// The user applied the offered time.
  accepted(kReminderSuggestionStateAccepted),

  /// The user rejected the offered time. Remembered indefinitely for that
  /// value — only a materially different suggestion may re-prompt.
  dismissed(kReminderSuggestionStateDismissed)
  ;

  const ReminderSuggestionState(this.wireValue);

  /// The string persisted in Drift. Never write `name` — the wire value is
  /// the stable contract with the database.
  final String wireValue;

  /// Parse a persisted wire value, falling back to [none] for anything
  /// unrecognised (a hand-edited or corrupt row must not crash Settings).
  static ReminderSuggestionState fromWire(String value) {
    for (final state in ReminderSuggestionState.values) {
      if (state.wireValue == value) return state;
    }
    return ReminderSuggestionState.none;
  }
}
