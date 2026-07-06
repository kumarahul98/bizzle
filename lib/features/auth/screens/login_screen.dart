import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/screens/sign_in_success_screen.dart';
import 'package:traevy/features/onboarding/widgets/google_continue_button.dart';
import 'package:traevy/features/onboarding/widgets/onboarding_intro_block.dart';

/// First-run login wall (Phase 20, D-03/D-04/D-05).
///
/// Mounted by the no-flash root gate in `lib/app.dart` for a guest who has
/// not yet cleared first-run (`has_seen_onboarding == false`). Reuses the
/// onboarding visuals ([OnboardingIntroBlock]) but with FIRST-RUN navigation
/// semantics: both actions write the persisted flag via a DAO setter so the
/// gate routes the user to the main shell and the wall never reappears.
///
///   * Google: `AuthService.signIn()` then set the flag; on first sign-in
///     push [SignInSuccessScreen]. The gate routes `AuthSignedIn → MainShell`
///     automatically, so this never pushes the shell itself.
///   * Skip: set the flag only. The write flips `userPreferenceProvider`, the
///     gate re-renders `AuthGuest & seen → MainShell` — no manual navigation.
///
/// When `firebaseReady == false` the Google button is disabled (opacity +
/// tooltip + Semantics), mirroring the onboarding degrade path (T-09-05-03).
class LoginScreen extends ConsumerWidget {
  /// Create the first-run login screen.
  const LoginScreen({super.key});

  Future<void> _onGoogleTap(BuildContext context, WidgetRef ref) async {
    try {
      final firstSignIn = await ref.read(authServiceProvider).signIn();
      // Only persist the flag after a SUCCESSFUL sign-in (D-04) — a cancel
      // must leave the user on the login screen.
      await ref.read(userPreferencesDaoProvider).setHasSeenOnboarding(true);
      if (!context.mounted) return;
      if (firstSignIn) {
        final authState = ref.read(authStateProvider);
        final initial = switch (authState) {
          AuthSignedIn(:final name) =>
            name.isNotEmpty ? name[0].toUpperCase() : kPlaceholderUserInitial,
          _ => kPlaceholderUserInitial,
        };
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SignInSuccessScreen(initial: initial),
          ),
        );
      }
      // The auth gate routes AuthSignedIn → MainShell — no push here.
    } on GoogleSignInException {
      // User cancelled — silent no-op, stay on the login screen.
    } on Object {
      // Network / credential error — silent no-op (sign-in sheet owns the
      // rich error copy; the first-run path stays minimal).
    }
  }

  Future<void> _onSkipTap(BuildContext context, WidgetRef ref) async {
    await ref.read(userPreferencesDaoProvider).setHasSeenOnboarding(true);
    // The flag write flips userPreferenceProvider; the gate re-renders to
    // MainShell. No manual navigation (single source of truth, no flash).
    if (!context.mounted) return;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final firebaseReady = ref.watch(firebaseReadyProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const OnboardingIntroBlock(),
                        const Spacer(),
                        if (firebaseReady)
                          GoogleContinueButton(
                            onTap: () => _onGoogleTap(context, ref),
                          )
                        else
                          Opacity(
                            opacity: kDisabledSignInOpacity,
                            child: Tooltip(
                              message: kCopySignInDisabledTooltip,
                              child: Semantics(
                                enabled: false,
                                child: GoogleContinueButton(onTap: () {}),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => _onSkipTap(context, ref),
                            child: Text(
                              kCopyLoginSkip,
                              style: TraevyFonts.ui(
                                size: 14,
                                weight: FontWeight.w500,
                                color: tokens.textDim,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            'By continuing you agree to our Terms.\n'
                            'Trips stay on your device until you sign in.',
                            style: TraevyFonts.ui(
                              size: 11,
                              color: tokens.textMuted,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
