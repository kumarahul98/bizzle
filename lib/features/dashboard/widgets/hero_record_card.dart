import 'package:flutter/material.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/shared/widgets/section_label.dart';

// Sizes and spacing from UI-SPEC §3.
const double _kButtonDiameter = 124;
const double _kCardHorizontalPadding = 28;
const double _kCardVerticalPadding = 24;
const double _kIconSize = 36;

/// Hero record card containing the 124dp circular START button.
///
/// Replaces the legacy FAB. The [onStart] callback is provided by
/// DashboardScreen and preserves the existing permission-check flow.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §3 Hero record card.
/// Research: `.planning/phases/08-ui-overhaul/08-RESEARCH.md` Pattern 4.
class HeroRecordCard extends StatelessWidget {
  /// Create the hero record card.
  const HeroRecordCard({
    required this.isTracking,
    required this.onStart,
    this.autoLabelDirection,
    this.autoLabelTime,
    super.key,
  });

  /// Whether a trip is currently being recorded.
  final bool isTracking;

  /// Called when the user taps START. Null-safe: only called when not tracking.
  final VoidCallback onStart;

  /// Auto-labelled direction string (e.g. 'To office'). Shown when idle.
  final String? autoLabelDirection;

  /// Auto-labelled departure time (e.g. '08:30'). Shown when idle.
  final String? autoLabelTime;

  Color _shadowColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0x66000000) : const Color(0x40B43C28);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: tokens.border),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _kCardHorizontalPadding,
          vertical: _kCardVerticalPadding,
        ),
        child: Column(
          children: [
            const SectionLabel(text: 'Ready to record'),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: isTracking ? null : onStart,
              child: Container(
                width: _kButtonDiameter,
                height: _kButtonDiameter,
                decoration: BoxDecoration(
                  color: tokens.record,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _shadowColor(context),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      size: _kIconSize,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'START',
                      style: TraevyFonts.ui(
                        size: 13,
                        weight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isTracking)
              _RecordingPill(tokens: tokens)
            else
              _AutoLabelRow(
                direction: autoLabelDirection,
                time: autoLabelTime,
                tokens: tokens,
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordingPill extends StatelessWidget {
  const _RecordingPill({required this.tokens});
  final TraevyTokensExt tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.record,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '● $kDashboardFabActiveLabel',
        style: TraevyFonts.ui(
          size: 12,
          weight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _AutoLabelRow extends StatelessWidget {
  const _AutoLabelRow({
    required this.direction,
    required this.time,
    required this.tokens,
  });
  final String? direction;
  final String? time;
  final TraevyTokensExt tokens;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final dir = direction ?? 'To office';
    final t = time ?? '';
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Auto-labelled ',
            style: TraevyFonts.ui(size: 12.5, color: tokens.textDim),
          ),
          TextSpan(
            text: dir,
            style: TraevyFonts.ui(
              size: 12.5,
              weight: FontWeight.w700,
              color: onSurface,
            ),
          ),
          if (t.isNotEmpty)
            TextSpan(
              text: ' · $t',
              style: TraevyFonts.mono(size: 12.5, color: tokens.textDim),
            ),
        ],
      ),
    );
  }
}
