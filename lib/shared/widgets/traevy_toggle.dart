import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// Traevy-styled toggle switch.
///
/// A 38×22dp pill-shaped toggle with an 18dp white knob. Off state uses
/// `borderStr` background with knob aligned left; on state uses `moving`
/// background with knob aligned right. Animates over 180ms.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §8 Settings Toggle.
class TraevyToggle extends StatelessWidget {
  /// Creates a [TraevyToggle].
  ///
  /// [value] determines the current on/off state.
  /// [onChanged] is called with the inverted value on tap.
  const TraevyToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Current toggle state. `true` = on (moving bg + right knob).
  final bool value;

  /// Called with the new value when the user taps the toggle.
  final ValueChanged<bool> onChanged;

  static const double _width = 38;
  static const double _height = 22;
  static const double _knobSize = 18;
  static const Duration _duration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final trackColor = value ? tokens.moving : tokens.borderStr;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: _duration,
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Align(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: _knobSize,
              height: _knobSize,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kTraevyKnobShadow,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
