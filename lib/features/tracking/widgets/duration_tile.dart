import 'package:flutter/material.dart';

/// Live elapsed-time tile shown on the tracking screen (D-12).
///
/// Renders a Material 3 [Card] with a `Duration` label above a large
/// monospace-feeling display value formatted as either `MM:SS` (trips
/// under one hour) or `HH:MM:SS` (longer trips). The tile is stateless:
/// the parent owns the `trackingStateProvider` subscription and passes
/// [elapsedSeconds] on every rebuild.
class DurationTile extends StatelessWidget {
  /// Create a new tile displaying [elapsedSeconds].
  const DurationTile({required this.elapsedSeconds, super.key});

  /// Whole seconds of trip elapsed time to render.
  final int elapsedSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Duration', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              _formatElapsed(elapsedSeconds),
              style: theme.textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Format [seconds] as `HH:MM:SS` when >= 3600, otherwise `MM:SS`.
///
/// Private to this file so the build method stays short and the
/// formatting contract is independently testable via widget tests.
String _formatElapsed(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final hours = safe ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  final secs = safe % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = secs.toString().padLeft(2, '0');
  if (hours > 0) {
    final hh = hours.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
  return '$mm:$ss';
}
