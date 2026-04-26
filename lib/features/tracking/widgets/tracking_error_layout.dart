import 'package:flutter/material.dart';

/// Error-state body for the tracking screen.
///
/// Shows the user-facing [message] above a Retry button. When
/// [onOpenSettings] is provided (location-unavailable errors), an additional
/// "Open Location Settings" button is shown so the user can enable
/// high-accuracy mode without hunting through Android settings manually.
class TrackingErrorLayout extends StatelessWidget {
  const TrackingErrorLayout({
    required this.message,
    required this.onRetry,
    this.onOpenSettings,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  /// When non-null, renders an "Open Location Settings" button below Retry.
  final VoidCallback? onOpenSettings;

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
            if (onOpenSettings != null) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onOpenSettings,
                child: const Text('Open Location Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
