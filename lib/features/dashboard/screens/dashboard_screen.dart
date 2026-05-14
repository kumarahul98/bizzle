import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/features/dashboard/widgets/hero_record_card.dart';
import 'package:traevy/features/dashboard/widgets/home_header.dart';
import 'package:traevy/features/dashboard/widgets/today_section.dart';
import 'package:traevy/features/dashboard/widgets/week_loss_card.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';

/// The dashboard home screen — the app root showing today's trips and
/// a weekly traffic loss card at a glance (UX-01).
///
/// Phase 8: replaces AppBar + FAB with HomeHeader + HeroRecordCard,
/// TodaySection, and WeekLossCard per UI-SPEC.md §3 / Plan 04.
///
/// [_handleStart] preserves the existing permission-check flow — wired via
/// HeroRecordCard(onStart: callback) per RESEARCH.md Pattern 4.
class DashboardScreen extends ConsumerWidget {
  /// Create the dashboard screen.
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingStateProvider);
    final isTracking = trackingState is TrackingActive;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: HomeHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HeroRecordCard(
                  isTracking: isTracking,
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
    final status = await service.currentStatus();
    if (!context.mounted) return;
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
    await Navigator.pushNamed(context, kRouteTracking);
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
