import 'package:flutter/material.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';

/// Full-screen CTA card shown when the tracking screen detects a
/// hard-blocking permission state: fine location denied / permanently
/// denied, or POST_NOTIFICATIONS denied.
///
/// Implements the D-09 permanent-deny flow (`Open settings` deep-link),
/// the D-07 first-prompt-denied flow (`Grant location` retry), and the
/// UX-03 gap-closure notification-denied flow (`Open settings` deep-link
/// for POST_NOTIFICATIONS on Android 13+). The parent tracking screen
/// decides which branch to show based on the resolved
/// [TrackingPermissionStatus] and wires [onGrant] accordingly:
///
///   * [TrackingPermissionStatus.denied] → re-run
///     `TrackingPermissionService.preflight()`
///   * [TrackingPermissionStatus.permanentlyDenied] →
///     `openSystemSettings()`
///   * [TrackingPermissionStatus.notificationDenied] →
///     `openSystemSettings()` (the system notification settings page is
///     the only reliable route after the user has hit "Don't allow")
class PermissionGate extends StatelessWidget {
  /// Create a new gate for [status]. [onGrant] is invoked when the user
  /// taps the action button.
  const PermissionGate({
    required this.status,
    required this.onGrant,
    super.key,
  });

  /// The resolved permission status that triggered the gate. MUST be
  /// one of [TrackingPermissionStatus.denied],
  /// [TrackingPermissionStatus.permanentlyDenied], or
  /// [TrackingPermissionStatus.notificationDenied].
  final TrackingPermissionStatus status;

  /// Handler invoked when the user taps the action button.
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final (String title, String buttonLabel) = switch (status) {
      TrackingPermissionStatus.permanentlyDenied => (
          'Location permission permanently denied',
          'Open settings',
        ),
      TrackingPermissionStatus.notificationDenied => (
          'Notifications are required to track commutes in the background',
          'Open settings',
        ),
      TrackingPermissionStatus.denied => (
          'Traevy needs location to record your commute',
          'Grant location',
        ),
      TrackingPermissionStatus.fullyGranted ||
      TrackingPermissionStatus.foregroundOnly =>
        // PermissionGate is only rendered for blocking states; the
        // parent tracking screen's branch guard filters non-blocking
        // states out before this widget is built. Treat a leak as a
        // programming error with a safe neutral fallback so the UI
        // surfaces something rather than throwing mid-build.
        (
          'Traevy needs location to record your commute',
          'Grant location',
        ),
    };
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: onGrant,
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
