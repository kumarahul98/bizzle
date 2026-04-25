import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';
import 'package:traevy/features/trips/services/direction_label_service.dart';

// Spacing constants — all multiples of 4 per UI-SPEC.
const double _kFieldGap = 16;
const double _kSectionGap = 24;
const double _kButtonGap = 8;
const double _kLabelGap = 8;

/// Direction enum for the SegmentedButton.
/// Mapped to kDirectionToOffice / kDirectionToHome at save time.
enum _TripDirection { toOffice, toHome }

_TripDirection _toEnum(String direction) => direction == kDirectionToOffice
    ? _TripDirection.toOffice
    : _TripDirection.toHome;

String _toConstant(_TripDirection d) =>
    d == _TripDirection.toOffice ? kDirectionToOffice : kDirectionToHome;

/// Modal bottom sheet for manually entering a forgotten commute trip.
///
/// D-09: invoked from the home screen FAB via [showModalBottomSheet]
/// (not a named route).
/// D-10: saved with isManualEntry=true, distanceMeters=0, timeMovingSeconds=0,
///       timeStuckSeconds=0, routePolyline=''.
/// D-11: HH:MM validation via parseHhMm; Save is disabled until valid.
class ManualEntrySheet extends ConsumerStatefulWidget {
  /// Create the manual entry sheet.
  const ManualEntrySheet({super.key});

  @override
  ConsumerState<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<ManualEntrySheet> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _durationController = TextEditingController();
  String? _durationError;
  late _TripDirection _direction;

  @override
  void initState() {
    super.initState();
    // Default direction from current time using DirectionLabelService.
    // Uses kDefaultDirectionCutoffHour (synchronous — no DB read needed
    // for default).
    const labeler = DirectionLabelService();
    final defaultDirection = labeler.label(
      DateTime.now(), // already local
      kDefaultDirectionCutoffHour,
      kDefaultDirectionCutoffHour,
    );
    _direction = _toEnum(defaultDirection);
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // cannot enter future trips (ASVS V5)
    );
    if (!mounted) return; // Pitfall 1
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _validateDuration(String value) {
    final result = parseHhMm(value);
    setState(() {
      if (value.trim().isEmpty) {
        _durationError = 'Enter a duration like 0:45.';
      } else if (result == null) {
        _durationError = 'Use HH:MM format between 0:01 and 23:59.';
      } else {
        _durationError = null;
      }
    });
  }

  Future<void> _save() async {
    final duration = parseHhMm(_durationController.text);
    if (duration == null) {
      _validateDuration(_durationController.text);
      return;
    }
    // Pitfall 6: build local midnight then convert to UTC.
    final startUtc = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    ).toUtc();
    final endUtc = startUtc.add(duration);

    await ref
        .read(tripManagementProvider.notifier)
        .insertManualTrip(
          startTimeUtc: startUtc,
          endTimeUtc: endUtc,
          direction: _toConstant(_direction),
        );
    if (!mounted) return; // Pitfall 1
    final state = ref.read(tripManagementProvider);
    if (state is TripManagementSaved) {
      ref.read(tripManagementProvider.notifier).reset();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip added')),
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
    final dateFormat = DateFormat.yMMMEd();
    final durationText = _durationController.text;
    final isFormValid = parseHhMm(durationText) != null;

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
          Text('Add missed commute', style: textTheme.titleLarge),
          const SizedBox(height: _kFieldGap),
          Text('Date', style: textTheme.labelLarge),
          const SizedBox(height: _kLabelGap),
          OutlinedButton.icon(
            onPressed: isSaving ? null : _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(dateFormat.format(_selectedDate)),
          ),
          const SizedBox(height: _kFieldGap),
          Text('Duration (HH:MM)', style: textTheme.labelLarge),
          const SizedBox(height: _kLabelGap),
          TextField(
            controller: _durationController,
            enabled: !isSaving,
            keyboardType: TextInputType.datetime,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp('[0-9:]')),
            ],
            maxLength: 5,
            decoration: InputDecoration(
              hintText: '0:45',
              filled: true,
              errorText: _durationError,
              counterText: '', // hide the maxLength counter
            ),
            onChanged: _validateDuration,
          ),
          const SizedBox(height: _kFieldGap),
          Text('Direction', style: textTheme.labelLarge),
          const SizedBox(height: _kLabelGap),
          SegmentedButton<_TripDirection>(
            segments: const <ButtonSegment<_TripDirection>>[
              ButtonSegment(
                value: _TripDirection.toOffice,
                label: Text('To office'),
              ),
              ButtonSegment(
                value: _TripDirection.toHome,
                label: Text('To home'),
              ),
            ],
            selected: <_TripDirection>{_direction},
            showSelectedIcon: false,
            onSelectionChanged: isSaving
                ? null
                : (s) => setState(() => _direction = s.first),
          ),
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
                onPressed: (isSaving || !isFormValid) ? null : _save,
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
