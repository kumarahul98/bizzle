import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/onboarding/widgets/feature_tick.dart';
import 'package:traevy/features/onboarding/widgets/google_continue_button.dart';
import 'package:traevy/shared/widgets/traevy_logo_mark.dart';

/// Static onboarding scaffold: logo + headline + feature ticks + Google
/// continue button + skip link + terms blurb.
///
/// Reachable via the `kRouteOnboarding` named route. Authentication wiring
/// lands in Phase 9 — the Continue with Google button is currently a
/// visual scaffold with a no-op tap handler.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §9 Onboarding Screen.
class OnboardingScreen extends StatelessWidget {
  /// Create the onboarding screen.
  const OnboardingScreen({super.key});

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
              const TraevyLogoMark(),
              const SizedBox(height: 32),
              Text(
                'Track every\ncommute.',
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
                'One tap to start, automatic traffic insight, works '
                'offline. Sign in later to back up.',
                style: TraevyFonts.ui(
                  size: 16,
                  color: tokens.textDim,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              const FeatureTick(
                title: 'One-tap recording',
                subtitle: 'Start when you leave, stop when you arrive.',
              ),
              const SizedBox(height: 14),
              const FeatureTick(
                title: 'Auto traffic detection',
                subtitle: 'See exactly how long you were stuck.',
              ),
              const SizedBox(height: 14),
              const FeatureTick(
                title: 'Works offline',
                subtitle: 'Sync when you have a connection — never required.',
              ),
              const Spacer(),
              // Wired in Phase 9 — currently a visual scaffold only.
              GoogleContinueButton(onTap: () {}),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(
                    'Skip — try without account',
                    style: TraevyFonts.ui(
                      size: 14,
                      weight: FontWeight.w500,
                      color: tokens.textDim,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'By continuing you agree to our terms.',
                  style: TraevyFonts.ui(size: 11, color: tokens.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
