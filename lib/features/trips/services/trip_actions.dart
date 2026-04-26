import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';

/// Show a delete confirmation dialog and call
/// [TripManagementNotifier.deleteTrip] on confirmation.
///
/// Two-step guard (T-03-14): user must tap the destructive 'Delete'
/// button explicitly; dialog dismissal is treated as cancel via
/// `confirmed ?? false`.
///
/// Reused by HomeScreen and HistoryScreen trip cards (D-08).
/// Pitfall 7 mitigation: context.mounted is checked after every await.
Future<void> handleDeleteTrip(
  BuildContext context,
  WidgetRef ref,
  String tripId,
) async {
  final colorScheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete trip?'),
      content: const Text('This trip will be permanently removed.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (confirmed ?? false) {
    await ref.read(tripManagementProvider.notifier).deleteTrip(tripId);
    if (!context.mounted) return;
    final state = ref.read(tripManagementProvider);
    if (state is TripManagementSaved) {
      ref.read(tripManagementProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip deleted')),
      );
    } else if (state is TripManagementError) {
      ref.read(tripManagementProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't delete the trip. Try again."),
        ),
      );
    }
  }
}
