import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/settings/widgets/settings_row.dart';
import 'package:traevy/sync/restore_controller.dart';

/// Settings "Restore from cloud" row (Phase 11, SYNC-03, D-09).
///
/// Tapping triggers [RestoreController.restore] (download all cloud trips →
/// single dedupe-by-UUID Drift batch) and surfaces the result as a SnackBar:
/// "Restored N trips" / "Already up to date" / the fixed restore-error copy —
/// all from constants (no hardcoded strings). The controller catches its own
/// errors and never rethrows, so the tap can never crash or freeze the UI
/// (T-11-03-02); no try/catch is needed at the call site.
///
/// While a restore is in flight the subtitle shows the "Restoring…" copy and
/// the tap is guarded against re-entry. Only shown in the signed-in Account
/// section.
class RestoreRow extends ConsumerWidget {
  /// Creates the restore-from-cloud row.
  const RestoreRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restoreControllerProvider);
    final isRestoring = state is RestoreRestoring;

    return SettingsRow(
      label: kSettingsRestoreRowLabel,
      subtitle: isRestoring ? kSettingsRestoreInProgress : null,
      onTap: isRestoring ? null : () => _onTap(context, ref),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    await ref.read(restoreControllerProvider.notifier).restore();
    // Guard post-await context use — the screen lives in MainShell.
    if (!context.mounted) return;
    final message = _messageFor(ref.read(restoreControllerProvider));
    if (message == null) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Map the post-restore [state] to its result SnackBar copy (constants only).
  String? _messageFor(RestoreState state) => switch (state) {
    RestoreSuccess(:final count) when count == 0 => kSettingsRestoreUpToDate,
    RestoreSuccess(:final count) =>
      '$kSettingsRestoreResultTemplate $count ${_tripNoun(count)}',
    RestoreError() => kSettingsRestoreError,
    _ => null,
  };

  /// Singular / plural trip noun for the "Restored N trips" copy.
  String _tripNoun(int count) =>
      count == 1 ? kRestoreTripNounSingular : kRestoreTripNounPlural;
}
