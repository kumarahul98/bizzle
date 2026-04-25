import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/routes.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';
import 'package:traevy/features/tracking/services/tracking_permission_service.dart';
import 'package:traevy/features/trips/providers/trip_management_providers.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Traevy')),
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
  /// [TripManagementNotifier.deleteTrip] on confirmation.
  ///
  /// Two-step guard (T-03-14): user must tap the destructive 'Delete'
  /// button explicitly; dialog dismissal (back tap, outside tap) is
  /// treated as cancel via `confirmed ?? false`.
  ///
  /// Called from trip cards in Phase 4.
  Future<void> handleDeleteTrip(
    BuildContext context,
    WidgetRef ref,
    String tripId,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete trip?'),
        content: const Text('This trip will be permanently removed.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted) return; // Pitfall 1: always check after await
    if (confirmed ?? false) {
      await ref.read(tripManagementProvider.notifier).deleteTrip(tripId);
      if (!context.mounted) return;
      final state = ref.read(tripManagementProvider);
      if (state is TripManagementSaved) {
        ref.read(tripManagementProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted')),
        );
      } else if (state is TripManagementError) {
        ref.read(tripManagementProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't delete the trip. Try again.")),
        );
      }
    }
  }
}
