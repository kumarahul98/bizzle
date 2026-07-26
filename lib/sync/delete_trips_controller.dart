import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/sync/api_client.dart';

/// Finite state of the "Delete all data" flow (Phase 38, DEL-ALL-DATA). A
/// sealed model — never a raw string — per the CLAUDE.md "sealed classes for
/// finite state" rule. The Settings row switches on these variants
/// exhaustively (never a `default`).
@immutable
sealed class DeleteTripsState {
  const DeleteTripsState();
}

/// Resting state — no delete has run, or the last result was acknowledged.
class DeleteTripsIdle extends DeleteTripsState {
  const DeleteTripsIdle();
}

/// A delete-all-data wipe is currently in flight.
class DeleteTripsInProgress extends DeleteTripsState {
  const DeleteTripsInProgress();
}

/// The wipe completed. [count] is the number of LOCAL trip rows removed.
class DeleteTripsSuccess extends DeleteTripsState {
  const DeleteTripsSuccess(this.count);

  /// Number of local trip rows deleted by this wipe.
  final int count;
}

/// The wipe failed (signed-in server call threw). The concrete error is
/// intentionally NOT carried — the UI shows a fixed copy constant, never
/// `error.toString()` (T-38-01 PII guard).
class DeleteTripsError extends DeleteTripsState {
  const DeleteTripsError();
}

/// Drives the "Delete all data" flow (Phase 38, DEL-ALL-DATA).
///
/// Guest path: no server call — wipes local trips + clears the sync queue.
/// Signed-in path: purges server trips FIRST via [ApiClient.deleteAllTrips],
/// then wipes local trips + clears the sync queue. If the server call throws,
/// [deleteAllTrips] transitions to [DeleteTripsError] and returns WITHOUT
/// touching local data — never rethrows, so a tap can never crash or freeze
/// the UI (mirrors `RestoreController`'s discipline).
///
/// Manual Riverpod 3.x `Notifier` (no `@riverpod` codegen — the project-wide
/// drift_dev/analyzer pin, see `lib/database/providers.dart`).
class DeleteTripsController extends Notifier<DeleteTripsState> {
  @override
  DeleteTripsState build() => const DeleteTripsIdle();

  /// Wipe all trip data. Guest: local-only. Signed-in: server-first, then
  /// local. Double-tap while [DeleteTripsInProgress] is a no-op. Never
  /// rethrows.
  Future<void> deleteAllTrips() async {
    if (state is DeleteTripsInProgress) return;
    state = const DeleteTripsInProgress();

    if (ref.read(authStateProvider) is AuthSignedIn) {
      try {
        await ref.read(apiClientProvider).deleteAllTrips();
      } on SyncException {
        state = const DeleteTripsError();
        return;
      }
    }

    final count = await ref.read(tripsDaoProvider).deleteAllTrips();
    await ref.read(syncQueueDaoProvider).clearAll();
    state = DeleteTripsSuccess(count);
  }
}

/// keepAlive `NotifierProvider` (bare, not `.autoDispose`) exposing the
/// delete-all-data flow state. Matches the manual-provider convention in
/// `lib/database/providers.dart` / `restoreControllerProvider`.
final NotifierProvider<DeleteTripsController, DeleteTripsState>
deleteTripsControllerProvider =
    NotifierProvider<DeleteTripsController, DeleteTripsState>(
      DeleteTripsController.new,
      name: 'deleteTripsControllerProvider',
    );
