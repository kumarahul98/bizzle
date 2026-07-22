import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/stats/services/stats_period.dart';

/// Three-segment control (Week / Month / Year) driving
/// [selectedStatsPeriodProvider]. Provider state — not widget state — so that
/// switching the period moves every period-aware card together (Phase 34, Q6).
///
/// Styling mirrors the Trip History `HistoryViewToggle`: selected cell fills
/// with `onSurface`, unselected cells are transparent with dim text.
class StatsPeriodSelector extends ConsumerWidget {
  /// Creates a [StatsPeriodSelector].
  const StatsPeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final selectedBg = Theme.of(context).colorScheme.onSurface;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final selected = ref.watch(selectedStatsPeriodProvider);

    void select(StatsPeriod period) =>
        ref.read(selectedStatsPeriodProvider.notifier).select(period);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderStr),
      ),
      child: Row(
        children: <Widget>[
          _SegmentCell(
            label: kStatsPeriodWeekTab,
            selected: selected is WeekPeriod,
            onTap: () => select(const WeekPeriod()),
            selectedBg: selectedBg,
            selectedText: bgColor,
            unselectedText: tokens.textDim,
          ),
          _SegmentCell(
            label: kStatsPeriodMonthTab,
            selected: selected is MonthPeriod,
            onTap: () => select(const MonthPeriod()),
            selectedBg: selectedBg,
            selectedText: bgColor,
            unselectedText: tokens.textDim,
          ),
          _SegmentCell(
            label: kStatsPeriodYearTab,
            selected: selected is YearPeriod,
            onTap: () => select(const YearPeriod()),
            selectedBg: selectedBg,
            selectedText: bgColor,
            unselectedText: tokens.textDim,
          ),
        ],
      ),
    );
  }
}

class _SegmentCell extends StatelessWidget {
  const _SegmentCell({
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
