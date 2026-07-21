import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
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
          // FirebaseAuth.signOut() → authStateChanges emits null → this sheet
          // rebuilds into the guest path below.
          onTap: () => unawaited(ref.read(authServiceProvider).signOut()),
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
