import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/widgets/sign_in_sheet.dart';

/// A calm, non-nagging "not connected" indicator for the dashboard header.
///
/// Phase 20, AUTH-04, SC#3, D-06.
///
/// A skipped / local-only (guest) user has trips that are NOT backed up. This
/// indicator is the single passive signal of that fact: a muted
/// `cloud_off` [IconButton] in the always-visible `HomeHeader`. Tapping it
/// (user-initiated only — there is NO auto-shown snackbar, dialog, or toast)
/// opens the existing [showSignInSheet] so the user can sign in to back up
/// without leaving the dashboard.
///
/// State contract — switches exhaustively on the sealed [AuthState] (never a
/// `default`, so a future variant is a compile error):
///   * [AuthGuest]    → the indicator is shown.
///   * [AuthSignedIn] → renders nothing, so a signed-in user never sees a
///     stale "not connected" badge.
///   * [AuthLoading]  → renders nothing, so the indicator never flashes while
///     the auth state resolves on first run.
class GuestConnectionIndicator extends ConsumerWidget {
  /// Create the guest connection indicator.
  const GuestConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return switch (auth) {
      AuthGuest() => _GuestIcon(
        // User-initiated CTA only (D-06): the sheet opens on tap, never
        // automatically.
        onPressed: () => showSignInSheet(context),
      ),
      AuthLoading() || AuthSignedIn() => const SizedBox.shrink(),
    };
  }
}

/// The muted `cloud_off` icon button. Extracted so the switch stays lean and
/// the token lookup happens only on the branch that renders something.
class _GuestIcon extends StatelessWidget {
  const _GuestIcon({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;

    return IconButton(
      icon: const Icon(Icons.cloud_off_outlined),
      // Muted colour keeps it calm and consistent with the avatar's
      // textMuted styling — it informs without demanding attention.
      color: tokens.textMuted,
      iconSize: 20,
      tooltip: kCopyGuestNotConnectedTooltip,
      onPressed: onPressed,
    );
  }
}
