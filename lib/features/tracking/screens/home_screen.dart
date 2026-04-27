import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/tracking/state/tracking_state.dart';
import 'package:traevy/features/trips/services/trip_actions.dart'
    as trip_actions;
import 'package:traevy/features/trips/widgets/manual_entry_sheet.dart';

/// Phase 2 minimal home screen (D-13).
///
/// Shows the app title, a short subtitle, and a single `Start commute`
/// CTA. Tapping the CTA probes — but does not request — the current
/// permission status:
///
///   * [TrackingPermissionStatus.permanentlyDenied] → show the D-09
///     location-settings dialog, do NOT navigate.
///   * [TrackingPermissionStatus.notificationDenied] → show the UX-03
///     notification-settings dialog, do NOT navigate. The foreground
///     notification is a hard requirement for background tracking on
///     Android 13+, so Start is blocked until the user grants it.
///   * every other state → navigate to the tracking screen, which
///     runs the full four-step preflight in its own `initState` and
///     handles [TrackingPermissionStatus.denied] and
///     [TrackingPermissionStatus.foregroundOnly] there.
class HomeScreen extends ConsumerWidget {
  /// Create the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingStateProvider);
    final isTracking = trackingState is TrackingActive;

    return Scaffold(
      appBar: AppBar(title: const Text('Traevy')),
      floatingActionButton: isTracking
          ? null
          : FloatingActionButton(
              onPressed: () => _handleAddManualTrip(context, ref),
              tooltip: 'Add missed commute',
              child: const Icon(Icons.add),
            ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Track your commute',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FractionallySizedBox(
              widthFactor: 0.7,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start commute'),
                onPressed: () => _handleStart(context, ref),
              ),
            ),
            const SizedBox(height: 12),
            FractionallySizedBox(
              widthFactor: 0.7,
              child: OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, kRouteHistory),
                child: const Text('View history'),
              ),
            ),
            const SizedBox(height: 12),
            FractionallySizedBox(
              widthFactor: 0.7,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, kRouteStats),
                child: const Text(kStatsHomeButtonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Open the manual entry bottom sheet so the user can record a forgotten
  /// commute.
  ///
  /// D-09: FAB is hidden while tracking is active (T-03-20).
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
    if (!context.mounted) return; // Pitfall 1: always check after await
  }

  Future<void> _handleStart(BuildContext context, WidgetRef ref) async {
    final service = ref.read(trackingPermissionServiceProvider);
    final status = await service.currentStatus();
    if (!context.mounted) return;
    if (status == TrackingPermissionStatus.permanentlyDenied) {
      await _showSettingsDialog(
        context,
        service,
        title: 'Location permission denied',
        body:
            'Location permission is permanently denied. Open system '
            'settings to enable it?',
      );
      return;
    }
    if (status == TrackingPermissionStatus.notificationDenied) {
      await _showSettingsDialog(
        context,
        service,
        title: 'Notifications required',
        body:
            'Notifications are required to track commutes in the '
            'background. Open system settings to enable them?',
      );
      return;
    }
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (shouldOpen ?? false) {
      await service.openSystemSettings();
    }
  }

  /// Show a delete confirmation dialog and call
  /// `TripManagementNotifier.deleteTrip` on confirmation.
  ///
  /// Delegates to the top-level [trip_actions.handleDeleteTrip] so the
  /// HistoryScreen trip cards can share the same confirmation flow
  /// without duplicating the dialog implementation (Phase 4 D-08).
  Future<void> handleDeleteTrip(
    BuildContext context,
    WidgetRef ref,
    String tripId,
  ) => trip_actions.handleDeleteTrip(context, ref, tripId);
}
