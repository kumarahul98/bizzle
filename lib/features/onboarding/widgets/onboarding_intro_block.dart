import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/onboarding/widgets/feature_tick.dart';
import 'package:traevy/shared/widgets/traevy_logo_mark.dart';

/// The shared top-of-screen visual block used by both the onboarding screen
/// and the first-run `LoginScreen`: logo mark, headline, subtitle, and the
/// three feature ticks.
///
/// Extracted so the first-run `LoginScreen` reuses the exact onboarding
/// visuals without duplicating the column (`CLAUDE.md`: keep widgets small and
/// avoid copy-paste). The sign-in / skip actions differ between the two
/// screens, so only this static intro is shared — the actions stay in each
/// screen.
class OnboardingIntroBlock extends StatelessWidget {
  /// Create the shared onboarding intro block.
  const OnboardingIntroBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TraevyLogoMark(),
        const SizedBox(height: 24),
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
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            'One tap to start, one tap to stop. '
            'See exactly how much of your day '
            'is lost to traffic.',
            style: TraevyFonts.ui(
              size: 16,
              color: tokens.textDim,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 40),
        const FeatureTick(
          title: 'One-tap recording',
          subtitle: 'Start when you leave, stop when you arrive.',
        ),
        const SizedBox(height: 18),
        const FeatureTick(
          title: 'Auto traffic detection',
          subtitle: 'We split moving time from time stuck.',
        ),
        const SizedBox(height: 18),
        const FeatureTick(
          title: 'Works offline',
          subtitle: 'Trips save to the device, sync later.',
        ),
      ],
    );
  }
}
