import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/trips/widgets/estimated_hint.dart';
import 'package:traevy/shared/utils/formatters.dart';
import 'package:traevy/shared/widgets/info_sheet.dart';
import 'package:traevy/shared/widgets/stuck_bar.dart';

const double _kLegendDotSize = 8;

/// Trip detail moving/stuck traffic section (Quick 260801-oux): a [StuckBar]
/// plus legend, or — for a GPS trip with nothing attributable — an honest
/// no-traffic-data notice instead of an empty grey bar.
///
/// A GPS trip can legitimately finish at 0/0: `TripAccumulator` attributes
/// nothing when every sample gap exceeds `kTrackingMaxAttributableGapSeconds`,
/// and a restored pre-Phase-31 snapshot marks its whole prefix unattributed.
/// `TripEditRecompute.rescaleTraffic` deliberately returns (0, 0) for a 0/0
/// input (D-02 — never invent a ratio), so no edit can ever move such a trip
/// off zero. Rendering an empty grey bar plus "0m moving / 0m stuck" made
/// that look like a broken edit. This branch does NOT change any math — it
/// only stops the UI from implying a number exists.
class TripTrafficSection extends StatelessWidget {
  /// Create the traffic section for a trip's [movingSeconds]/[stuckSeconds].
  ///
  /// [isEdited] surfaces the "~ estimated" hint (Phase 19, D-04) — it is
  /// suppressed automatically in the 0/0 case below, since nothing was
  /// estimated for a trip with no traffic data.
  const TripTrafficSection({
    required this.movingSeconds,
    required this.stuckSeconds,
    this.isEdited = false,
    super.key,
  });

  /// Seconds spent moving (speed >= 10 km/h).
  final int movingSeconds;

  /// Seconds spent stuck in traffic (speed < 10 km/h).
  final int stuckSeconds;

  /// True for a fully-edited trip (Phase 19, D-04).
  final bool isEdited;

  @override
  Widget build(BuildContext context) {
    if (movingSeconds + stuckSeconds == 0) {
      final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
      return Row(
        children: <Widget>[
          Expanded(
            child: Text(
              kNoTrafficDataLabel,
              style: TraevyFonts.mono(size: 12, color: tokens.textDim),
            ),
          ),
          const InfoIconButton(
            title: kNoTrafficDataInfoTitle,
            body: kNoTrafficDataInfoBody,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StuckBar(movingSeconds: movingSeconds, stuckSeconds: stuckSeconds),
        const SizedBox(height: 8),
        _TrafficLegend(
          movingSeconds: movingSeconds,
          stuckSeconds: stuckSeconds,
          isEdited: isEdited,
        ),
      ],
    );
  }
}

/// Moving/stuck legend row: colored dots + labels, the stuck explainer icon,
/// and the optional "~ estimated" hint. Extracted to keep
/// [TripTrafficSection] under CLAUDE.md's ~100-line widget limit.
class _TrafficLegend extends StatelessWidget {
  const _TrafficLegend({
    required this.movingSeconds,
    required this.stuckSeconds,
    required this.isEdited,
  });

  final int movingSeconds;
  final int stuckSeconds;
  final bool isEdited;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return Row(
      children: <Widget>[
        _LegendDot(color: tokens.moving),
        const SizedBox(width: 6),
        Text(
          '${formatTrafficDuration(movingSeconds)} moving',
          style: TraevyFonts.mono(size: 12, color: tokens.moving),
        ),
        const Spacer(),
        _LegendDot(color: tokens.stuck),
        const SizedBox(width: 6),
        Text(
          '${formatTrafficDuration(stuckSeconds)} stuck',
          style: TraevyFonts.mono(size: 12, color: tokens.stuck),
        ),
        // D-08: an honest explanation of how "stuck" is measured, including
        // the fact that the map highlights only the longer stretches.
        const InfoIconButton(title: kStuckInfoTitle, body: kStuckInfoBody),
        if (isEdited) ...<Widget>[
          const SizedBox(width: 8),
          const EstimatedHint(size: 12),
        ],
      ],
    );
  }
}

/// Small colored circle used in the moving/stuck legend row.
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kLegendDotSize,
      height: _kLegendDotSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
