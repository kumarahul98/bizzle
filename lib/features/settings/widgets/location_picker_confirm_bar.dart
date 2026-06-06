import 'package:flutter/material.dart';

/// The bottom confirm bar of the location picker (LOC-01).
///
/// Renders a single prominent [FilledButton] labelled "Set <slot> here". The
/// button's `onPressed` is the only path that reads the map centre (D-12
/// read-on-confirm) — the bar itself holds no map state.
class LocationPickerConfirmBar extends StatelessWidget {
  /// Create the confirm bar.
  ///
  /// [label] is the button copy; [onConfirm] persists the current map centre.
  const LocationPickerConfirmBar({
    required this.label,
    required this.onConfirm,
    super.key,
  });

  /// Button copy, e.g. "Set home here".
  final String label;

  /// Invoked on tap — the screen reads `mapController.camera.center` here.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onConfirm,
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
