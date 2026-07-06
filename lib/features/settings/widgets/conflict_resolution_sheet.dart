import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/sync/restore_conflict.dart';
import 'package:traevy/sync/restore_controller.dart';
import 'package:drift/drift.dart' as drift;

class ConflictResolutionSheet extends ConsumerStatefulWidget {
  const ConflictResolutionSheet({
    super.key,
    required this.conflicts,
  });

  final List<RestoreConflict> conflicts;

  @override
  ConsumerState<ConflictResolutionSheet> createState() =>
      _ConflictResolutionSheetState();
}

class _ConflictResolutionSheetState
    extends ConsumerState<ConflictResolutionSheet> {
  final Map<String, String> _resolutions = {}; // tripId -> action
  final Map<String, Map<String, String>> _mergeSelections =
      {}; // tripId -> field -> 'local'/'cloud'

  Future<void> _applyAll(String defaultAction) async {
    final tripsDao = ref.read(tripsDaoProvider);
    int resolvedCount = 0;

    for (final conflict in widget.conflicts) {
      final action = _resolutions[conflict.localTrip.id] ?? defaultAction;

      if (action == kConflictKeepLocal) {
        continue;
      }

      final companion = conflict.cloudTrip.copyWith(
        id: drift.Value(conflict.localTrip.id),
        updatedAt: drift.Value(DateTime.now().toUtc()),
      );

      if (action == kConflictUseCloud) {
        await tripsDao.updateTrip(companion);
        resolvedCount++;
      } else if (action == kConflictMerge) {
        final localTrip = conflict.localTrip;
        final cloudTrip = conflict.cloudTrip;
        final selections = _mergeSelections[localTrip.id] ?? {};

        final merged = cloudTrip.copyWith(
          id: drift.Value(localTrip.id),
          startTime: selections['startTime'] == 'local'
              ? drift.Value(localTrip.startTime)
              : cloudTrip.startTime,
          endTime: selections['endTime'] == 'local'
              ? drift.Value(localTrip.endTime)
              : cloudTrip.endTime,
          durationSeconds: selections['durationSeconds'] == 'local'
              ? drift.Value(localTrip.durationSeconds)
              : cloudTrip.durationSeconds,
          distanceMeters: selections['distanceMeters'] == 'local'
              ? drift.Value(localTrip.distanceMeters)
              : cloudTrip.distanceMeters,
          direction: selections['direction'] == 'local'
              ? drift.Value(localTrip.direction)
              : cloudTrip.direction,
          updatedAt: drift.Value(DateTime.now().toUtc()),
        );
        await tripsDao.updateTrip(merged);
        resolvedCount++;
      }
    }

    ref
        .read(restoreControllerProvider.notifier)
        .resolveConflicts(resolvedCount);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              kConflictResolutionTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.conflicts.length,
                itemBuilder: (context, index) {
                  final conflict = widget.conflicts[index];
                  final tripId = conflict.localTrip.id;
                  final selectedAction =
                      _resolutions[tripId] ?? kConflictKeepLocal;

                  final isOverlap = conflict is OverlapConflict;
                  final title = isOverlap
                      ? 'Overlap Conflict'
                      : 'Modified Conflict';

                  return ExpansionTile(
                    title: Text(title),
                    subtitle: Text(
                      'Trip ID: $tripId\nSelected: $selectedAction',
                    ),
                    children: [
                      RadioListTile<String>(
                        title: const Text(kConflictKeepLocal),
                        value: kConflictKeepLocal,
                        groupValue: selectedAction,
                        onChanged: (val) =>
                            setState(() => _resolutions[tripId] = val!),
                      ),
                      RadioListTile<String>(
                        title: const Text(kConflictUseCloud),
                        value: kConflictUseCloud,
                        groupValue: selectedAction,
                        onChanged: (val) =>
                            setState(() => _resolutions[tripId] = val!),
                      ),
                      RadioListTile<String>(
                        title: const Text(kConflictMerge),
                        value: kConflictMerge,
                        groupValue: selectedAction,
                        onChanged: (val) =>
                            setState(() => _resolutions[tripId] = val!),
                      ),
                      if (selectedAction == kConflictMerge)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 32.0,
                            right: 16.0,
                            bottom: 8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final field in [
                                'startTime',
                                'endTime',
                                'durationSeconds',
                                'distanceMeters',
                                'direction',
                              ])
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(field),
                                    SegmentedButton<String>(
                                      segments: const [
                                        ButtonSegment(
                                          value: 'local',
                                          label: Text('Local'),
                                        ),
                                        ButtonSegment(
                                          value: 'cloud',
                                          label: Text('Cloud'),
                                        ),
                                      ],
                                      selected: {
                                        _mergeSelections[tripId]?[field] ??
                                            'cloud',
                                      },
                                      onSelectionChanged: (set) {
                                        setState(() {
                                          _mergeSelections.putIfAbsent(
                                            tripId,
                                            () => {},
                                          )[field] = set.first;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () => _applyAll(kConflictKeepLocal),
                  child: const Text('Keep All Local'),
                ),
                FilledButton(
                  onPressed: () => _applyAll(kConflictUseCloud),
                  child: const Text('Use All Cloud'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _applyAll(kConflictMerge),
              child: const Text('Merge All'),
            ),
          ],
        ),
      ),
    );
  }
}
