import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/shared/widgets/trip_row_card.dart';

/// A date-grouped section for the trip history list.
///
/// Renders a header row (date label + optional subtitle + total duration)
/// followed by a full-width `bgElev` card with a top and bottom border
/// containing one [TripRowCard] per trip.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §5 Trip History.
class TripSectionCard extends StatelessWidget {
  /// Creates a [TripSectionCard].
  const TripSectionCard({
    required this.dateLabel,
    required this.totalLabel,
    required this.trips,
    required this.onTripTap,
    this.subtitleLabel,
    super.key,
  });

  /// Primary date string, e.g. 'Today' or 'Mon 28 Apr'.
  final String dateLabel;

  /// Optional secondary label, e.g. 'Mon, 28 Apr'.
  final String? subtitleLabel;

  /// Formatted total duration string, e.g. '1h 22m'.
  final String totalLabel;

  /// Ordered list of trips for this date group.
  final List<TripSummary> trips;

  /// Called when a trip row is tapped.
  final ValueChanged<TripSummary> onTripTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final sub = subtitleLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: <Widget>[
              Text(
                dateLabel,
                style: TraevyFonts.ui(
                  size: 13,
                  weight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
              if (sub != null) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  sub,
                  style: TraevyFonts.ui(
                    size: 11,
                    weight: FontWeight.w500,
                    color: tokens.textMuted,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                totalLabel,
                style: TraevyFonts.mono(
                  size: 12,
                  weight: FontWeight.w600,
                  color: tokens.textDim,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: tokens.bgElev,
            border: Border(
              top: BorderSide(color: tokens.border),
              bottom: BorderSide(color: tokens.border),
            ),
          ),
          child: trips.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No trips',
                    style: TraevyFonts.ui(
                      size: 13,
                      weight: FontWeight.w500,
                      color: tokens.textMuted,
                    ),
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (int i = 0; i < trips.length; i++)
                      TripRowCard(
                        direction: trips[i].direction,
                        startTime: trips[i].startTime,
                        endTime: trips[i].endTime,
                        durationSeconds: trips[i].durationSeconds,
                        distanceMeters: trips[i].distanceMeters,
                        stuckSeconds: trips[i].timeStuckSeconds,
                        showDivider: i < trips.length - 1,
                        onTap: () => onTripTap(trips[i]),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
