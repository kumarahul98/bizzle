import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/shared/widgets/section_label.dart';

// Spacing constants — multiples of 4 per UI-SPEC.
const double _kCardPadding = 20;
const double _kTitleBodyGap = 12;

/// Thin bgElev card wrapper for Phase 8 stats cards.
///
/// Renders a Container with tokens.bgElev background, 16dp radius,
/// tokens.border border, 20dp padding, and an optional title
/// rendered as a SectionLabel above the child.
///
/// Cards are read-only — no InkWell or onTap.
class StatsCard extends StatelessWidget {
  /// Construct a stats card.
  ///
  /// When [title] is non-null, it renders as a [SectionLabel] above
  /// the [child] with [_kTitleBodyGap] between them.
  const StatsCard({
    required this.child,
    this.title,
    this.padding,
    super.key,
  });

  /// Optional card heading rendered as a [SectionLabel].
  final String? title;

  /// Body slot — typically a Column of value rows or a chart.
  final Widget child;

  /// Override the default [_kCardPadding] on all sides.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return Container(
      padding: padding ?? const EdgeInsets.all(_kCardPadding),
      decoration: BoxDecoration(
        color: tokens.bgElev,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: title != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionLabel(text: title!),
                const SizedBox(height: _kTitleBodyGap),
                child,
              ],
            )
          : child,
    );
  }
}
