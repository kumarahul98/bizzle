import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/settings/widgets/settings_row.dart';

/// Number of decimal places shown for a saved coordinate (≈11 m precision at
/// the equator — enough to confirm the saved spot without over-stating GPS
/// accuracy).
const int _kCoordDecimals = 5;

/// A settings row that shows a saved Home or Office anchor (LOC-01).
///
/// Reads the relevant coord from [userPreferenceProvider] and renders either
/// the formatted `lat, lng` or [kCopyLocationNotSet] when the slot is empty
/// (D-13). Tapping the row invokes [onTap] — the parent opens the picker.
///
/// PII note (T-21-02-01): the coordinate is rendered only in the local UI; it
/// is never logged or sent anywhere.
class SavedLocationTile extends ConsumerWidget {
  /// Create a [SavedLocationTile].
  ///
  /// [isHome] selects which saved slot this row reflects (Home vs Office).
  /// [onTap] opens the picker for that slot.
  const SavedLocationTile({
    required this.isHome,
    required this.onTap,
    super.key,
  });

  /// True → reflects/edits the Home anchor; false → the Office anchor.
  final bool isHome;

  /// Invoked when the row is tapped (parent opens the picker).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferenceProvider);
    final label = isHome
        ? kSettingsHomeLocationLabel
        : kSettingsOfficeLocationLabel;

    final subtitle = prefs.maybeWhen(
      data: (value) {
        final lat = isHome ? value.homeLat : value.officeLat;
        final lng = isHome ? value.homeLng : value.officeLng;
        return _formatCoord(lat, lng);
      },
      orElse: () => kCopyLocationNotSet,
    );

    return SettingsRow(
      label: label,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  /// Format a saved coordinate, or [kCopyLocationNotSet] when either component
  /// is null (the slot has never been set — D-13).
  static String _formatCoord(double? lat, double? lng) {
    if (lat == null || lng == null) return kCopyLocationNotSet;
    return '${lat.toStringAsFixed(_kCoordDecimals)}, '
        '${lng.toStringAsFixed(_kCoordDecimals)}';
  }
}
