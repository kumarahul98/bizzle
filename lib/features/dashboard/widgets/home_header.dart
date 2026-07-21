import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/dashboard/widgets/account_sheet.dart';
import 'package:traevy/features/dashboard/widgets/guest_connection_indicator.dart';

/// Dashboard home header: date + greeting on the left, a guest "not
/// connected" indicator + avatar circle on the right.
///
/// A [ConsumerWidget] reading [authStateProvider] twice over (Phase 32,
/// D-01): for the embedded [GuestConnectionIndicator] (Phase 20, AUTH-04) and
/// for the identity shown here. The greeting names the signed-in user and the
/// avatar carries their initial; a guest — or a signed-in account with no
/// usable display name — falls back to [kPlaceholderUserName] /
/// [kPlaceholderUserInitial].
///
/// The provider is watched, not read, so signing in or out while the
/// dashboard is mounted updates both immediately (T-32-04).
///
/// The avatar opens the account sheet (D-02); its touch target is
/// [kAccountAvatarTouchTarget] while the painted circle stays
/// [kAccountAvatarPaintedSize].
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §3 Home / Dashboard.
class HomeHeader extends ConsumerWidget {
  /// Create the home header.
  const HomeHeader({super.key});

  static String _formatDate(DateTime now) {
    final weekday = DateFormat('EEE').format(now);
    final monthDay = DateFormat('d MMM').format(now);
    return '$weekday · $monthDay';
  }

  /// The name to greet for [auth].
  ///
  /// [AuthSignedIn] yields the first whitespace-delimited word of the display
  /// name; everything else — and any name that is empty or only whitespace
  /// once trimmed — yields [kPlaceholderUserName]. `AuthStateNotifier`
  /// already substitutes the fallback for a null `displayName`, but not for
  /// the empty and whitespace-only strings Firebase can also return, which is
  /// why this trims before splitting.
  static String greetingName(AuthState auth) => switch (auth) {
    AuthSignedIn(:final name) => _firstWordOrFallback(name),
    AuthGuest() || AuthLoading() => kPlaceholderUserName,
  };

  /// The single character to paint inside the avatar for [auth].
  ///
  /// Always the uppercased first character of [greetingName], so the avatar
  /// and the greeting can never disagree and the circle is never blank. Read
  /// via `characters` rather than `[0]` so a name whose first character is a
  /// non-Latin grapheme cluster is not split mid-way.
  static String avatarInitial(AuthState auth) =>
      greetingName(auth).characters.first.toUpperCase();

  static String _firstWordOrFallback(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return kPlaceholderUserName;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final auth = ref.watch(authStateProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(now).toUpperCase(),
                style: TraevyFonts.ui(
                  size: 11,
                  weight: FontWeight.w600,
                  letterSpacing: 1,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$kGreetingPrefix${greetingName(auth)}',
                style: textTheme.titleLarge,
              ),
            ],
          ),
          const Spacer(),
          // Guest-only "not connected" indicator (Phase 20, AUTH-04, D-06):
          // renders nothing once signed in, so the avatar stays the sole
          // trailing element for an authenticated user.
          const GuestConnectionIndicator(),
          const SizedBox(width: 4),
          _AccountAvatarButton(initial: avatarInitial(auth)),
        ],
      ),
    );
  }
}

/// The avatar circle as the account entry point (Phase 32, D-02).
///
/// Painted at [kAccountAvatarPaintedSize] inside a
/// [kAccountAvatarTouchTarget] square, so the visual is unchanged from Phase 8
/// while the tappable area meets the Material minimum.
class _AccountAvatarButton extends StatelessWidget {
  const _AccountAvatarButton({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return SizedBox(
      width: kAccountAvatarTouchTarget,
      height: kAccountAvatarTouchTarget,
      // IconButton rather than a bare InkWell for the same reason
      // GuestConnectionIndicator and InfoIconButton use one: it carries the
      // tooltip/semantics label a lone letter cannot, and enforces the
      // interactive minimum size itself.
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: kAccountAvatarLabel,
        constraints: const BoxConstraints(
          minWidth: kAccountAvatarTouchTarget,
          minHeight: kAccountAvatarTouchTarget,
        ),
        onPressed: () => unawaited(showAccountSheet(context)),
        icon: Container(
          width: kAccountAvatarPaintedSize,
          height: kAccountAvatarPaintedSize,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initial,
              style: TraevyFonts.ui(
                size: 14,
                weight: FontWeight.w700,
                color: tokens.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
