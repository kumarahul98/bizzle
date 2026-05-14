import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';

/// Traevy brand mark: a rounded square with inverted text/bg colours
/// containing the short brand name ("tv") in JetBrains Mono 700.
///
/// Uses [Theme.of(context).colorScheme.onSurface] as the square fill
/// and [Theme.of(context).scaffoldBackgroundColor] as the text colour
/// so the mark inverts correctly in both light and dark modes.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §9 Onboarding 'tv' logo.
class TraevyLogoMark extends StatelessWidget {
  /// Creates a [TraevyLogoMark].
  ///
  /// [size] controls the side length of the rounded square in logical pixels.
  /// Defaults to 56.
  const TraevyLogoMark({this.size = 56, super.key});

  /// Side length of the logo mark in logical pixels. Defaults to 56.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.onSurface;
    final textColor = theme.scaffoldBackgroundColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          kBrandShortName,
          style: TraevyFonts.mono(
            size: size * 0.5,
            weight: FontWeight.w700,
            color: textColor,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }
}
