import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';

/// Traevy brand mark: the app's icon artwork (`assets/icons/logo.png`) shown
/// as a rounded-square tile.
///
/// This is the SAME source file used to generate the Android/iOS launcher
/// icons via the `flutter_launcher_icons` config in `pubspec.yaml`, so the
/// in-app mark and the home-screen icon always stay identical.
///
/// The artwork (a glowing gold dashed triangle on a solid black background)
/// is presented unmodified — no tinting, inversion, or theme-based
/// recoloring — in BOTH light and dark themes, because the black background
/// is baked into the image and the mark is meant to read like an app icon
/// regardless of the surrounding theme.
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        'assets/icons/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: kBrandFullName,
      ),
    );
  }
}
