import 'package:flutter/material.dart';

/// Transient-state body for the tracking screen (`TrackingStarting` and
/// `TrackingStopping`): a centered spinner above a status label.
///
/// Extracted from `tracking_screen.dart` so the screen file stays under
/// the 100-line CLAUDE.md widget cap. The label differs between the
/// two transient states (`Starting GPS...` vs `Saving trip...`).
class TrackingStatusLayout extends StatelessWidget {
  /// Create the status layout with a user-facing [label].
  const TrackingStatusLayout({required this.label, super.key});

  /// User-facing label describing the in-flight transition.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label),
        ],
      ),
    );
  }
}
