import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/settings/widgets/settings_row.dart';
import 'package:traevy/sync/sync_engine.dart';
import 'package:traevy/sync/sync_status.dart';

/// Settings cloud-sync status row (Phase 11, SYNC-03, D-09).
///
/// Renders the live [SyncStatus] as a subtitle under the "Cloud sync" label,
/// using only copy constants (no hardcoded strings). When the status is the
/// [SyncFailed] variant the row becomes tappable and invokes the Plan 02 engine
/// retry entry point `ref.read(syncEngineProvider).retryFailed()` — the PLAIN
/// `Provider<SyncEngine>` instance method (never `.notifier`; `retryFailed()`
/// already clears the backoff window, resets failed rows, and re-drains, so no
/// separate reset/drain calls are made here).
///
/// The pending count is read from [pendingSyncCountProvider] (derived from
/// `SyncQueueDao.watchPending()`) so the "$N pending" subtitle stays live as
/// trips enqueue or drain. Only shown in the signed-in Account section.
class CloudSyncRow extends ConsumerWidget {
  /// Creates the cloud-sync status row.
  const CloudSyncRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final pending = ref.watch(pendingSyncCountProvider).value ?? 0;

    final subtitle = switch (status) {
      SyncIdle() => kSettingsSyncStatusAllSynced,
      SyncSynced() => kSettingsSyncStatusAllSynced,
      SyncSyncing() => kSettingsSyncStatusSyncing,
      SyncOffline() =>
        pending > 0
            ? '$pending $kSettingsSyncStatusPendingTemplate'
            : kSettingsSyncStatusOffline,
      SyncFailed() => kSettingsSyncStatusFailed,
    };

    final isFailed = status is SyncFailed;

    return SettingsRow(
      label: kSettingsCloudSyncRowLabel,
      subtitle: subtitle,
      onTap: isFailed
          ? () => unawaited(ref.read(syncEngineProvider).retryFailed())
          : null,
    );
  }
}
