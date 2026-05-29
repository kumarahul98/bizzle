import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/shell/main_shell.dart';

/// One-time post-sign-in confirmation screen shown after a user successfully
/// signs in for the first time via the onboarding flow (D-12, UI-SPEC §C).
///
/// Pushed by the onboarding `GoogleContinueButton` handler in Plan 05 when
/// `AuthService.signIn()` returns `true` (first sign-in, rows backfilled).
/// Never shown again after the first sign-in — the navigation goes directly
/// to [MainShell] on subsequent launches because `authStateProvider` starts
/// in `AuthSignedIn`, not `AuthLoading`.
///
/// Layout mirrors the onboarding screen rhythm (UI-SPEC §C):
/// `Scaffold > SafeArea > Padding(horizontal: 28) > Column(crossAxisStart)`:
///   1. 44 dp avatar circle (`accentBg` fill + `accent` initial letter)
///   2. 48 px gap
///   3. `kCopyConfirmHeadline` in display style (36 px / w700 / -1.2 / 1.05)
///   4. 12 px gap
///   5. `kCopyConfirmBody` in body style (16 px / w400 / textDim / h1.5)
///   6. [Spacer]
///   7. Neutral "Let's go" CTA → `pushReplacement` to [MainShell]
///
/// The CTA reuses the `GoogleContinueButton` neutral shell (bgElev fill,
/// borderStr outline, 14 px radius, horizontal 18 / vertical 16 padding)
/// minus the Google glyph.
class SignInSuccessScreen extends StatelessWidget {
  /// Create the one-time confirmation screen.
  ///
  /// [initial] is the first character of the signed-in user's display name,
  /// rendered inside the avatar circle. Passed by the onboarding handler
  /// (Plan 05) from the `AuthSignedIn` payload.
  const SignInSuccessScreen({required this.initial, super.key});

  /// First character of the user's display name shown in the avatar circle.
  final String initial;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _AvatarCircle(initial: initial, tokens: tokens),
              const SizedBox(height: 48),
              Text(
                kCopyConfirmHeadline,
                style: TraevyFonts.ui(
                  size: 36,
                  weight: FontWeight.w700,
                  letterSpacing: -1.2,
                  height: 1.05,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                kCopyConfirmBody,
                style: TraevyFonts.ui(
                  size: 16,
                  color: tokens.textDim,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              const _LetsGoCta(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 44 dp avatar circle using `accentBg` fill and `accent`-coloured initial
/// letter. Reuses the `AccountRow` avatar treatment from
/// `lib/features/settings/widgets/account_row.dart` lines 43–60.
class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.initial, required this.tokens});

  final String initial;
  final TraevyTokensExt tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tokens.accentBg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TraevyFonts.ui(
            size: 16,
            weight: FontWeight.w700,
            color: tokens.accent,
          ),
        ),
      ),
    );
  }
}

/// Neutral "Let's go" CTA button. Mirrors the `GoogleContinueButton` shell
/// (`bgElev` fill, `borderStr` outline, 14 px radius, horizontal 18 /
/// vertical 16 padding) without the Google glyph (UI-SPEC §C).
///
/// Tap replaces the current route with [MainShell] so the back button does
/// not return to this one-time confirmation screen.
class _LetsGoCta extends StatelessWidget {
  const _LetsGoCta();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const MainShell()),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: tokens.bgElev,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.borderStr),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Center(
            child: Text(
              kCopyConfirmCta,
              style: TraevyFonts.ui(
                size: 14,
                weight: FontWeight.w600,
                color: onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
