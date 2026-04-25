import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/daos/trips_dao.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';

// Spacing constants — all multiples of 4 per UI-SPEC.
const double _kFieldGap = 16;
const double _kSectionGap = 24;
const double _kButtonGap = 8;
const double _kLabelGap = 8;

/// Direction enum for the SegmentedButton.
/// Mapped to kDirectionToOffice / kDirectionToHome at save time.
enum TripDirection { toOffice, toHome }

TripDirection _toEnum(String direction) => direction == kDirectionToOffice
    ? TripDirection.toOffice
    : TripDirection.toHome;

String _toConstant(TripDirection d) =>
    d == TripDirection.toOffice ? kDirectionToOffice : kDirectionToHome;

/// Modal bottom sheet for editing a trip's direction and times.
///
/// D-01: invoked via showModalBottomSheet (not Navigator.push).
/// D-02: no named route.
class EditTripSheet extends ConsumerStatefulWidget {
  /// Create the edit sheet for [summary].
  const EditTripSheet({required this.summary, super.key});

  /// The trip to edit. Used to initialise form state.
  final TripSummary summary;

  @override
  ConsumerState<EditTripSheet> createState() => _EditTripSheetState();
}

class _EditTripSheetState extends ConsumerState<EditTripSheet> {
  late TripDirection _direction;
  late DateTime _startTimeUtc;
  late DateTime _endTimeUtc;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    _direction = _toEnum(widget.summary.direction);
    _startTimeUtc = widget.summary.startTime;
    _endTimeUtc = widget.summary.endTime;
  }

  Future<void> _pickStartTime() async {
    final local = _startTimeUtc.toLocal();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (!mounted) return; // Pitfall 1: context.mounted in ConsumerState
    if (picked != null) {
      final updated = DateTime(
        local.year,
        local.month,
        local.day,
        picked.hour,
        picked.minute,
      ).toUtc();
      setState(() {
        _startTimeUtc = updated;
        _timeError = !_endTimeUtc.isAfter(_startTimeUtc)
            ? 'End time must be after start time.'
            : null;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final local = _endTimeUtc.toLocal();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (!mounted) return;
    if (picked != null) {
      final updated = DateTime(
        local.year,
        local.month,
        local.day,
        picked.hour,
        picked.minute,
      ).toUtc();
      setState(() {
        _endTimeUtc = updated;
        _timeError = !updated.isAfter(_startTimeUtc)
            ? 'End time must be after start time.'
            : null;
      });
    }
  }

  Future<void> _save() async {
    if (_timeError != null) return;
    await ref
        .read(tripManagementProvider.notifier)
        .editTrip(
          tripId: widget.summary.id,
          direction: _toConstant(_direction),
          startTimeUtc: _startTimeUtc,
          endTimeUtc: _endTimeUtc,
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
    final timeFormat = DateFormat.jm();

    return Padding(
      padding: EdgeInsets.only(
        left: _kFieldGap,
        right: _kFieldGap,
        bottom: MediaQuery.of(context).viewInsets.bottom + _kFieldGap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: _kSectionGap),
          Text('Edit trip', style: textTheme.titleLarge),
          const SizedBox(height: _kFieldGap),
          Text('Direction', style: textTheme.labelLarge),
          const SizedBox(height: _kLabelGap),
          SegmentedButton<TripDirection>(
            segments: const <ButtonSegment<TripDirection>>[
              ButtonSegment(
                value: TripDirection.toOffice,
                label: Text('To office'),
              ),
              ButtonSegment(
                value: TripDirection.toHome,
                label: Text('To home'),
              ),
            ],
            selected: <TripDirection>{_direction},
            showSelectedIcon: false,
            onSelectionChanged: isSaving
                ? null
                : (s) => setState(() => _direction = s.first),
          ),
          const SizedBox(height: _kFieldGap),
          Text('Start time', style: textTheme.labelLarge),
          const SizedBox(height: _kLabelGap),
          OutlinedButton.icon(
            onPressed: isSaving ? null : _pickStartTime,
            icon: const Icon(Icons.schedule),
            label: Text(timeFormat.format(_startTimeUtc.toLocal())),
          ),
          const SizedBox(height: _kFieldGap),
          Text('End time', style: textTheme.labelLarge),
          const SizedBox(height: _kLabelGap),
          OutlinedButton.icon(
            onPressed: isSaving ? null : _pickEndTime,
            icon: const Icon(Icons.schedule),
            label: Text(timeFormat.format(_endTimeUtc.toLocal())),
          ),
          if (_timeError != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _timeError!,
              style: textTheme.bodyLarge!.copyWith(color: colorScheme.error),
            ),
          ],
          const SizedBox(height: _kSectionGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: _kButtonGap),
              FilledButton(
                onPressed: (isSaving || _timeError != null) ? null : _save,
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
          ),
          const SizedBox(height: _kFieldGap),
        ],
      ),
    );
  }
}
