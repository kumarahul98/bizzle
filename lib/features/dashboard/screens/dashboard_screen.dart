import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/features/dashboard/providers/dashboard_providers.dart';
import 'package:traevy/features/dashboard/widgets/today_trips_section.dart';
import 'package:traevy/features/dashboard/widgets/weekly_summary_card.dart';
import 'package:traevy/features/stats/providers/stats_providers.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/widgets/manual_entry_sheet.dart';

const double _kBodyHorizontalPadding = 16;
const double _kBodyTopPadding = 24;
const double _kBodyBottomPadding = 32;
const double _kSectionGap = 16;
const double _kFabClearance = 32;

/// The dashboard home screen — the app root showing today's trips and
/// a weekly summary card at a glance (UX-01).
///
/// Replaces HomeScreen as the MaterialApp.home binding (D-01). Watches
/// trackingStateProvider, todaysTripSummariesProvider, and
/// statsSummaryProvider once in build and passes values down to child
/// widgets so children remain plain StatelessWidgets.
class DashboardScreen extends ConsumerWidget {
  /// Create the dashboard screen.
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingStateProvider);
    final isTracking = trackingState is TrackingActive;
    final asyncToday = ref.watch(todaysTripSummariesProvider);
    final asyncStats = ref.watch(statsSummaryProvider);

    final weekTotalSeconds =
        asyncStats.whenData((s) => s.weekTotalSeconds).asData?.value ?? 0;
    final weekStuckSeconds =
        asyncStats.whenData((s) => s.weekStuckSeconds).asData?.value ?? 0;
    final todayTripCount =
        asyncToday.whenData((t) => t.length).asData?.value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEE, d MMM').format(DateTime.now())),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: kDashboardAddTripTooltip,
            onPressed: () => _handleAddManualTrip(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => Navigator.pushNamed(context, kRouteHistory),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Stats',
            onPressed: () => Navigator.pushNamed(context, kRouteStats),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: kSettingsTooltip,
            onPressed: () => Navigator.pushNamed(context, kRouteSettings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _kBodyHorizontalPadding,
          _kBodyTopPadding,
          _kBodyHorizontalPadding,
          _kBodyBottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            WeeklySummaryCard(
              weekTotalSeconds: weekTotalSeconds,
              weekStuckSeconds: weekStuckSeconds,
              todayTripCount: todayTripCount,
            ),
            const SizedBox(height: _kSectionGap),
            TodayTripsSection(
              asyncToday: asyncToday,
              trackingState: trackingState,
            ),
            const SizedBox(height: _kFabClearance),
          ],
        ),
      ),
      floatingActionButton: isTracking
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, kRouteTracking),
              icon: const Icon(Icons.navigation_rounded),
              label: const Text(kDashboardFabActiveLabel),
            )
          : FloatingActionButton.extended(
              onPressed: () => _handleStart(context, ref),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(kDashboardFabIdleLabel),
            ),
    );
  }

  Future<void> _handleAddManualTrip(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => const ManualEntrySheet(),
    );
    if (!context.mounted) return;
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
