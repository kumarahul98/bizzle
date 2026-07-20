import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/database/providers.dart';
import 'package:traevy/features/settings/providers/settings_providers.dart';
import 'package:traevy/features/shell/providers/main_shell_provider.dart';
import 'package:traevy/features/tour/tour_config.dart';

/// Wraps one MainShell tab and runs its one-time guided [tour] the first time
/// the tab becomes visible.
///
/// ## The IndexedStack timing gotcha
///
/// MainShell mounts all four tab screens up front inside an `IndexedStack`, so
/// a screen's `initState` fires once at app start — NOT when the tab is
/// selected. A coach-mark can only target a widget that is actually visible,
/// so this host does not trigger on mount. Instead it watches
/// [mainShellIndexProvider] and starts the tour only once its `tabIndex` is the
/// selected (visible) tab AND the page's key is not already in `seen_tours`.
/// The initial tab (Today, index 0) is handled by a first-frame check because
/// `ref.listen` fires on change only.
///
/// On finish OR skip the page key is appended to `seen_tours` via
/// `UserPreferencesDao.markTourSeen` so the tour never runs again. Skip marks
/// only THIS page seen — other tabs still tour on their first visit.
class PageTourHost extends ConsumerStatefulWidget {
  /// Wrap [child] (the tab's screen) with the one-time [tour].
  const PageTourHost({required this.tour, required this.child, super.key});

  /// The page tour to run when this host's tab first becomes visible.
  final PageTour tour;

  /// The tab screen this host wraps.
  final Widget child;

  @override
  ConsumerState<PageTourHost> createState() => _PageTourHostState();
}

class _PageTourHostState extends ConsumerState<PageTourHost> {
  /// True once this page's tour has started (or been determined already-seen)
  /// for the current mount — guards against re-triggering on every rebuild.
  bool _started = false;

  OverlayEntry? _entry;

  /// Bounded retries while the target widgets finish their first layout after
  /// the tab becomes visible. Prevents an unbounded post-frame loop if a
  /// target never mounts (e.g. a screen still on its loading spinner).
  int _layoutRetries = 0;
  static const int _kMaxLayoutRetries = 5;

  @override
  void initState() {
    super.initState();
    // The initial tab is visible on first frame; ref.listen fires on change
    // only, so kick off a first-frame check here.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  /// Decide whether this page's tour should start now. Cheap and idempotent —
  /// safe to call from initState, tab-index changes, and prefs stream updates.
  void _maybeStart() {
    if (_started || !mounted) return;
    if (ref.read(mainShellIndexProvider) != widget.tour.tabIndex) return;

    final prefs = ref.read(userPreferenceProvider).asData?.value;
    if (prefs == null) return; // prefs not loaded yet — retry when they emit.

    if (prefs.seenTourKeys.contains(widget.tour.pageKey)) {
      _started = true; // Already seen — never show again.
      return;
    }
    if (widget.tour.steps.isEmpty) {
      _started = true;
      return;
    }

    _started = true;
    _layoutRetries = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay());
  }

  void _showOverlay() {
    if (!mounted || _entry != null) return;

    // The target widgets must be laid out before the spotlight can measure
    // them. If the first target is not yet in the tree, retry a few frames.
    final firstReady = widget.tour.steps.first.targetKey.currentContext != null;
    if (!firstReady) {
      if (_layoutRetries++ >= _kMaxLayoutRetries) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay());
      return;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (_) => _CoachmarkOverlay(
        steps: widget.tour.steps,
        onClose: _finish,
      ),
    );
    overlay.insert(_entry!);
  }

  /// Called on finish (last step) OR skip. Removes the overlay and persists the
  /// page key so this tour never runs again.
  void _finish() {
    _removeOverlay();
    if (!mounted) return;
    unawaited(
      ref.read(userPreferencesDaoProvider).markTourSeen(widget.tour.pageKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-evaluate when the selected tab changes (this tab becoming visible)
    // and when preferences finally load (seen set becomes known).
    ref
      ..listen<int>(mainShellIndexProvider, (_, next) {
        if (next == widget.tour.tabIndex) _maybeStart();
      })
      ..listen(userPreferenceProvider, (_, _) => _maybeStart());
    return widget.child;
  }
}

/// The full-screen coach-mark: a dimming scrim with a spotlight cut-out around
/// the current step's target, plus a themed tooltip card with Skip / Next.
class _CoachmarkOverlay extends StatefulWidget {
  const _CoachmarkOverlay({required this.steps, required this.onClose});

  final List<TourStep> steps;

  /// Invoked for both "finish last step" and "skip" — the host treats them
  /// identically (mark this page's tour seen).
  final VoidCallback onClose;

  @override
  State<_CoachmarkOverlay> createState() => _CoachmarkOverlayState();
}

class _CoachmarkOverlayState extends State<_CoachmarkOverlay> {
  int _index = 0;

  static const double _kSpotlightPadding = 8;
  static const double _kSpotlightRadius = 14;
  static const double _kTooltipMaxWidth = 340;
  static const double _kEdgeInset = 16;
  static const double _kTooltipGap = 12;

  void _next() {
    if (_index >= widget.steps.length - 1) {
      widget.onClose();
      return;
    }
    setState(() => _index++);
  }

  /// The current target's rectangle in overlay (== global) coordinates, or null
  /// if the target is not currently laid out.
  Rect? _targetRect() {
    final ctx = widget.steps[_index].targetKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<TraevyTokensExt>()!;
    final scheme = theme.colorScheme;
    final screen = MediaQuery.sizeOf(context);
    final step = widget.steps[_index];
    final rawRect = _targetRect();
    final spotlight = rawRect?.inflate(_kSpotlightPadding);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          // Full-screen barrier + dimming scrim with the spotlight hole.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // Absorb taps — buttons drive the flow.
              child: CustomPaint(
                painter: _SpotlightPainter(
                  spotlight: spotlight,
                  radius: _kSpotlightRadius,
                  scrimColor: Colors.black.withValues(alpha: 0.66),
                  borderColor: tokens.accent,
                ),
              ),
            ),
          ),
          _buildTooltip(context, tokens, scheme, screen, spotlight, step),
        ],
      ),
    );
  }

  Widget _buildTooltip(
    BuildContext context,
    TraevyTokensExt tokens,
    ColorScheme scheme,
    Size screen,
    Rect? spotlight,
    TourStep step,
  ) {
    final cardWidth = (screen.width - 2 * _kEdgeInset).clamp(
      0.0,
      _kTooltipMaxWidth,
    );

    // Horizontal: centre on the target, clamped to the screen edges.
    final centreX = spotlight?.center.dx ?? screen.width / 2;
    final left = (centreX - cardWidth / 2).clamp(
      _kEdgeInset,
      screen.width - _kEdgeInset - cardWidth,
    );

    // Vertical: below the target when there is room, otherwise above it.
    final placeBelow =
        spotlight == null ||
        spotlight.bottom + 180 <= screen.height ||
        spotlight.top < 180;

    final card = _TooltipCard(
      title: step.title,
      description: step.description,
      counter: kTourStepCounterTemplate
          .replaceAll('{current}', '${_index + 1}')
          .replaceAll('{total}', '${widget.steps.length}'),
      isLast: _index == widget.steps.length - 1,
      onSkip: widget.onClose,
      onNext: _next,
      tokens: tokens,
      scheme: scheme,
    );

    if (spotlight == null) {
      return Positioned(
        left: left,
        top: screen.height / 2 - 90,
        width: cardWidth,
        child: card,
      );
    }
    if (placeBelow) {
      return Positioned(
        left: left,
        top: spotlight.bottom + _kTooltipGap,
        width: cardWidth,
        child: card,
      );
    }
    return Positioned(
      left: left,
      bottom: screen.height - spotlight.top + _kTooltipGap,
      width: cardWidth,
      child: card,
    );
  }
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.title,
    required this.description,
    required this.counter,
    required this.isLast,
    required this.onSkip,
    required this.onNext,
    required this.tokens,
    required this.scheme,
  });

  final String title;
  final String description;
  final String counter;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final TraevyTokensExt tokens;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgElev,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderStr),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TraevyFonts.ui(
                size: 16,
                weight: FontWeight.w700,
                color: scheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TraevyFonts.ui(
                size: 13,
                color: tokens.textDim,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Text(
                  counter,
                  style: TraevyFonts.mono(
                    size: 12,
                    weight: FontWeight.w500,
                    color: tokens.textMuted,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.textDim,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    kTourSkipLabel,
                    style: TraevyFonts.ui(size: 14, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isLast ? kTourDoneLabel : kTourNextLabel,
                    style: TraevyFonts.ui(size: 14, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the dimming scrim over the whole screen with a rounded-rectangle hole
/// punched out around the [spotlight] target, plus a thin accent border tracing
/// the hole. When [spotlight] is null the scrim is solid (no cut-out).
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.spotlight,
    required this.radius,
    required this.scrimColor,
    required this.borderColor,
  });

  final Rect? spotlight;
  final double radius;
  final Color scrimColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()..color = scrimColor;
    final full = Offset.zero & size;

    final spot = spotlight;
    if (spot == null) {
      canvas.drawRect(full, scrimPaint);
      return;
    }

    final hole = RRect.fromRectAndRadius(spot, Radius.circular(radius));
    final scrimPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(full),
      Path()..addRRect(hole),
    );
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas
      ..drawPath(scrimPath, scrimPaint)
      ..drawRRect(hole, borderPaint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.spotlight != spotlight ||
      oldDelegate.scrimColor != scrimColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.radius != radius;
}
