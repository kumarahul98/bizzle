import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/trips/widgets/trip_timeline_row.dart';
import 'package:traevy/shared/widgets/section_label.dart';

/// Clock-icon timeline rows for a trip's Started / Stuck / Arrived events.
///
/// Displays three timeline rows for v0.1: "Started recording", optionally
/// "Stuck in traffic" at the approximate midpoint (when stuckMinutes > 0),
/// and "Arrived home" or "Arrived at office" based on direction.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §6 Trip Detail Screen.
class TripTimeline extends StatelessWidget {
  /// Creates a [TripTimeline].
  const TripTimeline({
    required this.startTime,
    required this.endTime,
    required this.stuckMinutes,
    required this.direction,
    super.key,
  });

  /// Trip start time (UTC); converted to local for display.
  final DateTime startTime;

  /// Trip end time (UTC); converted to local for display.
  final DateTime endTime;

  /// Minutes spent stuck in traffic. When > 0, a stuck row is shown.
  final int stuckMinutes;

  /// Trip direction string (kDirectionToOffice or kDirectionToHome).
  final String direction;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final localStart = startTime.toLocal();
    final localEnd = endTime.toLocal();

    // Approximate stuck midpoint: 40% through the trip.
    final tripDuration = localEnd.difference(localStart);
    final stuckPoint = localStart.add(
      Duration(seconds: (tripDuration.inSeconds * 0.4).round()),
    );

    final arrivedLabel = direction == kDirectionToHome
        ? 'Arrived home'
        : 'Arrived at office';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionLabel(text: 'Timeline'),
        const SizedBox(height: 12),
        TripTimelineRow(
          time: localStart,
          icon: Icons.location_on_rounded,
          iconBg: tokens.accentBg,
          iconColor: tokens.accent,
          label: 'Started recording',
        ),
        if (stuckMinutes > 0) ...<Widget>[
          const SizedBox(height: 12),
          TripTimelineRow(
            time: stuckPoint,
            icon: Icons.access_time_rounded,
            iconBg: tokens.stuckBg,
            iconColor: tokens.stuck,
            label: 'Stuck in traffic',
            duration: '$stuckMinutes min',
          ),
        ],
        const SizedBox(height: 12),
        TripTimelineRow(
          time: localEnd,
          icon: Icons.flag_rounded,
          iconBg: tokens.movingBg,
          iconColor: tokens.moving,
          label: arrivedLabel,
        ),
      ],
    );
  }
}
