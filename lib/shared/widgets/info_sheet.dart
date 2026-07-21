import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';

const double _kIconSize = 16;
const double _kIconTapTarget = 32;
const double _kSheetHorizontalPadding = 20;

/// Show a plain-language explainer sheet (Phase 31, D-08).
///
/// Styled after `showSignInSheet` — `showModalBottomSheet` on
/// `surfaceContainerLowest` with a drag handle — so the app has one
/// explanation surface rather than three inconsistent ones. Phases 32 and 33
/// consume this for the weekly summary and auto-pause explanations.
///
/// [title] and [body] must come from `constants.dart` (CLAUDE.md: no
/// hardcoded strings), and must be free of technical jargon — these sheets
/// exist precisely because the underlying mechanic is not self-evident.
Future<void> showInfoSheet(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _InfoSheetContent(title: title, body: body),
  );
}

/// A small tappable info icon that opens [showInfoSheet] with [title] and
/// [body].
///
/// Sized to a [_kIconTapTarget] square so it stays comfortably tappable beside
/// a compact label without the icon itself growing visually heavy.
class InfoIconButton extends StatelessWidget {
  /// Create an info icon that explains [title] / [body] when tapped.
  const InfoIconButton({required this.title, required this.body, super.key});

  /// Explainer sheet heading.
  final String title;

  /// Explainer sheet body copy.
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return SizedBox(
      width: _kIconTapTarget,
      height: _kIconTapTarget,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: _kIconSize,
        tooltip: kInfoIconSemanticLabel,
        icon: Icon(Icons.info_outline_rounded, color: tokens.textDim),
        onPressed: () => showInfoSheet(context, title: title, body: body),
      ),
    );
  }
}

/// Sheet body: heading, explanation, and a single dismiss action.
class _InfoSheetContent extends StatelessWidget {
  const _InfoSheetContent({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _kSheetHorizontalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 8),
            Text(
              title,
              style: TraevyFonts.ui(
                size: 22,
                weight: FontWeight.w700,
                letterSpacing: -0.6,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: TraevyFonts.ui(
                size: 16,
                color: tokens.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(kInfoSheetDismissLabel),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
