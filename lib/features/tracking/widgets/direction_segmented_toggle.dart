import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';

/// A 1-tap segmented To office / To home selector (TRACK-12, D-04).
///
/// Controlled widget — the parent owns [selected] and reacts to
/// [onSelected]; this widget holds no state. Emits only the
/// [kDirectionToOffice] / [kDirectionToHome] string constants, so no
/// arbitrary value can flow out of it (T-17-02 tamper guard).
///
/// Reused by the active-tracking hero surface (`_HeroActive`, where it calls
/// `TrackingNotifier.setDirection`) and the trip detail screen (where it
/// calls `tripManagementProvider.editTrip`). The edit-trip sheet keeps its
/// own enum-based SegmentedButton; this is the lightweight String-based
/// quick toggle for the two single-tap surfaces.
class DirectionSegmentedToggle extends StatelessWidget {
  /// Create a controlled direction toggle.
  ///
  /// [selected] must be [kDirectionToOffice] or [kDirectionToHome].
  const DirectionSegmentedToggle({
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    super.key,
  });

  /// Currently-selected direction constant (parent-owned).
  final String selected;

  /// Called with the newly-tapped direction constant.
  final ValueChanged<String> onSelected;

  /// When false the toggle is non-interactive (e.g. while a save is in
  /// flight). Defaults to true.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textStyle = TraevyFonts.ui(size: 13, weight: FontWeight.w600);
    return SegmentedButton<String>(
      segments: <ButtonSegment<String>>[
        ButtonSegment<String>(
          value: kDirectionToOffice,
          label: Text(kDirectionToOfficeLabel, style: textStyle),
        ),
        ButtonSegment<String>(
          value: kDirectionToHome,
          label: Text(kDirectionToHomeLabel, style: textStyle),
        ),
      ],
      selected: <String>{selected},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: tokens.surface2,
        foregroundColor: tokens.textDim,
        selectedBackgroundColor: tokens.record,
        selectedForegroundColor: Colors.white,
        side: BorderSide(color: tokens.border),
        visualDensity: VisualDensity.compact,
      ),
      onSelectionChanged: enabled
          ? (selection) => onSelected(selection.first)
          : null,
    );
  }
}
