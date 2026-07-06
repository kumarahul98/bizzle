import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';

/// Dismissible D-08 banner shown on the dashboard when the sync engine has
/// permanently failed to sync items and the auto-retry window is exhausted.
///
/// Rendered as a Material 3 [MaterialBanner] below the dashboard app bar.
class SyncStuckBanner extends StatelessWidget {
  /// Create a new banner that invokes [onReviewSettings] when tapped.
  const SyncStuckBanner({
    required this.onReviewSettings,
    required this.onDismiss,
    super.key,
  });

  /// Handler invoked when the user taps `Review in Settings`.
  final VoidCallback onReviewSettings;

  /// Handler invoked when the user dismisses the banner.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      leading: const Icon(Icons.sync_problem),
      content: const Text(kSyncStuckBannerMessage),
      actions: <Widget>[
        TextButton(
          onPressed: onReviewSettings,
          child: const Text(kSyncStuckBannerAction),
        ),
        TextButton(
          onPressed: onDismiss,
          child: const Text(kSyncStuckBannerDismiss),
        ),
      ],
    );
  }
}
