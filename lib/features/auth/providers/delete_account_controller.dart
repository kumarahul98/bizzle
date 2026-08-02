import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/sync/api_client.dart';

/// Finite state of the "Delete account" flow (Phase 38, DEL-ACCOUNT). A
/// sealed model — never a raw string — per the CLAUDE.md "sealed classes for
/// finite state" rule. The account sheet row switches on these variants
/// exhaustively (never a `default`).
@immutable
sealed class DeleteAccountState {
  const DeleteAccountState();
}

/// Resting state — no delete has run, or the last result was acknowledged.
class DeleteAccountIdle extends DeleteAccountState {
  const DeleteAccountIdle();
}

/// An account deletion is currently in flight.
class DeleteAccountInProgress extends DeleteAccountState {
  const DeleteAccountInProgress();
}

/// The account was deleted: server account + data gone, local trips, sync
/// queue, and local preferences (including saved Home/Office coordinates)
/// wiped, and the device signed out.
class DeleteAccountSuccess extends DeleteAccountState {
  const DeleteAccountSuccess();
}

/// The deletion failed (server call threw). The concrete error is
/// intentionally NOT carried — the UI shows a fixed copy constant, never
/// `error.toString()` (T-38-01 PII guard).
class DeleteAccountError extends DeleteAccountState {
  const DeleteAccountError();
}

/// Drives the "Delete account" flow (Phase 38, DEL-ACCOUNT).
///
/// Delegates the ordered server-first wipe to
/// `AuthService.deleteAccount()`. Unlike that method, this controller catches
/// its own errors and NEVER rethrows, so a tap can never crash or freeze the
/// UI — the account sheet guards against a double-tap while
/// [DeleteAccountInProgress] (mirrors `RestoreController` /
/// `DeleteTripsController`'s discipline).
///
/// Manual Riverpod 3.x `Notifier` (no `@riverpod` codegen — the project-wide
/// drift_dev/analyzer pin, see `lib/database/providers.dart`).
class DeleteAccountController extends Notifier<DeleteAccountState> {
  @override
  DeleteAccountState build() => const DeleteAccountIdle();

  /// Delete the signed-in user's account. Double-tap while
  /// [DeleteAccountInProgress] is a no-op. Never rethrows.
  Future<void> deleteAccount() async {
    if (state is DeleteAccountInProgress) return;
    state = const DeleteAccountInProgress();

    try {
      await ref.read(authServiceProvider).deleteAccount();
      state = const DeleteAccountSuccess();
    } on SyncException {
      state = const DeleteAccountError();
    }
  }
}

/// keepAlive `NotifierProvider` (bare, not `.autoDispose`) exposing the
/// delete-account flow state. Matches the manual-provider convention in
/// `lib/database/providers.dart` / `restoreControllerProvider`.
final NotifierProvider<DeleteAccountController, DeleteAccountState>
deleteAccountControllerProvider =
    NotifierProvider<DeleteAccountController, DeleteAccountState>(
      DeleteAccountController.new,
      name: 'deleteAccountControllerProvider',
    );
