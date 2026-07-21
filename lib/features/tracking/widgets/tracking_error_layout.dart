import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';

/// Error-state body for the tracking screen.
///
/// Shows the user-facing [message] above a Retry button. When
/// [onOpenSettings] is provided (location-unavailable errors), an additional
/// [kOpenPermissionSettingsLabel] button is shown so the user can fix the
/// permission without hunting through Android settings manually.
///
/// Phase 36 (D-03): the button was labelled "Open Location Settings" and led
/// to the device-wide location screen. It now leads to the app's own
/// permission list, like every other denial path, and takes its label from the
/// shared constant so the three cannot drift apart in wording again.
class TrackingErrorLayout extends StatelessWidget {
  const TrackingErrorLayout({
    required this.message,
    required this.onRetry,
    this.onOpenSettings,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  /// When non-null, renders an [kOpenPermissionSettingsLabel] button below
  /// Retry.
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
                child: const Text(kOpenPermissionSettingsLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
