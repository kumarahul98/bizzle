import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// View mode for the trip history screen.
enum HistoryView {
  /// Scrollable list of date-grouped trip sections.
  list,

  /// Calendar month view with day-tap filtering.
  calendar,
}

/// Pill segmented control for switching between List and Calendar views.
///
/// Selected: `onSurface` background + `bg` text.
/// Unselected: transparent + `textDim` text.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §5 Trip History.
class HistoryViewToggle extends StatelessWidget {
  /// Creates a [HistoryViewToggle].
  const HistoryViewToggle({
    required this.selectedView,
    required this.onChanged,
    super.key,
  });

  /// The currently selected [HistoryView].
  final HistoryView selectedView;

  /// Called when the user selects a different view.
  final ValueChanged<HistoryView> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    // tokens.text maps to colorScheme.onSurface in buildLightTheme.
    final selectedBg = colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderStr),
      ),
      child: Row(
        children: <Widget>[
          _ToggleCell(
            label: 'List',
            selected: selectedView == HistoryView.list,
            onTap: () => onChanged(HistoryView.list),
            selectedBg: selectedBg,
            selectedText: bgColor,
            unselectedText: tokens.textDim,
          ),
          _ToggleCell(
            label: 'Calendar',
            selected: selectedView == HistoryView.calendar,
            onTap: () => onChanged(HistoryView.calendar),
            selectedBg: selectedBg,
            selectedText: bgColor,
            unselectedText: tokens.textDim,
          ),
        ],
      ),
    );
  }
}

class _ToggleCell extends StatelessWidget {
  const _ToggleCell({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedBg,
    required this.selectedText,
    required this.unselectedText,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedBg;
  final Color selectedText;
  final Color unselectedText;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TraevyFonts.ui(
              size: 13,
              weight: FontWeight.w600,
              color: selected ? selectedText : unselectedText,
            ),
          ),
        ),
      ),
    );
  }
}
