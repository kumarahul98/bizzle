import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Finite sync-engine status (D-10). A sealed model — never a raw string —
/// per the CLAUDE.md "sealed classes for finite state" rule.
///
/// Plan 02's `SyncEngine` drives this via `SyncStatusNotifier.set(...)`; Plan
/// 03's Settings cloud-sync row renders it with an exhaustive `switch` on the
/// variants below (never `.when()`, which is for `AsyncValue`).
@immutable
sealed class SyncStatus {
  const SyncStatus();
}

/// Nothing in flight and nothing pending — the resting state.
class SyncIdle extends SyncStatus {
  const SyncIdle();
}

/// A sync flush is currently in progress.
class SyncSyncing extends SyncStatus {
  const SyncSyncing();
}

/// The queue drained successfully; all local changes are on the server.
class SyncSynced extends SyncStatus {
  const SyncSynced();
}

/// The device is offline (or the user is not signed in) — pending rows wait.
class SyncOffline extends SyncStatus {
  const SyncOffline();
}

/// One or more queue rows reached the terminal `failed` state. [count] is the
/// number of failed rows, surfaced in the Settings "tap to retry" row.
class SyncFailed extends SyncStatus {
  const SyncFailed(this.count);

  /// Number of failed queue rows.
  final int count;
}

/// Shared notifier that owns the current [SyncStatus]. Plan 02's engine calls
/// [set] on every state transition; Plan 03's Settings row reads the provider.
class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncIdle();

  /// Publish a new status. The engine (Plan 02) is the sole writer.
  ///
  /// Kept as a method (not a setter) because Plans 02 and 03 bind to this
  /// exact `set(...)` identifier — see the plan's frozen-public-names list.
  // ignore: use_setters_to_change_properties
  void set(SyncStatus status) => state = status;
}

/// keepAlive `NotifierProvider` (bare, not `.autoDispose`) exposing the shared
/// [SyncStatus]. Plans 02 and 03 both bind to this exact provider.
final NotifierProvider<SyncStatusNotifier, SyncStatus> syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncStatus>(
      SyncStatusNotifier.new,
      name: 'syncStatusProvider',
    );
