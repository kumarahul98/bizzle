import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';

/// Subtle inline "~ estimated" marker shown on an edited trip's moving/stuck
/// figures (Phase 19, D-04).
///
/// Edited traffic stats are derived via proportional rescale, not measured
/// from GPS, so this hint keeps the UI honest. Rendered in the dim token
/// colour + mono font and wrapped in a [Tooltip] that expands on why the
/// number is estimated. Reused on the trip detail legend and the history row.
class EstimatedHint extends StatelessWidget {
  /// Create the estimated hint. [size] tunes the font for the host context
  /// (detail legend vs. compact history row); defaults to 11.
  const EstimatedHint({this.size = 11, super.key});

  /// Font size for the hint label.
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return Tooltip(
      message: kEditEstimatedHintTooltip,
      child: Text(
        kEditEstimatedHintLabel,
        style: TraevyFonts.mono(
          size: size,
          color: tokens.textDim,
        ),
      ),
    );
  }
}
