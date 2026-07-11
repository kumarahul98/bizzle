import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/features/dashboard/widgets/hero_record_card.dart';
import 'package:traevy/features/dashboard/widgets/home_header.dart';
import 'package:traevy/features/dashboard/widgets/today_section.dart';
import 'package:traevy/features/dashboard/widgets/week_loss_card.dart';
import 'package:traevy/features/dashboard/widgets/sync_stuck_banner.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/sync/sync_engine.dart';
import 'package:traevy/sync/sync_status.dart';

/// The dashboard home screen — the app root showing today's trips and
/// a weekly traffic loss card at a glance (UX-01).
///
/// Phase 8: replaces AppBar + FAB with HomeHeader + HeroRecordCard,
/// TodaySection, and WeekLossCard per UI-SPEC.md §3 / Plan 04.
///
/// [_handleStart] preserves the existing permission-check flow — wired via
/// HeroRecordCard(onStart: callback) per RESEARCH.md Pattern 4.
class DashboardScreen extends ConsumerStatefulWidget {
  /// Create the dashboard screen.
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _dismissedStuckBanner = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<SyncStatus>(syncStatusProvider, (previous, next) {
      if (next is! SyncFailed) {
        setState(() => _dismissedStuckBanner = false);
      }
    });

    final trackingState = ref.watch(trackingStateProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    final showStuckBanner = !_dismissedStuckBanner && syncStatus is SyncFailed;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: HomeHeader()),
            if (showStuckBanner)
              SliverToBoxAdapter(
                child: _StuckBannerGate(
                  onReviewSettings: () {
                    Navigator.pushNamed(context, kRouteSettings);
                  },
                  onDismiss: () {
                    setState(() => _dismissedStuckBanner = true);
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HeroRecordCard(
                  onStart: () => _handleStart(context, ref),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: TodaySection(trackingState: trackingState),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(child: WeekLossCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStart(BuildContext context, WidgetRef ref) async {
    final service = ref.read(trackingPermissionServiceProvider);

    // D-01 iOS priming gate: show the location priming screen before the first
    // system When-In-Use prompt, for both fresh and already-signed-in users.
    //
    // Uses currentStatus() (probe-only, never prompts) to detect the
    // undetermined state. When locationWhenInUse is not yet granted,
    // currentStatus() returns denied — that's the signal to push the
    // priming screen first.
    //
    // On return from the priming screen, the user may have granted
    // When-In-Use (CTA) or skipped. Either way, control falls through to
    // the existing preflight() call, which on iOS will see location already
    // granted (no double prompt) or will surface the prompt inline (skip
    // path — acceptable fallback).
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final pre = await service.currentStatus();
      if (!context.mounted) return;
      if (pre == TrackingPermissionStatus.denied) {
        await Navigator.pushNamed(context, kRouteLocationPriming);
        if (!context.mounted) return;
      }
    }

    // preflight() runs the strict location → notifications dance and
    // prompts when needed. currentStatus() only probes — it would not
    // surface a system prompt on a fresh install with location denied,
    // and Start would silently fall through to start() (regression
    // introduced when TrackingScreen was deleted in 08-08).
    final status = await service.preflight();
    if (!context.mounted) return;
    if (status == TrackingPermissionStatus.denied) {
      // User declined the in-line prompt — there's no second screen to
      // show a re-prompt CTA, so dismiss; user re-taps START to retry.
      return;
    }
    if (status == TrackingPermissionStatus.permanentlyDenied) {
      await _showSettingsDialog(
        context,
        service,
        title: kDashboardPermDeniedTitle,
        body: kDashboardPermDeniedBody,
      );
      return;
    }
    if (status == TrackingPermissionStatus.notificationDenied) {
      await _showSettingsDialog(
        context,
        service,
        title: kDashboardNotifDeniedTitle,
        body: kDashboardNotifDeniedBody,
      );
      return;
    }
    if (!context.mounted) return;
    // Fire-and-forget: TrackingNotifier.start() flips state to TrackingStarting
    // synchronously; HeroRecordCard reflects the transition in place — no
    // navigation. Awaiting would block the dashboard for foreground-service
    // spin-up. See .planning/debug/hero-start-double-tap.md.
    unawaited(ref.read(trackingStateProvider.notifier).start());
  }

  Future<void> _showSettingsDialog(
    BuildContext context,
    TrackingPermissionService service, {
    required String title,
    required String body,
  }) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(kDialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(kDialogOpenSettings),
          ),
        ],
      ),
    );
    if (shouldOpen ?? false) {
      await service.openSystemSettings();
    }
  }
}

class _StuckBannerGate extends ConsumerWidget {
  const _StuckBannerGate({
    required this.onReviewSettings,
    required this.onDismiss,
  });

  final VoidCallback onReviewSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only instantiated/read when syncStatus is SyncFailed.
    // This prevents eager database instantiation in unrelated tests.
    final syncEngine = ref.read(syncEngineProvider);
    if (!syncEngine.autoRetryWindowElapsed) return const SizedBox.shrink();

    return SyncStuckBanner(
      onReviewSettings: onReviewSettings,
      onDismiss: onDismiss,
    );
  }
}
