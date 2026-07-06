import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/trips/widgets/estimated_hint.dart';

/// Inner text column for TripRowCard: name+duration row and time+stuck row.
///
/// Extracted to keep TripRowCard under the 100-line widget size limit.
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §5 Trip History.
class TripRowInfo extends StatelessWidget {
  const TripRowInfo({
    required this.displayName,
    required this.durationLabel,
    required this.timeRange,
    required this.stuckMins,
    this.isEdited = false,
    super.key,
  });

  final String displayName;
  final String durationLabel;
  final String timeRange;
  final int stuckMins;

  /// True for a fully-edited trip (Phase 19, D-04): renders the "~ estimated"
  /// hint after the stuck figure. Defaults to false.
  final bool isEdited;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: TraevyFonts.ui(
                  size: 15,
                  weight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Text(
              durationLabel,
              style: TraevyFonts.mono(
                size: 13,
                weight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                timeRange,
                style: TraevyFonts.mono(size: 12, color: tokens.textDim),
              ),
            ),
            if (stuckMins > 0)
              Text(
                '${stuckMins}m stuck',
                style: TraevyFonts.mono(
                  size: 12,
                  weight: FontWeight.w600,
                  color: tokens.stuck,
                ),
              ),
            if (isEdited) ...<Widget>[
              const SizedBox(width: 6),
              const EstimatedHint(),
            ],
          ],
        ),
      ],
    );
  }
}
