import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/onboarding/widgets/feature_tick.dart';

/// iOS-only location priming screen (Surface A, IOS-09, D-01).
///
/// Shown before the system When-In-Use prompt for BOTH fresh and
/// already-signed-in users, gated from the dashboard Start handler.
/// Its only job is to inform the user why location access is needed,
/// then surface the system When-In-Use dialog via a single CTA tap.
///
/// Critical ordering: the CTA requests `locationWhenInUse` HERE, then
/// pops back. The dashboard gate then calls `service.preflight()`, which
/// sees location already granted and skips the system prompt — no double
/// prompt (D-01).
///
/// The skip link pops without requesting. The dashboard gate then falls
/// through to `preflight()`, which on iOS surfaces the prompt inline —
/// acceptable fallback.
class OnboardingLocationPrimingScreen extends StatelessWidget {
  /// Create the location priming screen.
  const OnboardingLocationPrimingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
                        ExcludeSemantics(
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          kIosLocationPrimingHeading,
                          style: TraevyFonts.ui(
                            size: 22,
                            weight: FontWeight.w700,
                            letterSpacing: -0.6,
                            height: 1.2,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            kIosLocationPrimingBody,
                            style: TraevyFonts.ui(
                              size: 16,
                              color: tokens.textDim,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const FeatureTick(
                          title: kIosLocationPrimingTick1Title,
                          subtitle: kIosLocationPrimingTick1Subtitle,
                        ),
                        const SizedBox(height: 16),
                        const FeatureTick(
                          title: kIosLocationPrimingTick2Title,
                          subtitle: kIosLocationPrimingTick2Subtitle,
                        ),
                        const SizedBox(height: 16),
                        const FeatureTick(
                          title: kIosLocationPrimingTick3Title,
                          subtitle: kIosLocationPrimingTick3Subtitle,
                        ),
                        const Spacer(),
                        Semantics(
                          button: true,
                          label: kIosLocationPrimingCta,
                          child: _LocationCTAButton(
                            onTap: () async {
                              // Request When-In-Use here so that the dashboard
                              // gate's subsequent preflight() call sees it
                              // already granted and does not prompt a second
                              // time (D-01 no-double-prompt contract).
                              await Permission.locationWhenInUse.request();
                              if (!context.mounted) return;
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              child: Text(
                                kIosLocationPrimingSkip,
                                style: TraevyFonts.ui(
                                  size: 14,
                                  color: tokens.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            kIosLocationPrimingTerms,
                            style: TraevyFonts.ui(
                              size: 14,
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

/// CTA button for the location priming screen. Matches the
/// `GoogleContinueButton` shell exactly (same border radius, colors, padding)
/// with a location icon instead of the Google G mark.
class _LocationCTAButton extends StatelessWidget {
  const _LocationCTAButton({required this.onTap});

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
              const Icon(Icons.location_on_outlined, size: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  kIosLocationPrimingCta,
                  overflow: TextOverflow.ellipsis,
                  style: TraevyFonts.ui(
                    size: 15,
                    weight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
