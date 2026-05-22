import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/shared/widgets/section_label.dart';

/// Elapsed-time display for the active recording screen (Variant A).
///
/// Renders a ELAPSED section label above a 76sp JetBrains Mono timer in
/// HH:MM:SS format.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §4 Active Recording.
class ElapsedDisplay extends StatelessWidget {
  /// Creates an [ElapsedDisplay] with the given [durationSeconds].
  const ElapsedDisplay({required this.durationSeconds, super.key});

  /// Whole seconds to display. Negative values are clamped to zero.
  final int durationSeconds;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionLabel(text: 'Elapsed', fontSize: 11),
        const SizedBox(height: 8),
        Text(
          _formatElapsed(durationSeconds),
          style: TraevyFonts.mono(
            size: 76,
            weight: FontWeight.w500,
            color: onSurface,
            letterSpacing: -3,
          ),
        ),
      ],
    );
  }
}

/// Format [seconds] as `HH:MM:SS` (always). Negative inputs clamped to zero.
String _formatElapsed(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final hours = safe ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  final secs = safe % 60;
  final hh = hours.toString().padLeft(2, '0');
  final mm = minutes.toString().padLeft(2, '0');
  final ss = secs.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}
