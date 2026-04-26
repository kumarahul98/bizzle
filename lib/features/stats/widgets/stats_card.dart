import 'package:flutter/material.dart';

// Spacing constants — multiples of 4 per UI-SPEC.
const double _kCardPadding = 16;
const double _kTitleBodyGap = 8;

/// Reusable Material 3 card wrapper for every Phase 5 stat card.
///
/// Renders a [Card] with `surfaceContainerLow` background (matching
/// `TripCard`), 16px padding, the [title] in `titleMedium`, and the
/// caller-provided [child] below.
///
/// Cards are read-only (UI-SPEC §Interaction) — no `InkWell`, no
/// `onTap`, no ripple.
class StatsCard extends StatelessWidget {
  /// Construct a stats card.
  ///
  /// [title] is rendered as `titleMedium` (16sp w600) at the top of
  /// the card. [child] occupies the rest of the card body.
  const StatsCard({
    required this.title,
    required this.child,
    super.key,
  });

  /// Card heading text. Comes from a Phase 5 string constant.
  final String title;

  /// Body slot — typically a Column of value + helper rows.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(_kCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _kTitleBodyGap),
            child,
          ],
        ),
      ),
    );
  }
}
