import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';

/// The fixed centre crosshair painted on top of the picker map (D-12).
///
/// Wrapped in [IgnorePointer] so every pan/zoom gesture passes through to the
/// map beneath — the pin never moves; the map slides under it. The confirm
/// button reads the map centre on tap, which is exactly the point the crosshair
/// covers, so there is no tap-target ambiguity.
class LocationPickerCrosshair extends StatelessWidget {
  /// Create the centre crosshair overlay.
  const LocationPickerCrosshair({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return IgnorePointer(
      child: Center(
        child: Icon(
          Icons.place_rounded,
          size: kLocationPickerCrosshairSize,
          color: tokens.record,
          // A subtle shadow lifts the pin off busy map tiles.
          shadows: const <Shadow>[
            Shadow(blurRadius: 6, color: Color(0x66000000)),
          ],
        ),
      ),
    );
  }
}
