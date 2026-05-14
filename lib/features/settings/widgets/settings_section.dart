import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/shared/widgets/section_label.dart';

/// Grouped settings section: uppercase [SectionLabel] above a `bgElev` card
/// with top + bottom borders, containing [children] interleaved with hairline
/// dividers.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §8 Settings Screen.
class SettingsSection extends StatelessWidget {
  /// Creates a [SettingsSection].
  ///
  /// [title] renders as an UPPERCASE [SectionLabel] at 11sp.
  /// [children] are stacked vertically inside a `bgElev` card, with a
  /// `border`-colored 1dp divider inserted between every pair.
  const SettingsSection({
    required this.title,
    required this.children,
    super.key,
  });

  /// Section heading rendered above the card.
  final String title;

  /// Rows rendered inside the card. Dividers are inserted automatically
  /// between every pair.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: SectionLabel(text: title, fontSize: 11),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.bgElev,
              border: Border(
                top: BorderSide(color: tokens.border),
                bottom: BorderSide(color: tokens.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _interleaveWithDividers(children, tokens.border),
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _interleaveWithDividers(
    List<Widget> rows,
    Color dividerColor,
  ) {
    if (rows.length < 2) return rows;
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      out.add(rows[i]);
      if (i < rows.length - 1) {
        out.add(Divider(color: dividerColor, height: 1, thickness: 1));
      }
    }
    return out;
  }
}
