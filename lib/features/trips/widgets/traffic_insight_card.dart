import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// Callout card displayed on the Trip Detail screen when stuck time > 0.
///
/// Renders a stuckBg-coloured container with a clock icon and a rich-text
/// sentence: "You lost X minutes stuck in traffic. That's Y% of this trip."
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §6 Trip Detail Screen.
class TrafficInsightCard extends StatelessWidget {
  /// Creates a [TrafficInsightCard].
  ///
  /// [stuckMinutes] is the total minutes spent stuck in traffic for this trip.
  /// [totalMinutes] is the full trip duration in minutes (used to compute %).
  /// When [totalMinutes] is 0, the percentage renders as 0%.
  const TrafficInsightCard({
    required this.stuckMinutes,
    required this.totalMinutes,
    super.key,
  });

  /// Minutes spent stuck in traffic on this trip.
  final int stuckMinutes;

  /// Total trip duration in minutes.
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textTheme = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final pct = totalMinutes == 0
        ? 0
        : (stuckMinutes / totalMinutes * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.stuckBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tokens.stuck.withAlpha(46),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.access_time_rounded,
              size: 18,
              color: tokens.stuck,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: textTheme.bodyMedium?.copyWith(color: onSurface),
                children: <TextSpan>[
                  const TextSpan(text: 'You lost '),
                  TextSpan(
                    text: '$stuckMinutes minutes',
                    style: TraevyFonts.ui(
                      size: 13.5,
                      weight: FontWeight.w700,
                      color: tokens.stuck,
                    ),
                  ),
                  const TextSpan(text: ' stuck in traffic. '),
                  TextSpan(
                    text: "That's $pct%",
                    style: TraevyFonts.ui(
                      size: 13.5,
                      weight: FontWeight.w700,
                      color: onSurface,
                    ),
                  ),
                  const TextSpan(text: ' of this trip.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
