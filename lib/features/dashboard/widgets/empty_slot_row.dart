import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// Empty trip slot placeholder row — dashed circle with "+" icon and
/// a subtitle prompting the user to start a trip or add manually.
///
/// Used inside TodaySection when fewer than 2 trips are recorded today.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §3 Empty slot row.
class EmptySlotRow extends StatelessWidget {
  /// Create the empty slot row.
  const EmptySlotRow({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tokens.borderStr, width: 1.5),
            ),
            child: Center(
              child: Icon(
                Icons.add_rounded,
                size: 18,
                color: tokens.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evening commute',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tokens.textDim,
                ),
              ),
              Text(
                'Tap START or add manually',
                style: TraevyFonts.ui(size: 11.5, color: tokens.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
