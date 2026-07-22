import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';

/// A dismissible card that offers a recalibrated reminder time (Phase 33,
/// D-04).
///
/// Surfaced under the reminder rows when a fresh suggestion is worth showing
/// (see `ReminderSuggestionService.shouldOffer`). Accept applies the time;
/// Dismiss hides it and is remembered so the same value never re-prompts. The
/// permanent subtitle on the reminder-time row is the always-available second
/// surface — this card is the discoverable one.
class ReminderSuggestionCard extends StatelessWidget {
  /// Create a suggestion card for the `HH:mm` [suggestion].
  const ReminderSuggestionCard({
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
    super.key,
  });

  /// The suggested time as `HH:mm`.
  final String suggestion;

  /// Called when the user accepts the suggestion.
  final VoidCallback onAccept;

  /// Called when the user dismisses the suggestion.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final pretty = _pretty(suggestion);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderStr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            kReminderSuggestionCardTitle,
            style: TraevyFonts.ui(
              size: 15,
              weight: FontWeight.w700,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$kReminderSuggestionCardBodyPrefix$pretty'
            '$kReminderSuggestionCardBodyMiddle$pretty'
            '$kReminderSuggestionCardBodySuffix',
            style: TraevyFonts.ui(
              size: 14,
              color: tokens.textDim,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: onDismiss,
                child: const Text(kReminderSuggestionDismissLabel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onAccept,
                child: const Text(kReminderSuggestionAcceptLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Format `HH:mm` for display (e.g. `08:05` → `8:05 AM`), falling back to
  /// the raw value if it cannot be parsed.
  String _pretty(String hhMm) {
    try {
      return DateFormat.jm().format(DateFormat('HH:mm').parse(hhMm));
    } on FormatException {
      return hhMm;
    }
  }
}
