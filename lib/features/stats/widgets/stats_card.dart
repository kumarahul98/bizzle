import 'package:flutter/material.dart';

// Layout constants — multiples of 4 per UI-SPEC §Spacing Scale.
const double _kCardPadding = 16;
const double _kTitleBottomGap = 12;

/// Reusable Material 3 card wrapper shared by every stat card in Phase 5.
///
/// Renders a [Card] with [ColorScheme.surfaceContainerLow] background,
/// uniform 16 dp padding on all sides, a bold [title] row, and a [child]
/// body below a 12 dp gap.
///
/// All stat card widgets in this feature (WeekMonthTotalsCard,
/// DirectionAveragesCard, BestWorstDayCard, TrendChartCard,
/// TrafficWasteCard) delegate their outer shell to this wrapper so that
/// card shape, elevation, surface colour, and padding are consistent.
class StatsCard extends StatelessWidget {
  /// Construct a stats card with the given [title] and [child] body.
  const StatsCard({
    required this.title,
    required this.child,
    super.key,
  });

  /// Card heading shown above the body in [TextTheme.titleSmall].
  final String title;

  /// Body widget rendered below the title row.
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
            Text(title, style: textTheme.titleSmall),
            const SizedBox(height: _kTitleBottomGap),
            child,
          ],
        ),
      ),
    );
  }
}
