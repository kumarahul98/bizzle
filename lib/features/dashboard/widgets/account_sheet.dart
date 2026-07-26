import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/providers/delete_account_controller.dart';
import 'package:traevy/features/auth/widgets/sign_in_sheet.dart';
import 'package:traevy/features/settings/widgets/account_row.dart';
import 'package:traevy/features/settings/widgets/cloud_sync_row.dart';
import 'package:traevy/features/settings/widgets/restore_row.dart';
import 'package:traevy/features/settings/widgets/settings_row.dart';
import 'package:traevy/features/settings/widgets/settings_section.dart';

/// What the account sheet asks its caller to do once it has closed.
///
/// Only the sign-in handoff needs this: opening the sign-in sheet on top of
/// the account sheet would stack two modals, so the account sheet pops first
/// and [showAccountSheet] opens the next one.
enum _AccountSheetAction { signIn }

/// Show the account sheet (Phase 32, D-02).
///
/// Holds exactly what the Settings → Account section held before this phase:
/// [AccountRow], [CloudSyncRow], [RestoreRow] and Sign out when signed in; the
/// "Sign in to back up" row when guest. That section is deleted — this sheet
/// is the single place those controls live, so there is no second Sign out and
/// no second Restore able to fire concurrently.
///
/// Styled after `showSignInSheet` / `_openThemePicker`:
/// `showModalBottomSheet` on `surfaceContainerLowest` with a drag handle.
Future<void> showAccountSheet(BuildContext context) async {
  final action = await showModalBottomSheet<_AccountSheetAction>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    showDragHandle: true,
    // The signed-in sheet is four rows tall and overflows the default
    // half-screen bottom sheet, so it takes the height its content needs and
    // scrolls if the viewport is shorter still (small phones, large text).
    isScrollControlled: true,
    builder: (sheetContext) => const _AccountSheetContent(),
  );
  if (action != _AccountSheetAction.signIn) return;
  if (!context.mounted) return;
  await showSignInSheet(context);
}

/// Show a sign-out confirmation dialog and sign out only on confirm.
///
/// Two-step guard mirroring `handleDeleteTrip`: dialog dismissal counts as
/// cancel via `confirmed ?? false`. Sign out is reversible — local Drift data
/// survives — but it interrupts cloud sync and the signed-in session, and the
/// row sits one tap behind the dashboard avatar, so it earns a confirm step.
/// `context.mounted` is re-checked after the await before signing out.
Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final colorScheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(kSignOutDialogTitle),
      content: const Text(kSignOutDialogBody),
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
          child: const Text(kSignOutConfirm),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (confirmed ?? false) {
    await ref.read(authServiceProvider).signOut();
  }
}

/// Show a delete-account confirmation dialog and delete only on confirm
/// (Phase 38, DEL-ACCOUNT). Mirrors [_confirmSignOut]'s structure exactly,
/// with irreversible-deletion copy.
///
/// On confirm, [DeleteAccountController.deleteAccount] runs the ordered
/// server-first wipe (never rethrows). On [DeleteAccountError] a SnackBar
/// shows the fixed error copy — same `ScaffoldMessenger.maybeOf(context)`
/// mechanism `DeleteAllDataRow` uses. On [DeleteAccountSuccess] the sheet
/// pops: `AuthService.deleteAccount()` already called `signOut()`, which
/// flips [authStateProvider] to [AuthGuest], so `_AccountSheetContent`
/// re-renders as the guest row the moment this sheet closes — no manual
/// navigation is needed.
Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final colorScheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(kDeleteAccountDialogTitle),
      content: const Text(kDeleteAccountDialogBody),
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
          child: const Text(kDeleteAccountConfirm),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (!(confirmed ?? false)) return;

  await ref.read(deleteAccountControllerProvider.notifier).deleteAccount();

  if (!context.mounted) return;
  switch (ref.read(deleteAccountControllerProvider)) {
    case DeleteAccountError():
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(
        const SnackBar(content: Text(kDeleteAccountErrorSnackbar)),
      );
    case DeleteAccountSuccess():
      Navigator.of(context).pop();
    case DeleteAccountIdle():
    case DeleteAccountInProgress():
      break;
  }
}

/// State-aware body of the account sheet.
///
/// Watches [authStateProvider] and switches on the sealed [AuthState], so
/// signing out from here re-renders the sheet into its guest form without any
/// manual refresh (T-32-04).
class _AccountSheetContent extends ConsumerWidget {
  const _AccountSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final deleteAccountState = ref.watch(deleteAccountControllerProvider);
    final deletingAccount = deleteAccountState is DeleteAccountInProgress;

    final rows = switch (auth) {
      AuthSignedIn(:final name, :final email) => <Widget>[
        AccountRow(
          name: name,
          email: email,
          initial: name.isNotEmpty
              ? name[0].toUpperCase()
              : kPlaceholderUserInitial,
        ),
        const CloudSyncRow(),
        const RestoreRow(),
        SettingsRow(
          label: kCopySettingsSignOut,
          dangerous: true,
          // Confirm first (two-step guard, matching handleDeleteTrip): on
          // confirm, FirebaseAuth.signOut() → authStateChanges emits null →
          // this sheet rebuilds into the guest path below.
          onTap: () => unawaited(_confirmSignOut(context, ref)),
        ),
        // Phase 38 (DEL-ACCOUNT): irreversible, so it sits below Sign out and
        // is guarded by its own confirm dialog. A small spinner replaces the
        // chevron while the ordered server-first wipe is in flight; the row
        // is disabled for the same duration to prevent a double-tap.
        SettingsRow(
          label: kDeleteAccountRowLabel,
          subtitle: deletingAccount ? kDeleteAccountInProgress : null,
          dangerous: true,
          trailing: deletingAccount
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: deletingAccount
              ? null
              : () => unawaited(_confirmDeleteAccount(context, ref)),
        ),
      ],
      // Guest or still loading — single CTA. The sheet pops with the sign-in
      // action so showAccountSheet can open the sign-in sheet in its place
      // rather than on top of it.
      _ => <Widget>[
        SettingsRow(
          label: kCopySettingsGuestSignIn,
          onTap: () => Navigator.of(context).pop(_AccountSheetAction.signIn),
        ),
      ],
    };

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SettingsSection(
              title: kSettingsAccountSectionTitle,
              children: rows,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
