import 'package:flutter/material.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';

/// Full-screen CTA card shown when the tracking screen detects fine
/// location is denied or permanently denied.
///
/// Implements the D-09 permanent-deny flow (`Open settings` deep-link)
/// and the D-07 first-prompt-denied flow (`Grant location` retry).
/// The parent tracking screen decides which branch to show based on
/// the resolved [TrackingPermissionStatus] and wires [onGrant] to a
/// re-run of `TrackingPermissionService.preflight()` or
/// `openSystemSettings()` accordingly.
class PermissionGate extends StatelessWidget {
  /// Create a new gate for [status]. [onGrant] is invoked when the user
  /// taps the action button.
  const PermissionGate({
    required this.status,
    required this.onGrant,
    super.key,
  });

  /// The resolved permission status that triggered the gate.
  final TrackingPermissionStatus status;

  /// Handler invoked when the user taps the action button.
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final isPermanent = status == TrackingPermissionStatus.permanentlyDenied;
    final title = isPermanent
        ? 'Location permission permanently denied'
        : 'Traevy needs location to record your commute';
    final buttonLabel = isPermanent ? 'Open settings' : 'Grant location';
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
