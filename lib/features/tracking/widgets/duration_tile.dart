import 'package:flutter/material.dart';
import 'package:traevy/shared/widgets/stat_mini_card.dart';

/// Stuck-time tile shown on the active tracking screen (Variant A).
///
/// Thin adapter over [StatMiniCard] — preserves the public `elapsedSeconds`
/// constructor so existing widget-test `find.byType(DurationTile)` calls
/// continue to resolve.
///
/// Despite its legacy name `DurationTile`, the active layout repurposes this
/// slot to display "stuck in traffic" time with the `stuck` tone.
class DurationTile extends StatelessWidget {
  /// Creates a [DurationTile] with the given [elapsedSeconds].
  const DurationTile({required this.elapsedSeconds, super.key});

  /// Total elapsed seconds; displayed as stuck-in-traffic time in
  /// the active tracking tiles row.
  final int elapsedSeconds;

  @override
  Widget build(BuildContext context) {
    return StatMiniCard(
      label: 'STUCK',
      value: _formatStuck(elapsedSeconds),
      tone: StatMiniCardTone.stuck,
    );
  }
}

/// Format [seconds] as `Xm` or `Xs` for display in the STUCK tile.
String _formatStuck(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  if (safe >= 60) return '${safe ~/ 60}m';
  return '${safe}s';
}
