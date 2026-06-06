import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/trips/services/trip_edit_recompute.dart';

/// Compact date+time format for the break rows (local time shown).
final DateFormat _kBreakFormat = DateFormat('d MMM · HH:mm');

/// Prompt the user for a date then a time, composing a LOCAL [DateTime] and
/// returning it as UTC for storage (CLAUDE.md: UTC stored, local shown).
///
/// Returns null if the user cancels either dialog. [initialUtc] seeds both
/// dialogs in local time. Shared by [BreakRow] and the edit sheet's start/end
/// pickers so date+time selection is identical everywhere (D-09).
Future<DateTime?> pickLocalDateTimeAsUtc(
  BuildContext context,
  DateTime initialUtc,
) async {
  final local = initialUtc.toLocal();
  final date = await showDatePicker(
    context: context,
    initialDate: local,
    firstDate: DateTime(local.year - 2),
    lastDate: DateTime(local.year + 2),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(local),
  );
  if (time == null) return null;
  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  ).toUtc();
}

/// A single editable break segment row (Phase 19, D-09): a start date+time
/// button, an end date+time button, and a remove action. Pure presentation —
/// edits flow back via [onChanged]/[onRemove]; no persistence here.
class BreakRow extends StatelessWidget {
  /// Create a row for [segment]. [onChanged] fires with the updated segment
  /// when either endpoint is re-picked; [onRemove] fires when removed.
  const BreakRow({
    required this.segment,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  /// The break segment this row renders (start/end in UTC).
  final EditBreakSegment segment;

  /// Called with a new segment when the user re-picks start or end.
  final ValueChanged<EditBreakSegment> onChanged;

  /// Called when the user removes this break.
  final VoidCallback onRemove;

  Future<void> _pickStart(BuildContext context) async {
    final picked = await pickLocalDateTimeAsUtc(context, segment.start);
    if (picked != null) {
      onChanged(EditBreakSegment(start: picked, end: segment.end));
    }
  }

  Future<void> _pickEnd(BuildContext context) async {
    final picked = await pickLocalDateTimeAsUtc(context, segment.end);
    if (picked != null) {
      onChanged(EditBreakSegment(start: segment.start, end: picked));
    }
  }

  String _label(String prefix, DateTime utc) =>
      '$prefix ${_kBreakFormat.format(utc.toLocal())}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickStart(context),
              child: Text(
                _label(kEditStartDateTimeLabel, segment.start),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickEnd(context),
              child: Text(
                _label(kEditEndDateTimeLabel, segment.end),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Remove break',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
