import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_service_controller.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/tracking/widgets/direction_segmented_toggle.dart';
import 'package:traevy/features/tracking/widgets/elapsed_display.dart';
import 'package:traevy/features/tracking/widgets/pause_resume_button.dart';
import 'package:traevy/features/tracking/widgets/paused_indicators.dart';
import 'package:traevy/features/tracking/widgets/recording_header.dart';
import 'package:traevy/features/tracking/widgets/stop_button.dart';
import 'package:traevy/features/tracking/widgets/tracking_error_layout.dart';
import 'package:traevy/features/tracking/widgets/tracking_status_layout.dart';
import 'package:traevy/features/tracking/widgets/tracking_tiles_row.dart';
import 'package:traevy/shared/widgets/section_label.dart';

const double _kButtonDiameter = 124;
const double _kCardHorizontalPadding = 28;
const double _kCardVerticalPadding = 24;
const double _kIconSize = 36;

/// Hero card on the dashboard. Renders all five [TrackingState] cases
/// in place — there is no separate tracking screen. The dashboard scroll
/// view and MainShell tabs remain interactive while a trip records.
///
/// Closes Phase 8 UAT gaps 1 and 4. See `.planning/phases/08-ui-overhaul/08-08-PLAN.md`.
class HeroRecordCard extends ConsumerWidget {
  /// Create the hero card.
  const HeroRecordCard({
    required this.onStart,
    this.autoLabelDirection,
    this.autoLabelTime,
    super.key,
  });

  /// Permission-preflight wrapper. Parent owns permission UX; the hero
  /// only fires this when the user taps START while idle/error.
  final VoidCallback onStart;

  /// Auto-labelled direction string (e.g. 'To office'). Shown when idle.
  final String? autoLabelDirection;

  /// Auto-labelled departure time (e.g. '08:30'). Shown when idle.
  final String? autoLabelTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final state = ref.watch(trackingStateProvider);

    // Surface the persist-result snackbar on the Stopping → Idle edge.
    // Lifted from the deleted TrackingScreen.build (08-08 task 1).
    ref.listen<TrackingState>(trackingStateProvider, (previous, next) {
      if (previous is TrackingStopping && next is TrackingIdle) {
        _handlePersistResult(
          context,
          ref.read(trackingStateProvider.notifier).consumeLastPersistResult(),
        );
      }
    });

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
        child: switch (state) {
          TrackingIdle() => _HeroIdle(
            tokens: tokens,
            onStart: onStart,
            autoLabelDirection: autoLabelDirection,
            autoLabelTime: autoLabelTime,
          ),
          TrackingStarting() => const TrackingStatusLayout(
            label: 'Starting GPS...',
          ),
          TrackingActive(
            :final startedAt,
            :final elapsedSeconds,
            :final distanceMeters,
            :final currentSpeedKmh,
            :final timeStuckSeconds,
            :final isPaused,
            :final breakCount,
          ) =>
            _HeroActive(
              elapsedSeconds: elapsedSeconds,
              distanceMeters: distanceMeters,
              currentSpeedKmh: currentSpeedKmh,
              timeStuckSeconds: timeStuckSeconds,
              // Phase 18 (D-08): the paused/running treatment + break count are
              // driven purely by the snapshot — the hero is a dumb terminal.
              isPaused: isPaused,
              breakCount: breakCount,
              // D-05: header label + toggle selection both come from the
              // notifier's resolved direction (override ?? auto-label). Watch
              // prefs so the first frame and any pref change rebuild the label.
              direction: ref
                  .watch(trackingStateProvider.notifier)
                  .resolvedDirection(startedAt),
              onDirectionSelected: (direction) => ref
                  .read(trackingStateProvider.notifier)
                  .setDirection(direction),
              onStop: () => ref.read(trackingStateProvider.notifier).stop(),
              onPause: () => ref.read(trackingStateProvider.notifier).pause(),
              onResume: () => ref.read(trackingStateProvider.notifier).resume(),
            ),
          TrackingStopping() => const TrackingStatusLayout(
            label: 'Saving trip...',
          ),
          TrackingInterrupted() => const TrackingStatusLayout(
            label: 'Interrupted trip found...',
          ),
          TrackingError(:final message) => TrackingErrorLayout(
            message: message,
            onRetry: () => ref.read(trackingStateProvider.notifier).start(),
            onOpenSettings: Geolocator.openLocationSettings,
          ),
        },
      ),
    );
  }

  void _handlePersistResult(BuildContext context, PersistResult? result) {
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final text = switch (result) {
      PersistSaved() => 'Trip saved',
      PersistDiscardedTooShort() => 'Trip too short to save',
      PersistFailed(:final error) => 'Unable to save trip: $error',
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

class _HeroIdle extends StatelessWidget {
  const _HeroIdle({
    required this.tokens,
    required this.onStart,
    required this.autoLabelDirection,
    required this.autoLabelTime,
  });

  final TraevyTokensExt tokens;
  final VoidCallback onStart;
  final String? autoLabelDirection;
  final String? autoLabelTime;

  Color _shadowColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0x66000000) : const Color(0x40B43C28);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SectionLabel(text: 'Ready to record'),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onStart,
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
        _AutoLabelRow(
          direction: autoLabelDirection,
          time: autoLabelTime,
          tokens: tokens,
        ),
      ],
    );
  }
}

class _HeroActive extends StatefulWidget {
  const _HeroActive({
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.currentSpeedKmh,
    required this.timeStuckSeconds,
    required this.isPaused,
    required this.breakCount,
    required this.direction,
    required this.onDirectionSelected,
    required this.onStop,
    required this.onPause,
    required this.onResume,
  });

  final int elapsedSeconds;
  final double distanceMeters;
  final double currentSpeedKmh;
  final int timeStuckSeconds;
  final bool isPaused;
  final int breakCount;
  final String direction;
  final ValueChanged<String> onDirectionSelected;
  final VoidCallback onStop;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  State<_HeroActive> createState() => _HeroActiveState();
}

class _HeroActiveState extends State<_HeroActive> {
  // Optimistic selection so the header label + toggle flip on the same frame
  // as the tap (TRACK-12, D-05). setDirection does not emit a new
  // TrackingState, so this local mirror drives the immediate rebuild; the
  // resolved direction from the notifier reconciles it on the next snapshot.
  late String _selected = widget.direction;

  @override
  void didUpdateWidget(_HeroActive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.direction != oldWidget.direction) {
      _selected = widget.direction;
    }
  }

  void _onDirectionSelected(String direction) {
    setState(() => _selected = direction);
    widget.onDirectionSelected(direction);
  }

  String get _directionLabel => _selected == kDirectionToHome
      ? kDirectionToHomeLabel
      : kDirectionToOfficeLabel;

  @override
  Widget build(BuildContext context) {
    final isPaused = widget.isPaused;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RecordingHeader(directionLabel: _directionLabel),
        if (isPaused) ...const <Widget>[
          SizedBox(height: 12),
          Center(child: PausedBadge()),
        ],
        const SizedBox(height: 12),
        DirectionSegmentedToggle(
          selected: _selected,
          onSelected: _onDirectionSelected,
        ),
        const SizedBox(height: 16),
        // Phase 18 (D-09): while paused the elapsed value already arrives
        // FROZEN from the snapshot (no local clock) — we just dim it so the
        // paused state reads as visually distinct without changing the timer.
        Opacity(
          opacity: isPaused ? 0.4 : 1,
          child: ElapsedDisplay(durationSeconds: widget.elapsedSeconds),
        ),
        if (widget.breakCount > 0) ...<Widget>[
          const SizedBox(height: 10),
          BreakCountChip(breakCount: widget.breakCount),
        ],
        const SizedBox(height: 24),
        TrackingTilesRow(
          elapsedSeconds: widget.elapsedSeconds,
          distanceMeters: widget.distanceMeters,
          currentSpeedKmh: widget.currentSpeedKmh,
          timeStuckSeconds: widget.timeStuckSeconds,
        ),
        const SizedBox(height: 16),
        PauseResumeButton(
          isPaused: isPaused,
          onPressed: isPaused ? widget.onResume : widget.onPause,
        ),
        const SizedBox(height: 12),
        StopButton(onPressed: widget.onStop),
      ],
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

// kDashboardFabActiveLabel constant kept for legacy callers — it now refers
// to the in-place RecordingHeader inside HeroRecordCard. Reserved for future
// localization. The constant import is preserved for readers who grep the
// codebase for the symbol.
// ignore: unused_element
const String _kPreserveSymbol = kDashboardFabActiveLabel;
