import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';

/// Show a delete confirmation dialog and call
/// [TripManagementNotifier.deleteTrip] on confirmation.
///
/// Two-step guard (T-03-14): user must tap the destructive 'Delete'
/// button explicitly; dialog dismissal is treated as cancel via
/// `confirmed ?? false`.
///
/// Reused by DashboardScreen and HistoryScreen trip cards (D-08).
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
      title: const Text(kTripDeleteDialogTitle),
      content: const Text(kTripDeleteDialogBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(kDialogCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(kTripDeleteConfirm),
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
        const SnackBar(content: Text(kTripDeletedSnackbar)),
      );
    } else if (state is TripManagementError) {
      ref.read(tripManagementProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(kTripDeleteErrorSnackbar),
        ),
      );
    }
  }
}
