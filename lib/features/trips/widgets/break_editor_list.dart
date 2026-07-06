import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/trips/services/trip_edit_recompute.dart';
import 'package:traevy/features/trips/widgets/break_row.dart';

/// Break-list editor (Phase 19): a section header, one [BreakRow] per segment,
/// and an "Add break" button.
///
/// Pure presentation: add/edit/remove each produce a NEW immutable list passed
/// up via [onChanged] — the list is never mutated in place. A new break uses
/// [defaultStart]/[defaultEnd] so the parent can supply an in-window default.
class BreakEditorList extends StatelessWidget {
  /// Create the editor bound to [breaks]. [onChanged] receives the new list on
  /// every add/edit/remove. [defaultStart]/[defaultEnd] seed an added break.
  const BreakEditorList({
    required this.breaks,
    required this.onChanged,
    required this.defaultStart,
    required this.defaultEnd,
    super.key,
  });

  /// The current break segments (UTC).
  final List<EditBreakSegment> breaks;

  /// Called with the updated list after any add/edit/remove.
  final ValueChanged<List<EditBreakSegment>> onChanged;

  /// Start of a newly-added break (an in-window default from the parent).
  final DateTime defaultStart;

  /// End of a newly-added break.
  final DateTime defaultEnd;

  void _edit(int index, EditBreakSegment updated) {
    final next = List<EditBreakSegment>.of(breaks);
    next[index] = updated;
    onChanged(next);
  }

  void _remove(int index) {
    final next = List<EditBreakSegment>.of(breaks)..removeAt(index);
    onChanged(next);
  }

  void _add() {
    onChanged(<EditBreakSegment>[
      ...breaks,
      EditBreakSegment(start: defaultStart, end: defaultEnd),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(kEditBreaksSectionLabel, style: textTheme.labelLarge),
        const SizedBox(height: 8),
        for (var i = 0; i < breaks.length; i++)
          BreakRow(
            key: ValueKey<int>(i),
            segment: breaks[i],
            onChanged: (updated) => _edit(i, updated),
            onRemove: () => _remove(i),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(kEditAddBreakLabel),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: tokens.border),
            ),
          ),
        ),
      ],
    );
  }
}
