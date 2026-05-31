import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:traevy/config/theme.dart';

/// Visual scaffold for the "Continue with Google" button on the
/// onboarding screen.
///
/// Real authentication wires up in Phase 9 — this widget renders the
/// button shell and forwards taps to [onTap], which is currently a
/// no-op closure passed from `OnboardingScreen`.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §9 Onboarding.
class GoogleContinueButton extends StatelessWidget {
  /// Creates a [GoogleContinueButton] with the given [onTap] callback.
  const GoogleContinueButton({required this.onTap, super.key});

  /// Called when the button is tapped. Phase 9 wires this to the
  /// Google sign-in flow; for Phase 8 it is a no-op.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: tokens.bgElev,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.borderStr),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SvgPicture.asset(
                'assets/icons/google_g.svg',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Continue with Google',
                style: TraevyFonts.ui(
                  size: 14,
                  weight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
