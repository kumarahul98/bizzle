import 'package:flutter/material.dart';

/// Error-state body for the tracking screen.
///
/// Shows the user-facing [message] from a `TrackingError` sealed-class
/// variant above a Retry button that re-invokes `TrackingNotifier.start`.
/// Extracted from `tracking_screen.dart` so the screen file stays under
/// the 100-line CLAUDE.md widget cap.
class TrackingErrorLayout extends StatelessWidget {
  /// Create the error layout.
  const TrackingErrorLayout({
    required this.message,
    required this.onRetry,
    super.key,
  });

  /// User-facing error message to render.
  final String message;

  /// Handler invoked when the user taps the Retry button.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
