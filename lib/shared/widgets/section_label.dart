import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// Small uppercase section heading in the muted text color with letter
/// spacing 1.0. Used above grouped lists, card sections, and stat blocks.
///
/// No internal padding — callers wrap in [Padding] as needed.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §1 Section header style.
class SectionLabel extends StatelessWidget {
  /// Creates a [SectionLabel].
  ///
  /// [text] is rendered in UPPERCASE with letter spacing 1.0.
  /// [fontSize] defaults to 12 logical pixels.
  const SectionLabel({
    required this.text,
    this.fontSize = 12,
    super.key,
  });

  /// Section heading text. Rendered in UPPERCASE regardless of input case.
  final String text;

  /// Font size in logical pixels. Defaults to 12.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return Text(
      text.toUpperCase(),
      style: TraevyFonts.ui(
        size: fontSize,
        weight: FontWeight.w600,
        color: tokens.textMuted,
        letterSpacing: 1,
      ),
    );
  }
}
