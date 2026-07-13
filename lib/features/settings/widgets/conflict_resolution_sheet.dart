import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/sync/merge_resolution.dart';
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
    final breaksDao = ref.read(tripBreaksDaoProvider);
    final database = ref.read(appDatabaseProvider);
    int resolvedCount = 0;

    for (final conflict in widget.conflicts) {
      final action = _resolutions[conflict.localTrip.id] ?? defaultAction;
      final localTripId = conflict.localTrip.id;

      if (action == kConflictKeepLocal) {
        continue;
      }

      final companion = conflict.cloudTrip.copyWith(
        id: drift.Value(localTripId),
        updatedAt: drift.Value(DateTime.now().toUtc()),
      );

      if (action == kConflictUseCloud) {
        // T-26-16/T-26-17: cloud breaks ride along with "Use Cloud" too
        // (closing the SC5 gap beyond Merge alone), remapped to the LOCAL
        // trip id (an OverlapConflict's cloudBreaks carry a DIFFERENT
        // original tripId) and written atomically with the trip update.
        final remappedBreaks = [
          for (final b in conflict.cloudBreaks)
            b.copyWith(tripId: drift.Value(localTripId)),
        ];
        await database.transaction(() async {
          await tripsDao.updateTrip(companion);
          await breaksDao.deleteBreaksForTrip(localTripId);
          if (remappedBreaks.isNotEmpty) {
            await breaksDao.insertBreaks(remappedBreaks);
          }
        });
        resolvedCount++;
      } else if (action == kConflictMerge) {
        final localTrip = conflict.localTrip;
        final cloudTrip = conflict.cloudTrip;
        final selections = _mergeSelections[localTrip.id] ?? {};

        final result = resolveMerge(
          local: localTrip,
          cloud: cloudTrip,
          selections: selections,
          localBreaks: conflict.localBreaks,
          cloudBreaks: conflict.cloudBreaks,
        );
        await database.transaction(() async {
          await tripsDao.updateTrip(result.trip);
          await breaksDao.deleteBreaksForTrip(localTripId);
          if (result.breaks.isNotEmpty) {
            await breaksDao.insertBreaks(result.breaks);
          }
        });
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
                      // D-05: read-only breaks-differ indicator, informational
                      // for ANY resolution choice (not gated behind Merge).
                      // No per-break controls — just a visible count line.
                      if (conflict.localBreaks.length !=
                          conflict.cloudBreaks.length)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16.0,
                            right: 16.0,
                            bottom: 8.0,
                          ),
                          child: Text(
                            kConflictBreaksDifferTemplate
                                .replaceAll(
                                  '{local}',
                                  conflict.localBreaks.length.toString(),
                                )
                                .replaceAll(
                                  '{cloud}',
                                  conflict.cloudBreaks.length.toString(),
                                ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
                                            'local',
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
