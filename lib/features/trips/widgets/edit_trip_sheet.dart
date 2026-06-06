import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';
import 'package:traevy/features/trips/services/trip_edit_recompute.dart';
import 'package:traevy/features/trips/widgets/break_editor_list.dart';
import 'package:traevy/features/trips/widgets/break_row.dart';
import 'package:traevy/features/trips/widgets/edit_recompute_preview.dart';

// Spacing constants — all multiples of 4 per UI-SPEC.
const double _kFieldGap = 16;
const double _kSectionGap = 24;
const double _kButtonGap = 8;
const double _kLabelGap = 8;

// A newly-added break defaults to a 5-minute segment anchored at trip start.
const Duration _kDefaultBreakLength = Duration(minutes: 5);

// Display format for the start/end date+time buttons (local time shown).
final DateFormat _kDateTimeFormat = DateFormat('EEE, d MMM · HH:mm');

/// Direction enum for the SegmentedButton.
/// Mapped to kDirectionToOffice / kDirectionToHome at save time.
enum TripDirection { toOffice, toHome }

TripDirection _toEnum(String direction) => direction == kDirectionToOffice
    ? TripDirection.toOffice
    : TripDirection.toHome;

String _toConstant(TripDirection d) =>
    d == TripDirection.toOffice ? kDirectionToOffice : kDirectionToHome;

/// Modal bottom sheet for the full trip edit (Phase 19): direction, start/end
/// date+time, an add/edit/remove break editor, a live recompute preview, and
/// service-driven inline validation that gates Save.
///
/// All validation/recompute math lives in [TripEditRecompute]; the sheet only
/// reads it (live, in-memory — no Drift writes while editing, D-11) and on Save
/// hands the computed numbers to the extended `editTrip` write path (D-12).
class EditTripSheet extends ConsumerStatefulWidget {
  /// Create the edit sheet for [summary], seeded with [initialBreaks].
  const EditTripSheet({
    required this.summary,
    this.initialBreaks = const <EditBreakSegment>[],
    super.key,
  });

  /// The trip to edit. Used to initialise form state.
  final TripSummary summary;

  /// The trip's existing breaks (closed segments only), used to seed the
  /// embedded editor. Empty for trips with no breaks.
  final List<EditBreakSegment> initialBreaks;

  @override
  ConsumerState<EditTripSheet> createState() => _EditTripSheetState();
}

class _EditTripSheetState extends ConsumerState<EditTripSheet> {
  late TripDirection _direction;
  late DateTime _startTimeUtc;
  late DateTime _endTimeUtc;
  late List<EditBreakSegment> _breaks;

  // The ORIGINAL pre-edit moving/stuck — captured once so repeated edits
  // rescale from the original ratio, never a previously-rescaled value (D-01).
  late int _origMoving;
  late int _origStuck;

  // Live recompute state (in-memory only).
  EditValidationResult _validation = const EditValid();
  int _activeSeconds = 0;
  int _movingSeconds = 0;
  int _stuckSeconds = 0;

  @override
  void initState() {
    super.initState();
    _direction = _toEnum(widget.summary.direction);
    _startTimeUtc = widget.summary.startTime;
    _endTimeUtc = widget.summary.endTime;
    _breaks = List<EditBreakSegment>.of(widget.initialBreaks);
    _origMoving = widget.summary.timeMovingSeconds;
    _origStuck = widget.summary.timeStuckSeconds;
    _recompute();
  }

  /// Re-run validation + recompute on every change. Purely in-memory — no
  /// Drift writes happen here (D-11). When valid, preview values are derived
  /// from the SAME service calls Save uses (T-19-07: single code path).
  void _recompute() {
    final result = TripEditRecompute.validate(
      tripStart: _startTimeUtc,
      tripEnd: _endTimeUtc,
      breaks: _breaks,
    );
    _validation = result;
    if (result is EditValid) {
      _activeSeconds = TripEditRecompute.activeSeconds(
        _startTimeUtc,
        _endTimeUtc,
        _breaks,
      );
      final traffic = TripEditRecompute.rescaleTraffic(
        origMoving: _origMoving,
        origStuck: _origStuck,
        newActiveSeconds: _activeSeconds,
      );
      _movingSeconds = traffic.moving;
      _stuckSeconds = traffic.stuck;
    }
  }

  Future<void> _pickStart() async {
    final picked = await pickLocalDateTimeAsUtc(context, _startTimeUtc);
    if (picked != null) _applyWindow(start: picked);
  }

  Future<void> _pickEnd() async {
    final picked = await pickLocalDateTimeAsUtc(context, _endTimeUtc);
    if (picked != null) _applyWindow(end: picked);
  }

  /// Apply a start/end change, clamping breaks into the new window (D-10) and
  /// surfacing the "breaks adjusted" snackbar when any was clamped/dropped.
  void _applyWindow({DateTime? start, DateTime? end}) {
    final newStart = start ?? _startTimeUtc;
    final newEnd = end ?? _endTimeUtc;
    final clamped = TripEditRecompute.clampToWindow(
      newStart: newStart,
      newEnd: newEnd,
      breaks: _breaks,
    );
    setState(() {
      _startTimeUtc = newStart;
      _endTimeUtc = newEnd;
      _breaks = clamped.breaks;
      _recompute();
    });
    if (clamped.adjusted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kEditBreaksAdjustedSnackbar)),
      );
    }
  }

  void _onBreaksChanged(List<EditBreakSegment> next) {
    setState(() {
      _breaks = next;
      _recompute();
    });
  }

  Future<void> _save() async {
    if (_validation is! EditValid) return;
    final pausedSeconds =
        _endTimeUtc.difference(_startTimeUtc).inSeconds - _activeSeconds;
    await ref
        .read(tripManagementProvider.notifier)
        .editTrip(
          tripId: widget.summary.id,
          direction: _toConstant(_direction),
          startTimeUtc: _startTimeUtc,
          endTimeUtc: _endTimeUtc,
          breaks: _breaks,
          totalPausedSeconds: pausedSeconds,
          timeMovingSeconds: _movingSeconds,
          timeStuckSeconds: _stuckSeconds,
          durationSecondsOverride: _activeSeconds,
          markEdited: true,
        );
    if (!mounted) return;
    final state = ref.read(tripManagementProvider);
    if (state is TripManagementSaved) {
      ref.read(tripManagementProvider.notifier).reset();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip updated')),
      );
    } else if (state is TripManagementError) {
      ref.read(tripManagementProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save the trip. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final managementState = ref.watch(tripManagementProvider);
    final isSaving = managementState is TripManagementSaving;
    final invalid = _validation is EditInvalid;

    return Padding(
      padding: EdgeInsets.only(
        left: _kFieldGap,
        right: _kFieldGap,
        bottom: MediaQuery.of(context).viewInsets.bottom + _kFieldGap,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: _kSectionGap),
            Text('Edit trip', style: textTheme.titleLarge),
            const SizedBox(height: _kFieldGap),
            _DirectionField(
              direction: _direction,
              enabled: !isSaving,
              onChanged: (d) => setState(() => _direction = d),
            ),
            const SizedBox(height: _kFieldGap),
            _DateTimeField(
              label: kEditStartDateTimeLabel,
              valueLabel: _kDateTimeFormat.format(_startTimeUtc.toLocal()),
              onPressed: isSaving ? null : _pickStart,
            ),
            const SizedBox(height: _kFieldGap),
            _DateTimeField(
              label: kEditEndDateTimeLabel,
              valueLabel: _kDateTimeFormat.format(_endTimeUtc.toLocal()),
              onPressed: isSaving ? null : _pickEnd,
            ),
            const SizedBox(height: _kSectionGap),
            BreakEditorList(
              breaks: _breaks,
              onChanged: _onBreaksChanged,
              defaultStart: _startTimeUtc,
              defaultEnd: _startTimeUtc.add(_kDefaultBreakLength),
            ),
            const SizedBox(height: _kSectionGap),
            EditRecomputePreview(
              activeSeconds: _activeSeconds,
              movingSeconds: _movingSeconds,
              stuckSeconds: _stuckSeconds,
            ),
            if (_validation case EditInvalid(:final message)) ...<Widget>[
              const SizedBox(height: _kLabelGap),
              Text(
                message,
                style: textTheme.bodyLarge!.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: _kSectionGap),
            _ActionRow(
              isSaving: isSaving,
              saveEnabled: !isSaving && !invalid,
              onCancel: () => Navigator.of(context).pop(),
              onSave: _save,
            ),
            const SizedBox(height: _kFieldGap),
          ],
        ),
      ),
    );
  }
}

/// Direction label + SegmentedButton.
class _DirectionField extends StatelessWidget {
  const _DirectionField({
    required this.direction,
    required this.enabled,
    required this.onChanged,
  });

  final TripDirection direction;
  final bool enabled;
  final ValueChanged<TripDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Direction', style: textTheme.labelLarge),
        const SizedBox(height: _kLabelGap),
        SegmentedButton<TripDirection>(
          segments: const <ButtonSegment<TripDirection>>[
            ButtonSegment(
              value: TripDirection.toOffice,
              label: Text('To office'),
            ),
            ButtonSegment(value: TripDirection.toHome, label: Text('To home')),
          ],
          selected: <TripDirection>{direction},
          showSelectedIcon: false,
          onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
        ),
      ],
    );
  }
}

/// A labelled start/end date+time picker button.
class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.valueLabel,
    required this.onPressed,
  });

  final String label;
  final String valueLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: textTheme.labelLarge),
        const SizedBox(height: _kLabelGap),
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.event_rounded),
          label: Text(valueLabel),
        ),
      ],
    );
  }
}

/// Cancel + Save action row.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.isSaving,
    required this.saveEnabled,
    required this.onCancel,
    required this.onSave,
  });

  final bool isSaving;
  final bool saveEnabled;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
        const SizedBox(width: _kButtonGap),
        FilledButton(
          onPressed: saveEnabled ? onSave : null,
          child: isSaving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
