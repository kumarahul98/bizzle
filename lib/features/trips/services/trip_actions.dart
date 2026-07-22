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

/// Restore a soft-deleted trip from the Trash (Phase 35, D-05).
///
/// No confirmation — restore is non-destructive. Shows a success or error
/// snackbar and resets the shared notifier afterwards. `context.mounted` is
/// checked after the await before touching the UI.
Future<void> handleRestoreTrip(
  BuildContext context,
  WidgetRef ref,
  String tripId,
) async {
  await ref.read(tripManagementProvider.notifier).restoreTrip(tripId);
  if (!context.mounted) return;
  final state = ref.read(tripManagementProvider);
  if (state is TripManagementSaved) {
    ref.read(tripManagementProvider.notifier).reset();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(kTrashRestoredSnackbar)),
    );
  } else if (state is TripManagementError) {
    ref.read(tripManagementProvider.notifier).reset();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(kTrashActionErrorSnackbar)),
    );
  }
}

/// Permanently (hard) delete a trip from the Trash (Phase 35, D-05).
///
/// This one really is irreversible, so it confirms first (two-step guard:
/// dialog dismissal counts as cancel via `confirmed ?? false`). On confirm it
/// hard-deletes locally — cascade removes breaks and stuck segments — and
/// enqueues nothing (the tombstone was pushed at soft-delete time).
/// `context.mounted` is checked after every await.
Future<void> handleDeleteTripPermanently(
  BuildContext context,
  WidgetRef ref,
  String tripId,
) async {
  final colorScheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(kTrashPermanentDeleteDialogTitle),
      content: const Text(kTrashPermanentDeleteDialogBody),
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
          child: const Text(kTrashPermanentDeleteConfirm),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (confirmed ?? false) {
    await ref
        .read(tripManagementProvider.notifier)
        .deleteTripPermanently(
          tripId,
        );
    if (!context.mounted) return;
    final state = ref.read(tripManagementProvider);
    if (state is TripManagementSaved) {
      ref.read(tripManagementProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kTrashPermanentlyDeletedSnackbar)),
      );
    } else if (state is TripManagementError) {
      ref.read(tripManagementProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kTrashActionErrorSnackbar)),
      );
    }
  }
}
