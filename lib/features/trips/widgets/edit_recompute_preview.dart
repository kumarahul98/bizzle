import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// Read-only live preview of an edited trip's recomputed active duration and
/// moving/stuck split (Phase 19, D-11).
///
/// Pure presentation: the edit sheet computes [activeSeconds]/[movingSeconds]/
/// [stuckSeconds] via `TripEditRecompute` on every change and passes them in.
/// No editing, no persistence — what is shown here is exactly what Save will
/// persist (T-19-07 mitigation: single recompute code path).
class EditRecomputePreview extends StatelessWidget {
  /// Create the preview for the supplied recomputed values (all in seconds).
  const EditRecomputePreview({
    required this.activeSeconds,
    required this.movingSeconds,
    required this.stuckSeconds,
    super.key,
  });

  /// Recomputed active duration in seconds.
  final int activeSeconds;

  /// Recomputed moving seconds (speed ≥ 10 km/h).
  final int movingSeconds;

  /// Recomputed stuck seconds (speed < 10 km/h).
  final int stuckSeconds;

  static String _fmt(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.bgElev,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _PreviewStat(
              label: 'Duration',
              value: _fmt(activeSeconds),
              color: onSurface,
            ),
          ),
          Expanded(
            child: _PreviewStat(
              label: 'Moving',
              value: _fmt(movingSeconds),
              color: tokens.moving,
            ),
          ),
          Expanded(
            child: _PreviewStat(
              label: 'Stuck',
              value: _fmt(stuckSeconds),
              color: tokens.stuck,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TraevyFonts.ui(size: 11, color: tokens.textDim),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TraevyFonts.mono(
            size: 18,
            weight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
