import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// A single row inside a `SettingsSection`: label on the left, optional
/// mono subtitle below, optional trailing control (toggle, chevron, badge).
///
/// When [trailing] is null and [onTap] is non-null, a default chevron
/// is rendered to communicate tappability.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §8 Settings Screen.
class SettingsRow extends StatelessWidget {
  /// Creates a [SettingsRow].
  ///
  /// [label] is the primary text (Inter 14sp w500).
  /// [subtitle] is optional helper text (JetBrains Mono 12sp dim).
  /// [trailing] is an optional widget rendered on the right edge — typically
  /// a `TraevyToggle` or status badge.
  /// [onTap] makes the row tappable. When non-null and [trailing] is null,
  /// a chevron is auto-rendered.
  /// [dangerous] renders [label] in the `danger` color (used for Sign out).
  const SettingsRow({
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dangerous = false,
    super.key,
  });

  /// Primary label text.
  final String label;

  /// Optional helper text rendered below [label] in JetBrains Mono.
  final String? subtitle;

  /// Optional trailing widget (toggle, badge). When null and [onTap] is
  /// non-null, a chevron is rendered.
  final Widget? trailing;

  /// Tap handler. When non-null, the row becomes an [InkWell].
  final VoidCallback? onTap;

  /// When true, renders [label] in the `danger` color (destructive actions).
  final bool dangerous;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final labelColor = dangerous
        ? tokens.record
        : Theme.of(context).colorScheme.onSurface;
    final effectiveTrailing =
        trailing ??
        (onTap == null
            ? null
            : Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: tokens.textMuted,
              ));
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TraevyFonts.ui(
                    size: 14,
                    weight: FontWeight.w500,
                    color: labelColor,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TraevyFonts.mono(size: 12, color: tokens.textDim),
                  ),
                ],
              ],
            ),
          ),
          if (effectiveTrailing != null) ...<Widget>[
            const SizedBox(width: 12),
            effectiveTrailing,
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    // Material(type: transparency) provides the ink-splash sink InkWell
    // needs; the enclosing MainShell has no Scaffold around this screen.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
