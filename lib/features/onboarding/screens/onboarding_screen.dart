import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/screens/sign_in_success_screen.dart';
import 'package:traevy/features/onboarding/widgets/google_continue_button.dart';
import 'package:traevy/features/onboarding/widgets/onboarding_intro_block.dart';

/// Onboarding scaffold: logo + headline + feature ticks + Google continue
/// button + skip link + terms blurb.
///
/// Reachable via the `kRouteOnboarding` named route. The "Continue with
/// Google" button is wired to `AuthService.signIn()` (Phase 9 AUTH-01/AUTH-03).
/// On first sign-in (`signIn()` returns `true`) the user is pushed to the
/// one-time `SignInSuccessScreen` (D-12). Subsequent launches will not reach
/// this screen because `authStateProvider` starts in `AuthSignedIn`.
///
/// When `firebaseReady == false` (D-15 — dev/CI build without
/// `google-services.json`), the button is disabled (opacity + tooltip +
/// Semantics) so no broken sign-in is triggerable (T-09-05-03).
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §9 Onboarding Screen.
/// See: `.planning/phases/09-authentication/09-UI-SPEC.md` §Wired-only surfaces.
class OnboardingScreen extends ConsumerWidget {
  /// Create the onboarding screen.
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final firebaseReady = ref.watch(firebaseReadyProvider);

    return Scaffold(
      body: SafeArea(
        // Scroll-safe sticky-footer layout: the sign-in block stays pinned to
        // the bottom via Spacer on tall screens (design is a 740px phone), and
        // the whole screen scrolls instead of overflowing on shorter devices.
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
                          // Wired to AuthService.signIn() (AUTH-01).
                          GoogleContinueButton(
                            onTap: () async {
                              try {
                                final firstSignIn = await ref
                                    .read(authServiceProvider)
                                    .signIn();
                                // context.mounted guard after every await
                                // (trip_actions.dart lines 42, 48 discipline).
                                if (!context.mounted) return;
                                if (firstSignIn) {
                                  // D-12: first sign-in — derive initial.
                                  final authState = ref.read(authStateProvider);
                                  final initial = switch (authState) {
                                    AuthSignedIn(:final name) =>
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : kPlaceholderUserInitial,
                                    _ => kPlaceholderUserInitial,
                                  };
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          SignInSuccessScreen(initial: initial),
                                    ),
                                  );
                                }
                                // Repeat sign-in: the app.dart auth gate
                                // already routes to MainShell — no push here.
                              } on GoogleSignInException {
                                // User cancelled — silent no-op.
                              } on Object {
                                // Network / credential error — silent no-op.
                                // The sign-in sheet handles rich error copy;
                                // the onboarding path stays minimal.
                              }
                            },
                          )
                        else
                          // D-15 degrade path: Firebase not configured.
                          // Disabled button (T-09-05-03).
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
                          child: GestureDetector(
                            onTap: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              child: Text(
                                'Skip — try without an account',
                                style: TraevyFonts.ui(
                                  size: 14,
                                  weight: FontWeight.w500,
                                  color: tokens.textDim,
                                ),
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
