import 'package:flutter/material.dart';

/// Dismissible D-08 banner shown on the tracking screen when the user
/// granted fine location but denied background location.
///
/// Rendered as a Material 3 [MaterialBanner] at the top of the tracking
/// screen body so it sits above the three live tiles. The only action
/// is `Open settings`, which invokes [onOpenSettings] — callers wire
/// this to `TrackingPermissionService.openSystemSettings` via Riverpod.
///
/// The banner is stateless: the parent tracking screen decides whether
/// to show it by inspecting the resolved permission status once
/// (`preflight()` in `initState`), so there is no reactive status
/// stream to subscribe to here.
///
/// The optional [body] parameter accepts platform-specific copy. When
/// omitted (null), the default Android copy is used. Pass
/// `kIosPermissionBannerBody` from `constants.dart` at the call site on iOS:
///
/// ```dart
/// PermissionBanner(
///   onOpenSettings: ...,
///   body: defaultTargetPlatform == TargetPlatform.iOS
///       ? kIosPermissionBannerBody
///       : null,
/// )
/// ```
class PermissionBanner extends StatelessWidget {
  /// Create a new banner that invokes [onOpenSettings] when tapped.
  ///
  /// [body] defaults to the existing Android copy when null.
  const PermissionBanner({
    required this.onOpenSettings,
    this.body,
    super.key,
  });

  /// Handler invoked when the user taps `Open settings`.
  final VoidCallback onOpenSettings;

  /// Optional override for the banner body text. When null, the default
  /// Android copy is displayed. Pass `kIosPermissionBannerBody` on iOS.
  final String? body;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      leading: const Icon(Icons.warning_amber_rounded),
      content: Text(
        body ??
            'Tracking will stop when the app is backgrounded. '
                'Enable always-on for full tracking.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: onOpenSettings,
          child: const Text('Open settings'),
        ),
      ],
    );
  }
}
