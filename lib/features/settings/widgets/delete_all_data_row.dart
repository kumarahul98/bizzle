import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/settings/widgets/settings_row.dart';
import 'package:traevy/sync/delete_trips_controller.dart';

/// Settings "Delete all data" row (Phase 38, DEL-ALL-DATA).
///
/// Tapping opens an error-styled confirm dialog (mirrors the account sheet's
/// `_confirmSignOut` dialog). On confirm,
/// `DeleteTripsController.deleteAllTrips` runs: guests are wiped locally
/// only; signed-in users are purged server-side first. The controller never
/// rethrows, so no try/catch is needed here. The result is surfaced as a
/// SnackBar — success or the fixed error copy — the same feedback mechanism
/// `RestoreRow` uses. Shown in BOTH guest and signed-in Settings → Data.
class DeleteAllDataRow extends ConsumerWidget {
  /// Creates the delete-all-data row.
  const DeleteAllDataRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deleteTripsControllerProvider);
    final inProgress = state is DeleteTripsInProgress;

    return SettingsRow(
      label: kDeleteAllDataRowLabel,
      dangerous: true,
      subtitle: inProgress ? kDeleteAllDataInProgress : null,
      onTap: inProgress ? null : () => _onTap(context, ref),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmDeleteAllData(context);
    if (!(confirmed ?? false)) return;
    if (!context.mounted) return;

    await ref.read(deleteTripsControllerProvider.notifier).deleteAllTrips();

    if (!context.mounted) return;
    final message = _messageFor(ref.read(deleteTripsControllerProvider));
    if (message == null) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Error-styled confirm dialog mirroring the account sheet's
  /// `_confirmSignOut` structure exactly.
  Future<bool?> _confirmDeleteAllData(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(kDeleteAllDataDialogTitle),
        content: const Text(kDeleteAllDataDialogBody),
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
            child: const Text(kDeleteAllDataConfirm),
          ),
        ],
      ),
    );
  }

  /// Map the post-delete [state] to its result SnackBar copy (constants only).
  String? _messageFor(DeleteTripsState state) => switch (state) {
    DeleteTripsSuccess() => kDeleteAllDataSuccessSnackbar,
    DeleteTripsError() => kDeleteAllDataErrorSnackbar,
    _ => null,
  };
}
